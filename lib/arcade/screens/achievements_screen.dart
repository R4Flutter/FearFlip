import 'package:flutter/material.dart';

import '../arcade_controller.dart';
import '../model/achievements.dart';
import '../model/shop_catalog.dart';
import '../ui/kit.dart';
import 'dialogs.dart';

/// Trophies: every achievement with its progress; finished ones wait for a
/// claim (souls, sometimes a runner).
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final arcade = ArcadeScope.of(context);
    final progress = arcade.progress;
    return ListenableBuilder(
      listenable: progress,
      builder: (context, _) {
        // Claimable first, then in progress, then claimed.
        final list = List<Achievement>.of(Achievements.all)
          ..sort((a, b) {
            int rank(Achievement x) => progress.canClaimAchievement(x)
                ? 0
                : progress.isClaimed(x)
                ? 2
                : 1;
            return rank(a) - rank(b);
          });
        Widget grid(int columns) => GridView.count(
          crossAxisCount: columns,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: columns == 2 ? 4.4 : 3.4,
          padding: const EdgeInsets.all(4),
          children: [for (final a in list) _AchievementTile(achievement: a)],
        );
        return MenuPage(
          title: 'Trophies',
          souls: progress.souls,
          trailing: StatChip(
            icon: FF.art('icon_trophy', size: 24),
            text: '${progress.claimedAchievements}/${Achievements.all.length}',
          ),
          onBack: () => Navigator.of(context).pop(),
          body: StonePanel(padding: const EdgeInsets.all(10), child: grid(2)),
          tallBody: StonePanel(padding: const EdgeInsets.all(8), child: grid(1)),
        );
      },
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final arcade = ArcadeScope.of(context);
    final progress = arcade.progress;
    final value = progress.metricValue(achievement);
    final claimable = progress.canClaimAchievement(achievement);
    final claimed = progress.isClaimed(achievement);
    final item = achievement.itemId == null ? null : ShopCatalog.byId(achievement.itemId!);
    return Slot(
      highlight: claimable ? FF.gold : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Opacity(
            opacity: claimed || claimable ? 1 : 0.5,
            child: FF.art('icon_trophy', size: 54),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(achievement.title, maxLines: 1, style: FF.text(19, weight: FontWeight.w700, color: claimed ? FF.gold : FF.bone)),
                Text(achievement.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: FF.text(14, color: FF.bone2)),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: BoneBar(
                        value: achievement.target == 0 ? 1 : value / achievement.target,
                        height: 16,
                        color: claimed ? FF.gold : FF.amber,
                        label: '${value > achievement.target ? achievement.target : value}/${achievement.target}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    const FFIcon(FFGlyph.soul, size: 20),
                    Text('${achievement.souls}', style: FF.text(15, weight: FontWeight.w700)),
                    if (item != null) ...[
                      const SizedBox(width: 6),
                      const FFIcon(FFGlyph.crown, size: 20),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (claimable)
            SlabButton(
              label: 'CLAIM',
              tone: ButtonTone.gold,
              height: 46,
              width: 104,
              fontSize: 17,
              pulse: true,
              sound: null,
              onPressed: () async {
                final reward = progress.claimAchievement(achievement);
                await showRewardDialog(context, reward: reward, title: achievement.title);
                arcade.announceAchievements();
              },
            )
          else if (claimed)
            const FFIcon(FFGlyph.check, size: 34),
        ],
      ),
    );
  }
}
