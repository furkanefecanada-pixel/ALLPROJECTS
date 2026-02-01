import 'package:flutter/material.dart';
import 'game_logic.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  IconData _iconFor(ItemType t) {
    switch (t) {
      case ItemType.mysteryBox:
        return Icons.inventory_2;
      case ItemType.gem:
        return Icons.diamond;
      case ItemType.badge:
        return Icons.workspace_premium;
      case ItemType.ticket:
        return Icons.confirmation_number;
      case ItemType.waterBottle:
        return Icons.water_drop;
      case ItemType.snack:
        return Icons.cookie;
    }
  }

  String _timeAgo(int sec) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final d = (now - sec).clamp(0, 99999999);
    if (d < 60) return '${d}s ago';
    if (d < 3600) return '${(d / 60).floor()}m ago';
    if (d < 86400) return '${(d / 3600).floor()}h ago';
    return '${(d / 86400).floor()}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final logic = GameLogic.I;

    return ValueListenableBuilder(
      valueListenable: logic.tick,
      builder: (_, __, ___) {
        final items = logic.inventory;

        return Scaffold(
          appBar: AppBar(
            title: const Text('INVENTORY'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: Text(
                    'COINS: ${logic.coins}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
          body: items.isEmpty
              ? const Center(child: Text('NO ITEMS YET'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final it = items[i];

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Row(
                        children: [
                          Icon(_iconFor(it.type), size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  it.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.05,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _timeAgo(it.collectedAtSec),
                                  style: TextStyle(color: Colors.white.withOpacity(0.65)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '+${it.rewardCoins}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}