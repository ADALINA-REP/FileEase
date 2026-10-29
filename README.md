# FileEase — Mobile Photo Compressor & Offline PDF Tools

<p align="center">
  <img src="https://raw.githubusercontent.com/flutter/assets-for-api-docs/master/assets/widgets/owl.jpg" width="100" height="100" alt="FileEase Logo" style="border-radius: 20px; display: none;" />
</p>

**FileEase** est une application mobile utilitaire moderne, rapide et élégante, développée avec **Flutter & Dart**, conçue pour résoudre les besoins quotidiens de manipulation de photos et de documents PDF en toute confidentialité.

> 🔒 **100% Hors-Ligne & Privé (Zero Upload Cloud)** : Tous les traitements (compression, redimensionnement, conversion et génération de PDF) sont exécutés localement sur le processeur du smartphone via des Isolates Dart, sans envoyer aucun fichier vers un serveur distant.

---

## 📱 Fonctionnalités Clés (MVP Réalisé)

1. **Compresseur Photo à Taille Cible (KB / MB)** :
   - Sélection rapide de taille cible : **50 Ko, 100 Ko, 200 Ko, 500 Ko, 1 Mo** ou saisie libre au Ko près.
   - Algorithme de recherche dichotomique intelligent sur la table de quantification JPEG avec mise à l'échelle progressive pour garantir la taille demandée sans altération excessive.
   - Mode manuel avec curseur de qualité interactif (10% à 95%).
   - Indispensable pour les formulaires de concours, démarches administratives et plateformes web imposant des limites strictes (ex: *"Moins de 200 Ko"*).

2. **Photos vers PDF (Multi-pages)** :
   - Sélection de multiples photos (factures, justificatifs, pièces d'identité, cours).
   - Ordonnancement des pages avec aperçu immédiat et suppression en 1 clic.
   - Presets de format de page : **Format A4 standard**, **Lettre US**, ou **Ajuster à l'image**.
   - Export en PDF ultra-net, prévisualisation avec le lecteur PDF natif et partage instantané.

3. **Redimensionnement d'Images** :
   - Ajustement précis de la largeur et de la hauteur en pixels avec verrouillage du ratio d'aspect.
   - Échelle en pourcentage (25%, 50%, 75%, 150%, 200%).
   - Préréglages validés par l'analyse de marché : **Format Passeport (35×45 mm / 413×531 px)**, **Avatar carré (500×500 px)**, **Full HD (1920×1080 px)** et **Web / Blog (1200×800 px)**.

4. **Conversion de Format d'Image** :
   - Conversion bidirectionnelle **JPG ↔ PNG**.
   - Préservation de la netteté et remplissage automatique des zones transparentes par un fond blanc pur lors de l'export en JPEG.

5. **Historique Local & Économie d'Espace** :
   - Calcul automatique et affichage du volume total de mégaoctets économisés.
   - Accès rapide aux fichiers exportés, partage et ouverture directe.
   - Bouton de purge intégrale du cache temporaire pour garantir la vie privée.

6. **Monétisation Responsable Google AdMob** :
   - Intégration du SDK officiel `google_mobile_ads`.
   - Bannières discrètes et adaptatives, masquées automatiquement si aucune annonce n'est disponible pour ne pas casser la mise en page.
   - Annonces interstitielles strictement plafonnées (limitation de fréquence : jamais au lancement, uniquement après 3 opérations réussies, avec délai de refroidissement de 90 secondes).
   - Mode gracieux sans crash sur les environnements hors-ligne, Web et Desktop.

7. **Design System & Ergonomie** :
   - Architecture visuelle moderne Bento Grid.
   - Palette de couleurs professionnelle : Bleu nuit `#0F172A`, Bleu profond `#1D4ED8`, Cyan `#0284C7`.
   - Typographie Google Fonts *Inter*.
   - Support complet du **Thème Clair** et du **Thème Sombre** avec persistance locale des préférences.

---

## 🛠️ Stack Technique & Architecture

```
lib/
├── core/
│   ├── theme/
│   │   └── app_theme.dart          # Palettes de couleurs (Light & Dark), styles Material 3, polices
│   ├── utils/
│   │   └── formatters.dart         # Formatage lisible des tailles (KB, MB), ratios et dimensions
│   └── widgets/
│       └── result_bottom_sheet.dart# Feuille modale de résultat (gain d'espace, ouverture, partage)
├── features/
│   ├── home/presentation/
│   │   └── home_screen.dart        # Bento Grid d'accueil, Hero card 200 Ko, statut vie privée
│   ├── image_compress/presentation/
│   │   └── image_compress_screen.dart # Compression par taille cible (Ko) et qualité (%)
│   ├── image_resize/presentation/
│   │   └── image_resize_screen.dart   # Redimensionnement pixels, échelle et préréglages passeport
│   ├── image_convert/presentation/
│   │   └── image_convert_screen.dart  # Conversion JPG ↔ PNG
│   ├── pdf_tools/presentation/
│   │   └── images_to_pdf_screen.dart  # Génération de documents PDF multi-pages A4
│   ├── history/presentation/
│   │   └── history_screen.dart        # Historique des opérations, espace économisé, purge
│   └── settings/presentation/
│       └── settings_screen.dart       # Choix du thème, politique de confidentialité, nettoyage cache
├── services/
│   ├── image_service.dart          # Décodage, encodage et calculs d'images en Isolates Dart
│   ├── pdf_service.dart            # Composition et rendu de PDF vectoriels et multi-images
│   ├── file_service.dart           # Sélecteur natif (FilePicker), exports, ouverture (OpenFilex) et partage (SharePlus)
│   ├── history_service.dart        # Sauvegarde locale SharedPreferences des métadonnées
│   └── ads_service.dart            # Service Google AdMob, bannières et interstitiels avec capping
└── main.dart                       # Point d'entrée, verrouillage portrait, chargement du thème
```

---

## 📦 Dépendances et Licences Open Source

| Package | Version | Licence | Rôle |
|---|---|---|---|
| `image` | 4.5.4 | Apache-2.0 | Manipulation d'images, redimensionnement et compression en pur Dart |
| `pdf` | 3.12.0 | Apache-2.0 | Création et rendu de documents PDF multi-pages |
| `file_picker` | 13.3.0 | MIT | Sélection native de fichiers sans permissions intrusives |
| `path_provider` | 2.1.6 | BSD-3-Clause | Résolution des répertoires cache et stockage temporaire |
| `share_plus` | 13.3.1 | BSD-3-Clause | Partage natif vers WhatsApp, e-mail, Drive, etc. |
| `open_filex` | 5.0.0 | BSD-3-Clause | Visualisation des PDF et photos avec les applications par défaut |
| `google_mobile_ads` | 9.2.0 | Apache-2.0 | SDK officiel Google AdMob |
| `shared_preferences` | 2.5.6 | BSD-3-Clause | Persistance du thème et de l'historique local |
| `google_fonts` | 8.2.1 | Apache-2.0 | Typographie moderne *Inter* |
| `intl` | 0.20.3 | BSD-3-Clause | Formatage des dates et nombres |

---

## 🚀 Installation & Commandes de Développement

### Prérequis
- Flutter SDK `>= 3.41.0` (Dart `>= 3.11.0`)
- Android Studio / Android SDK 34+ pour la compilation Android

### Installation des dépendances
```bash
flutter pub get
```

### Vérification de l'analyse statique
```bash
flutter analyze
```

### Exécution des tests automatisés
```bash
flutter test
```

### Lancement en mode debug
```bash
flutter run
```

### Compilation de l'APK Android (Release)
```bash
flutter build apk --release
```

---

## 💰 Configuration AdMob pour la Mise en Production

Pour connecter vos propres annonces publicitaires réelles avant la publication sur Google Play :

1. Créez votre compte sur [Google AdMob](https://admob.google.com).
2. Ajoutez une application Android nommée `FileEase`.
3. Remplacez l'ID d'application de test dans `android/app/src/main/AndroidManifest.xml` :
   ```xml
   <meta-data
       android:name="com.google.android.gms.ads.APPLICATION_ID"
       android:value="ca-app-pub-VOTRE_APP_ID_REEL~XXXXXXXXXX"/>
   ```
4. Créez vos unités d'annonces (Bannière adaptative et Interstitiel) et mettez à jour les constantes dans `lib/services/ads_service.dart`.
5. Activez les messages de consentement européen UMP (RGPD) dans la section *Confidentialité et messages* de votre console AdMob.

---

## 📄 Licence
Ce projet est développé sous licence **MIT**.
