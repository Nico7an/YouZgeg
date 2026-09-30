# 🚀 YouZgeg - Auto-Patcher YouTube Morphe

Système automatisé de détection, compilation et mise à jour de **YouTube avec les patches Morphe** (sans publicité, SponsorBlock, lecture en arrière-plan, intégration GmsCore/MicroG, etc.).

---

## 🏗️ Architecture & Fonctionnement

1. **Détection automatique & Patch (Cloud - GitHub Actions)** :
   - Un workflow s'exécute chaque jour à **04h00 UTC** (ou à la demande via `workflow_dispatch`).
   - Il interroge les dernières versions de Morphe et détermine la version compatible la plus récente de YouTube.
   - Si une nouvelle version est disponible, il télécharge l'APK officiel, applique l'ensemble des 83+ patches Morphe, signe l'APK avec le keystore persistant `morphe.keystore` et publie une **GitHub Release privée**.
   - **Avantage** : 0% de charge CPU/RAM sur votre serveur Debian de production.

2. **Mises à jour automatiques sur votre smartphone (Obtainium)** :
   - YouTube patché ne passe plus par Google Play Store (les mises à jour Play Store sont désactivées pour éviter d'écraser les patchs).
   - **Obtainium** (sur Android) surveille votre dépôt GitHub (avec un token d'accès personnel pour un dépôt privé).
   - Dès qu'un nouvel APK est disponible, Obtainium vous envoie une **notification Android : "Mise à jour disponible pour YouTube Morphe"**.
   - En un clic (ou automatiquement en tâche de fond avec Shizuku), l'APK se met à jour par-dessus l'ancienne version **sans perte de compte ni de configuration**.

3. **Compilation locale sur le serveur (`build_local.sh`)** :
   - Un script autonome utilisant Docker (`eclipse-temurin:21`) est disponible si vous préférez compiler directement sur le serveur.
   - L'APK généré est déposé à la racine : `youtube-morphe.apk`.

---

## 📱 Configuration sur le smartphone Android

### Étape 1 : Prérequis (MicroG)
Pour pouvoir vous connecter à votre compte Google sur YouTube sans root :
- Téléchargez et installez **[MicroG-RE](https://github.com/MorpheApp/MicroG-RE/releases)** sur votre téléphone.

### Étape 2 : Installer l'APK initial
- Récupérez `youtube-morphe.apk` généré à la racine de ce dossier (ou depuis les Releases GitHub) et installez-le.

### Étape 3 : Configurer Obtainium pour les mises à jour automatiques
1. Installez **[Obtainium](https://github.com/ImranR98/Obtainium/releases)** sur votre smartphone Android.
2. Créez un token GitHub (Personal Access Token - Fine-grained ou Classic) avec permission `read:packages` ou lecture de dépôt :
   - Rendez-vous sur GitHub : `Settings` → `Developer Settings` → `Personal access tokens` → `Tokens (classic)`.
   - Cochez `repo` (pour lire les releases d'un dépôt privé).
3. Dans Obtainium :
   - Allez dans **Settings** → **Credentials & API Keys** → **GitHub** → Collez votre token.
   - Cliquez sur **Add App** :
     - **App Source URL** : `https://github.com/Nico7an/YouZgeg`
     - Cochez *Include Prereleases* si souhaité.
     - Cliquez sur **Add**.
4. Désormais, dès qu'une nouvelle version de YouTube Morphe est générée, Obtainium vous proposera la mise à jour directement !

---

## ⚙️ Commandes Utiles sur le Serveur

### Créer et synchroniser le dépôt GitHub privé
Pour initialiser le dépôt privé sur votre compte GitHub (`Nico7an`) :
```bash
cd /home/nico/Documents/YouZgeg
git init
git add .
git commit -m "feat: setup Morphe auto-builder pipeline"
gh repo create Nico7an/YouZgeg --private --source=. --remote=origin --push
```

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

---

## 🔑 Signature & Keystore
Le fichier `morphe.keystore` contient la clé RSA de signature de l'APK.
**IMPORTANT** : Ce fichier doit être conservé précieusement et partagé entre les builds (commité dans votre dépôt privé) afin qu'Android reconnaisse toujours les mises à jour comme provenant de la même source (`INSTALL_FAILED_UPDATE_INCOMPATIBLE` évité).
