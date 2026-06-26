extends CanvasLayer
class_name Hud

# Interfaz estilo Wolfenstein: barra inferior con puntaje, vida, balas, la cara
# de BJ y el arma equipada; sobre la barra, el arma que dispara y la mira; al
# centro, los carteles de ganaste / moriste. Todo armado por codigo.

const ALTO_BARRA := 84
const AZUL_HUD := Color(0.13, 0.14, 0.32)
const DORADO := Color(0.95, 0.85, 0.4)

var jugador: Jugador

var _arma: TextureRect            # el arma que dispara (encima de la barra)
var _cara: TextureRect            # cara de BJ dentro de la barra
var _flash: ColorRect
var _mensaje: Label
var _aviso: Label                 # cartel temporal (NIVEL 2, etc.)
var _t_aviso := 0.0

# valores de la barra inferior
var _lbl_puntaje: Label
var _lbl_vida: Label
var _lbl_balas: Label
var _lbl_arma: Label

# animacion del arma y caras
var _frames_arma: Array[Texture2D] = []
var _caras: Array[Texture2D] = []
var _t_disparo := 0.0
var _flash_alpha := 0.0
var _sprite_arma_cargado := ""

func configurar(j: Jugador) -> void:
	jugador = j
	j.estado_cambiado.connect(_refrescar)
	j.disparo_hecho.connect(_al_disparar)
	j.murio.connect(_al_morir)
	j.arma_cambiada.connect(_cargar_arma)
	# ya tengo jugador: cargo el arma y pinto los valores iniciales
	if is_node_ready():
		_cargar_arma()
		_refrescar()

func _ready() -> void:
	layer = 10
	_caras = Texturas.cargar_frames("faces", "cara%d", 1, 7)

	# overlay rojo para el daño (cubre todo)
	_flash = ColorRect.new()
	_flash.color = Color(0.7, 0, 0, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	# arma que dispara, centrada arriba de la barra
	_arma = TextureRect.new()
	_arma.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_arma.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_arma.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_arma.offset_left = -160
	_arma.offset_right = 160
	_arma.offset_top = -300 - ALTO_BARRA
	_arma.offset_bottom = -ALTO_BARRA
	_arma.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_arma)

	# mira en el centro
	var mira := Label.new()
	mira.text = "+"
	mira.add_theme_font_size_override("font_size", 28)
	mira.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	mira.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	mira.offset_left = -9
	mira.offset_top = -50
	mira.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mira)

	_construir_barra()

	# cartel central (ganaste / moriste)
	_mensaje = Label.new()
	_mensaje.add_theme_font_size_override("font_size", 46)
	_mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mensaje.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mensaje.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mensaje.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mensaje.visible = false
	add_child(_mensaje)

	# cartel temporal arriba (aviso de nivel)
	_aviso = Label.new()
	_aviso.add_theme_font_size_override("font_size", 54)
	_aviso.add_theme_color_override("font_color", DORADO)
	_aviso.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_aviso.add_theme_constant_override("outline_size", 8)
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_aviso.offset_top = 60
	_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aviso.visible = false
	add_child(_aviso)

	_cargar_arma()
	_refrescar()

# arma la barra inferior con sus paneles
func _construir_barra() -> void:
	var barra := Panel.new()
	barra.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	barra.offset_top = -ALTO_BARRA
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = AZUL_HUD
	estilo.border_color = Color(0.05, 0.05, 0.12)
	estilo.border_width_top = 3
	barra.add_theme_stylebox_override("panel", estilo)
	add_child(barra)

	var fila := HBoxContainer.new()
	fila.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fila.add_theme_constant_override("separation", 10)
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra.add_child(fila)

	_lbl_puntaje = _panel(fila, "PUNTAJE", DORADO)
	_lbl_vida = _panel(fila, "VIDA", Color(0.45, 0.9, 0.5))

	# cara de BJ al centro de la barra
	if not _caras.is_empty():
		var marco := PanelContainer.new()
		var est2 := StyleBoxFlat.new()
		est2.bg_color = Color(0.05, 0.05, 0.12)
		est2.set_corner_radius_all(4)
		est2.set_content_margin_all(4)
		marco.add_theme_stylebox_override("panel", est2)
		marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cara = TextureRect.new()
		_cara.texture = _caras[0]
		_cara.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_cara.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_cara.custom_minimum_size = Vector2(54, 72)
		_cara.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marco.add_child(_cara)
		fila.add_child(marco)

	_lbl_balas = _panel(fila, "BALAS", DORADO)
	_lbl_arma = _panel(fila, "ARMA", Color(0.7, 0.8, 1.0))

# crea un panelcito vertical [titulo / valor] y devuelve la label del valor
func _panel(padre: Node, titulo: String, color: Color) -> Label:
	var caja := VBoxContainer.new()
	caja.custom_minimum_size = Vector2(150, 0)
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tit := Label.new()
	tit.text = titulo
	tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tit.add_theme_font_size_override("font_size", 13)
	tit.add_theme_color_override("font_color", Color(0.6, 0.62, 0.75))
	caja.add_child(tit)

	var val := Label.new()
	val.text = "0"
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.add_theme_font_size_override("font_size", 30)
	val.add_theme_color_override("font_color", color)
	val.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	val.add_theme_constant_override("outline_size", 3)
	caja.add_child(val)

	padre.add_child(caja)
	return val

# carga los frames del arma equipada (segun arma_info del jugador)
func _cargar_arma() -> void:
	if jugador == null:
		return
	var info := jugador.arma_info()
	var sprite: String = info["sprite"]
	if sprite == _sprite_arma_cargado and not _frames_arma.is_empty():
		return
	_sprite_arma_cargado = sprite
	_frames_arma = Texturas.cargar_frames("sprites", sprite + "_%02d", 1, int(info["frames"]))
	if _frames_arma.is_empty():
		_frames_arma = [Texturas.sprite("arma"), Texturas.sprite("arma_disparo")]
	_arma.texture = _frames_arma[0]

func _process(delta: float) -> void:
	# recoil del arma: vuelve al frame idle despues de un toque
	if _t_disparo > 0.0:
		_t_disparo -= delta
		if _t_disparo <= 0.0:
			_arma.texture = _frames_arma[0]
	# el flash de daño se desvanece
	if _flash_alpha > 0.0:
		_flash_alpha = maxf(0.0, _flash_alpha - delta * 1.5)
		_flash.color.a = _flash_alpha
	# el aviso de nivel se oculta solo
	if _t_aviso > 0.0:
		_t_aviso -= delta
		if _t_aviso <= 0.0:
			_aviso.visible = false

func _refrescar() -> void:
	if jugador == null:
		return
	_lbl_puntaje.text = "%d" % jugador.puntaje
	_lbl_vida.text = "%d" % jugador.vida
	_lbl_balas.text = "%d" % jugador.municion
	_lbl_arma.text = jugador.arma_info()["nombre"]
	_lbl_balas.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3) if jugador.municion == 0 else DORADO)
	_refrescar_cara()

# elige la cara segun el porcentaje de vida (cara1 sano ... cara7 casi muerto)
func _refrescar_cara() -> void:
	if _cara == null or _caras.is_empty():
		return
	var frac := float(jugador.vida) / float(jugador.vida_max)
	var n := _caras.size()
	var idx := int(round((1.0 - frac) * (n - 1)))
	_cara.texture = _caras[clampi(idx, 0, n - 1)]

func _al_disparar() -> void:
	# muestra el frame mas "abierto" de la animacion de disparo
	_arma.texture = _frames_arma[mini(2, _frames_arma.size() - 1)]
	_t_disparo = 0.06

func _al_morir() -> void:
	_flash_dano()

func dano_recibido() -> void:
	_flash_dano()

func _flash_dano() -> void:
	_flash_alpha = 0.6
	_flash.color.a = _flash_alpha

func mostrar_mensaje(texto: String, color: Color) -> void:
	if texto == "":
		_mensaje.visible = false
		_arma.visible = true
		return
	_mensaje.text = texto
	_mensaje.add_theme_color_override("font_color", color)
	_mensaje.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_mensaje.add_theme_constant_override("outline_size", 6)
	_mensaje.visible = true
	_arma.visible = false

# muestra un cartel grande por un par de segundos (ej. "NIVEL 2")
func mostrar_aviso(texto: String) -> void:
	_aviso.text = texto
	_aviso.visible = true
	_t_aviso = 2.2

