class_name Ads
extends RefCounted
## Rewarded ads, for REVIVE only (GEMINI.md: never mid-play). A web portal allows only its own ad SDK, so each portal's
## export loads just its own in the head include and this asks every SDK below in turn: CrazyGames, Poki,
## GameDistribution, then Google H5 Games Ads (your own site). One that isn't on the page, has nothing to show (no fill,
## error, cooldown, no ad started within AD_WAIT_MS) or is blocked hands over to the next; the first ad watched ends
## it. Game audio is muted while an ad plays. Off the web (desktop, editor, tests) there are no ads.
## Head includes (CrazyGames' is in export_presets.cfg; put the portal's IDs in):
##   Poki: <script src='https://game-cdn.poki.com/scripts/v2/poki-sdk.js'></script>
##     <script>PokiSDK.init().catch(function () {});</script>
##   GameDistribution: <script>window.GD_OPTIONS = {gameId: 'GAME_ID', onEvent: function (e) {
##     if (e.name === 'SDK_REWARDED_WATCH_COMPLETE') window.fearflipGdWatched = true; }};</script>
##     <script src='https://html5.api.gamedistribution.com/main.min.js'></script>
##   Own site (approved AdSense account): <script async data-ad-client='ca-pub-ID' crossorigin='anonymous'
##     src='https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js'></script><script>window.adsbygoogle =
##     window.adsbygoogle || []; var adBreak = adConfig = function (o) { adsbygoogle.push(o); };
##     adConfig({preloadAdBreaks: 'on'});</script>

## What an ad came to, worst miss last: watched (reward), no ads here at all (CrazyGames' Basic Launch: the reward is
## free), nothing to show (no reward, CrazyGames forbids rewarding an adError: try again later), an ad blocker.
enum { WATCHED, OFF, EMPTY, BLOCKED }
const SDKS: Array[String] = ["crazygames", "poki", "gamedistribution", "h5"]
## How long an SDK gets to start its ad before the next one is asked. They all answer; this only keeps a broken one
## from holding the death screen.
const AD_WAIT_MS := 15000
## Each SDK's rewarded call, behind one shape: show(sdk, started, done, waitMs) answers done('watched' | 'off' |
## 'empty' | 'blocked') once; whatever a timed-out SDK says later is dropped.
const JS := """
window.fearflipAds = window.fearflipAds || (function () {
	var sdks = {
		crazygames: {
			present: function () { return !!(window.fearflipSdk && window.fearflipSdk.ready); },
			show: function (started, done) {
				window.CrazyGames.SDK.ad.requestAd('rewarded', {
					adStarted: started,
					adFinished: function () { done('watched'); },
					adError: function (e) { done({ adsDisabledBasicLaunch: 'off', adblock: 'blocked' }[e && e.code] || 'empty'); }
				});
			}
		},
		poki: {
			present: function () { return !!window.PokiSDK; },
			show: function (started, done) {
				started();
				window.PokiSDK.rewardedBreak().then(function (ok) { done(ok ? 'watched' : 'empty'); }, function () { done('empty'); });
			}
		},
		gamedistribution: {
			present: function () { return !!(window.gdsdk && window.gdsdk.showAd); },
			show: function (started, done) {
				window.fearflipGdWatched = false;
				started();
				window.gdsdk.showAd('rewarded').then(function () { done(window.fearflipGdWatched ? 'watched' : 'empty'); },
					function () { done('empty'); });
			}
		},
		h5: {
			present: function () { return typeof window.adBreak === 'function'; },
			show: function (started, done) {
				var watched = false;
				window.adBreak({ type: 'reward', name: 'revive', beforeAd: started,
					beforeReward: function (showAd) { showAd(); },
					adDismissed: function () {},
					adViewed: function () { watched = true; },
					adBreakDone: function () { done(watched ? 'watched' : 'empty'); } });
			}
		}
	};
	return {
		present: function (name) { return sdks[name].present(); },
		show: function (name, started, done, waitMs) {
			var over = false, playing = false;
			var answer = function (result) { if (!over) { over = true; done(result); } };
			setTimeout(function () { if (!playing) { answer('empty'); } }, waitMs);
			try {
				sdks[name].show(function () { playing = true; if (!over) { started(); } }, answer);
			} catch (e) {
				answer('empty');
			}
		}
	};
})();
"""

## Starts one SDK's ad; its answer comes back through heard(). Tests swap in a fake.
static var ask: Callable = _ask_page
static var _answer: Callable
static var _left: Array[String] = []
static var _miss := OFF
## The page's two callbacks into here, made once (JS can't call a freed one).
static var _js: Array[JavaScriptObject] = []


## An ad SDK is on this page, so REVIVE plays an ad first.
static func on_page() -> bool:
	return SDKS.any(_present)


## Plays a rewarded ad and calls `answer` once with what it came to (OFF at once with no SDK on the page).
static func rewarded(answer: Callable) -> void:
	_answer = answer
	_left = SDKS.duplicate()
	_miss = OFF
	_ask_next()


## An SDK's answer: the first ad watched ends it, a miss hands over to the next SDK.
static func heard(result: int) -> void:
	AudioServer.set_bus_mute(0, false)
	if result == WATCHED:
		_finish(WATCHED)
	else:
		_miss = maxi(_miss, result)
		_ask_next()


static func _ask_next() -> void:
	if _left.is_empty():
		_finish(_miss)
	else:
		ask.call(_left.pop_front())


static func _finish(result: int) -> void:
	if _answer.is_valid():
		_answer.call(result)


static func _ask_page(sdk: String) -> void:
	if not _present(sdk):
		heard(OFF)
		return
	if _js.is_empty():
		_js = [JavaScriptBridge.create_callback(_started), JavaScriptBridge.create_callback(_heard_page)]
	var page: Variant = JavaScriptBridge.get_interface("fearflipAds")  # a JS object: its methods aren't Godot's
	page.show(sdk, _js[0], _js[1], AD_WAIT_MS)


static func _present(sdk: String) -> bool:
	if not OS.has_feature("web"):
		return false
	JavaScriptBridge.eval(JS, true)
	# A JS boolean comes back as an int (0/1), and int == bool is a script error: take its truth.
	return true if JavaScriptBridge.eval("window.fearflipAds.present('%s')" % sdk, true) else false


static func _started(_args: Array) -> void:
	AudioServer.set_bus_mute(0, true)


static func _heard_page(args: Array) -> void:
	heard({"watched": WATCHED, "off": OFF, "blocked": BLOCKED}.get(args[0], EMPTY))


## A midgame ad between VERSUS rounds (plans/12), never during one: CrazyGames' (it caps how often), then `done` once,
## watched or not. Off the web or with no CrazyGames SDK on the page, `done` at once; an ad that never answers gives up
## after AD_WAIT_MS.
static var _midgame_done: Callable
static var _midgame_js: Array[JavaScriptObject] = []


static func midgame(done: Callable) -> void:
	if not _present("crazygames"):
		done.call()
		return
	_midgame_done = done
	if _midgame_js.is_empty():
		_midgame_js = [JavaScriptBridge.create_callback(_started), JavaScriptBridge.create_callback(_midgame_over)]
	var callbacks: Variant = JavaScriptBridge.create_object("Object")
	callbacks.adStarted = _midgame_js[0]
	callbacks.adFinished = _midgame_js[1]
	callbacks.adError = _midgame_js[1]
	var crazy: Variant = JavaScriptBridge.get_interface("CrazyGames")
	crazy.SDK.ad.requestAd("midgame", callbacks)
	(Engine.get_main_loop() as SceneTree).create_timer(AD_WAIT_MS / 1000.0).timeout.connect(_midgame_over.bind([]))


static func _midgame_over(_args: Array) -> void:
	AudioServer.set_bus_mute(0, false)
	var done := _midgame_done
	_midgame_done = Callable()
	if done.is_valid():
		done.call()
