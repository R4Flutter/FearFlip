import 'dart:math' as math;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';

import '../../services/ads_service.dart';
import '../../services/purchase_service.dart';
import '../theme/app_palette.dart';

/// Full-featured "Remove Ads" one-time purchase dialog.
///
/// Shows real product price, purchase button, restore button, loading states,
/// success confirmation, and clear error messages.
///
/// Open via:
/// ```dart
/// await showRemoveAdsDialog(context);
/// ```
Future<void> showRemoveAdsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _RemoveAdsDialog(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog shell
// ─────────────────────────────────────────────────────────────────────────────

class _RemoveAdsDialog extends StatefulWidget {
  const _RemoveAdsDialog();

  @override
  State<_RemoveAdsDialog> createState() => _RemoveAdsDialogState();
}

class _RemoveAdsDialogState extends State<_RemoveAdsDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glitch;
  late final PurchaseService _service;

  // One-shot result message — cleared before each new action.
  String? _resultMessage;
  bool _resultIsSuccess = false;

  // Track whether a restore was explicitly triggered from this dialog
  // (vs. a status change from a buy flow).
  bool _restoreWasTriggered = false;

  @override
  void initState() {
    super.initState();

    _glitch = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();

    _service = PurchaseService.instance;
    _service.addListener(_onServiceChange);

    try {
      FirebaseAnalytics.instance.logEvent(name: 'purchase_screen_shown');
    } catch (_) {}
  }

  @override
  void dispose() {
    _glitch.dispose();
    _service.removeListener(_onServiceChange);
    super.dispose();
  }

  void _onServiceChange() {
    if (!mounted) return;
    final status = _service.status;

    switch (status) {
      case PurchaseStatus.purchased:
        AdsService.instance.disableAdsPermanently();
        setState(() {
          _resultIsSuccess = true;
          _resultMessage = '🎉 Ads removed! Enjoy uninterrupted gameplay.';
        });
        _restoreWasTriggered = false;
        break;

      case PurchaseStatus.error:
        setState(() {
          _resultIsSuccess = false;
          _resultMessage = _service.errorMessage.isNotEmpty
              ? _service.errorMessage
              : 'Purchase failed. Please try again.';
        });
        break;

      case PurchaseStatus.notPurchased:
        // Only show "nothing found" when a restore was explicitly triggered
        // AND we are no longer in the restoring state.
        if (_restoreWasTriggered && !_service.isRestoring) {
          setState(() {
            _resultIsSuccess = false;
            _resultMessage =
                'No Remove Ads purchase found for this account. '
                'If you purchased on a different account, sign in to that '
                'account in the store and try again.';
          });
          _restoreWasTriggered = false;
        }
        break;

      case PurchaseStatus.restoring:
      case PurchaseStatus.purchasing:
      case PurchaseStatus.initialising:
        // Clear stale result messages while an action is in progress.
        if (_resultMessage != null) {
          setState(() => _resultMessage = null);
        }
        break;
    }
  }

  Future<void> _onBuy() async {
    setState(() {
      _resultMessage = null;
      _restoreWasTriggered = false;
    });
    await _service.buyRemoveAds();
    // The purchase stream drives _onServiceChange from here.
  }

  Future<void> _onRestore() async {
    setState(() {
      _resultMessage = null;
      _restoreWasTriggered = true;
    });
    await _service.restorePurchases();
    // restorePurchases() now waits for the stream internally — the status
    // is already final when this returns, so _onServiceChange fires last.
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: (screenHeight * 0.88).clamp(500.0, 720.0),
        ),
        child: AnimatedBuilder(
          animation: _glitch,
          builder: (context, _) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppPalette.surface,
                  border: Border.all(
                    color: AppPalette.accentPink.withAlpha(180),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppPalette.accentPink.withAlpha(50),
                      blurRadius: 32,
                      spreadRadius: 2,
                    ),
                    const BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background grid
                    CustomPaint(
                      painter: _RemoveAdsGridPainter(progress: _glitch.value),
                    ),
                    // Radial glow
                    IgnorePointer(
                      child: Align(
                        alignment: const Alignment(0, -0.8),
                        child: Container(
                          width: 380,
                          height: 180,
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                AppPalette.accentPink.withAlpha(60),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Content
                    ListenableBuilder(
                      listenable: _service,
                      builder: (context, _) {
                        return _DialogContent(
                          service: _service,
                          resultMessage: _resultMessage,
                          resultIsSuccess: _resultIsSuccess,
                          onBuy: _onBuy,
                          onRestore: _onRestore,
                          onClose: () => Navigator.of(context).pop(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog content
// ─────────────────────────────────────────────────────────────────────────────

class _DialogContent extends StatelessWidget {
  const _DialogContent({
    required this.service,
    required this.resultMessage,
    required this.resultIsSuccess,
    required this.onBuy,
    required this.onRestore,
    required this.onClose,
  });

  final PurchaseService service;
  final String? resultMessage;
  final bool resultIsSuccess;
  final VoidCallback onBuy;
  final VoidCallback onRestore;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final isSubscribed = service.isSubscribed;
    final isBusy = service.isPurchasing; // covers both purchasing + restoring
    final isInitialising = service.status == PurchaseStatus.initialising;

    final product = service.productDetails;
    // Show real price from Play, or "Loading…" — never a hardcoded fallback.
    final priceText = product?.price;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              children: [
                _GlowIcon(
                  icon: isSubscribed
                      ? Icons.verified_rounded
                      : Icons.block_rounded,
                  color: isSubscribed
                      ? AppPalette.neonGreen
                      : AppPalette.accentPink,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSubscribed ? 'ADS REMOVED ✓' : 'REMOVE ADS',
                        style: TextStyle(
                          color: isSubscribed
                              ? AppPalette.neonGreen
                              : AppPalette.accentPink,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          letterSpacing: 0.8,
                          shadows: [
                            Shadow(
                              color:
                                  (isSubscribed
                                          ? AppPalette.neonGreen
                                          : AppPalette.accentPink)
                                      .withAlpha(120),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        isSubscribed
                            ? 'Permanently unlocked — no more ads'
                            : 'One-time purchase · Permanent · Restores on reinstall',
                        style: const TextStyle(
                          color: AppPalette.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppPalette.textMuted,
                  ),
                  tooltip: 'Close',
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Price chip ──────────────────────────────────────────────────
            if (!isSubscribed)
              _PriceChip(
                price: priceText,
                isLoading: isInitialising || (priceText == null && !isBusy),
              ),

            const SizedBox(height: 16),

            // ── Benefits ────────────────────────────────────────────────────
            _BenefitsList(subscribed: isSubscribed),

            const SizedBox(height: 20),

            // ── Result message ──────────────────────────────────────────────
            if (resultMessage != null)
              _ResultBanner(
                message: resultMessage!,
                isSuccess: resultIsSuccess,
              ),

            if (resultMessage != null) const SizedBox(height: 12),

            // ── Loading indicator ────────────────────────────────────────────
            if (isBusy)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _LoadingRow(
                  label: service.isRestoring
                      ? 'Checking your purchases…'
                      : 'Processing…',
                ),
              ),

            // ── CTA buttons ─────────────────────────────────────────────────
            if (isSubscribed)
              FilledButton.icon(
                onPressed: onClose,
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('All good – enjoy the game!'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppPalette.neonGreen,
                  foregroundColor: Colors.black,
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
            else ...[
              // Buy button
              _BuyButton(
                price: priceText,
                isLoading: isBusy || isInitialising,
                onPressed: (isBusy || isInitialising) ? null : onBuy,
              ),

              const SizedBox(height: 10),

              // Restore button
              OutlinedButton.icon(
                onPressed: (isBusy || isInitialising) ? null : onRestore,
                icon: const Icon(Icons.restore_rounded, size: 18),
                label: const Text('Restore Purchases'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  foregroundColor: AppPalette.textPrimary,
                  side: const BorderSide(color: AppPalette.borderSoft),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 14),

            // ── Legal / one-time purchase note ──────────────────────────────
            if (!isSubscribed)
              const Text(
                'This is a one-time purchase. Once bought, Remove Ads is '
                'permanently unlocked on all devices signed in to the same '
                'store account. Restore anytime via "Restore Purchases".',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppPalette.textMuted,
                  fontSize: 10,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _GlowIcon extends StatelessWidget {
  const _GlowIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        shape: BoxShape.circle,
        border: Border.all(color: color.withAlpha(160), width: 1.6),
        boxShadow: [BoxShadow(color: color.withAlpha(80), blurRadius: 18)],
      ),
      child: Icon(icon, color: color, size: 26),
    );
  }
}

class _PriceChip extends StatelessWidget {
  const _PriceChip({required this.price, required this.isLoading});

  /// Null means price hasn't loaded yet.
  final String? price;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppPalette.accentPink.withAlpha(30),
            AppPalette.accentPurple.withAlpha(20),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.accentPink.withAlpha(120)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.star_rate_rounded,
            color: AppPalette.accentPink,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  price ?? 'Loading price…',
                  style: TextStyle(
                    color: price != null
                        ? AppPalette.textPrimary
                        : AppPalette.textMuted,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                const Text(
                  'One-time · Permanent · Restores on reinstall',
                  style: TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (isLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppPalette.accentPink,
              ),
            ),
        ],
      ),
    );
  }
}

class _BenefitsList extends StatelessWidget {
  const _BenefitsList({required this.subscribed});

  final bool subscribed;

  static const _benefits = [
    (Icons.block_rounded, 'No interstitial ads between stages'),
    (Icons.videocam_off_rounded, 'No rewarded video pop-ups'),
    (Icons.web_asset_off_rounded, 'No banner ads on the dashboard'),
    (Icons.flash_on_rounded, 'Pure, uninterrupted gameplay'),
    (Icons.all_inclusive_rounded, 'Permanent — never expires'),
    (Icons.loop_rounded, 'Restores automatically on reinstall'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.borderSoft),
      ),
      child: Column(
        children: [
          for (final (icon, text) in _benefits)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: subscribed
                        ? AppPalette.neonGreen
                        : AppPalette.accentPink,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(
                        color: AppPalette.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (subscribed)
                    const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: AppPalette.neonGreen,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.message, required this.isSuccess});

  final String message;
  final bool isSuccess;

  @override
  Widget build(BuildContext context) {
    final color = isSuccess ? AppPalette.neonGreen : AppPalette.danger;
    final icon = isSuccess ? Icons.check_circle_rounded : Icons.error_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(160)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow({this.label = 'Processing…'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppPalette.accentPink,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: AppPalette.accentPink.withAlpha(200),
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _BuyButton extends StatefulWidget {
  const _BuyButton({
    required this.price,
    required this.isLoading,
    required this.onPressed,
  });

  final String? price;
  final bool isLoading;
  // Null when disabled (busy / initialising).
  final VoidCallback? onPressed;

  @override
  State<_BuyButton> createState() => _BuyButtonState();
}

class _BuyButtonState extends State<_BuyButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scale;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scale = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnim = _scale;
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.isLoading;
    final priceLabel = widget.price != null
        ? 'Buy Now · ${widget.price}'
        : 'Buy Now';

    return GestureDetector(
      onTapDown: enabled ? (_) => _scale.reverse() : null,
      onTapUp: enabled
          ? (_) {
              _scale.forward();
              widget.onPressed!();
            }
          : null,
      onTapCancel: enabled ? () => _scale.forward() : null,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: !enabled
                  ? [
                      AppPalette.accentPink.withAlpha(120),
                      AppPalette.accentPurple.withAlpha(120),
                    ]
                  : [AppPalette.accentPink, AppPalette.accentPurple],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: !enabled
                ? []
                : [
                    BoxShadow(
                      color: AppPalette.accentPink.withAlpha(100),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.block_rounded,
                      color: Colors.black,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      priceLabel,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Background painter
// ─────────────────────────────────────────────────────────────────────────────

class _RemoveAdsGridPainter extends CustomPainter {
  const _RemoveAdsGridPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppPalette.accentPink.withAlpha(22)
      ..strokeWidth = 1;

    const spacing = 28.0;
    for (var x = 0.0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Scanline
    final scanlineTop = (size.height + 60) * progress - 30;
    final scanRect = Rect.fromLTWH(0, scanlineTop, size.width, 30);
    final scanPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          AppPalette.accentPink.withAlpha(50),
          Colors.transparent,
        ],
      ).createShader(scanRect);
    canvas.drawRect(scanRect, scanPaint);

    // Glitch lines
    final glitchPaint = Paint()..color = AppPalette.accentPurple.withAlpha(60);
    for (var i = 0; i < 4; i++) {
      final wave = progress * math.pi * (6 + i * 2.1);
      final top = (size.height * (0.15 + 0.18 * i) + math.sin(wave) * 12).clamp(
        0.0,
        size.height - 3.0,
      );
      final left = (size.width * (0.05 + i * 0.04) + math.cos(wave * 1.2) * 18)
          .clamp(0.0, size.width - 80.0);
      final w = (size.width * (0.28 + i * 0.06)).clamp(70.0, size.width - left);
      canvas.drawRect(Rect.fromLTWH(left, top, w, 2), glitchPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RemoveAdsGridPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
