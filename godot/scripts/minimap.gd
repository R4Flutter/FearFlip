extends Control

var maze: Array[String] = []
var player_cell := Vector2i.ZERO
var goal_cell := Vector2i.ZERO
var devil_cell := Vector2i.ZERO
var explored: Dictionary = {}
var cell_size := 14.0

func _ready() -> void:
    custom_minimum_size = Vector2(220, 220)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    queue_redraw()

func _process(_delta: float) -> void:
    queue_redraw()

func _draw() -> void:
    var map_width := float(maze[0].length()) * cell_size if not maze.is_empty() else 0.0
    var map_height := float(maze.size()) * cell_size
    draw_style_box(_panel_style(Color(0.015, 0.02, 0.035, 0.92)), Rect2(0, 0, map_width + 20, map_height + 20))
    for y in maze.size():
        for x in maze[y].length():
            var cell := Vector2i(x, y)
            var rect := Rect2(10 + x * cell_size, 10 + y * cell_size, cell_size - 1, cell_size - 1)
            if maze[y][x] == "1":
                draw_rect(rect, Color(0.16, 0.19, 0.24, 1))
            elif explored.get(cell, false):
                draw_rect(rect, Color(0.07, 0.11, 0.15, 1))
            else:
                draw_rect(rect, Color(0.008, 0.012, 0.02, 1))
    _draw_marker(goal_cell, Color(0.2, 1.0, 0.55, 1), 3.5)
    _draw_marker(devil_cell, Color(1.0, 0.16, 0.18, 1), 3.5)
    _draw_marker(player_cell, Color(0.25, 0.75, 1.0, 1), 4.0)

func _draw_marker(cell: Vector2i, color: Color, radius: float) -> void:
    draw_circle(Vector2(10 + cell.x * cell_size + cell_size * 0.5, 10 + cell.y * cell_size + cell_size * 0.5), radius, color)

func _panel_style(color: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.border_color = Color(0.25, 0.65, 0.8, 0.55)
    style.set_border_width_all(1)
    style.corner_radius_top_left = 6
    style.corner_radius_top_right = 6
    style.corner_radius_bottom_left = 6
    style.corner_radius_bottom_right = 6
    return style
