import 'package:flutter/material.dart';

class TopBar extends StatelessWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: const Border(
          bottom: BorderSide(color: Colors.black12),
        ),
      ),
      child: Row(
        children: [
          Image.asset(
            "assets/Polaris.png",
            height: 60,
          ),
          const SizedBox(width: 20),
          const Text(
            "Dashboard",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const Spacer(),

          // Right-side status (optional, keep if you want)
          Text(
            "Last update: ${DateTime.now().toUtc().toString().substring(11, 19)} UTC",
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),

          
        ],
      ),
    );
  }
}
