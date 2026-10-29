/**
 * Guide utilisateur (français). Les libellés d'écran sont écrits entre « »
 * exactement comme dans l'application ; la vue les met en évidence.
 */

export interface GuideTopic {
  id: string
  title: string
  summary: string
  route?: string
  steps?: string[]
  tips?: string[]
  warning?: string
}

export interface GuideChapter {
  id: string
  icon: string
  title: string
  intro: string
  topics: GuideTopic[]
}

export interface QuickStartStep {
  title: string
  text: string
  route: string
}

export const hotelQuickStart: QuickStartStep[] = [
  { title: 'Activer le module Hôtel', text: 'Sans ce module, le menu « Hôtel » n\'apparaît pas.', route: '/admin/settings/modules' },
  { title: 'Créer le bâtiment', text: 'Puis les « Ailes / zones » et les « Étages ».', route: '/admin/hotel/room-config/buildings' },
  { title: 'Définir les types de chambres', text: 'Prix par nuit, capacité, lits et « Équipements » inclus.', route: '/admin/hotel/room-config/room-types' },
  { title: 'Créer les chambres', text: 'Une par une, ou une « Plage (en masse) ».', route: '/admin/hotel/rooms' },
  { title: 'Régler l\'hôtel', text: 'Heures d\'arrivée et de départ, caution, taxes et ménage.', route: '/admin/hotel/settings' },
  { title: 'Prendre une réservation', text: 'On réserve un type de chambre ; le numéro est attribué à l\'arrivée.', route: '/admin/hotel/reservations' },
  { title: 'Enregistrer la première arrivée', text: 'La chambre passe en occupée et le folio s\'ouvre.', route: '/admin/hotel/stays' },
]

export const quickStart: QuickStartStep[] = [
  { title: 'Configurer l\'entreprise', text: 'Devise de l\'application, modes de paiement de la caisse, logo des tickets et factures.', route: '/admin/organization/currencies' },
  { title: 'Créer les magasins', text: 'Un magasin par point de vente. Un seul peut être « Magasin principal ».', route: '/admin/organization/stores' },
  { title: 'Créer les entrepôts', text: 'Les lieux où le stock est compté (dépôt, réserve, boutique).', route: '/admin/organization/warehouses' },
  { title: 'Ajouter les utilisateurs', text: 'Rôles, magasins autorisés et PIN caissier.', route: '/admin/organization/users' },
  { title: 'Préparer les référentiels', text: 'Taxes, catégories, marques et unités de mesure.', route: '/admin/catalog/taxes' },
  { title: 'Créer les produits', text: 'Un par un ou en masse avec le modèle Excel.', route: '/admin/products' },
  { title: 'Remplir l\'assortiment du magasin', text: 'Importer les produits du catalogue dans le magasin pour les vendre.', route: '/admin/stores' },
  { title: 'Saisir le stock initial', text: '« Créer un solde d\'ouverture » par entrepôt.', route: '/admin/inventory/counts' },
  { title: 'Créer les caisses et appareils', text: 'Une caisse par tiroir-caisse, puis lier les terminaux.', route: '/admin/organization/registers' },
  { title: 'Faire la première vente', text: 'Ouvrir un shift, puis encaisser au point de vente.', route: '/admin/pos/terminal' },
]

export const guideChapters: GuideChapter[] = [
  {
    id: 'start',
    icon: 'info',
    title: 'Bien démarrer',
    intro: 'Connexion, repères dans l\'interface et réglages personnels. À lire en premier.',
    topics: [
      {
        id: 'login',
        title: 'Se connecter et se déconnecter',
        summary: 'Chaque personne a son propre compte. Ses droits dépendent de ses rôles et des magasins qui lui sont affectés.',
        steps: [
          'Ouvrez l\'adresse de l\'application dans votre navigateur.',
          'Saisissez votre adresse e-mail et votre mot de passe, puis cliquez sur « Connexion ».',
          'Un écran de chargement s\'affiche quelques secondes, puis le « Tableau de bord » s\'ouvre.',
          'Pour quitter, ouvrez le menu de votre profil en haut à droite et cliquez sur « Déconnexion ».',
        ],
        tips: ['Ne partagez jamais votre compte : toutes les ventes, mouvements de stock et validations sont enregistrés au nom de la personne connectée.'],
      },
      {
        id: 'layout',
        title: 'Se repérer dans l\'interface',
        summary: 'Le menu de gauche donne accès aux modules ; la barre du haut regroupe les réglages rapides.',
        steps: [
          'Menu de gauche : cliquez sur un module (ex. « Catalogue ») pour afficher ses pages. « Fermer le menu » le réduit pour gagner de la place.',
          'Cloche « Notifications » : alertes non lues (stock faible, rupture…) et lien « Voir les alertes ».',
          'Icône lune / soleil : bascule entre « Thème sombre » et « Thème clair ».',
          'Sélecteur de langue : « Français », « English » ou « Kiswahili ».',
          'Sélecteur de magasin (ex. « Magasin Centre ») : choisit le « Magasin actif ».',
          'Menu du profil : « Mon profil », « Paramètres », « Déconnexion ».',
        ],
      },
      {
        id: 'search',
        title: 'Trouver une page en 2 secondes (Ctrl K)',
        summary: 'La recherche globale ouvre n\'importe quelle page sans passer par le menu.',
        steps: [
          'Appuyez sur Ctrl + K, ou cliquez sur « Recherche » en haut du menu.',
          'Tapez le nom d\'une page ou d\'un module (ex. « inventaire », « shifts »).',
          'Choisissez avec les flèches ↑ ↓ puis validez avec Entrée.',
        ],
      },
      {
        id: 'store',
        title: 'Choisir le magasin actif',
        summary: 'La caisse, le stock, les commandes et la plupart des rapports affichent les données du magasin actif.',
        steps: [
          'Cliquez sur le nom du magasin dans la barre du haut.',
          'Choisissez le magasin dans la liste « Magasin actif ».',
          'Toutes les données de la page sont rechargées pour ce magasin.',
        ],
        warning: 'Si une page affiche « Sélectionnez un magasin actif… », choisissez d\'abord un magasin en haut à droite.',
      },
    ],
  },
  {
    id: 'hotel',
    icon: 'bed',
    title: 'Hôtel',
    intro: 'Réception : chambres, réservations, séjours, folio, ménage et demandes clients. Le menu « Hôtel » n\'apparaît que si le module est actif.',
    topics: [
      {
        id: 'hotel-module',
        title: 'Afficher le menu Hôtel',
        route: '/admin/settings/modules',
        summary: 'Le module « Hôtel » doit être « Actif ». Sinon le menu de gauche ne montre que la caisse.',
        steps: [
          'Ouvrez « Paramètres » → « Modules ».',
          'Sur la carte « Hôtel », basculez l\'interrupteur sur « Actif ».',
          'Le menu « Hôtel » liste alors « Tableau de bord hôtel », « Stock », « Configuration chambres », « Chambres », « Réservations », « Séjours », « Factures clients », « Clients hôtel », « Housekeeping », « Calendrier », « Concierge », « Rapports » et « Configuration ».',
        ],
      },
      {
        id: 'hotel-dashboard',
        title: 'Lire le tableau de bord hôtel',
        route: '/admin/hotel/dashboard',
        summary: 'La journée de la réception : réservations, arrivées, départs et chambres.',
        steps: [
          'Les cartes montrent les « Nouvelles réservations », les « Arrivées », les « Départs » et le « Chiffre d\'affaires », comparés à la semaine précédente.',
          '« Disponibilité des chambres » compte les chambres « Occupées », « Réservées », « Disponibles » et « Pas prêtes ». « Tout voir » ouvre la liste des chambres.',
          '« Nouvelle réservation » ouvre directement le formulaire de réservation.',
          'Le bloc « Tâches » reprend le ménage encore ouvert ; « Tout voir » ouvre « Housekeeping ».',
        ],
      },
      {
        id: 'hotel-structure',
        title: 'Préparer la structure des chambres',
        route: '/admin/hotel/room-config/buildings',
        summary: 'Dans « Configuration chambres », créez les lieux avant les chambres, dans cet ordre.',
        steps: [
          '« Bâtiments » → « Ajouter un bâtiment » (ex. Principal, Annexe), puis « Enregistrer ».',
          '« Ailes / zones » : rattachez chaque aile à un bâtiment. Sans bâtiment, la page indique de le créer d\'abord.',
          '« Étages » : bâtiment, aile éventuelle, « N° étage » et « Libellé » (ex. Rez-de-chaussée).',
          '« Équipements » : nom, catégorie et « Valeur de remplacement ». Cette valeur est facturée au départ si l\'article est manquant ou endommagé.',
          '« Types chambres » → « Nouveau type » : « Type d\'espace » (« Chambre d\'hôtes », « Salle de conférence » ou « Salle de réception »), nom, « Prix de base / nuit », adultes, lits, photos et « Équipements inclus ». Laissez « Actif (réservable si libre) » coché.',
        ],
        tips: ['Le code du type et le code de l\'équipement sont générés à partir du nom. Les photos viennent de la « Galerie » du catalogue.'],
      },
      {
        id: 'hotel-rooms',
        title: 'Créer les chambres',
        route: '/admin/hotel/rooms',
        summary: 'Chaque chambre a un numéro, un type et un emplacement. C\'est elle qui est attribuée au client.',
        steps: [
          'Cliquez sur « Nouvelle chambre ».',
          '« Emplacement dans l\'établissement » : bâtiment, aile (« Tout le bâtiment » si aucune) et étage.',
          'Choisissez « Une chambre » ou « Plage (en masse) » (« Du numéro » / « Au numéro ») pour créer plusieurs chambres d\'un coup.',
          'Choisissez le « Type de chambre » et le « Numéro de chambre ». Le « Nom affiché » peut rester vide : le numéro sera affiché.',
          '« État au moment de la création » : laissez « Propre » pour une chambre neuve. Cochez « Actif (réservable si libre) », puis « Enregistrer ».',
        ],
        tips: ['Un « Prix par nuit (surcharge) » vide reprend le prix du type. Les équipements du type sont déjà inclus ; cochez seulement les suppléments de cette chambre.'],
      },
      {
        id: 'hotel-settings',
        title: 'Régler les horaires, la caution et les taxes',
        route: '/admin/hotel/settings',
        summary: 'Page « Configuration ». Ces valeurs servent aux arrivées, aux départs et au calcul du folio.',
        steps: [
          '« Arrivée et départ » : « Heure d\'arrivée », « Heure de départ », limites et frais d\'arrivée anticipée ou de départ tardif.',
          '« Caution (dépôt de garantie) » : montant demandé à l\'enregistrement.',
          '« Politique d\'annulation » : fenêtre gratuite, pénalité, et « Facturer les no-shows ».',
          '« Taxes et frais » : « TVA », « Taxe de consommation (TC) » et « Prix chambre TVA / TC » (activé = tarif TTC, désactivé = tarif HT).',
          '« Ménage » : cochez « Marquer automatiquement sale au départ » pour que la chambre passe « Sale » après le check-out.',
          'Cliquez sur « Enregistrer ». L\'« Aperçu de la configuration » montre un exemple de nuit.',
        ],
      },
      {
        id: 'hotel-booking',
        title: 'Créer une réservation',
        route: '/admin/hotel/reservations',
        summary: 'On réserve un type de chambre. La chambre physique est attribuée à l\'arrivée.',
        steps: [
          'Cliquez sur « Nouvelle réservation ».',
          '« Client » : « Client existant » (recherche dans Ventes → Clients) ou « Nouveau client » (nom, e-mail, téléphone).',
          '« Dates et type de chambre » : type, « Date d\'arrivée », « Date de départ », adultes, enfants et « Caution » si besoin.',
          'Indiquez le « Canal de réservation » (« Direct », « Téléphone », « Walk-in », « Agence »…) et les « Demandes spéciales ».',
          'Enregistrez. Le statut est calculé automatiquement (« En attente », « Confirmée », « Garantie »…).',
        ],
        tips: [
          'Filtres utiles : « Arrivées du jour », « Aujourd\'hui », « 7 prochains jours », « Actives » ou « Historique ».',
          'Dans le détail : « Notifier le client » envoie le récapitulatif, « Ouvrir le séjour » lance l\'arrivée.',
        ],
      },
      {
        id: 'hotel-checkin',
        title: 'Enregistrer une arrivée (check-in)',
        route: '/admin/hotel/stays',
        summary: 'La chambre passe en occupée et un folio s\'ouvre. Deux cas : client déjà réservé, ou client de passage.',
        steps: [
          'Client réservé : ouvrez la réservation puis « Ouvrir le séjour ».',
          'Client de passage : dans « Séjours », cliquez sur « Arrivée sans réservation ».',
          'Étape « Client » : identité (nationalité, pièce d\'identité). Téléversez le document ou choisissez « Remplir le blanc ».',
          'Étape « Chambre et dates » : « Type de chambre », puis une « Chambre disponible ». Sans chambre libre, la liste reste vide.',
          'Étape « Confirmation » : « Paiement du séjour » — « Encaisser maintenant » (montant reçu) ou « Crédit » (paiement plus tard).',
          'Cliquez sur « Confirmer l\'arrivée », puis « Signer » (le client scanne le QR ou signe à l\'écran). « Passer pour l\'instant » reporte la signature.',
        ],
        warning: 'Le nom, la nationalité, la pièce, le type, une chambre libre, les dates et le motif du séjour sont obligatoires.',
      },
      {
        id: 'hotel-folio',
        title: 'Suivre le séjour et le folio',
        route: '/admin/hotel/stays',
        summary: 'Le folio est la note du client : nuits, taxes, consommations, encaissements et solde.',
        steps: [
          '« Séjours » : onglets « Plan chambres », « Liste des séjours », « Arrivées », « Départs ». Filtrez « En séjour », « Enregistré », « Parti »…',
          'Ouvrez un séjour avec « Voir ». Les onglets sont « Vue d\'ensemble », « Room service », « Journal » et « Folio client ».',
          '« Encaisser » enregistre un règlement sur le folio. « Changer de chambre » attribue une autre chambre libre.',
          '« Exporter hébergement », « Exporter consommation » ou « Exporter fiche d\'enregistrement », puis « Imprimer ».',
        ],
        tips: [
          'À la caisse, « Facturer au séjour » ajoute la vente au folio du client présent.',
          'Au restaurant, « Mettre en chambre » fait la même chose depuis la table.',
        ],
      },
      {
        id: 'hotel-checkout',
        title: 'Enregistrer un départ (check-out)',
        route: '/admin/hotel/stays',
        summary: 'Contrôlez les équipements, puis clôturez. La chambre peut repasser « Sale » selon la configuration.',
        steps: [
          'Ouvrez le séjour et cliquez sur « Départ ».',
          '« Contrôle des équipements » : pour chaque article, « Présent », « Manquant » ou « Endommagé ».',
          'Les articles manquants ou endommagés s\'ajoutent au folio à leur valeur de remplacement. « Frais d\'équipement » montre le total.',
          'Cliquez sur « Confirmer le départ ». Le séjour passe « Parti ».',
        ],
        warning: 'Si « Avertissement solde impayé » est activé dans « Configuration », un folio encore dû déclenche une alerte au départ.',
      },
      {
        id: 'hotel-housekeeping',
        title: 'Housekeeping',
        route: '/admin/hotel/housekeeping',
        summary: 'État des chambres et tâches de ménage.',
        steps: [
          'Onglet « Chambres » : filtrez par « Condition » (« Propre », « Sale », « Nettoyage », « Inspectée », « Maintenance », « Hors service ») et par occupation.',
          'Onglet « Tâches » → « Nouvelle tâche » : chambre, type (« Nettoyage », « Inspection », « Turndown », « Linge », « Maintenance »), priorité et personne assignée.',
          'Faites avancer la tâche avec « Démarrer » puis « Terminer ».',
        ],
      },
      {
        id: 'hotel-calendar',
        title: 'Calendrier',
        route: '/admin/hotel/calendar',
        summary: 'Planning de l\'équipe : formations, réunions, maintenance, ménage. Les séjours y apparaissent aussi.',
        steps: [
          'Cliquez sur « Ajouter un événement » : titre, catégorie, début, fin, notes.',
          'Changez de mois avec « Mois précédent » / « Mois suivant », ou revenez avec « Aujourd\'hui ».',
          'Un événement se déplace ou se prolonge directement sur le calendrier. Un bloc « Séjour » reste lié à la réservation.',
        ],
      },
      {
        id: 'hotel-concierge',
        title: 'Concierge',
        route: '/admin/hotel/concierge',
        summary: 'Demandes des clients pendant le séjour : room service, transport, activité, maintenance, VIP.',
        steps: [
          'Cliquez sur « Nouvelle demande ».',
          '« Lier à un séjour en cours », ou saisissez le client et la chambre à la main.',
          'Choisissez le « Type de service », un « Titre court », la « Priorité » et, si besoin, la date souhaitée.',
          'Assignez à l\'« Interne » ou à un « Fournisseur », puis enregistrez.',
          'Faites avancer la demande : « Prendre en compte », « Mettre en cours », « Marquer terminée » ou « Annuler ».',
        ],
      },
      {
        id: 'hotel-guests',
        title: 'Clients hôtel',
        route: '/admin/hotel/guests',
        summary: 'Annuaire des clients déjà passés à la réception, avec leurs séjours et réservations.',
        steps: [
          'Recherchez par nom, téléphone ou e-mail.',
          'La liste indique le dernier séjour, le nombre de réservations et si le client est « Actif ».',
          '« Nouvelle réservation » repart du client choisi.',
        ],
        tips: ['Les fiches sont les mêmes que dans Ventes → Clients. Un client créé à la caisse peut être repris ici.'],
      },
      {
        id: 'hotel-reports',
        title: 'Rapports hôtel',
        route: '/admin/hotel/reports',
        summary: 'Occupation, revenu et ménage, distincts des rapports de caisse.',
        steps: [
          'Choisissez la « Période » (par défaut « 30 derniers jours »).',
          'Lisez le « Taux d\'occupation », le « RevPAR », le « Revenu total », l\'« ADR » et la « Durée moy. séjour ».',
          '« Disponibilité chambres », « État housekeeping », « Réservations » et « Revenu par type » détaillent la période.',
          '« Exporter » pour sortir le rapport.',
        ],
      },
      {
        id: 'hotel-stock',
        title: 'Stock vu depuis l\'hôtel',
        route: '/admin/hotel/stock',
        summary: 'Le « Tableau de bord stock » de l\'hôtel reprend le stock du magasin : valeur, alertes et mouvements.',
        steps: [
          'Les cartes montrent les produits en stock, la valeur, les alertes de stock bas et les ventes du mois.',
          '« Navigation rapide » ouvre les pages déjà connues : « Produits », « Catégories », « Transferts de stock », « Inventaires », « Sorties de stock », « Fournisseurs », « Entrepôts », « Rapports ».',
        ],
        tips: ['Le stock se saisit dans Inventaire (solde d\'ouverture, réceptions, inventaires). Cette page ne crée pas les quantités.'],
      },
      {
        id: 'hotel-invoices',
        title: 'Factures clients',
        route: '/admin/hotel/stays',
        summary: 'La note du client se lit et s\'encaisse sur le folio du séjour. La page « Factures clients » du menu n\'est pas encore branchée.',
        steps: [
          'Ouvrez « Séjours », puis le séjour, onglet « Folio client ».',
          'Le récapitulatif sépare « Hébergement », « Taxes & frais », « Consommations », « Équipements / frais » et « Règlements ».',
          '« Encaisser » solde tout ou partie. « Exporter hébergement » et « Exporter consommation » sortent les pièces.',
        ],
      },
    ],
  },
  {
    id: 'catalog',
    icon: 'products',
    title: 'Catalogue et produits',
    intro: 'Le catalogue est la liste centrale des articles et services. Un produit doit ensuite être importé dans un magasin pour être vendu.',
    topics: [
      {
        id: 'product-form',
        title: 'Créer un produit',
        route: '/admin/products',
        summary: 'La fiche produit est organisée en onglets : « Général », « Prix », « Galerie photos », « Codes-barres », et selon la structure « Variantes » ou « Composé (Recette) ».',
        steps: [
          'Dans « Produits », choisissez le catalogue puis cliquez sur « Nouveau ».',
          'Onglet « Général » : renseignez le SKU, le « Nom » et la « Description ».',
          'Choisissez la « Nature de l\'article » : « Article quantifiable » (suivi en stock) ou « Service » (non stockable, vendu directement).',
          'Pour un article quantifiable, choisissez la « Structure » : « Simple », « Variante » (taille, couleur), « Lot » ou « Composé (Recette) ».',
          'Cochez au besoin « Suivi par n° de série », « Suivi par lot », « Suivi d\'expiration » (avec « Jours avant expiration ») et « Peut être un accompagnement ».',
          'Choisissez la taxe dans « Taxes ».',
          'Onglet « Prix » : saisissez le « Prix de vente » et le « Prix d\'achat ». « Ajouter un tarif » crée des prix « Détail », « Gros », « VIP », « Distributeur » ou « Prix spécial » avec une « Qté min ».',
          'Onglet « Codes-barres » : « Ajouter un code » ou « Générer », puis « Imprimer » les étiquettes.',
          'Cliquez sur « Enregistrer ». La photo s\'ajoute ensuite dans l\'onglet « Galerie photos ».',
        ],
        tips: [
          'Variantes : saisissez seulement SKU, taille et couleur ; le prix vient de l\'onglet tarification.',
          'Le SKU et le nom sont obligatoires ; en cas d\'échec, vérifiez aussi les tarifs.',
        ],
      },
      {
        id: 'product-import',
        title: 'Importer ou exporter les produits avec Excel',
        route: '/admin/products',
        summary: 'Pour créer ou mettre à jour beaucoup de produits d\'un coup.',
        steps: [
          'Dans « Produits », ouvrez « Exporter (PDF / Excel) » puis « Modèle d\'import (Excel) » pour un fichier vierge, ou « Excel » pour exporter le catalogue actuel.',
          'Remplissez une ligne par produit. Colonnes : SKU, Nom, Description, Code-barres, Type, Prix de vente, Prix d\'achat, Catégorie, Marque, Unité, Taxe, Actif, Suivi par lot, Numéro de série, Suivi péremption, Jours avant péremption, Seuil stock bas, Accompagnements.',
          'Écrivez les prix en monnaie normale (ex. 1500 ou 1 500), les cases à cocher en Oui / Non, et la catégorie, la marque, l\'unité et la taxe par leur nom.',
          'Cliquez sur « Importer (Excel) » et choisissez le fichier.',
          'Le résultat indique les produits créés, mis à jour et ignorés, avec la raison de chaque ligne refusée.',
        ],
        tips: [
          'Le SKU identifie le produit : un SKU existant est mis à jour, un nouveau SKU crée un produit.',
          'Une cellule vide ne modifie rien. Pour changer seulement les prix, gardez les colonnes SKU et Prix de vente.',
        ],
        warning: 'La catégorie, la marque, l\'unité et la taxe doivent déjà exister. Les produits à variantes et les packs se créent depuis le formulaire.',
      },
      {
        id: 'store-assortment',
        title: 'Rendre un produit vendable dans un magasin',
        route: '/admin/stores',
        summary: 'Seuls les produits de l\'assortiment du magasin apparaissent à la caisse. Page « Assortiment magasin » (Ctrl K → « Magasins », ou raccourci « Import magasin » du tableau de bord).',
        steps: [
          'Choisissez le magasin actif en haut à droite.',
          'Colonne « Depuis le catalogue » : recherchez les articles, cochez-les ou « Tout sélectionner ».',
          'Réglez si besoin la « Classification du magasin » (catégories, marques, unités) pour toute la sélection.',
          'Cliquez sur « Importer la sélection ».',
          'Colonne « Dans ce magasin » : « Fiche magasin » permet un « Prix magasin » (vide = prix catalogue) ; « Retirer » enlève l\'article du magasin.',
        ],
      },
      {
        id: 'gallery',
        title: 'Galerie catalogue',
        route: '/admin/catalog/gallery',
        summary: 'Banque d\'images partagée par tous les produits du catalogue.',
        steps: [
          'Glissez-déposez des images sur la zone prévue ou cliquez sur « Choisir des images ».',
          'Pour attacher une image à un produit, déposez-la sur la carte du produit, ou choisissez-la depuis l\'onglet « Galerie photos » de la fiche.',
        ],
      },
      {
        id: 'price-lists',
        title: 'Listes des prix',
        route: '/admin/catalog/prices',
        summary: 'Modifier rapidement les prix détail, gros, VIP et spécial de tous les produits.',
        steps: [
          'Choisissez le catalogue et la « Devise ».',
          'Modifiez les montants directement dans le tableau ; la colonne « Détail (HT / TVA / TTC) » montre le calcul de taxe.',
          'Cliquez sur « Enregistrer ».',
        ],
        tips: ['Les montants saisis dans une autre devise sont convertis avec le taux de change.'],
      },
      {
        id: 'accompaniments',
        title: 'Accompagnements gratuits',
        route: '/admin/accompaniments',
        summary: 'Proposer des articles offerts avec un plat ou un produit (ex. frites, sauce).',
        steps: [
          'Sur la fiche des articles offerts, cochez « Peut être un accompagnement ».',
          'Dans « Accompagnements », associez ces articles aux produits principaux.',
          'À la caisse, la fenêtre « Accompagnements gratuits » s\'ouvre quand on ajoute le produit principal.',
        ],
      },
    ],
  },
  {
    id: 'customers',
    icon: 'customers',
    title: 'Clients, crédit et fidélité',
    intro: 'Fiches clients, ventes à crédit, paiements et points de fidélité.',
    topics: [
      {
        id: 'customer-create',
        title: 'Ajouter un client',
        route: '/admin/customers',
        summary: 'Le « Code client » (ex. CLI-0001) est généré automatiquement.',
        steps: [
          'Dans « Clients », cliquez sur « Ajouter un client ».',
          'Saisissez le « Nom du client » et le « Type de client » : « Particulier » ou « Société » (le NIF est alors obligatoire).',
          'Complétez les contacts (téléphone, e-mail, adresse).',
          'Fixez le « Plafond de crédit » (0 = pas de plafond) et la « Remise (%) » par défaut si besoin.',
          'Cliquez sur « Enregistrer ».',
        ],
        tips: ['Un client peut aussi être créé directement à la caisse avec « Créer un client ».'],
      },
      {
        id: 'customer-credit',
        title: 'Suivre le crédit et encaisser un paiement',
        route: '/admin/customers',
        summary: 'Une vente à crédit augmente le solde du client, un paiement le diminue. L\'historique reste dans l\'onglet « Relevé ».',
        steps: [
          'Ouvrez la fiche du client : « Solde », « Plafond de crédit », « Crédit disponible » et « Points fidélité » sont en haut.',
          'Cliquez sur « Enregistrer un paiement » et saisissez le montant reçu.',
          'Exemple : après une vente de 100 000 à crédit, un paiement de 50 000 ramène le solde à 50 000.',
        ],
      },
      {
        id: 'loyalty',
        title: 'Points de fidélité',
        route: '/admin/customers',
        summary: '1 000 F dépensés = 1 point ; 1 point = 1 F d\'avoir utilisable en caisse.',
        steps: [
          'Les points sont gagnés automatiquement à chaque vente liée au client.',
          'Pour les utiliser, ouvrez l\'onglet « Fidélité » de la fiche, saisissez les « Points à utiliser » puis « Utiliser ».',
        ],
      },
    ],
  },
  {
    id: 'pos',
    icon: 'device-pos',
    title: 'Point de vente (caisse)',
    intro: 'Encaisser les ventes sur place, à emporter ou en livraison, gérer les commandes, les shifts et les réservations.',
    topics: [
      {
        id: 'shift-open',
        title: 'Ouvrir la caisse (shift)',
        route: '/admin/pos/shifts',
        summary: 'Le shift relie les ventes à un caissier et à une caisse, avec un fond de caisse de départ.',
        steps: [
          'Dans « Shifts », cliquez sur « Ouvrir un shift ».',
          'Choisissez la « Caisse », saisissez le « Fond de caisse » (espèces de départ), puis « Enregistrer ».',
          'Depuis la caisse, la fenêtre « Ouvrir la caisse » demande le PIN caissier, la caisse et le fond de caisse.',
        ],
        warning: 'Il faut au moins une caisse active (« Organisation → Caisses »). Clôturez le shift en cours avant d\'en ouvrir un autre.',
      },
      {
        id: 'sale',
        title: 'Faire une vente',
        route: '/admin/pos/terminal',
        summary: 'Ajouter les articles, choisir le mode de commande et le client, puis encaisser.',
        steps: [
          'Recherchez un produit dans « Rechercher des produits… » (touche F2), filtrez par catégorie, ou scannez son code-barres.',
          'Touchez la carte du produit pour l\'ajouter. Selon le produit, choisissez une option, une unité de vente (ex. « Bouteille ») ou des accompagnements.',
          'Ajustez les quantités avec + et −.',
          'Choisissez le « Mode de commande » : « Sur place » (avec une table), « À emporter » ou « Livraison » (client et adresse obligatoires).',
          'Cliquez sur « Client » pour lier la vente à un client (par défaut « Client de passage »).',
          'Ajoutez si besoin une « Remise » (« Pourcentage » ou « Montant fixe ») ou une « Note ».',
          'Cliquez sur « Confirmer » (touche F8) pour ouvrir le « Paiement ».',
        ],
        tips: ['Les articles en rupture affichent « Rupture » ; la quantité disponible est indiquée sur chaque carte.'],
      },
      {
        id: 'payment',
        title: 'Encaisser : espèces, mobile money, carte, crédit, paiement mixte',
        route: '/admin/pos/terminal',
        summary: 'Le ticket s\'imprime et le tiroir-caisse s\'ouvre automatiquement après le paiement.',
        steps: [
          'Mode « Simple » : choisissez « Espèces », « Mobile Money », « Carte », « Banque » ou « Crédit ». En espèces, saisissez le « Montant reçu » : la « Monnaie » à rendre est calculée.',
          'Mode « Mixte » : « Ajouter un mode » pour chaque moyen, « Compléter le reste » pour le dernier. La somme doit égaler le total.',
          '« Crédit » : un client est obligatoire ; le montant s\'ajoute à son solde.',
          'Validez. Les points de fidélité gagnés s\'affichent sur la confirmation.',
        ],
        warning: 'Si la fenêtre indique « Aucun mode de paiement configuré », ajoutez-les dans les paramètres de l\'entreprise (Point of Sale → Modes de paiement caisse POS).',
      },
      {
        id: 'hold',
        title: 'Mettre une vente en attente et la reprendre',
        route: '/admin/pos/terminal',
        summary: 'Utile pour une table qui commande en plusieurs fois ou un client qui revient.',
        steps: [
          'Cliquez sur « Attente » : la vente est gardée (une commande de table retourne au plan de salle).',
          'Cliquez sur « Récup. » pour voir les « Ventes en attente ».',
          'Choisissez « Modifier », « Ajouter articles » ou « Payer ».',
        ],
      },
      {
        id: 'refund',
        title: 'Retour et remboursement',
        route: '/admin/pos/terminal',
        summary: 'Retour total ou partiel d\'une vente ; le remboursement suit la quantité rendue.',
        steps: [
          'Ouvrez « Retour et remboursement » et saisissez la « Référence de la vente à rembourser ».',
          'Choisissez « Remboursement partiel » (quantités par ligne) ou « Tout retourner ».',
          'Choisissez la méthode : « Méthode originale », « Espèces », « Carte », « Banque » ou « Avoir client », puis « Rembourser ».',
        ],
      },
      {
        id: 'orders',
        title: 'Commandes : suivre, modifier, fusionner',
        route: '/admin/pos/orders',
        summary: 'Toutes les ventes et commandes encaissées au point de vente, avec ticket et facture.',
        steps: [
          'Filtrez par période, « Statut », « Paiement » ou client ; « Exporter CSV » exporte la liste.',
          'Commande « Terminée » : réimprimez le « Ticket » ou la « Facture ».',
          'Commande « En attente » : « Modifier » (rouvre la caisse), « Payer » ou « Fusionner ».',
          'Fusion : choisissez l\'autre commande en attente, vérifiez « Commande finale » et « Table finale », puis « Confirmer la fusion ».',
        ],
        warning: 'Si les deux commandes ont des clients différents, choisissez le client à conserver et cochez la confirmation.',
      },
      {
        id: 'shift-close',
        title: 'Clôturer le shift et contrôler la caisse',
        route: '/admin/pos/shifts',
        summary: 'Le système calcule les « Espèces attendues » ; vous saisissez les « Espèces comptées ».',
        steps: [
          'Cliquez sur « Clôturer le shift ».',
          'Comptez le tiroir et saisissez les « Espèces comptées ».',
          'En cas d\'écart, la « Justification de la différence » est obligatoire.',
          '« Détails » sur la carte du shift affiche le rapprochement complet : fond de caisse, ventes, remboursements, entrées, sorties, dépenses et écart.',
        ],
      },
      {
        id: 'reservations',
        title: 'Réservations de tables',
        route: '/admin/pos/reservations',
        summary: 'Planifier l\'arrivée des clients avant l\'encaissement.',
        steps: [
          'Cliquez sur « Nouvelle réservation » : client, « Date et heure », « Couverts », « Table ».',
          'Le jour venu : « Confirmer », puis « Installer » le client à une table.',
          'Encaissez depuis le plan de salle (« Ouvrir le plan de salle »), puis « Terminer ». « Absent » ou « Annuler » si le client ne vient pas.',
        ],
      },
      {
        id: 'qr',
        title: 'Commandes par QR code aux tables',
        route: '/admin/pos/qr-codes',
        summary: 'Les clients scannent le QR de leur table et commandent depuis leur téléphone.',
        steps: [
          'Dans « QR des tables », cliquez sur « Générer » pour chaque table, puis « Imprimer » ou « Télécharger ».',
          'Dans « Commandes QR », choisissez l\'« Approbation » : « Manuelle » (validation par le personnel) ou « Automatique ».',
          'Traitez les commandes « En attente » : « Approuver », « Tout approuver », « Modifier » ou « Refuser » (avec un motif).',
        ],
        tips: ['« Régénérer » rend l\'ancien QR inutilisable (ex. QR volé ou abîmé).'],
      },
    ],
  },
  {
    id: 'inventory',
    icon: 'inventory',
    title: 'Inventaire et stock',
    intro: 'Le stock ne se modifie jamais directement : chaque vente, réception, transfert ou correction crée un mouvement traçable.',
    topics: [
      {
        id: 'validation',
        title: 'Le principe de la double validation',
        summary: 'Approvisionnements, transferts, sorties et ajustements suivent les mêmes étapes, pour éviter les erreurs.',
        steps: [
          '« Enregistrer la saisie » : le document est en « Saisie », le stock ne change pas.',
          '« Confirmer » : le document est « Confirmé », le stock ne change toujours pas.',
          '« Approuver » : le mouvement est « Confirmé et appliqué », le stock est mis à jour.',
        ],
        tips: ['Séparez les rôles : une personne saisit, un responsable approuve.'],
      },
      {
        id: 'stock',
        title: 'Consulter le stock et l\'historique d\'un produit',
        route: '/admin/inventory/stock',
        summary: 'Quantités par produit, statut (« Rupture », stock faible) et historique des mouvements.',
        steps: [
          'Ouvrez « Inventaire → Produits ».',
          'Cliquez sur « Historique » d\'un produit et filtrez « Du » / « Au » : chaque ligne montre le type de mouvement (Achat, Vente, Transfert, Perte…), la quantité et le stock résultant.',
        ],
      },
      {
        id: 'opening',
        title: 'Saisir le stock initial (solde d\'ouverture)',
        route: '/admin/inventory/counts',
        summary: 'À faire une seule fois par article et par entrepôt, au démarrage.',
        steps: [
          'Dans « Inventaires », cliquez sur « Créer un solde d\'ouverture ».',
          'Choisissez l\'« Entrepôt » et la « Date du solde d\'ouverture ».',
          'Ajoutez chaque article avec sa « Quantité initiale » et son « Prix d\'achat unitaire ».',
          'Cliquez sur « Valider l\'ouverture ».',
        ],
        warning: 'Ensuite, toute correction passe par un ajustement ou un inventaire.',
      },
      {
        id: 'count',
        title: 'Faire un inventaire physique',
        route: '/admin/inventory/counts',
        summary: 'Comparer le stock système au stock réellement compté ; les écarts deviennent des ajustements.',
        steps: [
          'Cliquez sur « Nouvel inventaire complet » : entrepôt, date, responsable. Cochez si besoin « Bloquer ventes, achats et transferts pendant le comptage ». Puis « Lancer le comptage ».',
          'Scannez ou recherchez chaque article et saisissez le « Comptage physique ». Indiquez la « Raison de l\'écart » si besoin.',
          'Suivez les compteurs « Comptés », « Manquants », « Excédents », « Différence nette ».',
          'Faites avancer : « Terminer le comptage », « Vérifier », « Approuver », puis « Valider l\'inventaire ».',
        ],
        tips: [
          '« Comptage cyclique » : comptez une partie du stock à tour de rôle (classes ABC) sans bloquer les ventes.',
          '« Vérification ponctuelle » : contrôle rapide de quelques produits.',
        ],
      },
      {
        id: 'supplies',
        title: 'Approvisionnement direct',
        route: '/admin/inventory/supplies',
        summary: 'Faire entrer de la marchandise sans passer par le cycle d\'achat complet.',
        steps: [
          'Cliquez sur « Nouvel approvisionnement », ajoutez les lignes. Le prix d\'achat reprend celui du stock ; s\'il change, le coût moyen pondéré s\'applique à la mise en stock.',
          'Confirmez, approuvez, puis « Mettre en stock ».',
        ],
        tips: ['Le fournisseur est facultatif : sans fournisseur, le stock augmente quand même.'],
      },
      {
        id: 'transfers',
        title: 'Transférer du stock entre entrepôts',
        route: '/admin/inventory/transfers',
        summary: 'Magasin A → demande → validation → expédition → réception → magasin B.',
        steps: [
          'Cliquez sur « Nouveau transfert », choisissez source et destination, ajoutez les lignes, puis « Enregistrer la saisie ».',
          '« Demander » puis « Valider » : le stock ne bouge pas encore.',
          '« Expédier » : le stock de la source diminue, le transfert est en transport.',
          '« Réceptionner » : le stock de la destination augmente.',
        ],
        warning: 'Il faut deux entrepôts différents.',
      },
      {
        id: 'issues',
        title: 'Sorties, pertes et ajustements',
        route: '/admin/inventory/issues',
        summary: 'Retirer du stock (perte, casse, périmé) ou corriger un écart.',
        steps: [
          '« Sorties de stock » → « Nouvelle sortie » : entrepôt, « Type de mouvement » (« Perte », « Dommage », « Périmé », « Sortie ajustement »), motif et lignes.',
          '« Mouvements de stock » → « Nouvel ajustement » pour une entrée ou une sortie de correction.',
          'Validez avec « Enregistrer la saisie », « Confirmer », puis « Approuver ».',
        ],
      },
      {
        id: 'references',
        title: 'Référentiels : entrepôts, fournisseurs, catégories, marques, unités, taxes',
        route: '/admin/catalog/categories',
        summary: 'Les listes de base utilisées par les produits, les achats et le stock.',
        steps: [
          'Chaque page a un bouton « Ajouter… » et, sur chaque ligne, « Modifier » et « Supprimer ».',
          'Catégories, marques et unités sont propres à chaque magasin : cochez au moins un magasin.',
          'Taxes : « Ajouter une taxe » avec nom (ex. TVA 18%), code, taux et « Nature fiscale ». Cochez « Prix TTC (Inclus) » si le prix affiché contient déjà la taxe.',
        ],
        tips: ['Seules les taxes actives peuvent être affectées aux produits.'],
      },
    ],
  },
  {
    id: 'purchases',
    icon: 'purchases',
    title: 'Achats et fournisseurs',
    intro: 'Le cycle complet : réquisition → proforma → bon de commande → réception (le stock augmente) → facture → paiement.',
    topics: [
      {
        id: 'requisitions',
        title: 'Demander un achat (réquisition)',
        route: '/admin/purchases/requisitions',
        summary: 'Une demande interne qui doit être approuvée. Elle n\'ajoute pas de stock.',
        steps: [
          'Cliquez sur « Nouvelle réquisition » : « Entrepôt », « Priorité », « Date souhaitée », « Motif » et lignes de produits.',
          '« Soumettre », puis un responsable clique sur « Approuver » ou « Rejeter ».',
          'Une réquisition approuvée se convertit : « Convertir en approvisionnement » ou « Convertir en proforma » (fournisseur obligatoire).',
        ],
      },
      {
        id: 'proformas',
        title: 'Comparer les devis (proformas)',
        route: '/admin/purchases/proformas',
        summary: 'Enregistrer les devis fournisseurs et choisir le meilleur.',
        steps: [
          '« Nouvelle proforma » : fournisseur, « Expiration », conditions de paiement et de livraison, lignes.',
          '« Envoyer », « Examiner », puis « Approuver » ou « Rejeter ».',
          'Une proforma approuvée se convertit en approvisionnement.',
        ],
      },
      {
        id: 'orders',
        title: 'Commander et réceptionner la marchandise',
        route: '/admin/purchases/orders',
        summary: 'La réception est l\'étape qui augmente le stock et crée la facture fournisseur.',
        steps: [
          '« Nouvelle commande » : entrepôt, fournisseur et lignes, puis « Enregistrer la saisie ».',
          'Sur le détail : « Soumettre » puis « Approuver ».',
          'À l\'arrivée des marchandises, saisissez les quantités dans la colonne « Réceptionner » puis cliquez sur « Réceptionner ». Une réception partielle est possible.',
          'La section « Réceptions » confirme l\'entrée en stock et la facture créée.',
        ],
        warning: 'Une commande sans fournisseur ne peut pas être réceptionnée.',
      },
      {
        id: 'payments',
        title: 'Payer les factures fournisseurs',
        route: '/admin/purchases/payments',
        summary: 'Les paiements mettent à jour le « Reste à payer » de chaque facture.',
        steps: [
          'Ouvrez « Factures fournisseurs » ou « Paiements fournisseurs ».',
          'Cliquez sur « Payer » : montant, « Mode de paiement » et « Référence », puis validez.',
          'La facture passe en « Partiellement payée » ou « Payée ».',
        ],
        tips: ['L\'« Aperçu » des achats affiche le « Montant restant à payer » et les meilleurs fournisseurs.'],
      },
      {
        id: 'suppliers',
        title: 'Fiches fournisseurs',
        route: '/admin/suppliers',
        summary: 'Contacts et « Solde dû » de chaque fournisseur.',
        steps: ['Cliquez sur « Ajouter un fournisseur », renseignez contact, téléphone et adresse, puis enregistrez.'],
      },
    ],
  },
  {
    id: 'expenses',
    icon: 'coins',
    title: 'Dépenses',
    intro: 'Enregistrer les dépenses (loyer, transport, fournitures…) et les analyser.',
    topics: [
      {
        id: 'expense-create',
        title: 'Enregistrer une dépense',
        route: '/admin/expenses',
        summary: 'Une dépense est liée à une succursale, et éventuellement à une session de caisse.',
        steps: [
          'Cliquez sur « Nouvelle dépense ».',
          'Choisissez la « Succursale », la « Catégorie » et la « Session de caisse » (« Hors caisse » si payée hors tiroir).',
          'Saisissez le « Libellé » et le « Montant », puis « Enregistrer ».',
        ],
        tips: ['Une dépense payée depuis la caisse apparaît dans le rapprochement du shift.'],
      },
      {
        id: 'expense-categories',
        title: 'Catégories et rapports de dépenses',
        route: '/admin/expenses/reports',
        summary: 'Classer les dépenses puis les analyser par mois, année, catégorie ou caisse.',
        steps: [
          '« Catégories » → « Nouvelle catégorie » : couleur, nom (ex. Administratives, Logistiques) et description.',
          '« Rapports » : choisissez la « Période » puis la vue « Mensuel », « Annuel », « Par catégorie » ou « Par caisse ».',
          '« Exporter en PDF » pour imprimer.',
        ],
      },
    ],
  },
  {
    id: 'reports',
    icon: 'dashboard',
    title: 'Rapports',
    intro: 'Suivre l\'activité : ventes, stock, achats, recettes, performance des équipes.',
    topics: [
      {
        id: 'reports-common',
        title: 'Utiliser un rapport',
        route: '/admin/reports/dashboard',
        summary: 'Tous les rapports fonctionnent de la même façon.',
        steps: [
          'Choisissez la période (« Du » / « Au ») et, si proposé, le magasin, puis « Appliquer ».',
          'Parcourez les onglets du rapport (ex. « Vue d\'ensemble », « Produits », « Clients »).',
          '« Exporter PDF » ouvre l\'impression ; « Exporter Excel » télécharge le fichier.',
        ],
      },
      {
        id: 'reports-list',
        title: 'Quel rapport pour quelle question ?',
        route: '/admin/reports/dashboard',
        summary: 'Le « Tableau de bord des rapports » résume tout et donne accès aux autres via « Explorer les Rapports ».',
        steps: [
          'Combien ai-je vendu ? « Rapports de Ventes » (tendances, produits, clients).',
          'Qu\'est-ce que j\'ai encaissé aujourd\'hui ? « Rapport Journalier » (calendrier, cliquez sur un jour).',
          'Par mode de paiement ? « Rapport Condensé ».',
          'Quels produits sont sortis ? « Rapport de Recette ».',
          'Mon stock est-il sain ? « Rapports d\'Inventaire » et « Stock par Boutique » (alertes, rotation, recommandations).',
          'Combien ai-je acheté ? « Rapports d\'Achat ».',
          'Suis-je rentable ? « Rapports Financiers » (chiffre d\'affaires, marge, dépenses, bénéfice).',
          'Qui vend le plus ? « Performance Utilisateur » (attribué au serveur qui a pris la commande).',
          'Et demain ? « Prévisions » (au moins 2 mois de données).',
        ],
      },
    ],
  },
  {
    id: 'restaurant',
    icon: 'restaurant',
    title: 'Restaurant',
    intro: 'Plan de salle, commandes de table et écran cuisine (module « Restaurant »).',
    topics: [
      {
        id: 'tables',
        title: 'Créer les zones et les tables',
        route: '/admin/hospitality',
        summary: 'Le plan de salle sert à la caisse, sur le web, Android et Windows.',
        steps: [
          'Onglet « Tables » : « Ajouter une zone » (ex. Terrasse), puis « Ajouter une table » avec nom, places, zone et forme.',
          'Une table occupée ne peut pas être supprimée.',
        ],
      },
      {
        id: 'kitchen',
        title: 'Envoyer en cuisine et servir',
        route: '/admin/hospitality',
        summary: 'Les plats passent par les colonnes « Nouveau », « En préparation », « Prêt ».',
        steps: [
          'Sur la commande d\'une table : « Ajouter » les articles (« Entrée », « Plat », « Dessert »), puis « Envoyer en cuisine ».',
          'Onglet « Cuisine » : faites avancer chaque ticket « En préparation », « Prêt », puis « Servi ».',
          'Terminez avec « Encaisser », ou « Mettre en chambre » pour un client de l\'hôtel.',
        ],
      },
    ],
  },
  {
    id: 'devices',
    icon: 'device-tablet',
    title: 'Appareils et synchronisation',
    intro: 'Relier les caisses Android et Windows, les imprimantes et les tablettes, et suivre la synchronisation hors ligne.',
    topics: [
      {
        id: 'device-add',
        title: 'Ajouter et lier un appareil',
        route: '/admin/organization/devices',
        summary: 'Chaque appareil reçoit un jeton unique à saisir dans l\'application Android ou Windows.',
        steps: [
          'Choisissez le magasin, puis cliquez sur « Ajouter un appareil ».',
          'Choisissez la « Catégorie d\'appareil » (« Terminal de vente », « Imprimante »…), le nom, la connexion et les entrepôts.',
          'Choisissez le « Type » : « Master » (poste principal du magasin), « Esclave » ou « Autonome », puis « Enregistrer ».',
          'Ouvrez « Modifier » : dans « Jeton de synchronisation », cliquez sur « Afficher » puis « Copier ».',
          'Saisissez ce jeton dans l\'application sur l\'appareil. L\'« Enregistrement » passe de « En attente » à « Lié ».',
        ],
        warning: 'Appareil perdu ou volé : cliquez sur « Révoquer », il ne pourra plus se connecter.',
      },
      {
        id: 'sync',
        title: 'Travailler hors ligne',
        route: '/admin/sync',
        summary: 'Les caisses continuent de vendre sans internet ; les ventes partent au serveur au retour de la connexion.',
        steps: [
          'Sans connexion, les ventes sont gardées sur l\'appareil (file d\'attente).',
          'Au retour du réseau, elles sont envoyées automatiquement au serveur.',
          'La page « Synchronisation » (Ctrl K → « Synchronisation ») montre la « Dernière synchro » de chaque terminal et la « File hors ligne ».',
          'En cas de « Conflit », choisissez « Garder la copie locale », « Garder le serveur » ou « Réessayer ».',
        ],
      },
      {
        id: 'app-versions',
        title: 'Installer l\'application caisse',
        route: '/admin/settings/app-versions',
        summary: '« Versions de l\'application » liste les versions Android et Windows disponibles.',
        steps: ['Ouvrez la version souhaitée avec « Voir » pour télécharger le fichier d\'installation.'],
      },
    ],
  },
  {
    id: 'admin',
    icon: 'account',
    title: 'Administration et paramètres',
    intro: 'Utilisateurs, droits, magasins, entreprise, modules et abonnement. Réservé aux administrateurs.',
    topics: [
      {
        id: 'users',
        title: 'Utilisateurs, rôles et PIN',
        route: '/admin/organization/users',
        summary: 'Chaque utilisateur a des rôles (ce qu\'il peut faire) et des magasins (où il peut le faire).',
        steps: [
          'Cliquez sur « Ajouter un utilisateur » : nom, e-mail, téléphone, mot de passe.',
          'Le « PIN » (4 à 6 chiffres, unique) sert à ouvrir la caisse ; « Générer » en crée un.',
          'Choisissez les « Rôles » et « Affecter les magasins » (aucun magasin coché = accès à tous).',
          'Sur la carte : « Réinitialiser le mot de passe », « Révoquer les sessions », « Désactiver ».',
        ],
        tips: ['Les droits de chaque rôle se règlent dans « Rôles » : « Créer », « Lire », « Modifier », « Supprimer » par module.'],
      },
      {
        id: 'company',
        title: 'Entreprise, devises et modes de paiement',
        route: '/admin/organization/currencies',
        summary: 'Les réglages communs à tous les magasins.',
        steps: [
          '« Devise de l\'application » : la devise de tous les montants. « Ajouter une devise » et « Taux de change » pour les autres devises.',
          'Point of Sale → « Modes de paiement caisse POS » : seuls les modes actifs et cochés « Disponible POS » apparaissent à la caisse.',
          '« Pied de page ticket » : le texte imprimé en bas des tickets.',
          'Branding : logo de l\'application et logo des factures (JPG, PNG ou SVG, 2 Mo max).',
        ],
      },
      {
        id: 'stores',
        title: 'Magasins et caisses',
        route: '/admin/organization/stores',
        summary: 'Un magasin = un point de vente ; une caisse = un tiroir-caisse dans ce magasin.',
        steps: [
          '« Ajouter un magasin » : nom, code, « Actif », « Magasin principal » (un seul possible).',
          'Créez ensuite les caisses dans « Organisation → Caisses » : elles sont nécessaires pour ouvrir un shift.',
        ],
      },
      {
        id: 'modules',
        title: 'Activer ou désactiver un module',
        route: '/admin/settings/modules',
        summary: 'N\'affichez que ce dont vous avez besoin (Hôtel, Restaurant, CRM, Comptabilité…).',
        steps: [
          'Basculez l\'interrupteur de la carte du module (« Actif » / « Inactif »).',
          'Un module actif peut avoir des « Réglages » à enregistrer.',
        ],
        warning: 'Au moins un module doit rester actif.',
      },
      {
        id: 'subscription',
        title: 'Abonnement',
        route: '/admin/settings/subscription',
        summary: 'Formule en cours, factures et changement de formule.',
        steps: [
          'Consultez l\'« Abonnement en cours » et son statut.',
          'Pour évoluer : « Passer à cette formule » dans « Formules disponibles ».',
          'Pour une facture ouverte : « Déclarer un paiement » avec la référence.',
        ],
        warning: 'Seule une montée de formule est possible. Un abonnement suspendu bloque les autres écrans jusqu\'au paiement.',
      },
      {
        id: 'notifications',
        title: 'Notifications',
        route: '/admin/notifications',
        summary: 'Choisir quels événements préviennent qui, et par quel canal.',
        steps: [
          'Onglet « Événements » : les alertes à envoyer.',
          'Onglet « Canaux » : Application, E-mail, SMS, WhatsApp, notification push ; « Envoyer un essai » pour tester.',
          '« Tout marquer comme lu » vide la cloche.',
        ],
      },
    ],
  },
  {
    id: 'online',
    icon: 'sales',
    title: 'Commandes en ligne et QR marchand',
    intro: 'Recevoir les commandes de l\'application client et publier des QR codes (menus, paiement, profil).',
    topics: [
      {
        id: 'external-orders',
        title: 'Commandes de l\'application externe',
        route: '/admin/settings/orders',
        summary: 'Valider, préparer et livrer les commandes passées depuis l\'application client.',
        steps: [
          'Filtrez par type : « Livraison », « Sur place », « À emporter ».',
          'Faites avancer chaque commande : « Validée », « En préparation », « En livraison », « Livrée ».',
          '« Analyses App Externe » montre le chiffre, le panier moyen et les tendances sur 7, 30 ou 90 jours.',
        ],
      },
      {
        id: 'merchant-qr',
        title: 'Créer un QR marchand',
        route: '/admin/settings/merchant-qr',
        summary: 'QR de table, menu PDF, lien de menu, paiement ou profil de la société.',
        steps: [
          'Cliquez sur « Créer » et choisissez le « Type de QR ».',
          'Remplissez le formulaire et enregistrez : l\'aperçu imprimable s\'affiche.',
          '« Télécharger » (PNG / PDF) ou « Copier l\'URL ».',
        ],
        tips: ['Les QR de table, de menu PDF et de lien s\'ouvrent dans un navigateur ; les autres demandent l\'application mobile.'],
      },
    ],
  },
  {
    id: 'troubleshooting',
    icon: 'search',
    title: 'Problèmes fréquents',
    intro: 'Les blocages les plus courants et leur solution.',
    topics: [
      {
        id: 'product-missing',
        title: 'Un produit n\'apparaît pas à la caisse',
        route: '/admin/stores',
        summary: 'Il est dans le catalogue mais pas dans l\'assortiment du magasin, ou il est inactif.',
        steps: ['Importez-le dans le magasin (« Assortiment magasin » → « Importer la sélection ») et vérifiez qu\'il est « Actif ».'],
      },
      {
        id: 'out-of-stock',
        title: 'Un produit est en « Rupture » alors qu\'il est en rayon',
        route: '/admin/inventory/counts',
        summary: 'Le stock n\'a pas été saisi ou la réception n\'a pas été validée.',
        steps: [
          'Stock de départ : « Créer un solde d\'ouverture ».',
          'Achat : vérifiez que la commande est « Réceptionnée » et l\'approvisionnement « Confirmé et appliqué ».',
          'Écart réel : faites un inventaire ou un ajustement.',
        ],
      },
      {
        id: 'no-shift',
        title: 'Impossible d\'ouvrir un shift',
        route: '/admin/organization/registers',
        summary: 'Aucune caisse active, ou un shift est déjà ouvert sur toutes les caisses.',
        steps: ['Créez une caisse dans « Organisation → Caisses », ou clôturez le shift en cours.'],
      },
      {
        id: 'no-payment',
        title: '« Aucun mode de paiement configuré »',
        route: '/admin/organization/currencies',
        summary: 'Aucun mode de paiement n\'est actif pour la caisse.',
        steps: ['Paramètres de l\'entreprise → Point of Sale → « Modes de paiement caisse POS » : activez et cochez « Disponible POS ».'],
      },
      {
        id: 'cash-gap',
        title: 'Écart de caisse à la clôture',
        route: '/admin/pos/shifts',
        summary: 'Les espèces comptées ne correspondent pas aux espèces attendues.',
        steps: [
          'Ouvrez « Détails » du shift et vérifiez les remboursements, entrées, sorties et dépenses payées en caisse.',
          'Vérifiez les paiements mixtes et les ventes à crédit enregistrées par erreur en espèces.',
          'Saisissez la justification : elle reste visible dans l\'historique.',
        ],
      },
      {
        id: 'device-offline',
        title: 'Une caisse ne synchronise plus',
        route: '/admin/sync',
        summary: 'Connexion perdue, jeton révoqué ou conflit en attente.',
        steps: [
          'Vérifiez la connexion internet de l\'appareil.',
          'Dans « Appareils », vérifiez que l\'appareil est « Lié » et non révoqué.',
          'Dans « Synchronisation », traitez les éléments en « Conflit » ou « Échec ».',
        ],
      },
      {
        id: 'hotel-hidden',
        title: 'Le menu « Hôtel » n\'apparaît pas',
        route: '/admin/settings/modules',
        summary: 'Le module Hôtel est inactif, ou le rôle de l\'utilisateur ne le voit pas.',
        steps: [
          '« Paramètres » → « Modules » : la carte « Hôtel » doit être « Actif ».',
          'Dans « Rôles », vérifiez que le rôle a le droit « Lire » sur le module hôtel.',
        ],
      },
      {
        id: 'no-vacant-room',
        title: '« Aucune chambre libre » à l\'arrivée',
        route: '/admin/hotel/rooms',
        summary: 'Aucune chambre active du type choisi n\'est libre et propre.',
        steps: [
          'Vérifiez dans « Chambres » que des chambres existent, sont « Actif » et ne sont pas déjà occupées.',
          'Dans « Housekeeping », une chambre « Sale », « Maintenance » ou « Hors service » ne se propose pas. Passez-la « Propre » quand elle est prête.',
        ],
      },
    ],
  },
]
