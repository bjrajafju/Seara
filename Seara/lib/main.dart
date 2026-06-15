import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:media_kit/media_kit.dart';
import 'package:seara/providers/messages_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/settings/themes_screen.dart';
import 'screens/settings/privacy_screen.dart';
import 'screens/messages/messages_screen.dart';
import 'screens/daily_question/daily_question_screen.dart';
import 'screens/auth/welcome_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'controllers/post_feed_controller.dart';
import 'controllers/story_feed_controller.dart';
import 'services/auth_error_handler.dart';
import 'services/deep_link_service.dart';
import 'services/feed/audio_preferences_service.dart';
import 'services/time_service.dart';
import 'services/auto_update_service.dart';
import 'screens/update_screen.dart';
import 'widgets/desync_error_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Starts the app and wires top-level providers
void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    await windowManager.ensureInitialized();
    if (await _handleSingleInstance(args)) {
      return;
    }
    await _registerWindowsProtocol();
  }

  await Future.delayed(const Duration(seconds: 3));

  await Supabase.initialize(
    url: 'https://nzxmjazsegtsmsdqnisq.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im56eG1qYXpzZWd0c21zZHFuaXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTkwNjExMzMsImV4cCI6MjA3NDYzNzEzM30.kRJQfqNMJDK4RWxxMT2tcQYrugyesedxrX-V9Nq8_mU',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
      autoRefreshToken: false,
    ),
  );

  MediaKit.ensureInitialized();
  JustAudioMediaKit.ensureInitialized();
  await AudioPreferencesService.init();
  await TimeService.syncTime();

  if (kIsWeb) {
    FilePicker.platform = FilePicker.platform;
  }

  final themeProvider = ThemeProvider();
  await themeProvider.init();
  final authProvider = AuthProvider();

  // Inicializar o serviço de links centralizado
  DeepLinkService.instance.init(authProvider);

  authProvider.addListener(() async {
    if (authProvider.isLoggedIn) {
      await themeProvider.loadThemeForCurrentUser();
    } else if (!authProvider.isLoggedIn && !authProvider.isChecking) {
      await themeProvider.loadThemeForUser(null);
    }
  });

  await authProvider.checkSession();
  runApp(SearaApp(themeProvider: themeProvider, authProvider: authProvider));
}

class SearaApp extends StatefulWidget {
  const SearaApp({
    super.key,
    required this.themeProvider,
    required this.authProvider,
  });

  final ThemeProvider themeProvider;
  final AuthProvider authProvider;

  @override
  State<SearaApp> createState() => _SearaAppState();
}

class _SearaAppState extends State<SearaApp> {
  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<bool>? _desyncSubscription;
  bool _hasCriticalDesync = false;

  // Estado de Atualização
  bool _isCheckingUpdate = true;
  UpdateInfo? _updateInfo;
  UpdateStatus _updateStatus = UpdateStatus.upToDate;

  @override
  void initState() {
    super.initState();
    _checkUpdate();
    _hasCriticalDesync = TimeService.hasCriticalDesync;
    _desyncSubscription = TimeService.desyncStream.listen((isCritical) {
      setState(() {
        _hasCriticalDesync = isCritical;
      });
    });
  }

  Future<void> _checkUpdate() async {
    if (!kIsWeb && Platform.isWindows) {
      final result = await AutoUpdateService.checkUpdate();
      print("UPDATE RESULT: ${result['status']}");
      if (mounted) {
        setState(() {
          _updateStatus = result['status'] as UpdateStatus;
          _updateInfo = result['info'] as UpdateInfo?;
          _isCheckingUpdate = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _desyncSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: widget.authProvider),
        ChangeNotifierProvider<ThemeProvider>.value(
          value: widget.themeProvider,
        ),
        ChangeNotifierProvider(create: (_) => MessagesProvider()),
        ChangeNotifierProvider(create: (_) => StoryFeedController()),
        ChangeNotifierProvider(create: (_) => PostFeedController()),
      ],

      child: Consumer2<AuthProvider, ThemeProvider>(
        builder: (context, auth, theme, _) {
          // Prioridade absoluta para o ecrã de reset se houver um link de recuperação ativo
          // Na Web, o processamento pode demorar, por isso verificamos a URL.
          // Em Desktop, o auth.isRecovering é setado pelo DeepLinkService após validar a sessão.
          final bool isRecoveryInUrl =
              kIsWeb &&
              (Uri.base.fragment.contains('type=recovery') ||
                  Uri.base.queryParameters.containsKey('code'));

          final bool shouldShowReset =
              (isRecoveryInUrl || auth.isRecovering) && !auth.recoveryHandled;

          return MaterialApp(
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            title: 'SEARA',
            scrollBehavior: const MaterialScrollBehavior().copyWith(
              dragDevices: {
                ui.PointerDeviceKind.touch,
                ui.PointerDeviceKind.mouse,
                ui.PointerDeviceKind.trackpad,
              },
            ),
            themeMode: ThemeMode.light,
            theme: theme.currentTheme,
            home: _isCheckingUpdate
                ? const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  )
                : _updateStatus != UpdateStatus.upToDate
                ? UpdateScreen(
                    updateInfo: _updateInfo!,
                    isForced: _updateStatus == UpdateStatus.forcedUpdate,
                  )
                : _hasCriticalDesync
                ? const DesyncErrorScreen()
                : auth.authErrorMessage != null
                ? Scaffold(
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(auth.authErrorMessage!),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              auth.clearAuthError();
                              auth.checkSession();
                            },
                            child: const Text("Tentar Novamente"),
                          ),
                          TextButton(
                            onPressed: () => auth.logout(),
                            child: const Text("Ir para Login"),
                          ),
                        ],
                      ),
                    ),
                  )
                : shouldShowReset
                ? const ResetPasswordScreen()
                : (auth.isChecking || auth.isRecovering)
                ? const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  )
                : auth.isLoggedIn
                ? const HomeScreen()
                : const WelcomeScreen(),
            routes: {
              '/home': (ctx) => const HomeScreen(),
              '/profile': (ctx) => const ProfileScreen(),
              '/settings': (ctx) => const SettingsScreen(),
              '/themes': (ctx) => const ThemesScreen(),
              '/privacy': (ctx) => const PrivacyScreen(),
              '/messages': (ctx) => const MessagesScreen(),
              '/daily-question': (ctx) => const DailyQuestionScreen(),
              '/reset-password': (ctx) => const ResetPasswordScreen(),
            },
          );
        },
      ),
    );
  }
}

/// Registra o esquema de URL no Windows Registry para suporte a Deep Links
Future<void> _registerWindowsProtocol() async {
  try {
    final exePath = Platform.resolvedExecutable;
    const protocol = 'seara';

    // HKCU (Current User) não requer privilégios de administrador
    await Process.run('reg', [
      'add',
      'HKCU\\Software\\Classes\\$protocol',
      '/ve',
      '/d',
      'URL:seara Protocol',
      '/f',
    ]);
    await Process.run('reg', [
      'add',
      'HKCU\\Software\\Classes\\$protocol',
      '/v',
      'URL Protocol',
      '/d',
      '',
      '/f',
    ]);
    await Process.run('reg', [
      'add',
      'HKCU\\Software\\Classes\\$protocol\\shell\\open\\command',
      '/ve',
      '/d',
      '"$exePath" "%1"',
      '/f',
    ]);
  } catch (e) {
    debugPrint("Erro ao registrar protocolo Windows: $e");
  }
}

/// Lida com a instância única no Windows usando sockets
Future<bool> _handleSingleInstance(List<String> args) async {
  try {
    // Tenta conectar ao porto onde a primeira instância estaria a ouvir
    final socket = await Socket.connect(
      '127.0.0.1',
      54321,
      timeout: const Duration(milliseconds: 500),
    );

    // Se conectou, outra instância está ativa. Enviamos os argumentos.
    if (args.isNotEmpty) {
      socket.write(args.join(' '));
    }
    await socket.flush();
    await socket.close();
    return true; // Somos a segunda instância, devemos fechar
  } catch (_) {
    // Nenhuma instância no porto, seremos a primeira
    _startSingleInstanceServer();
    return false;
  }
}

void _startSingleInstanceServer() async {
  try {
    final server = await ServerSocket.bind('127.0.0.1', 54321);
    server.listen((socket) {
      socket.listen((data) {
        final message = String.fromCharCodes(data).trim();
        if (message.isNotEmpty) {
          if (message.startsWith('seara://')) {
            DeepLinkService.handle(Uri.parse(message));
          }
        }
        // Trazer a janela para a frente
        windowManager.show();
        windowManager.focus();
      });
    });
  } catch (e) {
    debugPrint("SingleInstance: Erro ao iniciar servidor: $e");
  }
}
