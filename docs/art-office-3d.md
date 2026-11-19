# Kit de oficina 3D

El archivo editable `art/source/office-kit-3d.blend` abre una galería con los 12 modelos. Cada colección `office3d_<tipo>` contiene las piezas geométricas, los materiales y un objeto raíz `Asset_<tipo>`. Los escritorios, la recepción, el taller y el arcade retoman la paleta y los detalles de los sprites originales de la oficina en `art/source/office-props.blend`. Se modelaron las piezas con primitivas, biseles y materiales planos. El kit no requiere texturas externas, complementos adicionales ni ejecución automática de scripts.

## Editar un modelo

1. Abrí `art/source/office-kit-3d.blend` en Blender y elegí su colección en el Outliner. Los objetos raíz colocan las colecciones en la galería. Editá los componentes bajo el objeto raíz correspondiente.
2. Conservá el centro de la huella y el apoyo en el suelo. La huella es de 1 × 1 m en los ejes X/Y de Blender, con el suelo en Z=0. El frente apunta a −Y en Blender. En Godot el suelo es Y=0 y el frente apunta a +Z. La altura es propia de cada modelo.
3. Guardá el archivo y, desde la raíz del proyecto, ejecutá la exportación y la verificación. Sustituí la primera línea si tu ejecutable de Blender está en otra ruta.

```powershell
$officeBlender = './output/tools/blender-4.5.9-windows-x64/blender.exe'
& $officeBlender --background --factory-startup --disable-autoexec --python-exit-code 1 --python scripts/blender_office_3d.py -- --from-blend
& $officeBlender --background --factory-startup --disable-autoexec --python-exit-code 1 --python scripts/verify_office_3d_assets.py
```

La opción `--from-blend` conserva el archivo fuente y permite exportar sus cambios. Omitila sólo para regenerar el kit desde el código, lo que reemplaza `office-kit-3d.blend` y los derivados. La exportación triangula la geometría y agrupa las piezas por material y padre. Los GLB se escriben en `game/art/office3d/` y el manifiesto registra los tamaños, los triángulos y los SHA-256 de la fuente y los derivados.

## Abrir y actualizar el mapa completo

`art/source/office-map-3d.blend` reúne la planta de la oficina, pisos de salas, muros, muebles, puertas, portales, buzón y sala de arcade con sus seis estaciones. En el Outliner, las colecciones `Floors`, `Walls`, `Furniture`, `Doors`, `Gameplay` y `Labels` permiten aislar cada parte. En `Furniture`, seleccioná el objeto raíz con el identificador del layout para mover o rotar un mueble entero. Las instancias de un mismo modelo comparten la malla. Para retocar una sola en modo Edición, hacé sus datos de malla de usuario único primero.

El mapa de juego usa `game/data/office_layout.json` para las ubicaciones en la oficina. El ensamblador interpreta 40 píxeles por metro y toma las zonas de juego fijas del diseño de la escena. El flujo de posiciones va del JSON a Blender. Los movimientos hechos en Blender quedan en la escena editable. Para cambiar posiciones en el juego, usá el editor del juego y su exportación JSON.

Desde la raíz del proyecto, después de cambiar el JSON o el kit, regenerá el ensamblado de referencia.

```powershell
& $officeBlender --background --factory-startup --disable-autoexec --python-exit-code 1 --python scripts/blender_office_map.py
```

Para ver una partida editada, exportá su JSON desde el editor y elegí un .blend distinto para conservar la referencia.

```powershell
& $officeBlender --background --factory-startup --disable-autoexec --python-exit-code 1 --python scripts/blender_office_map.py -- --layout './layout-editado.json' --output './mapa-editado.blend'
```

## Contrato con la escena

- `door.glb` tiene una altura cerrada de 2,12 m. La abertura del marco está en el plano X/Y de Godot y la hoja gira sobre Y en `DoorLeaf`, junto a la jamba izquierda. El marco carece de umbral para dejar libre el paso.
- `avatar.glb` tiene una altura de 1,655 m. Conservá los pivotes `LegLeft` y `LegRight` y los nombres de material `skin`, `hair`, `shirt` y `legs`. La escena usa estos nombres para animar las piernas y aplicar la apariencia del personaje.
- La posición, rotación, escala horizontal y colisión de un mueble pertenecen al mapa del juego. Editá el modelo en Blender para cambiar su forma y usá el editor del juego para mover sus instancias.

Procedencia y créditos en `art/office3d-manifest.json`. El kit corresponde al arte original del proyecto. La licencia de distribución pública de las fuentes queda pendiente de definición.
