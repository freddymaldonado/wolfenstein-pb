extends CharacterBody3D
class_name Enemigo

# Enemigo dibujado como un sprite billboard, al estilo del Wolfenstein original.
# Empieza dormido y, al detectar al jugador (distancia + linea de vista), lo
# persigue y dispara. Las stats son variables para que el jefe las reutilice.

signal murio

# stats configurables antes de add_child (el jefe las ajusta)
var velocidad := 3.3
var radio_deteccion := 20.0
var rango_ataque := 16.0
var dist_parada := 5.5           # distancia a la que se planta a disparar
var intervalo_ataque := 1.4
var dano := 9
var prob_acierto := 0.65
var prefijo := "guardia"         # familia de sprites: guardia_* o jefe_*
var pixel_size := 0.028
var puntos := 0                  # puntaje que otorga al morir
var es_jefe := false
var vida := 100
var vida_max := 100

var vivo := true
var alerta := false
var jugador: Jugador
var _sprite: Sprite3D
var _cooldown_ataque := 0.0
var _ultima_pos_conocida := Vector3.ZERO
var _tiene_objetivo := false
var _barra: Sprite3D             # barra de vida flotante (solo jefe)
var _barra_fondo: Sprite3D

var _idle: Texture2D
var _walk: Array[Texture2D] = []
var _shoot: Array[Texture2D] = []
var _pain: Texture2D
var _die: Array[Texture2D] = []
var _t_anim := 0.0
var _t_shoot := 0.0
var _t_pain := 0.0
var _muriendo := false
var _t_die := 0.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.55 if es_jefe else 0.35
	capsula.height = 2.2 if es_jefe else 1.4
	forma.shape = capsula
	add_child(forma)

	_cargar_animacion()

	_sprite = Sprite3D.new()
	_sprite.texture = _idle
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.shaded = false
	_sprite.pixel_size = pixel_size
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.position = Vector3(0, 0.82 if es_jefe else 0.4, 0)
	add_child(_sprite)

	if es_jefe:
		_crear_barra_vida()

# carga los frames reales; si falta alguno usa el sprite generado de respaldo
func _cargar_animacion() -> void:
	_idle = Texturas.cargar("sprites", prefijo + "_idle")
	if _idle == null:
		_idle = Texturas.sprite("guardia")
	_walk = Texturas.cargar_frames("sprites", prefijo + "_walk%d", 1, 4)
	_shoot = Texturas.cargar_frames("sprites", prefijo + "_shoot%d", 1, 3)
	_pain = Texturas.cargar("sprites", prefijo + "_pain")
	_die = Texturas.cargar_frames("sprites", prefijo + "_die%d", 1, 7)
	if _die.is_empty():
		_die = [Texturas.sprite("guardia_muerto")]

# barra de vida roja flotando sobre la cabeza del jefe
func _crear_barra_vida() -> void:
	_barra_fondo = Sprite3D.new()
	_barra_fondo.texture = ImageTexture.create_from_image(_img_color(Color(0.1, 0.0, 0.0)))
	_barra_fondo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_barra_fondo.shaded = false
	_barra_fondo.pixel_size = 0.02
	_barra_fondo.position = Vector3(0, 2.7, 0)
	_barra_fondo.no_depth_test = true
	add_child(_barra_fondo)

	_barra = Sprite3D.new()
	_barra.texture = ImageTexture.create_from_image(_img_color(Color(0.85, 0.1, 0.1)))
	_barra.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_barra.shaded = false
	_barra.pixel_size = 0.02
	_barra.position = Vector3(0, 2.7, 0.001)
	_barra.no_depth_test = true
	add_child(_barra)
	_actualizar_barra()

func _img_color(c: Color) -> Image:
	var img := Image.create(100, 8, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return img

func _actualizar_barra() -> void:
	if _barra == null:
		return
	var frac := clampf(float(vida) / float(vida_max), 0.0, 1.0)
	_barra.scale = Vector3(frac, 1.0, 1.0)
	_barra.position.x = -(1.0 - frac) * 100.0 * 0.02 * 0.5

func _physics_process(delta: float) -> void:
	_t_anim += delta
	if not vivo:
		_animar_muerte(delta)
		return
	_cooldown_ataque = maxf(0.0, _cooldown_ataque - delta)
	_t_shoot = maxf(0.0, _t_shoot - delta)
	_t_pain = maxf(0.0, _t_pain - delta)
	if jugador == null or not jugador.vivo:
		velocity = Vector3.ZERO
		_actualizar_sprite(false)
		return

	var hacia := jugador.global_position - global_position
	hacia.y = 0.0
	var dist := hacia.length()
	var ve := _hay_linea_de_vista(dist)

	# se despierta cuando estas cerca y te puede ver
	if not alerta and dist <= radio_deteccion and ve:
		alerta = true

	if not alerta:
		velocity = Vector3.ZERO
		_actualizar_sprite(false)
		return

	# si lo ve, recuerda su posicion y lo persigue; si lo pierde, va hasta el
	# ultimo punto donde lo vio antes de rendirse
	if ve:
		_ultima_pos_conocida = jugador.global_position
		_tiene_objetivo = true

	var objetivo := jugador.global_position if ve else _ultima_pos_conocida
	var hacia_obj := objetivo - global_position
	hacia_obj.y = 0.0
	var dist_obj := hacia_obj.length()

	var moviendose := false
	# se acerca hasta dist_parada y ahi se planta para disparar
	if _tiene_objetivo and dist_obj > dist_parada:
		var dir := _direccion_navegacion(hacia_obj)
		velocity.x = dir.x * velocidad
		velocity.z = dir.z * velocidad
		moviendose = true
		# llego al ultimo punto conocido y no hay nadie: deja de perseguir
		if not ve and dist_obj <= 1.2:
			_tiene_objetivo = false
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	velocity.y = 0.0
	move_and_slide()

	# dispara si lo ve y esta en rango, incluso mientras se acerca
	if ve and dist <= rango_ataque and _cooldown_ataque == 0.0:
		_atacar()
	_actualizar_sprite(moviendose)

# elige el frame segun el estado: dolor > disparo > caminar > idle
func _actualizar_sprite(moviendose: bool) -> void:
	if _t_pain > 0.0 and _pain:
		_sprite.texture = _pain
	elif _t_shoot > 0.0 and not _shoot.is_empty():
		var idx := int((intervalo_ataque * 0.5 - _t_shoot) * 12.0)
		_sprite.texture = _shoot[clampi(idx, 0, _shoot.size() - 1)]
	elif moviendose and not _walk.is_empty():
		var f := int(_t_anim * 6.0) % _walk.size()
		_sprite.texture = _walk[f]
	else:
		_sprite.texture = _idle

func _atacar() -> void:
	_cooldown_ataque = intervalo_ataque
	_t_shoot = intervalo_ataque * 0.5
	if randf() <= prob_acierto:
		jugador.recibir_dano(dano)

# busca una direccion libre hacia el objetivo: si el frente esta tapado, prueba
# desviarse en abanico hacia los lados y toma el primer camino despejado. Es una
# evasion simple, sin pathfinding, pero alcanza para rodear pilares y esquinas.
func _direccion_navegacion(hacia_obj: Vector3) -> Vector3:
	var dir := hacia_obj.normalized()
	if _camino_libre(dir, 2.0):
		return dir
	for ang in [35.0, -35.0, 65.0, -65.0, 95.0, -95.0, 130.0, -130.0]:
		var d := dir.rotated(Vector3.UP, deg_to_rad(ang))
		if _camino_libre(d, 1.7):
			return d
	return dir

# true si no hay pared en los proximos 'largo' metros en esa direccion
func _camino_libre(dir: Vector3, largo: float) -> bool:
	var espacio := get_world_3d().direct_space_state
	var origen := global_position + Vector3(0, 0.4, 0)
	var destino := origen + dir * largo
	var consulta := PhysicsRayQueryParameters3D.create(origen, destino, 1, [get_rid()])
	return espacio.intersect_ray(consulta).is_empty()

# true si no hay ninguna pared entre el enemigo y el jugador
func _hay_linea_de_vista(dist: float) -> bool:
	var espacio := get_world_3d().direct_space_state
	var origen := global_position + Vector3(0, 0.4, 0)
	var destino := jugador.global_position + Vector3(0, 0.4, 0)
	var consulta := PhysicsRayQueryParameters3D.create(origen, destino, 1, [get_rid()])
	var golpe := espacio.intersect_ray(consulta)
	if golpe.is_empty():
		return true
	return origen.distance_to(golpe.position) >= dist - 0.6

func recibir_dano(cantidad: int) -> void:
	if not vivo:
		return
	vida -= cantidad
	alerta = true
	_t_pain = 0.18
	_actualizar_barra()
	if vida <= 0:
		_morir()

func _morir() -> void:
	vivo = false
	velocity = Vector3.ZERO
	_muriendo = true
	_t_die = 0.0
	# deja de bloquear y de recibir disparos
	collision_layer = 0
	collision_mask = 0
	for hijo in get_children():
		if hijo is CollisionShape3D:
			hijo.disabled = true
	if _barra:
		_barra.visible = false
		_barra_fondo.visible = false
	if puntos > 0 and jugador:
		jugador.puntaje += puntos
		jugador.estado_cambiado.emit()
	murio.emit()

# recorre los frames de muerte y deja el ultimo en el piso
func _animar_muerte(delta: float) -> void:
	if not _muriendo:
		return
	_t_die += delta
	var idx := int(_t_die * 12.0)
	if idx >= _die.size():
		idx = _die.size() - 1
		_muriendo = false
		_sprite.position = Vector3(0, 0.0 if es_jefe else -0.35, 0)
	_sprite.texture = _die[idx]
