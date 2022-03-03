extends Control


onready var file_dialog = $FileDialog
onready var file_button = $VBoxContainer/TopPanel/Buttons/FolderButton
onready var error_dialog = $ErrorDialog

onready var ui_anim = $UIAnimations

onready var sprite_size_check = $VBoxContainer/TopPanel/Buttons/SpriteSize/SpriteSizeCheckBox
onready var sprite_size_spin = $VBoxContainer/TopPanel/Buttons/SpriteSize/SpriteSizeSpinBox

onready var x_offset_button = $VBoxContainer/ToolPanel/Buttons/XOffset
onready var y_offset_button = $VBoxContainer/ToolPanel/Buttons/YOffset

onready var current_anim_button = $VBoxContainer/ToolPanel/Buttons/CurrentAnimButton

onready var grid = $Grid
onready var sprite = $Grid/Sprite
onready var animations = $Grid/Sprite/AnimationPlayer

var sprites_array

# TODO: Find a use for these
var current_sprite
var current_sprite_name
var current_sprite_offset

# File paths
var project_location
var scripts_folder
var attacks_folder
var sprites_folder

enum Tools{NONE, MOVE}
var current_tool = Tools.NONE

var within_canvas

func _ready():
	pass 

func _process(delta):
	sprite.scale = Vector2(sprite_size_spin.value, sprite_size_spin.value)

func _input(event):
	if Input.is_mouse_button_pressed(1):
		if current_tool == Tools.MOVE:
			if within_canvas:
				sprite.offset = (get_global_mouse_position() - sprite.position).round()
				var anim = animations.get_animation(current_anim_button.get_item_text(current_anim_button.selected))
				anim.track_insert_key(0, 0.0, Vector2(sprite.offset.x, sprite.offset.y))

func get_load_gml(dir):
	# Check if load.gml exists in the folder where it should be
	var file = File.new()
	if file.file_exists(dir + "/scripts/load.gml"):
		# File found, set the variables
		project_location = dir
		scripts_folder = dir + "/scripts"
		attacks_folder = scripts_folder + "/attacks"
		sprites_folder = dir + "/sprites"
		
		# Open and get load.gml
		file.open(scripts_folder + "/load.gml", File.READ)
		var content = file.get_as_text()
		file.close()
		
		# Regex time!
		# It matches a line starting with "sprite_change_offset"
		# Then finds the animations name, the X- and Y-offset
		var regex = RegEx.new()
		regex.compile("sprite_change_offset.*\"(.*)\".*,(.*).*,(.*)\\)")
		var result = regex.search_all(content)
		sprites_array = result
		return true
	else:
		# Couldn't find the file, epic fail
		error_dialog.show()
		return false

func new_animation(anim_name, x_offset, y_offset):
	# TODO: Insert the animation-making code from file dialog here
	var anim = Animation.new()
	
	# Make an animation track for offset based on the info on load.gml
	var offset_track = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(offset_track, ":offset")
	anim.track_insert_key(offset_track, 0.0, -Vector2(x_offset, y_offset))
	
	# Iterate through all files in /sprites until it finds a sprite with the same name
	var texture_dir = Directory.new()
	texture_dir.open(sprites_folder)
	texture_dir.list_dir_begin()
	var file_name = texture_dir.get_next()
	while file_name != "":
		# Regex again!
		# We search if the filename has "_strip" directly after it
		# We also take the frame number for later use
		var regex = RegEx.new()
		regex.compile(anim_name + "_strip" + "(.*).png")
		var result = regex.search(file_name)
		if result:
			# Found the sprite!
			# Make an animation track for the texture
			var image = Image.new()
			image.load(sprites_folder + "/" + file_name)
			var texture = ImageTexture.new()
			texture.create_from_image(image, 0)
			var texture_track = anim.add_track(Animation.TYPE_VALUE)
			anim.track_set_path(texture_track, ":texture")
			anim.track_insert_key(texture_track, 0.0, texture)
			
			# Make an animation track for Hframes
			var h_frames = result.get_string(1).to_int()
			var hframes_track = anim.add_track(Animation.TYPE_VALUE)
			anim.track_set_path(hframes_track, ":hframes")
			anim.track_insert_key(hframes_track, 0.0, h_frames)
		file_name = texture_dir.get_next()
	
	# Add an animation to the player and menu for every sprite in load.gml
	animations.add_animation(anim_name, anim)
	current_anim_button.add_item(anim_name)

func _on_FolderButton_pressed():
	file_dialog.show()


func _on_FileDialog_dir_selected(dir):
	# TODO: Make a sparate function for adding animations
	if get_load_gml(dir):
		# For each sprite, make an animation file.
		for x in sprites_array:
			new_animation(x.get_string(1), x.get_string(2), x.get_string(3))


func _on_MoveTool_toggled(button_pressed):
	if button_pressed:
		current_tool = Tools.MOVE
	else:
		current_tool = Tools.NONE


func _on_Grid_mouse_entered():
	within_canvas = true
	match current_tool:
		Tools.NONE:
			grid.mouse_default_cursor_shape = Control.CURSOR_ARROW
		Tools.MOVE:
			grid.mouse_default_cursor_shape = Control.CURSOR_MOVE


func _on_Grid_mouse_exited():
	within_canvas = false


func _on_UpdateButton_pressed():
	# Saves a load.gml file
	var file = File.new()
	file.open(scripts_folder + "/load.gml", File.WRITE)
	# For each animation, store a line
	for x in animations.get_animation_list():
		if x == "RESET":
			pass
		else:
			var anim = animations.get_animation(x)
			var offsets: Vector2 = anim.track_get_key_value(0, 0)
			# TODO: Make this line shorter
			file.store_line("sprite_change_offset(\"" + x + "\", " + str(-offsets.x) + ", " + str(-offsets.y) + ");")
	file.close()
	ui_anim.play("CharUpdated")


func _on_CurrentAnimButton_item_selected(index):
	animations.current_animation = current_anim_button.get_item_text(index)


func _on_SpriteSizeCheckBox_toggled(button_pressed):
	if button_pressed:
		sprite_size_spin.editable = true
	else:
		sprite_size_spin.value = 1
		sprite_size_spin.editable = false
