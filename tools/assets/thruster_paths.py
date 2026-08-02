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
