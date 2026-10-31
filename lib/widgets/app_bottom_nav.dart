import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({super.key, required this.currentIndex, required this.onTap});

  static const _tabs = <({IconData icon, String label, String tooltip})>[
    (icon: Icons.home_filled, label: 'Home', tooltip: 'Home feed'),
    (icon: Icons.video_collection_outlined, label: 'Reels', tooltip: 'Short football videos'),
    (icon: Icons.send_outlined, label: 'Direct', tooltip: 'Direct messages'),
    (icon: Icons.search, label: 'Search', tooltip: 'Explore players and football content'),
    (icon: Icons.person_outline, label: 'Profile', tooltip: 'Your profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      height: 58 + bottomInset,
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
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            tab.icon,
                            size: 25,
                            color: active ? AppColors.text : AppColors.sub,
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
