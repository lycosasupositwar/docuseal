# Guide d'intégration pour une IA : Création d'une interface Django pour les templates DocuSeal

Ce document fournit toutes les informations nécessaires à un agent d'IA pour développer une application Django capable de créer et de manipuler des templates dans la base de données de DocuSeal.

## 1. Objectif

L'objectif est de permettre à une application Django d'insérer des données dans une base de données PostgreSQL de DocuSeal (une application Ruby on Rails) afin qu'un nouveau template, basé sur un fichier PDF ou DOCX, apparaisse et soit fonctionnel dans l'interface de DocuSeal.

## 2. Flux de processus de création de template dans DocuSeal

Comprendre le flux natif de DocuSeal est essentiel pour répliquer son comportement :

1.  **Téléversement** : Un utilisateur téléverse un fichier (PDF, DOCX, etc.).
2.  **Création du `Blob`** : Un enregistrement `ActiveStorage::Blob` est créé. Il contient les métadonnées du fichier (nom, taille, type MIME, checksum). Le fichier lui-même est stocké (par exemple, sur le disque local ou sur S3).
3.  **Création du `Template`** : Un enregistrement `Template` est créé dans la base de données. Il contient le nom, les champs, les signataires, etc.
4.  **Attachement du document** : Un `ActiveStorage::Attachment` est créé pour lier le `Blob` du fichier au `Template`. C'est cet attachement qui représente le "document".
5.  **Analyse du document** : Le fichier est analysé. Pour les PDF, les champs de formulaire (AcroForm) sont extraits. Le nombre de pages est compté.
6.  **Génération des aperçus** : Des images d'aperçu pour chaque page sont générées (généralement en PNG, avec une largeur maximale de 1400px).
7.  **Attachement des aperçus** : Pour chaque aperçu, un nouveau `Blob` est créé, puis un `Attachment` est créé pour lier ce `Blob` d'aperçu à l'attachement du document principal (c'est une relation polymorphique où un attachement est attaché à un autre attachement).
8.  **Persistance des métadonnées** : Les métadonnées extraites (champs, nombre de pages) sont stockées dans la colonne `metadata` (JSON) du `Blob` du document principal. Les champs sont également normalisés et stockés dans la colonne `fields` (JSON) du `Template`.

## 3. Schéma de la base de données à manipuler

### Table `templates`

Contient les informations de base du template.

-   `name` (string) : Nom du template.
-   `slug` (string) : Identifiant unique pour l'URL (doit être généré).
-   `schema` (jsonb) : Décrit les documents attachés. Exemple : `[{"attachment_uuid": "uuid-du-document", "name": "NomDuFichier"}]`.
-   `fields` (jsonb) : Le plus important. Un tableau d'objets, où chaque objet est un champ.
-   `submitters` (jsonb) : Un tableau d'objets décrivant les signataires.
-   `author_id`, `account_id`, `folder_id` (integer) : Clés étrangères à remplir avec des valeurs valides de votre instance DocuSeal.

### Table `active_storage_blobs`

Contient les métadonnées de chaque fichier. Un blob pour le document original, et un blob pour chaque page d'aperçu.

-   `key` (string) : Clé unique pointant vers le fichier dans le service de stockage. L'application Django doit s'assurer que le fichier est accessible à DocuSeal via cette clé.
-   `filename` (string) : Nom du fichier original.
-   `content_type` (string) : Type MIME.
-   `metadata` (jsonb) : Crucial. Pour le blob du document, doit contenir `{"number_of_pages": X}`. Pour les blobs d'aperçu, `{"width": Y, "height": Z}`.
-   `byte_size` (integer) : Taille du fichier en octets.
-   `checksum` (string) : Checksum MD5 du fichier (encodé en Base64).
-   `uuid` (string) : UUID unique pour le blob.

### Table `active_storage_attachments`

Table de liaison polymorphique.

-   `name` (string) : "documents" pour le fichier principal, "preview_images" pour les aperçus.
-   `uuid` (string) : UUID unique pour l'attachement.
-   `record_type` (string) :
    -   `'Template'` pour l'attachement du document.
    -   `'ActiveStorage::Attachment'` pour les attachements d'aperçu.
-   `record_id` (integer) :
    -   ID du template (pour le document).
    -   ID de l'attachement du document (pour les aperçus).
-   `blob_id` (integer) : ID du blob correspondant.

## 4. Structure des champs (JSON)

La colonne `templates.fields` est un tableau. Chaque objet champ doit avoir la structure suivante :

```json
{
  "uuid": "uuid-genere-pour-le-champ",
  "submitter_uuid": "uuid-du-signataire-defini-dans-submitters",
  "name": "Nom du champ (ex: Signature)",
  "type": "signature", // autres types: text, date, checkbox, etc.
  "required": true,
  "areas": [
    {
      "x": 100.5,
      "y": 200.2,
      "w": 150,
      "h": 30,
      "page": 0, // Numéro de page (commence à 0)
      "attachment_uuid": "uuid-de-l-attachement-du-document"
    }
  ]
}
```

### **Point crucial : le système de coordonnées**

Les coordonnées (`x`, `y`, `w`, `h`) dans `areas` **ne sont pas** basées sur les dimensions du PDF original. Elles sont basées sur les dimensions de l'image d'aperçu, qui est standardisée à une **largeur maximale de 1400 pixels**. L'application Django doit :
1.  Calculer le ratio `1400 / largeur_originale_de_la_page_pdf`.
2.  Multiplier toutes les coordonnées extraites du PDF par ce ratio pour les normaliser avant de les insérer dans la base de données.

## 5. Guide de création d'un template (séquence d'opérations)

Pour créer un nouveau template à partir d'un fichier PDF :

1.  **Préparation Côté Django** :
    -   Générez tous les UUID nécessaires : un pour le template, un pour chaque champ, un pour chaque signataire, un pour le blob du document, un pour l'attachement du document, un pour chaque blob d'aperçu, et un pour chaque attachement d'aperçu.
    -   Utilisez une bibliothèque Python (ex: `PyPDF2`) pour lire le PDF, compter le nombre de pages et extraire les dimensions de chaque page.
    -   Utilisez une bibliothèque de conversion (ex: `pdf2image`, `wand`) pour générer une image PNG pour chaque page. Redimensionnez ces images pour qu'elles aient une largeur de 1400 pixels, en conservant le ratio.
    -   Calculez le checksum (MD5 en Base64) et la taille en octets pour le PDF original et pour chaque image d'aperçu générée.
    -   Stockez le PDF et les images d'aperçu dans un emplacement de stockage (disque, S3) que DocuSeal peut lire.

2.  **Transactions SQL (PostgreSQL)** : Exécutez les insertions suivantes dans l'ordre.

    ```sql
    -- Remplacez les valeurs entre <...>

    -- Étape 1: Insérer le blob pour le document PDF original
    INSERT INTO active_storage_blobs (key, filename, content_type, metadata, service_name, byte_size, checksum, created_at, updated_at, uuid)
    VALUES ('<key_pdf>', '<nom_fichier.pdf>', 'application/pdf', '{"number_of_pages": <nb_pages>}', 'local', <taille_pdf>, '<checksum_pdf>', NOW(), NOW(), '<uuid_blob_pdf>');

    -- Étape 2: Insérer un blob pour CHAQUE image d'aperçu (répétez pour chaque page)
    INSERT INTO active_storage_blobs (key, filename, content_type, metadata, service_name, byte_size, checksum, created_at, updated_at, uuid)
    VALUES ('<key_apercu_p0>', '0.png', 'image/png', '{"width": 1400, "height": <hauteur_calculee>}', 'local', <taille_apercu>, '<checksum_apercu>', NOW(), NOW(), '<uuid_blob_apercu_p0>');

    -- Étape 3: Insérer le template
    INSERT INTO templates (slug, name, "schema", fields, submitters, author_id, account_id, folder_id, source, preferences, created_at, updated_at)
    VALUES ('<slug_template>', '<nom_template>', '[{"attachment_uuid": "<uuid_attachement_doc>"}]', '[{"uuid": "<uuid_champ>", ...}]'::jsonb, '[{"uuid": "<uuid_signataire>"}]'::jsonb, 1, 1, 1, 'upload', '{}', NOW(), NOW());

    -- Étape 4: Lier le blob du document au template
    INSERT INTO active_storage_attachments (name, uuid, record_type, record_id, blob_id, created_at)
    VALUES ('documents', '<uuid_attachement_doc>', 'Template', (SELECT id FROM templates WHERE slug = '<slug_template>'), (SELECT id FROM active_storage_blobs WHERE uuid = '<uuid_blob_pdf>'), NOW());

    -- Étape 5: Lier CHAQUE blob d'aperçu à l'attachement du document (répétez pour chaque page)
    INSERT INTO active_storage_attachments (name, uuid, record_type, record_id, blob_id, created_at)
    VALUES ('preview_images', '<uuid_attachement_apercu_p0>', 'ActiveStorage::Attachment', (SELECT id FROM active_storage_attachments WHERE uuid = '<uuid_attachement_doc>'), (SELECT id FROM active_storage_blobs WHERE uuid = '<uuid_blob_apercu_p0>'), NOW());

    ```

Utilisez `ON CONFLICT DO NOTHING` sur les contraintes d'unicité (comme `uuid` ou `slug`) pour rendre les opérations idempotentes.
