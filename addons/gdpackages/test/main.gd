extends Node2D
## Entry point for the GDPackages-based demo RPG system

func _ready() -> void:
	print("\n========== GDPackages RPG System Demo ==========\n")
	print("Initializing packages...")
	
	# Loading all packages from the directory
	PackageManager.load_packages_in_directory("res://addons/gdpackages/test/packages/")
	
	print("\n========== System Initialized ==========")
	print("\nControls:")
	print("  [1] - Attack self")
	print("  [2] - Heal self")
	print("  [3] - Apply freeze")
	print("  [4] - Apply poison")
	print("\n=========================================\n")
	
	# Give a small delay before initializing package switcher
	await get_tree().process_frame
	_initialize_package_connections()
	_add_packages_to_scene()

func _add_packages_to_scene() -> void:
	## Adding packages to the scene tree so they receive input events
	print("[DEBUG] Starting to add packages to the scene")
	print("[DEBUG] Total packages: ", PackageManager.packages.keys().size())
	for package_name in PackageManager.packages.keys():
		var package = PackageManager.get_package(package_name)
		print("[DEBUG] Checking package: %s (null=%s, has_parent=%s)" % [package_name, package == null, package and package.get_parent() != null])
		if package and not package.get_parent():
			add_child(package)
			print("[SCENE] Package %s added to scene" % package_name)

func _initialize_package_connections() -> void:
	## Setting up connection between packages after loading
	print("[DEBUG] Starting initialization of connections between packages")
	
	var health_pkg = PackageManager.get_package("health_package")
	var weapon_pkg = PackageManager.get_package("weapon_package")
	var status_pkg = PackageManager.get_package("status_effect_package")
	var player_pkg = PackageManager.get_package("player_package")
	
	print("[DEBUG] health_pkg = %s" % ("null" if health_pkg == null else "ok"))
	print("[DEBUG] weapon_pkg = %s" % ("null" if weapon_pkg == null else "ok"))
	print("[DEBUG] status_pkg = %s" % ("null" if status_pkg == null else "ok"))
	print("[DEBUG] player_pkg = %s" % ("null" if player_pkg == null else "ok"))
	
	if not health_pkg or not weapon_pkg or not status_pkg or not player_pkg:
		print("Error: not all packages loaded!")
		return
	
	# All connections are now established through events, no need for direct calls
	print("[INIT] Connections between packages established via events")

func _get_package_core(package: Package):
	## Helper function to get the package core
	for child in package.get_children():
		if child.get_script():
			# Check if this is the package core
			if "set_package_reference" in child:
				return child
	return null
