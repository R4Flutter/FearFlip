extends SceneTree
## Headless run of every res://tests/test_*.gd suite (no editor / MCP needed):
## godot --headless --path godot -s res://tests/run_tests.gd


func _initialize() -> void:
	# Deferred: the root only enters the tree after _initialize, and scene tests need a live tree.
	_run.call_deferred()


func _run() -> void:
	var suites: Array = []
	for file in DirAccess.get_files_at("res://tests"):
		if file.begins_with("test_") and file.ends_with(".gd"):
			suites.append(load("res://tests/" + file).new())
	var results: Dictionary = McpTestRunner.new().run_suites(suites)
	print(JSON.stringify(results, "  "))
	quit(0 if results.get("failed", 1) == 0 else 1)
