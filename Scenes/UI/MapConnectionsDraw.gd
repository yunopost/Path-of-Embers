extends Control
## Custom Control that draws map connection lines
## This is attached to MapConnections node in MapScreen.tscn

var connection_data: Array[Dictionary] = []
var map_screen_ref: Node = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	# Ensure we can draw
	queue_redraw()
	print("MapConnectionsDraw._ready() called")  # Debug

func _draw():
	## Draw all connection lines with fading/highlighting
	if connection_data.is_empty():
		print("MapConnectionsDraw._draw(): connection_data is empty")  # Debug
		return
	
	print("MapConnectionsDraw._draw(): Drawing ", connection_data.size(), " connections")  # Debug
	
	var base_color = Color(0.5, 0.5, 0.5, 1.0)
	
	for conn in connection_data:
		var start = conn.start
		var end = conn.end
		
		# Determine line properties based on state
		var alpha: float
		var width: float
		
		if conn.is_current_outgoing:
			# Brightest: current node outgoing to selectable
			alpha = 0.95
			width = 3.0
		elif conn.is_selectable:
			# Bright: leads to selectable node
			alpha = 0.85
			width = 2.5
		else:
			# Faded: not on selectable path
			alpha = 0.25
			width = 1.5
		
		var color = base_color
		color.a = alpha
		
		# Draw line
		draw_line(start, end, color, width)

func set_connection_data(data: Array[Dictionary]):
	## Update connection data and trigger redraw
	connection_data = data
	visible = true  # Ensure visible
	print("MapConnectionsDraw.set_connection_data(): Received ", data.size(), " connections, queueing redraw, visible=", visible)  # Debug
	queue_redraw()
