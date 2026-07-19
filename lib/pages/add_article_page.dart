import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddArticlePage extends StatefulWidget {
  const AddArticlePage({super.key});

  @override
  State<AddArticlePage> createState() => _AddArticlePageState();
}

class _AddArticlePageState extends State<AddArticlePage> {
  final _formKey = GlobalKey<FormState>();
  
  final nomController = TextEditingController();
  final prixController = TextEditingController();
  final descriptionController = TextEditingController();
  final villeController = TextEditingController();
  final dureeController = TextEditingController();
  
  String? categorieSelectionnee;
  String? etatSelectionne;
  
  final ImagePicker picker = ImagePicker();
  List<XFile> images = [];
  bool enCoursDeChargement = false;

  final List<String> categories = ["Art", "Électronique", "Mode", "Véhicules", "Immobilier"];
  final List<String> etats = ["Neuf", "Très bon état", "Bon état", "Satisfaisant"];

  @override
  void dispose() {
    nomController.dispose();
    prixController.dispose();
    descriptionController.dispose();
    villeController.dispose();
    dureeController.dispose();
    super.dispose();
  }

  Future<void> selectionnerImages() async {
    try {
      final List<XFile> photos = await picker.pickMultiImage();
      setState(() {
        images.addAll(photos);
      });
    } catch (e) {
      debugPrint("ERREUR SELECTION PHOTO : $e");
    }
  }

  void supprimerImage(int index) {
    setState(() {
      images.removeAt(index);
    });
  }

  Future<void> publierArticle() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      enCoursDeChargement = true;
    });

    try {
      String imageUrl = '';

      if (images.isNotEmpty) {
        final file = File(images.first.path);
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';

        await Supabase.instance.client.storage
            .from('articles')
            .upload(fileName, file);

        imageUrl = Supabase.instance.client.storage
            .from('articles')
            .getPublicUrl(fileName);
      }

      // Sécurisation des parsing pour éviter les crashs si l'utilisateur saisit des lettres
      final prixSaisi = int.tryParse(prixController.text.trim()) ?? 0;
      final dureeSaisie = int.tryParse(dureeController.text.trim()) ?? 24;

      await Supabase.instance.client.from('articles').insert({
        'nom': nomController.text.trim(),
        'prix': prixSaisi,
        'description': descriptionController.text.trim(),
        'categorie': categorieSelectionnee,
        'ville': villeController.text.trim(),
        'etat': etatSelectionne,
        'duree': dureeSaisie,
        'vendeur': Supabase.instance.client.auth.currentUser?.email ?? 'Inconnu',
        'image_url': imageUrl,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Votre article a été publié avec succès !'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la publication : $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          enCoursDeChargement = false;
        });
      }
    }
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
          "Créer une annonce",
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Photos de l'article",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                  ),
                  const SizedBox(height: 10),
                  
                  SizedBox(
                    height: 110,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: images.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return GestureDetector(
                            onTap: selectionnerImages,
                            child: Container(
                              width: 100,
                              margin: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_outlined, color: Color(0xFFD4AF37), size: 30),
                                  SizedBox(height: 6),
                                  Text(
                                    "Ajouter",
                                    style: TextStyle(color: Color(0xFFD4AF37), fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final imageIndex = index - 1;
                        return Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              margin: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                image: DecorationImage(
                                  image: FileImage(File(images[imageIndex].path)),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 8,
                              child: GestureDetector(
                                onTap: () => supprimerImage(imageIndex),
                                child: const CircleAvatar(
                                  radius: 11,
                                  backgroundColor: Colors.red,
                                  child: Icon(Icons.close, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    "Détails de l'article",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: nomController,
                    decoration: decorationInput("Nom de l'article", Icons.shopping_bag_outlined),
                    validator: (v) => v == null || v.isEmpty ? 'Veuillez entrer un titre' : null,
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: prixController,
                    keyboardType: TextInputType.number,
                    decoration: decorationInput("Prix de départ (FCFA)", Icons.sell_outlined),
                    validator: (v) => v == null || v.isEmpty ? 'Veuillez entrer un prix de départ' : null,
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: decorationInput("Description détaillée", Icons.description_outlined),
                    validator: (v) => v == null || v.isEmpty ? 'Veuillez entrer une description' : null,
                  ),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                    value: categorieSelectionnee,
                    decoration: decorationInput("Catégorie", Icons.category_outlined),
                    items: categories.map((cat) {
                      return DropdownMenuItem(value: cat, child: Text(cat));
                    }).toList(),
                    onChanged: (val) => setState(() => categorieSelectionnee = val),
                    validator: (v) => v == null ? 'Sélectionnez une catégorie' : null,
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: villeController,
                    decoration: decorationInput("Ville ou Localisation", Icons.location_on_outlined),
                    validator: (v) => v == null || v.isEmpty ? 'Veuillez spécifier la localisation' : null,
                  ),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                    value: etatSelectionne,
                    decoration: decorationInput("État de l'article", Icons.stars_outlined),
                    items: etats.map((e) {
                      return DropdownMenuItem(value: e, child: Text(e));
                    }).toList(),
                    onChanged: (val) => setState(() => etatSelectionne = val),
                    validator: (v) => v == null ? 'Spécifiez l\'état de l\'article' : null,
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: dureeController,
                    keyboardType: TextInputType.number,
                    decoration: decorationInput("Durée de l'enchère (heures)", Icons.hourglass_top_rounded),
                    validator: (v) => v == null || v.isEmpty ? 'Déterminez la durée' : null,
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1F2937),
                        foregroundColor: const Color(0xFFD4AF37),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: publierArticle,
                      child: const Text(
                        "🚀 Publier mon annonce",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          
          if (enCoursDeChargement)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: const Center(
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                        ),
                        SizedBox(height: 16),
                        Text(
                          "Publication en cours...",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  InputDecoration decorationInput(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
      prefixIcon: Icon(icon, color: const Color(0xFF1F2937).withOpacity(0.7)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }
}