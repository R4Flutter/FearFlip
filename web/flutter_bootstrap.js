{{flutter_js}}
{{flutter_build_config}}

// Waits for the CrazyGames SDK (at most a few seconds) so the game can read
// the player's cloud save on its first frame, then starts the engine.
(async function () {
  try {
    if (window.ffcg) {
      await Promise.race([
        window.ffcg.init(),
        new Promise(function (r) { setTimeout(r, 4000); })
      ]);
    }
  } catch (e) {}
  _flutter.loader.load({
    config: { renderer: 'canvaskit' },
    onEntrypointLoaded: async function (engineInitializer) {
      const appRunner = await engineInitializer.initializeEngine();
      await appRunner.runApp();
    }
  });
})();
