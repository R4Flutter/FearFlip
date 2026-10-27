import 'dart:async';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';

import '../presentation/gameplay/maze_art.dart';
import '../services/audio_manager.dart';
import 'arcade_controller.dart';
import 'platform/portal.dart';
import 'progress_controller.dart';
import 'screens/hub_screen.dart';
import 'ui/input_mode.dart';
import 'ui/kit.dart';

/// FearFlip: straight to the dashboard, no sign-in. Progress is saved through
/// the [Portal] (CrazyGames cloud data on the web).
class ArcadeApp extends StatefulWidget {
  const ArcadeApp({this.portal, super.key});

  /// Injected in tests; the platform's portal otherwise.
  final Portal? portal;

  @override
  State<ArcadeApp> createState() => _ArcadeAppState();
}

class _ArcadeAppState extends State<ArcadeApp> with WidgetsBindingObserver {
  late final Portal _portal = widget.portal ?? Portal.instance;
  late final ProgressController _progress = ProgressController(portal: _portal);
  late final ArcadeController _arcade = ArcadeController(
    portal: _portal,
    progress: _progress,
  );
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_boot());
  }

  Future<void> _boot() async {
    try {
      await _portal.init();
    } catch (error) {
      debugPrint('[Arcade] portal init failed: $error');
    }
    await _progress.load();
    await _arcade.loadDaily();
    Sfx.instance.setSwitches(
      musicOn: _progress.musicOn,
      sfxOn: _progress.sfxOn,
    );
    Sfx.instance.setPortalMuted(_portal.portalMuted.value);
    _portal.portalMuted.addListener(_onPortalMute);
    if (!mounted) return;
    setState(() => _ready = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _portal.finishLoading();
      unawaited(AudioManager.instance.preload());
      unawaited(AudioManager.instance.setMenuThemeActive(true));
      // The maze art loads while the player is on the dashboard.
      unawaited(MazeArt.shared());
    });
  }

  void _onPortalMute() =>
      Sfx.instance.setPortalMuted(_portal.portalMuted.value);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        Sfx.instance.setPaused(true);
        unawaited(_progress.save());
      case AppLifecycleState.resumed:
        Sfx.instance.setPaused(false);
        _progress.refreshDay();
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _portal.portalMuted.removeListener(_onPortalMute);
    _arcade.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FearFlip',
      debugShowCheckedModeBanner: false,
      navigatorKey: _arcade.navigatorKey,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        fontFamily: FF.bodyFont,
        scaffoldBackgroundColor: FF.void_,
        canvasColor: FF.void_,
        colorScheme: const ColorScheme.dark(
          primary: FF.amber,
          secondary: FF.spirit,
          surface: FF.slate,
        ),
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
            color: FF.bone,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: FF.ink, width: 2),
          ),
          textStyle: FF.boxText(14),
        ),
      ),
      builder: (context, child) => ArcadeScope(
        arcade: _arcade,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            if (event.kind == PointerDeviceKind.touch) {
              InputMode.touchSeen.value = true;
            }
          },
          child: Stack(
            children: [
              ?child,
              _ToastHost(arcade: _arcade),
            ],
          ),
        ),
      ),
      home: _ready ? const HubScreen() : const ColoredBox(color: FF.void_),
    );
  }
}

class _ToastHost extends StatelessWidget {
  const _ToastHost({required this.arcade});

  final ArcadeController arcade;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: IgnorePointer(
          child: Material(
            type: MaterialType.transparency,
            child: ValueListenableBuilder<ToastMessage?>(
              valueListenable: arcade.toast,
              builder: (context, message, _) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, animation) => SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(0, -1.2),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutBack,
                        ),
                      ),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: message == null
                    ? const SizedBox(key: ValueKey('none'), height: 0)
                    : Padding(
                        key: ValueKey(message),
                        padding: const EdgeInsets.only(top: 10),
                        child: Center(child: _Toast(message: message)),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast({required this.message});

  final ToastMessage message;

  @override
  Widget build(BuildContext context) {
    final icon = switch (message.kind) {
      ToastKind.achievement => FF.art('icon_trophy', size: 40),
      ToastKind.reward => const FFIcon(FFGlyph.soul, size: 38),
      ToastKind.warning => FF.art('icon_cross', size: 36),
      ToastKind.info => const FFIcon(FFGlyph.flame, size: 36),
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: BoneBox(
        padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.title,
                    style: FF.boxText(
                      18,
                      color: message.kind == ToastKind.warning
                          ? FF.blood2
                          : FF.slate,
                    ),
                  ),
                  if (message.subtitle != null)
                    Text(
                      message.subtitle!,
                      style: FF.boxText(14, color: FF.leatherDark),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
