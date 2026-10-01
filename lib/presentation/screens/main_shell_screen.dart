import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_language.dart';
import '../../core/theme/app_preferences_provider.dart';
import '../../core/theme/liquid_glass_theme.dart';
import '../controllers/document_providers.dart';
import 'ai_chat_sheet.dart';
import 'home_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';

/// Main Application Shell — Scan · Home · Settings with a compact floating dock.
///
/// Dock gesture recognition:
///   ↓  Swipe DOWN on dock  → reveals beautiful search bar in Home's AppBar.
///   ↑  Swipe UP   on dock  → opens AI Vault Assistant bottom sheet.
class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  int _currentIndex = 1; // Home is default
  late final PageController _pageController;

  // Dock drag tracking
  double _dragStartY = 0;
  static const double _kDragThreshold = 28.0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
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
      setState(() => _currentIndex = index);
    }
  }

  void _handleDockSwipe(double deltaY) {
    // Negative deltaY = swipe UP → AI chat
    // Positive deltaY = swipe DOWN → search
    if (deltaY < -_kDragThreshold) {
      // Swipe UP: open AI chat
      AiChatSheet.show(context);
    } else if (deltaY > _kDragThreshold) {
      // Swipe DOWN: show search bar (only makes sense on Home tab)
      if (_currentIndex == 1) {
        ref.read(searchVisibleProvider.notifier).state = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLiquidGlass = ref.watch(liquidGlassEnabledProvider);
    final language = ref.watch(appLanguageProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchVisible = ref.watch(searchVisibleProvider);

    final screens = [
      ScanScreen(onDocumentSaved: () => _onTabSelected(1)),
      HomeScreen(
        onNavigateToScan: () => _onTabSelected(0),
        onNavigateToSettings: () => _onTabSelected(2),
      ),
      const SettingsScreen(),
    ];

    // Standard Universal App Navigation:
    // 1. If search is open -> close search
    // 2. If on Scan or Settings -> go to Home
    // 3. If on Home -> close app
    final canPopApp = !searchVisible && _currentIndex == 1;

    return PopScope(
      canPop: canPopApp,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (ref.read(searchVisibleProvider)) {
          ref.read(searchVisibleProvider.notifier).state = false;
          return;
        }
        if (_currentIndex != 1) {
          _onTabSelected(1);
          return;
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
      _DockTab(icon: Icons.document_scanner_rounded,
          label: AppStrings.get('tab_scan', language)),
      _DockTab(icon: Icons.home_rounded,
          label: AppStrings.get('tab_home', language)),
      _DockTab(icon: Icons.settings_outlined,
          label: AppStrings.get('tab_settings', language)),
    ];

    Widget dockContent = Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(tabs.length, (index) {
        final tab = tabs[index];
        final isSelected = _currentIndex == index;

        Color activePillColor;
        Color activeContentColor;
        Color inactiveContentColor;
        BoxBorder? activePillBorder;

        if (isLiquidGlass) {
          // Liquid Glass style: harmonious translucent glass pill matching theme palette
          activePillColor = isDark
              ? const Color(0x3538BDF8)
              : const Color(0x252563EB);
          activePillBorder = Border.all(
            color: isDark
                ? const Color(0x6038BDF8)
                : const Color(0x502563EB),
            width: 1.0,
          );
          activeContentColor = isDark
              ? LiquidGlassTheme.accentElectricBlue
              : const Color(0xFF2563EB);
          inactiveContentColor =
              isDark ? Colors.white60 : const Color(0xFF475569);
        } else if (!isDark) {
          activePillColor = const Color(0xFFEFF6FF);
          activeContentColor = const Color(0xFF2563EB);
          inactiveContentColor = const Color(0xFF64748B);
        } else {
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  tab.icon,
                  size: 20,
                  color: isSelected
                      ? activeContentColor
                      : inactiveContentColor,
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
    );

    Widget dockInner;
    if (isLiquidGlass) {
      dockInner = GestureDetector(
        // Detect vertical drag on the dock for search / AI chat gestures
        onVerticalDragStart: (d) => _dragStartY = d.globalPosition.dy,
        onVerticalDragEnd: (d) {
          final delta = d.globalPosition.dy - _dragStartY;
          _handleDockSwipe(delta);
        },
        child: LiquidGlassCard(
          isLiquidGlass: true,
          radius: 30,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Center(child: dockContent),
        ),
      );
    } else {
      BoxDecoration dockDecoration;
      if (!isDark) {
        dockDecoration = BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFFDCE7F4), width: 1.1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F2B5C).withValues(alpha: 0.09),
              blurRadius: 22,
              offset: const Offset(0, 7),
            ),
          ],
        );
      } else {
        dockDecoration = BoxDecoration(
          color: const Color(0xFF0C1338),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFF202E68), width: 1.1),
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

      dockInner = GestureDetector(
        // Detect vertical drag on the dock for search / AI chat gestures
        onVerticalDragStart: (d) => _dragStartY = d.globalPosition.dy,
        onVerticalDragEnd: (d) {
          final delta = d.globalPosition.dy - _dragStartY;
          _handleDockSwipe(delta);
        },
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: dockDecoration,
          child: dockContent,
        ),
      );
    }

    // Gesture hint pill above the dock (subtle swipe indicators)
    return SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Swipe gesture hints
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _gestureHint(
                  Icons.keyboard_arrow_down_rounded,
                  'Search',
                  isDark,
                  onTap: () {
                    if (_currentIndex == 1) {
                      ref.read(searchVisibleProvider.notifier).state = true;
                    }
                  },
                ),
                const SizedBox(width: 24),
                _gestureHint(
                  Icons.keyboard_arrow_up_rounded,
                  'AI Chat',
                  isDark,
                  onTap: () => AiChatSheet.show(context),
                ),
              ],
            ),
          ),
          Container(
            height: 68,
            alignment: Alignment.bottomCenter,
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: 270,
              height: 54,
              child: dockInner,
            ),
          ),
        ],
      ),
    );
  }

  Widget _gestureHint(IconData icon, String label, bool isDark, {VoidCallback? onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: isDark ? Colors.white38 : Colors.black38),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white38 : Colors.black38,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
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
