import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_language.dart';
import '../../core/theme/app_preferences_provider.dart';
import '../../core/theme/liquid_glass_theme.dart';
import '../controllers/document_providers.dart';
import '../widgets/cloud_sync_settings_card.dart';
import 'login_screen.dart';

/// Settings screen matching user design with Apple Liquid Glass styling,
/// Theme switcher, Trilingual support (English, සිංහල, සිංග්ලිෂ්),
/// Categorized document view toggle, Liquid glass toggle, and Logout.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLiquidGlass = ref.watch(liquidGlassEnabledProvider);
    final themeMode = ref.watch(themeModeProvider);
    final language = ref.watch(appLanguageProvider);
    final isCategorized = ref.watch(categorizedViewProvider);
    final userAsync = ref.watch(googleAuthStateProvider);
    final user = userAsync.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          AppStrings.get('tab_settings', language),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
        child: Column(
          children: [
            // 1. Profile & Preferences Header Card (Matching user screenshot)
            _buildProfilePreferencesCard(context, ref, user, isLiquidGlass, language, isDark),

            const SizedBox(height: 16),

            // 2. App Theme Segmented Control Card (Matching user screenshot)
            _buildThemeSelectorCard(context, ref, themeMode, isLiquidGlass, language, isDark),

            const SizedBox(height: 16),

            // 3. Language Selector Card (English, සිංහල, සිංග්ලිෂ්)
            _buildLanguageSelectorCard(context, ref, language, isLiquidGlass, isDark),

            const SizedBox(height: 16),

            // 4. Categorized Documents Toggle Card
            _buildCategorizedToggleCard(context, ref, isCategorized, isLiquidGlass, language, isDark),

            const SizedBox(height: 16),

            // 5. Apple Liquid Glass Mode Toggle Card
            _buildLiquidGlassToggleCard(context, ref, isLiquidGlass, language, isDark),

            const SizedBox(height: 16),

            // 6. Cloud Backup & Sync Expandable Card
            _buildCloudSyncAccordion(context, ref, isLiquidGlass, language, isDark),

            const SizedBox(height: 24),

            // 7. Logout Button / Sign-in Action
            _buildLogoutSection(context, ref, user, isLiquidGlass, language, isDark),

            const SizedBox(height: 110), // Padding for floating navigation dock
          ],
        ),
      ),
    );
  }

  // --- 1. Profile & Preferences Card ---
  Widget _buildProfilePreferencesCard(
    BuildContext context,
    WidgetRef ref,
    dynamic user,
    bool isLiquidGlass,
    AppLanguage language,
    bool isDark,
  ) {
    return LiquidGlassCard(
      isLiquidGlass: isLiquidGlass,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          // Blue circle icon container as in screenshot
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2979FF), Color(0xFF1565C0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2979FF).withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: user != null && user.photoUrl != null
                ? ClipOval(
                    child: Image.network(
                      user.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 26,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.get('profile_and_preferences', language),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  user != null
                      ? '${user.displayName ?? user.email}'
                      : AppStrings.get('profile_subtitle', language),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  ),
                ),
                if (user != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        AppStrings.get('cloud_connected', language),
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. App Theme Segmented Control Card (Exact screenshot design) ---
  Widget _buildThemeSelectorCard(
    BuildContext context,
    WidgetRef ref,
    ThemeMode currentMode,
    bool isLiquidGlass,
    AppLanguage language,
    bool isDark,
  ) {
    String activeText;
    switch (currentMode) {
      case ThemeMode.light:
        activeText = AppStrings.get('theme_light_active', language);
        break;
      case ThemeMode.dark:
        activeText = AppStrings.get('theme_dark_active', language);
        break;
      case ThemeMode.system:
        activeText = AppStrings.get('theme_system_active', language);
        break;
    }

    return LiquidGlassCard(
      isLiquidGlass: isLiquidGlass,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.nightlight_round,
                color: Color(0xFF2979FF),
                size: 20,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.get('app_theme', language),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    activeText,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Segmented Bar (System | Light | Dark)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0x33000000) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.white10 : const Color(0xFFCBD5E1),
              ),
            ),
            child: Row(
              children: [
                _buildThemeSegmentButton(
                  context,
                  ref,
                  mode: ThemeMode.system,
                  currentMode: currentMode,
                  icon: Icons.smartphone,
                  label: AppStrings.get('theme_system', language),
                  isDark: isDark,
                ),
                _buildThemeSegmentButton(
                  context,
                  ref,
                  mode: ThemeMode.light,
                  currentMode: currentMode,
                  icon: Icons.wb_sunny_outlined,
                  label: AppStrings.get('theme_light', language),
                  isDark: isDark,
                ),
                _buildThemeSegmentButton(
                  context,
                  ref,
                  mode: ThemeMode.dark,
                  currentMode: currentMode,
                  icon: Icons.dark_mode_outlined,
                  label: AppStrings.get('theme_dark', language),
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSegmentButton(
    BuildContext context,
    WidgetRef ref, {
    required ThemeMode mode,
    required ThemeMode currentMode,
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    final isSelected = mode == currentMode;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          ref.read(themeModeProvider.notifier).setThemeMode(mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF2A2D3A) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? (isDark ? LiquidGlassTheme.accentAmber : const Color(0xFF0F172A))
                    : (isDark ? Colors.white60 : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                      : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 3. Language Selector Card (English, සිංහල, සිංග්ලිෂ්) ---
  Widget _buildLanguageSelectorCard(
    BuildContext context,
    WidgetRef ref,
    AppLanguage currentLanguage,
    bool isLiquidGlass,
    bool isDark,
  ) {
    return LiquidGlassCard(
      isLiquidGlass: isLiquidGlass,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.language,
                color: Color(0xFF2979FF),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.get('change_language', currentLanguage),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      currentLanguage.nativeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3-way Language Selector (English | සිංහල | සිංග්ලිෂ්)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0x33000000) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.white10 : const Color(0xFFCBD5E1),
              ),
            ),
            child: Row(
              children: [
                _buildLanguagePill(
                  ref,
                  lang: AppLanguage.english,
                  current: currentLanguage,
                  isDark: isDark,
                ),
                _buildLanguagePill(
                  ref,
                  lang: AppLanguage.sinhala,
                  current: currentLanguage,
                  isDark: isDark,
                ),
                _buildLanguagePill(
                  ref,
                  lang: AppLanguage.singlish,
                  current: currentLanguage,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguagePill(
    WidgetRef ref, {
    required AppLanguage lang,
    required AppLanguage current,
    required bool isDark,
  }) {
    final isSelected = lang == current;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          ref.read(appLanguageProvider.notifier).setLanguage(lang);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF2A2D3A) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              lang.nativeLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (isDark ? LiquidGlassTheme.accentAmber : const Color(0xFF0F172A))
                    : (isDark ? Colors.white60 : const Color(0xFF64748B)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- 4. Categorized View Toggle Card ---
  Widget _buildCategorizedToggleCard(
    BuildContext context,
    WidgetRef ref,
    bool isCategorized,
    bool isLiquidGlass,
    AppLanguage language,
    bool isDark,
  ) {
    return LiquidGlassCard(
      isLiquidGlass: isLiquidGlass,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isCategorized
                  ? Colors.amber.withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.dashboard_customize_outlined,
              color: isCategorized ? LiquidGlassTheme.accentAmber : Colors.grey,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.get('categorized_option', language),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppStrings.get('categorized_sub', language),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: isCategorized,
            activeTrackColor: LiquidGlassTheme.accentAmber.withValues(alpha: 0.6),
            activeThumbColor: LiquidGlassTheme.accentAmber,
            onChanged: (val) {
              ref.read(categorizedViewProvider.notifier).set(val);
            },
          ),
        ],
      ),
    );
  }

  // --- 5. Apple Liquid Glass Mode Toggle Card ---
  Widget _buildLiquidGlassToggleCard(
    BuildContext context,
    WidgetRef ref,
    bool isLiquidGlass,
    AppLanguage language,
    bool isDark,
  ) {
    return LiquidGlassCard(
      isLiquidGlass: isLiquidGlass,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: isLiquidGlass
                  ? const LinearGradient(
                      colors: [Color(0xFF00E5FF), Color(0xFF9E00FF)],
                    )
                  : null,
              color: isLiquidGlass ? null : Colors.grey.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.auto_awesome,
              color: isLiquidGlass ? Colors.white : Colors.grey,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.get('liquid_glass', language),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppStrings.get('liquid_glass_sub', language),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: isLiquidGlass,
            activeTrackColor: const Color(0xFF00E5FF).withValues(alpha: 0.6),
            activeThumbColor: const Color(0xFF00E5FF),
            onChanged: (val) {
              ref.read(liquidGlassEnabledProvider.notifier).set(val);
            },
          ),
        ],
      ),
    );
  }

  // --- 6. Cloud Sync Accordion ---
  Widget _buildCloudSyncAccordion(
    BuildContext context,
    WidgetRef ref,
    bool isLiquidGlass,
    AppLanguage language,
    bool isDark,
  ) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: LiquidGlassCard(
        isLiquidGlass: isLiquidGlass,
        padding: EdgeInsets.zero,
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2979FF).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.cloud_sync,
              color: Color(0xFF2979FF),
              size: 22,
            ),
          ),
          title: Text(
            AppStrings.get('cloud_sync_title', language),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          subtitle: Text(
            'Google Drive AppData Sandbox Status',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
          ),
          children: const [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: CloudSyncSettingsCard(),
            ),
          ],
        ),
      ),
    );
  }

  // --- 7. Logout / Sign-in Action Button ---
  Widget _buildLogoutSection(
    BuildContext context,
    WidgetRef ref,
    dynamic user,
    bool isLiquidGlass,
    AppLanguage language,
    bool isDark,
  ) {
    if (user == null) {
      // Prompt user to sign in
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: LiquidGlassTheme.accentAmber,
            foregroundColor: Colors.black87,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const LoginScreen(isOpenedFromSettings: true),
              ),
            );
          },
          icon: const Icon(Icons.login, size: 20),
          label: Text(
            AppStrings.get('btn_login', language),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      );
    }

    // Logout Button
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: Colors.redAccent.withValues(alpha: 0.5),
            width: 1.2,
          ),
          backgroundColor: Colors.redAccent.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: () => _confirmSignOut(context, ref, language),
        icon: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
        label: Text(
          AppStrings.get('btn_logout', language),
          style: const TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(
    BuildContext context,
    WidgetRef ref,
    AppLanguage language,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          AppStrings.get('logout_confirm_title', language),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          AppStrings.get('logout_confirm_msg', language),
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              AppStrings.get('cancel', language),
              style: const TextStyle(color: Colors.white60),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(AppStrings.get('btn_logout', language)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(googleAuthServiceProvider).signOut();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully signed out of Google Account.'),
            backgroundColor: Color(0xFF1E1E24),
          ),
        );
      }
    }
  }
}
