class_name MatchIconCatalog
extends RefCounted
## Lightweight generated UI icons; no imported portrait atlas is required.
static var _heroes: Dictionary = {}
static var _skills: Dictionary = {}

static func _texture(key: String, hero: bool) -> Texture2D:
	var cache := _heroes if hero else _skills
	if cache.has(key): return cache[key]
	var image := Image.create(72, 72, false, Image.FORMAT_RGBA8)
	var palette := [Color("36b7ff"), Color("f45b75"), Color("b16cff"), Color("f3a840"), Color("4bd48b"), Color("e9d65e")]
	var color: Color = palette[absi(key.hash()) % palette.size()]
	var center := Vector2(36, 36)
	for y in range(72):
		for x in range(72):
			var point := Vector2(x, y)
			var distance := point.distance_to(center)
			var pixel := Color("152131") if distance < 34 else Color.TRANSPARENT
			if hero:
				if point.distance_to(Vector2(36, 27)) < 14 or (absf(x - 36) < 21 and y >= 38 and y <= 62): pixel = color
				if absf(x - 36) < 3 and y < 18: pixel = color.lightened(0.35)
			else:
				if distance < 23 or absf(x - 36) < 4 or absf(y - 36) < 4: pixel = color
			image.set_pixel(x, y, pixel)
	var texture := ImageTexture.create_from_image(image)
	cache[key] = texture
	return texture

static func hero_icon(passive_id: String) -> Texture2D:
	return _texture(passive_id, true)

static func skill_icon(passive_id: String) -> Texture2D:
	return _texture(passive_id, false)
