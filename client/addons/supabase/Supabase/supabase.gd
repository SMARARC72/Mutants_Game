@tool
extends Node

const ENVIRONMENT_VARIABLES : String = "supabase/config"

var auth : SupabaseAuth 
var database : SupabaseDatabase
var realtime : SupabaseRealtime
var storage : SupabaseStorage

var debug: bool = false

var config : Dictionary = {
    "supabaseUrl": "",
    "supabaseKey": ""
}

var header : PackedStringArray = [
    "Content-Type: application/json",
    "Accept: application/json"
]

func _ready() -> void:
    load_config()
    load_nodes()

# Load all config settings from ProjectSettings
func load_config() -> void:
    if config.supabaseKey != "" and config.supabaseUrl != "":
        pass
    else:
        var env = ConfigFile.new()
        var env_path := "res://addons/supabase/.env"
        var err = env.load(env_path)
        if err == OK:
            for key in config.keys(): 
                var value : String = env.get_value(ENVIRONMENT_VARIABLES, key, "")
                if value == "":
                    printerr("%s has not a valid value." % key)
                else:
                    config[key] = value
        elif err != ERR_FILE_NOT_FOUND:
            printerr("Unable to read Supabase config at '%s' (error %d)" % [env_path, err])
        elif debug:
            print_debug("Supabase config absent; starting in offline mode.")
    if config.supabaseKey != "":
        header.append("apikey: %s"%[config.supabaseKey])

func load_nodes() -> void:
    auth = SupabaseAuth.new(config, header)
    database = SupabaseDatabase.new(config, header)
    realtime = SupabaseRealtime.new(config)
    storage = SupabaseStorage.new(config)
    add_child(auth)
    add_child(database)
    add_child(realtime)
    add_child(storage)

func set_debug(debugging: bool) -> void:
    debug = debugging

func _print_debug(msg: String) -> void:
    if debug: print_debug(msg)
