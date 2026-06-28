import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/services/settings_service.dart';
import 'core/models/book.dart';
import 'features/library/library_screen.dart';
import 'features/reader/reader_screen.dart';
import 'features/settings/config_screen.dart';
import 'features/orp_editor/orp_editor_screen.dart';
import 'package:flutter/services.dart';
import 'features/library/archive_screen.dart';
import 'features/library/library_provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'core/database/book_dao.dart';
import 'core/database/orp_dao.dart';
import 'epub/epub_importer.dart';
import 'core/database/database_helper.dart';
import 'dart:async';
import 'features/companions/companion_screen.dart';

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const LibraryScreen()),
    GoRoute(
      path: '/reader/:bookId',
      builder: (context, state) {
        final book = state.extra as Book;
        return ReaderScreen(book: book);
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/orp-editor',
      builder: (context, state) => const OrpEditorScreen(),
    ),
    GoRoute(
      path: '/archive',
      builder: (context, state) => const ArchiveScreen(),
    ),
    GoRoute(
      path: '/companions',
      builder: (context, state) => const CompanionScreen(),
    ),
  ],
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  await SettingsService.instance.init();
  await DatabaseHelper.instance.seedMissingAbbreviations();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  StreamSubscription? _intentSub;

  @override
  void initState() {
    super.initState();

    // App bereits offen – Datei empfangen
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((files) {
      if (files.isNotEmpty) {
        _importEpubFromPath(files.first.path);
      }
    });

    // App kalt gestartet über Intent
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      if (files.isNotEmpty) {
        _importEpubFromPath(files.first.path);
        ReceiveSharingIntent.instance.reset();
      }
    });
  }

  @override
  void dispose() {
    _intentSub?.cancel();
    super.dispose();
  }

  Future<void> _importEpubFromPath(String path) async {
    if (!path.toLowerCase().endsWith('.epub')) return;
    final importer = EpubImporter(BookDao(), OrpDao());
    await importer.importEpubFromPath(path);
    ref.invalidate(libraryProvider);
    _router.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: MaterialApp.router(
      title: 'Speader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00B4D8),
          secondary: Color(0xFF00B4D8),
          surface: Color(0xFF112240),
        ),
        scaffoldBackgroundColor: const Color(0xFF0A1628),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A1628),
          foregroundColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        cardColor: const Color(0xFF112240),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF00B4D8);
            }
            return Colors.white54;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF00B4D8).withValues(alpha: 0.5);
            }
            return Colors.white24;
          }),
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: Color(0xFF00B4D8),
          thumbColor: Color(0xFF00B4D8),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF00B4D8)),
        ),
        dividerColor: Colors.white12,
      ),
      routerConfig: _router,
    ),
  );
  }
}
