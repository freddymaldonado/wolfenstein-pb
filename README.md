# Wolfenstein 3D — Proyecto Final

**Freddy Maldonado Pereyra — Cod. UPB 59814**

Clon en 3D del viejo **Wolfenstein 3D**, hecho en **Godot 4.6**. Es un shooter en
primera persona: recorres una mazmorra con paredes texturizadas, los guardias te
ven y te disparan, juntas munición / botiquines / tesoros, abres puertas y tenes
que llegar a la **SALIDA** para ganar.

Todo el mundo se arma **por codigo** a partir de un mapa de texto. No hay escenas
pesadas hechas a mano: la escena principal es un solo nodo con el script
[scripts/game.gd](scripts/game.gd).

## Como correr

1. Abrir esta carpeta (`proyectofinal/`) en Godot 4.6 y darle **Play (F5)**.
2. La escena principal es [scenes/game.tscn](scenes/game.tscn).
3. El mouse queda capturado para mirar. Con **Esc** lo suelto/recapturo.

### Controles

| Tecla | Accion |
|-------|--------|
| **W A S D** / flechas | moverse |
| **Mouse** | mirar |
| **Click izquierdo** | disparar |
| **Shift** | correr |
| **Esc** | soltar / recapturar el mouse |
| **R** | reiniciar el nivel |

## Que tiene

- **FPS real en 3D**: `CharacterBody3D` con movimiento y mouse look, colisiones
  contra las paredes, disparo por *hitscan* (un rayo desde la camara).
- **Paredes estilo Wolfenstein**: grilla de cubos texturizados, con materiales
  *unshaded* (planos, sin depender de luces) y filtro *nearest* para el look
  pixelado. Hay 4 variantes de pared.
- **Enemigos billboard con IA**: los guardias son sprites planos que siempre
  miran a la camara. Arrancan dormidos y cuando te ven (distancia + linea de
  vista contra las paredes) te persiguen y disparan cada cierto rato.
- **Objetos recogibles**: tesoros (puntaje), municion, botiquines (curan) y
  llaves. Flotan y se recogen al tocarlos.
- **Puertas corredizas**: se abren solas cuando te acercas y se cierran al
  alejarte.
- **HUD**: vida, municion, puntaje, tesoros, llaves, mira al centro, el arma
  abajo con su fogonazo al disparar, flash rojo al recibir daño.
- **Estados de juego**: pantalla de **MORISTE** si te quedas sin vida y de
  **¡GANASTE!** al llegar a la salida, ambas con reinicio.
- **Niebla** oscura para dar profundidad de mazmorra.

## Estructura

```
proyectofinal/
  project.godot          config minima (Godot 4.6, Forward Plus)
  scenes/game.tscn       escena principal (un nodo con game.gd)
  mapas/
    e1.map               nivel 1
    e2.map               nivel 2 (arena del jefe final)
  scripts/
    game.gd              arma todo el mundo y maneja los estados
    mapa.gd              lee el .map de texto a una grilla
    texturas.gd          fabrica de texturas/sprites (real o generado)
    player.gd            el jugador en primera persona
    enemy.gd             enemigo (guardia y jefe) con IA
    pickup.gd            objetos recogibles
    puerta.gd            puerta corrediza
    hud.gd               interfaz en pantalla
    menu.gd              menu de pausa con ajustes
  assets/
    sprites/             sprites de personajes/items (PNG)
    faces/               caras del HUD (PNG)
```

## Sprites reales de Wolfenstein

Los sprites de personajes y del arma son los **reales** de Wolfenstein,
convertidos de BMP a PNG con el fondo magenta (`#980088`) vuelto transparente, y
viven en `assets/sprites/`. Las texturas de pared y piso se **generan por codigo**
en `texturas.gd` (look pixelado, sin depender de archivos externos), asi el juego
nunca queda roto aunque falte un recurso.

Los sprites originales se pueden bajar de The Wolfenstein 3D Vault:
<https://wolfenvault.areyep.com/resources.html> (la descarga es manual; el sitio
bloquea bajadas automaticas).

## Como esta hecho el mapa

Cada caracter del `.map` es una celda de la grilla:

| Char | Significa |
|------|-----------|
| `#` `=` `%` `$` | pared (4 variantes de textura) |
| `.` o espacio | piso |
| `P` `^` `v` `<` `>` | inicio del jugador (y hacia donde mira) |
| `G` | guardia |
| `H` | jefe final |
| `D` | puerta |
| `T` | tesoro · `M` municion · `B` botiquin · `K` llave |
| `X` | salida del nivel |

Para hacer otro nivel basta con copiar un `.map`, dibujarlo y agregarlo a la
constante `NIVELES` en [scripts/game.gd](scripts/game.gd).

## Recursos que mire

El codigo es mio. Para las mecanicas lei sobre:
- Wolfenstein 3D (Wikipedia): <https://en.wikipedia.org/wiki/Wolfenstein_3D>
- FPS / billboards y docs de Godot 4: <https://docs.godotengine.org/en/stable/>
- Sprites originales: The Wolfenstein 3D Vault (link arriba).
