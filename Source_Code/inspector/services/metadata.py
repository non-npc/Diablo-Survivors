"""Read installation metadata without running executables."""
import ctypes
import json
import sys
from pathlib import Path

def executable_version(path):
    if sys.platform != "win32":
        return None
    dll = ctypes.WinDLL("version", use_last_error=True)
    dll.GetFileVersionInfoSizeW.argtypes = [ctypes.c_wchar_p, ctypes.POINTER(ctypes.c_uint32)]
    dll.GetFileVersionInfoSizeW.restype = ctypes.c_uint32
    dll.GetFileVersionInfoW.argtypes = [ctypes.c_wchar_p, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_void_p]
    dll.GetFileVersionInfoW.restype = ctypes.c_int
    dll.VerQueryValueW.argtypes = [ctypes.c_void_p, ctypes.c_wchar_p, ctypes.POINTER(ctypes.c_void_p), ctypes.POINTER(ctypes.c_uint32)]
    dll.VerQueryValueW.restype = ctypes.c_int
    ignored = ctypes.c_uint32()
    size = dll.GetFileVersionInfoSizeW(str(path), ctypes.byref(ignored))
    if not size or size > 16 * 1024 * 1024: return None
    buffer = ctypes.create_string_buffer(size)
    if not dll.GetFileVersionInfoW(str(path), 0, size, buffer): return None
    pointer = ctypes.c_void_p()
    length = ctypes.c_uint32()
    if not dll.VerQueryValueW(buffer, "\\", ctypes.byref(pointer), ctypes.byref(length)) or length.value < 52: return None
    values = ctypes.cast(pointer, ctypes.POINTER(ctypes.c_uint32 * 13)).contents
    if values[0] != 0xFEEF04BD: return None
    def version(high, low):
        return ".".join(str(n) for n in (high >> 16, high & 0xffff, low >> 16, low & 0xffff))
    result = {"fixed_file_version": version(values[2], values[3]), "fixed_product_version": version(values[4], values[5])}
    translations = ctypes.c_void_p()
    translation_size = ctypes.c_uint32()
    if dll.VerQueryValueW(buffer, "\\VarFileInfo\\Translation", ctypes.byref(translations), ctypes.byref(translation_size)) and translation_size.value >= 4:
        pair = ctypes.cast(translations, ctypes.POINTER(ctypes.c_uint16 * 2)).contents
        prefix = f"\\StringFileInfo\\{pair[0]:04x}{pair[1]:04x}\\"
        for key, resource in (("file_version", "FileVersion"), ("product_version", "ProductVersion")):
            text_pointer = ctypes.c_void_p()
            text_size = ctypes.c_uint32()
            if dll.VerQueryValueW(buffer, prefix + resource, ctypes.byref(text_pointer), ctypes.byref(text_size)) and text_size.value:
                offset = text_pointer.value - ctypes.addressof(buffer)
                if 0 <= offset < size:
                    count = min(text_size.value, (size - offset) // ctypes.sizeof(ctypes.c_wchar), 4096)
                    result[key] = ctypes.wstring_at(text_pointer, count).split("\x00", 1)[0]
    return result

def installation_metadata(folder):
    folder = Path(folder)
    result = {"executables": [], "distribution_metadata": []}
    for path in sorted(folder.rglob("*.exe")):
        details = executable_version(path)
        if details:
            result["executables"].append({"path": path.relative_to(folder).as_posix(), **details})
    for path in sorted(folder.glob("goggame-*.info")):
        try:
            info = json.loads(path.read_text(encoding="utf-8-sig"))
            result["distribution_metadata"].append({"distribution": "GOG", "name": info.get("name"), "game_id": info.get("gameId"), "build_id": info.get("buildId"), "language": info.get("language"), "languages": info.get("languages", [])})
        except (ValueError, OSError):
            continue
    return result
