import { computed, ref } from 'vue'

export type Locale = 'fr' | 'en' | 'sw'

/** Shared with the admin app (`frontend`) so language stays global. */
export const LOCALE_STORAGE_KEY = 'pos_locale'
const LEGACY_STORAGE_KEY = 'itara_website_locale'

type Dict = {
  nav: Record<string, string>
  actions: Record<string, string>
  footer: Record<string, string>
  state: Record<string, string>
  hero: Record<string, string>
  stats: { icon: string; label: string; hint: string }[]
  suite: {
    eyebrow: string
    title: string
    lede: string
    copyTitle: string
    copyBody: string
    items: string[]
    cta: string
  }
  modules: {
    eyebrow: string
    title: string
    lede: string
    items: { icon: string; title: string; text: string; items: string[] }[]
  }
  why: {
    eyebrow: string
    title: string
    lede: string
    items: { icon: string; title: string; text: string }[]
  }
  pricing: {
    eyebrow: string
    title: string
    lede: string
    perMonth: string
    popular: string
    trial: string
    plans: { name: string; lede: string; price: string; note: string; featured: boolean; features: string[] }[]
  }
  apps: {
    eyebrow: string
    title: string
    lede: string
    posLabel: string
    posTitle: string
    posText: string
    posItems: string[]
    posWin: string
    posAndroid: string
    adminLabel: string
    adminTitle: string
    adminText: string
    adminItems: string[]
    adminCta: string
  }
  contact: Record<string, string>
  eco: {
    modesLabel: string
    master: string
    slave: string
    standalone: string
    masterBlurb: string
    slaveBlurb: string
    standaloneBlurb: string
    backoffice: string
    cloudAdmin: string
    masterHub: string
    syncLocal: string
    posSlave: string
    windowsLan: string
    androidLan: string
    stockCatalog: string
    viaMaster: string
    masterShort: string
    lanWifi: string
    salesPay: string
    slaveNote: string
    sharedStock: string
    realtimeCatalog: string
    offlineQueue: string
    syncWhenBack: string
    cloudDirect: string
    posStandalone: string
    winOrAndroid: string
    noMaster: string
    localStock: string
    catalog: string
  }
  preview: { checkout: string }
}

const fr: Dict = {
  nav: {
    home: 'Accueil',
    suite: 'Suite',
    modules: 'Modules',
    why: 'Pourquoi nous',
    pricing: 'Tarifs',
    apps: 'Apps',
    contact: 'Contact',
  },
  actions: {
    getStarted: 'Commencer',
    login: 'Connexion',
    register: 'Inscription',
    themeLight: 'Mode clair',
    themeDark: 'Mode sombre',
    language: 'Langue',
  },
  footer: {
    quickLinks: 'Liens rapides',
    contact: 'Contact',
    admin: 'Espace admin',
    rights: 'Tous droits réservés.',
    blurb: 'Caisse, stock et back-office unifiés pour votre enseigne.',
  },
  state: {
    loading: 'Chargement…',
    notFound: 'Marque introuvable',
  },
  hero: {
    badgeSuffix: 'Business Suite',
    tagline: 'Une plateforme. Des possibilités illimitées.',
    lede: 'Point de vente, stock, organisation et pilotage — une suite métier pour chaque enseigne.',
    cta: 'Commencer',
    modules: 'Nos modules',
  },
  stats: [
    { icon: 'DEV', label: 'Windows & Android', hint: 'Terminal de caisse' },
    { icon: 'WEB', label: 'Back-office web', hint: 'Administration' },
    { icon: 'SYNC', label: 'Sync locale', hint: 'Master · terminaux' },
  ],
  suite: {
    eyebrow: 'Business Suite',
    title: 'Suite métier tout-en-un',
    lede: 'Une plateforme pour vendre en magasin, synchroniser le stock et piloter l’enseigne — du terminal Flutter au back-office Vue.',
    copyTitle: 'Conçue comme votre back-office',
    copyBody: '{product} relie caisse, catalogue, stocks et organisation sur le même tenant. Activez les modules dont vous avez besoin et gardez la marque de votre enseigne partout.',
    items: [
      'Encaissement offline-ready avec sync Master',
      'Catalogue et stocks partagés par magasin',
      'Administration web, thèmes et multi-appareils',
    ],
    cta: 'Ouvrir l’espace admin',
  },
  modules: {
    eyebrow: 'Nos modules',
    title: 'Modules métier prêts à activer',
    lede: 'Six briques pour couvrir la caisse, le stock et le pilotage — alignées sur le back-office.',
    items: [
      {
        icon: 'POS',
        title: 'Point de vente',
        text: 'Encaissement complet pour retail, restaurant et hospitalité.',
        items: ['Panier & paiements', 'Tables & shifts', 'Tickets & cuisine', 'Multi-magasin'],
      },
      {
        icon: 'INV',
        title: 'Inventaire',
        text: 'Suivi de stock en temps réel, alertes et inventaires.',
        items: ['Mouvements', 'Transferts', 'Codes-barres', 'Alertes stock'],
      },
      {
        icon: 'CAT',
        title: 'Catalogue',
        text: 'Produits, variantes, taxes et listes de prix par magasin.',
        items: ['Variantes', 'Taxes', 'Images', 'Tarifs'],
      },
      {
        icon: 'ORG',
        title: 'Organisation',
        text: 'Magasins, rôles, caisses et appareils appairés.',
        items: ['Rôles & droits', 'Caisses', 'Appareils', 'Multi-tenant'],
      },
      {
        icon: 'HOT',
        title: 'Hospitalité',
        text: 'Tables, cuisine, réservations et service en salle.',
        items: ['Plan de salle', 'Cuisine', 'Commandes', 'Serveurs'],
      },
      {
        icon: 'RPT',
        title: 'Reporting',
        text: 'Pilotage, dépenses, achats et vision business.',
        items: ['Ventes', 'Achats', 'Dépenses', 'Exports'],
      },
    ],
  },
  why: {
    eyebrow: 'Pourquoi nous',
    title: 'Pensé pour le commerce moderne',
    lede: 'Des fondations enterprise pour scaler sans perdre la simplicité terrain.',
    items: [
      { icon: 'CL', title: 'Cloud & local', text: 'Back-office cloud et caisse locale — sync Master / terminaux.' },
      { icon: 'RT', title: 'Temps réel', text: 'Stock, ventes et appareils synchronisés dès que le réseau revient.' },
      { icon: 'SEC', title: 'Sécurité caisse', text: 'PIN, verrouillage session et rôles isolés par terminal.' },
      { icon: 'AN', title: 'Analytique', text: 'Rapports clairs pour piloter chaque magasin et l’enseigne.' },
      { icon: 'MOD', title: 'Modules métiers', text: 'Activez retail, restaurant ou hospitalité selon votre activité.' },
      { icon: 'SUP', title: 'Support', text: 'Accompagnement pour le déploiement, la marque et les appareils.' },
    ],
  },
  pricing: {
    eyebrow: 'Tarifs',
    title: 'Tarification simple et transparente',
    lede: 'Choisissez l’offre adaptée. Tous les plans incluent un essai de 14 jours.',
    perMonth: '/mois',
    popular: 'Le plus choisi',
    trial: 'Essai gratuit',
    plans: [
      {
        name: 'Starter',
        lede: 'Parfait pour démarrer',
        price: '4',
        note: 'ou facturé à l’année',
        featured: false,
        features: ['5 utilisateurs', '3 appareils', '2 magasins', '1 000 produits', '2 modules', 'Support email'],
      },
      {
        name: 'Professional',
        lede: 'Le plus choisi',
        price: '8',
        note: 'ou facturé à l’année',
        featured: true,
        features: ['25 utilisateurs', '10 appareils', '10 magasins', '10 000 produits', 'Modules métier', 'Support prioritaire'],
      },
      {
        name: 'Enterprise',
        lede: 'Pour les grandes enseignes',
        price: '17',
        note: 'ou facturé à l’année',
        featured: false,
        features: ['Utilisateurs illimités', 'Appareils illimités', 'Magasins illimités', 'Tous les modules', 'Stockage illimité', 'Support 24/7'],
      },
    ],
  },
  apps: {
    eyebrow: 'Nos apps',
    title: 'Télécharger les apps {product}',
    lede: 'Le terminal POS tourne sur Windows et Android. Le back-office web pilote catalogue, stocks et organisation.',
    posLabel: 'Point de vente professionnel',
    posTitle: '{product} POS',
    posText: 'Caisse all-in-one pour retail, restaurant et hospitalité — commandes, tables, stock et multi-magasin.',
    posItems: [
      'Commandes & affichage cuisine',
      'Tables, shifts & paiements',
      'Sync stock en temps réel',
      'Windows & Android',
    ],
    posWin: 'Demander le build Windows',
    posAndroid: 'Version Android',
    adminLabel: 'Back-office web',
    adminTitle: '{product} Admin',
    adminText: 'Administration cloud : catalogue, stocks, magasins, rôles, rapports et marque marketing.',
    adminItems: [
      'Catalogue & inventaire',
      'Organisation multi-magasin',
      'Rapports & exports',
      'Branding enseigne',
    ],
    adminCta: 'Ouvrir l’espace admin',
  },
  contact: {
    eyebrow: 'Contact',
    title: 'Nous écrire',
    lede: 'Une question ? Envoyez-nous un message — nous répondons rapidement.',
    details: 'Coordonnées',
    support: 'Support {product} et accès back-office.',
    email: 'Email',
    phone: 'Téléphone',
    tenant: 'Tenant',
    note: 'Note',
    noteBody: 'Renseignez email / téléphone dans Organisation → Marque.',
    name: 'Votre nom',
    namePh: 'Jean Dupont',
    yourEmail: 'Votre email',
    emailPh: 'vous@exemple.com',
    subject: 'Sujet',
    subjectPh: 'Comment pouvons-nous aider ?',
    message: 'Message',
    messagePh: 'Parlez-nous de vos besoins…',
    send: 'Envoyer le message',
    sending: 'Envoi…',
    ok: 'Message prêt — votre client mail s’ouvre.',
    error: 'Merci de remplir tous les champs.',
    mailName: 'Nom',
    mailEmail: 'Email',
    formTitle: 'Envoyer un message',
    formHint: 'Nous vous répondons sous 24 heures ouvrées.',
    response: 'Réponse rapide',
    responseHint: 'Sous 24 h',
    channels: 'Canaux directs',
  },
  eco: {
    modesLabel: 'Modes d’architecture',
    master: 'Master',
    slave: 'Esclave',
    standalone: 'Autonome',
    masterBlurb: 'Hub local · sync esclaves + cloud',
    slaveBlurb: 'Caisse secondaire · relayée au Master',
    standaloneBlurb: 'Terminal seul · sync cloud directe',
    backoffice: 'Back-office',
    cloudAdmin: 'Cloud · Admin web',
    masterHub: 'Master Hub',
    syncLocal: 'Sync locale',
    posSlave: 'POS Esclave',
    windowsLan: 'Windows · LAN',
    androidLan: 'Android · LAN',
    stockCatalog: 'Stock · Catalogue · Shifts',
    viaMaster: 'via Master',
    masterShort: 'Master',
    lanWifi: 'LAN / Wi-Fi',
    salesPay: 'Ventes · Paiements',
    slaveNote: 'Relayé au Master · pas de cloud direct',
    sharedStock: 'Stock partagé',
    realtimeCatalog: 'Catalogue · temps réel',
    offlineQueue: 'File offline',
    syncWhenBack: 'Sync au retour Master',
    cloudDirect: 'Cloud · sync directe',
    posStandalone: 'POS Autonome',
    winOrAndroid: 'Windows ou Android',
    noMaster: 'Sans Master · indépendant',
    localStock: 'Stock local',
    catalog: 'Catalogue',
  },
  preview: { checkout: 'Encaisser' },
}

const en: Dict = {
  nav: {
    home: 'Home',
    suite: 'Suite',
    modules: 'Modules',
    why: 'Why us',
    pricing: 'Pricing',
    apps: 'Apps',
    contact: 'Contact',
  },
  actions: {
    getStarted: 'Get Started',
    login: 'Log in',
    register: 'Register',
    themeLight: 'Light mode',
    themeDark: 'Dark mode',
    language: 'Language',
  },
  footer: {
    quickLinks: 'Quick Links',
    contact: 'Contact',
    admin: 'Admin space',
    rights: 'All rights reserved.',
    blurb: 'Unified POS, stock and back-office for your brand.',
  },
  state: {
    loading: 'Loading…',
    notFound: 'Brand not found',
  },
  hero: {
    badgeSuffix: 'Business Suite',
    tagline: 'One Platform. Infinite Possibilities.',
    lede: 'Point of sale, stock, organization and control — a business suite for every brand.',
    cta: 'Get Started',
    modules: 'Our Modules',
  },
  stats: [
    { icon: 'DEV', label: 'Windows & Android', hint: 'POS terminal' },
    { icon: 'WEB', label: 'Web back-office', hint: 'Administration' },
    { icon: 'SYNC', label: 'Local sync', hint: 'Master · terminals' },
  ],
  suite: {
    eyebrow: 'Business Suite',
    title: 'All-in-One Business Suite',
    lede: 'One platform to sell in-store, sync stock and run the brand — from the Flutter terminal to the Vue back-office.',
    copyTitle: 'Built like your back-office',
    copyBody: '{product} connects POS, catalog, stock and organization on the same tenant. Enable the modules you need and keep your brand everywhere.',
    items: [
      'Offline-ready checkout with Master sync',
      'Shared catalog and stock per store',
      'Web admin, themes and multi-device',
    ],
    cta: 'Open admin space',
  },
  modules: {
    eyebrow: 'Our Modules',
    title: 'Business modules ready to enable',
    lede: 'Six building blocks for checkout, stock and control — aligned with the back-office.',
    items: [
      {
        icon: 'POS',
        title: 'Point of Sale',
        text: 'Full checkout for retail, restaurant and hospitality.',
        items: ['Cart & payments', 'Tables & shifts', 'Tickets & kitchen', 'Multi-store'],
      },
      {
        icon: 'INV',
        title: 'Inventory',
        text: 'Real-time stock tracking, alerts and counts.',
        items: ['Movements', 'Transfers', 'Barcodes', 'Stock alerts'],
      },
      {
        icon: 'CAT',
        title: 'Catalog',
        text: 'Products, variants, taxes and price lists per store.',
        items: ['Variants', 'Taxes', 'Images', 'Pricing'],
      },
      {
        icon: 'ORG',
        title: 'Organization',
        text: 'Stores, roles, registers and paired devices.',
        items: ['Roles & permissions', 'Registers', 'Devices', 'Multi-tenant'],
      },
      {
        icon: 'HOT',
        title: 'Hospitality',
        text: 'Tables, kitchen, reservations and floor service.',
        items: ['Floor plan', 'Kitchen', 'Orders', 'Servers'],
      },
      {
        icon: 'RPT',
        title: 'Reporting',
        text: 'Sales, expenses, purchases and business insight.',
        items: ['Sales', 'Purchases', 'Expenses', 'Exports'],
      },
    ],
  },
  why: {
    eyebrow: 'Why Choose Us',
    title: 'Built for Modern Business',
    lede: 'Enterprise foundations that scale without losing floor simplicity.',
    items: [
      { icon: 'CL', title: 'Cloud & local', text: 'Cloud back-office and local POS — Master / terminal sync.' },
      { icon: 'RT', title: 'Real time', text: 'Stock, sales and devices sync as soon as the network returns.' },
      { icon: 'SEC', title: 'POS security', text: 'PIN, session lock and roles isolated per terminal.' },
      { icon: 'AN', title: 'Analytics', text: 'Clear reports to steer every store and the brand.' },
      { icon: 'MOD', title: 'Business modules', text: 'Enable retail, restaurant or hospitality for your activity.' },
      { icon: 'SUP', title: 'Support', text: 'Help with rollout, branding and devices.' },
    ],
  },
  pricing: {
    eyebrow: 'Pricing',
    title: 'Simple, Transparent Pricing',
    lede: 'Pick the plan that fits. Every plan includes a 14-day trial.',
    perMonth: '/mo',
    popular: 'Most popular',
    trial: 'Start Free Trial',
    plans: [
      {
        name: 'Starter',
        lede: 'Perfect to get started',
        price: '4',
        note: 'or billed yearly',
        featured: false,
        features: ['5 users', '3 devices', '2 stores', '1,000 products', '2 modules', 'Email support'],
      },
      {
        name: 'Professional',
        lede: 'Most popular',
        price: '8',
        note: 'or billed yearly',
        featured: true,
        features: ['25 users', '10 devices', '10 stores', '10,000 products', 'Business modules', 'Priority support'],
      },
      {
        name: 'Enterprise',
        lede: 'For large brands',
        price: '17',
        note: 'or billed yearly',
        featured: false,
        features: ['Unlimited users', 'Unlimited devices', 'Unlimited stores', 'All modules', 'Unlimited storage', '24/7 support'],
      },
    ],
  },
  apps: {
    eyebrow: 'Our Apps',
    title: 'Download {product} Apps',
    lede: 'The POS terminal runs on Windows and Android. The web back-office drives catalog, stock and organization.',
    posLabel: 'Professional point of sale',
    posTitle: '{product} POS',
    posText: 'All-in-one checkout for retail, restaurant and hospitality — orders, tables, stock and multi-store.',
    posItems: [
      'Orders & kitchen display',
      'Tables, shifts & payments',
      'Real-time inventory sync',
      'Windows & Android',
    ],
    posWin: 'Request Windows build',
    posAndroid: 'Android version',
    adminLabel: 'Web back-office',
    adminTitle: '{product} Admin',
    adminText: 'Cloud admin: catalog, stock, stores, roles, reports and marketing brand.',
    adminItems: [
      'Catalog & inventory',
      'Multi-store organization',
      'Reports & exports',
      'Brand styling',
    ],
    adminCta: 'Open admin space',
  },
  contact: {
    eyebrow: 'Contact Us',
    title: 'Get in Touch',
    lede: 'Have a question? Send us a message — we reply quickly.',
    details: 'Contact details',
    support: '{product} support and back-office access.',
    email: 'Email',
    phone: 'Phone',
    tenant: 'Tenant',
    note: 'Note',
    noteBody: 'Set email / phone in Organization → Brand.',
    name: 'Your Name',
    namePh: 'John Doe',
    yourEmail: 'Your Email',
    emailPh: 'you@example.com',
    subject: 'Subject',
    subjectPh: 'How can we help?',
    message: 'Message',
    messagePh: 'Tell us more about your needs…',
    send: 'Send message',
    sending: 'Sending…',
    ok: 'Message ready — your mail client is opening.',
    error: 'Please fill in all fields.',
    mailName: 'Name',
    mailEmail: 'Email',
    formTitle: 'Send a message',
    formHint: 'We reply within 24 business hours.',
    response: 'Fast reply',
    responseHint: 'Within 24h',
    channels: 'Direct channels',
  },
  eco: {
    modesLabel: 'Architecture modes',
    master: 'Master',
    slave: 'Slave',
    standalone: 'Standalone',
    masterBlurb: 'Local hub · sync slaves + cloud',
    slaveBlurb: 'Secondary POS · relayed to Master',
    standaloneBlurb: 'Single terminal · direct cloud sync',
    backoffice: 'Back-office',
    cloudAdmin: 'Cloud · Web admin',
    masterHub: 'Master Hub',
    syncLocal: 'Local sync',
    posSlave: 'Slave POS',
    windowsLan: 'Windows · LAN',
    androidLan: 'Android · LAN',
    stockCatalog: 'Stock · Catalog · Shifts',
    viaMaster: 'via Master',
    masterShort: 'Master',
    lanWifi: 'LAN / Wi-Fi',
    salesPay: 'Sales · Payments',
    slaveNote: 'Relayed to Master · no direct cloud',
    sharedStock: 'Shared stock',
    realtimeCatalog: 'Catalog · real time',
    offlineQueue: 'Offline queue',
    syncWhenBack: 'Sync when Master returns',
    cloudDirect: 'Cloud · direct sync',
    posStandalone: 'Standalone POS',
    winOrAndroid: 'Windows or Android',
    noMaster: 'No Master · independent',
    localStock: 'Local stock',
    catalog: 'Catalog',
  },
  preview: { checkout: 'Charge' },
}

const sw: Dict = {
  nav: {
    home: 'Nyumbani',
    suite: 'Suite',
    modules: 'Moduli',
    why: 'Kwa nini sisi',
    pricing: 'Bei',
    apps: 'Programu',
    contact: 'Wasiliana',
  },
  actions: {
    getStarted: 'Anza',
    login: 'Ingia',
    register: 'Jisajili',
    themeLight: 'Mwanga',
    themeDark: 'Giza',
    language: 'Lugha',
  },
  footer: {
    quickLinks: 'Viungo',
    contact: 'Wasiliana',
    admin: 'Admin',
    rights: 'Haki zote zimehifadhiwa.',
    blurb: 'POS, hisa na back-office kwa biashara yako.',
  },
  state: {
    loading: 'Inapakia…',
    notFound: 'Chapa haijapatikana',
  },
  hero: {
    badgeSuffix: 'Business Suite',
    tagline: 'Jukwaa moja. Uwezekano usio na mwisho.',
    lede: 'POS, hisa, shirika na udhibiti — suite ya biashara kwa kila brand.',
    cta: 'Anza',
    modules: 'Moduli zetu',
  },
  stats: [
    { icon: 'DEV', label: 'Windows & Android', hint: 'Terminali ya POS' },
    { icon: 'WEB', label: 'Back-office wavuti', hint: 'Utawala' },
    { icon: 'SYNC', label: 'Sync ya ndani', hint: 'Master · terminali' },
  ],
  suite: {
    eyebrow: 'Business Suite',
    title: 'Suite ya biashara yote',
    lede: 'Jukwaa moja kuuza dukani, kusawazisha hisa na kuendesha brand — kutoka terminali ya Flutter hadi back-office ya Vue.',
    copyTitle: 'Imejengwa kama back-office yako',
    copyBody: '{product} inaunganisha POS, katalogi, hisa na shirika kwenye tenant moja. Washa moduli unazohitaji na weka brand yako kila mahali.',
    items: [
      'Malipo offline-ready na sync ya Master',
      'Katalogi na hisa zinazoshirikiwa kwa duka',
      'Admin wavuti, theme na vifaa vingi',
    ],
    cta: 'Fungua admin',
  },
  modules: {
    eyebrow: 'Moduli zetu',
    title: 'Moduli za biashara tayari kutumika',
    lede: 'Vipengele sita kwa POS, hisa na udhibiti — vinaendana na back-office.',
    items: [
      {
        icon: 'POS',
        title: 'Point of Sale',
        text: 'Malipo kamili kwa rejareja, mgahawa na ukarimu.',
        items: ['Kikapu & malipo', 'Meza & zamu', 'Tiketi & jikoni', 'Maduka mengi'],
      },
      {
        icon: 'INV',
        title: 'Hisa',
        text: 'Ufuatiliaji wa hisa papo hapo, arifa na hesabu.',
        items: ['Harakati', 'Uhamisho', 'Barcode', 'Arifa za hisa'],
      },
      {
        icon: 'CAT',
        title: 'Katalogi',
        text: 'Bidhaa, tofauti, kodi na orodha za bei kwa duka.',
        items: ['Tofauti', 'Kodi', 'Picha', 'Bei'],
      },
      {
        icon: 'ORG',
        title: 'Shirika',
        text: 'Maduka, majukumu, rejista na vifaa vilivyounganishwa.',
        items: ['Majukumu & ruhusa', 'Rejista', 'Vifaa', 'Multi-tenant'],
      },
      {
        icon: 'HOT',
        title: 'Ukarimu',
        text: 'Meza, jikoni, uhifadhi na huduma ya sakafu.',
        items: ['Mpango wa sakafu', 'Jikoni', 'Oda', 'Wahudumu'],
      },
      {
        icon: 'RPT',
        title: 'Ripoti',
        text: 'Mauzo, matumizi, ununuzi na maarifa ya biashara.',
        items: ['Mauzo', 'Ununuzi', 'Matumizi', 'Export'],
      },
    ],
  },
  why: {
    eyebrow: 'Kwa nini sisi',
    title: 'Imejengwa kwa biashara ya kisasa',
    lede: 'Msingi wa enterprise kwa kukua bila kupoteza urahisi wa sakafu.',
    items: [
      { icon: 'CL', title: 'Cloud & ndani', text: 'Back-office cloud na POS ya ndani — sync Master / terminali.' },
      { icon: 'RT', title: 'Wakati halisi', text: 'Hisa, mauzo na vifaa husawazishwa mtandao unaporudi.' },
      { icon: 'SEC', title: 'Usalama wa POS', text: 'PIN, kufunga session na majukumu kwa terminali.' },
      { icon: 'AN', title: 'Uchambuzi', text: 'Ripoti wazi kuongoza kila duka na brand.' },
      { icon: 'MOD', title: 'Moduli za biashara', text: 'Washa rejareja, mgahawa au ukarimu kwa shughuli yako.' },
      { icon: 'SUP', title: 'Msaada', text: 'Usaidizi wa kuanzisha, brand na vifaa.' },
    ],
  },
  pricing: {
    eyebrow: 'Bei',
    title: 'Bei rahisi na wazi',
    lede: 'Chagua mpango unaofaa. Kila mpango una majaribio ya siku 14.',
    perMonth: '/mwezi',
    popular: 'Maarufu zaidi',
    trial: 'Anza majaribio',
    plans: [
      {
        name: 'Starter',
        lede: 'Bora kuanza',
        price: '4',
        note: 'au malipo ya mwaka',
        featured: false,
        features: ['Watumiaji 5', 'Vifaa 3', 'Maduka 2', 'Bidhaa 1,000', 'Moduli 2', 'Msaada wa email'],
      },
      {
        name: 'Professional',
        lede: 'Maarufu zaidi',
        price: '8',
        note: 'au malipo ya mwaka',
        featured: true,
        features: ['Watumiaji 25', 'Vifaa 10', 'Maduka 10', 'Bidhaa 10,000', 'Moduli za biashara', 'Msaada wa kipaumbele'],
      },
      {
        name: 'Enterprise',
        lede: 'Kwa brand kubwa',
        price: '17',
        note: 'au malipo ya mwaka',
        featured: false,
        features: ['Watumiaji bila kikomo', 'Vifaa bila kikomo', 'Maduka bila kikomo', 'Moduli zote', 'Hifadhi bila kikomo', 'Msaada 24/7'],
      },
    ],
  },
  apps: {
    eyebrow: 'Programu zetu',
    title: 'Pakua programu za {product}',
    lede: 'Terminali ya POS inaendesha Windows na Android. Back-office wavuti inaongoza katalogi, hisa na shirika.',
    posLabel: 'POS ya kitaalamu',
    posTitle: '{product} POS',
    posText: 'Malipo yote kwa rejareja, mgahawa na ukarimu — oda, meza, hisa na maduka mengi.',
    posItems: [
      'Oda & onyesho la jikoni',
      'Meza, zamu & malipo',
      'Sync ya hisa papo hapo',
      'Windows & Android',
    ],
    posWin: 'Omba build ya Windows',
    posAndroid: 'Toleo la Android',
    adminLabel: 'Back-office wavuti',
    adminTitle: '{product} Admin',
    adminText: 'Admin cloud: katalogi, hisa, maduka, majukumu, ripoti na brand ya marketing.',
    adminItems: [
      'Katalogi & hisa',
      'Shirika la maduka mengi',
      'Ripoti & export',
      'Brand ya biashara',
    ],
    adminCta: 'Fungua admin',
  },
  contact: {
    eyebrow: 'Wasiliana',
    title: 'Tuandikie',
    lede: 'Una swali? Tutumie ujumbe — tunajibu haraka.',
    details: 'Maelezo ya mawasiliano',
    support: 'Msaada wa {product} na ufikiaji wa back-office.',
    email: 'Email',
    phone: 'Simu',
    tenant: 'Tenant',
    note: 'Kumbuka',
    noteBody: 'Weka email / simu katika Organization → Brand.',
    name: 'Jina lako',
    namePh: 'John Doe',
    yourEmail: 'Email yako',
    emailPh: 'wewe@mfano.com',
    subject: 'Mada',
    subjectPh: 'Tunaweza kusaidia vipi?',
    message: 'Ujumbe',
    messagePh: 'Tuambie kuhusu mahitaji yako…',
    send: 'Tuma ujumbe',
    sending: 'Inatuma…',
    ok: 'Ujumbe uko tayari — programu ya barua inafunguka.',
    error: 'Tafadhali jaza sehemu zote.',
    mailName: 'Jina',
    mailEmail: 'Email',
    formTitle: 'Tuma ujumbe',
    formHint: 'Tunajibu ndani ya masaa 24 ya kazi.',
    response: 'Jibu la haraka',
    responseHint: 'Ndani ya 24h',
    channels: 'Njia za moja kwa moja',
  },
  eco: {
    modesLabel: 'Hali za usanifu',
    master: 'Master',
    slave: 'Slave',
    standalone: 'Autonome',
    masterBlurb: 'Hub ya ndani · sync slaves + cloud',
    slaveBlurb: 'POS ya pili · inapelekwa kwa Master',
    standaloneBlurb: 'Terminali pekee · sync cloud moja kwa moja',
    backoffice: 'Back-office',
    cloudAdmin: 'Cloud · Admin wavuti',
    masterHub: 'Master Hub',
    syncLocal: 'Sync ya ndani',
    posSlave: 'POS Slave',
    windowsLan: 'Windows · LAN',
    androidLan: 'Android · LAN',
    stockCatalog: 'Hisa · Katalogi · Zamu',
    viaMaster: 'kupitia Master',
    masterShort: 'Master',
    lanWifi: 'LAN / Wi-Fi',
    salesPay: 'Mauzo · Malipo',
    slaveNote: 'Inapelekwa kwa Master · hakuna cloud moja kwa moja',
    sharedStock: 'Hisa ya pamoja',
    realtimeCatalog: 'Katalogi · wakati halisi',
    offlineQueue: 'Foleni offline',
    syncWhenBack: 'Sync Master atakaporudi',
    cloudDirect: 'Cloud · sync moja kwa moja',
    posStandalone: 'POS Autonome',
    winOrAndroid: 'Windows au Android',
    noMaster: 'Bila Master · huru',
    localStock: 'Hisa ya ndani',
    catalog: 'Katalogi',
  },
  preview: { checkout: 'Lipisha' },
}

const messages: Record<Locale, Dict> = { fr, en, sw }

export function isLocale(value: string | null | undefined): value is Locale {
  return value === 'fr' || value === 'en' || value === 'sw'
}

function readQueryLocale(): Locale | null {
  try {
    const raw = new URLSearchParams(window.location.search).get('lang')
    return isLocale(raw) ? raw : null
  } catch {
    return null
  }
}

function readStoredLocale(): Locale | null {
  try {
    const stored = localStorage.getItem(LOCALE_STORAGE_KEY) || localStorage.getItem(LEGACY_STORAGE_KEY)
    return isLocale(stored) ? stored : null
  } catch {
    return null
  }
}

function detectBrowserLocale(): Locale {
  const nav = navigator.language.toLowerCase()
  if (nav.startsWith('sw')) return 'sw'
  if (nav.startsWith('fr')) return 'fr'
  return 'en'
}

function readLocale(): Locale {
  return readQueryLocale() || readStoredLocale() || detectBrowserLocale()
}

const locale = ref<Locale>(typeof window !== 'undefined' ? readLocale() : 'fr')

function fill(template: string, vars?: Record<string, string>) {
  if (!vars) return template
  return template.replace(/\{(\w+)\}/g, (_, key: string) => vars[key] ?? `{${key}}`)
}

export function getLocale(): Locale {
  return locale.value
}

export function useI18n() {
  const dict = computed(() => messages[locale.value])

  function setLocale(next: Locale) {
    locale.value = next
    try {
      localStorage.setItem(LOCALE_STORAGE_KEY, next)
      localStorage.removeItem(LEGACY_STORAGE_KEY)
    } catch {
      // ignore quota / private mode
    }
    document.documentElement.lang = next
    // Keep URL shareable / deep-linkable for admin handoff
    try {
      const url = new URL(window.location.href)
      url.searchParams.set('lang', next)
      window.history.replaceState(null, '', `${url.pathname}${url.search}${url.hash}`)
    } catch {
      // ignore
    }
  }

  /** Dot-path lookup, e.g. t('hero.cta') or t('nav', 'home') for legacy. */
  function t(a: string, b?: string, vars?: Record<string, string>): string {
    const path = b ? `${a}.${b}` : a
    const parts = path.split('.')
    let cur: unknown = messages[locale.value]
    for (const part of parts) {
      if (cur == null || typeof cur !== 'object') {
        cur = undefined
        break
      }
      cur = (cur as Record<string, unknown>)[part]
    }
    if (typeof cur === 'string') return fill(cur, vars)
    return path
  }

  return { locale, dict, setLocale, t, locales: ['fr', 'en', 'sw'] as const }
}

export function initLocale() {
  const fromQuery = readQueryLocale()
  if (fromQuery) {
    locale.value = fromQuery
    try {
      localStorage.setItem(LOCALE_STORAGE_KEY, fromQuery)
      localStorage.removeItem(LEGACY_STORAGE_KEY)
    } catch {
      // ignore
    }
  }
  document.documentElement.lang = locale.value

  window.addEventListener('storage', (event) => {
    if (event.key !== LOCALE_STORAGE_KEY && event.key !== LEGACY_STORAGE_KEY) return
    if (isLocale(event.newValue)) {
      locale.value = event.newValue
      document.documentElement.lang = event.newValue
    }
  })
}
