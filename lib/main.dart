import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'pages/main_navigation_page.dart';
import 'pages/login_page.dart';
import 'dart:developer' as developer;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialisation sécurisée via les variables d'environnement Flutter
    // Rappel Run/Build : flutter run --dart-define=SUPABASE_URL=ton_url --dart-define=SUPABASE_ANON_KEY=ta_cle
    await Supabase.initialize(
      url: const String.fromEnvironment(
        'SUPABASE_URL', 
        defaultValue: 'https://ikglzslzifixwwnldxar.supabase.co',
      ),
      publishableKey: const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        // ATTENTION : Vérifie bien que cette clé commence par "eyJ..." dans ton dashboard Supabase
        defaultValue: 'sb_publishable_d1FqgsDO8qPVmnIB-Nv9uA_mTTQNJrz',
      ),
    );
    
    developer.log('Supabase connecté avec succès !', name: 'Initialization');
  } catch (e) {
    developer.log('Échec critique de l\'initialisation Supabase', error: e, name: 'Initialization');
  }

  runApp(const MonApp());
}

class MonApp extends StatelessWidget {
  const MonApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryDark = Color(0xFF1F2937);
    const primaryGold = Color(0xFFD4AF37);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ROYALIS',
      
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF5F3EE),
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryDark,
          primary: primaryDark,
          secondary: primaryGold,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: primaryDark,
          elevation: 0.5,
          centerTitle: true,
          iconTheme: IconThemeData(color: primaryDark),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: primaryGold,
        ),
      ),

      // Gestion dynamique et résiliente de la session utilisateur
      home: StreamBuilder<AuthState>(
        stream: SupabaseService.authStateChanges,
        builder: (context, snapshot) {
          // 1. Gestion des erreurs de flux (Réseau ou expiration)
          if (snapshot.hasError) {
            return const Scaffold(
              body: Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'Erreur de connexion aux serveurs de Royalis. Veuillez vérifier votre réseau.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: primaryDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }

          // 2. Écran d'attente lors de la récupération initiale du Token de session
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          // 3. Routage réactif : L'état s'ajuste immédiatement en cas de Token invalide ou Log-out
          final session = snapshot.data?.session;
          if (session != null) {
            return const MainNavigationPage();
          }
          
          return const LoginPage();
        },
      ),
    );
  }
}