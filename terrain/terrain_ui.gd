tool
extends Control

var octaves = 5
var persistence = 0.30
var period = 50
var lacunarity = 2
var water_level = -0.27
var power = 0.341

signal on_value_changed

func _ready():
   $VBoxContainer/octaves/slider.value = octaves
   $VBoxContainer/persistence/slider.value = persistence
   $VBoxContainer/period/slider.value = period
   $VBoxContainer/lacunarity/slider.value = lacunarity
   $VBoxContainer/water_level/slider.value = water_level
   $VBoxContainer/power/slider.value = power

func _on_octaves_value_changed(value):
	$VBoxContainer/octaves/value.text = str(value)
	octaves = value
	emit_signal("on_value_changed")
	pass # Replace with function body.


func _on_persistence_value_changed(value):
	$VBoxContainer/persistence/value.text = str(value)
	persistence = value
	emit_signal("on_value_changed")
	pass # Replace with function body.


func _on_period_value_changed(value):
	$VBoxContainer/period/value.text = str(value)
	period = value
	emit_signal("on_value_changed")
	pass # Replace with function body.


func _on_lacunarity_value_changed(value):
	$VBoxContainer/lacunarity/value.text = str(value)
	lacunarity = value
	emit_signal("on_value_changed")
	pass # Replace with function body.


func _on_water_value_changed(value):
	$VBoxContainer/water_level/value.text = str(value)
	water_level = value
	emit_signal("on_value_changed")
	pass # Replace with function body.


func _on_power_value_changed(value):
	$VBoxContainer/power/value.text = str(value)
	power = value
	emit_signal("on_value_changed")
	pass # Replace with function body.
