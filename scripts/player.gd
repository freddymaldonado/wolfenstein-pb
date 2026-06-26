extends CharacterBody3D
class_name Jugador

# Jugador en primera persona estilo Wolfenstein: movimiento plano, mouse look y
# disparo por hitscan. La vida, municion y puntaje viven aca y el HUD los lee.

signal murio
signal estado_cambiado            # algo cambio (vida, balas, puntaje)
signal disparo_hecho              # el HUD muestra el fogonazo
signal dano_recibido              # dispara el flash rojo de pantalla
signal arma_cambiada              # el HUD actualiza el sprite del arma

# velocidad y sensibilidad se ajustan desde el menu, por eso son var
var velocidad := 7.6
var velocidad_correr := 10.0
var sensibilidad := 0.0025
const ALCANCE_DISPARO := 40.0

# las dos armas comparten la misma municion. cadencia mas baja = mas rapida
const ARMAS := [
	{"nombre": "PISTOLA", "cadencia": 0.15, "dano": 32, "auto": true, "sprite": "pistola", "frames": 6},
	{"nombre": "METRALLETA", "cadencia": 0.07, "dano": 20, "auto": true, "sprite": "metralleta", "frames": 5},
]

var vida_max := 100
var vida := 100
var municion := 20
var municion_max := 99
var puntaje := 0
var llaves := 0
var tesoros := 0
var vivo := true
var arma_actual := 0              # indice en ARMAS

var _cooldown := 0.0
var _disparando := false          # true mientras se mantiene el click
var camara: Camera3D

func _ready() -> void:
	# armo el cuerpo: capsula de colision + camara a la altura de los ojos
	collision_layer = 2
	collision_mask = 1
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.3
	capsula.height = 1.4
	forma.shape = capsula
	add_child(forma)

	camara = Camera3D.new()
	camara.position = Vector3(0, 0.55, 0)
	camara.fov = 75.0
	add_child(camara)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(evento: InputEvent) -> void:
	if not vivo:
		return
	if evento is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-evento.relative.x * sensibilidad)
		camara.rotate_x(-evento.relative.y * sensibilidad)
		# no dejo que la camara de la vuelta hacia arriba/abajo
		camara.rotation.x = clampf(camara.rotation.x, -1.2, 1.2)
	elif evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT:
		# el disparo real ocurre en _physics_process
		_disparando = evento.pressed
	elif evento is InputEventMouseButton and evento.pressed:
		# rueda del mouse cambia de arma
		if evento.button_index == MOUSE_BUTTON_WHEEL_UP:
			cambiar_arma(arma_actual - 1)
		elif evento.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cambiar_arma(arma_actual + 1)
	elif evento is InputEventKey and evento.pressed and not evento.echo:
		if evento.keycode == KEY_1:
			cambiar_arma(0)
		elif evento.keycode == KEY_2:
			cambiar_arma(1)
		elif evento.keycode == KEY_Q:
			cambiar_arma(arma_actual + 1)

func cambiar_arma(indice: int) -> void:
	var n := ARMAS.size()
	indice = ((indice % n) + n) % n        # envuelve dentro del rango
	if indice == arma_actual:
		return
	arma_actual = indice
	arma_cambiada.emit()
	estado_cambiado.emit()

func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if not vivo:
		velocity = Vector3.ZERO
		return

	# disparo sostenido: mientras el gatillo este apretado y el arma lo permita
	if _disparando:
		disparar()

	var entrada := Vector3.ZERO
	var adelante := -transform.basis.z
	var derecha := transform.basis.x
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		entrada += adelante
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		entrada -= adelante
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		entrada -= derecha
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		entrada += derecha
	entrada.y = 0.0
	entrada = entrada.normalized()

	var vel := velocidad
	if Input.is_physical_key_pressed(KEY_SHIFT):
		vel = velocidad_correr
	velocity.x = entrada.x * vel
	velocity.z = entrada.z * vel
	velocity.y = 0.0
	move_and_slide()

func disparar() -> void:
	if _cooldown > 0.0 or not vivo:
		return
	if municion <= 0:
		return
	var arma: Dictionary = ARMAS[arma_actual]
	municion -= 1
	_cooldown = arma["cadencia"]
	disparo_hecho.emit()
	estado_cambiado.emit()

	# rayo desde el centro de la camara hacia adelante
	var espacio := get_world_3d().direct_space_state
	var origen := camara.global_position
	var destino := origen + (-camara.global_transform.basis.z) * ALCANCE_DISPARO
	var consulta := PhysicsRayQueryParameters3D.create(origen, destino, 1 | 4, [get_rid()])
	consulta.collide_with_areas = false
	var golpe := espacio.intersect_ray(consulta)
	if golpe.has("collider"):
		var obj = golpe.collider
		if obj is Enemigo:
			obj.recibir_dano(arma["dano"])

func recibir_dano(cantidad: int) -> void:
	if not vivo:
		return
	vida = maxi(0, vida - cantidad)
	estado_cambiado.emit()
	dano_recibido.emit()
	if vida == 0:
		vivo = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		murio.emit()

func curar(cantidad: int) -> void:
	vida = mini(vida_max, vida + cantidad)
	estado_cambiado.emit()

func agregar_municion(cantidad: int) -> void:
	municion = mini(municion_max, municion + cantidad)
	estado_cambiado.emit()

func agregar_tesoro(valor: int) -> void:
	puntaje += valor
	tesoros += 1
	estado_cambiado.emit()

func agregar_llave() -> void:
	llaves += 1
	estado_cambiado.emit()

# datos del arma equipada, para que el hud arme su sprite
func arma_info() -> Dictionary:
	return ARMAS[arma_actual]

# corta el disparo sostenido (lo usa el menu al pausar para que no quede tirando)
func detener_disparo() -> void:
	_disparando = false
