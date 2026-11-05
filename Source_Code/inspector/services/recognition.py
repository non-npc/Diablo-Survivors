"""Bounded content inspection and original Diablo CEL/CL2 decoding.

Format references: permissively licensed clx-conversion-tools (Unlicense) and
MPQ Editor documentation. This module contains independently written code;
no third-party parser source or game asset content is embedded.
"""
import io
import math
import struct
from pathlib import Path
from PIL import Image, ImageDraw

IDENTIFIER_VERSION = "0.3.2"
MAX_PIXELS = 16 * 1024 * 1024
MAX_FRAME_PIXELS = 1024 * 1024


def sprite_groups(data):
    if len(data) < 12: raise ValueError("Truncated sprite offset table")
    first = struct.unpack_from("<I", data)[0]
    def group(start, end, exact_end=True, table_end=None):
        if start + 8 > end: raise ValueError("Invalid sprite group")
        count = struct.unpack_from("<I", data, start)[0]
        if not 0 < count <= 10000 or start + (count + 2) * 4 > (table_end or end):
            raise ValueError("Invalid frame count")
        offsets = struct.unpack_from("<" + "I" * (count + 1), data, start + 4)
        if offsets[0] < (count + 2) * 4 or (offsets[-1] != end - start if exact_end else offsets[-1] > end - start) or any(a > b for a, b in zip(offsets, offsets[1:])):
            raise ValueError("Invalid sprite frame offsets")
        return [(start + a, start + b) for a, b in zip(offsets, offsets[1:])]
    if first <= 10000 and (first + 2) * 4 <= len(data) and struct.unpack_from("<I", data, (first + 1) * 4)[0] == len(data):
        return [group(0, len(data))]
    if first % 4 or not 4 <= first <= 64 * 4 or first > len(data):
        raise ValueError("Invalid sprite group table")
    starts = list(struct.unpack_from("<" + "I" * (first // 4), data)) + [len(data)]
    if starts[0] != first or any(a >= b for a, b in zip(starts, starts[1:])):
        raise ValueError("Invalid group offsets")
    # Classic directional files place all group headers together, followed by
    # each group's pixels. Frame offsets are relative to that group's header,
    # so a group's data is not bounded by the next header's address.
    groups = [group(start, len(data), exact_end=(i == len(starts)-2), table_end=starts[i+1] if i < len(starts)-2 else None) for i,start in enumerate(starts[:-1])]
    # CEL can interleave a group's header and pixels, whereas many CL2 files
    # collect their headers first. Accept both and forbid pixel/header overlap.
    headers = [(start,start+(len(g)+2)*4) for start,g in zip(starts,groups)]
    if any(begin < header_end and end > header_start for g in groups for begin,end in g for header_start,header_end in headers):
        raise ValueError("Sprite pixels overlap a group header")
    return groups


def rle_pixels(data, kind):
    indices, alpha = bytearray(), bytearray()
    cursor = 0
    while cursor < len(data):
        control = data[cursor]
        cursor += 1
        if kind == "CL2":
            if control < 128:
                count = control
                indices.extend(bytes(count)); alpha.extend(bytes(count))
            elif control < 191:
                count = 191 - control
                if cursor >= len(data): raise ValueError("Truncated fill run")
                indices.extend(bytes([data[cursor]]) * count); alpha.extend(b"\xff" * count)
                cursor += 1
            else:
                count = 256 - control
                if cursor + count > len(data): raise ValueError("Truncated literal run")
                indices.extend(data[cursor:cursor+count]); alpha.extend(b"\xff" * count)
                cursor += count
        else:
            if control >= 128:
                count = 256 - control
                indices.extend(bytes(count)); alpha.extend(bytes(count))
            else:
                count = control
                if cursor + count > len(data): raise ValueError("Truncated literal run")
                indices.extend(data[cursor:cursor+count]); alpha.extend(b"\xff" * count)
                cursor += count
        if len(indices) > MAX_FRAME_PIXELS: raise ValueError("Sprite frame exceeds pixel limit")
    return indices, alpha


def frame_layout(frame, kind, override=0):
    if len(frame) < 2: raise ValueError("Empty sprite frame")
    header = struct.unpack_from("<H", frame)[0]
    clipped = kind == "CL2" or header == 10
    start = header if clipped else 0
    if clipped and (header % 2 or not 2 <= header <= min(len(frame), 32)):
        raise ValueError("Invalid clipped-frame header")
    width = override
    if not width and clipped:
        offsets = struct.unpack_from("<" + "H" * (header // 2), frame)
        previous = header
        inferred = set()
        for offset in offsets[1:]:
            if offset == 0: break
            if not previous <= offset <= len(frame): raise ValueError("Invalid 32-line clip offsets")
            indices, _ = rle_pixels(frame[previous:offset], kind)
            if len(indices) % 32: raise ValueError("Clip block is not 32 full lines")
            inferred.add(len(indices) // 32)
            previous = offset
        if len(inferred) == 1: width = inferred.pop()
    if not width: raise ValueError("Sprite width needs a verified catalog rule or manual preview width")
    if not 1 <= width <= 4096: raise ValueError("Invalid sprite width")
    indices, alpha = rle_pixels(frame[start:], kind)
    if not indices or len(indices) % width: raise ValueError("Frame pixels do not form complete rows")
    return width, len(indices) // width, indices, alpha


def palette_image(indices, alpha, width, height, palette):
    image = Image.frombytes("P", (width, height), bytes(indices))
    image.putpalette(palette if palette is not None else bytes(v for i in range(256) for v in (i, i, i)))
    image = image.convert("RGBA")
    image.putalpha(Image.frombytes("L", (width, height), bytes(alpha)))
    return image.transpose(Image.Transpose.FLIP_TOP_BOTTOM)


def inspect_wav(data):
    end = min(len(data), struct.unpack_from("<I", data, 4)[0] + 8)
    cursor = 12
    info = {}
    while cursor + 8 <= end:
        kind, size = struct.unpack_from("<4sI", data, cursor)
        start = cursor + 8
        if kind == b"fmt " and size >= 16 and start + 16 <= len(data):
            codec, channels, rate, byte_rate, alignment, bits = struct.unpack_from("<HHIIHH", data, start)
            info.update(codec=codec, channels=channels, sample_rate=rate, bits_per_sample=bits, byte_rate=byte_rate)
        if kind == b"data": info["audio_bytes"] = size
        cursor = start + size + (size % 2)
    if not info.get("sample_rate") or not info.get("channels"): raise ValueError("WAV has no valid format chunk")
    if info.get("byte_rate") and "audio_bytes" in info:
        info["duration_seconds"] = round(info["audio_bytes"] / info["byte_rate"], 3)
    return info


def inspect_resource(data, name, palette=None, width=0, preview_frames=8, preview_group=0, translation=None):
    lower = name.lower().replace("\\", "/")
    suffix = Path(lower).suffix
    result = {"type": "binary", "format": "unknown", "confidence": "unknown", "bytes": len(data), "decoder_version": IDENTIFIER_VERSION}
    preview = None
    if data[:4] == b"RIFF" and data[8:12] == b"WAVE":
        result.update(type="audio", format="WAV", confidence="signature", **inspect_wav(data))
    elif data[:4] == b"OggS":
        result.update(type="audio", format="OGG", confidence="signature")
    elif data[:4] == b"fLaC":
        result.update(type="audio", format="FLAC", confidence="signature")
    elif data[:4] in {b"SMK2", b"SMK4"}:
        result.update(type="video", format=data[:4].decode(), confidence="signature")
        if len(data) >= 16:
            w, h, count = struct.unpack_from("<III", data, 4)
            result.update(width=w, height=h, frame_count=count)
    elif suffix == ".trn" and len(data) == 256:
        result.update(type="palette", format="TRN", confidence="structure", colors=256, description="Palette-index translation table")
    elif suffix == ".pal" and len(data) == 768:
        result.update(type="palette", format="RGB256", confidence="structure", colors=256)
        preview = Image.new("RGB", (256, 256))
        draw = ImageDraw.Draw(preview)
        for n in range(256):
            draw.rectangle((n%16*16, n//16*16, n%16*16+15, n//16*16+15), fill=tuple(data[n*3:n*3+3]))
    elif suffix in {".til", ".min", ".sol", ".dun"}:
        result.update(type="terrain", format=suffix[1:].upper(), confidence="extension")
        if suffix == ".til" and len(data) % 8 == 0:
            result.update(confidence="structure", record_count=len(data)//8, description="Four little-endian microtile references per tile")
        elif suffix == ".min" and len(data) % 2 == 0:
            result.update(confidence="structure", reference_count=len(data)//2, description="Microtile composition references; tile-shape and collision mappings require validation")
        elif suffix == ".sol":
            result.update(record_count=len(data), description="Terrain property flags")
        elif suffix == ".dun" and len(data) >= 4:
            w, h = struct.unpack_from("<HH", data)
            if 0 < w <= 512 and 0 < h <= 512 and len(data) >= 4 + w*h*2:
                result.update(confidence="structure", width=w, height=h, description="Dungeon tile grid; additional layers preserved raw")
                values = struct.unpack_from("<" + "H"*(w*h), data, 4)
                preview = Image.new("RGB", (w,h))
                preview.putdata([((v*47)%256,(v*97)%256,(v*137)%256) for v in values])
                preview = preview.resize((min(512,w*8),min(512,h*8)),Image.Resampling.NEAREST)
                result["preview_note"] = "Tile-ID visualization, not reconstructed terrain artwork"
    elif suffix in {".cel", ".cl2"}:
        kind = suffix[1:].upper()
        groups = sprite_groups(data)
        if not 0 <= preview_group < len(groups): raise ValueError("Invalid sprite direction group")
        if translation is not None:
            from adapters.diablo1.validation import translated_palette
            if palette is None: raise ValueError("Select a palette before applying a translation")
            palette = translated_palette(palette, translation)
        terrain = suffix == ".cel" and lower.startswith("levels/")
        result.update(type="terrain" if terrain else "sprite", format=kind, confidence="structure", group_count=len(groups), frame_count=sum(len(g) for g in groups))
        result["frames_per_group"] = [len(g) for g in groups]
        images = []
        layout = []
        for n,(start,end) in enumerate(groups[preview_group][:preview_frames]):
            try:
                frame = data[start:end]
                if terrain and len(frame) == 1024:
                    w,h,indices,alpha = 32,32,frame,b"\xff"*1024
                else:
                    w,h,indices,alpha = frame_layout(frame,kind,width)
                images.append(palette_image(indices,alpha,w,h,palette))
                layout.append({"frame":n,"width":w,"height":h})
            except ValueError as exc:
                result["preview_warning"] = str(exc)
                break
        if images:
            cell_w = max(i.width for i in images)
            cell_h = max(i.height for i in images)
            columns = min(4,len(images))
            rows = math.ceil(len(images)/columns)
            if columns*cell_w*rows*cell_h > MAX_PIXELS: raise ValueError("Sprite preview exceeds pixel limit")
            preview = Image.new("RGBA",(columns*cell_w,rows*cell_h))
            for n, image in enumerate(images):
                x,y = n%columns*cell_w,n//columns*cell_h
                preview.paste(image,(x,y))
                layout[n].update(x=x,y=y)
            result.update(width=cell_w,height=cell_h,preview_frames=layout,preview_group=preview_group,preview_note="Preview of the first group; animation timing, palette translations and actor mappings are not verified")
            if palette is None: result["palette_note"] = "Grayscale fallback; original palette association unresolved"
    else:
        try:
            with Image.open(io.BytesIO(data)) as image:
                if image.width*image.height > MAX_PIXELS: raise ValueError("Image exceeds pixel limit")
                result.update(type="image",format=image.format,confidence="signature",width=image.width,height=image.height,frame_count=getattr(image,"n_frames",1))
                preview = image.convert("RGBA")
                preview.thumbnail((1024,1024))
        except (OSError, SyntaxError):
            if data and b"\x00" not in data[:4096]:
                try:
                    text=data.decode("utf-8")
                    if all(c.isprintable() or c in "\r\n\t" for c in text[:4096]):
                        result.update(type="text",format="UTF-8",confidence="content",text_preview=text[:2000])
                except UnicodeDecodeError: pass
    return result,preview
