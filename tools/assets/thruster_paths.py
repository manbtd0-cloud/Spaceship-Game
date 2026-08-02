from __future__ import annotations

Point3 = tuple[float, float, float]


def classify_effect_name(group: str, position: Point3) -> str:
    side = "Left" if position[0] < 0.0 else "Right"
    if group == "Main":
        return f"ThrusterEffects/MainEffects/Main{side}Effect"
    if group == "Retro":
        return f"ThrusterEffects/RetroEffects/Retro{side}Effect"
    if group in {"FrontUpper", "RearUpper", "RearLower", "FrontLower"}:
        return f"ThrusterEffects/ManeuverEffects/{group}{side}Effect"
    raise ValueError(f"unsupported effect group: {group}")


def effect_path_to_socket_path(effect_path: str) -> str:
    prefix_mapping = {
        "ThrusterEffects/MainEffects/": "Thrusters/Main/",
        "ThrusterEffects/RetroEffects/": "Thrusters/Retro/",
        "ThrusterEffects/ManeuverEffects/": "Thrusters/Maneuver/",
    }
    for effect_prefix, socket_prefix in prefix_mapping.items():
        if effect_path.startswith(effect_prefix):
            leaf = effect_path.removeprefix(effect_prefix)
            if not leaf.endswith("Effect"):
                break
            socket_leaf = leaf.removesuffix("Effect")
            if not socket_leaf:
                break
            return f"{socket_prefix}{socket_leaf}"
    raise ValueError(f"unsupported effect path: {effect_path}")
