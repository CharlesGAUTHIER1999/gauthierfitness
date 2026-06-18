# 03 — Manuel d'utilisation

> Guide destiné aux **utilisateurs finaux** (clients de la boutique) et aux **administrateurs** qui gèrent le catalogue
> et les commandes. Couvre la compétence RNCP **C2.4.1**.

---

## Partie A — Parcours client

### A.1 Découvrir le catalogue

1. Ouvrir <https://gauthierfitness.fr>.
2. La page d'accueil affiche les produits mis en avant.
3. Le menu permet de filtrer par :
    - **Genre** (homme, femme, mixte)
    - **Catégorie** (t-shirts, leggings, accessoires, nutrition, etc.)
    - **Tag** (nouveautés, meilleures ventes)
4. Cliquer sur un produit ouvre la **page détail** avec :
    - Galerie d'images (image principale + survol)
    - Sélecteur de variante (couleur ou goût selon le produit)
    - Sélecteur de taille / format / contenance
    - Indicateur de stock
    - Bouton **« Personnaliser »** si le produit est customisable
    - Bouton **« Ajouter au panier »**

### A.2 Personnaliser un produit (2D)

Disponible sur les vêtements et accessoires customisables.

1. Cliquer sur **« Personnaliser »** sur la page produit.
2. L'éditeur 2D s'ouvre avec une vue du produit.
3. Outils disponibles :
    - **Texte** — choisir police, couleur, taille, position
    - **Logo** — uploader un fichier PNG/JPG/WebP (≤ 3 Mo)
    - **Image** — uploader une image décorative (≤ 5 Mo)
    - **IA** *(si activée sur le produit)* — décrire un design en langage naturel, l'IA génère une image
4. Manipuler les éléments par drag-and-drop, redimensionner avec les poignées.
5. Cliquer sur **« Aperçu »** pour voir le rendu final.
6. Cliquer sur **« Ajouter au panier »** — la personnalisation est enregistrée et liée à la ligne du panier.

#### Mode formulaire (accessibilité)

Pour les utilisateurs ne pouvant pas utiliser la souris, un bouton **« Mode formulaire »** propose la même customisation
via des champs texte et des sélecteurs.

### A.3 Génération de design par IA

Sur les produits qui autorisent l'IA :

1. Dans l'éditeur, cliquer sur l'icône **« IA »**.
2. Saisir un prompt descriptif (10 caractères minimum, 5000 maximum).
    - Exemple : *« Un dragon stylisé en noir et or, esthétique japonaise, sur fond transparent »*
3. Cliquer sur **« Générer »** — la requête prend 6 à 10 secondes.
4. L'image générée apparaît dans l'éditeur, manipulable comme une image uploadée.
5. Si le résultat ne convient pas, relancer la génération avec un prompt affiné.

> **Note** — Les designs générés sont sauvegardés dans le compte utilisateur et réutilisables.

### A.4 Gérer son panier

1. Cliquer sur l'icône panier en haut à droite.
2. Pour chaque ligne :
    - Voir le sous-total, la variante, la personnalisation éventuelle
    - Modifier la quantité avec les boutons `+` / `−`
    - Supprimer la ligne avec l'icône poubelle
3. Le sous-total et le délai de livraison s'affichent en bas.
4. Cliquer sur **« Passer commande »** pour aller au checkout.

### A.5 Passer commande

1. Connexion / inscription si pas déjà connecté.
2. Saisir l'**adresse de livraison** (prénom, nom, adresse, code postal, ville, pays, téléphone optionnel).
3. Cliquer sur **« Payer »** — le formulaire Stripe Elements apparaît.
4. Saisir la carte bancaire (Stripe gère le **3D-Secure** automatiquement si la banque le demande).
5. Confirmer le paiement.
6. **Redirection vers la page de confirmation** avec récap de commande.
7. Email de confirmation envoyé dans la foulée.

### A.6 Suivre ses commandes

1. Menu **« Mon compte » → « Mes commandes »**.
2. Liste des commandes par ordre antéchronologique.
3. Pour chaque commande :
    - Numéro, date, statut (`new`, `processing`, `shipped`, `delivered`, `canceled`)
    - Total TTC
    - Suivi de livraison (numéro de tracking + lien transporteur quand disponible)
4. Cliquer sur une commande pour voir le détail (lignes, prix unitaire, personnalisations).
5. À chaque changement de statut → email automatique.

### A.7 Contacter le support

Formulaire de contact en footer : <https://gauthierfitness.fr/contact>

- Nom, email, sujet (optionnel), message obligatoires.
- Limité à 5 envois par minute par IP (anti-spam).
- Le message arrive sur l'email support configuré (`hortense.gauthier2002@gmail.com`).

---

## Partie B — Back-office administrateur

### B.1 Accéder à l'admin

1. Se connecter avec un compte ayant le rôle `admin`.
2. Aller sur <https://gauthierfitness.fr/admin>.
3. Le dashboard affiche les statistiques globales : produits actifs, commandes du jour/semaine/mois, CA, alertes stock.

### B.2 Gérer le catalogue

#### Lister / rechercher les produits

- Menu **« Produits »** → tableau paginé (20 / page) avec recherche par nom ou SKU.
- Filtres : `actif`, `customisable`.
- Colonnes : image, nom, SKU, prix TTC, statut, options.

#### Créer un produit

- Bouton **« Nouveau produit »** → formulaire avec :
    - Identifiants : nom, SKU (unique), description
    - Prix HT, prix TTC, TVA (généralement 20 %)
    - Flags : actif, customisable, mode (`2d` / `3d`), autoriser texte / image / IA
    - Options (taille / format / contenance) — ajoutables en une seule étape
- À la création, le slug est généré automatiquement à partir du nom et dédupliqué si conflit.

#### Modifier / supprimer un produit

- Cliquer sur une ligne → page d'édition.
- Tous les champs sont modifiables, sauf le slug.
- Suppression possible — les commandes existantes conservent leur snapshot et restent consultables.
- Bouton **« Activer / Désactiver »** pour cacher temporairement du catalogue public.

### B.3 Gérer le stock

#### Vue d'ensemble

- Menu **« Stock »** → liste paginée de tous les produits avec leur quantité totale (somme des lots).
- Recherche par nom / SKU.
- Filtre visuel : produits en **rupture** (qty = 0) ou en **alerte** (qty < 5).

#### Détail d'un produit

- Cliquer sur un produit → vue détail :
    - **Stock global** (lots sans variante) — par exemple pour la nutrition unitaire
    - **Stock par option** (lots associés à une taille / goût)
    - Pour chaque lot : numéro, quantité, quantité initiale, date d'expiration
    - Lots triés FIFO (expiration la plus proche en premier)

#### Réapprovisionner

- Bouton **« Nouveau lot »** → formulaire :
    - Option (optionnelle, sinon stock global)
    - Numéro de lot (obligatoire, unique)
    - Quantité initiale
    - Date d'expiration (optionnelle, doit être future)
- À la création, un mouvement de stock `in` est tracé automatiquement.

#### Corriger un lot

- Bouton **« Ajuster »** sur un lot → saisir la nouvelle quantité et un motif obligatoire.
- Un mouvement de stock `correction` est tracé avec le delta.
- Utilisé pour : casse, inventaire physique, erreur de saisie.

#### Historique des mouvements

- Bouton **« Historique »** sur un produit → tableau paginé (30 / page) avec :
    - Date, type (`in` / `out` / `correction`), quantité, raison, lot concerné
    - Sorties (`out`) automatiquement liées à la commande qui a consommé le stock.

### B.4 Gérer les commandes

#### Lister / rechercher

- Menu **« Commandes »** → tableau paginé (20 / page).
- Filtres : statut, recherche par email/nom/prénom client.
- Colonnes : numéro, client, total TTC, statut paiement, statut commande, date.

#### Détail d'une commande

- Cliquer sur une commande → vue détail :
    - Client (firstname, lastname, email, téléphone)
    - Lignes (produit, variante, personnalisation, quantité, prix unitaire, total)
    - Paiement (provider, montant, statut, ID Stripe)
    - Livraison (adresse complète, transporteur, tracking)

#### Changer le statut

- Bouton **« Marquer comme... »** :
    - **Processing** — commande prise en charge (préparation)
    - **Shipped** — expédiée → email automatique au client avec numéro de tracking
    - **Delivered** — livrée → email automatique
    - **Canceled** — annulée → email automatique

Les emails ne sont envoyés **qu'une seule fois** par transition grâce aux marqueurs `shipped_email_sent_at`, etc.

#### Saisir un numéro de tracking

- Sur la page détail, encart **« Livraison »** → champ tracking + URL transporteur.
- Visible côté client dans **« Mes commandes »**.

---

## Partie C — Comptes utilisateurs

### Rôles

| Rôle                | Capacités                                                      |
|---------------------|----------------------------------------------------------------|
| Anonyme             | Naviguer le catalogue, contacter le support                    |
| Client (`customer`) | + Ajouter au panier, commander, customiser, voir ses commandes |
| Admin (`admin`)     | + Accéder au back-office, gérer catalogue / stock / commandes  |

Le rôle admin est attribué via la commande artisan :

```bash
php artisan tinker
>>> User::find(1)->roles()->attach(Role::where('name', 'admin')->first());
```

### Réinitialisation de mot de passe

Pas encore exposée côté UI — à passer par l'admin pour générer un nouveau mot de passe :

```bash
php artisan tinker
>>> User::find($id)->update(['password' => Hash::make('nouveau-mdp')]);
```

Évolution prévue : flow self-service classique avec lien magique par email.

---

## Partie D — Dépannage

### « Mon panier disparaît à chaque déconnexion »

C'est volontaire : le panier est lié à l'utilisateur en base. À la connexion suivante, il est récupéré tel quel. Si
vide, vérifier que la commande n'a pas été validée entre temps (un paiement réussi vide le panier).

### « Le paiement échoue »

- Vérifier que la carte n'est pas en mode test (4242 ne fonctionne qu'en environnement de dev).
- Le 3D-Secure peut être déclenché par la banque — finir la procédure dans le pop-up.
- Si l'erreur persiste, vérifier dans Stripe Dashboard (`payment_intent.payment_failed` log).

### « Un produit affiche stock = 0 mais je viens d'en ajouter »

Vider le cache navigateur ou rafraîchir. Le stock est recalculé à la volée par requête SQL (somme des `quantity` des
lots).

### « L'éditeur 2D ne s'ouvre pas »

- Vérifier que le navigateur supporte WebGL (testable sur <https://get.webgl.org>).
- Désactiver les bloqueurs de scripts (uBlock peut bloquer `react-konva`).
