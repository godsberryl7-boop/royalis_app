# 📋 PLAN D'ACTION - DÉPLOIEMENT SÉCURISÉ ROYALIS

## ⚡ ÉTAPE 1 : CORRECTIONS CRITIQUES (À faire AUJOURD'HUI)

### 1.1 Exécuter le script SQL
**Fichier** : `schema_corrections.sql`

**Où** : Supabase Dashboard → SQL Editor → Copier/Coller
**Risque si pas fait** : 🔴 Race conditions massives, RLS vulnerables

**Vérification** :
```sql
-- Exécutez cette requête pour confirmer
SELECT 
  table_name,
  array_agg(policyname) as policies
FROM pg_policies
WHERE tablename IN ('articles', 'encheres', 'avis', 'signalements')
GROUP BY table_name;
```

### 1.2 Tester les enchères simultanées
**Objectif** : Vérifier que le trigger PostgreSQL bloque les race conditions

**Procédure** :
1. Ouvrir l'app sur 2 navigateurs (Chrome + Firefox)
2. Connecter 2 comptes différents
3. Trouver le même article
4. Encherir **EN MÊME TEMPS** (cliquer Encherir quasi-simultanément)
5. Vérifier que l'enchère invalide est rejetée

**Résultat attendu** :
- ✅ Enchère 1 (110 000) acceptée
- ❌ Enchère 2 (105 000) REJETÉE avec message "Enchère invalide"

### 1.3 Vérifier les notifications
**Test** : Faire une enchère valide et attendre...

**Résultat attendu** :
- Ancien leader reçoit notification ✅
- Table notifications a un nouvel enregistrement ✅

---

## 🔧 ÉTAPE 2 : MIGRER VERS RIVERPOD (Optionnel mais fortement recommandé)

### 2.1 Ajouter Riverpod à pubspec.yaml
```yaml
dependencies:
  flutter_riverpod: ^2.4.0
  riverpod: ^2.4.0
```

### 2.2 Wrappez l'app
**main.dart** (avant `runApp()`) :
```dart
runApp(
  const ProviderScope(
    child: MonApp(),
  ),
);
```

### 2.3 Remplacer les pages
- ✅ `home_page.dart` → Déjà en Riverpod (fourni)
- ✅ `detail_page.dart` → À refactoriser (voir détails ci-dessous)

---

## 📄 ÉTAPE 3 : REFACTORISATION DETAIL_PAGE (Critique)

### Problèmes actuels
1. **FutureBuilder imbriqués** → Performances mauvaises
2. **Pas de cache** → Même requête x3 fois
3. **Listeners pas bien fermés** → Risque fuite mémoire

### Solution
Utiliser le fichier `lib/pages/detail_page_refactored.dart` que nous allons créer.

**Avant** (actuel) :
```dart
StreamBuilder<Article>(
  stream: Supabase.instance.client.from('articles').stream(...),
  builder: (context, snapshot) { ... }
)
```

**Après** (Riverpod) :
```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final articleAsync = ref.watch(articleDetailProvider(widget.article.id!));
  return articleAsync.when(
    data: (article) => _buildContent(article),
    loading: () => LoadingWidget(),
    error: (err, st) => ErrorWidget(),
  );
}
```

---

## 🧪 ÉTAPE 4 : TESTS CRITIQUES

### Tests manuels (OBLIGATOIRE avant prod)

#### Test 1 : Créer un article
- [ ] Aller sur Add Article
- [ ] Remplir tous les champs
- [ ] Uploader une image
- [ ] Cliquer Publier
- [ ] ✅ Article apparaît dans la liste avec l'image

#### Test 2 : Rechercher un article
- [ ] Écrire dans la barre de recherche
- [ ] ✅ Les articles filtrés s'affichent
- [ ] Cliquer sur un article → Ouvre la page détail

#### Test 3 : Enchère valide
- [ ] Ouvrir un article
- [ ] Proposer une enchère > prix actuel
- [ ] ✅ Enchère acceptée
- [ ] Prix affiche la nouvelle valeur
- [ ] Ancien leader reçoit notification

#### Test 4 : Enchère invalide (DEVRAIT ÊTRE REJETÉE)
- [ ] Proposer une enchère <= prix actuel
- [ ] ✅ Message d'erreur s'affiche
- [ ] L'enchère n'est PAS créée en BD

#### Test 5 : Vendeur ne peut pas enchérir
- [ ] Connecté en tant que vendeur
- [ ] Ouvrir son propre article
- [ ] Cliquer sur Encherir
- [ ] ✅ Message "Vous êtes le vendeur"

#### Test 6 : Favoris
- [ ] Cliquer ❤️ sur un article
- [ ] ✅ Compte favori augmente
- [ ] Rafraîchir la page
- [ ] ✅ Cœur reste rempli

#### Test 7 : Performance (50+ articles)
- [ ] Rafraîchir la page d'accueil
- [ ] Scroller jusqu'en bas
- [ ] ✅ Pas de lag
- [ ] Articles chargent progressivement

#### Test 8 : Offline mode
- [ ] Activer Airplane Mode
- [ ] Essayer de consulter un article
- [ ] ✅ Message d'erreur clair (connexion requise)
- [ ] Désactiver Airplane Mode
- [ ] ✅ App revient normal

---

## 📦 ÉTAPE 5 : PRÉ-PUBLICATION CHECKLIST

### Code
- [ ] `flutter analyze` ← Pas d'erreurs
- [ ] `flutter format lib/` ← Code bien formaté
- [ ] Tous les `TODO` supprimés ou complétés
- [ ] Pas de `print()` (utiliser `developer.log()`)

### Sécurité
- [ ] Clés Supabase en variables d'environnement
- [ ] Pas de clés en dur dans `main.dart`
- [ ] RLS policies vérifiées
- [ ] Triggers PostgreSQL activés

### Performance
- [ ] Images compressées (< 100KB)
- [ ] Pagination lazy-load implémentée
- [ ] Streams cancellés dans `dispose()`
- [ ] Pas de FutureBuilder imbriqués non-nécessaires

### Assets
- [ ] App Icon mise à jour (512x512)
- [ ] Screenshots pour Play Store/App Store
- [ ] README.md à jour

### Versioning
- [ ] pubspec.yaml : version bumped
- [ ] CHANGELOG.md créé/mis à jour
- [ ] Git tag créé

---

## 🚀 ÉTAPE 6 : DÉPLOIEMENT ANDROID

### 6.1 Build APK debug (test)
```bash
flutter build apk --debug
# Fichier : build/app/outputs/flutter-apk/app-debug.apk
```

### 6.2 Build APK release (prod)
```bash
flutter build apk --release
# Fichier : build/app/outputs/flutter-apk/app-release.apk
```

### 6.3 Upload sur Google Play
1. Créer projet Google Play Console
2. Créer signataire (si pas déjà)
3. Uploader APK
4. Remplir description, screenshots, etc.
5. Soumettre pour review (⏳ 1-3 heures)

**Note** : Besoin d'un Google Account + $25 (frais Play Store)

---

## 📊 ÉTAPE 7 : MONITORING POST-DÉPLOIEMENT

### Mettre en place Sentry (crash reporting)
```bash
flutter pub add sentry_flutter
```

### Vérifier régulièrement
- [ ] Pas de crashs en prod
- [ ] Performance OK (< 2s load time)
- [ ] Pas de race conditions (checker logs)
- [ ] Utilisateurs satisfaits (5★ reviews)

---

## 🎯 ROADMAP FUTURE

### V1.1 (2-3 semaines)
- [ ] Dark mode
- [ ] Admin dashboard
- [ ] Système de disputes
- [ ] Notifications push

### V1.2 (1 mois)
- [ ] Authentification SMS
- [ ] Vérification badge vendeur
- [ ] Historique transactions
- [ ] Analytics

### V2.0 (3 mois)
- [ ] App iOS
- [ ] Web app (Flutter Web)
- [ ] API REST publique
- [ ] Intégration paiement (Stripe/Wave)

---

## ❓ QUESTIONS FRÉQUENTES

### Q1 : Et si j'oublie d'exécuter schema_corrections.sql ?
**R** : 🔴 Race conditions + avis/signalements accessibles à tous → DANGER. À faire d'abord.

### Q2 : Riverpod obligatoire ?
**R** : Non, mais recommandé. L'app fonctionne sans, mais cache fragmenté.

### Q3 : Combien de temps avant prod ?
**R** : ~1 jour de travail + 2-3 jours de tests + review Google Play. Total : ~5 jours.

### Q4 : Coût Supabase ?
**R** : Free tier = 500MB storage + 2GB bandwidth/mois. Gratuit!

---

**FIN DU PLAN D'ACTION**

Questions ? Poste sur GitHub Issues ! 🚀
