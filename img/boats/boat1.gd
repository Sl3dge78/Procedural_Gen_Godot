extends KinematicBody2D

export var speed = 5.0

func _ready():
	pass
	
func _process(delta):
	var movement = Vector2(0,0)
	if Input.is_action_pressed("ui_left"):
		$Sprite/AnimationPlayer.play("MoveL")
		movement.x -= 1
	elif Input.is_action_pressed("ui_right"):
		$Sprite/AnimationPlayer.play("MoveR")
		movement.x += 1
	if Input.is_action_pressed("ui_down"):
		movement.y += 1
	elif Input.is_action_pressed("ui_up"):
		movement.y -= 1
		
	movement = movement.normalized() * speed
	
	move_and_slide(movement)
