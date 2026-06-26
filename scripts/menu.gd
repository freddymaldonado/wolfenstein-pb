extends CanvasLayer
class_name MenuPausa

# Menu de pausa con ajustes. Se abre/cierra con Escape, congela el juego y deja
# tocar velocidad, sensibilidad del mouse y volumen. Corre con el arbol pausado
# (process_mode = ALWAYS) y su UI se arma por codigo con StyleBox.

const ANCHO_PANEL := 460.0
const FONDO := Color(0.05, 0.05, 0.10, 0.88)
const PANEL := Color(0.11, 0.12, 0.20, 0.98)
const ACENTO := Color(0.85, 0.2, 0.2)
const DORADO := Color(0.95, 0.85, 0.4)
const TEXTO := Color(0.85, 0.87, 0.95)

var jugador: Jugador

var _raiz: Control
var _abierto := false

# guardo rangos para mapear sliders <-> valores reales
const VEL_MIN := 2.5
const VEL_MAX := 9.0
const SENS_MIN := 0.0008
const SENS_MAX := 0.006

var _lbl_vel: Label
var _lbl_sens: Label
var _lbl_vol: Label

func configurar(j: Jugador) -> void:
	jugador = j

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS   # sigue vivo con el juego pausado
	_construir()
	_raiz.visible = false

func _construir() -> void:
	# fondo que oscurece la escena
	_raiz = Control.new()
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_raiz)

	var fondo := ColorRect.new()
	fondo.color = FONDO
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.add_child(fondo)

	# panel central
	var panel := PanelContainer.new()
	var est := StyleBoxFlat.new()
	est.bg_color = PANEL
	est.border_color = ACENTO
	est.set_border_width_all(2)
	est.set_corner_radius_all(10)
	est.set_content_margin_all(26)
	est.shadow_color = Color(0, 0, 0, 0.5)
	est.shadow_size = 16
	panel.add_theme_stylebox_override("panel", est)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(ANCHO_PANEL, 0)
	panel.offset_left = -ANCHO_PANEL * 0.5
	panel.offset_right = ANCHO_PANEL * 0.5
	panel.offset_top = -250
	_raiz.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	panel.add_child(col)

	# titulo
	var titulo := Label.new()
	titulo.text = "PAUSA  ·  AJUSTES"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 34)
	titulo.add_theme_color_override("font_color", DORADO)
	titulo.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	titulo.add_theme_constant_override("outline_size", 4)
	col.add_child(titulo)

	var sub := Label.new()
	sub.text = "Wolfenstein PB"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.55, 0.57, 0.7))
	col.add_child(sub)

	col.add_child(_separador())

	# sliders
	var frac_vel := inverse_lerp(VEL_MIN, VEL_MAX, jugador.velocidad if jugador else 4.8)
	_lbl_vel = _slider(col, "Velocidad de movimiento", frac_vel, _al_cambiar_vel)
	var frac_sens := inverse_lerp(SENS_MIN, SENS_MAX, jugador.sensibilidad if jugador else 0.0025)
	_lbl_sens = _slider(col, "Sensibilidad del mouse", frac_sens, _al_cambiar_sens)
	var vol_db: float = AudioServer.get_bus_volume_db(0)
	var frac_vol := clampf(db_to_linear(vol_db), 0.0, 1.0)
	_lbl_vol = _slider(col, "Volumen", frac_vol, _al_cambiar_vol)

	col.add_child(_separador())

	# botones
	col.add_child(_boton("Reanudar  (Esc)", DORADO, cerrar))
	col.add_child(_boton("Reiniciar nivel  (R)", Color(0.5, 0.7, 1.0), _reiniciar))
	col.add_child(_boton("Salir del juego", ACENTO, _salir))

	# ayuda de controles abajo del panel
	var ayuda := Label.new()
	ayuda.text = "WASD mover · Mouse mirar · Click disparar · Shift correr\n1/2 o rueda cambiar arma · Q siguiente arma"
	ayuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ayuda.add_theme_font_size_override("font_size", 13)
	ayuda.add_theme_color_override("font_color", Color(0.55, 0.57, 0.7))
	ayuda.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	ayuda.offset_top = -70
	ayuda.offset_bottom = -30
	ayuda.offset_left = -360
	ayuda.offset_right = 360
	_raiz.add_child(ayuda)

func _separador() -> HSeparator:
	var s := HSeparator.new()
	var est := StyleBoxFlat.new()
	est.bg_color = Color(0.3, 0.32, 0.45, 0.5)
	est.content_margin_top = 1
	est.content_margin_bottom = 1
	s.add_theme_stylebox_override("separator", est)
	return s

# slider con etiqueta + valor; devuelve la label del valor para refrescarla
func _slider(padre: Node, texto: String, valor_inicial: float, callback: Callable) -> Label:
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 4)

	var fila := HBoxContainer.new()
	var et := Label.new()
	et.text = texto
	et.add_theme_font_size_override("font_size", 16)
	et.add_theme_color_override("font_color", TEXTO)
	et.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(et)

	var val := Label.new()
	val.add_theme_font_size_override("font_size", 16)
	val.add_theme_color_override("font_color", DORADO)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fila.add_child(val)
	caja.add_child(fila)

	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.01
	sl.value = valor_inicial
	sl.custom_minimum_size = Vector2(0, 22)
	sl.value_changed.connect(func(v): callback.call(v, val))
	caja.add_child(sl)

	padre.add_child(caja)
	callback.call(valor_inicial, val)   # pinta el valor inicial
	return val

func _boton(texto: String, color: Color, accion: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 18)
	b.custom_minimum_size = Vector2(0, 42)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.16, 0.17, 0.27)
	normal.border_color = color
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(8)
	var hover := normal.duplicate()
	hover.bg_color = color.darkened(0.3)
	var press := normal.duplicate()
	press.bg_color = color.darkened(0.1)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", press)
	b.add_theme_color_override("font_color", TEXTO)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.pressed.connect(accion)
	return b

# ------------------------------------------------------------- callbacks UI

func _al_cambiar_vel(frac: float, lbl: Label) -> void:
	var v := lerpf(VEL_MIN, VEL_MAX, frac)
	if jugador:
		jugador.velocidad = v
		jugador.velocidad_correr = v * 1.55
	lbl.text = "%.1f" % v

func _al_cambiar_sens(frac: float, lbl: Label) -> void:
	var s := lerpf(SENS_MIN, SENS_MAX, frac)
	if jugador:
		jugador.sensibilidad = s
	lbl.text = "%d%%" % int(round(frac * 100))

func _al_cambiar_vol(frac: float, lbl: Label) -> void:
	# 0 -> mute ; 1 -> 0 dB
	if frac <= 0.001:
		AudioServer.set_bus_mute(0, true)
	else:
		AudioServer.set_bus_mute(0, false)
		AudioServer.set_bus_volume_db(0, linear_to_db(frac))
	lbl.text = "%d%%" % int(round(frac * 100))

# ----------------------------------------------------------------- control

func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and not evento.echo:
		if evento.keycode == KEY_ESCAPE:
			alternar()
			get_viewport().set_input_as_handled()
		elif evento.keycode == KEY_R and _abierto:
			_reiniciar()

func alternar() -> void:
	if _abierto:
		cerrar()
	else:
		abrir()

func abrir() -> void:
	_abierto = true
	_raiz.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if jugador:
		jugador.detener_disparo()

func cerrar() -> void:
	_abierto = false
	_raiz.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if jugador:
		jugador.detener_disparo()

func _reiniciar() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _salir() -> void:
	get_tree().quit()
