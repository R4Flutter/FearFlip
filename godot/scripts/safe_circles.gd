class_name SafeCircles
extends RefCounted
## Safe circles (plans/05 §3.5): evenly spaced along the floor route. Inside one the Devil can't
## catch you and backs off, but protection drains while you stand in it. An empty circle goes dark
## until you've explored RECHARGE_CELLS new cells (late floors: never comes back).

const RECHARGE_CELLS := 12

var cells: Array[Vector2i] = []
## Seconds of protection left per circle.
var charge: Array[float] = []
var capacity := 8.0
var single_use := false
var _recharge_left: Array[int] = []


## `count` circles at (i+1)/(count+1) along `route` (e.g. 1/3 and 2/3), nudged to the nearest
## route cell that `allowed` accepts. Never the first or last route cell.
func place(route: Array[Vector2i], count: int, allowed: Callable) -> void:
	cells.clear()
	if route.size() < 3:
		return
	for i in count:
		var mid := roundi(float(i + 1) / float(count + 1) * (route.size() - 1))
		for offset in route.size():
			var pick := -1
			for idx in [mid + offset, mid - offset]:
				if idx > 0 and idx < route.size() - 1 and not cells.has(route[idx]) and allowed.call(route[idx]):
					pick = idx
					break
			if pick >= 0:
				cells.append(route[pick])
				break
	charge.clear()
	_recharge_left.clear()
	for _cell in cells:
		charge.append(capacity)
		_recharge_left.append(0)


func index_at(cell: Vector2i) -> int:
	return cells.find(cell)


func protects(cell: Vector2i) -> bool:
	var i := index_at(cell)
	return i >= 0 and charge[i] > 0.0


## Drain the circle you stand in. Returns true on the frame it runs dry.
func drain(cell: Vector2i, delta: float) -> bool:
	var i := index_at(cell)
	if i < 0 or charge[i] <= 0.0:
		return false
	charge[i] = maxf(charge[i] - delta, 0.0)
	if charge[i] > 0.0:
		return false
	_recharge_left[i] = -1 if single_use else RECHARGE_CELLS
	return true


## Call when you enter a cell you've never visited. Dark circles count down and refill.
func on_new_cell() -> void:
	for i in cells.size():
		if _recharge_left[i] > 0:
			_recharge_left[i] -= 1
			if _recharge_left[i] == 0:
				charge[i] = capacity
