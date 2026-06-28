@tool
extends EditorImportPlugin

# LOCAL MOD (Mutants_Game, Cluster 2): upstream claims the generic ".csv"/".tsv" extensions at
# priority 2.0, which OUTRANKS and hijacks Godot's built-in Translation importer. The project
# ships a translation CSV (addons/maaacks_game_template/base/translations/menus_translations.csv)
# that MUST stay on the Translation importer. So this fork recognizes a dedicated ".csvdata"
# extension only (mirrors the inkgd ".inkjson" precedent in THIRD_PARTY.md) and drops the
# priority below the built-in. Plain ".csv" files are therefore left untouched. The creature
# registry itself lives at docs/creature_registry.csv (OUTSIDE res://) and is converted to the
# committed res://catalog/species/species_db.tres by tools/gen_species_db.mjs at build time; this
# importer is the in-editor path for a dev who copies the registry in as a *.csvdata file.

enum Presets { CSV, CSV_HEADER, TSV, TSV_HEADER }
enum Delimiters { COMMA, TAB, SEMICOLON }


func _get_importer_name():
	return "com.timothyqiu.godot-csv-importer"


func _get_visible_name():
	return "CSV Data"


func _get_priority():
	# LOCAL MOD: below the built-in Translation importer so plain *.csv stays a translation.
	return 1.0


func _get_import_order():
	return 0


func _get_recognized_extensions():
	# LOCAL MOD: dedicated extension so we never hijack plain *.csv / *.tsv files.
	return ["csvdata"]


func _get_save_extension():
	return "res"


func _get_resource_type():
	return "Resource"


func _get_preset_count():
	return Presets.size()


func _get_preset_name(preset):
	match preset:
		Presets.CSV:
			return "CSV"
		Presets.CSV_HEADER:
			return "CSV with headers"
		Presets.TSV:
			return "TSV"
		Presets.TSV_HEADER:
			return "TSV with headers"
		_:
			return "Unknown"


func _get_import_options(_path, preset):
	var delimiter = Delimiters.COMMA
	var headers = false
	match preset:
		Presets.CSV_HEADER:
			headers = true
		Presets.TSV:
			delimiter = Delimiters.TAB
		Presets.TSV_HEADER:
			delimiter = Delimiters.TAB
			headers = true

	return [
		{name = "delimiter", default_value = delimiter, property_hint = PROPERTY_HINT_ENUM, hint_string = "Comma,Tab,Semicolon"},
		{name = "headers", default_value = headers},
		{name = "detect_numbers", default_value = false},
		{name = "force_float", default_value = true},
		{name = "detect_booleans", default_value = false},
	]


func _get_option_visibility(_path, option, options):
	return true  # Godot does not update the visibility immediately


func _import(source_file, save_path, options, platform_variants, gen_files):
	var delim: String
	match options.delimiter:
		Delimiters.COMMA:
			delim = ","
		Delimiters.TAB:
			delim = "\t"
		Delimiters.SEMICOLON:
			delim = ";"

	var file = FileAccess.open(source_file, FileAccess.READ)
	if not file:
		printerr("Failed to open file: ", source_file)
		return FAILED

	var lines = []
	while not file.eof_reached():
		var line = file.get_csv_line(delim)
		if not options.headers or lines.size() > 0:
			var detected := []
			for field in line:
				if options.detect_numbers and field.is_valid_float():
					if not options.force_float and field.is_valid_int():
						detected.append(int(field))
						continue
					detected.append(float(field))
					continue
				if options.detect_booleans:
					if field.nocasecmp_to("false") == 0:
						detected.append(false)
						continue
					if field.nocasecmp_to("true") == 0:
						detected.append(true)
						continue
				detected.append(field)
			lines.append(detected)
		else:
			lines.append(line)
	file.close()

	# Remove trailing empty line
	if not lines.is_empty() and lines.back().size() == 1 and lines.back()[0] == "":
		lines.pop_back()

	var data = preload("csv_data.gd").new()

	if options.headers:
		if lines.is_empty():
			printerr("Can't find header in empty file")
			return ERR_PARSE_ERROR

		var headers = lines[0]
		for i in range(1, lines.size()):
			var fields = lines[i]
			if fields.size() > headers.size():
				printerr("Line %d has more fields than headers" % i)
				return ERR_PARSE_ERROR
			var dict = {}
			for j in headers.size():
				var name = headers[j]
				var value = fields[j] if j < fields.size() else null
				dict[name] = value
			data.records.append(dict)
	else:
		data.records = lines

	var filename = save_path + "." + _get_save_extension()
	var err = ResourceSaver.save(data, filename)
	if err != OK:
		printerr("Failed to save resource: ", err)
	return err
