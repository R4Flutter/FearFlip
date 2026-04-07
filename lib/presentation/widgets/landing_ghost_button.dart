import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

class LandingGhostButton extends StatelessWidget {
  const LandingGhostButton({
    required this.label,
    required this.icon,
    this.fontSize = 20,
    this.iconSize = 34,
    this.horizontalPadding = 18,
    this.verticalPadding = 18,
    this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final double fontSize;
  final double iconSize;
  final double horizontalPadding;
  final double verticalPadding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: AppPalette.surfaceSoft,
            border: Border.all(color: AppPalette.borderSoft),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              Icon(icon, color: AppPalette.textMuted, size: iconSize),
            ],
          ),
        ),
      ),
    );
  }
}
