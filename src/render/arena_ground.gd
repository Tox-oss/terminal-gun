extends Node3D
const FLOOR_SCENE := "res://assets/models/ground_tile.glb"
const CRATE_SCENE := "res://assets/models/crate.glb"
const TILE := 2.0
const WALL_ROWS := 1
const CRATE_COUNT := 28
const CRATE_SEED := 20240502
const CRATE_TENTATIVI := 6
const FALLBACK_RADIUS := 35.0
const FLOOR_MARGIN := 8.0
const CRATE_INNER := 7.0
const CRATE_OUTER_GAP := 4.0

var _floor: MultiMeshInstance3D = null
var _wall: MultiMeshInstance3D = null
var _crates: MultiMeshInstance3D = null
var _sources: Array[PackedScene] = []
var _written_crates: Array[Transform3D] = []
var _written_floor: Array[Transform3D] = []
var _written_wall: Array[Transform3D] = []
var _contract_cache: Node = null
var _built: bool = false
var _radius: float = 0.0

func _ready() -> void:
	_build()

func _build() -> void:
	if _built:
		return
	_built = true
	_radius = arena_radius()
	_floor = _add_multimesh("Floor", FLOOR_SCENE)
	_build_floor(_floor, _radius)
	_wall = _add_multimesh("Wall", FLOOR_SCENE)
	_build_wall(_wall, _radius)
	_crates = _add_multimesh("Crates", CRATE_SCENE)
	_build_crates(_crates, _radius)
	_fit_aabbs(_radius)

func _add_multimesh(node_name: String, scene_path: String) -> MultiMeshInstance3D:
	var mi := MultiMeshInstance3D.new()
	mi.name = node_name
	add_child(mi)
	var mesh := _load_mesh(scene_path)
	if mesh == null:
		push_warning("arena_ground: nessuna mesh in %s" % scene_path)
		return mi
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = false
	mm.mesh = mesh
	mm.instance_count = 1
	mi.multimesh = mm
	mi.material_override = _flat_material()
	mi.custom_aabb = AABB()
	return mi

func _fit_aabbs(radius: float) -> void:
	var side := radius * 2.0 + FLOOR_MARGIN
	var half := side * 0.5 * sqrt(2.0)
	var box := AABB(Vector3(-half, -0.5, -half), Vector3(half * 2.0, 10.0, half * 2.0))
	for mi in [_floor, _wall, _crates]:
		if mi != null:
			(mi as MultiMeshInstance3D).custom_aabb = box

func _flat_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.95
	m.metallic = 0.0
	return m

func _build_floor(mi: MultiMeshInstance3D, radius: float) -> void:
	var mm := _multimesh_of(mi)
	if mm == null:
		return
	var side := radius * 2.0 + FLOOR_MARGIN
	var per_side := int(ceil(side / TILE))
	var origin := -side * 0.5
	var flat := Basis.IDENTITY
	var transforms: Array[Transform3D] = []
	for ix in per_side:
		for iz in per_side:
			var x := origin + (float(ix) + 0.5) * TILE
			var z := origin + (float(iz) + 0.5) * TILE
			transforms.append(Transform3D(flat, Vector3(x, 0.0, z)))
	mm.instance_count = transforms.size()
	var n := 0
	for t in transforms:
		mm.set_instance_transform(n, t)
		n += 1
	mm.visible_instance_count = transforms.size()
	_written_floor = transforms

func _build_wall(mi: MultiMeshInstance3D, radius: float) -> void:
	var mm := _multimesh_of(mi)
	if mm == null:
		return
	var segments := maxi(8, int(ceil(TAU * radius / TILE)))
	var transforms: Array[Transform3D] = []
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		var outward := Vector3(cos(angle), 0.0, sin(angle))
		var tangent := Vector3(-sin(angle), 0.0, cos(angle))
		var basis := Basis(tangent, outward, Vector3.UP)
		for row in WALL_ROWS:
			var y := (float(row) + 0.5) * TILE
			transforms.append(Transform3D(basis, outward * radius + Vector3(0.0, y, 0.0)))
	mm.instance_count = transforms.size()
	var n := 0
	for t in transforms:
		mm.set_instance_transform(n, t)
		n += 1
	mm.visible_instance_count = transforms.size()
	_written_wall = transforms

func _build_crates(mi: MultiMeshInstance3D, radius: float) -> void:
	var mm := _multimesh_of(mi)
	if mm == null:
		return
	mm.instance_count = CRATE_COUNT
	_written_crates.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = CRATE_SEED
	var outer := maxf(CRATE_INNER + 1.0, radius - CRATE_OUTER_GAP)
	for i in CRATE_COUNT:
		var angle := rng.randf() * TAU
		var r := rng.randf_range(CRATE_INNER, outer)
		var p := Vector2(cos(angle) * r, sin(angle) * r)
		var pos := Vector3(p.x, TILE * 0.225, p.y)
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU), pos)
		mm.set_instance_transform(i, t)
		_written_crates.append(t)
	mm.visible_instance_count = CRATE_COUNT

func arena_radius() -> float:
	var game := _contract()
	if game == null:
		return FALLBACK_RADIUS
	var value = game.get("arena_radius")
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return maxf(float(value), 6.0)
	return FALLBACK_RADIUS

func floor_instances() -> int:
	return _visible_count(_floor)

func wall_instances() -> int:
	return _visible_count(_wall)

func crate_instances() -> int:
	return _visible_count(_crates)

func floor_transform(i: int) -> Transform3D:
	if i < 0 or i >= _written_floor.size():
		return Transform3D.IDENTITY
	return _written_floor[i]

func crate_transform(i: int) -> Transform3D:
	if i < 0 or i >= _written_crates.size():
		return Transform3D.IDENTITY
	return _written_crates[i]

func floor_tiles_on(_piano: int) -> int:
	return _written_floor.size()

func wall_tiles_on(_piano: int) -> int:
	return _written_wall.size()

func crate_floor(_i: int) -> int:
	return 0

func crates_inside_holes() -> int:
	return 0

func floor_count() -> int:
	return 1

func floor_height() -> float:
	return 0.0

func _multimesh_of(mi: MultiMeshInstance3D) -> MultiMesh:
	if mi == null:
		return null
	return mi.multimesh

func _visible_count(mi: MultiMeshInstance3D) -> int:
	if mi == null or mi.multimesh == null:
		return 0
	return mi.multimesh.visible_instance_count

func _contract() -> Node:
	if _contract_cache != null and is_instance_valid(_contract_cache):
		return _contract_cache
	var tree := get_tree()
	if tree != null:
		_contract_cache = tree.root.get_node_or_null("Game")
	return _contract_cache

func _load_mesh(path: String) -> Mesh:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path)
	if not (packed is PackedScene):
		return null
	_sources.append(packed as PackedScene)
	var probe: Node = (packed as PackedScene).instantiate()
	var found: Mesh = null
	var stack: Array[Node] = []
	stack.append(probe)
	while not stack.is_empty() and found == null:
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			found = (node as MeshInstance3D).mesh
		else:
			for child in node.get_children():
				stack.append(child)
	probe.free()
	return found