extends Node3D
class_name Juego

# Controlador principal. Lee el mapa de texto y arma todo el mundo 3D por codigo
# (piso, techo, paredes, puertas, enemigos, items y salida), gestiona el HUD, el
# menu, la progresion de niveles y los estados de ganar / perder / reiniciar.

const CELDA := 3.0                # tamaño de cada celda en metros
const ALTO := 3.0                 # altura de las paredes
const NIVELES := ["res://mapas/e1.map", "res://mapas/e2.map"]   # el ultimo tiene al jefe

var mapa: Mapa
var jugador: Jugador
var hud: Hud
var menu: MenuPausa
var mundo: Node3D                 # contenedor del nivel actual (se reconstruye)
var nivel_actual := 0
var total_tesoros := 0
var enemigos_vivos := 0
var termino := false
var _puertas_pendientes: Array[Puerta] = []

func _ready() -> void:
	_armar_ambiente()
	_crear_jugador()
	_crear_hud()
	_crear_menu()
	_cargar_nivel(0)

# arma (o rearma) un nivel: libera el mundo anterior y construye el nuevo.
# el jugador, hud y menu persisten entre niveles, solo cambia el escenario.
func _cargar_nivel(indice: int) -> void:
	nivel_actual = indice
	mapa = Mapa.cargar(NIVELES[indice])
	if mapa == null:
		push_error("No se pudo cargar el mapa: %s" % NIVELES[indice])
		return

	if mundo:
		mundo.queue_free()
	mundo = Node3D.new()
	mundo.name = "Mundo"
	add_child(mundo)

	total_tesoros = 0
	enemigos_vivos = 0
	termino = false
	_puertas_pendientes.clear()

	_armar_piso_techo()
	_armar_paredes()
	_armar_puertas()
	_armar_salida()
	_colocar_jugador()
	_crear_enemigos()
	_crear_jefes()
	_crear_items()

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if hud:
		hud.mostrar_mensaje("", Color.WHITE)
		if nivel_actual > 0:
			hud.mostrar_aviso("NIVEL %d" % (nivel_actual + 1))

func _es_ultimo_nivel() -> bool:
	return nivel_actual >= NIVELES.size() - 1

func _unhandled_input(evento: InputEvent) -> void:
	# R reinicia, pero solo durante el juego (en pausa lo maneja el menu)
	if termino and evento is InputEventKey and evento.pressed and not evento.echo:
		if evento.keycode == KEY_R:
			get_tree().reload_current_scene()

# ---------------------------------------------------------------- construccion

func _armar_ambiente() -> void:
	# un poco de niebla oscura para dar profundidad de mazmorra
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.03)
	env.fog_enabled = true
	env.fog_light_color = Color(0.02, 0.02, 0.03)
	env.fog_density = 0.018
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 1.0
	we.environment = env
	add_child(we)

func _centro(longitud: int) -> float:
	return (longitud - 1) * CELDA * 0.5

func _armar_piso_techo() -> void:
	var ancho_m := mapa.ancho * CELDA
	var alto_m := mapa.alto * CELDA
	var cx := _centro(mapa.ancho)
	var cz := _centro(mapa.alto)

	var piso := MeshInstance3D.new()
	var plano_p := PlaneMesh.new()
	plano_p.size = Vector2(ancho_m, alto_m)
	piso.mesh = plano_p
	piso.material_override = Texturas.material_plano(Color(0.18, 0.16, 0.16))
	piso.position = Vector3(cx, 0, cz)
	mundo.add_child(piso)

	var techo := MeshInstance3D.new()
	var plano_t := PlaneMesh.new()
	plano_t.size = Vector2(ancho_m, alto_m)
	techo.mesh = plano_t
	techo.material_override = Texturas.material_plano(Color(0.10, 0.10, 0.13))
	techo.position = Vector3(cx, ALTO, cz)
	techo.rotation_degrees = Vector3(180, 0, 0)   # que mire hacia abajo
	mundo.add_child(techo)

func _armar_paredes() -> void:
	var cuerpo := StaticBody3D.new()
	cuerpo.collision_layer = 1
	cuerpo.collision_mask = 0
	cuerpo.name = "Muros"
	mundo.add_child(cuerpo)

	# un MeshInstance por celda de pared, con su variante de textura
	var materiales := {}   # cache de materiales por variante
	for fila in mapa.alto:
		for col in mapa.ancho:
			if not mapa.es_pared(col, fila):
				continue
			var variante := mapa.variante_en(col, fila)
			if not materiales.has(variante):
				materiales[variante] = Texturas.material_pared(variante)
			var pos := Vector3(col * CELDA, ALTO * 0.5, fila * CELDA)

			var malla := MeshInstance3D.new()
			var caja := BoxMesh.new()
			caja.size = Vector3(CELDA, ALTO, CELDA)
			malla.mesh = caja
			malla.material_override = materiales[variante]
			malla.position = pos
			mundo.add_child(malla)

			var col_forma := CollisionShape3D.new()
			var forma := BoxShape3D.new()
			forma.size = Vector3(CELDA, ALTO, CELDA)
			col_forma.shape = forma
			col_forma.position = pos
			cuerpo.add_child(col_forma)

func _armar_puertas() -> void:
	var material := Texturas.material_puerta()
	for celda in mapa.puertas:
		var p := Puerta.new()
		p.collision_layer = 1
		p.collision_mask = 0
		p.position = Vector3(celda.x * CELDA, 0, celda.y * CELDA)
		p.configurar(CELDA, material)
		mundo.add_child(p)
		# el jugador se asigna despues de crearlo
		_puertas_pendientes.append(p)

func _armar_salida() -> void:
	if mapa.salida.x < 0:
		return
	var pos := Vector3(mapa.salida.x * CELDA, 0, mapa.salida.y * CELDA)

	# marca visual: un cartel SALIDA flotando y un piso verde brillante
	var cartel := Label3D.new()
	cartel.text = "SALIDA"
	cartel.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	cartel.modulate = Color(0.3, 1.0, 0.4)
	cartel.outline_modulate = Color(0, 0, 0)
	cartel.outline_size = 8
	cartel.font_size = 64
	cartel.pixel_size = 0.01
	cartel.position = pos + Vector3(0, 1.6, 0)
	mundo.add_child(cartel)

	var brillo := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(CELDA, CELDA)
	brillo.mesh = plano
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.2, 0.8, 0.3)
	brillo.material_override = m
	brillo.position = pos + Vector3(0, 0.02, 0)
	mundo.add_child(brillo)

	var area := Area3D.new()
	area.monitoring = true
	area.collision_layer = 0
	area.collision_mask = 2
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(CELDA, ALTO, CELDA)
	forma.shape = caja
	forma.position = Vector3(0, ALTO * 0.5, 0)
	area.add_child(forma)
	area.position = pos
	area.body_entered.connect(_al_llegar_salida)
	mundo.add_child(area)

# ------------------------------------------------------------------- entidades

# crea al jugador una sola vez; entre niveles solo se reposiciona
func _crear_jugador() -> void:
	jugador = Jugador.new()
	jugador.name = "Jugador"
	add_child(jugador)
	jugador.murio.connect(_al_morir_jugador)

# lo lleva al inicio del nivel actual y reengancha las puertas nuevas
func _colocar_jugador() -> void:
	jugador.position = Vector3(mapa.inicio_jugador.x * CELDA, 0.9, mapa.inicio_jugador.y * CELDA)
	jugador.rotation.y = mapa.angulo_jugador
	jugador.velocity = Vector3.ZERO
	for p in _puertas_pendientes:
		p.jugador = jugador

func _crear_enemigos() -> void:
	for celda in mapa.guardias:
		var e := Enemigo.new()
		e.position = Vector3(celda.x * CELDA, 0.8, celda.y * CELDA)
		e.jugador = jugador
		e.puntos = 100
		mundo.add_child(e)
		e.murio.connect(_al_morir_enemigo)
		enemigos_vivos += 1

# el jefe final: mucha vida, mas grande, pega mas fuerte y mas seguido
func _crear_jefes() -> void:
	for celda in mapa.jefes:
		var j := Enemigo.new()
		j.es_jefe = true
		j.prefijo = "jefe"
		j.vida = 800
		j.vida_max = 800
		j.velocidad = 3.6
		j.dano = 18
		j.intervalo_ataque = 0.85
		j.prob_acierto = 0.8
		j.rango_ataque = 24.0
		j.dist_parada = 8.0
		j.radio_deteccion = 34.0
		j.pixel_size = 0.052
		j.puntos = 5000
		j.position = Vector3(celda.x * CELDA, 1.0, celda.y * CELDA)
		j.jugador = jugador
		mundo.add_child(j)
		j.murio.connect(_al_morir_jefe)
		enemigos_vivos += 1

func _crear_items() -> void:
	for it in mapa.items:
		var celda: Vector2i = it["pos"]
		var p := Pickup.new()
		p.tipo = it["tipo"]
		p.position = Vector3(celda.x * CELDA, 0.6, celda.y * CELDA)
		mundo.add_child(p)
		if it["tipo"] == "tesoro":
			total_tesoros += 1

func _crear_hud() -> void:
	hud = Hud.new()
	add_child(hud)
	hud.configurar(jugador)
	jugador.dano_recibido.connect(hud.dano_recibido)

func _crear_menu() -> void:
	menu = MenuPausa.new()
	menu.configurar(jugador)   # seteo el jugador antes de entrar al arbol
	add_child(menu)

# --------------------------------------------------------------------- estados

func _al_morir_enemigo() -> void:
	enemigos_vivos = maxi(0, enemigos_vivos - 1)

func _al_morir_jefe() -> void:
	enemigos_vivos = maxi(0, enemigos_vivos - 1)
	if termino:
		return
	termino = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var texto := "¡DERROTASTE A HITLER!\n\nPuntaje %d   Tesoros %d/%d\n\nR para jugar de nuevo" % [
		jugador.puntaje, jugador.tesoros, total_tesoros]
	hud.mostrar_mensaje(texto, Color(0.95, 0.85, 0.3))

func _al_morir_jugador() -> void:
	if termino:
		return
	termino = true
	hud.mostrar_mensaje("MORISTE\n\nR para reintentar", Color(0.9, 0.2, 0.2))

func _al_llegar_salida(cuerpo: Node) -> void:
	if termino or not (cuerpo is Jugador):
		return
	# si quedan mas niveles, avanza; si es el ultimo, la salida solo abre
	# tras vencer al jefe (en el nivel del jefe se gana matandolo)
	if not _es_ultimo_nivel():
		_avanzar_nivel()
		return
	termino = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var texto := "¡GANASTE!\n\nPuntaje %d   Tesoros %d/%d\n\nR para jugar de nuevo" % [
		jugador.puntaje, jugador.tesoros, total_tesoros]
	hud.mostrar_mensaje(texto, Color(0.95, 0.85, 0.3))

# bonus al pasar de nivel: se duplica la vida maxima (y se rellena) y mas balas
func _avanzar_nivel() -> void:
	jugador.vida_max *= 2
	jugador.vida = jugador.vida_max
	jugador.agregar_municion(40)
	jugador.estado_cambiado.emit()
	_cargar_nivel(nivel_actual + 1)
