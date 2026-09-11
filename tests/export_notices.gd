extends SceneTree
## Include the exact engine build's bundled notices in the distributable.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		quit(1)
		return
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	if not file:
		quit(1)
		return
	file.store_string(Engine.get_license_text())
	file.store_string("\n\nBundled component notices\n" + JSON.stringify(Engine.get_copyright_info(), "  "))
	file.store_string("\n\nBundled license texts\n" + JSON.stringify(Engine.get_license_info(), "  "))
	file.close()
	quit()
