# Editar la oficina

1. Abrí **Editar mapa 3D** en la oficina. Si estás en una sala con otra
   persona, salí de la sala primero.
2. Arrastrá una pieza del mapa para moverla, o elegila en la lista. Usá **X-**, **X+**,
   **Z-** y **Z+** para moverla diez unidades. Podés usar los campos
   X y Z para ubicarla por coordenadas. **Girar 90°** rota la pieza
   seleccionada y **Quitar** la elimina del diseño.
3. Elegí un tipo y arrastrá **Arrastrar pieza al mapa** hasta el lugar deseado.
   También podés pulsar **Agregar en el centro**. Podés sumar muebles,
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


## Arrastrar y soltar

En **Editar mapa 3D**, mantené presionado un mueble y arrastralo a su nueva
posición. Al soltarlo se ajusta a pasos de 10. También funciona con un dedo;
en pantallas angostas el panel queda abajo y se puede desplazar su contenido.

Para agregar, elegí un tipo en el selector y arrastrá **Arrastrar pieza al mapa**
hasta el lugar deseado. **Agregar en el centro** conserva la alternativa por clic.
Para eliminar, seleccioná la pieza y pulsá **Quitar**, o arrastrala hasta ese botón.
**Deshacer** recupera una eliminación o revierte un arrastre completo.

Soltar fuera del contorno o encima del panel cancela la colocación (salvo al
soltar una pieza existente en Quitar). **Escape**, perder el foco o cambiar el
tamaño de la ventana también cancelan el arrastre. Los campos X/Z y el giro
siguen disponibles. Guardá el borrador para conservar los cambios al recargar.

El contorno, las paredes originales, las puertas y sus destinos siguen fijos;
se editan los muebles y las paredes modulares de la paleta. El borrador continúa
siendo local: entrar en una sala usa el mapa compartido del servidor.
