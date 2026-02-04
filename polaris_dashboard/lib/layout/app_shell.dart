import 'package:flutter/material.dart';
import 'side_nav.dart';
import 'top_bar.dart';
import '../screens/overview_screen.dart';
import '../screens/map_screen.dart';
import '../screens/alerts_screen.dart';
import '../screens/authority_screen.dart';
import '../screens/trends_screen.dart';



class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selectedIndex = 0;

  final screens = const [
    OverviewScreen(),
    LiveMapScreen(),
    AlertsScreen(),
    TrendsScreen(),
    AuthorityScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SideNav(
            selectedIndex: selectedIndex,
            onSelect: (i) => setState(() => selectedIndex = i),
          ),
          Expanded(
            child: Column(
              children: [
                const TopBar(),
                Expanded(child: screens[selectedIndex]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
