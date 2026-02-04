import 'package:flutter/material.dart';

class SideNav extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onSelect;

  const SideNav({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelect,
      labelType: NavigationRailLabelType.all,
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.dashboard),
          label: Text('Overview'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.map),
          label: Text('Live Map'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.notifications),
          label: Text('Alerts'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.trending_up),
          label: Text('Trends'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.security),
          label: Text('Authority'),
        ),
      ],
    );
  }
}
