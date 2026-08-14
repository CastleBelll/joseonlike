extends RefCounted
## ChoiceText: upgrade deltas, base stat summaries, and passive step text.


func run() -> Array[String]:
	var failures: Array[String] = []

	var upgrade_ko: String = ChoiceText.weapon_upgrade_description(
		{"damage": 3.5, "cooldown_sec": -0.05}, "ko")
	if not (upgrade_ko.contains("피해 +3.5") and upgrade_ko.contains("쿨다운 -0.05초")):
		failures.append("upgrade ko text wrong: %s" % upgrade_ko)

	var upgrade_en: String = ChoiceText.weapon_upgrade_description({"damage": 3.0}, "en")
	if upgrade_en != "DMG +3":
		failures.append("whole numbers should trim to integers, got: %s" % upgrade_en)

	if ChoiceText.weapon_upgrade_description({}, "ko") != "":
		failures.append("an empty per_level must produce an empty description")

	var base_ko: String = ChoiceText.weapon_base_description(
		{"damage": 12.0, "cooldown_sec": 1.2, "pierce": 0.0, "speed": 260.0}, "ko")
	if not (base_ko.contains("피해 12") and base_ko.contains("쿨다운 1.2초") and base_ko.contains("탄속 260")):
		failures.append("base ko text wrong: %s" % base_ko)
	if base_ko.contains("관통"):
		failures.append("zero-value stats must be omitted from base text")

	if ChoiceText.passive_description(0.08, 1, 5) != "+8% (1/5)":
		failures.append("fractional passive text wrong: %s" % ChoiceText.passive_description(0.08, 1, 5))
	if ChoiceText.passive_description(1.0, 2, 2) != "+1 (2/2)":
		failures.append("flat passive text wrong: %s" % ChoiceText.passive_description(1.0, 2, 2))

	return failures
