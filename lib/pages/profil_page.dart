// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'mes_articles_page.dart';
import 'favoris_page.dart';
import 'mes_encheres_page.dart';
import 'notifications_page.dart';
import 'conversations_page.dart';
import 'statistiques_page.dart';
import 'login_page.dart';

class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  User? user;

  @override
  void initState() {
    super.initState();
    user = Supabase.instance.client.auth.currentUser;
  }

  void ouvrirPageConnectee(Widget page) {
    if (user == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      ).then((_) {
        // Met à jour l'état si l'utilisateur s'est connecté entre-temps
        setState(() {
          user = Supabase.instance.client.auth.currentUser;
        });
      });
      return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final bool estConnecte = user != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // Fond ultra clair neutre
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Mon Profil",
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- SECTION EN-TÊTE AVATAR ---
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFD4AF37),
                        width: 2.5,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      // ✨ Remplacement de .withOpacity par .withValues
                      backgroundColor: const Color(0xFF1F2937).withValues(alpha: 0.05),
                      child: Icon(
                        Icons.person_rounded,
                        size: 55,
                        color: estConnecte ? const Color(0xFF1F2937) : Colors.grey.shade400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    estConnecte ? user!.email! : "Utilisateur non connecté",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (estConnecte)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        // ✨ Remplacement de .withOpacity par .withValues
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "👑 Membre Royalis",
                        style: TextStyle(
                          color: Color(0xFFD4AF37),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, left: 32, right: 32),
                      child: SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginPage()),
                            ).then((_) {
                              setState(() {
                                user = Supabase.instance.client.auth.currentUser;
                              });
                            });
                          },
                          icon: const Icon(Icons.login_rounded, size: 18),
                          label: const Text(
                            "Se connecter",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFD4AF37),
                            side: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- SECTION : ACTIVITÉS ET ENCHÈRES ---
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Mon activité",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF9CA3AF),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Column(
                children: [
                  buildTileMenu(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: "Conversations",
                    onTap: () => ouvrirPageConnectee(const ConversationsPage()),
                  ),
                  const Divider(height: 1, indent: 56),
                  buildTileMenu(
                    icon: Icons.inventory_2_outlined,
                    title: "Mes Articles",
                    onTap: () => ouvrirPageConnectee(const MesArticlesPage()),
                  ),
                  const Divider(height: 1, indent: 56),
                  buildTileMenu(
                    icon: Icons.emoji_events_outlined,
                    title: "Mes enchères gagnées",
                    onTap: () => ouvrirPageConnectee(const MesEncheresPage()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- SECTION : SUIVI & PERFORMANCES ---
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Performances",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF9CA3AF),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: buildTileMenu(
                icon: Icons.bar_chart_rounded,
                title: "Mes statistiques",
                onTap: () => ouvrirPageConnectee(const StatistiquesPage()),
              ),
            ),

            const SizedBox(height: 32),

            // --- BOUTON DE DÉCONNEXION ---
            if (estConnecte)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                    ),
                    title: const Text(
                      "Déconnexion du compte",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade400),
                    onTap: () async {
                      await Supabase.instance.client.auth.signOut();

                      if (!context.mounted) return;

                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                        (route) => false,
                      );
                    },
                  ),
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // Widget helper pour conserver une homogénéité parfaite des cellules
  Widget buildTileMenu({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          // ✨ Remplacement de .withOpacity par .withValues
          color: const Color(0xFF1F2937).withValues(alpha: 0.04),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFFD4AF37), size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1F2937),
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 14,
        color: Colors.grey.shade400,
      ),
      onTap: onTap,
    );
  }
}