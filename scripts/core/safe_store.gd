class_name SafeStore
extends RefCounted
## Robust JSON persistence:
## - payload wrapped with a version and an MD5 checksum;
## - written to a temporary file first, then the previous good file becomes `.bak`;
## - on load, a missing/corrupted main file falls back to the backup, then to defaults.

const STATUS_OK := "ok"
const STATUS_NEW := "new"
const STATUS_RECOVERED := "recovered"  # main file was bad, backup used
const STATUS_RESET := "reset"  # both bad, defaults used


static func save(path: String, data: Dictionary) -> bool:
	var payload := JSON.stringify(data)
	var wrapped := JSON.stringify({"v": 1, "sum": payload.md5_text(), "data": payload})
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("SafeStore: cannot write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(wrapped)
	f.close()
	if FileAccess.file_exists(path) and _read_valid(path) != null:
		DirAccess.copy_absolute(path, path + ".bak")
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_warning("SafeStore: rename failed (%s)" % error_string(err))
		return false
	return true


## Returns {"data": Dictionary, "status": String}.
static func read(path: String, defaults: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"):
		return {"data": defaults.duplicate(true), "status": STATUS_NEW}
	var main = _read_valid(path)
	if main != null:
		return {"data": main, "status": STATUS_OK}
	var bak = _read_valid(path + ".bak")
	if bak != null:
		push_warning("SafeStore: %s corrupted, restored from backup" % path)
		return {"data": bak, "status": STATUS_RECOVERED}
	push_warning("SafeStore: %s and backup unreadable, using defaults" % path)
	return {"data": defaults.duplicate(true), "status": STATUS_RESET}


static func erase(path: String) -> void:
	for p in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


static func _read_valid(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var outer: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (outer is Dictionary) or not outer.has("data") or not outer.has("sum"):
		return null
	var payload: String = outer.data
	if payload.md5_text() != outer.sum:
		return null
	var data: Variant = JSON.parse_string(payload)
	return data if data is Dictionary else null
