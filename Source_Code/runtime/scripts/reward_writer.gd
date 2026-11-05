extends RefCounted
const Classes=preload("res://scripts/class_progress.gd")
# This function runs on a worker thread and only accesses its copied inputs/files.
static func save(path:String,summary:Dictionary,fallback:Dictionary) -> Dictionary:
    var document:Dictionary=fallback
    if FileAccess.file_exists(path):
        var parsed=JSON.parse_string(FileAccess.get_file_as_string(path))
        if not parsed is Dictionary:return {"ok":false}
        document=parsed
    var candidate:Dictionary=Classes.record(Classes.migrate(document),summary)
    if DirAccess.make_dir_recursive_absolute(path.get_base_dir())!=OK:return {"ok":false}
    var output:=FileAccess.open(path+".tmp",FileAccess.WRITE)
    if output==null:return {"ok":false}
    output.store_string(JSON.stringify(candidate));output.flush()
    var error:=output.get_error();output.close()
    if error!=OK or DirAccess.rename_absolute(path+".tmp",path)!=OK:return {"ok":false}
    return {"ok":true,"progress":candidate,"earned":candidate.runs.back().gold_earned}
