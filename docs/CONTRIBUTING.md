# Contribuir a Oficina 3D

Esta guía sirve para probar y modificar una copia aislada del juego. El punto
de entrada es `game/project.godot`. [Arquitectura de Oficina 3D](architecture-3d.md)
describe las unidades del mapa, el editor local y el contrato de red.
[Cómo editar el mapa](edit-map.md).

## Abrir el juego

1. Instalá Godot **4.7.1**, edición estándar. Para exportar a Web instalá también
   las plantillas de exportación de esa versión.
2. Importá `game/project.godot` desde el gestor de proyectos. Esperá a que Godot
   termine de importar los GLB y ejecutá el proyecto con **F6** en
   `game/scenes/office3d.tscn` o **F5** desde cualquier escena.
3. Probá el recorrido con WASD o flechas y los controles táctiles en una ventana
   estrecha. Probá las puertas al Arcade y al Taller desde la oficina e ingresá
   y volvé de cada panel. El juego local requiere únicamente Godot.

Los GLB están en el paquete. Blender **4.5.9** es opcional y sirve para editar
los archivos fuente o regenerar recursos. [Receta del kit 3D](art-office-3d.md).
Para una contribución de arte, adjuntá la fuente editable, el GLB exportado y el registro
de procedencia y licencia de cada recurso nuevo.

## Verificaciones locales

Desde la raíz del paquete, en PowerShell, definí `$Godot` con la ruta al
ejecutable de consola de Godot. En otros sistemas se pueden ejecutar los mismos
argumentos con el binario `godot`.

```powershell
& $Godot --headless --path game --editor --import --quit
& $Godot --headless --path game --script res://tests/office_test.gd
& $Godot --headless --path game --script res://tests/office3d_test.gd
& $Godot --headless --path game --script res://tests/office_layout_test.gd
& $Godot --headless --path game --script res://tests/playground_test.gd
& $Godot --headless --path game --script res://tests/playground_forms_test.gd
& $Godot --headless --path game --script res://tests/playground_creator_regression_test.gd
```

Revisá la salida de cada comando y su código de salida. Incluí los marcadores
de las pruebas ejecutadas y los pasos de reproducción en la propuesta.

## Dos clientes con una base local nueva

Requiere Docker Compose v2 y PowerShell 7 (`pwsh`). Usá una copia limpia y elegí
un nombre Compose propio. El candidato expone la API de Nakama en el puerto
local **17360** y el gateway web en el **18792**. Antes de arrancar comprobá que
estén libres. PostgreSQL y la consola administrativa quedan dentro de la red
de Compose.

```powershell
New-Item -ItemType Directory -Force output/web-next | Out-Null
& $Godot --headless --path game --export-release "Office Web" "../output/web-next/index.html"
pwsh -NoProfile -File server/setup.ps1
docker compose -p office3d-dev -f server/compose.candidate.yaml config --quiet
docker compose -p office3d-dev -f server/compose.candidate.yaml up -d
docker compose -p office3d-dev -f server/compose.candidate.yaml ps
```

Ejecutá `setup.ps1` una vez por copia. Genera credenciales independientes en
`server/.secrets/`. Conservá ese directorio fuera del control de versiones y de
cualquier registro técnico. El identificador de cliente configurado en el SDK
es público y corresponde al campo `socket.server_key` generado por la receta.
Si dos instalaciones conviven, asignales distintos puertos en sus Compose y
usá el puerto correspondiente al probar con el editor nativo.

```powershell
$env:OFFICE_BACKEND_PORT = '17360'
& $Godot --headless --path game --script res://tests/nakama_test.gd
& $Godot --headless --path game --script res://tests/office_network_test.gd
Remove-Item Env:OFFICE_BACKEND_PORT
```

Los marcadores esperados son `NAKAMA_TEST_PASS` y `OFFICE_NETWORK_PASS`. Para la
prueba web en la misma PC, abrí el gateway en el host de loopback con el puerto
18792 usando dos perfiles de navegador independientes. Creá una sala con el primero y copiá
su ID en el segundo. Verificá presencia y movimiento en ambas direcciones,
una partida y el retorno a la oficina. Para detener tu candidato y preservar
sus datos, ejecutá `docker compose -p office3d-dev -f server/compose.candidate.yaml stop`.

## Proponer un cambio

- Describí el problema o la mejora, el comportamiento esperado y cómo
  reproducirlo. Mantené cada propuesta enfocada en una tarea.
- Incluí el resultado de las pruebas pertinentes. Para UI o arte, incluí
  capturas desktop y móvil y el origen de los recursos añadidos.
- Para cambios al mapa compartido, adjuntá el diff de geometría del servidor
  y la verificación de las colisiones y las puertas con dos identidades.
- Trabajá con una copia y datos de prueba propios. Excluí cachés de Godot,
  exports, credenciales, bases y archivos de configuración personal del diff.

El SDK de Nakama conserva su [licencia Apache 2.0](../game/addons/com.heroiclabs.nakama/LICENSE)
y [procedencia](../game/addons/PROVENANCE.md). La licencia del código y del arte
propios y las condiciones de contribución externa están pendientes de
aprobación por el titular.
