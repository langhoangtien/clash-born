extends Node2D
## Read-only primitives; no interpolation or gameplay in the renderer.
var combat: CombatEngine

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if combat == null: return
	for projectile in combat.projectiles:
		var color := Color(1, 0.75, 0.25) if projectile.payload.type == "attack" else Color(0.65, 0.4, 1)
		draw_circle(projectile.position, 8, color)
		var direction := (projectile.destination - projectile.position).normalized()
		draw_line(projectile.position - direction * 20, projectile.position, color.darkened(0.3), 4)
