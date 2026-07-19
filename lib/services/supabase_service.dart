import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;

class SupabaseService {
  // Instance du client Supabase obtenue de manière dynamique et sécurisée
  static SupabaseClient get client => Supabase.instance.client;

  // ==========================================
  // AUTHENTIFICATION
  // ==========================================

  /// Connexion avec email et mot de passe
  static Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      return await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on AuthException catch (e) {
      developer.log('Erreur d\'authentification (Login): ${e.message}', name: 'SupabaseService', error: e);
      rethrow; // L'UI intercepte l'AuthException pour afficher le bon message (ex: identifiants invalides)
    } catch (e) {
      developer.log('Erreur inattendue (Login): $e', name: 'SupabaseService', error: e);
      throw Exception('Une erreur inattendue est survenue lors de la connexion.');
    }
  }

  /// Inscription d'un nouvel utilisateur avec métadonnées publiques (username)
  static Future<AuthResponse> register({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      final response = await client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'username': username.trim(),
        },
      );
      return response;
    } on AuthException catch (e) {
      developer.log('Erreur d\'authentification (Register): ${e.message}', name: 'SupabaseService', error: e);
      rethrow;
    } catch (e) {
      developer.log('Erreur inattendue (Register): $e', name: 'SupabaseService', error: e);
      throw Exception('Une erreur inattendue est survenue lors de l\'inscription.');
    }
  }

  /// Déconnexion complète de l'utilisateur et fermeture des canaux en temps réel
  static Future<void> logout() async {
    try {
      await client.auth.signOut();
    } catch (e) {
      developer.log('Erreur lors de la déconnexion: $e', name: 'SupabaseService', error: e);
    }
  }

  // ==========================================
  // UTILITAIRES DE SESSION
  // ==========================================

  /// Obtenir l'utilisateur Supabase actuellement connecté
  static User? get currentUser => client.auth.currentUser;

  /// Vérifier instantanément si un utilisateur possède une session active
  static bool get isAuthenticated => client.auth.currentSession != null;

  /// Récupérer le pseudo (username) de l'utilisateur connecté depuis ses métadonnées
  static String get currentUsername {
    final metadata = currentUser?.userMetadata;
    if (metadata != null && metadata.containsKey('username')) {
      return metadata['username'] as String;
    }
    return currentUser?.email?.split('@').first ?? "Utilisateur";
  }

  /// Flux en temps réel pour écouter les changements d'état d'authentification (utilisé dans main.dart)
  static Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;
}