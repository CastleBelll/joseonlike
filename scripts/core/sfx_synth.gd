class_name SfxSynth
extends RefCounted
## Pure sound synthesis (N9-52). Node-free and deterministic, so the headless
## suite can assert what a sound actually contains — length, headroom, decay —
## rather than trusting a binary nobody can hear in CI.
##
## The game shipped with an Effects bus, an effects-volume slider and no sound
## at all, because no sound files exist: the owner supplied music only. Rather
## than leave every hit silent, the effects are SYNTHESIZED here and written to
## asset/sfx/ by tools/make_sfx.gd. They are ordinary .wav files — dropping a
## real recording over one replaces it with no code change.
##
## A layer is a dictionary:
##   {"dur_sec", "freq_start", "freq_end", "wave" (sine|square|saw|noise),
##    "gain", "attack_sec", "decay" (exponent, higher = snappier),
##    "delay_sec" (start offset within the sound)}

const SAMPLE_RATE := 22050
## Peak amplitude every rendered sound is normalised to. Short of full scale on
## purpose: several effects overlap constantly (a hit, a crit and a death can
## land on the same frame) and a bus summing three 1.0 peaks clips.
const PEAK := 0.7
const MIN_ATTACK_SEC := 0.001


## Renders one layered sound to mono float samples in [-1, 1].
static func render(layers: Array) -> PackedFloat32Array:
	var total_sec: float = 0.0
	for layer: Variant in layers:
		if layer is Dictionary:
			total_sec = maxf(total_sec, _layer_end_sec(layer))
	var count: int = int(ceil(total_sec * float(SAMPLE_RATE)))
	var out := PackedFloat32Array()
	if count <= 0:
		return out
	out.resize(count)
	for layer: Variant in layers:
		if layer is Dictionary:
			_mix_layer(out, layer)
	return _normalized(out)


## PCM16 little-endian bytes, the format AudioStreamWAV wants for FORMAT_16_BITS.
static func to_pcm16(samples: PackedFloat32Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in range(samples.size()):
		# 32767, not 32768: the positive side saturates one step earlier, and
		# rounding to 32768 wraps to the loudest possible NEGATIVE sample — an
		# audible click exactly on the peak of every sound.
		var value: int = int(round(clampf(samples[i], -1.0, 1.0) * 32767.0))
		bytes.encode_s16(i * 2, value)
	return bytes


static func duration_sec(samples: PackedFloat32Array) -> float:
	return float(samples.size()) / float(SAMPLE_RATE)


static func peak(samples: PackedFloat32Array) -> float:
	var top: float = 0.0
	for sample: float in samples:
		top = maxf(top, absf(sample))
	return top


## Contract for the generator: a layer has to make a sound (positive length and
## gain) and name a waveform that exists.
static func layer_issues(layer: Dictionary, label: String) -> Array[String]:
	var issues: Array[String] = []
	if float(layer.get("dur_sec", 0.0)) <= 0.0:
		issues.append(label + ".dur_sec must be positive")
	if float(layer.get("gain", 0.0)) <= 0.0:
		issues.append(label + ".gain must be positive")
	if float(layer.get("delay_sec", 0.0)) < 0.0:
		issues.append(label + ".delay_sec cannot be negative")
	var wave: String = String(layer.get("wave", ""))
	if not ["sine", "square", "saw", "noise"].has(wave):
		issues.append("%s.wave '%s' is not a waveform" % [label, wave])
	elif wave != "noise":
		if float(layer.get("freq_start", 0.0)) <= 0.0:
			issues.append(label + ".freq_start must be positive")
		if float(layer.get("freq_end", 0.0)) <= 0.0:
			issues.append(label + ".freq_end must be positive")
	return issues


static func _layer_end_sec(layer: Dictionary) -> float:
	return float(layer.get("delay_sec", 0.0)) + float(layer.get("dur_sec", 0.0))


static func _mix_layer(out: PackedFloat32Array, layer: Dictionary) -> void:
	var wave: String = String(layer.get("wave", "sine"))
	var gain: float = float(layer.get("gain", 1.0))
	var decay: float = maxf(float(layer.get("decay", 1.0)), 0.0)
	var attack_sec: float = maxf(float(layer.get("attack_sec", 0.004)), MIN_ATTACK_SEC)
	var freq_start: float = float(layer.get("freq_start", 440.0))
	var freq_end: float = float(layer.get("freq_end", freq_start))
	var dur_sec: float = float(layer.get("dur_sec", 0.1))
	var start: int = int(float(layer.get("delay_sec", 0.0)) * float(SAMPLE_RATE))
	var length: int = int(dur_sec * float(SAMPLE_RATE))
	# Deterministic noise: a fixed seed derived from the layer keeps regenerated
	# files byte-identical, so a rebuild never shows up as a spurious asset
	# change in the diff.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(wave) + int(freq_start) + length
	# The phase is integrated rather than computed from t, because sin(TAU*f(t)*t)
	# on a sweeping f produces a discontinuity the ear hears as a click.
	var phase: float = 0.0
	for i: int in range(length):
		var index: int = start + i
		if index < 0 or index >= out.size():
			continue
		var progress: float = float(i) / float(maxi(length - 1, 1))
		var freq: float = lerpf(freq_start, freq_end, progress)
		phase += freq / float(SAMPLE_RATE)
		var envelope: float = _envelope(
			float(i) / float(SAMPLE_RATE), dur_sec, attack_sec, decay
		)
		out[index] += _sample(wave, phase, rng) * gain * envelope


static func _sample(wave: String, phase: float, rng: RandomNumberGenerator) -> float:
	match wave:
		"square":
			return 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		"saw":
			return fmod(phase, 1.0) * 2.0 - 1.0
		"noise":
			return rng.randf_range(-1.0, 1.0)
		_:
			return sin(phase * TAU)


## Linear attack into an exponential decay. The attack exists only to stop the
## click a hard start makes; the decay is what gives each effect its character.
static func _envelope(t: float, dur_sec: float, attack_sec: float, decay: float) -> float:
	if t < attack_sec:
		return t / attack_sec
	var remaining: float = 1.0 - (t - attack_sec) / maxf(dur_sec - attack_sec, MIN_ATTACK_SEC)
	return pow(clampf(remaining, 0.0, 1.0), decay)


static func _normalized(samples: PackedFloat32Array) -> PackedFloat32Array:
	var top: float = peak(samples)
	if top <= 0.0:
		return samples
	var scale: float = PEAK / top
	for i: int in range(samples.size()):
		samples[i] *= scale
	return samples
