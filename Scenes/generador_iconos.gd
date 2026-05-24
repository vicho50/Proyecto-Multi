extends Node

# Esta función hace el trabajo sucio
func extraer_foto():
	# Busca el viewport. Ajusta "SubViewport" al nombre real de tu nodo
	var viewport = $SubViewportContainer/SubViewport
	

	var textura = viewport.get_texture()
	var imagen = textura.get_image()
	imagen.flip_y() # Corrige la inversión de Godot
	
	# Guardar en la carpeta de datos de usuario
	var ruta = "res://Assets/UI/Iconos_Tropas/captura_pantalla.png"
	imagen.save_png(ruta)
	
	print("¡Foto guardada en: ", ProjectSettings.globalize_path(ruta))
 
	
# Para probarlo rápido, haremos que se active al pulsar una tecla
func _input(event):
	if event.is_action_pressed("ui_accept"): # Por defecto es la tecla 'Enter'
		extraer_foto()
