extends RefCounted
## Guards the N9-52 sound synthesis (SfxSynth) and the effects data contract
## (SfxService). Nobody can hear a CI run, so what is asserted here is what a
## sound must MEASURABLY be: the right length, inside its headroom, actually
## decaying, and never clipping when its layers stack.

const EPSILON := 0.002

const BEEP: Dictionary = {
	"wave": "sine", "dur_sec": 0.1, "freq_start": 440.0, "freq_end": 440.0,
	"gain": 1.0, "attack_sec": 0.004, "decay": 2.0,
}


func test_render_length_follows_the_longest_layer() -> bool:
	var samples: PackedFloat32Array = SfxSynth.render([
		BEEP,
		_layer({"dur_sec": 0.05, "delay_sec": 0.2}),
	])
	# The delayed layer ends at 0.25s, well past the 0.1s beep.
	return absf(SfxSynth.duration_sec(samples) - 0.25) < EPSILON


func test_render_normalizes_to_the_headroom_peak() -> bool:
	# A quiet layer and a loud one both come out at the same peak — loudness
	# BETWEEN effects is a data decision, not an artefact of the gains here.
	var quiet: PackedFloat32Array = SfxSynth.render([_layer({"gain": 0.05})])
	var loud: PackedFloat32Array = SfxSynth.render([_layer({"gain": 4.0})])
	return absf(SfxSynth.peak(quiet) - SfxSynth.PEAK) < EPSILON \
		and absf(SfxSynth.peak(loud) - SfxSynth.PEAK) < EPSILON


func test_stacked_layers_still_fit_inside_full_scale() -> bool:
	# Three identical layers sum to 3x before normalisation. If normalisation
	# ever stopped running, this is the test that catches the clipping.
	var samples: PackedFloat32Array = SfxSynth.render([BEEP, BEEP, BEEP])
	return SfxSynth.peak(samples) <= 1.0


func test_sound_decays_instead_of_holding() -> bool:
	var samples: PackedFloat32Array = SfxSynth.render([BEEP])
	var late: float = 0.0
	# The last tenth of the sound must be quieter than the peak, or the
	# envelope is not doing anything and every effect ends in a click.
	for i: int in range(int(float(samples.size()) * 0.9), samples.size()):
		late = maxf(late, absf(samples[i]))
	return late < SfxSynth.PEAK * 0.25


func test_starts_from_silence() -> bool:
	# The first sample being anything but ~0 is an audible click on every play.
	var samples: PackedFloat32Array = SfxSynth.render([BEEP])
	return samples.size() > 0 and absf(samples[0]) < 0.05


func test_render_is_deterministic_even_with_noise() -> bool:
	# Noise is seeded so regenerating the .wav files produces an empty diff.
	var layers: Array = [{"wave": "noise", "dur_sec": 0.05, "gain": 1.0, "decay": 2.0}]
	return SfxSynth.render(layers) == SfxSynth.render(layers)


func test_pcm16_is_two_bytes_per_sample_and_never_wraps() -> bool:
	var samples := PackedFloat32Array([1.0, -1.0, 0.0, 2.0])
	var bytes: PackedByteArray = SfxSynth.to_pcm16(samples)
	# The clamped over-range sample must land on the positive maximum, NOT
	# wrap to the loudest negative value.
	return bytes.size() == 8 and bytes.decode_s16(0) == 32767 \
		and bytes.decode_s16(2) == -32767 and bytes.decode_s16(6) == 32767


func test_empty_input_is_empty_output_not_a_crash() -> bool:
	return SfxSynth.render([]).is_empty() \
		and SfxSynth.to_pcm16(PackedFloat32Array()).is_empty()


func test_layer_issues_reject_unusable_layers() -> bool:
	var silent: Array[String] = SfxSynth.layer_issues({
		"wave": "sine", "dur_sec": 0.0, "gain": 0.0, "freq_start": 1.0, "freq_end": 1.0
	}, "x")
	var unknown_wave: Array[String] = SfxSynth.layer_issues({
		"wave": "trumpet", "dur_sec": 0.1, "gain": 1.0
	}, "x")
	return silent.size() == 2 and unknown_wave.size() == 1


func test_layer_issues_accept_noise_without_a_frequency() -> bool:
	# Noise has no pitch; demanding one would make every noise layer illegal.
	return SfxSynth.layer_issues(
		{"wave": "noise", "dur_sec": 0.05, "gain": 1.0}, "x"
	).is_empty()


func test_shipped_audio_data_declares_real_effect_files() -> bool:
	return SfxService.data_issues(MusicService.load_config()).is_empty()


func test_shipped_effects_cover_every_wired_event() -> bool:
	# These ids are called by name from the stage. A rename in data with no
	# rename at the call site is silence, and silence looks like "no sound
	# happened here yet" rather than like a bug.
	var config: Dictionary = MusicService.load_config()
	for sound_id: String in ["hit", "crit", "kill", "pickup", "levelup",
			"skill", "hurt", "boss_warn"]:
		if SfxService.sfx(config, sound_id).is_empty():
			return false
	return true


func _layer(overrides: Dictionary) -> Dictionary:
	var layer: Dictionary = BEEP.duplicate()
	layer.merge(overrides, true)
	return layer
