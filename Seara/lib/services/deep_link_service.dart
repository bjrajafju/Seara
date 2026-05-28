import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:protocol_handler/protocol_handler.dart';
import 'package:app_links/app_links.dart';
import '../providers/auth_provider.dart';
import '../main.dart' show navigatorKey;

class DeepLinkService with ProtocolListener {
  static final DeepLinkService instance = DeepLinkService._();
  AuthProvider? _authProvider;
  StreamSubscription<Uri>? _linkSubscription;

  DeepLinkService._() {
    protocolHandler.addListener(this);
  }

  void init(AuthProvider authProvider) async {
    _authProvider = authProvider;

    // 1. Escutar links em tempo de execução
    _linkSubscription?.cancel();
    _linkSubscription = AppLinks().uriLinkStream.listen((uri) {
      handle(uri, authProvider: _authProvider);
    });

    // 2. Tratar link inicial (quando a app estava fechada)
    Uri? initialUri;
    try {
      initialUri = await AppLinks().getInitialLink();
    } catch (e) {
      debugPrint("DeepLinkService: Erro ao capturar link inicial: $e");
    }

    if (initialUri != null) {
      handle(initialUri, authProvider: _authProvider);
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
    protocolHandler.removeListener(this);
  }

  @override
  void onProtocolUrlReceived(String url) {
    debugPrint('DeepLinkService: Received protocol URL: $url');
    handle(Uri.parse(url), authProvider: _authProvider);
  }

  static void handle(Uri uri, {AuthProvider? authProvider}) async {
    debugPrint('DeepLinkService: Handling URI: $uri');
    
    // Suportar tanto o esquema customizado quanto links de localhost (Web) ou domínio real
    final isSearaScheme = uri.scheme == 'seara';
    final isWebReset = uri.fragment.contains('type=recovery') || uri.queryParameters.containsKey('code');

    if (!isSearaScheme && !isWebReset) return;

    final isRecovery = (uri.host == 'auth' && uri.path == '/recovery') || isWebReset;

    if (isRecovery) {
      debugPrint('DeepLinkService: Recovery flow detected');
      
      // Mostrar loading state se possível
      if (authProvider != null) {
        authProvider.setRecovering(true);
        authProvider.setRecoveryHandled(false);
      }

      // Informar o Supabase sobre a nova URL de sessão (necessário para extrair tokens)
      try {
        await Supabase.instance.client.auth.getSessionFromUrl(uri);
        debugPrint('DeepLinkService: Session processing complete');
        
        // Validar se temos uma sessão válida após o processamento da URL
        final session = Supabase.instance.client.auth.currentSession;
        final user = session?.user;

        if (session == null || user == null) {
          debugPrint('DeepLinkService: Invalid or expired recovery link');
          
          if (authProvider != null) {
            authProvider.setRecovering(false);
          }

          // Mostrar erro ao utilizador
          if (navigatorKey.currentContext != null) {
            ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
              const SnackBar(
                content: Text('Este link de recuperação já expirou ou já foi utilizado.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        debugPrint('DeepLinkService: Recovery session established for ${user.email}');
      } catch (e) {
        debugPrint('DeepLinkService: Error establishing session: $e');
        
        if (authProvider != null) {
          authProvider.setRecovering(false);
        }

        if (navigatorKey.currentContext != null) {
          ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
            const SnackBar(
              content: Text('Não foi possível validar o link de recuperação. Tenta novamente.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Se o navigatorKey já estiver disponível, navegar
      // Usamos pushNamedAndRemoveUntil para limpar a stack e evitar loops
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/reset-password',
          (route) => route.isFirst,
        );
      }
    }
  }
}
