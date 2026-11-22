import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Adresse de retour après un lien de confirmation email ou une connexion Google.
///
/// - Web : l'origine de la page courante (ex. http://localhost:5000 en local, l'URL Vercel en
///   production). Elle doit figurer dans Supabase → Authentication → URL Configuration →
///   Redirect URLs, sinon Supabase renvoie vers la « Site URL » par défaut.
/// - Mobile : schéma profond déclaré dans AndroidManifest.xml et Info.plist.
const String kMobileAuthCallback = 'com.elearning.student.student_app://login-callback';

String? get authRedirectUrl => kIsWeb ? Uri.base.origin : kMobileAuthCallback;

/// Traduit les erreurs Supabase Auth (en anglais, parfois techniques) en messages clairs pour un
/// élève. Codes : https://supabase.com/docs/guides/auth/debugging/error-codes
String frenchAuthMessage(Object error) {
  if (error is AuthException) {
    switch (error.code) {
      case 'invalid_credentials':
        return 'Email ou mot de passe incorrect.';
      case 'email_not_confirmed':
        return 'Votre adresse email n\'est pas encore confirmée. Ouvrez le lien reçu par email '
            '(pensez à regarder dans les spams).';
      case 'user_already_exists':
      case 'email_exists':
        return 'Un compte existe déjà avec cette adresse email.';
      case 'weak_password':
        return 'Mot de passe trop faible : au moins 8 caractères, avec des lettres et des chiffres.';
      case 'email_address_invalid':
        return 'Adresse email invalide.';
      case 'over_email_send_rate_limit':
      case 'over_request_rate_limit':
        return 'Trop de tentatives en peu de temps. Patientez quelques minutes puis réessayez.';
      case 'signup_disabled':
      case 'email_provider_disabled':
        return 'Les inscriptions par email sont momentanément fermées.';
      case 'provider_disabled':
        return 'La connexion avec Google n\'est pas encore activée sur la plateforme.';
      case 'same_password':
        return 'Le nouveau mot de passe doit être différent de l\'ancien.';
    }
    if (error is AuthRetryableFetchException || error.statusCode == null) {
      return 'Connexion impossible. Vérifiez votre accès à internet puis réessayez.';
    }
    if (error.statusCode == '429') {
      return 'Trop de tentatives en peu de temps. Patientez quelques minutes puis réessayez.';
    }
    return error.message;
  }
  final text = error.toString();
  if (text.contains('SocketException') ||
      text.contains('Failed host lookup') ||
      text.contains('ClientException') ||
      text.contains('XMLHttpRequest')) {
    return 'Connexion impossible. Vérifiez votre accès à internet puis réessayez.';
  }
  return 'Une erreur inattendue est survenue. Réessayez dans un instant.';
}

/// Vrai si l'erreur signifie « email pas encore confirmé » (pour proposer de renvoyer l'email).
bool isEmailNotConfirmed(Object error) =>
    error is AuthException && error.code == 'email_not_confirmed';
