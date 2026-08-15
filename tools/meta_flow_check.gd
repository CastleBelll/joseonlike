extends Node
## N7-1 runtime persistence check over the REAL save path: each phase is a
## separate process, so state must survive a full relaunch to pass.
## Run: godot --headless --path . res://tools/meta_flow_check.tscn -- --phase=X
##   --phase=bank    bank a finished run's gold into the profile and save
##   --phase=buy     buy iron_bones rank 1 through SaveService (atomic write)
##   --phase=verify  print what a fresh boot loaded from disk

const NODE_ID := "iron_bones"


func _ready() -> void:
	var phase: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="):
			phase = arg.get_slice("=", 1)
	if SaveService.instance == null:
		push_error("meta_flow_check: SaveManager autoload missing")
		get_tree().quit(1)
		return
	match phase:
		"bank":
			var total: int = SaveService.instance.bank_run(300.0, 100, 200, true)
			print("FLOW bank: gold=%d" % total)
		"buy":
			var before: int = SaveService.instance.gold()
			var reason: String = SaveService.instance.purchase_meta_node(
				MetaTree.load_tree(), NODE_ID
			)
			print("FLOW buy: reason=%s gold %d -> %d rank=%d" % [
				reason, before, SaveService.instance.gold(),
				MetaTree.rank_of(SaveService.instance.profile["meta_tree"], NODE_ID),
			])
		"verify":
			print("FLOW verify: gold=%d rank=%d" % [
				SaveService.instance.gold(),
				MetaTree.rank_of(
					SaveService.instance.profile.get("meta_tree", {}), NODE_ID
				),
			])
		_:
			push_error("meta_flow_check: pass --phase=bank|buy|verify after --")
	get_tree().quit(0)
