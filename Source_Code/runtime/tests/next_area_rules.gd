extends SceneTree
const Classes=preload("res://scripts/class_progress.gd")
func _initialize() -> void:
    var progress:Dictionary=Classes.migrate({"area_order":["d2-area-2","d2-area-3"],"last_played":{"character":"necromancer","area":"d2-area-2","difficulty":"legendary"}})
    var run:Dictionary={"outcome":"victory","difficulty":"legendary","area_id":"d2-area-2","class_id":"necromancer","seconds":960,"kills":10,"challenges":[]}
    var result:Dictionary=Classes.record(progress,run)
    assert(result.last_played.area=="d2-area-3" and result.last_played.difficulty=="easy","Legendary clear must persist the next area on Easy")
    assert(result.last_played.character=="necromancer","Advancing areas must preserve the character")
    run.area_id="d2-area-3"
    result=Classes.record(result,run)
    assert(result.last_played.area=="d2-area-3","Final area clear must not select an invalid next area")
    print("NEXT_AREA_RULES_OK");quit()
