extends RefCounted
class_name Mapa

# Lector de mapas de texto: cada caracter es una celda de la grilla. Los niveles
# viven en archivos .map de texto plano, faciles de dibujar a mano.
#
# leyenda:
#   #  pared variante 1        =  pared variante 2
#   %  pared variante 3        $  pared variante 4
#   .  o espacio  -> piso vacio
#   P  inicio del jugador
#   <  ^  >  v   inicio del jugador mirando izq/arriba/der/abajo
#   G  guardia (enemigo)
#   D  puerta
#   T  tesoro (suma puntaje)
#   M  municion
#   B  botiquin (cura)
#   K  llave
#   H  jefe final (Hitler)
#   X  salida del nivel (hay que llegar para ganar)

const PARED := "PARED"
const PUERTA := "PUERTA"
const VACIO := "VACIO"

# que caracteres son pared y con que variante de textura
const VARIANTES_PARED := {"#": 1, "=": 2, "%": 3, "$": 4}

var ancho: int = 0
var alto: int = 0
var celdas: Array = []          # matriz [fila][col] con el tipo de muro
var variantes: Array = []       # matriz [fila][col] con la variante de textura (1..4)
var inicio_jugador := Vector2i(1, 1)
var angulo_jugador := 0.0       # yaw inicial en radianes
var guardias: Array[Vector2i] = []
var jefes: Array[Vector2i] = []
var puertas: Array[Vector2i] = []
var items: Array = []           # cada uno {pos: Vector2i, tipo: String}
var salida := Vector2i(-1, -1)

# carga un .map desde disco. devuelve un Mapa o null si falla
static func cargar(ruta: String) -> Mapa:
	if not FileAccess.file_exists(ruta):
		push_error("No encuentro el mapa: %s" % ruta)
		return null
	var f := FileAccess.open(ruta, FileAccess.READ)
	var texto := f.get_as_text()
	f.close()
	return desde_texto(texto)

static func desde_texto(texto: String) -> Mapa:
	var m := Mapa.new()
	var lineas := texto.replace("\r", "").split("\n")
	# saco lineas vacias del final pero respeto las del medio
	while lineas.size() > 0 and lineas[lineas.size() - 1].strip_edges() == "":
		lineas.remove_at(lineas.size() - 1)
	if lineas.is_empty():
		push_error("El mapa esta vacio")
		return null
	# el ancho es la linea mas larga; las cortas se rellenan con pared
	for l in lineas:
		m.ancho = max(m.ancho, l.length())
	m.alto = lineas.size()
	for fila in m.alto:
		var linea: String = lineas[fila]
		var fila_celdas: Array = []
		var fila_var: Array = []
		for col in m.ancho:
			var c := "#" if col >= linea.length() else linea[col]
			fila_var.append(VARIANTES_PARED.get(c, 1))
			fila_celdas.append(m._procesar(c, col, fila))
		m.celdas.append(fila_celdas)
		m.variantes.append(fila_var)
	return m

# clasifica un caracter, guarda spawns/items y devuelve el tipo de muro
func _procesar(c: String, col: int, fila: int) -> String:
	if VARIANTES_PARED.has(c):
		return PARED
	match c:
		"D":
			puertas.append(Vector2i(col, fila))
			return PUERTA
		"P", "^":
			inicio_jugador = Vector2i(col, fila)
			angulo_jugador = 0.0 if c == "P" else PI
		"v":
			inicio_jugador = Vector2i(col, fila)
			angulo_jugador = 0.0
		"<":
			inicio_jugador = Vector2i(col, fila)
			angulo_jugador = PI * 0.5
		">":
			inicio_jugador = Vector2i(col, fila)
			angulo_jugador = -PI * 0.5
		"G":
			guardias.append(Vector2i(col, fila))
		"H":
			jefes.append(Vector2i(col, fila))
		"T":
			items.append({"pos": Vector2i(col, fila), "tipo": "tesoro"})
		"M":
			items.append({"pos": Vector2i(col, fila), "tipo": "municion"})
		"B":
			items.append({"pos": Vector2i(col, fila), "tipo": "botiquin"})
		"K":
			items.append({"pos": Vector2i(col, fila), "tipo": "llave"})
		"X":
			salida = Vector2i(col, fila)
	return VACIO

# variante de textura para una celda de pared (1..4)
func variante_en(col: int, fila: int) -> int:
	if not dentro(col, fila):
		return 1
	return variantes[fila][col]

# true si la celda esta dentro de la grilla
func dentro(col: int, fila: int) -> bool:
	return col >= 0 and fila >= 0 and col < ancho and fila < alto

# true si esa celda bloquea el paso (pared). las puertas se manejan aparte.
func es_pared(col: int, fila: int) -> bool:
	if not dentro(col, fila):
		return true
	return celdas[fila][col] == PARED

func tipo_en(col: int, fila: int) -> String:
	if not dentro(col, fila):
		return PARED
	return celdas[fila][col]
