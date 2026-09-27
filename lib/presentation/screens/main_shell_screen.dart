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

/// Main Application Shell hosting Home, Scan, and Settings with a floating Apple Liquid Glass dock.
class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  int _currentIndex = 0;
  late final PageController _pageController;
  final List<int> _tabHistory = [0];

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

    final screens = [
      HomeScreen(
        onNavigateToScan: () => _onTabSelected(1),
        onNavigateToSettings: () => _onTabSelected(2),
      ),
      ScanScreen(
        onDocumentSaved: () => _onTabSelected(0),
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
    final tabs = [
      _DockTab(icon: Icons.home_rounded, label: AppStrings.get('tab_home', language)),
      _DockTab(icon: Icons.document_scanner_rounded, label: AppStrings.get('tab_scan', language)),
      _DockTab(icon: Icons.tune_rounded, label: AppStrings.get('tab_settings', language)),
    ];

    Widget dockContent = Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isLiquidGlass
            ? (isDark ? const Color(0x38181A24) : const Color(0xB8FFFFFF))
            : (isDark ? const Color(0xFF1E1E24) : Colors.white),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(
          color: isLiquidGlass
              ? (isDark ? const Color(0x40FFFFFF) : const Color(0xA3FFFFFF))
              : (isDark ? const Color(0xFF2A2A32) : const Color(0xFFCBD5E1)),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(tabs.length, (index) {
          final tab = tabs[index];
          final isSelected = _currentIndex == index;

          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _onTabSelected(index),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSelected ? 16 : 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark
                            ? LiquidGlassTheme.accentAmber.withValues(alpha: 0.18)
                            : const Color(0xFF2563EB).withValues(alpha: 0.12))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tab.icon,
                        size: 22,
                        color: isSelected
                            ? (isDark ? LiquidGlassTheme.accentAmber : const Color(0xFF2563EB))
                            : (isDark ? Colors.white54 : const Color(0xFF94A3B8)),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            tab.label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? LiquidGlassTheme.accentAmber : const Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );

    if (isLiquidGlass) {
      dockContent = ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: dockContent,
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 14),
        child: dockContent,
      ),
    );
  }
}

class _DockTab {
  final IconData icon;
  final String label;

  const _DockTab({required this.icon, required this.label});
}
