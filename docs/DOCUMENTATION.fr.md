# SysteMIC — Documentation du backoffice église

**Version :** 1.0.0  
**Dernière mise à jour :** juillet 2026  
**Application :** SysteMIC (`mic_backoffice`)

> **Guides :** [Guide utilisateur (FR)](USER_GUIDE.fr.md) · [User guide (EN)](USER_GUIDE.md)

---

## Table des matières

1. [Introduction](#1-introduction)
2. [Premiers pas](#2-premiers-pas)
3. [Rôles et permissions](#3-rôles-et-permissions)
4. [Navigation (mobile vs bureau)](#4-navigation-mobile-vs-bureau)
5. [Tableau de bord](#5-tableau-de-bord)
6. [Membres](#6-membres)
7. [Départements](#7-départements)
8. [Présence aux cultes](#8-présence-aux-cultes)
9. [Présence à l'école du dimanche](#9-présence-à-lécole-du-dimanche)
10. [Visiteurs](#10-visiteurs)
11. [Événements](#11-événements)
12. [Formations (classes) et sessions](#12-formations-classes-et-sessions)
13. [Enseignements et auditeurs](#13-enseignements-et-auditeurs)
14. [Tâches, projets et étiquettes](#14-tâches-projets-et-étiquettes)
15. [Pénalités de tâches](#15-pénalités-de-tâches)
16. [Planning de service (Équipe Média)](#16-planning-de-service-équipe-média)
17. [Finances et collectes](#17-finances-et-collectes)
18. [Chat et annonces](#18-chat-et-annonces)
19. [Notifications et push](#19-notifications-et-push)
20. [Rapports](#20-rapports)
21. [Paramètres et administration](#21-paramètres-et-administration)
22. [Visionneuse de fichiers](#22-visionneuse-de-fichiers)
23. [Référence des règles métier](#23-référence-des-règles-métier)
24. [Annexe technique](#24-annexe-technique)

---

## 1. Introduction

### Qu'est-ce que SysteMIC ?

SysteMIC est une application de backoffice conçue pour la direction et l'administration d'une église. Elle centralise les opérations quotidiennes : fiches membres, présences, visiteurs, départements, tâches, finances, événements, formations, enseignements et rapports.

L'application est disponible sur **mobile** (téléphone/tablette) et **bureau/web** (navigateur ou fenêtre de bureau). Les deux plateformes partagent les mêmes données et le même backend.

### Qui l'utilise ?

| Type d'utilisateur | Usage typique |
|--------------------|---------------|
| **Admin / Pasteur** | Configuration complète, comptes utilisateurs, permissions des responsables, export de données |
| **Responsable de département** | Membres, présences, tâches, rapports de département, planning Équipe Média |
| **Responsable finances** | Enregistrements de collectes et rapports financiers |
| **Membre (avec connexion)** | Accès en lecture seule ou limité selon la configuration de l'administrateur |

### Langues

L'interface prend en charge le **français**, l'**anglais** et l'**espagnol**. Changez la langue dans **Paramètres**.

### Technologie (résumé)

- **Frontend :** Flutter (Dart)
- **Backend :** Supabase (base PostgreSQL, authentification, stockage, edge functions)
- **Notifications push (mobile) :** Firebase Cloud Messaging (FCM)

---

## 2. Premiers pas

### 2.1 Connexion

1. Ouvrez l'application.
2. Saisissez votre **e-mail** et votre **mot de passe**.
3. Appuyez sur **Se connecter**.

Si c'est votre première connexion avec le mot de passe par défaut (`Password123`), vous serez redirigé vers **Changer le mot de passe** avant de pouvoir utiliser l'application.

### 2.2 Mot de passe oublié

1. Sur l'écran de connexion, appuyez sur **Mot de passe oublié**.
2. Saisissez votre e-mail.
3. Suivez le lien de réinitialisation envoyé par e-mail.
4. Définissez un nouveau mot de passe sur l'écran de réinitialisation.

### 2.3 Configuration initiale (administrateur)

Un administrateur doit :

1. Créer les fiches membres (ou importer des données).
2. Créer des comptes de connexion pour les responsables qui en ont besoin (**Paramètres → Comptes membres**).
3. Configurer les **Accès responsables** par utilisateur (modules autorisés en lecture/création/modification/suppression).
4. Créer les départements et nommer les responsables.
5. Configurer éventuellement les notifications d'anniversaire et les paramètres de pénalités de tâches.

### 2.4 Comportement de l'écran de démarrage

Au lancement, l'application :

- Restaure votre session si elle est encore valide.
- Redirige vers la connexion si la session a expiré.
- Exécute des vérifications en arrière-plan (ex. calcul des pénalités de tâches).
- Enregistre l'appareil pour les notifications push sur mobile.

---

## 3. Rôles et permissions

### 3.1 Rôles utilisateur

| Rôle | Description |
|------|-------------|
| `admin` | Accès complet à toutes les fonctionnalités et paramètres |
| `pastor` | Traité comme admin pour les vérifications de permissions |
| `leader` | Accès contrôlé par les paramètres **Accès responsables** |
| `member` | Connexion liée à une fiche membre ; généralement en lecture seule sauf droits supplémentaires |

> **Note :** L'e-mail `mic@mic.com` est toujours traité comme administrateur (super admin).

### 3.2 Rôles au sein d'un département

Dans chaque département, chaque membre a un rôle départemental :

| Rôle | Signification |
|------|---------------|
| `leader` | Responsable du département |
| `subleader` | Adjoint |
| `member` | Membre ordinaire du département |

Les responsables et adjoints de département sont considérés comme « responsables » pour certaines vérifications de permissions, même si leur rôle utilisateur global est `member`.

### 3.3 Accès responsables (permissions granulaires)

**Chemin :** Paramètres → Gestion des accès responsables (administrateur uniquement)

Pour chaque responsable ou membre disposant d'une connexion, l'administrateur peut définir des permissions **par fonctionnalité** :

| Permission | Signification |
|------------|---------------|
| Voir | Peut ouvrir et consulter le module |
| Créer | Peut ajouter de nouveaux enregistrements |
| Modifier | Peut modifier des enregistrements existants |
| Supprimer | Peut supprimer ou effectuer une suppression logique |

**Fonctionnalités contrôlables :**

| Clé de fonctionnalité | Module |
|-----------------------|--------|
| `members` | Membres |
| `departments` | Départements |
| `trainings` | Formations / classes |
| `events` | Événements |
| `tasks` | Tâches |
| `reports` | Hub des rapports |
| `church_attendance` | Présence aux cultes |
| `sunday_school_attendance` | École du dimanche |
| `visitors` | Visiteurs |
| `giving` | Finances / collectes |
| `chat` | Annonces |
| `teachings` | Enseignements |

### 3.4 Règles d'accès particulières

- **Onglet Finances (navigation inférieure mobile) :** Visible uniquement si vous êtes admin **ou** responsable du département nommé **Finance**.
- **Création d'annonces :** Admin, pasteur ou responsable (non contrôlé par les accès responsables granulaires).
- **Pages Comptes membres et Accès responsables :** Admin/pasteur uniquement.

---

## 4. Navigation (mobile vs bureau)

### 4.1 Disposition mobile

- **Navigation inférieure** (sur les écrans principaux) : Accueil, Membres, [Finances si autorisé], Chat, Paramètres.
- **Actions rapides du tableau de bord** vers : Membres, Départements, Formations, Rapports, Présence aux cultes, École du dimanche, Visiteurs, Enseignements.
- Les autres modules (Tâches, détail des départements, etc.) sont accessibles depuis le tableau de bord, les listes ou la navigation interne.
- Bouton **Retour** standard dans la barre d'application.

### 4.2 Disposition bureau

- Activée lorsque la largeur d'écran est **≥ 500 px**.
- **Barre latérale gauche fixe** (240 px) avec tous les modules principaux.
- **Zone de contenu** avec en-tête et navigation en pile (liste → détail sans rechargement complet).
- Pages de connexion/inscription/mot de passe oublié distinctes pour le bureau.

**Modules de la barre latérale bureau :**

Accueil · Membres · Départements · Finances · Chat · Paramètres · Notifications · Anniversaires · Événements · Tâches · Formations · Rapports · Présence aux cultes · École du dimanche · Visiteurs · Enseignements · Sessions

### 4.3 Accès aux notifications

- **Mobile :** Icône cloche sur la barre du tableau de bord → Liste des notifications.
- **Bureau :** Élément Notifications dans la barre latérale.

---

## 5. Tableau de bord

**Chemin :** Accueil / Tableau de bord

### Objectif

Offre aux responsables un aperçu rapide de l'activité de l'église et des raccourcis vers les modules clés.

### Contenu affiché

#### Statistiques récapitulatives

| Statistique | Description |
|-------------|-------------|
| Sessions à venir | Sessions de formation dans les 35 prochains jours |
| Événements à venir | Événements futurs actifs |
| Tâches ouvertes | Tâches avec statut `pending` ou `in_progress` |
| Anniversaires | Membres fêtant leur anniversaire ce mois-ci |
| Membres | Total des membres actifs (mobile) |

#### Graphique de présence aux cultes (bureau)

- Graphique en courbes montrant la **présence quotidienne** lors des cultes récents.
- Compare la présence par culte avec la **présence hebdomadaire totale**.

#### Listes et tableaux (bureau)

- Événements à venir
- Enseignements récents
- Anniversaires à venir
- Nouveaux venus (membres marqués comme nouveaux)

#### Sections mobile

- Bannière de bienvenue avec la date du jour
- Grille d'actions rapides (8 raccourcis)
- Cartes d'aperçu : anniversaires, enseignements, nouveaux venus, événements

### Actions

- Tirer pour actualiser (mobile) afin de recharger toutes les données du tableau de bord.
- Appuyer sur une statistique ou un élément de liste pour ouvrir le module correspondant.

---

## 6. Membres

**Chemin :** Membres (`/members`)

### Objectif

Registre central de toutes les personnes liées à l'église : coordonnées, profil spirituel, départements, statut de nouveau venu et compte de connexion optionnel.

### 6.1 Liste des membres

- Rechercher et filtrer les membres.
- Filtrer par statut de nouveau venu, rôle, actif/inactif.
- Ouvrir une fiche membre ou ajouter un nouveau membre.

### 6.2 Ajouter / modifier un membre

#### Champs obligatoires

- Prénom, nom
- Date de naissance (obligatoire à la création)

#### Champs du profil

| Champ | Description |
|-------|-------------|
| E-mail, téléphone | Contact ; le téléphone utilise un sélecteur d'indicatif pays (Cameroun par défaut) |
| Adresse, ville, région, code postal, pays, quartier | Localisation |
| Genre | `male`, `female`, `other` |
| Situation matrimoniale | `single`, `married`, `divorced`, `widowed` |
| Rôle | `member`, `worker`, `leader`, `admin`, `sympathiser` |
| Profession | Niveaux d'études, recherche d'emploi, salarié — détermine les champs études/diplômes |
| Niveau d'études, filière, domaine, compétences clés, diplômes | Conditionnels selon la profession |
| Photo | Téléversée vers le stockage cloud |
| Actif | Indique si le membre est actuellement actif |
| Nouveau venu | Marqueur pour le suivi d'intégration |
| Date d'arrivée comme nouveau venu | Date de début en tant que nouveau venu |
| Intention du nouveau venu | Voir ci-dessous |
| Désactivation notifications anniversaire | Exclure des campagnes de notification d'anniversaire |

#### Intention du nouveau venu

| Valeur | Signification |
|--------|---------------|
| `wants_to_stay` | Souhaite rejoindre l'église |
| `does_not_know_yet` | Indécis |
| `just_passing` | **Ne peut pas être enregistré comme membre** — utiliser Visiteurs à la place |

### 6.3 Fiche membre

Les onglets comprennent généralement :

- **Profil** — détails complets, modification, suppression (si autorisé)
- **Présence** — historique de présence aux cultes et aux formations
- **Classes** — formations auxquelles le membre est inscrit

Actions :

- Modifier le membre
- Ouvrir le rapport individuel du membre
- Contacter via WhatsApp (si numéro de téléphone renseigné)

### 6.4 Anniversaires à venir

**Chemin :** `/members/birthdays`

- Liste les membres dont l'anniversaire arrive dans la période à venir.
- Utile pour le suivi pastoral et l'organisation des célébrations.

### 6.5 Comptes membres (administrateur)

**Chemin :** Paramètres → Comptes membres

- Créer un **compte de connexion** pour un membre disposant d'une adresse e-mail.
- Mot de passe par défaut : `Password123` (doit être changé à la première connexion).
- Les nouveaux comptes démarrent avec un accès **lecture seule** sur toutes les fonctionnalités jusqu'à ajustement des accès responsables par l'administrateur.

### 6.6 Passage de nouveau venu à membre intégré (automatique)

Lorsqu'un membre est marqué **nouveau venu**, le système suit sa présence aux cultes. Après **9 présences ou plus sur 90 jours**, le marqueur de nouveau venu peut être levé automatiquement (fonction base de données `check_and_update_new_comer_status`).

---

## 7. Départements

**Chemin :** Départements (`/departments`)

### Objectif

Organiser l'église en équipes (Équipe Média, Finances, Louange, etc.) avec membres, documents, tâches, rapports écrits et planning de service optionnel.

### 7.1 Liste des départements

- Voir tous les départements.
- Ajouter un département (si autorisé).
- Ouvrir le détail d'un département.

### 7.2 Créer / modifier un département

| Champ | Description |
|-------|-------------|
| Nom | Nom du département |
| Description | Texte optionnel |
| Actif | Indique si le département est en usage |
| Montant pénalité de tâche | Surcharge optionnelle de pénalité journalière pour les tâches du département (francs) |
| Documents | Jusqu'à 4 fichiers de référence (PDF, images, etc.) avec noms personnalisés |

### 7.3 Détail du département

#### Onglet Aperçu

- Description du département
- **Documents** — ouvrir dans la visionneuse de fichiers
- **Membres** — ajouter/retirer, attribuer un rôle départemental (`leader`, `subleader`, `member`)
- Statistiques et actions rapides

#### Onglet Tâches

- Ouvre l'**espace de travail tâches** filtré sur ce département.
- Générer des **rapports PDF mensuels ou annuels** des tâches du département.

#### Onglet Rapports

- Liste des **rapports écrits du département** (narratifs).
- Ajouter, modifier, supprimer des rapports.
- Exporter un PDF individuel ou un résumé.

### 7.4 Équipe Média — planning de service

Si le département est l'**Équipe Média**, un bouton **Planning de service** ouvre le roster de production média (voir [Section 16](#16-planning-de-service-équipe-média)).

---

## 8. Présence aux cultes

**Chemin :** Liste des présences aux cultes (`/attendance/church/list`) → Marquer la présence (`/attendance/church`)

### Objectif

Enregistrer qui a assisté à chaque rassemblement de l'église. Le système prend en charge **n'importe quelle date** et **plusieurs cultes nommés par jour** (ex. « Culte du matin » et « Culte du soir » le même dimanche).

### 8.1 Concepts

| Concept | Description |
|---------|-------------|
| **Culte** (`church_service`) | Un rassemblement à une **date** précise avec un **nom** obligatoire |
| **Enregistrement de présence** | Une ligne par membre et par culte |

> **Note historique :** Les anciennes données ont été migrées depuis les types dimanche/mercredi vers des cultes nommés (« Culte du dimanche », « Culte du mercredi »).

### 8.2 Liste des cultes

- Parcourir tous les cultes (du plus récent au plus ancien).
- Chaque ligne affiche : **nom du culte**, **date complète**, **nombre de présents**.
- Filtrer par plage de dates et nom de culte.
- Actions : ouvrir la présence, supprimer le culte, générer un rapport PDF.

### 8.3 Créer un nouveau culte

1. Ouvrir **Marquer la présence** (ou ajouter depuis la liste).
2. Choisir une **date** (n'importe quel jour de la semaine).
3. Saisir un **nom de culte** (obligatoire, unique pour cette date).
   - Exemples : « Dimanche matin », « Prière du mercredi », « Campagne de réveil ».
4. Enregistrer — la ligne de culte est créée dans `church_services`, puis vous pouvez marquer les présences.

### 8.4 Marquer la présence

Pour chaque **membre actif** :

| Type de présence | Signification |
|------------------|---------------|
| `onsite` | Présent physiquement |
| `online` | Suivi à distance (streaming, etc.) |
| `absent` | N'a pas assisté |

Options supplémentaires :

- **Observation spécifique** — note libre par membre (ex. motif d'absence).
- **Marquage groupé** — définir le même statut pour plusieurs membres à la fois.
- **Filtre** — afficher tous, présents sur place, en ligne, absents, ou **enfants** (âge 0–12 ans).
- **Recherche** — trouver des membres par nom.

### 8.5 Visiteurs sur la page de présence

- Enregistrer des visiteurs pour la même date de culte.
- Les visiteurs peuvent être liés à un `church_service_id` précis.
- Types de présence visiteur : `onsite`, `online` (les visiteurs n'utilisent pas `absent` de la même manière que les membres).

### 8.6 Contact WhatsApp

Depuis l'écran de présence, les responsables peuvent ouvrir WhatsApp pour contacter un membre (utilise le numéro enregistré).

### 8.7 Supprimer un culte

Suppression logique de :

- L'enregistrement du culte
- Toutes les lignes de présence pour ce culte
- Les visiteurs liés à ce culte

### 8.8 Rapports

Depuis la liste ou la page de présence :

- **Rapport complet de présence** (PDF) — plage de dates, filtre de culte optionnel.
- **Rapport des absents** (PDF) — membres marqués absents pour un culte donné.

### 8.9 Modèle de données (référence)

**`church_services`**

| Colonne | Description |
|---------|-------------|
| `id` | UUID |
| `service_date` | Date du rassemblement |
| `name` | Obligatoire ; unique par date |
| `created_by` | Utilisateur créateur |

**`church_attendance`**

| Colonne | Description |
|---------|-------------|
| `member_id` | Membre |
| `church_service_id` | Culte concerné |
| `service_date` | Date dénormalisée |
| `attendance_type` | `onsite`, `online`, `absent` |
| `specific_observation` | Note optionnelle |

---

## 9. Présence à l'école du dimanche

**Chemin :** Liste école du dimanche (`/attendance/sunday-school/list`) → Session (`/attendance/sunday-school`)

### Objectif

Présence pour **les enfants uniquement** (âges 0–12 selon la catégorie d'âge du système).

### Déroulement

1. Ouvrir la **liste des sessions** — regroupées par `attendance_date`.
2. Sélectionner une date (ou créer une nouvelle date de session).
3. Voir les membres enfants éligibles.
4. Marquer chaque enfant comme présent.
5. Exporter un rapport PDF pour une plage de dates.

### Données

**`sunday_school_attendance` :** `member_id`, `attendance_date`, `created_by`

> L'école du dimanche est **distincte** de la présence aux cultes et n'utilise pas `church_services`.

---

## 10. Visiteurs

**Chemin :** Visiteurs (`/visitors`)

### Objectif

Suivre les personnes qui visitent l'église sans être encore (ou jamais) membres à part entière — notamment celles qui sont « de passage ».

### 10.1 Ajouter / modifier un visiteur

| Champ | Description |
|-------|-------------|
| Prénom, nom | Obligatoires |
| E-mail, téléphone, adresse | Optionnels |
| Date de visite | Date de la visite |
| Culte | Lien optionnel vers un culte précis à cette date |
| Type de présence | `onsite` ou `online` |
| Notes | Texte libre |

Si le **culte** est laissé vide, la visite s'applique à la date en général (tout culte ce jour-là).

### 10.2 Convertir un visiteur en membre

Depuis la liste des visiteurs :

1. Sélectionner un visiteur.
2. Choisir **Convertir en membre**.
3. Compléter les champs membre (date de naissance, rôle, marqueurs nouveau venu).
4. L'enregistrement visiteur est supprimé logiquement ; un nouveau membre est créé.

> Les visiteurs avec l'intention `just_passing` doivent rester visiteurs, pas membres.

### 10.3 Rapports

- **Rapport visiteurs PDF** — filtrer par plage de dates depuis la page liste.

---

## 11. Événements

**Chemin :** Événements (`/events`)

### Objectif

Publier les événements de l'église, gérer les inscriptions et suivre les personnes inscrites.

### 11.1 Champs d'événement

| Champ | Description |
|-------|-------------|
| Titre, description | Détails de l'événement |
| Date de l'événement | Date de déroulement |
| Lieu | Optionnel |
| Actif | Indique si l'événement est visible |
| Répété | Indique si l'événement comporte plusieurs sessions |

### 11.2 Détail de l'événement

#### Onglet Aperçu

- Informations sur l'événement
- Modifier / supprimer (si autorisé)

#### Onglet Inscriptions

- Liste des membres inscrits et des invités.
- **Inscrire un membre** — choisir dans la liste des membres.
- **Inscrire un invité** — nom, e-mail, téléphone sans fiche membre.
- **Inscription groupée** — plusieurs membres à la fois.
- **Désinscrire** — retirer une inscription.

### 11.3 Événements répétés

Pour les événements répétés, le système peut **générer des sessions** (similaire aux sessions de formation). Chaque session peut avoir son propre suivi de présence.

---

## 12. Formations (classes) et sessions

**Chemin :** Formations (`/trainings`)

### Objectif

Programmes de formation structurés (classes de discipleship, cours de leadership, etc.) avec membres inscrits et présence par session.

### 12.1 Champs de formation (classe)

| Champ | Description |
|-------|-------------|
| Nom | Titre de la formation |
| Description | Optionnelle |
| Département | Lien optionnel vers un département |
| Actif | Indique si la formation est en cours |

### 12.2 Déroulement

1. **Créer une formation** et éventuellement la lier à un département.
2. **Inscrire des membres** sur la page de détail de la formation.
3. **Générer des sessions** — crée les dates de session planifiées (généralement hebdomadaires).
4. Ouvrir une **session** → **Prendre la présence** pour chaque membre inscrit.
5. Consulter le **rapport de formation** depuis le hub Rapports.

### 12.3 Sessions (bureau)

**Chemin :** Bureau → Sessions

Vue transversale de toutes les sessions à venir, toutes formations confondues.

### 12.4 Présence hors ligne (limitée)

La présence aux sessions de formation peut être mise en file d'attente hors ligne via `OfflineQueueService` et synchronisée au retour de la connexion.

---

## 13. Enseignements et auditeurs

**Chemin :** Enseignements (`/teachings`)

### Objectif

Enregistrer les sermons/enseignements délivrés à l'église et suivre quels ouvriers/responsables les ont « écoutés » (revus ou pris connaissance de l'enseignement).

### 13.1 Champs d'enseignement

| Champ | Description |
|-------|-------------|
| Titre | Titre de l'enseignement |
| Date d'enseignement | Date de prédication |
| Orateur | Personne ayant délivré l'enseignement |
| Description | Notes optionnelles |

### 13.2 Auditeurs

Sur la page **détail** de l'enseignement :

- Les **auditeurs** sont des membres avec le rôle `worker`, `leader` ou `admin`.
- Ajouter ou retirer des auditeurs manuellement.
- **Synchroniser depuis la présence** — ajouter automatiquement les auditeurs présents aux cultes à la date de l'enseignement (tout culte ce jour-là, sur place ou en ligne).

### 13.3 Tâches auto-créées pour l'Équipe Média

Lorsqu'un nouvel enseignement est enregistré, le système crée automatiquement **6 tâches** pour le département **Équipe Média** :

| Type de tâche | Description |
|---------------|-------------|
| Mid 1, Mid 2 | Montages vidéo de durée moyenne |
| Short 1, Short 2, Short 3 | Clips courts |
| Full | Montage de l'enregistrement complet |

- Date d'échéance = date d'enseignement + décalage (par défaut **10 jours**, configurable dans les paramètres de pénalités).
- Les tâches apparaissent dans l'espace de travail tâches du département.

---

## 14. Tâches, projets et étiquettes

**Chemin :** Tâches (`/tasks`)

### Objectif

Gestion des tâches par département et individuelles avec plusieurs vues, projets, étiquettes colorées, rappels et analyses.

### 14.1 Champs de tâche

| Champ | Valeurs / notes |
|-------|-----------------|
| Titre | Obligatoire |
| Description | Optionnelle |
| Département | Tâche rattachée au département |
| Membre assigné | Ou assignation à un individu |
| Projet | Regroupement optionnel |
| Date d'échéance | AAAA-MM-JJ |
| Priorité | `urgent`, `high`, `medium`, `low` |
| Statut | `pending`, `in_progress`, `completed`, `cancelled` |
| Étiquettes | Plusieurs étiquettes colorées |
| Montant pénalité par jour | Surcharge optionnelle (francs) |
| Archivée | Exclue des calculs de pénalités |

### 14.2 Vues de l'espace de travail

| Vue | Description |
|-----|-------------|
| **Projets** | Tâches regroupées par projet ; ajout inline ; glisser-déposer entre projets |
| **Toutes / Tableau** | Colonnes triables et redimensionnables ; édition inline du titre, statut, assigné, échéance, étiquettes, description |
| **Tableau Kanban** | Colonnes par statut |
| **Chronologie** | Diagramme de type Gantt avec zoom |
| **Retard moyen** | Analyse : retard moyen à la clôture des tâches |
| **Charge de travail** | Analyse : tâches par membre |
| **Pénalités** | Membres avec soldes de pénalités ; enregistrer des paiements |

### 14.3 Projets

**Chemin :** Tâches → Gérer les projets (`/tasks/projects`)

- Créer des projets avec titre et département optionnel.
- Assigner des tâches aux projets.
- Suivre l'avancement des projets.

### 14.4 Étiquettes

**Chemin :** Tâches → Gérer les étiquettes (`/tasks/tags`)

- Les étiquettes sont **limitées au département** (ou globales).
- Chaque étiquette a un **nom** et une **couleur** (sélecteur de palette).
- Assigner des étiquettes à la création/modification des tâches ou inline dans le tableau.

### 14.5 Assignations

- Une tâche peut avoir **plusieurs assignés** (`task_assignments`).
- Chaque assignation a un statut : `pending`, `completed`, `cancelled`.
- L'assignation envoie une notification **task_assigned** (et push sur mobile).

### 14.6 Rappels

- **Rappel par tâche** — notifier tous les assignés depuis le détail de la tâche.
- **Rappeler toutes les en attente** — rappel groupé depuis la liste des tâches.
- Crée des notifications `task_reminder`.

### 14.7 Rapports de tâches par département

Depuis **Détail du département → Tâches**, exporter :

- PDF mensuel de complétion des tâches
- PDF annuel de complétion des tâches

---

## 15. Pénalités de tâches

### Objectif

Encourager la réalisation dans les délais des tâches (notamment les livrables média liés aux enseignements) via un système de solde de pénalités financières.

### 15.1 Comment les pénalités s'accumulent

- Pour chaque assignation de tâche **non terminée** après sa **date d'échéance**, une pénalité journalière est ajoutée.
- La pénalité commence le **lendemain** de la date d'échéance.
- Priorité du montant :
  1. `penalty_amount_per_day` au niveau de la tâche
  2. `task_penalty_amount` du département
  3. Valeur globale par défaut (**100 frs/jour**)

### 15.2 Seuil de blocage

- Par défaut : **3 500 frs** de solde total.
- Si le solde de pénalités d'un membre ≥ seuil, il est **bloqué pour de nouvelles assignations** jusqu'à réduction du solde.

### 15.3 Enregistrer des paiements

**Chemin :** Tâches → Vue Pénalités

1. Sélectionner un membre avec un solde.
2. Enregistrer un **paiement** (montant, date, notes).
3. Le solde diminue en conséquence.

### 15.4 Paramètres (globaux)

Stockés dans `task_penalty_settings` (id = `global`) :

| Paramètre | Valeur par défaut |
|-----------|-------------------|
| Pénalité journalière par défaut | 100 frs |
| Seuil de blocage | 3 500 frs |
| Décalage échéance tâches enseignement | 10 jours après la date d'enseignement |

Les pénalités sont recalculées au démarrage de l'application (écran de démarrage).

---

## 16. Planning de service (Équipe Média)

**Chemin :** `/service-schedule` (depuis le département Équipe Média)

### Objectif

Assigner les membres de l'Équipe Média aux rôles de production pour chaque date de culte.

### 16.1 Planning

- Un planning par **département et par date de culte**.
- Notes optionnelles pour la journée.

### 16.2 Rôles

| Clé de rôle | Libellé |
|-------------|---------|
| `projection` | Projection |
| `call_recording` | Appel / Enregistrement |
| `principal_cameraman` | Caméraman principal |
| `secondary_cameraman` | Caméraman secondaire |
| `photographer` | Photographe |

Jusqu'à **3 membres** peuvent être assignés par rôle.

### 16.3 Déroulement

1. Choisir une date de culte.
2. Assigner des membres à chaque rôle.
3. Marquer les assignations comme **terminées** une fois accomplies.
4. Les assignés reçoivent une notification **service_schedule_assigned**.

---

## 17. Finances et collectes

**Chemin :** Finances / Collectes (`/giving`)

### Objectif

Enregistrer dîmes, offrandes, dépenses et dons spéciaux. Réservé aux **responsables du département Finances** et aux **administrateurs**.

### 17.1 Champs d'enregistrement de collecte

| Champ | Description |
|-------|-------------|
| Nom du donateur | Obligatoire (membre ou externe) |
| Montant | Nombre positif |
| Type | `receiving` ou `expense` |
| Étiquette | `tithe`, `offering`, `construction`, `special_op`, `gift`, `other` |
| Membre | Lien optionnel si le donateur est membre |
| Notes | Optionnelles |

### 17.2 Déroulement

1. Ouvrir la liste Finances.
2. **Ajouter une collecte** — remplir le formulaire et enregistrer.
3. Filtrer et rechercher les transactions.
4. Modifier ou consulter les enregistrements existants.
5. **Générer un rapport PDF** pour une plage de dates.

### 17.3 Accès

- Mobile : Finances apparaît dans la navigation inférieure uniquement pour les utilisateurs autorisés.
- Bureau : Finances dans la barre latérale pour les utilisateurs autorisés.
- Nécessite aussi la permission `giving` dans les accès responsables (pour les responsables non admin).

---

## 18. Chat et annonces

**Chemin :** Chat (`/chat`)

### Objectif

Diffuser des **annonces** à l'église — globales, par département ou ciblées sur des membres précis.

> Malgré le nom « Chat », il s'agit d'un **fil d'annonces**, pas d'une messagerie en temps réel.

### 18.1 Consulter les annonces

- Annonces les plus récentes en premier.
- Affiche titre, message, date, portée (globale / département / ciblée).

### 18.2 Créer des annonces (admin / pasteur / responsable)

| Champ | Description |
|-------|-------------|
| Titre | En-tête court |
| Message | Texte complet |
| Globale | Envoyer à tout le monde |
| Département | Limiter à un département |
| Membres cibles | IDs de membres spécifiques optionnels |

Les destinataires reçoivent une notification in-app **announcement** (et push sur mobile si activé).

---

## 19. Notifications et push

**Chemin :** Notifications (`/notifications`)

### 19.1 Boîte de réception in-app

- Liste toutes les notifications de l'utilisateur connecté.
- Compteur de non lus affiché sur le tableau de bord / barre latérale.
- Appuyer pour marquer comme lu.
- Les liens profonds peuvent ouvrir la tâche, l'événement, etc. associé.

### 19.2 Types de notification

| Type | Moment d'envoi |
|------|----------------|
| `task_assigned` | Quelqu'un est assigné à une tâche |
| `task_reminder` | Un responsable envoie un rappel |
| `birthday` | Campagne de notification d'anniversaire |
| `announcement` | Nouvelle annonce publiée |
| `event` | Lié à un événement |
| `service_schedule_assigned` | Assignation au planning Équipe Média |

### 19.3 Notifications push (mobile)

- Utilise Firebase Cloud Messaging.
- Jeton d'appareil enregistré à la connexion.
- Délivré via l'edge function Supabase `send-push-notification`.
- Appuyer sur une push ouvre l'écran notifications (ou le contenu associé).

### 19.4 Notifications d'anniversaire

**Chemin :** Paramètres → Notifications d'anniversaire

| Paramètre d'audience | Destinataires |
|----------------------|---------------|
| Tous | Tous les membres actifs non désinscrits |
| Responsables uniquement | Responsables et adjoints de département |
| Désactivé | Désactivé pour toute l'église |

Les membres peuvent se désinscrire individuellement via **birthday_notifications_opt_out** sur leur profil.

---

## 20. Rapports

**Chemin :** Rapports (`/reports`)

### 20.1 Hub des rapports

Point d'entrée central pour les analyses et exports.

### 20.2 Rapports disponibles

| Rapport | Chemin | Périodes | PDF |
|---------|--------|----------|-----|
| Membres (agrégé) | `/reports/members` | Hebdomadaire, mensuel, annuel, personnalisé | — |
| Membre individuel | `/reports/member/:id` | Personnalisé | — |
| Formations (agrégé) | `/reports/trainings` | Hebdomadaire, mensuel, annuel, personnalisé | — |
| Formation individuelle | `/reports/training/:id` | Par classe | — |
| Nouveaux venus | `/reports/new-comers` | Hebdomadaire, mensuel, annuel, personnalisé | Oui |
| Présence aux cultes | Depuis la liste des présences | Plage de dates | Oui |
| École du dimanche | Depuis la liste école du dimanche | Plage de dates | Oui |
| Visiteurs | Depuis la liste visiteurs | Plage de dates | Oui |
| Finances | Depuis la page finances | Plage de dates | Oui |
| Tâches département | Depuis le détail département | Mensuel, annuel | Oui |
| Rapports écrits département | Depuis les rapports département | Par rapport | Oui |

### 20.3 Contenu du rapport nouveaux venus

- Liste des nouveaux venus avec intention et statut
- Répartition des présences (sur place / en ligne / absent) par nouveau venu
- Statistiques récapitulatives pour la période

### 20.4 Contenu du rapport de présence aux cultes

- Cultes dans la plage de dates avec effectifs
- Matrice de présence des membres (qui a assisté à quels cultes)
- Graphiques de présence regroupés par nom de culte
- Résumés d'assiduité / mensuels

---

## 21. Paramètres et administration

**Chemin :** Paramètres (`/settings`)

### 21.1 Préférences

| Paramètre | Options |
|-----------|---------|
| Langue | Français, anglais, espagnol |
| Thème | Clair, sombre, système |
| Notifications | Activer/désactiver la préférence de notification locale |

### 21.2 Notifications d'anniversaire

Configurer l'audience des notifications d'anniversaire pour toute l'église (voir [Section 19.4](#194-notifications-danniversaire)).

### 21.3 Gestion des données

| Action | Description |
|--------|-------------|
| Exporter toutes les données | Sauvegarde JSON complète (partager/enregistrer) |
| Importer des données | Restaurer depuis JSON (ignore les e-mails en double) |
| Exporter membres CSV | Tableur de la liste des membres |
| Synchroniser utilisateurs et membres | Admin : aligner les utilisateurs auth avec les fiches membres |
| PDF tous les utilisateurs | Admin : exporter le rapport liste utilisateurs |

### 21.4 Paramètres admin (admin/pasteur uniquement)

- **Gestion des accès responsables** — permissions par fonctionnalité et par utilisateur
- **Comptes membres** — créer des connexions pour les membres

### 21.5 Compte

- Afficher l'e-mail connecté
- Changer le mot de passe
- Se déconnecter
- Affichage de la version de l'application

### 21.6 Panneau administrateur

**Chemin :** `/admin` (admin)

- Créer des utilisateurs admin ou pasteur (e-mail, mot de passe, rôle).

---

## 22. Visionneuse de fichiers

**Chemin :** `/file-viewer` (ouvert depuis les documents de département et ailleurs)

### Objectif

Consulter les fichiers téléversés (notamment PDF et images) dans l'application.

### Comportement

- **PDF :** Rendu avec pdfrx ou WebView selon la plateforme.
- **Images :** Affichées inline.
- **Bureau :** S'ouvre en superposition dans le shell avec navigation retour.
- Les fichiers sont stockés dans Supabase Storage ; les URL sont passées à la visionneuse.

---

## 23. Référence des règles métier

| Règle | Détail |
|-------|--------|
| Passage nouveau venu → membre intégré | 9+ présences aux cultes sur 90 jours → `is_new_comer` levé |
| De passage | Impossible de créer comme membre ; utiliser Visiteurs |
| Cultes (`church_services`) | Date + nom obligatoires ; plusieurs par jour ; nom unique par date |
| Types de présence (culte) | `onsite`, `online`, `absent` |
| Types de présence (visiteur) | `onsite`, `online` |
| Filtre enfants | Âge 0–12 (`MemberUtils` catégorie enfant) |
| École du dimanche | Enfants uniquement ; table distincte de la présence aux cultes |
| Pénalités de tâches | Accumulation journalière après échéance ; seuil de blocage 3 500 frs |
| Tâches enseignement | 6 tâches auto par nouvel enseignement pour l'Équipe Média |
| Mot de passe par défaut | `Password123` pour les comptes nouveaux/synchronisés |
| Suppression logique | La plupart des tables utilisent `deleted_at` au lieu d'une suppression définitive |
| Pays téléphone par défaut | Cameroun (`CM`, +237) |
| Super admin | `mic@mic.com` a toujours l'accès admin |
| Accès finances | Admin ou responsable du département Finance |
| Création d'annonces | Admin, pasteur ou responsable (tout responsable) |

---

## 24. Annexe technique

### 24.1 Principales tables de base de données

| Table | Module |
|-------|--------|
| `users` | Authentification et rôles |
| `members` | Registre des membres |
| `leader_access` | Permissions granulaires |
| `departments`, `department_members` | Départements |
| `church_services`, `church_attendance` | Présence aux cultes |
| `sunday_school_attendance` | École du dimanche |
| `visitors` | Visiteurs |
| `events`, `event_registrations`, `event_sessions` | Événements |
| `classes`, `sessions`, `class_members`, `attendance` | Formations |
| `teachings`, `teaching_listeners` | Enseignements |
| `tasks`, `task_assignments`, `task_tags`, `tags`, `projects` | Tâches |
| `task_penalty_settings`, `task_penalty_payments` | Pénalités |
| `service_schedules`, `service_schedule_assignments` | Planning média |
| `giving` | Finances |
| `announcements` | Chat |
| `notifications`, `device_tokens` | Notifications |
| `new_comers` | Historique nouveaux venus |

### 24.2 Services clés (`lib/services/`)

| Service | Responsabilité |
|---------|----------------|
| `church_service_service.dart` | CRUD des cultes |
| `church_attendance_service.dart` | Marquage et requêtes de présence |
| `member_service.dart` | CRUD membres |
| `department_service.dart` | Départements |
| `task_service.dart` | Tâches, assignations, rappels |
| `task_penalty_service.dart` | Calcul des pénalités et paiements |
| `visitor_service.dart` | Visiteurs |
| `finance_service.dart` | Enregistrements de collectes |
| `teaching_service.dart` | Enseignements et auditeurs |
| `service_schedule_service.dart` | Planning Équipe Média |
| `leader_access_service.dart` | Vérifications de permissions |
| `notification_service.dart` | Notifications in-app |
| `report_service.dart` | Agrégation des rapports |
| `*_pdf_service.dart` | Génération PDF |

### 24.3 Référence des routes

Voir `lib/core/routes/route_names.dart` pour la liste complète des routes nommées.

### 24.4 Prise en charge hors ligne

- `OfflineQueueService` met en file d'attente des opérations limitées (présence formation, mises à jour de tâches) hors ligne.
- Le mode hors ligne complet **n'est pas** implémenté ; la présence aux cultes nécessite une connexion.

### 24.5 Migrations

Le schéma de base de données est géré via des scripts SQL à la racine du projet et `supabase/migrations/`. Migration notable :

- `MIGRATE_CHURCH_SERVICES.sql` — introduit `church_services` et supprime `service_type` de la présence aux cultes et des visiteurs.

### 24.6 Configuration des notifications push

Voir `supabase/functions/send-push-notification/README.md` pour la configuration du compte de service Firebase et le déploiement de l'edge function.

---

## Historique du document

| Date | Modification |
|------|--------------|
| Juillet 2026 | Documentation complète initiale ; modèle cultes (`church_services` : date + nom, plusieurs par jour) |

---

*Pour le support technique ou les demandes de fonctionnalités, contactez l'administrateur système de votre église.*
