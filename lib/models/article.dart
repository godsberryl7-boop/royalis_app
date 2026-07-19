class Article {
  final int? id; // Généré automatiquement par Supabase
  final String nom;
  final int prix;
  final String description;
  final String categorie;
  final String vendeur;
  final String ville;
  final String imageUrl;
  final String etat;
  final int duree; // En heures par exemple
  final DateTime? createdAt;
  final int vues;
  final int favoris;
  final int nbEncheres;

  Article({
    this.id,
    required this.nom,
    required this.prix,
    required this.description,
    required this.categorie,
    required this.vendeur,
    required this.ville,
    required this.imageUrl,
    required this.etat,
    required this.duree,
    this.createdAt,
    this.vues = 0,
    this.favoris = 0,
    this.nbEncheres = 0,
  });

  /// Convertit un enregistrement Supabase (Map) en objet Article de façon sécurisée
  factory Article.fromMap(Map<String, dynamic> map) {
    return Article(
      id: (map['id'] as num?)?.toInt(),
      nom: map['nom']?.toString() ?? '',
      // Sécurisation contre le crash classique int/double de Supabase :
      prix: (map['prix'] as num?)?.toInt() ?? 0,
      description: map['description']?.toString() ?? '',
      categorie: map['categorie']?.toString() ?? '',
      vendeur: map['vendeur']?.toString() ?? '',
      ville: map['ville']?.toString() ?? '',
      imageUrl: map['image_url']?.toString() ?? '',
      etat: map['etat']?.toString() ?? '',
      duree: (map['duree'] as num?)?.toInt() ?? 24,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'].toString()).toLocal()
          : null,
      vues: (map['vues'] as num?)?.toInt() ?? 0,
      favoris: (map['favoris'] as num?)?.toInt() ?? 0,
      nbEncheres: (map['nb_encheres'] as num?)?.toInt() ?? 0,
    );
  }

  /// Convertit l'objet Article en Map (JSON) pour Supabase
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = {
      'nom': nom,
      'prix': prix,
      'description': description,
      'categorie': categorie,
      'vendeur': vendeur,
      'ville': ville,
      'image_url': imageUrl,
      'etat': etat,
      'duree': duree,
      'vues': vues,
      'favoris': favoris,
      'nb_encheres': nbEncheres,
    };
    
    if (id != null) data['id'] = id;
    if (createdAt != null) data['created_at'] = createdAt!.toIso8601String();
    
    return data;
  }

  /// Permet de dupliquer un article en modifiant uniquement certains champs (ex: incrémenter les vues)
  Article copyWith({
    int? id,
    String? nom,
    int? prix,
    String? description,
    String? categorie,
    String? vendeur,
    String? ville,
    String? imageUrl,
    String? etat,
    int? duree,
    DateTime? createdAt,
    int? vues,
    int? favoris,
    int? nbEncheres,
  }) {
    return Article(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      prix: prix ?? this.prix,
      description: description ?? this.description,
      categorie: categorie ?? this.categorie,
      vendeur: vendeur ?? this.vendeur,
      ville: ville ?? this.ville,
      imageUrl: imageUrl ?? this.imageUrl,
      etat: etat ?? this.etat,
      duree: duree ?? this.duree,
      createdAt: createdAt ?? this.createdAt,
      vues: vues ?? this.vues,
      favoris: favoris ?? this.favoris,
      nbEncheres: nbEncheres ?? this.nbEncheres,
    );
  }
}