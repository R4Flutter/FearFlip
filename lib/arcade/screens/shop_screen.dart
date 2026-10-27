import 'package:flutter/material.dart';

import '../arcade_controller.dart';
import '../model/boosts.dart';
import '../model/shop_catalog.dart';
import '../progress_controller.dart';
import '../ui/kit.dart';
import '../ui/runner_preview.dart';

enum _Tab { runners, lanterns, trails, powerUps }

/// Runners, lanterns, trails and power-ups for souls. Tapping an item
/// previews it on the runner; the button below buys or equips it.
class ShopScreen extends StatefulWidget {
  const ShopScreen({this.initialTab, super.key});

  final ShopCategory? initialTab;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  late _Tab _tab = switch (widget.initialTab) {
    ShopCategory.lantern => _Tab.lanterns,
    ShopCategory.trail => _Tab.trails,
    _ => _Tab.runners,
  };
  String? _selected;

  ShopCategory? get _category => switch (_tab) {
    _Tab.runners => ShopCategory.runner,
    _Tab.lanterns => ShopCategory.lantern,
    _Tab.trails => ShopCategory.trail,
    _Tab.powerUps => null,
  };

  @override
  Widget build(BuildContext context) {
    final arcade = ArcadeScope.of(context);
    final progress = arcade.progress;
    return ListenableBuilder(
      listenable: progress,
      builder: (context, _) {
        final category = _category;
        final items = category == null
            ? const <ShopItem>[]
            : ShopCatalog.of(category);
        ShopItem? selected;
        for (final item in items) {
          if (item.id == _selected) selected = item;
        }
        selected ??=
            items.where(progress.isEquipped).firstOrNull ?? items.firstOrNull;
        final preview = _previewLook(progress, selected);

        Widget tabs() => Row(
          children: [
            for (final tab in _Tab.values) ...[
              if (tab != _Tab.values.first) const SizedBox(width: 8),
              Expanded(
                child: SlabButton(
                  label: switch (tab) {
                    _Tab.runners => 'RUNNERS',
                    _Tab.lanterns => 'LANTERNS',
                    _Tab.trails => 'TRAILS',
                    _Tab.powerUps => 'POWER-UPS',
                  },
                  height: 50,
                  fontSize: 17,
                  tone: tab == _tab ? ButtonTone.amber : ButtonTone.stone,
                  onPressed: () => setState(() {
                    _tab = tab;
                    _selected = null;
                  }),
                ),
              ),
            ],
          ],
        );

        Widget grid(int columns) => category == null
            ? _PowerUpGrid(progress: progress, columns: columns)
            : GridView.count(
                crossAxisCount: columns,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.92,
                padding: const EdgeInsets.all(4),
                children: [
                  for (final item in items)
                    _ItemCard(
                      item: item,
                      owned: progress.owns(item.id),
                      equipped: progress.isEquipped(item),
                      selected: item.id == selected?.id,
                      onTap: () => setState(() => _selected = item.id),
                    ),
                ],
              );

        Widget previewPanel({required double size}) => StonePanel(
          glow: preview.light,
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RunnerPreview(look: preview, size: size),
              if (selected != null) ...[
                Text(selected.name, style: FF.title(34)),
                const SizedBox(height: 4),
                Text(
                  selected.text,
                  textAlign: TextAlign.center,
                  style: FF.text(15, color: FF.bone2),
                ),
                const SizedBox(height: 12),
                _ActionButton(item: selected, progress: progress),
              ] else ...[
                Text('POWER-UPS', style: FF.title(34)),
                const SizedBox(height: 4),
                Text(
                  'Take them into a stage from the stage card.',
                  textAlign: TextAlign.center,
                  style: FF.text(15, color: FF.bone2),
                ),
              ],
              const SizedBox(height: 12),
              _FreeSoulsButton(progress: progress),
            ],
          ),
        );

        return MenuPage(
          title: 'Shop',
          souls: progress.souls,
          onBack: () => Navigator.of(context).pop(),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 380, child: previewPanel(size: 230)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    tabs(),
                    const SizedBox(height: 12),
                    Expanded(child: grid(4)),
                  ],
                ),
              ),
            ],
          ),
          tallBody: Column(
            children: [
              previewPanel(size: 150),
              const SizedBox(height: 10),
              tabs(),
              const SizedBox(height: 10),
              Expanded(child: grid(3)),
            ],
          ),
        );
      },
    );
  }

  RunnerLook _previewLook(ProgressController progress, ShopItem? item) {
    final p = progress.profile;
    return RunnerLook.of(
      runnerId: item?.category == ShopCategory.runner ? item!.id : p.runner,
      lanternId: item?.category == ShopCategory.lantern ? item!.id : p.lantern,
      trailId: item?.category == ShopCategory.trail ? item!.id : p.trail,
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.owned,
    required this.equipped,
    required this.selected,
    required this.onTap,
  });

  final ShopItem item;
  final bool owned;
  final bool equipped;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final look = RunnerLook.of(
      runnerId: item.category == ShopCategory.runner
          ? item.id
          : ShopCatalog.defaultRunner,
      lanternId: item.category == ShopCategory.lantern
          ? item.id
          : ShopCatalog.defaultLantern,
      trailId: item.category == ShopCategory.trail ? item.id : 'trail_none',
    );
    final status = equipped
        ? 'EQUIPPED'
        : owned
        ? 'OWNED'
        : switch (item.route) {
            UnlockRoute.souls => '${item.price}',
            UnlockRoute.loginDay7 => 'DAY 7 GIFT',
            UnlockRoute.achievement => 'TROPHY',
            UnlockRoute.free => 'FREE',
          };
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Sfx.instance.play(Sound.click, volume: 0.5);
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: FF.ink.withValues(alpha: selected ? 0.95 : 0.78),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? FF.gold : (equipped ? FF.amberDark : FF.slate2),
              width: selected ? 3 : 2,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: FF.gold.withValues(alpha: 0.35),
                      blurRadius: 14,
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Expanded(
                child: Opacity(
                  opacity: owned ? 1 : 0.85,
                  child: RunnerPreview(
                    look: look,
                    size: 120,
                    walking: item.category == ShopCategory.trail,
                    turning: false,
                  ),
                ),
              ),
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FF.text(16, weight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!owned && item.route == UnlockRoute.souls) ...[
                    const FFIcon(FFGlyph.soul, size: 20),
                    const SizedBox(width: 4),
                  ],
                  if (!owned && item.route != UnlockRoute.souls) ...[
                    const FFIcon(FFGlyph.lock, size: 18),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FF.text(
                        15,
                        color: equipped
                            ? FF.gold
                            : (owned ? FF.spirit : FF.bone2),
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.item, required this.progress});

  final ShopItem item;
  final ProgressController progress;

  @override
  Widget build(BuildContext context) {
    if (progress.isEquipped(item)) {
      return const SlabButton(
        label: 'EQUIPPED',
        tone: ButtonTone.stone,
        height: 56,
        width: 260,
        onPressed: null,
      );
    }
    if (progress.owns(item.id)) {
      return SlabButton(
        label: 'EQUIP',
        tone: ButtonTone.spirit,
        height: 56,
        width: 260,
        onPressed: () => progress.equip(item),
      );
    }
    if (!item.buyable) {
      return SlabButton(
        label: item.route == UnlockRoute.loginDay7
            ? 'DAILY DAY 7 GIFT'
            : 'EARN IN TROPHIES',
        tone: ButtonTone.stone,
        height: 56,
        width: 260,
        onPressed: null,
      );
    }
    final affordable = progress.canAfford(item.price);
    return SlabButton(
      label: 'BUY  ${formatNumber(item.price)}',
      icon: const FFIcon(FFGlyph.soul, size: 30),
      tone: affordable ? ButtonTone.gold : ButtonTone.stone,
      height: 56,
      width: 260,
      sound: null,
      onPressed: () {
        final result = progress.buy(item);
        if (result == PurchaseResult.bought) {
          Sfx.instance.play(Sound.purchase);
          ArcadeScope.of(context).announceAchievements();
        } else {
          Sfx.instance.play(Sound.denied, volume: 0.6);
          ArcadeScope.of(context).showToast(
            ToastMessage(
              'Not enough souls',
              subtitle: 'Collect soul wisps in the mazes, or watch a video.',
              kind: ToastKind.warning,
            ),
          );
        }
      },
    );
  }
}

class _FreeSoulsButton extends StatelessWidget {
  const _FreeSoulsButton({required this.progress});

  final ProgressController progress;

  @override
  Widget build(BuildContext context) {
    final left = progress.freeSoulVideosLeft;
    return SlabButton(
      label: '+${ProgressController.freeSoulsPerVideo} SOULS',
      sublabel: left > 0 ? 'WATCH A VIDEO · $left LEFT TODAY' : 'BACK TOMORROW',
      icon: FF.art('icon_film', size: 28),
      tone: left > 0 ? ButtonTone.bone : ButtonTone.stone,
      height: 56,
      width: 260,
      onPressed: left <= 0
          ? null
          : () async {
              final arcade = ArcadeScope.of(context);
              if (!await arcade.watchRewarded()) return;
              final souls = progress.claimFreeSoulVideo();
              if (souls > 0 && context.mounted) {
                Sfx.instance.play(Sound.coins);
                arcade.showToast(
                  ToastMessage('+$souls souls', kind: ToastKind.reward),
                );
              }
            },
    );
  }
}

class _PowerUpGrid extends StatelessWidget {
  const _PowerUpGrid({required this.progress, required this.columns});

  final ProgressController progress;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: columns == 4 ? 2 : 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: columns == 4 ? 1.9 : 1.15,
      padding: const EdgeInsets.all(4),
      children: [
        for (final type in BoostType.values)
          Slot(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                FFIcon(boostGlyphFor(type.name), size: 64),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        Boosts.info[type]!.name,
                        style: FF.text(19, weight: FontWeight.w700),
                      ),
                      Text(
                        Boosts.info[type]!.text,
                        maxLines: 2,
                        style: FF.text(14, color: FF.bone2),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            'OWNED ×${progress.boostCount(type)}',
                            style: FF.text(
                              15,
                              color: FF.spirit,
                              weight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          SlabButton(
                            label: '${Boosts.info[type]!.price}',
                            icon: const FFIcon(FFGlyph.soul, size: 22),
                            height: 42,
                            fontSize: 17,
                            sound: null,
                            tone: progress.canAfford(Boosts.info[type]!.price)
                                ? ButtonTone.gold
                                : ButtonTone.stone,
                            onPressed: () {
                              if (progress.buyBoost(type)) {
                                Sfx.instance.play(Sound.purchase, volume: 0.7);
                              } else {
                                Sfx.instance.play(Sound.denied, volume: 0.6);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
