import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({super.key, required this.currentIndex, required this.onTap});

  static const _tabs = [
    {'icon': '🏠', 'label': 'Feed'},
    {'icon': '🌍', 'label': 'Discover'},
    {'icon': '+', 'label': ''},
    {'icon': '💬', 'label': 'Groups'},
    {'icon': '🕸', 'label': 'Scouts'},
    {'icon': '👤', 'label': 'Profile'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64 + MediaQuery.of(context).padding.bottom,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.black,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_tabs.length, (i) {
          final tab = _tabs[i];
          final active = i == currentIndex;
          if (i == 2) {
            return GestureDetector(
              onTap: () => onTap(i),
              child: Container(
                width: 48,
                height: 34,
                decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(20)),
                alignment: Alignment.center,
                child: const Text('+', style: TextStyle(color: AppColors.black, fontSize: 20, fontWeight: FontWeight.bold)),
              ),
            );
          }
          return GestureDetector(
            onTap: () => onTap(i),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tab['icon']!, style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 2),
                Text(tab['label']!, style: TextStyle(fontSize: 10, color: active ? AppColors.green : AppColors.muted)),
              ],
            ),
          );
        }),
      ),
    );
  }
}
