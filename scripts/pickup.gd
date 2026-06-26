extends Area3D
class_name Pickup

# Objeto recogible (tesoro, municion, botiquin o llave). Es un sprite billboard
# que flota; al tocarlo el jugador aplica su efecto y desaparece.

const VALOR_TESORO := 100
const MUNICION_DA := 14
const BOTIQUIN_CURA := 25

var tipo := "tesoro"
var _sprite: Sprite3D
var _t := 0.0
var _y_base := 0.0

func _ready() -> void:
	monitoring = true
	collision_layer = 0
	collision_mask = 2                 # detecta al jugador (capa 2)
	var forma := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = 0.7
	forma.shape = esfera
	add_child(forma)

	_sprite = Sprite3D.new()
	_sprite.texture = Texturas.sprite(tipo)
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.shaded = false
	_sprite.pixel_size = 0.03
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	add_child(_sprite)
	_y_base = _sprite.position.y

	body_entered.connect(_al_tocar)

func _process(delta: float) -> void:
	# flotacion suave para que se note que es recogible
	_t += delta
	_sprite.position.y = _y_base + sin(_t * 3.0) * 0.08

func _al_tocar(cuerpo: Node) -> void:
	if not (cuerpo is Jugador):
		return
	var j: Jugador = cuerpo
	match tipo:
		"tesoro":
			j.agregar_tesoro(VALOR_TESORO)
		"municion":
			j.agregar_municion(MUNICION_DA)
		"botiquin":
			if j.vida >= j.vida_max:
				return                 # no lo gasto si estoy full vida
			j.curar(BOTIQUIN_CURA)
		"llave":
			j.agregar_llave()
	queue_free()
