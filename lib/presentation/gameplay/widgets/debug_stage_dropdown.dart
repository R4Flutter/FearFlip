import 'package:flutter/material.dart';
import '../../theme/app_palette.dart';

class DebugStageDropdown extends StatelessWidget {
  const DebugStageDropdown({
    required this.currentStage,
    required this.maxStage,
    required this.onStageSelected,
    super.key,
  });

  final int currentStage;
  final int maxStage;
  final ValueChanged<int> onStageSelected;

  @override
  Widget build(BuildContext context) {
    final safeStage = currentStage.clamp(1, maxStage).toInt();

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 8, 4),
      decoration: BoxDecoration(
        color: AppPalette.surface.withAlpha(224),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.accentPurple.withAlpha(170)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bug_report_rounded,
            color: AppPalette.accentPurple.withAlpha(220),
            size: 16,
          ),
          const SizedBox(width: 6),
          const Text(
            'TEST STAGE',
            style: TextStyle(
              color: AppPalette.textMuted,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.45,
            ),
          ),
          const SizedBox(width: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: safeStage,
              isDense: true,
              menuMaxHeight: 320,
              dropdownColor: AppPalette.surfaceAlt,
              iconEnabledColor: AppPalette.neonGreen,
              style: const TextStyle(
                color: AppPalette.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
              items: List<DropdownMenuItem<int>>.generate(maxStage, (index) {
                final stage = index + 1;
                return DropdownMenuItem<int>(
                  value: stage,
                  child: Text('Stage $stage'),
                );
              }, growable: false),
              onChanged: (value) {
                if (value != null) {
                  onStageSelected(value);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
