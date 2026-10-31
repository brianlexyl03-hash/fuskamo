import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({super.key, required this.currentIndex, required this.onTap});

  static const _tabs = <({IconData icon, String label, String tooltip})>[
    (icon: Icons.home_outlined, label: 'Home', tooltip: 'Home feed'),
    (icon: Icons.explore_outlined, label: 'Explore', tooltip: 'Explore players and football content'),
    (icon: Icons.add, label: 'Create', tooltip: 'Create a post, story or reel'),
    (icon: Icons.chat_bubble_outline, label: 'Messages', tooltip: 'Direct messages'),
    (icon: Icons.person_outline, label: 'Profile', tooltip: 'Your profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      height: 62 + bottomInset,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.black,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_tabs.length, (index) {
          final tab = _tabs[index];
          final active = index == currentIndex;
          final isCreate = index == 2;
          return Expanded(
            child: Semantics(
              button: true,
              selected: active,
              label: tab.tooltip,
              child: Tooltip(
                message: tab.tooltip,
                child: InkWell(
                  onTap: () => onTap(index),
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox.expand(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: isCreate ? 42 : 36,
                          height: isCreate ? 32 : 30,
                          decoration: BoxDecoration(
                            color: isCreate ? AppColors.green : Colors.transparent,
                            borderRadius: BorderRadius.circular(isCreate ? 10 : 8),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            tab.icon,
                            size: isCreate ? 23 : 24,
                            color: isCreate
                                ? AppColors.black
                                : active
                                    ? AppColors.green
                                    : AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tab.label,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                            color: active ? AppColors.green : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
