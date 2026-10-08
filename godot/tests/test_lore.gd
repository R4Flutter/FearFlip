extends McpTestSuite
## plans/06 §4 + P5: the light mystery. Thirty short notes, an ending per act plus the true one, eight bestiary
## entries, and a Voice on the death screen that answers how (and how often) you died.


func suite_name() -> String:
	return "lore"


func test_the_archive_holds_thirty_short_notes() -> void:
	assert_eq(Lore.NOTES.size(), 30)
	for i in Lore.NOTES.size():
		var words := _words(Lore.NOTES[i])
		assert_true(words > 0 and words <= 70, "note %d: %d words" % [i + 1, words])


func test_every_act_has_an_ending_and_there_is_a_true_one() -> void:
	assert_eq(Lore.ACT_ENDINGS.size(), StageRule.ACT_COUNT)
	var endings: Array = Lore.ACT_ENDINGS.duplicate()
	endings.append(Lore.TRUE_ENDING)
	for i in endings.size():
		var words := _words(endings[i])
		assert_true(words > 40 and words <= 150, "ending %d: %d words" % [i + 1, words])


func test_the_bestiary_names_eight_threats_and_what_counts_them() -> void:
	assert_eq(Lore.BESTIARY.size(), 8)
	var ids := {}
	for beast: Dictionary in Lore.BESTIARY:
		ids[beast["id"]] = true
		assert_false(String(beast["name"]).is_empty() or String(beast["rule"]).is_empty(), beast["id"])
		assert_true(_words(beast["lore"]) <= 70, "%s lore: %d words" % [beast["id"], _words(beast["lore"])])
		assert_false(String(beast["seen"]).is_empty(), "%s: the counter that reveals it" % beast["id"])
		for count: Array in beast["counts"]:
			assert_eq(count.size(), 2, "%s: [label, stat]" % beast["id"])
	assert_eq(ids.size(), 8, "unique ids")


func test_the_voice_answers_how_you_died() -> void:
	var devil := Lore.voice("devil", 7, 0.3, 4)
	assert_eq(devil, Lore.voice("devil", 7, 0.3, 4), "same death, same line")
	assert_true(Lore.VOICE["devil"].has(devil) or Lore.VOICE["any"].has(devil), devil)
	var trap := Lore.voice("trap", 7, 0.3, 4)
	assert_true(Lore.VOICE["trap"].has(trap) or Lore.VOICE["any"].has(trap), trap)
	var lines := {}
	for deaths in range(2, 40):
		lines[Lore.voice("time", deaths, 0.3, 4)] = true
	assert_gt(lines.size(), 8, "it doesn't repeat itself much")
	assert_true(Lore.VOICE["first"].has(Lore.voice("devil", 1, 0.3, 4)), "the first death")
	assert_true(Lore.VOICE["close"].has(Lore.voice("devil", 7, 0.95, 4)), "inches from the exit")
	assert_true(Lore.VOICE["gate"].has(Lore.voice("devil", 7, 0.3, StageRule.GATE_FLOOR)), "at the Gate")
	assert_true(Lore.VOICE["start"].has(Lore.voice("trap", 7, 0.3, 1)), "on the act's first floor")
	assert_eq(Lore.voice("devil", 100, 0.95, 1), Lore.VOICE_MILESTONES[100], "milestones come first")


func _words(text: String) -> int:
	return text.split(" ", false).size()
