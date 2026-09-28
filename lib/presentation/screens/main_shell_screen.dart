import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_language.dart';
import '../../core/theme/app_preferences_provider.dart';
import '../../core/theme/liquid_glass_theme.dart';
import '../controllers/document_providers.dart';
import 'home_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';

/// Main Application Shell hosting Home, Scan, and Settings with a compact, tiny rounded dock.
/// Dock layout:
/// - Scan section on the LEFT (index 0)
/// - Home section in the CENTER (index 1) - default active tab
/// - Settings section on the RIGHT (index 2)
class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  // Center tab (Home) is the default active section
  int _currentIndex = 1;
  late final PageController _pageController;
  final List<int> _tabHistory = [1];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    // Reconcile delta and silent auth in background on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(googleAuthServiceProvider).signInSilently();
      ref.read(syncQueueRepositoryProvider).reconcileStartupDelta();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (_currentIndex != index) {
      _tabHistory.add(index);
      setState(() => _currentIndex = index);
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _onPageChanged(int index) {
    if (_currentIndex != index) {
      _tabHistory.add(index);
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLiquidGlass = ref.watch(liquidGlassEnabledProvider);
    final language = ref.watch(appLanguageProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Ordered tabs: Scan on LEFT, Home in CENTER, Settings on RIGHT
    final screens = [
      ScanScreen(
        onDocumentSaved: () => _onTabSelected(1), // Return to Home on save
      ),
      HomeScreen(
        onNavigateToScan: () => _onTabSelected(0),
        onNavigateToSettings: () => _onTabSelected(2),
      ),
      const SettingsScreen(),
    ];

    return PopScope(
      canPop: _tabHistory.length <= 1,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_tabHistory.length > 1) {
          _tabHistory.removeLast();
          final prevIndex = _tabHistory.last;
          setState(() => _currentIndex = prevIndex);
          _pageController.animateToPage(
            prevIndex,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOutCubic,
          );
        }
      },
      child: Scaffold(
        extendBody: true,
        body: LiquidGlassBackground(
          isLiquidGlass: isLiquidGlass,
          child: PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            physics: const BouncingScrollPhysics(),
            children: screens,
          ),
        ),
        bottomNavigationBar: _buildFloatingDock(
          context: context,
          isLiquidGlass: isLiquidGlass,
          language: language,
          isDark: isDark,
        ),
      ),
    );
  }

  Widget _buildFloatingDock({
    required BuildContext context,
    required bool isLiquidGlass,
    required AppLanguage language,
    required bool isDark,
  }) {
    // Dock order: Scan on Left, Home in Center, Settings on Right
    final tabs = [
      _DockTab(icon: Icons.document_scanner_rounded, label: AppStrings.get('tab_scan', language)),
      _DockTab(icon: Icons.home_rounded, label: AppStrings.get('tab_home', language)),
      _DockTab(icon: Icons.tune_rounded, label: AppStrings.get('tab_settings', language)),
    ];

    // Dock decoration depending on active style mode
    BoxDecoration dockBoxDecoration;
    if (isLiquidGlass) {
      // Screenshot 3: Apple 3D Pure Liquid Glass (Crystal clear, see-through, not white)
      dockBoxDecoration = BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.45, 1.0],
          colors: isDark
              ? const [
                  Color(0x28FFFFFF), // Specular light highlight
                  Color(0x0AFFFFFF), // Ultra-clear transparent crystal body
                  Color(0x15FFFFFF), // Refractive crystal sheen
                ]
              : const [
                  Color(0x35FFFFFF), // Ultra-clean transparent crystal highlight
                  Color(0x0DFFFFFF), // Clear see-through body (NOT milky white)
                  Color(0x1EFFFFFF), // Pure glass refraction
                ],
        ),
        border: Border.all(
          color: isDark ? const Color(0x3DFFFFFF) : const Color(0x4DFFFFFF),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.35) : const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: -2,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.30),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      );
    } else if (!isDark) {
      // Screenshot 1: Milk white pill with subtle soft-blue border & delicate shadow
      dockBoxDecoration = BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: const Color(0xFFDCE7F4),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F2B5C).withValues(alpha: 0.09),
            blurRadius: 22,
            offset: const Offset(0, 7),
          ),
        ],
      );
    } else {
      // Screenshot 2: Electric midnight navy pill with glowing indigo border & deep shadow
      dockBoxDecoration = BoxDecoration(
        color: const Color(0xFF0C1338),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: const Color(0xFF202E68),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFF1D3DF0).withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      );
    }

    Widget dockInner = Container(
      height: 54, // Compact & tiny height
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: dockBoxDecoration,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(tabs.length, (index) {
          final tab = tabs[index];
          final isSelected = _currentIndex == index;

          // Compute colors based on active mode
          Color activePillColor;
          Color activeContentColor;
          Color inactiveContentColor;
          BoxBorder? activePillBorder;

          if (isLiquidGlass) {
            activePillColor = isDark
                ? Colors.white.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.65);
            activePillBorder = Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.85),
              width: 1.0,
            );
            activeContentColor = isDark ? Colors.white : const Color(0xFF0F172A);
            inactiveContentColor = isDark ? Colors.white60 : const Color(0xFF64748B);
          } else if (!isDark) {
            // Screenshot 1: Royal blue active on milk white
            activePillColor = const Color(0xFFEFF6FF);
            activeContentColor = const Color(0xFF2563EB);
            inactiveContentColor = const Color(0xFF64748B);
          } else {
            // Screenshot 2: Electric blue active on midnight navy
            activePillColor = const Color(0xFF162356);
            activeContentColor = const Color(0xFF38BDF8);
            inactiveContentColor = const Color(0xFF94A3B8);
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _onTabSelected(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: isSelected ? 14 : 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: isSelected ? activePillColor : Colors.transparent,
                borderRadius: BorderRadius.circular(22),
                border: isSelected ? activePillBorder : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    tab.icon,
                    size: 20,
                    color: isSelected ? activeContentColor : inactiveContentColor,
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 5),
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: activeContentColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );

    // Apply BackdropFilter blur if Liquid Glass is active
    if (isLiquidGlass) {
      dockInner = ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: dockInner,
        ),
      );
    }

    // Small and tiny floating dock anchored strictly near bottom
    return SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: true,
      child: Container(
        height: 68,
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.only(bottom: 12),
        child: SizedBox(
          width: 260, // Small and tiny width
          height: 52,
          child: dockInner,
        ),
      ),
    );
  }
}

class _DockTab {
  final IconData icon;
  final String label;

  const _DockTab({required this.icon, required this.label});
}
