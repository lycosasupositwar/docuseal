# Schéma de la base de données pour la création de templates

Ce document détaille le schéma des tables de la base de données impliquées dans le processus de création de templates dans DocuSeal.

## Table `templates`

Cette table contient les informations principales sur les templates.

-   `id` : Clé primaire de la table.
-   `slug` : Identifiant unique utilisé dans les URL.
-   `name` : Nom du template.
-   `schema` : (TEXT) Stocke la structure du document, y compris les informations sur les fichiers attachés (documents) et leurs conditions.
-   `fields` : (TEXT) Stocke un tableau JSON des champs du template. Chaque objet champ contient des attributs tels que `uuid`, `submitter_uuid`, `name`, `type`, `required`, etc.
-   `submitters` : (TEXT) Stocke un tableau JSON des signataires du template.
-   `author_id` : Clé étrangère vers la table `users`, indiquant l'auteur du template.
-   `account_id` : Clé étrangère vers la table `accounts`, indiquant le compte auquel le template appartient.
-   `archived_at` : Date et heure à laquelle le template a été archivé.
-   `created_at` : Date et heure de création du template.
-   `updated_at` : Date et heure de la dernière mise à jour du template.
-   `folder_id` : Clé étrangère vers la table `template_folders`, indiquant le dossier dans lequel le template est stocké.
-   `...` : D'autres colonnes liées aux préférences, aux liens de partage, etc.

## Modèle `Document` et `Active Storage`

Le modèle `Document` n'a pas sa propre table. Il s'agit en fait d'un `ActiveStorage::Attachment` qui est associé à un `Template`. Le `record_type` de l'attachement est `Template` et le `name` est `documents`.

### Table `active_storage_attachments`

Cette table est une table polymorphique qui lie les enregistrements aux `blobs` (fichiers).

-   `id` : Clé primaire de la table.
-   `name` : Nom de l'attachement (par exemple, `documents` ou `preview_images`).
-   `uuid` : Identifiant unique de l'attachement.
-   `record_type` : Type de l'enregistrement auquel l'attachement est associé (par exemple, `Template` ou `ActiveStorage::Attachment` pour les aperçus).
-   `record_id` : ID de l'enregistrement auquel l'attachement est associé.
-   `blob_id` : Clé étrangère vers la table `active_storage_blobs`.
-   `created_at` : Date et heure de création de l'attachement.

### Table `active_storage_blobs`

Cette table contient les métadonnées sur les fichiers téléversés.

-   `id` : Clé primaire de la table.
-   `key` : Clé unique utilisée pour référencer le fichier dans le service de stockage.
-   `filename` : Nom du fichier d'origine.
-   `content_type` : Type MIME du fichier.
-   `metadata` : (TEXT) Colonne JSON qui stocke les métadonnées extraites du fichier, telles que le nombre de pages, les champs de formulaire, les dimensions des images, etc.
-   `service_name` : Nom du service de stockage utilisé (par exemple, `local`, `s3`).
-   `byte_size` : Taille du fichier en octets.
-   `checksum` : Checksum du fichier.
-   `created_at` : Date et heure de création du blob.
-   `uuid` : Identifiant unique du blob.
