extends RefCounted
class_name Texturas

# Fabrica de texturas y sprites. Si existe el PNG real en assets/ lo usa; si no,
# genera uno por codigo como respaldo, asi el juego corre sin depender de los
# assets. Para usar sprites reales basta dejarlos en assets/ con estos nombres:
#   assets/muros/pared1.png ... pared4.png   (paredes, idealmente 64x64)
#   assets/sprites/guardia.png, guardia_muerto.png, municion.png, botiquin.png,
#   tesoro.png, llave.png, arma.png, arma_disparo.png

const FILTRO_PIXEL := BaseMaterial3D.TEXTURE_FILTER_NEAREST

# ---------------------------------------------------------------- utilidades

# carga el png real si existe, si no devuelve null
static func _cargar_real(ruta: String) -> Texture2D:
	if ResourceLoader.exists(ruta):
		var t := load(ruta)
		if t is Texture2D:
			return t
	return null

static func _a_textura(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)

# carga un png de assets/ por nombre; si no esta, devuelve null (el que llama
# decide el fallback). sirve para los frames reales de wolfenstein.
static func cargar(carpeta: String, nombre: String) -> Texture2D:
	return _cargar_real("res://assets/%s/%s.png" % [carpeta, nombre])

# carga una lista de frames; corta en cuanto falta uno. devuelve [] si no hay
static func cargar_frames(carpeta: String, patron: String, desde: int, hasta: int) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	for i in range(desde, hasta + 1):
		var t := cargar(carpeta, patron % i)
		if t == null:
			break
		frames.append(t)
	return frames

# ------------------------------------------------------------------- paredes

# material listo para usar en una pared. indice elige la variante de textura.
static func material_pared(indice: int) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.texture_filter = FILTRO_PIXEL
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var real := _cargar_real("res://assets/muros/pared%d.png" % indice)
	mat.albedo_texture = real if real else _gen_pared(indice)
	mat.roughness = 1.0
	mat.metallic = 0.0
	return mat

static func _gen_pared(indice: int) -> ImageTexture:
	# paleta por variante para que se note el cambio de muro
	var paletas := [
		[Color(0.45, 0.18, 0.18), Color(0.30, 0.10, 0.10)], # rojo ladrillo
		[Color(0.30, 0.32, 0.38), Color(0.18, 0.19, 0.24)], # piedra azulada
		[Color(0.40, 0.36, 0.22), Color(0.26, 0.23, 0.13)], # piedra arena
		[Color(0.22, 0.34, 0.26), Color(0.13, 0.21, 0.16)], # verde musgo
	]
	var p = paletas[(indice - 1) % paletas.size()]
	var base: Color = p[0]
	var junta: Color = p[1]
	var s := 64
	var img := Image.create_empty(s, s, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = indice * 7919
	for y in s:
		var fila := y / 16
		var desfase := (fila % 2) * 16
		for x in s:
			var bx := (x + desfase) % 32
			var color: Color
			if (y % 16) < 3 or bx < 3:
				color = junta
			else:
				var ruido := rng.randf_range(-0.05, 0.05)
				color = base.lightened(ruido) if ruido > 0.0 else base.darkened(-ruido)
			# sombrita arriba de cada ladrillo para dar volumen
			if (y % 16) == 3:
				color = color.lightened(0.12)
			img.set_pixel(x, y, color)
	return _a_textura(img)

# textura de piso o techo (un color plano con grano fino)
static func material_plano(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.texture_filter = FILTRO_PIXEL
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var s := 32
	var img := Image.create_empty(s, s, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(color.r * 1000) + int(color.g * 100) + int(color.b * 10) + 1
	for y in s:
		for x in s:
			var d := rng.randf_range(-0.04, 0.04)
			img.set_pixel(x, y, color.lightened(d) if d > 0.0 else color.darkened(-d))
	mat.albedo_texture = _a_textura(img)
	mat.roughness = 1.0
	return mat

# material de puerta (madera con refuerzos)
static func material_puerta() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.texture_filter = FILTRO_PIXEL
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var real := _cargar_real("res://assets/muros/puerta.png")
	mat.albedo_texture = real if real else _gen_puerta()
	mat.roughness = 1.0
	return mat

static func _gen_puerta() -> ImageTexture:
	var s := 64
	var img := Image.create_empty(s, s, false, Image.FORMAT_RGBA8)
	var madera := Color(0.5, 0.36, 0.18)
	var metal := Color(0.55, 0.57, 0.62)
	img.fill(madera)
	for y in s:
		for x in s:
			# vetas verticales
			if (x % 8) == 0:
				img.set_pixel(x, y, madera.darkened(0.25))
			# marco metalico
			if x < 3 or x >= s - 3 or y < 3 or y >= s - 3:
				img.set_pixel(x, y, metal)
			# manija
			if x >= s - 14 and x <= s - 9 and y >= 28 and y <= 36:
				img.set_pixel(x, y, metal.lightened(0.2))
	return _a_textura(img)

# ------------------------------------------------------------------- sprites

# devuelve una Texture2D lista para un Sprite3D (enemigo, item, etc.)
static func sprite(nombre: String) -> Texture2D:
	var real := _cargar_real("res://assets/sprites/%s.png" % nombre)
	if real:
		return real
	match nombre:
		"guardia": return _gen_guardia(false)
		"guardia_muerto": return _gen_guardia(true)
		"municion": return _gen_municion()
		"botiquin": return _gen_botiquin()
		"tesoro": return _gen_tesoro()
		"llave": return _gen_llave()
		"arma": return _gen_arma(false)
		"arma_disparo": return _gen_arma(true)
	return _gen_tesoro()

# helper para pintar rectangulos en una imagen
static func _rect(img: Image, x0: int, y0: int, w: int, h: int, c: Color) -> void:
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, c)

static func _gen_guardia(muerto: bool) -> ImageTexture:
	var w := 32
	var h := 48
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var piel := Color(0.85, 0.68, 0.55)
	var uniforme := Color(0.25, 0.32, 0.30)
	var bota := Color(0.12, 0.12, 0.14)
	var arma := Color(0.2, 0.2, 0.22)
	if muerto:
		# guardia tirado: lo dibujo "acostado" achatado abajo
		_rect(img, 4, 38, 24, 8, uniforme)
		_rect(img, 6, 40, 6, 6, piel)        # cabeza
		_rect(img, 20, 41, 8, 4, bota)       # botas
		var sangre := Color(0.5, 0.05, 0.05)
		_rect(img, 2, 45, 28, 3, sangre)
	else:
		_rect(img, 11, 2, 10, 9, piel)       # cabeza
		_rect(img, 11, 2, 10, 2, bota)       # casco/pelo
		_rect(img, 14, 5, 2, 2, Color(0,0,0)) # ojos
		_rect(img, 17, 5, 2, 2, Color(0,0,0))
		_rect(img, 8, 11, 16, 20, uniforme)  # torso
		_rect(img, 4, 12, 5, 16, uniforme)   # brazo izq
		_rect(img, 23, 12, 5, 16, uniforme)  # brazo der
		_rect(img, 24, 18, 8, 4, arma)       # arma apuntando
		_rect(img, 10, 31, 5, 14, bota)      # pierna izq
		_rect(img, 17, 31, 5, 14, bota)      # pierna der
	return _a_textura(img)

static func _gen_municion() -> ImageTexture:
	var img := Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_rect(img, 6, 4, 12, 16, Color(0.55, 0.45, 0.15))  # caja
	_rect(img, 6, 4, 12, 3, Color(0.7, 0.58, 0.2))     # tapa
	for i in 3:
		_rect(img, 8 + i * 3, 8, 2, 10, Color(0.85, 0.75, 0.3)) # balas
	return _a_textura(img)

static func _gen_botiquin() -> ImageTexture:
	var img := Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_rect(img, 4, 6, 16, 12, Color(0.92, 0.92, 0.92))   # caja blanca
	_rect(img, 4, 6, 16, 2, Color(0.7, 0.7, 0.7))
	_rect(img, 10, 9, 4, 6, Color(0.85, 0.1, 0.1))      # cruz roja
	_rect(img, 8, 11, 8, 2, Color(0.85, 0.1, 0.1))
	return _a_textura(img)

static func _gen_tesoro() -> ImageTexture:
	var img := Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var oro := Color(0.95, 0.8, 0.15)
	# copa estilo wolfenstein
	_rect(img, 6, 4, 12, 3, oro)
	_rect(img, 8, 7, 8, 6, oro)
	_rect(img, 10, 13, 4, 4, oro.darkened(0.15))
	_rect(img, 7, 17, 10, 3, oro)
	_rect(img, 8, 5, 2, 6, oro.lightened(0.3))  # brillo
	return _a_textura(img)

static func _gen_llave() -> ImageTexture:
	var img := Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var dorado := Color(0.9, 0.75, 0.2)
	_rect(img, 5, 8, 8, 8, dorado)      # cabeza de la llave
	_rect(img, 7, 10, 4, 4, Color(0,0,0,0))
	_rect(img, 13, 11, 8, 2, dorado)    # cuerpo
	_rect(img, 18, 13, 2, 3, dorado)    # dientes
	return _a_textura(img)

static func _gen_arma(disparando: bool) -> ImageTexture:
	var img := Image.create_empty(96, 96, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var metal := Color(0.22, 0.22, 0.26)
	var mango := Color(0.35, 0.25, 0.15)
	# pistola centrada abajo
	_rect(img, 40, 40, 16, 40, metal)   # cañon/cuerpo
	_rect(img, 40, 60, 24, 30, mango)   # empuñadura
	_rect(img, 44, 30, 8, 14, metal)    # mira
	if disparando:
		var fuego := Color(1.0, 0.85, 0.2)
		_rect(img, 38, 18, 20, 16, fuego)
		_rect(img, 44, 10, 8, 10, Color(1.0, 1.0, 0.6))
	return _a_textura(img)
