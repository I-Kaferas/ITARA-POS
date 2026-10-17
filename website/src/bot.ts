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
  patterns: RegExp
}

const intents: Intent[] = [
  {
    id: 'pricing',
    patterns: /\b(prix|tarif|tarification|abonnement|plan|pricing|price|cost|bei|gharama|malipo)\b/i,
  },
  {
    id: 'modules',
    patterns: /\b(module|modules|moduli|inventaire|inventory|catalogue|catalog|hospitalit|restaurant|reporting|hisa|katalogi)\b/i,
  },
  {
    id: 'pos',
    patterns: /\b(pos|caisse|terminal|windows|android|app|application|t[eé]l[eé]charg|download|pakua)\b/i,
  },
  {
    id: 'sync',
    patterns: /\b(sync|synchron|master|esclave|slave|offline|hors.?ligne|lan|wifi|ndani)\b/i,
  },
  {
    id: 'demo',
    patterns: /\b(demo|d[eé]mo|essai|trial|tester|try|jaribu)\b/i,
  },
  {
    id: 'contact',
    patterns: /\b(contact|email|mail|t[eé]l[eé]phone|phone|simu|humain|agent|support|msaada)\b/i,
  },
  {
    id: 'hello',
    patterns: /^(bonjour|bonsoir|salut|hello|hi|hey|habari|hujambo|jambo)\b/i,
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
      'Je n’ai pas bien saisi. Essayez « tarifs », « modules », « POS », « sync » ou « contact ». Vous pouvez aussi laisser un message dans le formulaire — réponse humaine sous 24 h.',
    answers: {
      hello: 'Bonjour ! Comment puis-je vous aider concernant {product} ?',
      pricing:
        '{product} propose Starter, Business et Enterprise, avec 14 jours d’essai. Ouvrez la section Tarifs pour le détail, ou demandez une démo.',
      modules:
        'Les modules prêts à activer : Point de vente, Inventaire, Catalogue, Organisation, Hospitalité et Reporting. Tout s’active selon votre activité.',
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
      'I didn’t catch that. Try “pricing”, “modules”, “POS”, “sync” or “contact”. You can also leave a message in the form — human reply within 24h.',
    answers: {
      hello: 'Hello! How can I help you with {product}?',
      pricing:
        '{product} offers Starter, Business and Enterprise, with a 14-day trial. See Pricing for details, or ask for a demo.',
      modules:
        'Ready modules: Point of Sale, Inventory, Catalog, Organization, Hospitality and Reporting — enable what fits your business.',
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
      'Sikuelewa vizuri. Jaribu “bei”, “moduli”, “POS”, “sync” au “wasiliana”. Unaweza pia kuacha ujumbe kwenye fomu — jibu la binadamu ndani ya 24h.',
    answers: {
      hello: 'Habari! Nawezaje kukusaidia kuhusu {product}?',
      pricing:
        '{product} ina Starter, Business na Enterprise, na majaribio ya siku 14. Angalia Bei au omba demo.',
      modules:
        'Moduli tayari: Point of Sale, Hisa, Katalogi, Shirika, Ukarimu na Ripoti — washa unazohitaji.',
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
  const text = message.trim()
  const vars = {
    product: ctx.product,
    contactLine: contactLine(locale, ctx),
  }

  if (!text) {
    return { text: fill(pack.fallback, vars), suggestions: pack.suggestions }
  }

  for (const intent of intents) {
    if (intent.patterns.test(text)) {
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
  return /\b(humain|human|agent|conseiller|advisor|mtu|binadamu|parler|talk|zungumza)\b/i.test(message)
}
