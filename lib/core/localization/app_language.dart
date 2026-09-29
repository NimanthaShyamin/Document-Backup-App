/// Supported application languages.
enum AppLanguage {
  english('english', 'English', 'English'),
  sinhala('sinhala', 'සිංහල', 'Sinhala'),
  singlish('singlish', 'සිංග්ලිෂ්', 'Singlish');

  final String code;
  final String nativeLabel;
  final String englishLabel;

  const AppLanguage(this.code, this.nativeLabel, this.englishLabel);

  static AppLanguage fromCode(String code) {
    return AppLanguage.values.firstWhere(
      (lang) => lang.code == code,
      orElse: () => AppLanguage.english,
    );
  }
}

/// Central dictionary for English, Sinhala (සිංහල), and Singlish (සිංග්ලිෂ්).
class AppStrings {
  static const Map<String, Map<AppLanguage, String>> _localizedValues = {
    // Navigation
    'tab_home': {
      AppLanguage.english: 'Home',
      AppLanguage.sinhala: 'මුල් පිටුව',
      AppLanguage.singlish: 'හෝම්',
    },
    'tab_scan': {
      AppLanguage.english: 'Scan',
      AppLanguage.sinhala: 'ස්කෑන්',
      AppLanguage.singlish: 'ස්කෑන් කරන්න',
    },
    'tab_settings': {
      AppLanguage.english: 'Settings',
      AppLanguage.sinhala: 'සැකසුම්',
      AppLanguage.singlish: 'සෙටින්ග්ස්',
    },

    // App Bar & Branding
    'app_title': {
      AppLanguage.english: 'Document Vault',
      AppLanguage.sinhala: 'ලේඛන සුරක්ෂිතාගාරය',
      AppLanguage.singlish: 'ඩොකියුමන්ට් වෝල්ට්',
    },
    'app_subtitle': {
      AppLanguage.english: 'Secure Personal Vault with Google Drive Backup',
      AppLanguage.sinhala: 'Google Drive සමඟ සුරක්ෂිත පුද්ගලික ලේඛන ගබඩාව',
      AppLanguage.singlish: 'ගූගල් ඩ්‍රයිව් බ්ලැක්අප් සහිත සෙකියුර් වෝල්ට් එක',
    },

    // Settings Profile Card
    'profile_and_preferences': {
      AppLanguage.english: 'Profile & Preferences',
      AppLanguage.sinhala: 'පැතිකඩ සහ මනාපයන්',
      AppLanguage.singlish: 'ප්‍රොෆයිල් සහ ප්‍රිෆරන්ස්',
    },
    'profile_subtitle': {
      AppLanguage.english: 'Account settings & language options',
      AppLanguage.sinhala: 'ගිණුම් සැකසුම් සහ භාෂා තේරීම්',
      AppLanguage.singlish: 'එකවුන්ට් සෙටින්ග්ස් සහ ලැන්ග්වේජ් ඔප්ෂන්ස්',
    },
    'guest_user': {
      AppLanguage.english: 'Offline Vault User',
      AppLanguage.sinhala: 'නොබැඳි පරිශීලකයා',
      AppLanguage.singlish: 'ඕෆ්ලයින් වෝල්ට් යූසර්',
    },

    // Theme Settings
    'app_theme': {
      AppLanguage.english: 'App Theme',
      AppLanguage.sinhala: 'යෙදුම් තේමාව',
      AppLanguage.singlish: 'ඇප් තීම් එක',
    },
    'theme_system': {
      AppLanguage.english: 'System',
      AppLanguage.sinhala: 'පද්ධතිය',
      AppLanguage.singlish: 'සිස්ටම්',
    },
    'theme_light': {
      AppLanguage.english: 'Light',
      AppLanguage.sinhala: 'ආලෝකය',
      AppLanguage.singlish: 'ලයිට්',
    },
    'theme_dark': {
      AppLanguage.english: 'Dark',
      AppLanguage.sinhala: 'අඳුරු',
      AppLanguage.singlish: 'ඩාර්ක්',
    },
    'theme_system_active': {
      AppLanguage.english: 'System Default Active',
      AppLanguage.sinhala: 'පද්ධති පෙරනිමිය සක්‍රියයි',
      AppLanguage.singlish: 'සිස්ටම් ඩිෆෝල්ට් ඇක්ටිව්',
    },
    'theme_light_active': {
      AppLanguage.english: 'Light Mode Active',
      AppLanguage.sinhala: 'ආලෝක ප්‍රකාරය සක්‍රියයි',
      AppLanguage.singlish: 'ලයිට් මෝඩ් ඇක්ටිව්',
    },
    'theme_dark_active': {
      AppLanguage.english: 'Dark Mode Active',
      AppLanguage.sinhala: 'අඳුරු ප්‍රකාරය සක්‍රියයි',
      AppLanguage.singlish: 'ඩාර්ක් මෝඩ් ඇක්ටිව්',
    },

    // Language Settings
    'change_language': {
      AppLanguage.english: 'Change Language',
      AppLanguage.sinhala: 'භාෂාව වෙනස් කරන්න',
      AppLanguage.singlish: 'ලැන්ග්වේජ් මාරු කරන්න',
    },
    'select_language': {
      AppLanguage.english: 'Select Language',
      AppLanguage.sinhala: 'භාෂාව තෝරන්න',
      AppLanguage.singlish: 'ලැන්ග්වේජ් එක සිලෙක්ට් කරන්න',
    },

    // Liquid Glass Setting
    'liquid_glass': {
      AppLanguage.english: 'Apple Liquid Glass Style',
      AppLanguage.sinhala: 'දියර වීදුරු විලාසය',
      AppLanguage.singlish: 'ලික්විඩ් ග්ලාස් ස්ටයිල්',
    },
    'liquid_glass_sub': {
      AppLanguage.english: 'Translucent frosted glass & ambient aura',
      AppLanguage.sinhala: 'පාරභාසක වීදුරු සහ පරිසර ආලෝක ආචරණය',
      AppLanguage.singlish: 'ෆ්‍රොස්ටඩ් ග්ලාස් සහ ඕරා ඉෆෙක්ට්',
    },

    // Categorized Setting
    'categorized_option': {
      AppLanguage.english: 'Categorized Documents',
      AppLanguage.sinhala: 'වර්ගීකරණය කළ ලේඛන',
      AppLanguage.singlish: 'කැටගරි කරපු ඩොකියුමන්ට්ස්',
    },
    'categorized_sub': {
      AppLanguage.english: 'Group documents by Insurance, Revenue License, and QR',
      AppLanguage.sinhala: 'රක්ෂණ, ආදායම් බලපත්‍ර සහ QR අනුව කාණ්ඩගත කිරීම',
      AppLanguage.singlish: 'ඉන්ෂුවරන්ස්, රෙවනිව් ලයිසන් සහ කියුආර් වෙන වෙනම පෙන්නන්න',
    },

    // Security & Biometrics
    'biometric_delete': {
      AppLanguage.english: 'Biometric Deletion Protection',
      AppLanguage.sinhala: 'ජෛවමිතික මඟින් ලේඛන මැකීමේ ආරක්ෂාව',
      AppLanguage.singlish: 'බයෝමෙට්‍රික් ඩිලීට් ප්‍රොටෙක්ෂන්',
    },
    'biometric_delete_sub': {
      AppLanguage.english: 'Require fingerprint, Face ID, or passcode before deleting documents (Default ON)',
      AppLanguage.sinhala: 'ලේඛන මැකීමට පෙර ඇඟිලි සලකුණ හෝ මුරපදය තහවුරු කිරීම (පෙරනිමියෙන් සක්‍රියයි)',
      AppLanguage.singlish: 'ඩොකියුමන්ට් ඩිලීට් කරන්න කලින් ෆින්ගර්ප්‍රින්ට් එක හරි පාස්වර්ඩ් එක හරි ඉල්ලන්න (ඩිෆෝල්ට් ඔන්)',
    },

    // Gemini AI Auto-Fill
    'gemini_api_title': {
      AppLanguage.english: 'Gemini AI Document Scanner',
      AppLanguage.sinhala: 'Gemini AI ලේඛන ස්කෑනරය',
      AppLanguage.singlish: 'ජෙමිනයි AI ඩොකියුමන්ට් ස්කෑනර්',
    },
    'gemini_api_sub': {
      AppLanguage.english: 'Auto-fill vehicle details using Gemini Vision model',
      AppLanguage.sinhala: 'Gemini Vision ආකෘතිය භාවිතයෙන් වාහන විස්තර ස්වයංක්‍රීයව පිරවීම',
      AppLanguage.singlish: 'ජෙමිනයි විෂන් මොඩල් එකෙන් ඩොකියුමන්ට් විස්තර ඔටෝ ෆිල් කරන්න',
    },

    // Cloud & Logout
    'cloud_sync_title': {
      AppLanguage.english: 'Google Drive Vault Sync',
      AppLanguage.sinhala: 'Google Drive සුරක්ෂිතාගාර සමමුහුර්තකරණය',
      AppLanguage.singlish: 'ගූගල් ඩ්‍රයිව් වෝල්ට් සින්ක්',
    },
    'cloud_connected': {
      AppLanguage.english: 'Connected & Synced',
      AppLanguage.sinhala: 'සම්බන්ධ වී සමමුහුර්ත කර ඇත',
      AppLanguage.singlish: 'කනෙක්ට් වෙලා සින්ක් වෙලා තියෙන්නේ',
    },
    'cloud_offline': {
      AppLanguage.english: 'Offline Mode Active',
      AppLanguage.sinhala: 'නොබැඳි ප්‍රකාරය ක්‍රියාත්මකයි',
      AppLanguage.singlish: 'ඕෆ්ලයින් මෝඩ් එක ඇක්ටිව්',
    },
    'btn_logout': {
      AppLanguage.english: 'Sign Out of Google',
      AppLanguage.sinhala: 'ගිණුමෙන් ඉවත් වන්න',
      AppLanguage.singlish: 'ලොග් අවුට් වෙන්න',
    },
    'btn_login': {
      AppLanguage.english: 'Sign In with Google',
      AppLanguage.sinhala: 'Google සමඟ පිවිසෙන්න',
      AppLanguage.singlish: 'ගූගල් වලින් ලොග් වෙන්න',
    },
    'logout_confirm_title': {
      AppLanguage.english: 'Sign Out Confirmation',
      AppLanguage.sinhala: 'ඉවත් වීම තහවුරු කරන්න',
      AppLanguage.singlish: 'ලොග් අවුට් වෙන්න ෂුවර්ද?',
    },
    'logout_confirm_msg': {
      AppLanguage.english: 'Are you sure you want to sign out? Your offline documents will remain safely stored on this device.',
      AppLanguage.sinhala: 'ඔබට ගිණුමෙන් ඉවත් වීමට අවශ්‍ය බව සහතිකද? ඔබගේ නොබැඳි ලේඛන මෙම උපාංගයේ සුරක්ෂිතව පවතිනු ඇත.',
      AppLanguage.singlish: 'ඔයාට ෂුවර්ද ලොග් අවුට් වෙන්න ඕනෙ කියලා? ඔයාගෙ ඕෆ්ලයින් ඩොකියුමන්ට්ස් මේ ෆෝන් එකේ සේෆ් එකේ තියෙනවා.',
    },
    'cancel': {
      AppLanguage.english: 'Cancel',
      AppLanguage.sinhala: 'අවලංගු කරන්න',
      AppLanguage.singlish: 'කැන්සල්',
    },

    // Home Screen & Stats
    'summary_total': {
      AppLanguage.english: 'Total Docs',
      AppLanguage.sinhala: 'මුළු ලේඛන',
      AppLanguage.singlish: 'ඔක්කොම ඩොක්ස්',
    },
    'summary_active': {
      AppLanguage.english: 'Valid',
      AppLanguage.sinhala: 'වලංගු',
      AppLanguage.singlish: 'වැලිඩ්',
    },
    'summary_expiring': {
      AppLanguage.english: 'Expiring Soon',
      AppLanguage.sinhala: 'ඉක්මනින් කල් ඉකුත්වන',
      AppLanguage.singlish: 'ළඟදි එක්ස්පයර් වෙනවා',
    },
    'empty_title': {
      AppLanguage.english: 'No Vehicle Documents Found',
      AppLanguage.sinhala: 'වාහන ලේඛන කිසිවක් හමු නොවීය',
      AppLanguage.singlish: 'කිසිම ඩොකියුමන්ට් එකක් නෑ තාම',
    },
    'empty_subtitle': {
      AppLanguage.english: 'Scan a QR code or add your insurance and revenue licenses to get started.',
      AppLanguage.sinhala: 'ආරම්භ කිරීම සඳහා QR කේතයක් ස්කෑන් කරන්න හෝ ඔබගේ ලේඛන එකතු කරන්න.',
      AppLanguage.singlish: 'පටන් ගන්න කියුආර් එකක් ස්කෑන් කරන්න නැත්නම් ඩොකියුමන්ට්ස් ඇඩ් කරන්න.',
    },
    'btn_quick_scan': {
      AppLanguage.english: 'Scan Document Now',
      AppLanguage.sinhala: 'දැන්ම ස්කෑන් කරන්න',
      AppLanguage.singlish: 'දැන්ම ස්කෑන් කරන්න',
    },
    'search_hint': {
      AppLanguage.english: 'Search by Reg No, Title...',
      AppLanguage.sinhala: 'ලියාපදිංචි අංකය, නම අනුව සොයන්න...',
      AppLanguage.singlish: 'රෙජිස්ට්‍රේෂන් නොම්බරේ, නමෙන් හොයන්න...',
    },

    // Categories
    'cat_fuel_qr': {
      AppLanguage.english: 'Fuel Pass QR',
      AppLanguage.sinhala: 'ඉන්ධන බලපත්‍ර QR',
      AppLanguage.singlish: 'ෆුවෙල් පාස් QR',
    },
    'cat_insurance': {
      AppLanguage.english: 'Motor Insurance',
      AppLanguage.sinhala: 'මෝටර් රථ රක්ෂණය',
      AppLanguage.singlish: 'මෝටර් ඉන්ෂුවරන්ස්',
    },
    'cat_revenue': {
      AppLanguage.english: 'Revenue License',
      AppLanguage.sinhala: 'ආදායම් බලපත්‍රය',
      AppLanguage.singlish: 'රෙවනිව් ලයිසන් එක',
    },
    'cat_custom': {
      AppLanguage.english: 'Other Documents',
      AppLanguage.sinhala: 'වෙනත් ලේඛන',
      AppLanguage.singlish: 'වෙනත් ඩොකියුමන්ට්ස්',
    },

    // Scanner
    'scanner_title': {
      AppLanguage.english: 'Document & QR Scanner',
      AppLanguage.sinhala: 'ලේඛන සහ QR ස්කෑනරය',
      AppLanguage.singlish: 'ඩොකියුමන්ට් සහ QR ස්කෑනර්',
    },
    'scan_instruction': {
      AppLanguage.english: 'Align National Fuel Pass QR or Vehicle Document within frame',
      AppLanguage.sinhala: 'ඉන්ධන පාස් QR හෝ වාහන ලේඛනය රාමුව තුළ තබන්න',
      AppLanguage.singlish: 'ෆුවෙල් පාස් QR එක හරි ලේඛනය හරි මේ කොටුව ඇතුලට අල්ලන්න',
    },
    'save_to_vault': {
      AppLanguage.english: 'Save to Sandboxed Vault',
      AppLanguage.sinhala: 'සුරක්ෂිතාගාරයේ තැන්පත් කරන්න',
      AppLanguage.singlish: 'වෝල්ට් එකට සේව් කරන්න',
    },
    'veh_reg_no': {
      AppLanguage.english: 'Vehicle Registration No (e.g. WP CAB-1234)',
      AppLanguage.sinhala: 'වාහන ලියාපදිංචි අංකය (උදා: WP CAB-1234)',
      AppLanguage.singlish: 'වාහන රෙජිස්ට්‍රේෂන් නොම්බරේ (උදා: WP CAB-1234)',
    },
    'doc_title': {
      AppLanguage.english: 'Document Title',
      AppLanguage.sinhala: 'ලේඛනයේ නම',
      AppLanguage.singlish: 'ඩොකියුමන්ට් එකේ නම',
    },
    'policy_no': {
      AppLanguage.english: 'Policy / Certificate / Ref No',
      AppLanguage.sinhala: 'පොලිසි / සහතික / යොමු අංකය',
      AppLanguage.singlish: 'පොලිසි / රෙෆරන්ස් නොම්බරේ',
    },
    'expiry_date': {
      AppLanguage.english: 'Expiry Date',
      AppLanguage.sinhala: 'කල් ඉකුත්වන දිනය',
      AppLanguage.singlish: 'එක්ස්පයරි ඩේට් එක',
    },
    'demo_generator': {
      AppLanguage.english: 'Generate Instant Sample Document',
      AppLanguage.sinhala: 'ක්ෂණික ආදර්ශ ලේඛනයක් ජනනය කරන්න',
      AppLanguage.singlish: 'ටෙස්ට් කරන්න සැම්පල් ඩොකියුමන්ට් එකක් හදන්න',
    },
  };

  static String get(String key, AppLanguage lang) {
    final entry = _localizedValues[key];
    if (entry == null) return key;
    return entry[lang] ?? entry[AppLanguage.english] ?? key;
  }
}
