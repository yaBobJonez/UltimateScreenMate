#	Copyright © 2023 Mykhailo Stetsiuk
#
#	This file is part of Ultimate ScreenMate.
#
#	Ultimate ScreenMate is free software: you can redistribute it and/or modify it under
#	the terms of the GNU General Public License as published by the Free Software Foundation,
#	either version 3 of the License, or (at your option) any later version.
#
#	Ultimate ScreenMate is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
#	without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#	See the GNU General Public License for more details.
#
#	You should have received a copy of the GNU General Public License along with Ultimate ScreenMate.
#	If not, see <https://www.gnu.org/licenses/>. 

extends MarginContainer

var rng = RandomNumberGenerator.new()
var targetPosition
var skinDir
var data
var state = "idle"
var states = []
var action = 0
var actions = [null]
var isDragging = []
var isFollowing = []
var isLooping = false

func _ready():
	moveTargetNewRandom()
	loadSettings()
	loadConfig()
	loadLocales(skinDir+"translate.csv")
	$MoveTimer.connect("timeout", moveSprite)

func _process(delta):
	if not isDragging.is_empty():
		get_window().position += Vector2i(get_global_mouse_position()) - get_window().size/2
	elif not isFollowing.is_empty():
		var cursorLocation = get_global_mouse_position() + Vector2(get_window().position - get_window().size/2)
		if cursorLocation != targetPosition:
			$MoveTimer.paused = false
			targetPosition = cursorLocation

func loadSettings():
	var settings = JSON.parse_string(FileAccess.get_file_as_string("config.json"))
	skinDir = "user://"+settings["skin"]+"/"
	data = JSON.parse_string(FileAccess.get_file_as_string(skinDir+"config.json"))
	if settings["walking"] and data.has("walking"): states.push_back("walking")
	if settings["running"] and data.has("running"): states.push_back("running")

func loadConfig():
	$Sprite.scale = Vector2(data["scale"], data["scale"])
	get_window().size = Vector2(data["width"]*data["scale"], data["height"]*data["scale"])
	get_window().position = DisplayServer.screen_get_size()/2 - get_window().size/2
	$Sprite/Area2D/Collision.shape.extents = get_window().size * 0.75
	$Sprite.sprite_frames = SpriteFrames.new()
	$Sprite.sprite_frames.add_animation("idle")
	$Sprite.sprite_frames.set_animation_loop("idle", true)
	$Sprite.sprite_frames.set_animation_speed("idle", data["idle"]["fps"])
	loadAnimFrames("idle", data["idle"], data["width"], data["height"])
	$Sprite.sprite_frames.add_animation("dragged")
	$Sprite.sprite_frames.set_animation_loop("dragged", true)
	$Sprite.sprite_frames.set_animation_speed("dragged", data["dragged"]["fps"])
	loadAnimFrames("dragged", data["dragged"], data["width"], data["height"])
	if data.has("walking"):
		for d in ["NW", "N", "NE", "E", "SE", "S", "SW", "W"]:
			$Sprite.sprite_frames.add_animation("walking_"+d)
			$Sprite.sprite_frames.set_animation_loop("walking_"+d, true)
			$Sprite.sprite_frames.set_animation_speed("walking_"+d, data["walking"]["fps"])
			loadAnimFrames("walking_"+d, data["walking"][d], data["width"], data["height"])
	if data.has("running"):
		for d in ["NW", "N", "NE", "E", "SE", "S", "SW", "W"]:
			$Sprite.sprite_frames.add_animation("running_"+d)
			$Sprite.sprite_frames.set_animation_loop("running_"+d, true)
			$Sprite.sprite_frames.set_animation_speed("running_"+d, data["running"]["fps"])
			loadAnimFrames("running_"+d, data["running"][d], data["width"], data["height"])
	for name in data["random"]:
		$Sprite.sprite_frames.add_animation(name)
		var rAnim = data["random"][name]
		$Sprite.sprite_frames.set_animation_loop(name, rAnim["duration"] != -1)
		$Sprite.sprite_frames.set_animation_speed(name, rAnim["fps"])
		loadAnimFrames(name, rAnim, data["width"], data["height"])
		states.append(name)
	for name in data["actions"]:
		$Sprite.sprite_frames.add_animation("act_"+name)
		var rAnim = data["actions"][name]
		$Sprite.sprite_frames.set_animation_loop("act_"+name, rAnim["duration"] != -1)
		$Sprite.sprite_frames.set_animation_speed("act_"+name, rAnim["fps"])
		loadAnimFrames("act_"+name, rAnim, data["width"], data["height"])
		actions.push_back(name); $ActionsMenu.add_item(name)
	$Sprite.play("idle")
	$StateSwitchTimer.start(data["idle"]["duration"])
func loadAnimFrames(anim, datum, width, height):
	var sheet = ImageTexture.create_from_image(Image.load_from_file(skinDir+datum["file"]))
	var frames = []
	for row in range(sheet.get_height()/height): for col in range(sheet.get_width()/width):
		var atlas = AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(col*width, row*height, width, height)
		frames.push_back(atlas)
	for item in datum["frames"]:
		if item is Array: for n in range(item[0]): for arrItem in item.slice(1, item.size()):
			$Sprite.sprite_frames.add_frame(anim, frames[arrItem["id"]], arrItem["time"])
		else: $Sprite.sprite_frames.add_frame(anim, frames[item["id"]], item["time"])

func loadLocales(path):
	var csv = []; var f = FileAccess.open(path, FileAccess.READ)
	while not f.eof_reached(): var csvline = f.get_csv_line(); if csvline[0] != "": csv.append(csvline)
	for col in range(1, csv[0].size()):
		var tr = TranslationServer.get_translation_object(csv[0][col])
		if tr == null:
			tr = Translation.new()
			tr.locale = csv[0][col]
		for row in range(1, csv.size()): tr.add_message(csv[row][0], csv[row][col])
		TranslationServer.add_translation(tr)
	TranslationServer.set_locale(TranslationServer.get_locale())

func moveTargetNewRandom():
	var x = rng.randi_range(20, DisplayServer.screen_get_size().x - get_window().size.x - 20)
	var y = rng.randi_range(20, DisplayServer.screen_get_size().y - get_window().size.y - 20)
	targetPosition = Vector2(x, y)
func moveSprite():
	if isDragging.is_empty():
		if !isFollowing.is_empty(): moveSpritePer("walking", data["walking"]["speed"])
		elif state in ["walking", "running"]: moveSpritePer(state, data[state]["speed"])
func moveSpritePer(prefix, speed):
	var directionV2 = targetPosition - Vector2(get_window().position)
	var whereTo = Vector2i(directionV2.normalized() * speed)
	var n = -0.4 * speed; var p = 0.4 * speed
	if whereTo.x <= n and whereTo.y <= n: $Sprite.play(prefix+"_NW")
	elif whereTo.x >= p and whereTo.y <= n: $Sprite.play(prefix+"_NE")
	elif whereTo.x <= n and whereTo.y >= p: $Sprite.play(prefix+"_SW")
	elif whereTo.x >= p and whereTo.y >= p: $Sprite.play(prefix+"_SE")
	elif whereTo.y <= n: $Sprite.play(prefix+"_N")
	elif whereTo.x <= n: $Sprite.play(prefix+"_W")
	elif whereTo.y >= p: $Sprite.play(prefix+"_S")
	elif whereTo.x >= p: $Sprite.play(prefix+"_E")
	get_window().position += whereTo
	if directionV2.length_squared() < speed*speed:
		if not isFollowing.is_empty():
			$Sprite.play("idle")
			$MoveTimer.paused = true
		else: moveTargetNewRandom()

func onSpriteInputEvent(viewport, event, shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed:
			get_tree().quit(0)
		elif event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
			$OptionsMenu.popup_on_parent(get_window().get_visible_rect())
			onFreeze()
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if not isDragging.is_empty():
				$Sprite.play(isDragging[0]); $Sprite.set_frame_and_progress(isDragging[1], isDragging[2])
				$StateSwitchTimer.paused = false
				isDragging.clear()
			else:
				$ActionsMenu.popup_on_parent(get_window().get_visible_rect())
				onFreeze()
	elif event is InputEventMouseMotion:
		if event.button_mask == MOUSE_BUTTON_LEFT and isDragging.is_empty():
			isDragging = [$Sprite.animation, $Sprite.frame, $Sprite.frame_progress]
			$Sprite.play("dragged"); $StateSwitchTimer.paused = true

func changeState():
	print("Attempting to change...")
	if not isLooping:
		if states.size() < 1: return
		var next = states.pick_random()
		if state != "_ACTION": states.push_back(state)
		states.erase(next); state = next
		action = 0
	if action != 0:
		$Sprite.play("act_"+actions[action])
		if data["actions"][actions[action]]["duration"] != -1:
			$StateSwitchTimer.start(data["actions"][actions[action]]["duration"])
		else: $StateSwitchTimer.stop()
	else:
		if state not in ["walking", "running"]: $Sprite.play(state)
		if state in ["idle", "walking", "running"]: $StateSwitchTimer.start(data[state]["duration"])
		elif data["random"][state]["duration"] != -1:
			$StateSwitchTimer.start(data["random"][state]["duration"])
		else: $StateSwitchTimer.stop()
	print("CHANGED STATE TO "+state)

func onActionChosen(index):
	if index == 0: return
	if state != "_ACTION": states.push_back(state); state = "_ACTION"
	action = index
	$Sprite.play("act_"+actions[action])
	if data["actions"][actions[action]]["duration"] != -1:
		$StateSwitchTimer.start(data["actions"][actions[action]]["duration"])
	else: $StateSwitchTimer.stop()

func onFreeze():
	$MoveTimer.paused = true
	$StateSwitchTimer.paused = true
func onUnfreeze():
	$MoveTimer.paused = false
	$StateSwitchTimer.paused = false

func onOptionChosen(id):
	var index = $OptionsMenu.get_item_index(id)
	if id == 1:
		$OptionsMenu.set_item_text(index, "Stay here" if isFollowing.is_empty() else "Follow me")
		$StateSwitchTimer.paused = isFollowing.is_empty()
		if isFollowing.is_empty():
			isFollowing = [$Sprite.animation, $Sprite.frame, $Sprite.frame_progress]
			for i in range(2, 5+1):
				$OptionsMenu.set_item_disabled($OptionsMenu.get_item_index(i), true)
		else:
			$Sprite.play(isFollowing[0]); $Sprite.set_frame_and_progress(isFollowing[1], isFollowing[2])
			for i in range(2, 5+1):
				$OptionsMenu.set_item_disabled($OptionsMenu.get_item_index(i), false)
			if states.size() < 2: $OptionsMenu.set_item_disabled($OptionsMenu.get_item_index(3), true)
			isFollowing.clear()
	elif id == 2:
		changeState()
	elif id == 3:
		var unwanted = state
		changeState(); states.erase(unwanted)
		if(states.size() < 1): $OptionsMenu.set_item_disabled(index, true)
	elif id == 4:
		$Sprite.frame = 0
		if state in ["idle", "walking", "running"]: $StateSwitchTimer.start(data[state]["duration"])
		elif state == "_ACTION": onActionChosen(action)
		elif data["random"][state]["duration"] != -1:
			$StateSwitchTimer.start(data["random"][state]["duration"])
		else: $StateSwitchTimer.stop()
	elif id == 5:
		isLooping = !isLooping
		$OptionsMenu.set_item_text(index, "Do whatever" if isLooping else "Do just that")
	elif id == 101:
		DisplayServer.window_set_size(Vector2i(0, 0))
		get_tree().change_scene_to_file("res://scenes/settings_window.tscn")
	elif id == 102:
		get_tree().quit(0)
