extends SceneTree
## Writes src/weeks.json for the Long Night server (plans/11 v2): each week's maze as the game builds it (Race.
## export_week: the open cells, spawn, exit, key boxes, Flipping Time starts) and the rules every run is checked by
## (Race.server_rules: cell size, sample step, walk/sprint pace, stamina). The game is the only maze generator, so run
## this whenever the maze code or the player's pace changes, then redeploy (tests/test_race.gd fails until you do).
## Also writes test/route.json: the game's own route through the first week (spawn, keys, exit), which the server's
## tests walk to prove both sides read the grid the same way. From the repo root, with the weeks to export (default:
## this week and the 60 after it):
##   godot --headless --path godot -s "<repo>/server/long-night/export_weeks.gd" -- [first] [last]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var first := int(args[0]) if args.size() > 0 else Race.this_week()
	var last := int(args[1]) if args.size() > 1 else first + 60
	var weeks := {}
	for n in range(first, last + 1):
		weeks[str(n)] = Race.export_week(n)
	var root := ProjectSettings.globalize_path("res://").path_join("../server/long-night/")
	_write(root.path_join("src/weeks.json"), {"first": Race.FIRST_WEEK + "Z", "rules": Race.server_rules(), "weeks": weeks})
	var maze := Race.layout(first)
	var stops: Array[Vector2i] = maze.sigils.duplicate()
	stops.append(maze.exit)
	var cells: Array = []
	var at := maze.spawn
	for stop in stops:
		for cell in maze.route(at, stop).slice(0 if cells.is_empty() else 1):
			cells.append([cell.x, cell.y])
		at = stop
	_write(root.path_join("test/route.json"), {"week": first, "cells": cells})
	print("Long Night weeks %d..%d exported to %s" % [first, last, root])
	quit()


func _write(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("can't write %s" % path)
		return
	file.store_string(JSON.stringify(data))
