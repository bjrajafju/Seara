import 'package:supabase_flutter/supabase_flutter.dart';

class AuthErrorHandler {
  static String mapError(dynamic error) {
    if (error == null) return 'Ocorreu um erro desconhecido.';

    String message;
    String? code;

    if (error is AuthException) {
      message = error.message.toLowerCase();
      code = error.code?.toLowerCase();
    } else {
      message = error.toString().toLowerCase();
    }
    
    // Prioridade para códigos de erro específicos se existirem
    if (code == 'otp_expired') {
      return 'O código ou link de recuperação expirou. Pede um novo.';
    }
    if (code == 'invalid_credentials' || code == 'invalid_grant') {
      return 'Email ou palavra-passe incorretos.';
    }
    if (code == 'user_already_exists') {
      return 'Já existe uma conta com este email.';
    }
    if (code == 'weak_password') {
      return 'A palavra-passe deve ter pelo menos 6 caracteres.';
    }

    // Fallback para verificação de texto na mensagem
    if (message.contains('invalid login credentials') || 
        message.contains('invalid credentials') ||
        message.contains('invalid_grant')) {
      return 'Email ou palavra-passe incorretos.';
    }
    
    if (message.contains('new password should be different') ||
        message.contains('should be different from the old one')) {
      return 'A nova palavra-passe deve ser diferente da anterior.';
    }

    if (message.contains('weak password') || 
        message.contains('at least 6 characters') ||
        message.contains('password is too short')) {
      return 'A palavra-passe deve ter pelo menos 6 caracteres.';
    }

    if (message.contains('user already registered') || 
        message.contains('already registered') ||
        message.contains('user_already_exists')) {
      return 'Já existe uma conta com este email.';
    }

    if (message.contains('email not confirmed')) {
      return 'Por favor, confirme o seu email antes de entrar.';
    }

    if (message.contains('session expired') || 
        message.contains('jwt expired')) {
      return 'A sua sessão expirou. Inicie sessão novamente.';
    }

    if (message.contains('network error') || 
        message.contains('connection refused') ||
        message.contains('failed host lookup')) {
      return 'Problema de ligação ao servidor. Verifique a sua internet.';
    }

    if (message.contains('timeout')) {
      return 'O servidor demorou demasiado tempo a responder.';
    }
    
    // Se a mensagem já vier em Português do backend, mantê-la (ou parte dela)
    if (message.contains('obrigatórios') || message.contains('encontrado')) {
      if (error is AuthException) return error.message;
      return error.toString();
    }

    return 'Não foi possível completar a operação. Tente novamente.';
  }
}
