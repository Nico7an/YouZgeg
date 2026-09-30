# 🚀 YouZgeg - Auto-Patcher YouTube Morphe avec In-App Update

Système automatisé de détection, compilation et mise à jour **100% In-App** de YouTube patché avec Morphe (sans publicité, SponsorBlock, lecture en arrière-plan, intégration GmsCore/MicroG, etc.).

---

## 📲 Mise à jour In-App (comme dans Plezy)

**Aucun outil externe (comme Obtainium) n'est nécessaire.**
L'application intègre un module de vérification (`JhcUpdateCheckPatch`) directement injecté dans le bytecode de YouTube :

1. **Vérification automatique au démarrage** :
   - À l'ouverture de l'application (ou toutes les 24h), YouTube interroge l'API des releases du dépôt : `https://api.github.com/repos/Nico7an/YouZgeg/releases`.
   - Si une nouvelle version est disponible, **une popup Material 3 s'affiche directement dans l'application** :
     * Version disponible vs version installée.
     * Bouton **« Télécharger »** : télécharge l'APK et ouvre directement l'installeur de packages Android.
     * Bouton **« Plus tard »** (Snooze).
     * Lien vers le changelog.

2. **Vérification manuelle dans les paramètres** :
   - Dans YouTube : `Paramètres` → `Morphe` → `Mises à jour des patchs`.
   - Cliquez pour vérifier immédiatement s'il y a une mise à jour disponible.

---

## 🏗️ Architecture & Fonctionnement

1. **Détection automatique & Compilation (GitHub Actions)** :
   - Le workflow s'exécute chaque jour à **04h00 UTC** (ou à la demande via `workflow_dispatch`).
   - Il interroge les dernières versions de Morphe et détermine la version compatible la plus récente de YouTube.
   - Si une nouvelle version est disponible, il télécharge l'APK officiel, compile l'extension de mise à jour in-app pointant vers `Nico7an/YouZgeg`, applique l'ensemble des 84 patches Morphe, signe l'APK avec le keystore persistant `morphe.keystore` et publie la **GitHub Release** avec `youtube-morphe.apk`.
   - **Avantage** : 0% de charge CPU/RAM sur votre serveur Debian de production.

2. **Compilation locale sur le serveur (`build_local.sh`)** :
   - Un script autonome utilisant Docker (`eclipse-temurin:21`) est disponible si vous préférez compiler directement sur le serveur.
   - L'APK généré est déposé à la racine : `youtube-morphe.apk`.

---

## 📱 Installation sur le smartphone Android

### Étape 1 : Prérequis (MicroG)
Pour pouvoir vous connecter à votre compte Google sur YouTube sans root :
- Téléchargez et installez **[MicroG-RE](https://github.com/MorpheApp/MicroG-RE/releases)** sur votre téléphone.

### Étape 2 : Installer l'APK initial
- Téléchargez et installez **[youtube-morphe.apk](https://github.com/Nico7an/YouZgeg/releases/latest)** depuis les releases du dépôt.

### Étape 3 : C'est tout !
Dès qu'une nouvelle version est publiée, l'application vous proposera la mise à jour directement à l'écran.

---

## ⚙️ Commandes Utiles sur le Serveur

### Compiler localement en Docker
Si vous voulez forcer un build localement sur le serveur :
```bash
./build_local.sh
# Pour forcer la recompilation même si la version est inchangée :
./build_local.sh --force
```

### Télécharger le dernier APK depuis GitHub
Pour rapatrier le dernier APK compilé par GitHub Actions sur votre serveur :
```bash
./sync_latest.sh
```
