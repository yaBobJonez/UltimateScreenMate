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

extends Window

var skinsList = []
var config = {}

func _ready():
	refreshSkins()

func _process(delta):
	pass

func onApply():
	if not $PanelBg/VBoxContainer/Skins.is_anything_selected(): return
	config["skin"] = skinsList[$PanelBg/VBoxContainer/Skins.get_selected_items()[0]]
	config["walking"] = $PanelBg/VBoxContainer/OptionsBar/EnableWalkingCheck.button_pressed
	config["running"] = $PanelBg/VBoxContainer/OptionsBar/EnableRunningCheck.button_pressed
	FileAccess.open("config.json", FileAccess.WRITE).store_string(JSON.stringify(config))
func onClose():
	get_tree().change_scene_to_file("res://scenes/main_window.tscn")

func refreshSkins():
	$PanelBg/VBoxContainer/Skins.clear()
	skinsList.clear()
	var exeDir = DirAccess.open("user://")
	for dirName in exeDir.get_directories():
		if not exeDir.file_exists(dirName+"/config.json"): continue
		var data = JSON.parse_string(FileAccess.get_file_as_string("user://"+dirName+"/config.json"))
		var atlas = AtlasTexture.new()
		var iconRelPath = (data["random"]["idle"]["file"]
						   if data["random"].has("idle")
						   else data["random"].values()[0]["file"])
		atlas.atlas = ImageTexture.create_from_image(
			Image.load_from_file("user://%s/%s" % [dirName, iconRelPath])
		)
		atlas.region = Rect2(0, 0, data["width"], data["height"])
		$PanelBg/VBoxContainer/Skins.add_item(data["title"], atlas)
		skinsList.push_back(dirName)
	if skinsList.size() < 2:
		$PanelBg/VBoxContainer/BottomBar/DeleteSkinButton.disabled = true
	config = JSON.parse_string(FileAccess.get_file_as_string("config.json"))
	if config == null: config = {"walking": true, "running": true}
	elif config["skin"] in skinsList:
		$PanelBg/VBoxContainer/Skins.select(skinsList.find(config["skin"]))

func onInstallSkin(): $DirectoryDialog.show()
func onInstallSkinFolderSelected(dir):
	if not DirAccess.open(dir).file_exists("config.json"):
		$NoSkinFoundDialog.show(); return
	if Utils.copy_dir(dir, "user://"+dir.rsplit("/", true, 1)[1]) != Error.OK: return
	if Utils.remove_dir(dir) != Error.OK: return
	DirAccess.remove_absolute(dir)
	refreshSkins()

func onDeleteSkin():
	var index = $PanelBg/VBoxContainer/Skins.get_selected_items()[0]
	var dirToDel = skinsList[index]
	if Utils.remove_dir("user://"+dirToDel) != Error.OK: return
	DirAccess.remove_absolute("user://"+dirToDel)
	skinsList.remove_at(index)
	if config["skin"] == dirToDel:
		config["skin"] = skinsList[0]
		FileAccess.open("config.json", FileAccess.WRITE).store_string(JSON.stringify(config))
	refreshSkins()

func onRunningCheckbox(button_pressed): config["running"] = button_pressed
func onWalkingCheckbox(button_pressed): config["walking"] = button_pressed

func onAbout(): $AboutDialog.popup_centered()
