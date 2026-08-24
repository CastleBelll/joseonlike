extends RefCounted
## Guards the N9-1a BGM contract: the shipped audio data is coherent, every
## declared track file is actually in the build, and the validator catches the
## ways a track can be silently broken.


func test_the_shipped_audio_data_has_no_issues() -> bool:
	return MusicService.data_issues(MusicService.load_config()).is_empty()


func test_every_screen_that_plays_music_has_a_track() -> bool:
	var config: Dictionary = MusicService.load_config()
	# The stage looks its track up by stage id, so a missing entry here means
	# a silent region rather than an error anyone would notice.
	for track_id: String in ["title", "camp", Spawner.DEFAULT_STAGE_ID]:
		if MusicService.track(config, track_id).is_empty():
			return false
	return true


func test_a_track_pointing_at_a_missing_file_is_rejected() -> bool:
	var broken := {
		"_config": {"fade_sec": 1.0, "default_volume": 0.8},
		"tracks": {"ghost": {
			"name_ko": "없는 곡", "file": "res://asset/bgm/does_not_exist.mp3", "volume": 0.8,
		}},
	}
	var issues: Array[String] = MusicService.data_issues(broken)
	return issues.size() == 1 and issues[0].contains("does not exist")


func test_out_of_range_volumes_are_rejected() -> bool:
	var loud := {
		"_config": {"fade_sec": 1.0, "default_volume": 0.8},
		"tracks": {"a": {"name_ko": "x", "file": "res://data/audio.json", "volume": 1.5}},
	}
	var silent := {
		"_config": {"fade_sec": 1.0, "default_volume": 0.8},
		"tracks": {"a": {"name_ko": "x", "file": "res://data/audio.json", "volume": 0.0}},
	}
	return MusicService.data_issues(loud).size() == 1 \
		and MusicService.data_issues(silent).size() == 1


func test_a_negative_fade_and_an_empty_track_list_are_rejected() -> bool:
	var bad := {"_config": {"fade_sec": -1.0, "default_volume": 0.8}, "tracks": {}}
	var issues: Array[String] = MusicService.data_issues(bad)
	# Both problems reported, not just the first — a validator that stops at
	# one issue makes fixing data a guessing game.
	return issues.size() == 2


func test_an_unknown_track_id_resolves_to_nothing_rather_than_crashing() -> bool:
	return MusicService.track(MusicService.load_config(), "no_such_track").is_empty()
