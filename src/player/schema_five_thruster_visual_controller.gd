extends "res://src/player/ship_thruster_visual_controller.gd"

const REQUIRED_MANIFEST_SCHEMA := 5
const SCHEMA_FIVE_MANIFEST_PATH := (
    "res://assets/runtime/ships/player/small_sci_fi_fighter.manifest.json"
)
const REQUIRED_EFFECT_COUNT := 12
const REQUIRED_THRUSTER_VISUAL_STRATEGY := (
    "source_exact_nozzle_local_enginefire_geometry"
)

func _load_effect_contracts() -> Dictionary:
    var file := FileAccess.open(SCHEMA_FIVE_MANIFEST_PATH, FileAccess.READ)
    if file == null:
        return {}

    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        return {}

    var manifest: Dictionary = parsed
    if int(manifest.get("schema_version", 0)) != REQUIRED_MANIFEST_SCHEMA:
        return {}
    if (
        String(manifest.get("thruster_visual_strategy", ""))
        != REQUIRED_THRUSTER_VISUAL_STRATEGY
    ):
        return {}

    var effects_variant: Variant = manifest.get("thruster_effects", [])
    if not effects_variant is Array:
        return {}
    var effects: Array = effects_variant
    if effects.size() != REQUIRED_EFFECT_COUNT:
        return {}

    var result: Dictionary = {}
    for record_variant: Variant in effects:
        if not record_variant is Dictionary:
            return {}
        var record: Dictionary = record_variant
        var path := StringName(String(record.get("path", "")))
        if path == &"" or result.has(path):
            return {}
        result[path] = record
    return result
