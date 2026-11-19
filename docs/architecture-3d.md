# Arquitectura de Oficina 3D

La escena `game/scenes/office3d.tscn` presenta la oficina y las zonas de
juego desde una cámara elevada, con mallas GLB, luces y avatares 3D.
`game/scripts/world3d.gd` convierte el plano del juego a coordenadas
`Vector3(x / 40, altura, y / 40)`. El movimiento, las colisiones y las
puertas siguen usando el plano de la simulación de la oficina; las puertas
tienen una representación animada. La escena 2D `game/scenes/office.tscn`
puede abrirse por separado en el editor.

| Parte | Archivos |
|---|---|
| Integración de escena e interacción existente | `game/scripts/office3d.gd`, `game/scripts/office.gd` |
| Mundo, cámara y avatar | `game/scripts/world3d.gd`, `game/scripts/avatar3d.gd`, `game/art/office3d/` |
| Diseño inicial en 3D y edición local | `game/data/office_layout.json`, `game/scripts/office_layout_store.gd`, `game/scripts/office_map_editor.gd` |
| Simulación 2D y contratos de red | `game/scripts/office_map.gd`, `game/scripts/office_network.gd`, `server/modules/office.lua`, `server/modules/geometry.lua` |
| Minijuegos y creador | `game/scripts/playground_*.gd`, `server/modules/playground_*.lua` |

## Mapa editable

El JSON de diseño usa el esquema 1. Cada objeto tiene `id`, `kind`, `x`,
`y`, `w`, `d`, `rotation` y `zone`. Las posiciones y las huellas se expresan
en unidades del plano a razón de 40 por metro. La rotación del modelo es en
radianes sobre el eje Y. El diseño también contiene el contorno, paredes,
habitaciones, puertas y rótulos iniciales. Los anclajes de interacción se
mantienen fijos durante la edición.

Desde el editor integrado se pueden seleccionar, agregar, mover, rotar y
quitar muebles, paredes modulares y decoraciones. Cada huella debe caber
dentro del contorno de la oficina. Guardar conserva el diseño en el perfil local
del juego. Exportar e importar JSON permite transferir un diseño entre copias.
Al entrar en una sala de red se usa el diseño canónico y se aplican las
colisiones validadas por el servidor.

## Promover un cambio al mapa compartido

1. Revisar el JSON exportado en una copia limpia y describir el cambio visual
   y los efectos esperados en el recorrido.
2. Actualizar el diseño base y alinear paredes, muebles sólidos y anclajes
   con la geometría canónica en `office_map.gd`. Revisar la correspondencia
   de la huella de colisión rectangular con cada modelo editado.
3. Ejecutar `game/tests/export_geometry.gd` con Godot para regenerar
   `server/modules/geometry.lua`. Revisar el diff y reiniciar el Nakama propio
   del candidato para cargarlo.
4. Probar pasillos, colisiones, interacción y regreso de puertas. Repetir
   con dos clientes y verificar la presencia y el movimiento en ambas
   direcciones. [Guía de contribución](CONTRIBUTING.md).

## Transporte y juego

El cliente de Godot conserva el protocolo de Nakama. La presentación lee la
posición del jugador y de sus pares. El servidor controla la geometría,
valida el movimiento y procesa el estado de partidas. Los paneles de arcade
y taller reutilizan la interacción existente y los servidores de minijuegos.
En Web, el candidato sirve el cliente y su proxy WebSocket desde el mismo
origen. En nativo, `OFFICE_BACKEND_PORT` selecciona el puerto local de
Nakama para desarrollo.
