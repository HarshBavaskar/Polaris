import 'package:flutter/material.dart';

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
    if (compact) {
      return SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            _brandHeader(context),
            const SizedBox(height: 20),
            ...List.generate(_items.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _NavTile(
                  item: _items[index],
                  selected: index == selectedIndex,
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
        height: 70,
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
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? colorScheme.primary : colorScheme.onSurface,
                  ),
                ),
              ],
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
