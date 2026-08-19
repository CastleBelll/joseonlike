extends SceneTree
## Generates asset/sfx/*.wav from the synth definitions below (N9-52).
## Run: godot --headless --path . --script tools/make_sfx.gd
##
## The files are committed, so nobody needs this to build or play the game —
## it exists so the sounds can be RETUNED as data instead of being opaque
## binaries. Output is deterministic: regenerating without editing a
## definition produces byte-identical files and an empty diff.
##
## Every sound here is a placeholder in the same sense as PlaceholderArt: it
## keeps a missing asset from blocking the feature. Dropping a real recording
## over any of these .wav files replaces it with no code change.

const OUT_DIR := "res://asset/sfx"

## Sound design, one entry per effect id. Layers are mixed and the result is
## normalised, so gains are relative WITHIN a sound; loudness BETWEEN sounds is
## set in data/audio.json, where it can be retuned without regenerating.
const SOUNDS: Dictionary = {
	# The most repeated sound in the game by far — it plays several times a
	# second — so it is short, dull and low: anything bright becomes fatiguing
	# within a minute.
	"hit": [
		{"wave": "noise", "dur_sec": 0.05, "gain": 0.7, "attack_sec": 0.001, "decay": 3.0},
		{"wave": "square", "dur_sec": 0.07, "freq_start": 220.0, "freq_end": 90.0,
		 "gain": 0.5, "attack_sec": 0.002, "decay": 2.5},
	],
	# Distinguished from a hit by PITCH, not volume: a louder hit is just
	# noise, while a rising ring reads as "that one counted" even in a crowd.
	"crit": [
		{"wave": "square", "dur_sec": 0.05, "freq_start": 640.0, "freq_end": 980.0,
		 "gain": 0.6, "attack_sec": 0.001, "decay": 2.0},
		{"wave": "sine", "dur_sec": 0.16, "freq_start": 1320.0, "freq_end": 1560.0,
		 "gain": 0.5, "attack_sec": 0.002, "decay": 2.2, "delay_sec": 0.03},
		{"wave": "noise", "dur_sec": 0.04, "gain": 0.35, "attack_sec": 0.001, "decay": 4.0},
	],
	# Falls away instead of ringing out: a death is a thing ending.
	"kill": [
		{"wave": "saw", "dur_sec": 0.13, "freq_start": 420.0, "freq_end": 140.0,
		 "gain": 0.6, "attack_sec": 0.003, "decay": 2.0},
		{"wave": "noise", "dur_sec": 0.09, "gain": 0.3, "attack_sec": 0.002, "decay": 3.0},
	],
	"pickup": [
		{"wave": "square", "dur_sec": 0.05, "freq_start": 780.0, "freq_end": 780.0,
		 "gain": 0.5, "attack_sec": 0.002, "decay": 2.0},
		{"wave": "square", "dur_sec": 0.08, "freq_start": 1170.0, "freq_end": 1170.0,
		 "gain": 0.5, "attack_sec": 0.002, "decay": 2.0, "delay_sec": 0.05},
	],
	# A rising third-fifth-octave figure: the one moment in the run that is
	# unambiguously good news, so it is the only sound allowed to be musical.
	"levelup": [
		{"wave": "sine", "dur_sec": 0.14, "freq_start": 523.0, "freq_end": 523.0,
		 "gain": 0.5, "attack_sec": 0.006, "decay": 1.6},
		{"wave": "sine", "dur_sec": 0.14, "freq_start": 659.0, "freq_end": 659.0,
		 "gain": 0.5, "attack_sec": 0.006, "decay": 1.6, "delay_sec": 0.1},
		{"wave": "sine", "dur_sec": 0.3, "freq_start": 1046.0, "freq_end": 1046.0,
		 "gain": 0.6, "attack_sec": 0.006, "decay": 1.4, "delay_sec": 0.2},
	],
	# 축지 and 벽사진 share one sound: a downward noise sweep, which reads as
	# displacement rather than as another impact.
	"skill": [
		{"wave": "noise", "dur_sec": 0.22, "gain": 0.6, "attack_sec": 0.01, "decay": 1.8},
		{"wave": "sine", "dur_sec": 0.2, "freq_start": 900.0, "freq_end": 200.0,
		 "gain": 0.5, "attack_sec": 0.004, "decay": 1.5},
	],
	# Deliberately unpleasant, and low enough not to be confused with a hit
	# landing on something else.
	"hurt": [
		{"wave": "square", "dur_sec": 0.18, "freq_start": 190.0, "freq_end": 110.0,
		 "gain": 0.7, "attack_sec": 0.002, "decay": 1.6},
		{"wave": "noise", "dur_sec": 0.08, "gain": 0.4, "attack_sec": 0.001, "decay": 2.5},
	],
	# Two beeps, rising: the boss telegraph is a countdown, and a countdown
	# has to be heard as one even when the shape is off-screen.
	"boss_warn": [
		{"wave": "square", "dur_sec": 0.1, "freq_start": 440.0, "freq_end": 440.0,
		 "gain": 0.55, "attack_sec": 0.004, "decay": 2.0},
		{"wave": "square", "dur_sec": 0.16, "freq_start": 587.0, "freq_end": 587.0,
		 "gain": 0.6, "attack_sec": 0.004, "decay": 2.0, "delay_sec": 0.14},
	],
}


func _init() -> void:
	var failed: bool = false
	if not DirAccess.dir_exists_absolute(OUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUT_DIR)
	for sound_id: String in SOUNDS:
		var layers: Array = SOUNDS[sound_id]
		var bad_layer: bool = false
		for i: int in range(layers.size()):
			for issue: String in SfxSynth.layer_issues(layers[i], "%s[%d]" % [sound_id, i]):
				push_error("make_sfx: " + issue)
				bad_layer = true
		if bad_layer:
			failed = true
			continue
		var samples: PackedFloat32Array = SfxSynth.render(layers)
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = SfxSynth.SAMPLE_RATE
		stream.stereo = false
		stream.data = SfxSynth.to_pcm16(samples)
		var path: String = "%s/%s.wav" % [OUT_DIR, sound_id]
		var error: int = stream.save_to_wav(path)
		if error != OK:
			push_error("make_sfx: cannot write %s (error %d)" % [path, error])
			failed = true
			continue
		print("SFX %-10s %5.3fs peak %.2f -> %s" % [
			sound_id, SfxSynth.duration_sec(samples), SfxSynth.peak(samples), path
		])
	print("MAKE SFX: " + ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)
