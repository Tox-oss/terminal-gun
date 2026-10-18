extends RefCounted
## Numeri della geometria statica del mondo (milestone 10).

const OBSTACLE_COUNT := 12
const RADIUS_FRACTION := 0.065
const RING_RADII := [0.36, 0.78]
const RING_COUNTS := [3, 9]
const ANGLE_JITTER := 0.0
const SKIN_EPS := 1.0e-3

const E = preload("res://src/sim/enemy.gd")

static func radius_min_for_boss() -> float:
	return E.RADIUS[E.BOSS] / RADIUS_FRACTION

static func radius_for(arena_radius: float) -> float:
	return maxf(0.5, maxf(arena_radius, 1.0) * RADIUS_FRACTION)

static func min_separation(obstacles: PackedVector3Array) -> float:
	var minimo := 1.0e9
	for a in obstacles.size():
		for b in range(a + 1, obstacles.size()):
			var pa := obstacles[a]
			var pb := obstacles[b]
			var d := Vector2(pa.x - pb.x, pa.z - pb.z).length()
			if d < minimo:
				minimo = d
	return 0.0 if obstacles.size() < 2 else minimo

static func _hash01(n: int) -> float:
	var x := (n * 2654435761) & 0x7fffffff
	x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff
	x = x ^ (x >> 16)
	return float((x & 0xffff) % 65536) / 65536.0

static func layout(arena_radius: float, floor_index: int = 0) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(OBSTACLE_COUNT)
	var r := radius_for(arena_radius)
	var asse := 0.0
	var k := 0
	for anello in RING_RADII.size():
		var n: int = RING_COUNTS[anello]
		var passo := TAU / float(n)
		var base := asse - passo * 0.5
		var rr: float = arena_radius * float(RING_RADII[anello])
		for i in n:
			var a := passo * (float(i) + ANGLE_JITTER * (_hash01(k) * 2.0 - 1.0))
			out[k] = Vector3(cos(a + base) * rr, r, sin(a + base) * rr)
			k += 1
	return out

static func per_floor(n: int, floors: int) -> int:
	return n / maxi(floors, 1)

static func slice_floor(obs: PackedVector3Array, floor_index: int, floors: int) -> PackedVector3Array:
	var n := obs.size()
	if floors <= 1:
		return obs.duplicate()
	var per := per_floor(n, floors)
	var out := PackedVector3Array()
	var a := clampi(floor_index, 0, floors - 1) * per
	var b := mini(a + per, n)
	for i in range(a, b):
		out.append(obs[i])
	return out