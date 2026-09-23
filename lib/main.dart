import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';
import 'core/hardware/notification_engine.dart';
import 'core/storage/file_storage_manager.dart';
import 'data/datasources/local/app_database.dart';
import 'data/datasources/remote/drive_app_data_service.dart';
import 'data/repositories/sync_queue_repository_impl.dart';
import 'presentation/screens/document_list_screen.dart';

const String backgroundSyncTaskKey = 'com.vehicledocs.syncTask';

/// WorkManager Top-Level Background Task Dispatcher.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    developer.log('Executing WorkManager background sync task: $task');

    if (task == backgroundSyncTaskKey) {
      final db = AppDatabase();
      final storage = FileStorageManager();
      final drive = DriveAppDataService();
      final syncRepo = SyncQueueRepository(db: db, driveService: drive, storageManager: storage);

      try {
        await syncRepo.reconcileStartupDelta();
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
      isInDebugMode: false,
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

  runApp(
    const ProviderScope(
      child: VehicleDocumentVaultApp(),
    ),
  );
}

class VehicleDocumentVaultApp extends StatelessWidget {
  const VehicleDocumentVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vehicle Document Vault',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121214),
        primaryColor: Colors.amberAccent,
        colorScheme: const ColorScheme.dark(
          primary: Colors.amberAccent,
          secondary: Colors.amber,
          surface: Color(0xFF1E1E24),
          background: Color(0xFF121214),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A1E),
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: const DocumentListScreen(),
    );
  }
}
