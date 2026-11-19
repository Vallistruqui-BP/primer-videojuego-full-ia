# Editar la oficina

1. Abrí **Editar mapa 3D** en la oficina. Si estás en una sala con otra
   persona, salí de la sala primero.
2. Tocá una pieza del mapa o elegila en la lista. Usá **X-**, **X+**,
   **Z-** y **Z+** para moverla diez unidades. Podés usar los campos
   X y Z para ubicarla por coordenadas. **Girar 90°** rota la pieza
   seleccionada y **Quitar** la elimina del diseño.
3. Elegí un tipo y pulsá **Agregar pieza**. Podés sumar muebles,
   decoración y paredes modulares dentro del contorno. Las puertas,
   el contorno, las paredes de la distribución original y los accesos
   al Arcade y al Taller son parte del mapa base.
4. Pulsá **Probar** para caminar por el borrador. Volvé a abrir el editor
   para seguir editando. **Deshacer** recupera el cambio anterior.
   **Restaurar distribución original** repone las piezas del mapa base.
5. Pulsá **Guardar borrador** para conservar el diseño en el perfil de
   este navegador o en los datos locales de Godot. Después de recargar,
   abrí de nuevo el editor para ver el borrador. La oficina inicia con
   el mapa compartido.

**Exportar mapa (.json)** guarda una copia. La versión web la descarga y en
el ejecutable nativo queda como `oficina-mapa.json` en la carpeta de datos
del juego. Para importarla, abrí el archivo, copiá el JSON entero, pegalo
en el campo del editor y pulsá **Importar texto**. Pulsá **Guardar borrador**
para conservar la importación después de cerrar el juego.

Cuando creás una sala o entrás en una, la oficina usa el mapa compartido
validado por el servidor. El borrador sigue disponible al salir y reabrir
el editor. Para convertir un borrador en el mapa compartido, adjuntá su
JSON a una propuesta y seguí el proceso de revisión de geometría.
[Arquitectura de Oficina 3D](architecture-3d.md).
