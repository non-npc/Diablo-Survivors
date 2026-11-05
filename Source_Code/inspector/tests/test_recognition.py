import io
import struct
import pytest
from PIL import Image
from inspector.services.recognition import inspect_resource, sprite_groups, frame_layout, rle_pixels


def sample_cl2():
    # Two direction headers stored together, followed by both pixel groups.
    # 32 rows of one opaque palette-index-zero pixel, with a clipped header.
    pixels = b"\xff\x00" * 32
    frame = struct.pack("<5H",10,10+len(pixels),0,0,0)+pixels
    prefix = struct.pack("<2I",8,20)
    first = struct.pack("<3I",1,24,24+len(frame))
    second = struct.pack("<3I",1,12+len(frame),12+2*len(frame))
    return prefix+first+second+frame+frame


def test_image_signature_beats_misleading_extension():
    stream=io.BytesIO()
    Image.new("RGB",(19,13),(20,30,40)).save(stream,format="PCX")
    info,image=inspect_resource(stream.getvalue(),"not-an-image.bin")
    assert info["type"]=="image" and info["format"]=="PCX"
    assert (info["width"],info["height"])==(19,13)
    assert image.size==(19,13)


def test_wave_content_reports_codec_and_duration():
    fmt=struct.pack("<HHIIHH",1,2,8000,32000,4,16)
    audio=bytes(3200)
    body=b"WAVE"+b"fmt "+struct.pack("<I",len(fmt))+fmt+b"data"+struct.pack("<I",len(audio))+audio
    info,image=inspect_resource(b"RIFF"+struct.pack("<I",len(body))+body,"unknown.bin")
    assert info["type"]=="audio" and info["format"]=="WAV"
    assert info["channels"]==2 and info["sample_rate"]==8000
    assert info["duration_seconds"]==0.1 and image is None


def test_direction_tables_need_not_border_group_pixel_data():
    info,image=inspect_resource(sample_cl2(),"actor.cl2",palette=bytes([0,80,120])*256)
    assert info["group_count"]==2 and info["frame_count"]==2
    assert image.size==(1,32)
    # Color index zero is opaque when encoded as an opaque run.
    assert image.getpixel((0,0))==(0,80,120,255)
    assert info["preview_frames"][0]["height"]==32


def test_cl2_skip_fill_literal_and_bottom_up_orientation():
    # Bottom row: skip one, fill two; top row: literal three.
    indices,alpha=rle_pixels(bytes([1,189,7,253,1,2,3]),"CL2")
    assert list(indices)==[0,7,7,1,2,3]
    assert list(alpha)==[0,255,255,255,255,255]


def test_cel_literal_and_transparent_runs():
    indices,alpha=rle_pixels(bytes([2,4,5,254]),"CEL")
    assert list(indices)==[4,5,0,0]
    assert list(alpha)==[255,255,0,0]


@pytest.mark.parametrize("data,kind", [(b"\xbf", "CL2"),(b"\x80","CL2"),(b"\x02\x01","CEL")])
def test_reject_truncated_runs(data,kind):
    with pytest.raises(ValueError,match="Truncated"):
        rle_pixels(data,kind)


def test_reject_sprite_offset_overflow():
    data=bytearray(sample_cl2())
    struct.pack_into("<I",data,16,0xffffffff)
    with pytest.raises(ValueError): sprite_groups(data)


def test_tile_definitions_are_structurally_identified():
    info,image=inspect_resource(struct.pack("<8H",*range(8)),"levels/l1data/l1.til")
    assert info["type"]=="terrain" and info["format"]=="TIL"
    assert info["record_count"]==2 and info["confidence"]=="structure"


def test_dungeon_tile_grid_preview_is_labeled_as_ids():
    info,image=inspect_resource(struct.pack("<HH4H",2,2,1,2,3,4),"arena.dun")
    assert info["type"]=="terrain" and info["width"]==2
    assert image is not None and "not reconstructed" in info["preview_note"]


def test_invalid_wave_without_format_chunk_is_rejected():
    with pytest.raises(ValueError,match="format chunk"):
        inspect_resource(b"RIFF\x04\x00\x00\x00WAVE","invalid.wav")


def test_group_headers_can_be_interleaved_with_pixels():
    frame=b"synthetic bytes"
    second=8+12+len(frame)
    data=struct.pack("<2I",8,second)+struct.pack("<3I",1,12,12+len(frame))+frame+struct.pack("<3I",1,12,12+len(frame))+frame
    groups=sprite_groups(data)
    assert len(groups)==2
    assert data[groups[0][0][0]:groups[0][0][1]]==frame
    assert data[groups[1][0][0]:groups[1][0][1]]==frame
