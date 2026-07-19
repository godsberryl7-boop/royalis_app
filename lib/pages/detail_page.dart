import 'package:flutter/material.dart';
import '../models/article.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_page.dart';
import 'dart:async';

/// Constantes de l'application
class RoyalisColors {
  static const Color premiumBg = Color(0xFFF5F3EE);
  static const Color darkText = Color(0xFF1F2937);
  static const Color gold = Color(0xFFD4AF37);
  static const Color lightGray = Color(0xFF9CA3AF);
  static const Color borderGray = Color(0xFFE5E7EB);
}

class RoyalisConstants {
  static const int minBidStep = 500; // Pas d'enchère minimum en FCFA
  static const int maxRetries = 3;
  static const Duration streamTimeout = Duration(seconds: 10);
}

class DetailPage extends StatefulWidget {
  final Article article;

  const DetailPage({super.key, required this.article});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  // Gestion du temps réel et synchronisation
  Timer? _timerMinuteur;
  StreamSubscription? _abonnementRealtime;
  late Article articleActuel;

  // État local
  bool estFavori = false;
  bool isLoadingFavori = false;
  bool isLoadingEnchere = false;
  late int _vues;
  late int _favorisCount;
  late int _nbEncheres;
  late int _prixActuel;

  // Contrôleurs
  final enchereController = TextEditingController();

  // Gestion d'erreurs et état
  String? erreurMessage;
  bool estConnecte = false;
  bool estVendeur = false;

  @override
  void initState() {
    super.initState();
    articleActuel = widget.article;
    _initializeLocalState();
    _verifierConnexion();
    _demarrerMiseAJourEnTempsReel();
    _traiterFinEnchere();
  }

  /// Initialise les variables d'état local
  void _initializeLocalState() {
    _vues = articleActuel.vues;
    _favorisCount = articleActuel.favoris;
    _nbEncheres = articleActuel.nbEncheres;
    _prixActuel = articleActuel.prix;
  }

  /// Vérifie la connexion utilisateur et compare avec le vendeur
  void _verifierConnexion() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      setState(() {
        estConnecte = true;
        estVendeur = user.email == articleActuel.vendeur;
      });
      _verifierFavori();
    }
  }

  /// Lance le minuteur et écoute les changements temps réel
  void _demarrerMiseAJourEnTempsReel() {
    // Minuteur pour rafraîchir l'affichage du décompte
    _timerMinuteur = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });

    // Stream Supabase pour sync en temps réel
    try {
      _abonnementRealtime = Supabase.instance.client
          .from('articles')
          .stream(primaryKey: ['id'])
          .eq('id', articleActuel.id!)
          .timeout(
            RoyalisConstants.streamTimeout,
            onTimeout: (sink) {
              debugPrint('Stream timeout pour article ${articleActuel.id}');
              sink.close();
            },
          )
          .listen(
            (List<Map<String, dynamic>> donnees) {
              if (donnees.isNotEmpty && mounted) {
                setState(() {
                  articleActuel = Article.fromMap(donnees.first);
                  _prixActuel = articleActuel.prix;
                  _nbEncheres = articleActuel.nbEncheres;
                  _favorisCount = articleActuel.favoris;
                  _vues = articleActuel.vues;
                });
              }
            },
            onError: (error) {
              debugPrint('Erreur stream Supabase: $error');
              if (mounted) {
                setState(() {
                  erreurMessage = 'Erreur de synchronisation';
                });
              }
            },
          );
    } catch (e) {
      debugPrint('Erreur initialisation stream: $e');
    }
  }

  @override
  void dispose() {
    enchereController.dispose();
    _timerMinuteur?.cancel();
    _abonnementRealtime?.cancel();
    super.dispose();
  }

  /// Vérifie si l'article est dans les favoris
  Future<void> _verifierFavori() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || estVendeur) return;

    try {
      final data = await Supabase.instance.client
          .from('favoris')
          .select()
          .eq('utilisateur', user.email!)
          .eq('article_id', articleActuel.id!);

      if (mounted) {
        setState(() {
          estFavori = data.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint('Erreur vérification favori: $e');
    }
  }

  /// Bascule le statut favori
  Future<void> _toggleFavori() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || isLoadingFavori) return;

    setState(() => isLoadingFavori = true);

    try {
      if (estFavori) {
        await Supabase.instance.client
            .from('favoris')
            .delete()
            .eq('utilisateur', user.email!)
            .eq('article_id', articleActuel.id!);

        final nouveauCompte = (_favorisCount - 1).clamp(0, 999999);
        await Supabase.instance.client
            .from('articles')
            .update({'favoris': nouveauCompte})
            .eq('id', articleActuel.id!);

        if (mounted) {
          setState(() {
            _favorisCount = nouveauCompte;
            estFavori = false;
          });
        }
      } else {
        await Supabase.instance.client.from('favoris').insert({
          'utilisateur': user.email,
          'article_id': articleActuel.id!,
        });

        final nouveauCompte = _favorisCount + 1;
        await Supabase.instance.client
            .from('articles')
            .update({'favoris': nouveauCompte})
            .eq('id', articleActuel.id!);

        if (mounted) {
          setState(() {
            _favorisCount = nouveauCompte;
            estFavori = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoadingFavori = false);
      }
    }
  }

  /// Partage l'article
  void _partagerArticle() {
    // Implémentation du partage (vous pouvez utiliser share_plus package)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fonction de partage à implémenter')),
    );
  }

  /// Calcule le temps restant formaté
  String _tempsRestant() {
    if (articleActuel.createdAt == null) return "Temps inconnu";

    final fin = articleActuel.createdAt!.add(
      Duration(hours: articleActuel.duree),
    );
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

  /// Vérifie si l'enchère est terminée
  bool _enchereTerminee() {
    if (articleActuel.createdAt == null) return false;
    final fin = articleActuel.createdAt!.add(
      Duration(hours: articleActuel.duree),
    );
    return DateTime.now().isAfter(fin);
  }

  /// Soumet une enchère avec validation stricte
  Future<void> _soumettreEnchere() async {
    final user = Supabase.instance.client.auth.currentUser;

    // Validations de sécurité
    if (user == null) {
      _afficherErreur('Connexion requise pour enchérir');
      return;
    }

    if (estVendeur) {
      _afficherErreur('Vous ne pouvez pas enchérir sur votre propre article');
      return;
    }

    if (_enchereTerminee()) {
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

    final minMontant = _prixActuel + RoyalisConstants.minBidStep;
    if (montant <= _prixActuel) {
      _afficherErreur(
        'Votre offre doit être supérieure à $_prixActuel FCFA',
      );
      return;
    }

    if (montant < minMontant) {
      _afficherErreur(
        'Pas d\'enchère minimum: $_prixActuel + ${RoyalisConstants.minBidStep} FCFA',
      );
      return;
    }

    setState(() => isLoadingEnchere = true);

    try {
      // Récupère l'ancien leader
      final ancienneEnchere = await Supabase.instance.client
          .from('encheres')
          .select()
          .eq('article_id', articleActuel.id!)
          .order('montant', ascending: false)
          .limit(1);

      String? ancienLeader;
      if (ancienneEnchere.isNotEmpty) {
        ancienLeader = ancienneEnchere.first['utilisateur'];
      }

      // Insère la nouvelle enchère
      await Supabase.instance.client.from('encheres').insert({
        'montant': montant,
        'utilisateur': user.email,
        'article_id': articleActuel.id!,
        'article': articleActuel.nom,
      });

      // Met à jour le compteur et le prix
      final nouveauNbEncheres = _nbEncheres + 1;
      await Supabase.instance.client
          .from('articles')
          .update({
            'nb_encheres': nouveauNbEncheres,
            'prix': montant,
          })
          .eq('id', articleActuel.id!);

      // Notifie l'ancien leader
      if (ancienLeader != null && ancienLeader != user.email) {
        await Supabase.instance.client.from('notifications').insert({
          'utilisateur': ancienLeader,
          'message':
              '⚠️ Votre enchère sur ${articleActuel.nom} a été dépassée par une nouvelle offre de $montant FCFA.',
          'lu': false,
        });
      }

      if (mounted) {
        setState(() {
          _prixActuel = montant;
          _nbEncheres = nouveauNbEncheres;
        });

        enchereController.clear();
        FocusScope.of(context).unfocus();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Enchère acceptée !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _afficherErreur('Erreur: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => isLoadingEnchere = false);
      }
    }
  }

  /// Traite la fin de l'enchère (notification du gagnant, création de conversation)
  Future<void> _traiterFinEnchere() async {
    if (!_enchereTerminee()) return;

    try {
      final articleData = await Supabase.instance.client
          .from('articles')
          .select()
          .eq('id', articleActuel.id!)
          .single();

      if (articleData['gagnant_notifie'] == true) return;

      final gagnantData = await Supabase.instance.client
          .from('encheres')
          .select()
          .eq('article_id', articleActuel.id!)
          .order('montant', ascending: false)
          .limit(1)
          .single();

      final gagnant = gagnantData['utilisateur'];
      final montant = gagnantData['montant'];

      // Notifications
      await Future.wait([
        Supabase.instance.client.from('notifications').insert({
          'utilisateur': gagnant,
          'message':
              '🏆 Félicitations ! Vous avez remporté ${articleActuel.nom} pour $montant FCFA',
        }),
        Supabase.instance.client.from('notifications').insert({
          'utilisateur': articleActuel.vendeur,
          'message':
              '🏆 Votre article ${articleActuel.nom} a été vendu pour $montant FCFA',
        }),
      ]);

      // Crée ou récupère la conversation
      final conversationExistante = await Supabase.instance.client
          .from('conversations')
          .select()
          .eq('article_id', articleActuel.id!)
          .eq('acheteur', gagnant);

      if (conversationExistante.isEmpty) {
        final conversation = await Supabase.instance.client
            .from('conversations')
            .insert({
              'article_id': articleActuel.id!,
              'vendeur': articleActuel.vendeur,
              'acheteur': gagnant,
            })
            .select();

        final conversationId = conversation.first['id'];

        await Supabase.instance.client.from('messages').insert({
          'conversation_id': conversationId,
          'expediteur': 'SYSTEME',
          'message':
              '🏆 Félicitations ! Cette conversation a été créée automatiquement suite à la vente de ${articleActuel.nom}.',
        });
      }

      // Marque comme notifié
      await Supabase.instance.client
          .from('articles')
          .update({'gagnant_notifie': true})
          .eq('id', articleActuel.id!);
    } catch (e) {
      debugPrint('Erreur traitement fin enchère: $e');
    }
  }

  /// Signale un article
  Future<void> _signalerArticle() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client.from('signalements').insert({
        'article_id': articleActuel.id!,
        'utilisateur': user.email,
        'motif': 'Signalé par utilisateur',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Article signalé aux administrateurs'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      _afficherErreur('Erreur: ${e.toString()}');
    }
  }

  /// Ouvre le chat avec le vendeur
  Future<void> _ouvrirChat() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _afficherErreur('Connexion requise');
      return;
    }

    if (estVendeur) {
      _afficherErreur('Vous êtes le vendeur de cet article');
      return;
    }

    try {
      // Vérifie si la conversation existe
      final conversationExistante = await Supabase.instance.client
          .from('conversations')
          .select()
          .eq('article_id', articleActuel.id!)
          .eq('acheteur', user.email!);

      int conversationId;

      if (conversationExistante.isNotEmpty) {
        conversationId = conversationExistante.first['id'];
      } else {
        // Crée une nouvelle conversation
        final nouvelleConversation = await Supabase.instance.client
            .from('conversations')
            .insert({
              'article_id': articleActuel.id!,
              'vendeur': articleActuel.vendeur,
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
              nomCorrespondant: articleActuel.vendeur,
            ),
          ),
        );
      }
    } catch (e) {
      _afficherErreur('Erreur: ${e.toString()}');
    }
  }

  /// Récupère la note moyenne du vendeur
  Future<double> _noteVendeur() async {
    try {
      final avis = await Supabase.instance.client
          .from('avis')
          .select()
          .eq('vendeur', articleActuel.vendeur);

      if (avis.isEmpty) return 0;
      int total = 0;
      for (final a in avis) {
        total += (a['note'] ?? 0) as int;
      }
      return total / avis.length;
    } catch (e) {
      debugPrint('Erreur calcul note vendeur: $e');
      return 0;
    }
  }

  /// Récupère l'historique des enchères
  Future<List<Map<String, dynamic>>> _chargerEncheres() async {
    try {
      final data = await Supabase.instance.client
          .from('encheres')
          .select()
          .eq('article_id', articleActuel.id!)
          .order('montant', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Erreur chargement enchères: $e');
      return [];
    }
  }

  /// Affiche un message d'erreur
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
    final estFini = _enchereTerminee();

    return Scaffold(
      backgroundColor: RoyalisColors.premiumBg,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildImageHeader(estFini),
                _buildArticleInfo(),
                if (!estVendeur) _buildVendeurSection(),
                _buildDescriptionSection(),
                _buildDetailsSection(),
                _buildEncharesSection(),
                const SizedBox(height: 20),
              ],
            ),
          ),
          _buildBidFooter(estFini),
        ],
      ),
    );
  }

  /// Construit l'app bar
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
      title: Text(
        'Détail de l\'article',
        style: const TextStyle(
          color: RoyalisColors.darkText,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.flag_outlined, color: Colors.grey),
          onPressed: _signalerArticle,
        ),
      ],
    );
  }

  /// Construit l'en-tête avec image et overlay
  Widget _buildImageHeader(bool estFini) {
    return Stack(
      children: [
        Hero(
          tag: 'article-${articleActuel.id}',
          child: articleActuel.imageUrl.isNotEmpty
              ? Image.network(
                  articleActuel.imageUrl,
                  height: 320,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
                )
              : _buildImagePlaceholder(),
        ),
        // Badge de statut
        Positioned(
          bottom: 15,
          left: 15,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: estFini
                  ? Colors.red.withValues(alpha: 0.9)
                  : RoyalisColors.gold.withValues(alpha: 0.9),
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
        // Boutons d'action
        Positioned(
          top: 15,
          right: 15,
          child: Row(
            children: [
              _buildActionButton(
                icon: estFavori ? Icons.favorite : Icons.favorite_border,
                isLoading: isLoadingFavori,
                onTap: _toggleFavori,
              ),
              const SizedBox(width: 10),
              _buildActionButton(
                icon: Icons.share_outlined,
                onTap: _partagerArticle,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Bouton d'action arrondi
  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 6,
            ),
          ],
        ),
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                icon,
                color: icon == Icons.favorite ? Colors.red : RoyalisColors.gold,
                size: 24,
              ),
      ),
    );
  }

  /// Placeholder pour image manquante
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

  /// Infos de l'article (nom, vues, favoris, catégorie)
  Widget _buildArticleInfo() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  articleActuel.nom,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: RoyalisColors.darkText,
                  ),
                ),
              ),
              _buildStatsRow(),
            ],
          ),
          const SizedBox(height: 10),
          _buildCategoryBadge(),
          const SizedBox(height: 15),
          _buildPriceAndTimerRow(),
        ],
      ),
    );
  }

  /// Ligne de statistiques (vues, favoris)
  Widget _buildStatsRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          children: [
            Icon(Icons.remove_red_eye_outlined,
                size: 14, color: RoyalisColors.lightGray),
            const SizedBox(width: 4),
            Text('$_vues', style: const TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.favorite_outline,
                size: 14, color: RoyalisColors.lightGray),
            const SizedBox(width: 4),
            Text('$_favorisCount', style: const TextStyle(fontSize: 12)),
          ],
        ),
      ],
    );
  }

  /// Badge de catégorie
  Widget _buildCategoryBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: RoyalisColors.gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RoyalisColors.gold.withValues(alpha: 0.3)),
      ),
      child: Text(
        articleActuel.categorie,
        style: const TextStyle(
          color: RoyalisColors.gold,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Ligne prix actuel et temps restant
  Widget _buildPriceAndTimerRow() {
    return Row(
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
                  '$_prixActuel FCFA',
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
                  _tempsRestant(),
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
    );
  }

  /// Section vendeur
  Widget _buildVendeurSection() {
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
          FutureBuilder<double>(
            future: _noteVendeur(),
            builder: (context, snapshot) {
              final note = snapshot.data ?? 0;
              return Container(
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
                        articleActuel.vendeur.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: RoyalisColors.gold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            articleActuel.vendeur,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: RoyalisColors.gold,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                note.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (note >= 4)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Fiable',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.chat_bubble_outline,
                        color: RoyalisColors.gold,
                      ),
                      onPressed: _ouvrirChat,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Section description
  Widget _buildDescriptionSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 25),
          const Text(
            'Description de l\'objet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: RoyalisColors.darkText,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            articleActuel.description,
            style: TextStyle(
              color: Colors.grey.shade600,
              height: 1.5,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// Section détails (catégorie, localisation)
  Widget _buildDetailsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 25),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: RoyalisColors.borderGray),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Localisation',
                      style: TextStyle(color: Colors.grey),
                    ),
                    Text(
                      articleActuel.ville,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'État',
                      style: TextStyle(color: Colors.grey),
                    ),
                    Text(
                      'Très bon état',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Section historique des enchères
  Widget _buildEncharesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Historique des enchères',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: RoyalisColors.darkText,
                ),
              ),
              Text(
                '$_nbEncheres offre(s)',
                style: const TextStyle(
                  color: RoyalisColors.gold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _chargerEncheres(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildShimmerLoading();
              }

              if (snapshot.hasError) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Erreur lors du chargement',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                );
              }

              final encheres = snapshot.data ?? [];
              if (encheres.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: RoyalisColors.borderGray),
                  ),
                  child: const Text(
                    'Aucune offre pour le moment',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: encheres.length > 5 ? 5 : encheres.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final enchere = encheres[index];
                  final estLeader = index == 0;

                  return Container(
                    decoration: BoxDecoration(
                      color: estLeader
                          ? const Color(0xFFFFFDF5)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: estLeader
                            ? RoyalisColors.gold.withValues(alpha: 0.3)
                            : RoyalisColors.borderGray,
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        backgroundColor: estLeader
                            ? RoyalisColors.gold
                            : Colors.grey.shade200,
                        child: Icon(
                          Icons.gavel,
                          size: 16,
                          color: estLeader ? Colors.white : Colors.grey,
                        ),
                      ),
                      title: Text(
                        '${enchere['montant']} FCFA',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: estLeader
                              ? RoyalisColors.gold
                              : RoyalisColors.darkText,
                        ),
                      ),
                      subtitle: Text(enchere['utilisateur'] ?? 'Anonyme'),
                      trailing: estLeader
                          ? const Text(
                              '🏆 Leader',
                              style: TextStyle(
                                color: RoyalisColors.gold,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            )
                          : null,
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  /// Loading shimmer
  Widget _buildShimmerLoading() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return Container(
          height: 70,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(10),
          ),
        );
      },
    );
  }

  /// Barre d'action fixe en bas
  Widget _buildBidFooter(bool estFini) {
    if (estVendeur) {
      return Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                offset: const Offset(0, -4),
                blurRadius: 10,
              ),
            ],
          ),
          child: SafeArea(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '👤 Vous êtes le vendeur',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, -4),
              blurRadius: 10,
            ),
          ],
        ),
        child: SafeArea(
          child: estFini
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '🔒 Enchère terminée',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                )
              : Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: enchereController,
                          keyboardType: TextInputType.number,
                          cursorColor: RoyalisColors.gold,
                          enabled: !isLoadingEnchere,
                          decoration: const InputDecoration(
                            hintText: 'Votre offre (FCFA)',
                            border: InputBorder.none,
                            hintStyle: TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: isLoadingEnchere ? null : _soumettreEnchere,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RoyalisColors.darkText,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                          disabledBackgroundColor: Colors.grey.shade300,
                        ),
                        child: isLoadingEnchere
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Enchérir',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
