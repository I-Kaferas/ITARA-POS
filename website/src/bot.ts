import type { Locale } from './i18n'

export type BotContext = {
  product: string
  email?: string | null
  phone?: string | null
}

export type BotReply = {
  text: string
  suggestions: string[]
}

type Intent = {
  id: string
  patterns: RegExp[]
}

/** Strip accents / punctuation so “Tarifs ?” or “combien ça coûte” still match. */
function normalize(raw: string) {
  return raw
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
    .replace(/[^\p{L}\p{N}\s]/gu, ' ')
    .replace(/\s+/g, ' ')
}

const intents: Intent[] = [
  {
    id: 'pricing',
    patterns: [
      /\b(prix|tarif|tarifs|tarification|abonnement|abonnements|offre|offres|plan|plans|pricing|price|prices|cost|cout|coute|coute|combien|bei|gharama|malipo)\b/,
      /\b(starter|professional|business|enterprise)\b/,
      /\b(mensuel|annuel|par mois|\/mois|\/mo)\b/,
      /\b(essai|trial)\s*(gratuit|free|14)?\b/,
    ],
  },
  {
    id: 'modules',
    patterns: [
      /\b(module|modules|moduli|fonctionnalit|feature|features)\b/,
      /\b(inventaire|inventory|catalogue|catalog|hospitalit|hotel|hotellerie|restaurant|reporting|rapport|hisa|katalogi)\b/,
      /\b(que fait|what (does|can)|nini)\b/,
    ],
  },
  {
    id: 'pos',
    patterns: [
      /\b(pos|caisse|terminal|terminaux|windows|android|app|apps|application|applications)\b/,
      /\b(telecharg|download|pakua|installer|install)\b/,
    ],
  },
  {
    id: 'sync',
    patterns: [
      /\b(sync|synchron|master|esclave|slave|offline|hors ligne|lan|wifi|ndani|reseau|network)\b/,
    ],
  },
  {
    id: 'demo',
    patterns: [
      /\b(demo|essai|trial|tester|try|jaribu|commencer|get started|demarrer)\b/,
    ],
  },
  {
    id: 'contact',
    patterns: [
      /\b(contact|contacter|email|mail|telephone|phone|simu|humain|agent|support|msaada|aide|help|ecrire|message)\b/,
    ],
  },
  {
    id: 'hello',
    patterns: [
      /^(bonjour|bonsoir|salut|hello|hi|hey|habari|hujambo|jambo|coucou)(\s|$)/,
    ],
  },
  {
    id: 'about',
    patterns: [
      /\b(c est quoi|quest ce|qui etes|who are|what is|nini|apropos|a propos|itara|nexus|erp|logiciel|software|produit|product)\b/,
    ],
  },
]

const copy: Record<
  Locale,
  {
    welcome: string
    fallback: string
    answers: Record<string, string>
    suggestions: string[]
  }
> = {
  fr: {
    welcome:
      'Bonjour ! Je suis l’assistant {product}. Posez votre question — je réponds tout de suite. Pour un conseiller humain, comptez moins de 24 h.',
    fallback:
      'Je n’ai pas trouvé de correspondance exacte. Essayez par exemple : « tarifs », « modules », « POS », « sync », « démo » ou « contact ». Ou laissez un message dans le formulaire — réponse humaine sous 24 h.',
    answers: {
      hello: 'Bonjour ! Comment puis-je vous aider concernant {product} ?',
      about:
        '{product} est un ERP commerce & hospitalité : point de vente, stocks, restaurant, hôtel, achats et reporting — back-office cloud + caisse locale. Voyez Fonctionnalités, Tarifs ou Nos apps.',
      pricing:
        '{product} : Starter 7 $/mois (50 $/an), Professional 15 $/mois (100 $/an), Business 35 $/mois (350 $/an), Enterprise 79 $/mois (790 $/an). Essai 14 jours inclus. Ouvrez la section Tarifs pour le détail.',
      modules:
        'Modules prêts à activer : Point de vente, Inventaire, Catalogue, Organisation, Hospitalité (restaurant / hôtel) et Reporting. Tout s’active selon votre activité.',
      pos:
        'Le terminal POS tourne sur Windows et Android (commandes, tables, stock, multi-magasin). Le back-office web gère catalogue, stocks et organisation. Voyez « Nos apps ».',
      sync:
        'Architecture Master / Esclave / Autonome : sync locale sur le LAN, puis cloud. Les esclaves relaient au Master — idéal hors-ligne.',
      demo:
        'Pour un essai ou une démo, cliquez « Commencer » ou écrivez-nous via le formulaire Contact. Un conseiller répond sous 24 h.',
      contact:
        '{contactLine} Vous pouvez aussi remplir le formulaire « Nous écrire » — réponse humaine sous 24 h ouvrées.',
    },
    suggestions: ['Tarifs', 'Modules', 'POS Windows / Android', 'Sync Master', 'Parler à un humain'],
  },
  en: {
    welcome:
      'Hi! I’m the {product} assistant. Ask anything — I reply instantly. For a human advisor, expect under 24 hours.',
    fallback:
      'I didn’t find an exact match. Try “pricing”, “modules”, “POS”, “sync”, “demo” or “contact”. Or leave a message in the form — human reply within 24h.',
    answers: {
      hello: 'Hello! How can I help you with {product}?',
      about:
        '{product} is a commerce & hospitality ERP: POS, inventory, restaurant, hotel, purchasing and reporting — cloud back-office + local checkout. See Features, Pricing or Our apps.',
      pricing:
        '{product}: Starter $7/mo ($50/yr), Professional $15/mo ($100/yr), Business $35/mo ($350/yr), Enterprise $79/mo ($790/yr). 14-day trial included. Open Pricing for details.',
      modules:
        'Ready modules: Point of Sale, Inventory, Catalog, Organization, Hospitality (restaurant / hotel) and Reporting — enable what fits your business.',
      pos:
        'The POS terminal runs on Windows and Android (orders, tables, stock, multi-store). The web back-office manages catalog, stock and organization. See “Our apps”.',
      sync:
        'Master / Slave / Standalone architecture: local LAN sync, then cloud. Slaves relay to Master — great offline.',
      demo:
        'For a trial or demo, click Get started or write via the Contact form. An advisor replies within 24h.',
      contact:
        '{contactLine} You can also use the “Get in Touch” form — human reply within 24 business hours.',
    },
    suggestions: ['Pricing', 'Modules', 'POS Windows / Android', 'Master sync', 'Talk to a human'],
  },
  sw: {
    welcome:
      'Habari! Mimi ni msaidizi wa {product}. Uliza swali — najibu papo hapo. Kwa mshauri wa binadamu, chini ya saa 24.',
    fallback:
      'Sikupata jibu kamili. Jaribu “bei”, “moduli”, “POS”, “sync”, “demo” au “wasiliana”. Au acha ujumbe kwenye fomu — jibu la binadamu ndani ya 24h.',
    answers: {
      hello: 'Habari! Nawezaje kukusaidia kuhusu {product}?',
      about:
        '{product} ni ERP ya biashara na ukarimu: POS, hisa, mgahawa, hoteli, ununuzi na ripoti — back-office cloud + POS ya ndani. Angalia Vipengele, Bei au Programu.',
      pricing:
        '{product}: Starter $7/mwezi ($50/mwaka), Professional $15/mwezi ($100/mwaka), Business $35/mwezi ($350/mwaka), Enterprise $79/mwezi ($790/mwaka). Majaribio siku 14. Fungua Bei kwa maelezo.',
      modules:
        'Moduli tayari: Point of Sale, Hisa, Katalogi, Shirika, Ukarimu (mgahawa / hoteli) na Ripoti — washa unazohitaji.',
      pos:
        'Terminali ya POS inaendesha Windows na Android (oda, meza, hisa, maduka mengi). Back-office wavuti inasimamia katalogi, hisa na shirika.',
      sync:
        'Usanifu Master / Slave / Autonome: sync ya LAN kisha cloud. Slave hutoa kwa Master — vizuri offline.',
      demo:
        'Kwa jaribio au demo, bofya Anza au andika kupitia fomu ya Wasiliana. Mshauri anajibu ndani ya 24h.',
      contact:
        '{contactLine} Unaweza pia kujaza fomu “Tuandikie” — jibu la binadamu ndani ya masaa 24 ya kazi.',
    },
    suggestions: ['Bei', 'Moduli', 'POS Windows / Android', 'Sync Master', 'Zungumza na mtu'],
  },
}

function fill(template: string, vars: Record<string, string>) {
  return template.replace(/\{(\w+)\}/g, (_, key: string) => vars[key] ?? '')
}

function contactLine(locale: Locale, ctx: BotContext) {
  const parts: string[] = []
  if (ctx.email) parts.push(ctx.email)
  if (ctx.phone) parts.push(ctx.phone)
  if (parts.length === 0) {
    return locale === 'fr'
      ? 'Utilisez le formulaire Contact sur cette page.'
      : locale === 'sw'
        ? 'Tumia fomu ya Wasiliana kwenye ukurasa huu.'
        : 'Use the Contact form on this page.'
  }
  return locale === 'fr'
    ? `Contact direct : ${parts.join(' · ')}.`
    : locale === 'sw'
      ? `Mawasiliano ya moja kwa moja: ${parts.join(' · ')}.`
      : `Direct contact: ${parts.join(' · ')}.`
}

export function botWelcome(locale: Locale, ctx: BotContext): BotReply {
  const pack = copy[locale] ?? copy.fr
  return {
    text: fill(pack.welcome, { product: ctx.product }),
    suggestions: pack.suggestions,
  }
}

export function botReply(message: string, locale: Locale, ctx: BotContext): BotReply {
  const pack = copy[locale] ?? copy.fr
  const text = normalize(message)
  const vars = {
    product: ctx.product,
    contactLine: contactLine(locale, ctx),
  }

  if (!text) {
    return { text: fill(pack.fallback, vars), suggestions: pack.suggestions }
  }

  for (const intent of intents) {
    if (intent.patterns.some((pattern) => pattern.test(text))) {
      const answer = pack.answers[intent.id] ?? pack.fallback
      return {
        text: fill(answer, vars),
        suggestions: pack.suggestions,
      }
    }
  }

  return { text: fill(pack.fallback, vars), suggestions: pack.suggestions }
}

export function isHumanHandoff(message: string) {
  return /\b(humain|human|agent|conseiller|advisor|mtu|binadamu|parler|talk|zungumza)\b/i.test(
    normalize(message),
  )
}
