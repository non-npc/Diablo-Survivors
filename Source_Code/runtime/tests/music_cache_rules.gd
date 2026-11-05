extends SceneTree
func _initialize() -> void:
    var args:=OS.get_cmdline_user_args()
    var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
    var checked:Dictionary={}
    for area in manifest.arenas:
        assert(manifest.music.has(area),"Every imported area must have a soundtrack")
        var path:String=manifest.music[area].path
        if checked.has(path):continue
        var stream:=AudioStreamWAV.load_from_file(path)
        assert(stream!=null and stream.get_length()>0,"Cached music must decode in Godot")
        checked[path]=true
    print("MUSIC_CACHE_OK: ",manifest.arenas.size()," areas, ",checked.size()," playable tracks")
    quit()
