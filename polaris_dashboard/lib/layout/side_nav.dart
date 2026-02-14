import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class SideNav extends StatelessWidget {
  const SideNav({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    this.compact = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool compact;

  static const _items = <_NavItem>[
    _NavItem('Overview', Icons.dashboard_rounded),
    _NavItem('Live Map', Icons.map_rounded),
    _NavItem('Alerts', Icons.notifications_active_rounded),
    _NavItem('Trends', Icons.stacked_line_chart_rounded),
    _NavItem('Citizen Verify', Icons.fact_check_rounded),
    _NavItem('Authority', Icons.admin_panel_settings_rounded),
    _NavItem('Settings', Icons.settings_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final isAndroidUi =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (compact) {
      return SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(12, isAndroidUi ? 8 : 12, 12, 20),
          children: [
            _brandHeader(context),
            SizedBox(height: isAndroidUi ? 12 : 20),
            ...List.generate(_items.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _NavTile(
                  item: _items[index],
                  selected: index == selectedIndex,
                  dense: isAndroidUi,
                  onTap: () => onSelect(index),
                ),
              );
            }),
          ],
        ),
      );
    }

    return Container(
      width: 270,
      margin: const EdgeInsets.fromLTRB(16, 16, 8, 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          _brandHeader(context),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _NavTile(
                    item: _items[index],
                    selected: selectedIndex == index,
                    dense: false,
                    onTap: () => onSelect(index),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _brandHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color.fromARGB(255, 8, 8, 8) : const Color(0xFFF2F7FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0x66525252) : const Color(0x3390A4BF),
          width: 0.5,
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 62,
        child: Image.asset(
          'assets/Polaris_Logo_Side.PNG',
          fit: BoxFit.fitWidth,
          isAntiAlias: true,
          filterQuality: .high,
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.dense,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final bool dense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: selected ? 1.02 : 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected ? colorScheme.primary.withValues(alpha: 0.13) : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: dense ? 9 : 11,
              ),
              child: Row(
                children: [
                  AnimatedScale(
                    duration: const Duration(milliseconds: 180),
                    scale: selected ? 1.08 : 1,
                    child: Icon(
                      item.icon,
                      color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(width: dense ? 8 : 10),
                  Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: dense ? 13 : null,
                      color: selected ? colorScheme.primary : colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.title, this.icon);

  final String title;
  final IconData icon;
}
