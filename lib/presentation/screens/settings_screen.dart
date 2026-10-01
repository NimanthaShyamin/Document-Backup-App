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
    final isBiometricRequired = ref.watch(biometricDeleteRequiredProvider);
    final geminiApiKey = ref.watch(geminiApiKeyProvider);
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

            // 4. Biometric Document Deletion Protection Toggle Card (Default: ON)
            _buildBiometricDeleteToggleCard(context, ref, isBiometricRequired, isLiquidGlass, language, isDark),

            const SizedBox(height: 16),

            // 5. Gemini AI Document Scanner & Auto-Fill Card
            _buildGeminiApiKeyCard(context, ref, geminiApiKey, isLiquidGlass, language, isDark),

            const SizedBox(height: 16),

            // 6. Categorized Documents Toggle Card
            _buildCategorizedToggleCard(context, ref, isCategorized, isLiquidGlass, language, isDark),

            const SizedBox(height: 16),

            // 7. Apple Liquid Glass Mode Toggle Card
            _buildLiquidGlassToggleCard(context, ref, isLiquidGlass, language, isDark),

            const SizedBox(height: 16),

            // 8. Cloud Backup & Sync Expandable Card
            _buildCloudSyncAccordion(context, ref, isLiquidGlass, language, isDark),

            const SizedBox(height: 24),

            // 9. Logout Button / Sign-in Action
            _buildLogoutSection(context, ref, user, isLiquidGlass, language, isDark),

            const SizedBox(height: 110), // Padding for floating navigation dock
          ],
        ),
      ),
    );
  }

  // --- 1. Google-style Profile Card ---
  Widget _buildProfilePreferencesCard(
    BuildContext context,
    WidgetRef ref,
    dynamic user,
    bool isLiquidGlass,
    AppLanguage language,
    bool isDark,
  ) {
    final hasUser = user != null;
    final hasPhoto = hasUser && (user.photoUrl != null);
    final displayName = hasUser ? (user.displayName ?? '') : '';
    final email = hasUser ? (user.email ?? '') : '';
    final initials = displayName.isNotEmpty
        ? displayName.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : (email.isNotEmpty ? email[0].toUpperCase() : '?');

    return LiquidGlassCard(
      isLiquidGlass: isLiquidGlass,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // ── Banner + Avatar ────────────────────────────────────────
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Gradient banner
              Container(
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1D3DF0), const Color(0xFF6366F1)]
                        : [const Color(0xFF2563EB), const Color(0xFF6366F1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Stack(
                  children: [
                    // Subtle pattern overlay
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                        child: Opacity(
                          opacity: 0.08,
                          child: GridView.count(
                            crossAxisCount: 8,
                            children: List.generate(40,
                                (_) => const Icon(Icons.circle, color: Colors.white, size: 4)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Avatar — centred, overlapping the banner
              Positioned(
                bottom: -30,
                left: 20,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? const Color(0xFF0C1338) : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: hasPhoto
                        ? ClipOval(
                            child: Image.network(
                              user.photoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _buildInitialsAvatar(initials, isDark),
                            ),
                          )
                        : _buildInitialsAvatar(initials, isDark),
                  ),
                ),
              ),

              // Google "G" badge on the avatar
              if (hasUser)
                Positioned(
                  bottom: -30 + 44,
                  left: 20 + 44,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                        )
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'G',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4285F4),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // ── Account info section ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 38, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasUser && displayName.isNotEmpty
                            ? displayName
                            : AppStrings.get('profile_and_preferences', language),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      if (hasUser && email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : const Color(0xFF64748B),
                          ),
                        ),
                      ] else if (!hasUser)
                        Text(
                          AppStrings.get('profile_subtitle', language),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : const Color(0xFF64748B),
                          ),
                        ),
                      const SizedBox(height: 10),
                      // Status chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (hasUser)
                            _statusChip(
                              icon: Icons.cloud_done_rounded,
                              label: 'Google Drive Linked',
                              color: const Color(0xFF10B981),
                              isDark: isDark,
                            )
                          else
                            _statusChip(
                              icon: Icons.cloud_off_rounded,
                              label: 'Not Signed In',
                              color: Colors.amberAccent,
                              isDark: isDark,
                            ),
                          _statusChip(
                            icon: Icons.shield_outlined,
                            label: 'Vault Secured',
                            color: const Color(0xFF6366F1),
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialsAvatar(String initials, bool isDark) {
    return Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _statusChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
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

  // --- 4. Biometric Document Deletion Protection Toggle Card (Default: ON) ---
  Widget _buildBiometricDeleteToggleCard(
    BuildContext context,
    WidgetRef ref,
    bool isBiometricRequired,
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
              color: isBiometricRequired
                  ? Colors.redAccent.withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.fingerprint,
              color: isBiometricRequired ? Colors.redAccent : Colors.grey,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      AppStrings.get('biometric_delete', language),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'DEFAULT ON',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  AppStrings.get('biometric_delete_sub', language),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: isBiometricRequired,
            activeTrackColor: Colors.redAccent.withValues(alpha: 0.6),
            activeThumbColor: Colors.redAccent,
            onChanged: (val) {
              ref.read(biometricDeleteRequiredProvider.notifier).set(val);
            },
          ),
        ],
      ),
    );
  }

  // --- 5. Gemini AI Document Scanner & Auto-Fill Card ---
  Widget _buildGeminiApiKeyCard(
    BuildContext context,
    WidgetRef ref,
    String apiKey,
    bool isLiquidGlass,
    AppLanguage language,
    bool isDark,
  ) {
    final isConfigured = apiKey.trim().isNotEmpty;
    final maskedKey = isConfigured
        ? (apiKey.length > 8
            ? '${apiKey.substring(0, 4)}••••${apiKey.substring(apiKey.length - 4)}'
            : '••••••••')
        : 'Not Configured (Tap to setup)';

    return LiquidGlassCard(
      isLiquidGlass: isLiquidGlass,
      padding: const EdgeInsets.all(16),
      onTap: () => _showGeminiApiKeyDialog(context, ref, apiKey, isDark),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00E5FF), Color(0xFF2979FF)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      AppStrings.get('gemini_api_title', language),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isConfigured
                            ? Colors.green.withValues(alpha: 0.15)
                            : Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isConfigured ? 'ACTIVE' : 'OPTIONAL',
                        style: TextStyle(
                          color: isConfigured ? Colors.greenAccent : Colors.amberAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  AppStrings.get('gemini_api_sub', language),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Key: $maskedKey',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: isConfigured ? Colors.cyanAccent : Colors.amberAccent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.edit_outlined, size: 20, color: Colors.white38),
        ],
      ),
    );
  }

  void _showGeminiApiKeyDialog(
    BuildContext context,
    WidgetRef ref,
    String currentKey,
    bool isDark,
  ) {
    final controller = TextEditingController(text: currentKey);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Color(0xFF00E5FF), size: 22),
            SizedBox(width: 10),
            Text(
              'Gemini API Key',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your Google Gemini API key to enable AI-powered automatic document detail extraction when importing vehicle documents.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
              decoration: InputDecoration(
                labelText: 'Google AI Studio API Key',
                labelStyle: const TextStyle(color: Colors.white60),
                filled: true,
                fillColor: const Color(0xFF26262E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                  onPressed: () => controller.clear(),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              ref.read(geminiApiKeyProvider.notifier).setKey(controller.text.trim());
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Gemini API key updated successfully.'),
                  backgroundColor: Color(0xFF1E293B),
                ),
              );
            },
            child: const Text('Save Key', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- 6. Categorized View Toggle Card ---
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
