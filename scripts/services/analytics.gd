class_name AnalyticsService
extends Node
## Thin analytics event interface for JOSEONLIKE.
##
## M1 ships a no-op default: `is_available()` returns false and `log_event`
## only records that an event was attempted, so gameplay/meta code can call
## the API today without a real analytics SDK wired in.
##
## Shaped for Firebase Analytics (matches Android/iOS export targets in
## export_presets.cfg). Integrating it later requires:
## 1. Adding the Firebase GDExtension/plugin (a real dependency the
##    coordinator must approve — do not add speculatively).
## 2. Replacing log_event()'s body with the SDK's event-logging call.
## 3. Auditing every call site against the no-PII rule below before shipping —
##    the interface staying "thin" is what keeps that audit tractable.
##
## Hard rule: never pass PII (names, emails) or device identifiers
## (advertising ID, IMEI, IP) as event params. Only gameplay-shaped data
## (character/stage/weapon ids, counts, durations) belongs here.

var _events_logged: int = 0


func is_available() -> bool:
	# No-op stub: no analytics SDK is wired in for M1.
	return false


func log_event(event_name: String, params: Dictionary = {}) -> void:
	if event_name.is_empty():
		push_error("AnalyticsService.log_event called with an empty event_name")
		return
	_events_logged += 1
	if not is_available():
		push_warning("AnalyticsService.log_event('%s'): no analytics SDK integrated yet (M1 stub)" % event_name)
