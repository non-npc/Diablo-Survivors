"""Read-only classic MPQ metadata plus StormLib payload access.

The table hash/decryption algorithm implements the documented MPQ container
format; it is not executable game code. Only the approved StormLib reader
opens payloads. No source archive is changed.
"""
import ctypes
import ctypes.util
import hashlib
import os
import struct
import sys
from pathlib import Path
from manager.services.paths import ROOT

MAX_TABLE_BYTES = 64 * 1024 * 1024
MAX_ASSET_BYTES = 128 * 1024 * 1024
MASK = 0xFFFFFFFF
CRYPT = [0] * 0x500
seed = 0x100001
for i in range(256):
    for j in range(5):
        seed = (seed * 125 + 3) % 0x2AAAAB
        high = (seed & 0xFFFF) << 16
        seed = (seed * 125 + 3) % 0x2AAAAB
        CRYPT[i + j * 256] = high | (seed & 0xFFFF)

def name_hash(name, kind):
    a, b = 0x7FED7FED, 0xEEEEEEEE
    for value in name.replace("/", "\\").upper().encode("ascii"):
        a = (CRYPT[kind * 256 + value] ^ (a + b)) & MASK
        b = (value + a + b + (b << 5) + 3) & MASK
    return a

def decode_table(data, key):
    seed = 0xEEEEEEEE
    output = bytearray()
    for value, in struct.iter_unpack("<I", data):
        seed = (seed + CRYPT[0x400 + (key & 255)]) & MASK
        plain = value ^ ((key + seed) & MASK)
        output.extend(struct.pack("<I", plain))
        key = (((~key << 21) + 0x11111111) | (key >> 11)) & MASK
        seed = (plain + seed + (seed << 5) + 3) & MASK
    return bytes(output)

def safe_resource_path(name):
    name = name.replace("\\", "/")
    parts = name.split("/")
    if not name or name.startswith("/") or any(p in {"", ".", ".."} for p in parts) or any(":" in p or "\x00" in p for p in parts):
        raise ValueError("Unsafe archive resource path")
    return name

class ClassicMPQ:
    def __init__(self, path):
        self.path = Path(path).resolve()
        size = self.path.stat().st_size
        with self.path.open("rb") as stream:
            raw = stream.read(32)
            if len(raw) != 32:
                raise ValueError("Truncated MPQ header")
            magic, header_size, declared, version, shift, hash_offset, block_offset, hash_count, block_count = struct.unpack("<4sIIHHIIII", raw)
            if magic != b"MPQ\x1a" or version != 0 or header_size != 32:
                raise ValueError("Only classic MPQ v0 with a header at offset zero is currently inspected")
            if shift > 16 or declared > size or hash_count == 0 or hash_count & (hash_count - 1):
                raise ValueError("Invalid MPQ header values")
            def table(offset, count, name):
                length = count * 16
                if length > MAX_TABLE_BYTES or offset < header_size or offset + length > declared:
                    raise ValueError("MPQ table outside declared archive or size limit")
                stream.seek(offset)
                return decode_table(stream.read(length), name_hash(name, 3))
            self.hashes = list(struct.iter_unpack("<IIHHI", table(hash_offset, hash_count, "(hash table)")))
            self.blocks = list(struct.iter_unpack("<IIII", table(block_offset, block_count, "(block table)")))
        self.header = {"format_version": version, "physical_bytes": size, "declared_bytes": declared, "sector_bytes": 512 << shift, "hash_slots": hash_count, "block_entries": block_count, "existing_blocks": sum(bool(b[3] & 0x80000000) for b in self.blocks)}
        for offset, stored, decoded, flags in self.blocks:
            if flags & 0x80000000 and (offset < header_size or offset + stored > declared):
                raise ValueError("Asset block outside declared archive")

    def lookup(self, name):
        count = len(self.hashes)
        for index in range(count):
            a, b, locale, platform, block = self.hashes[(name_hash(name, 0) + index) % count]
            if block == MASK:
                return None
            if block == 0xFFFFFFFE:
                continue
            if a == name_hash(name, 1) and b == name_hash(name, 2):
                if block >= len(self.blocks):
                    raise ValueError("Hash references an invalid block")
                offset, stored, decoded, flags = self.blocks[block]
                if not flags & 0x80000000:
                    return None
                return {"block_index": block, "offset": offset, "stored_bytes": stored, "decoded_bytes": decoded, "flags": hex(flags), "locale": locale}
        return None

    def rows(self, names):
        named = {}
        for name in names:
            metadata = self.lookup(name)
            if metadata:
                named.setdefault(metadata["block_index"], []).append(name)
        rows = []
        for index, (offset, stored, decoded, flags) in enumerate(self.blocks):
            if flags & 0x80000000:
                for name in named.get(index, [""]):
                    rows.append({"source_path": name, "block_index": index, "offset": offset, "stored_bytes": stored, "decoded_bytes": decoded, "flags": hex(flags)})
        return rows

class StormArchive:
    def __init__(self, path):
        self.path = Path(path).resolve()
        configured = os.environ.get("STORMLIB_PATH")
        default = ROOT / ".tools/stormlib-9.40/x64/StormLib.dll"
        library = configured or (str(default) if default.is_file() else ctypes.util.find_library("storm"))
        if not library:
            raise RuntimeError("StormLib was not found. Run scripts/setup_stormlib.py or set STORMLIB_PATH.")
        loader = ctypes.WinDLL if sys.platform == "win32" else ctypes.CDLL
        self.dll = loader(library, use_last_error=True) if sys.platform == "win32" else loader(library)
        handle = ctypes.c_void_p
        u32 = ctypes.c_uint32
        signatures = {
            "SFileOpenArchive": ([ctypes.c_void_p, u32, u32, ctypes.POINTER(handle)], ctypes.c_bool),
            "SFileCloseArchive": ([handle], ctypes.c_bool),
            "SFileOpenFileEx": ([handle, ctypes.c_char_p, u32, ctypes.POINTER(handle)], ctypes.c_bool),
            "SFileCloseFile": ([handle], ctypes.c_bool),
            "SFileGetFileSize": ([handle, ctypes.POINTER(u32)], u32),
            "SFileReadFile": ([handle, ctypes.c_void_p, u32, ctypes.POINTER(u32), ctypes.c_void_p], ctypes.c_bool),
        }
        for name, (arguments, result) in signatures.items():
            fn = getattr(self.dll, name)
            fn.argtypes, fn.restype = arguments, result
        self.handle = handle()
        # Official Windows DLL distributions can be ANSI or Unicode builds.
        # Padded buffers keep either ABI probe bounded; the archive is read-only.
        encodings = ["utf-8", "utf-16-le"] if sys.platform == "win32" else ["utf-8"]
        for encoding in encodings:
            path_buffer = ctypes.create_string_buffer(str(self.path).encode(encoding), max(4096, len(str(self.path).encode(encoding)) + 4))
            if self.dll.SFileOpenArchive(path_buffer, 0, 0x100, ctypes.byref(self.handle)):
                break
        else:
            raise OSError(f"StormLib could not open archive: {self.path}")

    def read(self, name, limit=MAX_ASSET_BYTES):
        safe_resource_path(name)
        handle = ctypes.c_void_p()
        if not self.dll.SFileOpenFileEx(self.handle, name.replace("/", "\\").encode("ascii"), 0, ctypes.byref(handle)):
            raise FileNotFoundError(f"Archive resource not found: {name}")
        try:
            high = ctypes.c_uint32()
            low = self.dll.SFileGetFileSize(handle, ctypes.byref(high))
            size = (high.value << 32) | low
            if low == MASK or size > limit:
                raise ValueError("Asset exceeds extraction size limit or has invalid size")
            buffer = ctypes.create_string_buffer(size)
            read = ctypes.c_uint32()
            if size and (not self.dll.SFileReadFile(handle, buffer, size, ctypes.byref(read), None) or read.value != size):
                raise OSError(f"Incomplete or failed resource read: {name}")
            return buffer.raw[:size]
        finally:
            self.dll.SFileCloseFile(handle)

    def close(self):
        if self.handle:
            self.dll.SFileCloseArchive(self.handle)
            self.handle = None
    def __enter__(self):
        return self
    def __exit__(self, *args):
        self.close()
