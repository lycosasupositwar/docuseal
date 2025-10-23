-- Ce script SQL fournit des requêtes idempotentes pour insérer un nouveau template,
-- ses documents, et ses aperçus dans la base de données de DocuSeal.
-- Remplacez les placeholders `<..._value>` par les valeurs réelles.

-- Les requêtes utilisent `ON CONFLICT DO NOTHING` pour éviter les erreurs si
-- un enregistrement avec la même contrainte d'unicité (par exemple, uuid, key) existe déjà.

-- 1. Insérer le blob pour le document PDF/DOCX original
INSERT INTO active_storage_blobs (key, filename, content_type, metadata, service_name, byte_size, checksum, created_at, updated_at, uuid)
VALUES
    ('<blob_key_value>', '<filename_value>', 'application/pdf', '{ "identified": true, "analyzed": true, "pdf": { "number_of_pages": 1 } }', 'local', <byte_size_value>, '<checksum_value>', NOW(), NOW(), '<blob_uuid_value>')
ON CONFLICT (uuid) DO NOTHING;

-- 2. Insérer le blob pour l'image d'aperçu de la première page
INSERT INTO active_storage_blobs (key, filename, content_type, metadata, service_name, byte_size, checksum, created_at, updated_at, uuid)
VALUES
    ('<preview_blob_key_value>', '0.png', 'image/png', '{ "analyzed": true, "identified": true, "width": 1400, "height": 1812 }', 'local', <preview_byte_size_value>, '<preview_checksum_value>', NOW(), NOW(), '<preview_blob_uuid_value>')
ON CONFLICT (uuid) DO NOTHING;

-- 3. Insérer le template principal
INSERT INTO templates (slug, name, "schema", fields, submitters, author_id, account_id, folder_id, source, preferences, created_at, updated_at)
VALUES
    ('<template_slug_value>', '<template_name_value>', '[{ "attachment_uuid": "<document_attachment_uuid_value>", "name": "<document_name_value>" }]', '[{ "uuid": "<field_uuid_value>", "submitter_uuid": "<submitter_uuid_value>", "name": "Signature 1", "type": "signature", "required": true, "areas": [{ "x": 100, "y": 200, "w": 150, "h": 30, "page": 0, "attachment_uuid": "<document_attachment_uuid_value>" }] }]', '[{ "uuid": "<submitter_uuid_value>", "name": "Signer 1" }]', <author_id_value>, <account_id_value>, <folder_id_value>, 'upload', '{}', NOW(), NOW())
ON CONFLICT (slug) DO NOTHING;

-- 4. Attacher le document au template.
-- Note : L'ID du template doit être récupéré après l'insertion précédente.
INSERT INTO active_storage_attachments (name, uuid, record_type, record_id, blob_id, created_at)
VALUES
    ('documents', '<document_attachment_uuid_value>', 'Template', (SELECT id FROM templates WHERE slug = '<template_slug_value>'), (SELECT id FROM active_storage_blobs WHERE uuid = '<blob_uuid_value>'), NOW())
ON CONFLICT (uuid) DO NOTHING;

-- 5. Attacher l'image d'aperçu au document.
-- Note : L'ID de l'attachement du document doit être récupéré.
INSERT INTO active_storage_attachments (name, uuid, record_type, record_id, blob_id, created_at)
VALUES
    ('preview_images', '<preview_attachment_uuid_value>', 'ActiveStorage::Attachment', (SELECT id FROM active_storage_attachments WHERE uuid = '<document_attachment_uuid_value>'), (SELECT id FROM active_storage_blobs WHERE uuid = '<preview_blob_uuid_value>'), NOW())
ON CONFLICT (uuid) DO NOTHING;
