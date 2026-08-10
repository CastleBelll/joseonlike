class_name AdsService
extends Node
## Ad service interface for JOSEONLIKE's free-to-play + advertisement model (GDD §1).
##
## M1 ships a no-op stub: no ad SDK dependency yet, so `is_available()` always
## returns false and callers get warned instead of a real ad. This lets
## gameplay/meta code call the ad API today without blocking on SDK integration.
##
## Shaped for Google AdMob (mobile-first, matches Android/iOS export targets in
## export_presets.cfg). Integrating it later requires:
## 1. Adding the AdMob GDExtension/plugin to the exported project (a real
##    dependency the coordinator must approve — do not add speculatively).
## 2. Replacing the bodies below with AdMob rewarded/interstitial ad unit calls,
##    keyed by ad unit IDs pulled from build config/env, never hardcoded here.
## 3. Wiring is_available() to the SDK's real load-state callback instead of
##    the constant `false` used by this stub.

signal rewarded_ad_completed(reward_id: String)
signal rewarded_ad_failed(reason: String)
signal interstitial_ad_closed()


func is_available(ad_type: String = "rewarded") -> bool:
	# No-op stub: no ad SDK is wired in for M1.
	return false


## `on_complete` is called with `(granted: bool)` once the rewarded ad flow ends.
func show_rewarded(on_complete: Callable) -> void:
	if not is_available("rewarded"):
		push_warning("AdsService.show_rewarded: no ad SDK integrated yet (M1 stub) — reward not granted")
		rewarded_ad_failed.emit("no_sdk")
		on_complete.call(false)
		return
	on_complete.call(true)


func show_interstitial() -> void:
	if not is_available("interstitial"):
		push_warning("AdsService.show_interstitial: no ad SDK integrated yet (M1 stub)")
		return
	interstitial_ad_closed.emit()
