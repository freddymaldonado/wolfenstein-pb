extends StaticBody3D
class_name Puerta

# Puerta corrediza. Sube cuando el jugador se acerca y baja cuando se aleja;
# se mueve toda la puerta (malla + colision), asi abre o cierra el paso.

const ALTURA := 3.0
const DIST_ABRIR := 2.2
const DIST_CERRAR := 3.0
const VELOCIDAD := 3.0           # que tan rapido sube/baja

var jugador: Jugador
var _y_cerrada := 0.0
var _apertura := 0.0             # 0 = cerrada, 1 = arriba del todo

func configurar(tamano: float, material: StandardMaterial3D) -> void:
	# llamado por game.gd con el tamaño de celda y el material de puerta
	var malla := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3(tamano, ALTURA, tamano)
	malla.mesh = caja
	malla.material_override = material
	malla.position.y = ALTURA * 0.5
	add_child(malla)

	var col := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = Vector3(tamano, ALTURA, tamano)
	col.shape = forma
	col.position.y = ALTURA * 0.5
	add_child(col)

func _ready() -> void:
	_y_cerrada = position.y

func _process(delta: float) -> void:
	if jugador == null:
		return
	var d := global_position.distance_to(jugador.global_position)
	var objetivo := _apertura
	if d <= DIST_ABRIR:
		objetivo = 1.0
	elif d >= DIST_CERRAR:
		objetivo = 0.0
	_apertura = move_toward(_apertura, objetivo, VELOCIDAD * delta)
	position.y = _y_cerrada + _apertura * ALTURA
