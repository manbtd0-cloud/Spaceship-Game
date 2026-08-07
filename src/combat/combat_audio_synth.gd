class_name CombatAudioSynth
extends RefCounted

const SAMPLE_RATE := 44100
const TAU_F := TAU

enum Voice {
    PULSE,
    SHIELD_HIT,
    SHIELD_BREAK,
    HULL_HIT,
    THRUSTER,
    EXPLOSION,
    DEBRIS,
}

static func build_streams() -> Dictionary:
    return {
        &"pulse": _make_stream(Voice.PULSE, 0.18),
        &"shield_hit": _make_stream(Voice.SHIELD_HIT, 0.26),
        &"shield_break": _make_stream(Voice.SHIELD_BREAK, 0.58),
        &"hull_hit": _make_stream(Voice.HULL_HIT, 0.24),
        &"thruster": _make_stream(Voice.THRUSTER, 2.0),
        &"explosion": _make_stream(Voice.EXPLOSION, 1.35),
        &"debris": _make_stream(Voice.DEBRIS, 0.72),
    }

static func _make_stream(voice: Voice, duration_seconds: float) -> AudioStreamWAV:
    var frame_count := maxi(int(round(duration_seconds * SAMPLE_RATE)), 1)
    var pcm := PackedByteArray()
    pcm.resize(frame_count * 2)
    for index: int in range(frame_count):
        var t := float(index) / float(SAMPLE_RATE)
        var x := float(index) / float(maxi(frame_count - 1, 1))
        var sample := _sample_voice(voice, t, x)
        pcm.encode_s16(index * 2, int(round(clampf(sample, -1.0, 1.0) * 32760.0)))

    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = SAMPLE_RATE
    stream.stereo = false
    stream.data = pcm
    return stream

static func _sample_voice(voice: Voice, t: float, x: float) -> float:
    var noise := _noise(t)
    match voice:
        Voice.PULSE:
            var envelope := pow(1.0 - x, 2.8)
            var crack := sin(TAU_F * (520.0 * t - 150.0 * t * t))
            var body := sin(TAU_F * 82.0 * t)
            return (0.52 * crack + 0.42 * body + 0.22 * noise) * envelope
        Voice.SHIELD_HIT:
            var envelope := exp(-8.0 * x)
            var ring := sin(TAU_F * (1150.0 - 420.0 * x) * t)
            var body := sin(TAU_F * 165.0 * t)
            return (0.58 * ring + 0.28 * body + 0.30 * noise) * envelope
        Voice.SHIELD_BREAK:
            var envelope := pow(1.0 - x, 1.6)
            var sweep_frequency := lerpf(1450.0, 130.0, x)
            var sweep := sin(TAU_F * sweep_frequency * t)
            var low := sin(TAU_F * 72.0 * t)
            return (0.44 * sweep + 0.40 * low + 0.33 * noise) * envelope
        Voice.HULL_HIT:
            var envelope := exp(-10.0 * x)
            var metal := sin(TAU_F * 305.0 * t) * sin(TAU_F * 41.0 * t + 0.3)
            var thud := sin(TAU_F * 92.0 * t)
            return (0.35 * metal + 0.48 * thud + 0.34 * noise) * envelope
        Voice.THRUSTER:
            var seam := sin(PI * x)
            var low := sin(TAU_F * 54.0 * t)
            var turbine := sin(TAU_F * 118.0 * t + 0.8 * sin(TAU_F * 2.2 * t))
            return (0.52 * low + 0.20 * turbine + 0.30 * noise) * (0.78 + 0.22 * seam)
        Voice.EXPLOSION:
            var envelope := pow(1.0 - x, 1.75)
            var sub := sin(TAU_F * lerpf(62.0, 34.0, x) * t)
            var rupture := sin(TAU_F * 138.0 * t) * exp(-12.0 * x)
            return (0.54 * sub + 0.22 * rupture + 0.58 * noise) * envelope
        Voice.DEBRIS:
            var envelope := pow(1.0 - x, 1.45)
            var ring := sin(TAU_F * (430.0 + 55.0 * sin(TAU_F * 3.0 * t)) * t)
            var crackle_gate := maxf(sin(TAU_F * 19.0 * t), 0.0)
            return (0.22 * ring + 0.46 * noise * crackle_gate) * envelope
        _:
            return 0.0

static func _noise(t: float) -> float:
    return sin(
        17291.317 * t
        + 2.7 * sin(3911.13 * t + 0.7)
        + 1.4 * sin(997.7 * t + 1.9)
    )
