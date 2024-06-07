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

extends Node

var scene_mate = preload("res://scenes/main_window.tscn")
var scene_settings = preload("res://scenes/settings_window.tscn")
var matesList = []
signal matesList_removal_toggle(enable)

func add_mate(skinDir):
	var win = Window.new()
	win.borderless = true; win.always_on_top = true; win.unfocusable = true
	win.transparent = true; win.transparent_bg = true
	# Required for the window's viewport to pass through input events!
	win.physics_object_picking = true
	var mate = scene_mate.instantiate()
	mate.skinDir = skinDir
	matesList.append(mate)
	matesList_removal_toggle.connect(mate.onRemovalToggle)
	win.add_child(mate)
	get_tree().root.call_deferred("add_child", win)
	matesList_removal_toggle.emit(len(matesList) < 2)

func remove_mate(margCont):
	matesList.erase(margCont)
	margCont.get_parent().queue_free()
	matesList_removal_toggle.emit(len(matesList) < 2)

func open_settings(skinDir):
	var options = scene_settings.instantiate()
	options.skinDir = skinDir
	get_tree().root.call_deferred("add_child", options)

func copy_dir(from: String, to: String) -> Error:
	var fromD = DirAccess.open(from)
	if not fromD: return Error.FAILED
	if not DirAccess.dir_exists_absolute(to): DirAccess.make_dir_recursive_absolute(to)
	fromD.list_dir_begin()
	var next = fromD.get_next()
	while next != "":
		if from.right(1) == "/": from = from.left(from.length()-1)
		if to.right(1) == "/": to = to.left(to.length()-1)
		if fromD.current_is_dir(): return copy_dir(from+"/"+next, to+"/"+next)
		else: if fromD.copy(from+"/"+next, to+"/"+next) != Error.OK: return Error.FAILED
		next = fromD.get_next()
	return Error.OK
func remove_dir(from: String):
	var fromD = DirAccess.open(from)
	if not fromD: return Error.FAILED
	fromD.list_dir_begin()
	var next = fromD.get_next()
	while next != "":
		if from.right(1) == "/": from = from.left(from.length()-1)
		if fromD.current_is_dir():
			if remove_dir(from+"/"+next) != Error.OK: return Error.FAILED
		if DirAccess.remove_absolute(fromD.get_current_dir()+"/"+next) != Error.OK: return Error.FAILED
		next = fromD.get_next()
	return Error.OK
