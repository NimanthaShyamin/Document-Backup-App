import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'core/hardware/notification_engine.dart';
import 'core/storage/file_storage_manager.dart';
import 'core/theme/app_preferences_provider.dart';
import 'data/datasources/local/app_database.dart';
import 'data/datasources/remote/drive_sync_service.dart';
import 'data/datasources/remote/google_auth_service.dart';
import 'data/repositories/sync_repository.dart';
import 'presentation/screens/auth_gate.dart';

const String backgroundSyncTaskKey = 'com.vehicledocs.syncTask';

/// WorkManager Top-Level Background Task Dispatcher.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    developer.log('Executing WorkManager background sync task: $task');

    if (task == backgroundSyncTaskKey) {
      final db = AppDatabase();
      final storage = FileStorageManager();
      final auth = GoogleAuthService();

      // Perform silent sign-in in background worker isolate
      await auth.signInSilently();
      final drive = DriveSyncService(authService: auth);
      final syncRepo =
          SyncRepository(db: db, driveService: drive, storageManager: storage);

      try {
        await syncRepo.reconcile();
        await db.close();
        return true;
      } catch (e, stack) {
        developer.log('Background sync failed', error: e, stackTrace: stack);
        await db.close();
        return false;
      }
    }
    return true;
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF121214),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize local notifications engine
  await LocalNotificationEngine.instance.initialize();

  // Initialize background task scheduler
  try {
    await Workmanager().initialize(
      callbackDispatcher,
    );
    // Register periodic background sync (every 15 minutes minimum supported by OS)
    await Workmanager().registerPeriodicTask(
      'periodicSyncTask',
      backgroundSyncTaskKey,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  } catch (e) {
    developer.log('WorkManager initialization note: $e');
  }

  // Preload SharedPreferences synchronously for instant preference availability
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const VehicleDocumentVaultApp(),
    ),
  );
}

class VehicleDocumentVaultApp extends ConsumerWidget {
  const VehicleDocumentVaultApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Vehicle Document Vault',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        primaryColor: const Color(0xFF2563EB),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF2563EB),
          secondary: Color(0xFF38BDF8),
          surface: Color(0xFFFFFFFF),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Color(0xFF0F172A),
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF03061A),
        primaryColor: const Color(0xFF38BDF8),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          secondary: Color(0xFF2563EB),
          surface: Color(0xFF0C1338),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

