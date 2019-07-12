tool
extends Spatial

## GENERATION ##
export var gen = false
export var regenerate = false
var noise : OpenSimplexNoise
var image : Image
export var graine : int
var _graine : int
export var quad_count = 100
export var map_size = 100.0

## EROSION ##
export var iterations : int

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
	print("====================================================")
	edit_mesh()

func _process(delta):
	if gen:
		gen = false
		generate()

func generate():
	noise = OpenSimplexNoise.new()
	_graine = graine
	noise.seed = graine
	noise.lacunarity = $terrain_ui.lacunarity
	noise.octaves = $terrain_ui.octaves
	noise.period = $terrain_ui.period * quad_count/map_size
	noise.persistence = $terrain_ui.persistence

	var time_before = OS.get_ticks_msec()
	heightmap = get_basic_heightmap()
	var time_after =  OS.get_ticks_msec()
	print("heightmap generated : " + str(time_after-time_before)+"ms")

	time_before = OS.get_ticks_msec()
	erode(iterations)
	time_after =  OS.get_ticks_msec()
	print("simulated erosion : " + str(time_after-time_before)+"ms")

#	draw_noise()

	if not $mesh.mesh or regenerate :
		time_before = OS.get_ticks_msec()
		create_mesh()
		time_after =  OS.get_ticks_msec()
		print("mesh created : " + str(time_after-time_before)+"ms")
	else :
		time_before = OS.get_ticks_msec()
		edit_mesh()
		time_after =  OS.get_ticks_msec()
		print("mesh modified : " + str(time_after-time_before)+"ms")

	time_before = OS.get_ticks_msec()
	draw_texture()
	time_after =  OS.get_ticks_msec()
	print("created texture : "+str(time_after-time_before)+"ms")


func get_basic_heightmap():
	var heightmap = []
	for x in range(quad_count+1):
		for y in range(quad_count+1):
			var val = noise.get_noise_2d(x, y)
			if val > 0:
				pass
				#val = pow(val, $terrain_ui.power)

			heightmap.append(inverse_lerp(-1.0, 1.0,val))
	return heightmap

func erode(iterations = 1):
	var min_slope = -0.01
	var max_lifetime = 15
	var start_speed = 1.0
	var start_water = 1.0
	var inertia = 0.05
	var evaporation = 0.01
	var erosion = 0.3
	var deposition = 0.3
	var gravity = 4.0
	var capacity_factor = 4.0

	var radius = 3

	var max_g = 0
	var max_d = 0

	for i in range(iterations):
		var position = Vector2(rand_range(0.0, quad_count), rand_range(0.0, quad_count))
		var speed = start_speed
		var movement : Vector2
		var water = start_water
		var sediment = 0.0
		
#		print (position)
		
		for lifetime in range(max_lifetime):
			var h = get_gradient(position)
			var gradient = Vector2(h.x, h.y)
			var height = h.z
			movement.x = movement.x * inertia - gradient.x * (1 - inertia)
			movement.y = movement.y * inertia - gradient.y * (1 - inertia)

			position += movement.normalized()
			
#			print("moving " + str(movement.normalized()))
			
			if position.x < 0 or position.y < 0 or position.x > quad_count - 1 or position.y > quad_count - 1:
				break

			var new_height = get_gradient(position).z
			var delta = new_height - height
#			print(str(delta))
			if delta < -1 or delta > 1 :
				breakpoint
				
			var carry_capacity = max(-delta * speed * water * capacity_factor, 0.001)
			
#			print("sed "+ str(sediment) + "/" + str( carry_capacity))
			
			if delta > 0 or sediment > carry_capacity :
				
				var x = position.x - int(position.x)
				var y = position.y - int(position.y)
				var amount_to_drop = 0
				if delta > 0:
					amount_to_drop = min(abs(delta), sediment)
				else:
					amount_to_drop = (sediment - carry_capacity) * deposition

				if amount_to_drop < -0.00001:
					breakpoint
				if amount_to_drop > max_d:
					max_d = amount_to_drop

				heightmap[vector2_to_linear(position)] += amount_to_drop * x * y
				heightmap[coord_to_linear(position.x, position.y + 1)] += amount_to_drop * x * (1-y)
				heightmap[coord_to_linear(position.x+1, position.y)] += amount_to_drop * (1-x) * y
				heightmap[coord_to_linear(position.x+1, position.y + 1)] += amount_to_drop * (1-x) * (1-y)
				sediment -= amount_to_drop
				
#				print("dropped " + str(amount_to_drop) +" at " + str(position))
				
			else : # Moving downhill
				
				var amount_to_grab = min((carry_capacity-sediment) * erosion, -delta)
				sediment += grab_sediment(position, radius, amount_to_grab)
#				print("grabbed " + str(amount_to_grab) + " from " + str(position))
				if amount_to_grab < 0:
					breakpoint
				if amount_to_grab > max_g:
					max_g = amount_to_grab
			speed = sqrt( speed * speed + gravity * delta)
			water *= (1 - evaporation)
#			print("===")

#	print ("g : " + str(max_g))
#	print ("d : " + str(max_d))

func get_gradient(position : Vector2):

	var coord_x = int(position.x)
	var coord_y = int(position.y)

	var x = position.x - coord_x
	var y = position.y - coord_y

	var no_height = heightmap[coord_to_linear(coord_x, coord_y+1)]
	#print_debug("no height : " + str(no_height))
	var ne_height = heightmap[coord_to_linear(coord_x+1, coord_y+1)]
	#print_debug("ne height : " + str(ne_height))
	var so_height = heightmap[coord_to_linear(coord_x, coord_y)]
	#print_debug("so height : " + str(so_height))
	var se_height = heightmap[coord_to_linear(coord_x+1, coord_y)]
	#print_debug("se height : " + str(se_height))
	# hauteur de x+ moins hauteur de x-
	# pour trouver la hauteur de x+ = moyenne de NE et SE ; x- NO et SE

	var height_x_pos = (ne_height + se_height ) / 2.0
	var height_x_neg = (no_height + so_height ) / 2.0
	var gradient_x = lerp(se_height, ne_height, y) - lerp(so_height, no_height, y)
	#print_debug("grad x : " + str(gradient_x))
	var height_y_pos = (no_height + ne_height ) / 2.0
	var height_y_neg = (so_height + se_height ) / 2.0
	var gradient_y = lerp(so_height, se_height, x) - lerp(no_height, ne_height, x)
	#print_debug("grad y : " + str(gradient_y))

	var height = no_height * (1-x) * y + ne_height * (1-x) * (1-y) + so_height * x * y + se_height * x * (1-y)
	#print(height)
	return Vector3(gradient_x, gradient_y, height)

func grab_sediment(position, radius, amount_to_grab):
	var sediment_grabbed = 0.0
	var all_weights = get_sum_of_weights(position, radius)
	for x in range(int(max(position.x - radius, 0)), int(min(position.x + radius, quad_count))):
		for y in range (int(max(position.y - radius, 0)), int(min(position.y + radius, quad_count))):
			var distance = position.distance_to(Vector2(x, y))
			if distance > radius:
				continue
			var weight = max(0, radius - distance)/all_weights
			var amount_to_erode = amount_to_grab * weight
			heightmap[coord_to_linear(x,y)] -= amount_to_erode
			if heightmap[coord_to_linear(x,y)] < 0:
				heightmap[coord_to_linear(x,y)] = 0
				breakpoint
			sediment_grabbed += amount_to_erode
	return sediment_grabbed

func get_sum_of_weights(position, radius):
	var total_weights = 0.0
	for x in range(int(max(position.x - radius, 0)), int(min(position.x + radius, quad_count))):
		for y in range (int(max(position.y - radius, 0)), int(min(position.y + radius, quad_count))):
			var distance = position.distance_to(Vector2(x, y))
			if distance > radius:
				continue
			total_weights += max(0, radius - distance)
	return total_weights

func get_adjacent_tiles(position):
	var ret = []
	if position.x > 0:
		ret.append(Vector2(position.x - 1, position.y))
	if position.x < quad_count - 1:
		ret.append(Vector2(position.x + 1, position.y))
	if position.y > 0 :
		ret.append(Vector2(position.x, position.y - 1))
	if position.y < quad_count - 1:
		ret.append(Vector2(position.x, position.y + 1))

	if position.x > 0 and position.y > 0 :
		ret.append(Vector2(position.x - 1, position.y - 1))
	if position.x < quad_count - 1 and position.y > 0 :
		ret.append(Vector2(position.x + 1, position.y - 1))
	if position.x > 0 and position.y < quad_count - 1 :
		ret.append(Vector2(position.x - 1, position.y + 1))
	if position.x < quad_count - 1 and position.y < quad_count - 1 :
		ret.append(Vector2(position.x + 1, position.y + 1))

	return ret

func draw_texture():
	image = Image.new()
	image.create(quad_count, quad_count, false,  Image.FORMAT_RGB8)
	image.lock()
	for x in range(quad_count):
		for y in range(quad_count):
			#var val = inverse_lerp(-1, 1, noise.get_noise_2d(x, y))
			var val = heightmap[coord_to_linear(x,y)]

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
	image.create(quad_count, quad_count, false,  Image.FORMAT_RGB8)
	image.lock()
	for x in range(quad_count):
		for y in range(quad_count):
			var val =  heightmap[coord_to_linear(x,y)]
			var color = Color(val, val, val)
			image.set_pixel(x, y, color)
	image.unlock()
	var texture = ImageTexture.new()
	texture.create_from_image(image, 0)
	$map.texture = texture

func create_mesh():
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.add_smooth_group(true)
	for x in range(quad_count):
		for y in range(quad_count):
			add_quad(st, x, y)
	st.index()
	st.generate_normals()
	
	$mesh.mesh = st.commit()
	
func edit_mesh():
	var mdt = MeshDataTool.new()
	mdt.create_from_surface($mesh.mesh, 0)
	for i in range(mdt.get_vertex_count()):
		var v = mdt.get_vertex(i)
		var x = v.x / map_size * (quad_count-1)
		x = round(x)
		var y = v.z / map_size * (quad_count-1)
		y = round(y)
		
		var height = heightmap[coord_to_linear(x,y)] * mesh_mult
		
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
	var uv = Vector2(float(x)/(quad_count-1), float(y)/(quad_count-1))
	st.add_uv(uv)
	
	var i = coord_to_linear(x,y)
	var height = heightmap[i] * mesh_mult
	st.add_vertex(Vector3(uv.x * map_size, height, uv.y * map_size))
	#print(str(x) + " " + str(y) + " " + str(height))


#func linear_to_vector2(position : int):
#	return Vector2(position % (quad_count+1), position / quad_count+1)

func vector2_to_linear(position : Vector2) -> int:
	return int(position.x) * (quad_count+1) + int(position.y)

func coord_to_linear(x : int, y : int):
	return int(x) * (quad_count+1) + int(y)
