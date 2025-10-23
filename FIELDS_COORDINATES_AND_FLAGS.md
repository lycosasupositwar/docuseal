# Gestion des coordonnées et des flags des champs

Ce document explique comment les coordonnées et les options (flags) des champs de template sont stockés dans la base de données de DocuSeal.

## Structure des champs

Les informations sur les champs sont stockées dans la colonne `fields` de la table `templates` sous forme d'un tableau JSON. Chaque élément de ce tableau est un objet représentant un champ.

Voici un exemple de la structure d'un objet champ :

```json
{
  "uuid": "...",
  "submitter_uuid": "...",
  "name": "...",
  "type": "...",
  "required": true,
  "readonly": false,
  "prefillable": true,
  "areas": [
    {
      "x": 100,
      "y": 200,
      "w": 150,
      "h": 30,
      "page": 1,
      "attachment_uuid": "..."
    }
  ],
  "preferences": {},
  "validation": {},
  "conditions": []
}
```

## Coordonnées des champs

Les coordonnées de chaque champ sont stockées dans le tableau `areas`. Un champ peut avoir plusieurs `areas`, ce qui signifie qu'il peut apparaître à plusieurs endroits dans les documents.

-   `x` : La coordonnée X (horizontale) du coin supérieur gauche du champ, mesurée depuis le bord gauche de la page.
-   `y` : La coordonnée Y (verticale) du coin supérieur gauche du champ, mesurée depuis le bord supérieur de la page.
-   `w` : La largeur (width) du champ.
-   `h` : La hauteur (height) du champ.
-   `page` : Le numéro de la page sur laquelle le champ est situé.
-   `attachment_uuid` : L'UUID de la pièce jointe (`ActiveStorage::Attachment` représentant le document) à laquelle cette zone est associée.

**Note** : Les unités des coordonnées (`x`, `y`, `w`, `h`) sont basées sur les dimensions de l'aperçu de l'image généré (défini par une largeur maximale de `1400` pixels), et non sur les points PDF d'origine. La conversion est effectuée lors du traitement du document.

## Flags et options

Les "flags" et autres options sont stockés directement en tant qu'attributs de l'objet champ :

-   **Flags booléens** :
    -   `required` : Si `true`, le champ doit être rempli par le signataire.
    -   `readonly` : Si `true`, le champ ne peut pas être modifié par le signataire.
    -   `prefillable` : Si `true`, le champ peut être pré-rempli.

-   **Autres configurations** :
    -   `preferences` : Un objet JSON pour stocker des préférences spécifiques à l'interface utilisateur ou d'autres métadonnées.
    -   `validation` : Un objet JSON contenant des règles de validation (par exemple, `pattern` pour une expression régulière, `min`, `max`).
    -   `conditions` : Un tableau JSON qui définit la logique conditionnelle pour afficher ou masquer le champ en fonction des valeurs d'autres champs.
