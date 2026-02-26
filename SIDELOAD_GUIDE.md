# Installer l'application sur iPhone (Gratuitement)

Puisque vous n'avez pas de Mac, nous utilisons **GitHub Actions** pour construire l'application dans le cloud. Voici comment installer le fichier `.ipa` sur votre iPhone.

## 1. Télécharger le fichier IPA
1. Allez sur votre dépôt GitHub.
2. Cliquez sur l'onglet **Actions**.
3. Cliquez sur le dernier "run" (exécution) du workflow "Build iOS App".
4. En bas, dans la section **Artifacts**, téléchargez `DIETCapture-IPA`.
5. Décompressez le fichier zip pour obtenir `DIETCapture.ipa`.

## 2. Installer sur l'iPhone (Sideloading)
C'est totalement **gratuit**. Vous avez besoin d'un PC (Windows ou Linux) ou juste de l'iPhone si vous utilisez des services de signature en ligne (moins recommandés pour la confidentialité).

### Option A : AltStore (Recommandé - Windows/Linux)
Si vous avez accès un jour à un PC Windows ou si vous configurez AltServer sur Linux (plus complexe).
1. Installez **AltServer** sur votre ordinateur.
2. Connectez votre iPhone.
3. Installez **AltStore** sur votre iPhone via AltServer (nécessite votre Apple ID gratuit).
4. Transférez le fichier `DIETCapture.ipa` sur votre iPhone (via iCloud Drive, AirDrop, etc.).
5. Ouvrez AltStore sur l'iPhone, appuyez sur "+", et sélectionnez l'`ipa`.

## 3. Installer et Démarrer AltStore

1.  **Lancer le script d'installation** :
    ```bash
    chmod +x install_altstore.sh
    ./install_altstore.sh
    ```
2.  **Sur votre iPhone** :
    *   L'icône **AltStore** va apparaître.
    *   Si vous essayez de l'ouvrir, vous aurez un message "Développeur non approuvé".
    *   Allez dans **Réglages** > **Général** > **VPN et gestion de l'appareil**.
    *   Appuyez sur votre e-mail (Apple ID) sous "APP DE DÉVELOPPEMENT".
    *   Appuyez sur **"Faire confiance à..."**.
    *   Maintenant, vous pouvez ouvrir AltStore !

## 4. Installer DIETCapture (votre application)

Une fois que vous avez le fichier `DIETCapture.ipa` (téléchargé depuis GitHub Actions) :

### Méthode via USB (Recommandée sur Linux)
Utilisez le même outil `AltServer` pour installer votre app :

```bash
# 1. Définir le mot de passe de manière sécurisée (masqué)
read -s -p "Entrez votre mot de passe Apple ID : " APPLE_PASSWORD

# 2. Lancer l'installation (la commande utilisera la variable)
sudo ./AltServer -u <VOTRE_UDID> -a <VOTRE_EMAIL> -p "$APPLE_PASSWORD" DIETCapture.ipa

# 3. Effacer la variable après utilisation (optionnel mais recommandé)
unset APPLE_PASSWORD
```

*(Note : L'UDID est affiché par le script d'installation ou via la commande `idevice_id -l`)*

### Méthode via AltStore (sur le téléphone)
1.  Copiez le fichier `.ipa` sur votre iPhone (via iCloud Drive, AirDrop, ou téléchargement direct).
2.  Ouvrez **AltStore**.
3.  Allez dans l'onglet **My Apps**.
4.  Appuyez sur le **+** en haut à gauche.
5.  Sélectionnez le fichier `DIETCapture.ipa`.
6.  *Note : Cela nécessite que AltServer tourne sur le PC et soit sur le même Wi-Fi, ce qui est parfois instable sur Linux. La méthode USB ci-dessus est plus fiable.*

### Option B : Sideloadly (Windows/macOS)
Très simple si vous avez accès à un ordinateur Windows.
1. Téléchargez **Sideloadly**.
2. Connectez l'iPhone.
3. Glissez le fichier `.ipa` dans Sideloadly.
4. Entrez votre Apple ID.
5. Cliquez sur Start.

### Option C : Scarlet (Sans ordinateur - Directement sur l'iPhone)
1. Allez sur le site de [Scarlet](https://usescarlet.com/) depuis Safari sur l'iPhone.
2. Installez Scarlet (choisissez l'option "Direct Install" si elle fonctionne, sinon Computer method).
3. Ouvrez Scarlet et importez votre fichier `.ipa` pour l'installer.
*Note : Cette méthode peut parfois être révoquée par Apple.*

## Note Importante
Avec un compte Apple gratuit, l'application est signée pour **7 jours**. Après 7 jours, elle ne s'ouvrira plus. Vous devrez simplement la réinstaller (ou "rafraîchir" via AltStore) pour qu'elle fonctionne à nouveau. C'est la contrainte de la gratuité.