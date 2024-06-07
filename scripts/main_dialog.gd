#	Copyright © 2023–2024 Mykhailo Stetsiuk
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

extends AcceptDialog

var settings
var isQuit

func _ready():
	isQuit = true
	get_tree().root.min_size = Vector2i(0, 0)
	get_tree().root.size = Vector2i(0, 0)
	self.add_cancel_button("Quit")
	doAutoInstall()
	await verifySettings()
	isQuit = false
	for mateConf in settings:
		Utils.add_mate(mateConf["skin"])

func _process(delta): pass

func doAutoInstall():
	if DirAccess.open(".").dir_exists("autoinst"):
		if Utils.copy_dir("autoinst", "user://") != Error.OK:
			self.title = "Error"
			self.dialog_text = "CANT_INSTALL_DEFAULT_SKINS"
			self.remove_button(self.get_ok_button())
			self.popup_centered(); await self.canceled
		if Utils.remove_dir("autoinst") != Error.OK: return
		DirAccess.open(".").remove("autoinst")

func verifySettings():
	settings = JSON.parse_string(FileAccess.get_file_as_string("config.json"))
	if settings == null:
		self.title = "Warning"
		self.dialog_text = "CONFIG_REQUIRED"
		self.ok_button_text = "Go to Options"
		self.popup_centered(); await self.confirmed
	if typeof(settings) != TYPE_ARRAY:
		self.title = "Error"
		self.dialog_text = "BROKEN_CONFIG_RECONFIGURE"
		self.ok_button_text = "Go to Options"
		self.popup_centered(); await self.confirmed
	for mateSetting in settings: match mateSetting:
		{"skin": _, ..}:
			await verifyConfig(mateSetting["skin"])
		_:
			self.title = "Warning"
			self.dialog_text = "BROKEN_CONFIG_RECONFIGURE"
			self.ok_button_text = "Go to Options"
			self.popup_centered(); await self.confirmed

func verifyConfig(skinDir):
	var data = JSON.parse_string(FileAccess.get_file_as_string(skinDir+"config.json"))
	if data == null:
		self.title = "Error"
		self.dialog_text = "CANT_LOAD_SKIN"
		self.ok_button_text = "Go to Options"
		self.popup_centered(); await self.confirmed
	match data:
		{"title":_,"width":_,"height":_,"scale":_,"dragged":_,"random":_,"actions":_,..}: pass
		_:
			self.title = "Error"
			self.dialog_text = "INCOMPLETE_SKIN"
			self.ok_button_text = "Go to Options"
			self.popup_centered(); await self.confirmed
	if data.has("movements") and data["movements"].has("idle"): match data["movements"]["idle"]:
		{"file":_,"fps":_,"duration":_,"frames":[{"id":_,"time":_,..},..]}: pass
		_:
			self.title = "Error"
			self.dialog_text = "BROKEN_SKIN_IDLE"
			self.ok_button_text = "Go to Options"
			self.popup_centered(); await self.confirmed
	match data["dragged"]:
		{"file":_,"fps":_,"frames":[{"id":_,"time":_,..},..]}: pass
		_:
			self.title = "Error"
			self.dialog_text = "BROKEN_SKIN_DRAGGED"
			self.ok_button_text = "Go to Options"
			self.popup_centered(); await self.confirmed
	if data.has("walking"): match data["walking"]:
		{"speed":_,"fps":_,"duration":_,"NW":_,"N":_,"NE":_,"E":_,"SE":_,"S":_,"SW":_,"W":_,..}: pass
		_:
			self.title = "Error"
			self.dialog_text = "BROKEN_SKIN_WALKING"
			self.ok_button_text = "Go to Options"
			self.popup_centered(); await self.confirmed
	if data.has("running"): match data["running"]:
		{"speed":_,"fps":_,"duration":_,"NW":_,"N":_,"NE":_,"E":_,"SE":_,"S":_,"SW":_,"W":_,..}: pass
		_:
			self.title = "Error"
			self.dialog_text = "BROKEN_SKIN_RUNNING"
			self.ok_button_text = "Go to Options"
			self.popup_centered(); await self.confirmed

func onConfirm():
	if isQuit: get_tree().quit()
	else: get_tree().change_scene_to_file("res://scenes/settings_window.tscn")

func onCancel(): get_tree().quit()
