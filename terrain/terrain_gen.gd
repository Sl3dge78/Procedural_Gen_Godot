tool
extends Spatial

## UI ##
export var gen = false
export var do_erosion = false
export var draw_debug = false
#export var clear_debug = false

## GENERATION ##
var noise : OpenSimplexNoise
var image : Image
export var graine : int
export var vertex_count = 100
export var map_scale = 100.0

## EROSION ##
export var iterations : int
var amount_of_iterations_done = 0

export var brush_radius = 3
export var max_lifetime = 30
export var inertia = 0.05

export var sediment_capacity_factor = 4
export var min_sediment_capacity = 0.01
export var deposit_speed = 0.3
export var erode_speed = 0.3

export var gravity = 4
export var evaporation = 0.01

var sum_of_weights = []
var brush_indexes = []

## MESH ##
export var mesh_mult : float

## TEXTURE ##
export var water_color : Color
export var sand_color : Color
export var grass_color : Color
export var grass2_color : Color
export var mountain_color : Color
export var snow_color : Color

var heightmap

func _ready():
	generate()

func _process(delta):
	if not Engine.editor_hint:
		pass
#		clear_debug()
		erode(1)
		edit_mesh()
		draw_noise()
		amount_of_iterations_done += 1
		$terrain_ui/iterations.text = str(amount_of_iterations_done) +"k"

	else : 
		if gen:
			gen = false
			generate()
		if do_erosion:
			do_erosion = false
			erode(iterations)
			edit_mesh()
			draw_noise()
#		if clear_debug:
#			clear_debug()
#			clear_debug = false

func generate():
	noise = OpenSimplexNoise.new()
	noise.seed = graine
	noise.lacunarity = $terrain_ui.lacunarity
	noise.octaves = $terrain_ui.octaves
	noise.period = $terrain_ui.period
	noise.persistence = $terrain_ui.persistence
	heightmap = get_basic_heightmap()

	init_erosion(brush_radius)
	erode(iterations)

	create_mesh()

#	draw_texture()
	draw_noise()

func get_basic_heightmap():
	var heightmap = []
	for y in range(vertex_count):
		for x in range(vertex_count):
			var val = noise.get_noise_2d(x, y)
			if val > 0:
				pass
				#val = pow(val, $terrain_ui.power)

			heightmap.append(inverse_lerp(-1.0, 1.0,val))
	return heightmap

## == EROSION == ##

func erode(iterations = 1):
	
	if iterations > 10 :
		draw_debug = false
	
	for iteration in range(iterations):
		var pos_x = rand_range(0.0, vertex_count-1)
		var pos_y = rand_range(0.0, vertex_count-1)
		var dir = Vector2(0, 0)
		var speed = 1
		var water = 1
		var sediment = 0
		
		for lifetime in range(max_lifetime):
			var orig_x = pos_x
			var orig_y = pos_y

			# Get current height and gradients
			var h = get_gradient(pos_x, pos_y)
			var height = h.z
			var gradient_x = h.x
			var gradient_y = h.y
			
			# Calculate new position
			dir.x = (dir.x * inertia - gradient_x * (1 - inertia))
			dir.y = (dir.y * inertia - gradient_y * (1 - inertia))
			dir = dir.normalized()
			pos_x += dir.x
			pos_y += dir.y
			
			# Out of bounds
			if(pos_x < 0 or pos_y < 0 or pos_x > vertex_count-1 or pos_y > vertex_count-1):
				break
			
			var new_height = get_gradient(pos_x, pos_y).z
			var delta_height = new_height - height
			var sediment_capacity = max(-delta_height * speed * water * sediment_capacity_factor, min_sediment_capacity)
			
			if sediment > sediment_capacity or delta_height > 0 :
				# Drop
				var amount_to_deposit = min(delta_height, sediment) if delta_height > 0 else (sediment - sediment_capacity) * deposit_speed
				sediment -= amount_to_deposit
				deposit_sediment(orig_x, orig_y, amount_to_deposit)
			else :
				# Erode
				var amount_to_erode = min(-delta_height, (sediment_capacity - sediment) * erode_speed)
				sediment += amount_to_erode
				erode_sediment(orig_x, orig_y, amount_to_erode)
				
			speed = sqrt(speed * speed + delta_height * gravity)
			water -= 1 * evaporation
		
#		instantiate_marker_sphere(Vector2(pos_x, pos_y), Color(1, 0, 0))

func get_gradient(pos_x, pos_y):

	var coord_x = int(pos_x)
	var coord_y = int(pos_y)

	var offset_x = pos_x - coord_x
	var offset_y = pos_y - coord_y
	
	var i = coord_y * vertex_count + coord_x

	var se_height = heightmap[i]
	var so_height = heightmap[i+1]
	var ne_height = heightmap[i+vertex_count]
	var no_height = heightmap[i+vertex_count+1]
	
	var gradient_x = lerp(no_height, so_height, offset_y) - lerp(ne_height, se_height, offset_y)
	var gradient_y = lerp(ne_height, no_height, offset_x) - lerp(se_height, so_height, offset_x)

	var height = blerp(se_height, so_height, ne_height, no_height, offset_x, offset_y)
	return Vector3(gradient_x, gradient_y, height)

func deposit_sediment(pos_x, pos_y, amount_to_deposit):
	var coord_x = int(pos_x)
	var coord_y = int(pos_y)
	var i = coord_y * vertex_count + coord_x
	var offset_x = pos_x - coord_x
	var offset_y = pos_y - coord_y
	
#	heightmap[i] += amount_to_deposit * (1-offset_x) * (1-offset_y) 
#	heightmap[i + vertex_count] += amount_to_deposit * (1-offset_x) * (offset_y) 
#	heightmap[i + 1] += amount_to_deposit * (offset_x) * (1-offset_y) 
#	heightmap[i + vertex_count + 1] += amount_to_deposit * (offset_x) * (offset_y) 

	heightmap[i] += amount_to_deposit * (1-offset_x) * (1-offset_y) 
	heightmap[i + vertex_count] += amount_to_deposit * (1-offset_x) * (offset_y) 
	heightmap[i + 1] += amount_to_deposit * (offset_x) * (1-offset_y) 
	heightmap[i + vertex_count + 1] += amount_to_deposit * (offset_x) * (offset_y) 
	
	return amount_to_deposit

func erode_sediment(pos_x, pos_y, amount_to_erode):
	var sediment_grabbed = 0.0
	var i = int(pos_y) * vertex_count + int(pos_x)
	var all_weights = sum_of_weights[i]

	for j in brush_indexes[i]:
		var distance = Vector2(pos_x, pos_y).distance_to(linear_to_vector2(j))
		var weight = (1 - (distance/brush_radius))/all_weights
		var weighted_amount = amount_to_erode * weight
		var delta_sediment = heightmap[i] if heightmap[i] < weighted_amount else weighted_amount
		heightmap[i] -= delta_sediment
		sediment_grabbed += delta_sediment
	
	return sediment_grabbed

func init_erosion(radius):
	sum_of_weights = []
	brush_indexes = []
	for i in range(vertex_count * vertex_count):
		var position = linear_to_vector2(i)
		var total_weights = 0.0
		brush_indexes.append([])

		for y in range(int(max(position.y - radius-1, 0)), int(min(position.y + radius-1, vertex_count))):
			for x in range (int(max(position.x - radius-1, 0)), int(min(position.x + radius-1, vertex_count))):
				var distance = position.distance_to(Vector2(x, y))
				if distance > radius:
					continue
					
				brush_indexes[i].append(y * vertex_count + x)
				total_weights += 1 - (distance/radius)
		
		sum_of_weights.append(total_weights)

func instantiate_marker_sphere(position : Vector2, color : Color, scale = 0.2):
	if draw_debug:
		var mi = MeshInstance.new()
		mi.mesh = SphereMesh.new()
		
		var material = SpatialMaterial.new()
		material.albedo_color = color
		mi.material_override = material
		
		add_child(mi)
		var v = Vector3(position.x / vertex_count * map_scale, get_gradient(position.x, position.y).z * mesh_mult, position.y / vertex_count * map_scale)
		mi.translate(v)
		mi.scale_object_local(Vector3(scale, scale, scale))


## == TEXTURE == ##

func draw_texture():
	image = Image.new()
	image.create(vertex_count, vertex_count, false,  Image.FORMAT_RGB8)
	image.lock()
	for y in range(vertex_count):
		for x in range(vertex_count):
			var val = heightmap[y * vertex_count + x]

			if val <= $terrain_ui.water_level :
				image.set_pixel(x, y, water_color)
			elif val <= $terrain_ui.water_level + 0.05:
				image.set_pixel(x, y, sand_color)
			elif val <= 0.5 :
				image.set_pixel(x, y, grass_color)
			elif val <= 0.6:
				image.set_pixel(x, y, grass2_color)
			elif val <= 0.75 :
				image.set_pixel(x, y, mountain_color)
			elif val <= 0.9 :
				image.set_pixel(x, y, snow_color)
			#var color = Color(val, val, val)
			#image.set_pixel(x, y, color)
	image.unlock()
	var texture = ImageTexture.new()
	texture.create_from_image(image, 0)
	$map.texture = texture

	var mat = SpatialMaterial.new()
	mat.albedo_texture = $map.texture
	$mesh.material_override = mat

func draw_noise():
	image = Image.new()
	image.create(vertex_count, vertex_count, false,  Image.FORMAT_RGB8)
	image.lock()
	for y in range(vertex_count):
		for x in range(vertex_count):
			var val =  heightmap[y * vertex_count + x]
			var color = Color(val, val, val)
			image.set_pixel(x, y, color)
	image.unlock()
	var texture = ImageTexture.new()
	texture.create_from_image(image, 0)
	$map.texture = texture
	
	var mat = SpatialMaterial.new()
	mat.albedo_texture = $map.texture
	$mesh.material_override = mat

## == MESH == ##

func create_mesh():
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.add_smooth_group(true)
	for y in range(vertex_count-1):
		for x in range(vertex_count-1):
			add_quad(st, x, y)
	st.index()
	st.generate_normals()
	
	$mesh.mesh = st.commit()
	
func edit_mesh():
	var mdt = MeshDataTool.new()
	mdt.create_from_surface($mesh.mesh, 0)
	for i in range(mdt.get_vertex_count()):
		var v = mdt.get_vertex(i)
		var x = v.x / map_scale * vertex_count
		x = round(x)
		var y = v.z / map_scale * vertex_count
		y = round(y)
		
		var height = heightmap[y * vertex_count + x] * mesh_mult
		
		v.y = float(height)
		mdt.set_vertex(i, v)
	
	$mesh.mesh.surface_remove(0)
	mdt.commit_to_surface($mesh.mesh)

func add_quad(st, x, y):
	add_vert(st, x, y)
	add_vert(st, x+1, y)
	add_vert(st, x+1, y+1)

	add_vert(st, x, y)
	add_vert(st, x+1, y+1)
	add_vert(st, x, y+1)

func add_vert(st, x, y):
	var uv = Vector2(float(x)/vertex_count, float(y)/vertex_count)
	st.add_uv(uv)
	
	var i = y * vertex_count + x
	var height = heightmap[i] * mesh_mult
	st.add_vertex(Vector3(uv.x * map_scale, height, uv.y * map_scale))

func blerp(c00, c10, c01, c11, tx, ty):
	return lerp(lerp(c00, c10, tx), lerp(c01, c11, tx), ty)

func linear_to_vector2(position):
	return Vector2(position % vertex_count, position / vertex_count)

func vector2_to_linear(position : Vector2) -> int:
	return int(position.y) * vertex_count + int(position.x)

func coord_to_linear(x : int, y : int):
	return y * vertex_count + x

