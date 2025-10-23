# Processus de création de template dans DocuSeal

Ce document détaille le processus de création d'un template dans DocuSeal, depuis le téléversement d'un fichier PDF ou DOCX jusqu'à sa persistance en base de données.

## 1. Téléversement du fichier

Le processus débute lorsqu'un utilisateur téléverse un fichier via l'interface de création de template.

-   **Contrôleur** : `app/controllers/templates_uploads_controller.rb`
-   **Action** : `create`

L'action `create` du contrôleur `TemplatesUploadsController` est le point d'entrée. Elle gère le fichier téléversé, qu'il provienne d'un formulaire ou d'une URL.

## 2. Création du template et des pièces jointes

Le contrôleur fait appel à deux services principaux pour traiter le fichier :

-   `Templates::CreateAttachments` (`lib/templates/create_attachments.rb`)
-   `Templates::ProcessDocument` (`lib/templates/process_document.rb`)

### 2.1. `Templates::CreateAttachments`

Ce service est responsable de la création des pièces jointes (`ActiveStorage::Attachment`) pour le template.

1.  **Extraction des fichiers** : Si le fichier téléversé est une archive ZIP, le service extrait tous les fichiers qu'elle contient.
2.  **Création du `Blob` Active Storage** : Pour chaque fichier (PDF, image, etc.), un `ActiveStorage::Blob` est créé et téléversé. Le `blob` contient les métadonnées du fichier, telles que le nom du fichier, le type de contenu et le checksum.
3.  **Création du document** : Un enregistrement `Document` est créé pour chaque `blob`. Le `Document` est associé au `Template` et contient une référence au `blob`.

### 2.2. `Templates::ProcessDocument`

Ce service est responsable du traitement du contenu du document.

1.  **Extraction des champs de formulaire (pour les PDF)** : Si le document est un PDF, le service utilise la gem `HexaPDF` pour analyser le fichier et la classe `Templates::FindAcroFields` (`lib/templates/find_acro_fields.rb`) pour extraire les champs de formulaire (AcroForm).
2.  **Génération des aperçus** : Pour chaque page du document, des images d'aperçu sont générées à l'aide des gems `Pdfium` et `Vips`. Ces aperçus sont également stockés en tant que `ActiveStorage::Attachment` associés au `Document`.
3.  **Mise à jour des métadonnées** : Les champs extraits et d'autres métadonnées (comme le nombre de pages) sont stockés dans la colonne `metadata` de l'enregistrement `Document` au format JSON.

## 3. Persistance en base de données

Une fois le fichier traité, les informations sont persistées en base de données.

-   **Modèle `Template`** (`app/models/template.rb`) : Le modèle `Template` contient les informations générales sur le template, telles que le nom, l'auteur et le dossier. Les champs du template sont stockés dans la colonne `fields` au format JSON.
-   **Modèle `Document`** (`app/models/document.rb`) : Le modèle `Document` représente un fichier associé à un template. Il est lié à un `ActiveStorage::Blob` et contient les métadonnées extraites du fichier.
-   **Tables Active Storage** : Les tables `active_storage_blobs` et `active_storage_attachments` sont utilisées par Active Storage pour gérer les fichiers téléversés.

## Résumé du flux de données

1.  **`templates_uploads_controller.rb`** reçoit le fichier téléversé.
2.  Le contrôleur appelle **`Templates::CreateAttachments`** pour créer un `Document` et un `ActiveStorage::Blob`.
3.  `Templates::CreateAttachments` appelle **`Templates::ProcessDocument`** pour analyser le document, extraire les champs et générer les aperçus.
4.  Les informations sont enregistrées dans les tables **`templates`**, **`documents`**, **`active_storage_blobs`** et **`active_storage_attachments`**.
