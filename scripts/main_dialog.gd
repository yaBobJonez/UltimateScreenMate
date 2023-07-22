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

extends AcceptDialog

var skinDir
var isQuit

func _ready():
	skinDir = null; isQuit = false
	DisplayServer.window_set_size(Vector2i(0, 0))
	self.add_cancel_button("Quit")
	self.popup_centered()
	doAutoInstall()
	await verifySettings()
	await verifyConfig()
	get_tree().change_scene_to_file("res://scenes/main_window.tscn")

func _process(delta): pass

func doAutoInstall():
	if DirAccess.open(".").dir_exists("autoinst"):
		if Utils.copy_dir("autoinst", "user://") != Error.OK:
			self.title = "Error"
			self.dialog_text = "Default skins installation failed, cannot proceed."
			self.remove_button(self.get_ok_button())
			self.popup_centered(); await self.canceled
		if Utils.remove_dir("autoinst") != Error.OK: return
		DirAccess.open(".").remove("autoinst")

func verifySettings():
	var settings = JSON.parse_string(FileAccess.get_file_as_string("config.json"))
	if settings == null:
		self.title = "Warning"
		self.dialog_text = "You have to configure the program to start."
		self.ok_button_text = "Go to Options"
		self.popup_centered(); await self.confirmed
	match settings:
		{"skin": _, "walking": _, "running": _, ..}:
			skinDir = "user://"+settings["skin"]+"/"
		_:
			self.title = "Warning"
			self.dialog_text = "The config file may be broken, you have to reconfigure the program."
			self.ok_button_text = "Go to Options"
			self.popup_centered(); await self.confirmed

func verifyConfig():
	var data = JSON.parse_string(FileAccess.get_file_as_string(skinDir+"config.json"))
	if data == null:
		self.title = "Error"
		self.dialog_text = "The selected skin could not be loaded, please verify it and reconfigure."
		self.ok_button_text = "Go to Options"
		self.popup_centered(); await self.confirmed
	match data:
		{"title":_,"width":_,"height":_,"scale":_,"idle":_,"dragged":_,"random":_,"actions":_,..}: pass
		_:
			self.title = "Error"
			self.dialog_text = "The selected skin is incomplete, please verify your installation."
			self.ok_button_text = "Go to Options"
			self.popup_centered(); await self.confirmed
	match data["idle"]:
		{"file":_,"fps":_,"duration":_,"frames":[{"id":_,"time":_,..},..]}: pass
		_:
			self.title = "Error"
			self.dialog_text = "The selected skin may be broken: 'idle' is incomplete."
			self.ok_button_text = "Go to Options"
			self.popup_centered(); await self.confirmed
	match data["dragged"]:
		{"file":_,"fps":_,"frames":[{"id":_,"time":_,..},..]}: pass
		_:
			self.title = "Error"
			self.dialog_text = "The selected skin may be broken: 'dragged' is incomplete."
			self.ok_button_text = "Go to Options"
			self.popup_centered(); await self.confirmed
	if data.has("walking"): match data["walking"]:
		{"speed":_,"fps":_,"duration":_,"NW":_,"N":_,"NE":_,"E":_,"SE":_,"S":_,"SW":_,"W":_,..}: pass
		_:
			self.title = "Error"
			self.dialog_text = "The selected skin may be broken: 'walking' is incomplete."
			self.ok_button_text = "Go to Options"
			self.popup_centered(); await self.confirmed
	if data.has("running"): match data["running"]:
		{"speed":_,"fps":_,"duration":_,"NW":_,"N":_,"NE":_,"E":_,"SE":_,"S":_,"SW":_,"W":_,..}: pass
		_:
			self.title = "Error"
			self.dialog_text = "The selected skin may be broken: 'running' is incomplete."
			self.ok_button_text = "Go to Options"
			self.popup_centered(); await self.confirmed

func onConfirm():
	if isQuit: get_tree().quit()
	else: get_tree().change_scene_to_file("res://scenes/settings_window.tscn")

func onCancel(): get_tree().quit()
