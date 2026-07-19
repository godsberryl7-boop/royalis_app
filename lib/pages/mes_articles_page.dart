import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/article.dart';
import 'detail_page.dart';

class MesArticlesPage extends StatefulWidget {
  const MesArticlesPage({super.key});

  @override
  State<MesArticlesPage> createState() => _MesArticlesPageState();
}

class _MesArticlesPageState extends State<MesArticlesPage> {
  // ✨ Stockage du Future pour éviter les requêtes réseau en boucle au build
  late Future<List<Article>> _articlesFuture;

  @override
  void initState() {
    super.initState();
    _rafraichirArticles();
  }

  void _rafraichirArticles() {
    setState(() {
      _articlesFuture = chargerMesArticles();
    });
  }

  Future<List<Article>> chargerMesArticles() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];

    final data = await Supabase.instance.client
        .from('articles')
        .select()
        .eq('vendeur', user.email!);

    return data.map<Article>((item) => Article.fromMap(item)).toList();
  }

  Future<void> supprimerArticle(Article article) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Récupération des conversations associées à l'article
    final conversations = await Supabase.instance.client
        .from('conversations')
        .select('id')
        .eq('article_id', article.id!);

    // Extraction rapide de tous les IDs de conversations pour éviter une boucle de requêtes
    final conversationIds = conversations.map((c) => c['id']).toList();

    if (conversationIds.isNotEmpty) {
      // Suppression de tous les messages d'un coup grâce au filtre .in_()
      // ✨ Correction : Utilisez .inFilter
await Supabase.instance.client
    .from('messages')
    .delete()
    .inFilter('conversation_id', conversationIds);
    }

    // Suppression en bloc des autres tables liées
    await Supabase.instance.client
        .from('conversations')
        .delete()
        .eq('article_id', article.id!);

    await Supabase.instance.client
        .from('favoris')
        .delete()
        .eq('article_id', article.id!);

    await Supabase.instance.client
        .from('encheres')
        .delete()
        .eq('article_id', article.id!);

    await Supabase.instance.client
        .from('signalements')
        .delete()
        .eq('article_id', article.id!);

    // Enfin, suppression de l'article
    await Supabase.instance.client
        .from('articles')
        .delete()
        .eq('id', article.id!)
        .eq('vendeur', user.email!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Mes Articles",
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1F2937)),
      ),
      body: FutureBuilder<List<Article>>(
        future: _articlesFuture, // ✨ Utilisation de la variable stabilisée
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text("Une erreur est survenue : ${snapshot.error}"),
            );
          }

          final articles = snapshot.data ?? [];

          if (articles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    "Vous n'avez publié aucun article",
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
            itemCount: articles.length,
            itemBuilder: (context, index) {
              final article = articles[index];

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetailPage(article: article),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: article.imageUrl.isNotEmpty
                              ? Image.network(
                                  article.imageUrl,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 80,
                                  height: 80,
                                  color: Colors.grey.shade200,
                                  child: Icon(Icons.image, color: Colors.grey.shade400, size: 35),
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                article.nom,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${article.prix} FCFA",
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFD4AF37),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.remove_red_eye_outlined, size: 14, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Text(
                                    "${article.vues}",
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(Icons.favorite_border, size: 14, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Text(
                                    "${article.favoris}",
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () async {
                            final confirmer = await showDialog<bool>(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  title: const Text(
                                    "Supprimer l'article ?",
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  content: Text("Voulez-vous vraiment supprimer définitivement l'article « ${article.nom} » ?"),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: Text(
                                        "Annuler",
                                        style: TextStyle(color: Colors.grey.shade600),
                                      ),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text("Supprimer"),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (confirmer == true) {
                              try {
                                await supprimerArticle(article);
                              } catch (e) {
                                if (!context.mounted) return;

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Erreur lors de la suppression : ${e.toString()}"),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              if (!context.mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Article supprimé avec succès"),
                                  backgroundColor: Colors.green,
                                ),
                              );

                              // ✨ Actualise proprement la liste sans clignotement inutile
                              _rafraichirArticles();
                            }
                          },
                        ),
                      ],
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