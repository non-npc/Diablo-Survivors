extends SceneTree
const Cached=preload("res://scripts/cached_manifest.gd")
func write(path:String,document:Dictionary) -> void:
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(document));file.close()
func _initialize() -> void:
    var root:String=ProjectSettings.globalize_path("res://../.local/cache handoff é "+str(Time.get_ticks_usec()))
    var manifest:String=root.path_join(".local/diablo2/generations/example/survival.json")
    write(manifest,{"schema_version":1})
    write(root.path_join(".local/diablo2/active.json"),{"manifest_path":manifest})
    write(root.path_join(".local/launcher/settings.json"),{"active_game":"diablo2_lod"})
    assert(Cached.find(root)==manifest,"Direct game launch must recover the imported D2 cache, including paths with spaces and Unicode")
    write(root.path_join(".local/launcher/active_manifest.json"),{"game":"diablo2_lod","manifest_path":manifest})
    assert(Cached.find(root)==manifest,"Launcher handoff must select its exact manifest")
    write(root.path_join(".local/launcher/settings.json"),{"active_game":"diablo1"})
    assert(Cached.find(root).is_empty(),"Missing selected-game assets must not silently load a different game or demo")
    print("CACHED_MANIFEST_OK");quit()
