import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/article.dart';
import '../models/enchere.dart';
import '../providers/article_providers.dart';
import '../providers/enchere_providers.dart';
import '../providers/favori_providers.dart';
import '../services/repositories/enchere_repository.dart';
import '../services/repositories/favori_repository.dart';
import 'chat_page.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class RoyalisColors {
  static const Color premiumBg = Color(0xFFF5F3EE);
  static const Color darkText = Color(0xFF1F2937);
  static const Color gold = Color(0xFFD4AF37);
  static const Color lightGray = Color(0xFF9CA3AF);
  static const Color borderGray = Color(0xFFE5E7EB);
}

class DetailPageRefactored extends ConsumerStatefulWidget {
  final Article article;

  const DetailPageRefactored({super.key, required this.article});

  @override
  ConsumerState<DetailPageRefactored> createState() =>
      _DetailPageRefactoredState();
}

class _DetailPageRefactoredState extends ConsumerState<DetailPageRefactored> {
  late Timer _timerMinuteur;
  final enchereController = TextEditingController();
  bool isLoadingEnchere = false;

  @override
  void initState() {
    super.initState();
    _timerMinuteur = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timerMinuteur.cancel();
    enchereController.dispose();
    super.dispose();
  }

  bool _enchereTerminee(Article article) {
    if (article.createdAt == null) return false;
    final fin =
        article.createdAt!.add(Duration(hours: article.duree));
    return DateTime.now().isAfter(fin);
  }

  String _tempsRestant(Article article) {
    if (article.createdAt == null) return "Temps inconnu";

    final fin =
        article.createdAt!.add(Duration(hours: article.duree));
    final restant = fin.difference(DateTime.now());

    if (restant.isNegative) return "🔒 Enchère terminée";

    final jours = restant.inDays;
    final heures = restant.inHours % 24;
    final minutes = restant.inMinutes % 60;
    final secondes = restant.inSeconds % 60;

    if (jours > 0) {
      return "$jours j $heures h $minutes m";
    }
    return "${heures.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secondes.toString().padLeft(2, '0')}";
  }

  Future<void> _soumettreEnchere(Article article) async {
    final user = Supabase.instance.client.auth.currentUser;
    final enchereRepository = EnchereRepository();

    if (user == null) {
      _afficherErreur('Connexion requise');
      return;
    }

    if (user.email == article.vendeur) {
      _afficherErreur(
          'Vous ne pouvez pas enchérir sur votre propre article');
      return;
    }

    if (_enchereTerminee(article)) {
      _afficherErreur('Cette enchère est terminée');
      return;
    }

    final montantText = enchereController.text.trim();
    if (montantText.isEmpty) {
      _afficherErreur('Veuillez saisir un montant');
      return;
    }

    final montant = int.tryParse(montantText);
    if (montant == null) {
      _afficherErreur('Montant invalide');
      return;
    }

    setState(() => isLoadingEnchere = true);

    try {
      await enchereRepository.soumettreEnchere(
        articleId: article.id!,
        montant: montant,
      );

      enchereController.clear();
      FocusScope.of(context).unfocus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Enchère acceptée !'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Rafraîchit les données via Riverpod
      ref.refresh(articleDetailProvider(article.id!));
      ref.refresh(encheresStreamProvider(article.id!));
    } catch (e) {
      _afficherErreur(e.toString());
    } finally {
      if (mounted) {
        setState(() => isLoadingEnchere = false);
      }
    }
  }

  void _afficherErreur(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch l'article en temps réel (Riverpod cache + stream)
    final articleAsync =
        ref.watch(articleDetailProvider(widget.article.id!));

    return Scaffold(
      backgroundColor: RoyalisColors.premiumBg,
      appBar: _buildAppBar(),
      body: articleAsync.when(
        data: (article) {
          final estFini = _enchereTerminee(article);
          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildImageHeader(article, estFini),
                    _buildArticleInfo(article),
                    _buildVendeurSection(article),
                    _buildDescriptionSection(article),
                    _buildPriceAndTimerRow(article),
                    _buildEncharesSection(article),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              _buildBidFooter(article, estFini),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(RoyalisColors.gold),
          ),
        ),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.red.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                'Erreur de chargement',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.red.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.refresh(articleDetailProvider(widget.article.id!)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: RoyalisColors.darkText,
                  foregroundColor: RoyalisColors.gold,
                ),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios,
          color: RoyalisColors.darkText,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Détail de l\'article',
        style: TextStyle(
          color: RoyalisColors.darkText,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildImageHeader(Article article, bool estFini) {
    return Stack(
      children: [
        Hero(
          tag: 'article-${article.id}',
          child: article.imageUrl.isNotEmpty
              ? Image.network(
                  article.imageUrl,
                  height: 320,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
                )
              : _buildImagePlaceholder(),
        ),
        Positioned(
          bottom: 15,
          left: 15,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: estFini
                  ? Colors.red.withOpacity(0.9)
                  : RoyalisColors.gold.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              estFini ? "TERMINÉE" : "EN COURS",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        Positioned(
          top: 15,
          right: 15,
          child: _buildFavoriButton(article),
        ),
      ],
    );
  }

  Widget _buildFavoriButton(Article article) {
    final estFavoriAsync = ref.watch(estFavoriProvider(article.id!));
    final favoriRepository = FavoriRepository();

    return estFavoriAsync.when(
      data: (estFavori) => GestureDetector(
        onTap: () async {
          try {
            if (estFavori) {
              await favoriRepository.supprimerFavori(article.id!);
            } else {
              await favoriRepository.ajouterFavori(article.id!);
            }
            ref.refresh(estFavoriProvider(article.id!));
            ref.refresh(mesFavorisProvider);
          } catch (e) {
            _afficherErreur(e.toString());
          }
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 6,
              ),
            ],
          ),
          child: Icon(
            estFavori ? Icons.favorite : Icons.favorite_border,
            color: estFavori ? Colors.red : RoyalisColors.gold,
            size: 24,
          ),
        ),
      ),
      loading: () => const SizedBox(
        height: 40,
        width: 40,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => GestureDetector(
        onTap: () => ref.refresh(estFavoriProvider(article.id!)),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.favorite_border,
            color: RoyalisColors.gold,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: 320,
      width: double.infinity,
      color: Colors.grey.shade200,
      child: const Icon(
        Icons.image_outlined,
        size: 80,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildArticleInfo(Article article) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            article.nom,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: RoyalisColors.darkText,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: RoyalisColors.gold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              article.categorie,
              style: const TextStyle(
                color: RoyalisColors.gold,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendeurSection(Article article) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 25),
          const Text(
            'À propos du vendeur',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: RoyalisColors.darkText,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: RoyalisColors.borderGray),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: RoyalisColors.darkText,
                  child: Text(
                    article.vendeur.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: RoyalisColors.gold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    article.vendeur,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.chat_bubble_outline,
                    color: RoyalisColors.gold,
                  ),
                  onPressed: () => _ouvrirChat(article),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _ouvrirChat(Article article) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _afficherErreur('Connexion requise');
      return;
    }

    try {
      final conversationExistante = await Supabase.instance.client
          .from('conversations')
          .select()
          .eq('article_id', article.id!)
          .eq('acheteur', user.email!);

      int conversationId;

      if (conversationExistante.isNotEmpty) {
        conversationId = conversationExistante.first['id'];
      } else {
        final nouvelleConversation = await Supabase.instance.client
            .from('conversations')
            .insert({
              'article_id': article.id!,
              'vendeur': article.vendeur,
              'acheteur': user.email,
            })
            .select();

        conversationId = nouvelleConversation.first['id'];
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatPage(
              conversationId: conversationId,
              nomCorrespondant: article.vendeur,
            ),
          ),
        );
      }
    } catch (e) {
      _afficherErreur('Erreur: ${e.toString()}');
    }
  }

  Widget _buildDescriptionSection(Article article) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Description',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: RoyalisColors.darkText,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            article.description,
            style: const TextStyle(
              fontSize: 14,
              color: RoyalisColors.lightGray,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceAndTimerRow(Article article) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: RoyalisColors.borderGray),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Offre actuelle',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${article.prix} FCFA',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: RoyalisColors.gold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: RoyalisColors.darkText,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Temps restant',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _tempsRestant(article),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEncharesSection(Article article) {
    final encheresAsync = ref.watch(encheresStreamProvider(article.id!));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Historique des enchères',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: RoyalisColors.darkText,
            ),
          ),
          const SizedBox(height: 12),
          encheresAsync.when(
            data: (encheres) {
              if (encheres.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Aucune enchère pour le moment',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: encheres.length,
                itemBuilder: (context, index) {
                  final enchere = encheres[index];
                  final isLeader = index == 0;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isLeader
                          ? RoyalisColors.gold.withOpacity(0.1)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isLeader
                            ? RoyalisColors.gold
                            : RoyalisColors.borderGray,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (isLeader)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: RoyalisColors.gold,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '🏆 Leader',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        if (!isLeader) const SizedBox(width: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                enchere.utilisateur,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (enchere.createdAt != null)
                                Text(
                                  enchere.createdAt!.toString().split('.')[0],
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          '${enchere.montant} FCFA',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isLeader
                                ? RoyalisColors.gold
                                : RoyalisColors.darkText,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(RoyalisColors.gold),
              ),
            ),
            error: (error, stackTrace) => Center(
              child: Text(
                'Erreur: ${error.toString()}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBidFooter(Article article, bool estFini) {
    final user = Supabase.instance.client.auth.currentUser;
    final estVendeur = user?.email == article.vendeur;

    if (estVendeur || estFini) {
      return Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(
                color: Colors.grey.shade200,
              ),
            ),
          ),
          child: Center(
            child: Text(
              estVendeur ? 'Vous êtes le vendeur' : 'Enchère terminée',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
        ),
      );
    }

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: Colors.grey.shade200,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: enchereController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Entrer montant',
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: RoyalisColors.gold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: isLoadingEnchere
                  ? null
                  : () => _soumettreEnchere(article),
              style: ElevatedButton.styleFrom(
                backgroundColor: RoyalisColors.darkText,
                foregroundColor: RoyalisColors.gold,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isLoadingEnchere
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          RoyalisColors.gold,
                        ),
                      ),
                    )
                  : const Text(
                      'Enchérir',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
