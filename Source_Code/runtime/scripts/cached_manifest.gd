extends RefCounted

static func read_document(path:String) -> Dictionary:
    if not FileAccess.file_exists(path):return {}
    var value=JSON.parse_string(FileAccess.get_file_as_string(path))
    return value if value is Dictionary else {}

static func find(root:String) -> String:
    var local:String=root.path_join(".local")
    var selected:String=read_document(local.path_join("launcher/settings.json")).get("active_game","")
    var active:Dictionary=read_document(local.path_join("launcher/active_manifest.json"))
    var candidates:Array=[]
    if selected.is_empty() or active.get("game","")==selected:candidates.append(str(active.get("manifest_path","")))
    if selected in ["","diablo2","diablo2_lod"]:
        candidates.append(str(read_document(local.path_join("diablo2/active.json")).get("manifest_path","")))
    if selected in ["","diablo1"]:
        candidates.append(str(read_document(local.path_join("launcher/diablo1-preparation.json")).get("manifest_path","")))
    for candidate in candidates:
        if not candidate.is_empty() and FileAccess.file_exists(candidate):return candidate
    return ""
