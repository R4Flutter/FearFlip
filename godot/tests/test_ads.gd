extends McpTestSuite
## REVIVE's ad chain: SDKs are asked in order, a miss hands over to the next, the first ad watched ends it, and with
## nothing watched the worst miss is the answer (no SDK anywhere = OFF, the free revive).

## What each fake SDK answers; one missing from it isn't asked at all.
var _says: Dictionary = {}
var _asked: Array[String] = []
var _got: Array[int] = []


func suite_name() -> String:
	return "ads"


func setup() -> void:
	_asked.clear()
	_got.clear()
	Ads.ask = func(sdk: String) -> void:
		_asked.append(sdk)
		Ads.heard(_says.get(sdk, Ads.OFF))


func teardown() -> void:
	Ads.ask = Ads._ask_page


func _run(says: Dictionary) -> int:
	_says = says
	_got.clear()
	Ads.rewarded(func(result: int) -> void: _got.append(result))
	assert_eq(_got.size(), 1, "one answer per ad")
	return _got[0] if not _got.is_empty() else -1


func test_the_first_ad_watched_ends_the_chain() -> void:
	assert_eq(_run({"crazygames": Ads.EMPTY, "poki": Ads.WATCHED, "gamedistribution": Ads.WATCHED}), Ads.WATCHED)
	assert_eq(_asked, ["crazygames", "poki"] as Array[String])


func test_every_sdk_empty_means_no_reward() -> void:
	assert_eq(_run({"crazygames": Ads.EMPTY, "h5": Ads.EMPTY}), Ads.EMPTY)
	assert_eq(_asked, Ads.SDKS)


func test_an_ad_blocker_outweighs_an_empty_slot() -> void:
	assert_eq(_run({"crazygames": Ads.BLOCKED, "poki": Ads.EMPTY}), Ads.BLOCKED)


func test_no_sdk_anywhere_is_a_free_revive() -> void:
	assert_eq(_run({}), Ads.OFF)
	assert_eq(_run({"crazygames": Ads.OFF}), Ads.OFF, "Basic Launch")


func test_off_the_web_there_are_no_ads() -> void:
	Ads.ask = Ads._ask_page
	assert_false(Ads.on_page())
	assert_eq(_run({}), Ads.OFF)
