tool
extends EditorPlugin

var gdformatter_path = ""
var config_file = "user://gdformatter.cfg"
var files = []
var filesystem_interface := get_editor_interface().get_resource_filesystem()


func _enter_tree() -> void:
	var formatter = get_formatter()
	if formatter != "":
		print("Formatter installed in: %s" % formatter)
	connect("resource_saved", self, "on_file_save")
	add_tool_menu_item("Format Scripts", self, "format_all_scripts")
	add_tool_menu_item("Uninstall GDToolkit", self, "uninstall_gdtoolkit")


func uninstall_gdtoolkit(cb):
	var os = OS.get_name()
	var install_op = []
	if os == "Windows":
		OS.execute("pip", ["uninstall", "gdtoolkit"], true, install_op, true)
	else:
		OS.execute("pip3", ["uninstall", "gdtoolkit"], true, install_op, true)
	pass


func get_formatter() -> String:
	if gdformatter_path != "":
		return gdformatter_path

	var config = get_config()

	if config.has_section_key("formatter", "path"):
		return config.get_value("formatter", "path", gdformatter_path)
	else:
		return set_config(config)
	pass


func get_config():
	var config = ConfigFile.new()
	var err = config.load(config_file)
	if err != OK:
		config.save(config_file)
	return config
	pass


func set_config(config: ConfigFile) -> String:
	var path = install_gdtoolkit()
	config.set_value("formatter", "path", path)
	config.save(config_file)
	return path


func install_gdtoolkit() -> String:
	var os = OS.get_name()
	var install_op = []
	if os == "Windows":
		OS.execute("pip", ["install", "gdtoolkit", "--user"], true, install_op, true)
	else:
		OS.execute("pip3", ["install", "gdtoolkit", "--user"], true, install_op, true)

	var file_regex = RegEx.new()
	file_regex.compile("(\/.*?\\.\\S*)")
	var install_path = install_op[0].split("\n")[0]  # assumption that the first sentence is about gdtoolkit
	var result = file_regex.search(install_path)

	if result:
		var split_res = result.get_string().split("/")
		var gdtoolkit_path = []

		var idx = 0
		for word in split_res:
			idx += 1
			gdtoolkit_path.append(word)
			if word.to_lower() == "python":
				gdtoolkit_path.append(split_res[idx])
				break
		gdtoolkit_path = PoolStringArray(gdtoolkit_path).join("/")
		gdtoolkit_path += "/bin/gdformat"
		print("GDToolkit installation path is: %s" % gdtoolkit_path)
		return gdtoolkit_path
	else:
		print("GDToolkit installation failed, Add the path manually")
		return ""


func _exit_tree() -> void:
	remove_tool_menu_item("Format Scripts")
	remove_tool_menu_item("Uninstall GDToolkit")


func walk_files(dir: EditorFileSystemDirectory) -> void:
	for i in range(dir.get_file_count()):
		if dir.get_file_type(i) == "GDScript":
			files.append(dir.get_file_path(i))
	for j in range(dir.get_subdir_count()):
		walk_files(dir.get_subdir(j))


func format_script(file_path: String) -> void:
	var global_path = ProjectSettings.globalize_path(file_path)
	var array = [global_path]
	var args = PoolStringArray(array)

	var output = []
	var stat = OS.execute(get_formatter(), args, true, output, true)
	print("%s[exit code: %s]" % [output[0], stat])
	filesystem_interface.update_file(file_path)
	filesystem_interface.scan()


func format_all_scripts(cb) -> void:
	files = []
	var filesystem := filesystem_interface.get_filesystem()
	walk_files(filesystem)
	print('\n============================')
	print('Running formatter for files:')
	print('============================\n')
	for script in files:
		format_script(script)


func on_file_save(file: Resource) -> void:
	if filesystem_interface.get_file_type(file.resource_path) == "GDScript":
		print('\n============================')
		print('Running formatter for file:')
		print('============================\n')
		format_script(file.resource_path)
