import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/article.dart';
import 'detail_page.dart';
import 'dart:developer' as developer;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late ScrollController _scrollController;
  int _currentPage = 0;
  bool _isLoadingMore = false;

  // Filtres de recherche
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCategory;
  String? _selectedCity;

  static const List<String> categories = [
    "Art",
    "Électronique",
    "Mode",
    "Véhicules",
    "Immobilier"
  ];
  static const List<String> cities = [
    "Dakar",
    "Thiès",
    "Kaolack",
    "Saint-Louis",
    "Toutes les villes"
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Écoute le scroll pour la pagination
  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 500 &&
        !_isLoadingMore) {
      _loadMore();
    }
  }

  /// Charge la page suivante
  void _loadMore() {
    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });

    developer.log('Chargement page $_currentPage', name: 'HomePage');
  }

  /// Réinitialise la recherche
  void _resetSearch() {
    setState(() {
      _currentPage = 0;
      _isLoadingMore = false;
      _searchController.clear();
      _selectedCategory = null;
      _selectedCity = null;
    });
  }

  /// Construit la requête Stream Supabase directe
  Stream<List<Map<String, dynamic>>> _getArticlesStream() {
    var query = Supabase.instance.client
        .from('articles')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);

    return query;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3EE),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildFiltersSection(),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getArticlesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFD4AF37),
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
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
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => setState(() {}),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1F2937),
                              foregroundColor: const Color(0xFFD4AF37),
                            ),
                            child: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final rawData = snapshot.data ?? [];
                
                // Conversion Map vers Model Article
                var articles = rawData.map((map) => Article.fromMap(map)).toList();

                // Filtrage en mémoire (Recherche, Catégorie, Ville)
                if (_searchController.text.isNotEmpty) {
                  final query = _searchController.text.toLowerCase();
                  articles = articles.where((a) => a.nom.toLowerCase().contains(query)).toList();
                }

                if (_selectedCategory != null) {
                  articles = articles.where((a) => a.categorie == _selectedCategory).toList();
                }

                if (_selectedCity != null && _selectedCity != "Toutes les villes") {
                  articles = articles.where((a) => a.ville == _selectedCity).toList();
                }

                if (articles.isEmpty) {
                  final isSearching = _searchController.text.isNotEmpty ||
                      _selectedCategory != null ||
                      (_selectedCity != null && _selectedCity != "Toutes les villes");

                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 80,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Aucun article trouvé',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (isSearching)
                            ElevatedButton(
                              onPressed: _resetSearch,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1F2937),
                                foregroundColor: const Color(0xFFD4AF37),
                              ),
                              child: const Text('Réinitialiser la recherche'),
                            ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: articles.length + (_isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == articles.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFFD4AF37),
                            ),
                          ),
                        ),
                      );
                    }

                    final article = articles[index];
                    return _buildArticleCard(article);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Construit l'app bar
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      centerTitle: true,
      title: const Text(
        '🏆 ROYALIS',
        style: TextStyle(
          color: Color(0xFF1F2937),
          fontWeight: FontWeight.bold,
          fontSize: 20,
          letterSpacing: 1.5,
        ),
      ),
      leading: const SizedBox.shrink(),
    );
  }

  /// Section des filtres de recherche
  Widget _buildFiltersSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Barre de recherche
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Rechercher un article...',
              hintStyle: TextStyle(color: Colors.grey.shade500),
              prefixIcon: const Icon(
                Icons.search,
                color: Color(0xFF1F2937),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _resetSearch();
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: Colors.grey.shade200,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: Colors.grey.shade200,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFFD4AF37),
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 16,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Filtres: Catégorie et Ville
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Filtre Catégorie
                _buildFilterChip(
                  label: _selectedCategory ?? 'Catégorie',
                  isActive: _selectedCategory != null,
                  onTap: () => _showCategoryPicker(),
                ),
                const SizedBox(width: 8),
                // Filtre Ville
                _buildFilterChip(
                  label: _selectedCity ?? 'Ville',
                  isActive: _selectedCity != null,
                  onTap: () => _showCityPicker(),
                ),
                const SizedBox(width: 8),
                if (_selectedCategory != null || _selectedCity != null)
                  GestureDetector(
                    onTap: _resetSearch,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.red.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Réinitialiser',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Construit un chip de filtre
  Widget _buildFilterChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFD4AF37).withValues(alpha: 0.2)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? const Color(0xFFD4AF37)
                : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive
                    ? const Color(0xFFD4AF37)
                    : Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: isActive
                  ? const Color(0xFFD4AF37)
                  : Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }

  /// Montre le sélecteur de catégorie
  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Sélectionner une catégorie',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 16),
              ...categories.map(
                (category) => ListTile(
                  title: Text(category),
                  trailing: _selectedCategory == category
                      ? const Icon(
                          Icons.check,
                          color: Color(0xFFD4AF37),
                        )
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                      _currentPage = 0;
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
              if (_selectedCategory != null)
                ListTile(
                  title: const Text('Effacer le filtre'),
                  textColor: Colors.red,
                  onTap: () {
                    setState(() {
                      _selectedCategory = null;
                      _currentPage = 0;
                    });
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Montre le sélecteur de ville
  void _showCityPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Sélectionner une ville',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 16),
              ...cities.map(
                (city) => ListTile(
                  title: Text(city),
                  trailing: _selectedCity == city
                      ? const Icon(
                          Icons.check,
                          color: Color(0xFFD4AF37),
                        )
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedCity = city;
                      _currentPage = 0;
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
              if (_selectedCity != null)
                ListTile(
                  title: const Text('Effacer le filtre'),
                  textColor: Colors.red,
                  onTap: () {
                    setState(() {
                      _selectedCity = null;
                      _currentPage = 0;
                    });
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Construit une carte d'article
  Widget _buildArticleCard(Article article) {
    final estTerminee = article.createdAt != null &&
        DateTime.now().isAfter(
          article.createdAt!.add(Duration(hours: article.duree)),
        );

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetailPage(article: article),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Stack(
              children: [
                Hero(
                  tag: 'article-${article.id}',
                  child: article.imageUrl.isNotEmpty
                      ? Image.network(
                          article.imageUrl,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 200,
                            color: Colors.grey.shade200,
                            child: const Icon(
                              Icons.image_outlined,
                              size: 60,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : Container(
                          height: 200,
                          color: Colors.grey.shade200,
                          child: const Icon(
                            Icons.image_outlined,
                            size: 60,
                            color: Colors.grey,
                          ),
                        ),
                ),
                // Badge de statut
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: estTerminee
                          ? Colors.red.withValues(alpha: 0.9)
                          : const Color(0xFFD4AF37).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      estTerminee ? 'TERMINÉE' : 'EN COURS',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Contenu
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Catégorie
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      article.categorie,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFFD4AF37),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Nom
                  Text(
                    article.nom,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Prix
                  Text(
                    '${article.prix} FCFA',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD4AF37),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Localisation et statistiques
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            article.ville,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.local_fire_department_outlined,
                            size: 12,
                            color: Colors.orange.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${article.nbEncheres}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}