import 'package:flutter/material.dart';

import 'absent/absent_screen.dart';
import 'attend/attend_screen.dart';
import 'attendance_design.dart';
import 'attendance_history/attendance_history_screen.dart';
import 'home_screen.dart';
import 'profile/profile_screen.dart';

/// Main Shell with Persistent Conceptzilla Floating Bottom Navigation across all tabs
class MainNavigationShell extends StatefulWidget {
  final int initialIndex;

  const MainNavigationShell({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late final AnimationController _navEntryController;
  late final Animation<double> _navFade;
  late final Animation<Offset> _navSlide;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    _navEntryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _navFade = CurvedAnimation(
      parent: _navEntryController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );
    _navSlide = Tween<Offset>(
      begin: const Offset(0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _navEntryController,
      curve: const Interval(0.15, 0.85, curve: Curves.easeOutCubic),
    ));

    _navEntryController.forward();
  }

  @override
  void dispose() {
    _navEntryController.dispose();
    super.dispose();
  }

  void _onTabChange(int index) {
    if (index == 1) {
      // Direct Scan Action
      Navigator.push(
        context,
        SmoothPageRoute(
            page: const AttendScreen(action: AttendanceAction.checkIn)),
      );
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const HomeScreenContent(),
      const SizedBox.shrink(), // Placeholder for Scan trigger
      const AttendanceHistoryContent(),
      const AbsentContent(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AttendanceColors.page,
      body: Stack(
        children: [
          // Current Page with smooth cross-fade
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            child: KeyedSubtree(
              key: ValueKey<int>(_currentIndex),
              child: screens[_currentIndex],
            ),
          ),

          // Floating Bottom Navigation Bar with entry animation
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: _navSlide,
              child: FadeTransition(
                opacity: _navFade,
                child: AttendanceBottomNavigation(
                  currentIndex: _currentIndex,
                  onTap: _onTabChange,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
