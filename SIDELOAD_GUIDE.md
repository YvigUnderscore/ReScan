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
