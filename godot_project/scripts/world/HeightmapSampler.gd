extends RefCounted
class_name HeightmapSampler
## Leser originalspillets nøyaktige 1:1 heightmap (.hm) ekstrahert fra hvert bretts .cct-fil.
## Sikrer millimeter-presis gulvhøyde (Y) for Pinky og alle NPC-er/fiender selv inne i grotter og under tak!

var width: int = 0
var height: int = 0
var tl_x: float = 0.0
var tl_y: float = 0.0
var br_x: float = 0.0
var br_y: float = 0.0
var grid: PackedFloat32Array = PackedFloat32Array()
var valid: bool = false


func load_level(level_id: String) -> bool:
	valid = false
	var path := "res://data/heightmaps/%s.hm" % level_id
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return false
	width = f.get_16()
	height = f.get_16()
	tl_x = f.get_float()
	tl_y = f.get_float()
	br_x = f.get_float()
	br_y = f.get_float()
	var byte_count := width * height * 4
	var raw := f.get_buffer(byte_count)
	f.close()
	if raw.size() < byte_count:
		return false
	grid = raw.to_float32_array()
	valid = (width > 0 and height > 0 and grid.size() == width * height)
	return valid


## Returnerer nøyaktig gulvhøyde i Godot-meter (eller -9999.0 hvis utenfor gyldig område).
func sample_y(godot_x: float, godot_z: float) -> float:
	if not valid:
		return -9999.0
	var sw_x := godot_x * 10.0
	var sw_y := -godot_z * 10.0
	var dw := br_x - tl_x
	var dh := tl_y - br_y
	if absf(dw) < 0.001 or absf(dh) < 0.001:
		return -9999.0
	var rx := (sw_x - tl_x) / dw
	var ry := (tl_y - sw_y) / dh
	if rx < 0.0 or rx > 1.0 or ry < 0.0 or ry > 1.0:
		return -9999.0

	var fx := rx * float(width - 1)
	var fy := ry * float(height - 1)
	var x0 := clampi(int(floorf(fx)), 0, width - 1)
	var y0 := clampi(int(floorf(fy)), 0, height - 1)
	var x1 := mini(x0 + 1, width - 1)
	var y1 := mini(y0 + 1, height - 1)
	var tx := fx - float(x0)
	var ty := fy - float(y0)

	var h00 := grid[y0 * width + x0]
	var h10 := grid[y0 * width + x1]
	var h01 := grid[y1 * width + x0]
	var h11 := grid[y1 * width + x1]

	# Hvis alle 4 hjørner er gyldige (ikke tomrom), bruk bilineær interpolasjon nøyaktig som heightMap.ls
	if h00 > -5000.0 and h10 > -5000.0 and h01 > -5000.0 and h11 > -5000.0:
		# Unngå å interpolere tvers over bratte klipper (> 2.0m sprang)
		var mx := maxf(maxf(h00, h10), maxf(h01, h11))
		var mn := minf(minf(h00, h10), minf(h01, h11))
		if mx - mn < 2.0:
			var a := lerpf(h00, h10, tx)
			var b := lerpf(h01, h11, tx)
			return lerpf(a, b, ty)
	# Ellers velg nærmeste gyldige piksel
	var best := grid[clampi(int(roundf(fy)), 0, height - 1) * width + clampi(int(roundf(fx)), 0, width - 1)]
	if best > -5000.0:
		return best
	for v in [h00, h10, h01, h11]:
		if v > -5000.0:
			return v
	return -9999.0
