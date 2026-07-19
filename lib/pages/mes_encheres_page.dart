import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MesEncheresPage extends StatefulWidget {
  const MesEncheresPage({super.key});

  @override
  State<MesEncheresPage> createState() => _MesEncheresPageState();
}

class _MesEncheresPageState extends State<MesEncheresPage> {
  // ✨ Stockage du Future pour éviter les requêtes réseau en boucle
  late Future<List<Map<String, dynamic>>> _encheresFuture;

  @override
  void initState() {
    super.initState();
    _encheresFuture = chargerEncheres();
  }

  Future<List<Map<String, dynamic>>> chargerEncheres() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];

    final data = await Supabase.instance.client
        .from('encheres')
        .select()
        .eq('utilisateur', user.email!)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // Fond légèrement grisé pour détacher les cartes
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Mes Enchères",
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1F2937)),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _encheresFuture, // ✨ Utilisation de la variable stabilisée
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)), // Doré Premium
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Une erreur est survenue : ${snapshot.error}",
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final encheres = snapshot.data ?? [];

          if (encheres.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.gavel_outlined, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    "Aucune enchère placée pour le moment",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: encheres.length,
            itemBuilder: (context, index) {
              final e = encheres[index];

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.1), // Correction moderne de withOpacity
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.gavel, 
                        color: Color(0xFFD4AF37),
                        size: 24,
                      ),
                    ),
                    title: Text(
                      e['article'] ?? 'Article inconnu',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        "${e['montant']} FCFA",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFD4AF37), // Couleur Dorée Premium
                        ),
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}