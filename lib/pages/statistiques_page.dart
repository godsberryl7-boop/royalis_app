import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StatistiquesPage extends StatefulWidget {
  const StatistiquesPage({super.key});

  @override
  State<StatistiquesPage> createState() => _StatistiquesPageState();
}

class _StatistiquesPageState extends State<StatistiquesPage> {
  int nbArticles = 0;
  int nbVendus = 0;
  int nbAvis = 0;
  double noteMoyenne = 0;
  bool enCoursDeChargement = true;

  Future<void> chargerStats() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          enCoursDeChargement = false;
        });
      }
      return;
    }

    final email = user.email!;

    try {
      final articles = await Supabase.instance.client
          .from('articles')
          .select()
          .eq('vendeur', email);

      final vendus = await Supabase.instance.client
          .from('articles')
          .select()
          .eq('vendeur', email)
          .eq('gagnant_notifie', true);

      final avis = await Supabase.instance.client
          .from('avis')
          .select()
          .eq('vendeur', email);

      double moyenne = 0;

      if (avis.isNotEmpty) {
        int total = 0;
        for (final a in avis) {
          total += (a['note'] ?? 0) as int;
        }
        moyenne = total / avis.length;
      }

      if (!mounted) return;

      setState(() {
        nbArticles = articles.length;
        nbVendus = vendus.length;
        nbAvis = avis.length;
        noteMoyenne = moyenne;
        enCoursDeChargement = false;
      });
    } catch (e) {
      debugPrint("Erreur lors de la récupération des statistiques : $e");
      if (mounted) {
        setState(() {
          enCoursDeChargement = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    chargerStats();
  }

  Widget carteStats({
    required String titre,
    required String valeur,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFFD4AF37),
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                valeur,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                titre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF1F2937)),
        title: const Text(
          "Mes statistiques",
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: enCoursDeChargement
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
              ),
            )
          : RefreshIndicator(
              color: const Color(0xFFD4AF37),
              onRefresh: chargerStats,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                children: [
                  // Carte de bienvenue et vue globale
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1F2937), Color(0xFF374151)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Aperçu général",
                          style: TextStyle(
                            color: Color(0xFFD4AF37),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Vos performances de vente",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Mises à jour en temps réel pour suivre votre activité de vendeur.",
                          style: TextStyle(
                            color: Colors.grey.shade300,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Grille des statistiques
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.15,
                    children: [
                      carteStats(
                        titre: "Articles publiés",
                        valeur: "$nbArticles",
                        icon: Icons.inventory_2_outlined,
                      ),
                      carteStats(
                        titre: "Articles vendus",
                        valeur: "$nbVendus",
                        icon: Icons.emoji_events_outlined,
                      ),
                      carteStats(
                        titre: "Avis reçus",
                        valeur: "$nbAvis",
                        icon: Icons.forum_outlined,
                      ),
                      carteStats(
                        titre: "Note moyenne",
                        valeur: "${noteMoyenne.toStringAsFixed(1)} ★",
                        icon: Icons.star_border_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}