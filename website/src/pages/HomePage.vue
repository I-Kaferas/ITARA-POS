<script setup lang="ts">
import { computed, inject, reactive, ref, type Ref } from 'vue'
import EcosystemDiagram from '../components/EcosystemDiagram.vue'
import ModuleIcon from '../components/ModuleIcon.vue'
import PosPreview from '../components/PosPreview.vue'
import { PRODUCT_NAME, resolveCtaUrl, type TenantBranding } from '../branding'
import { useI18n } from '../i18n'

const branding = inject<Ref<TenantBranding | null>>('branding')!
const openSupportBot = inject<() => void>('openSupportBot', () => {})
const { t, dict } = useI18n()
const ctaHref = computed(() => (branding.value ? resolveCtaUrl(branding.value) : '#'))

const productName = computed(() => branding.value?.brand_name ?? PRODUCT_NAME)

const headline = computed(() => {
  const b = branding.value
  if (!b) return t('hero.tagline')
  const title = b.marketing.hero_title.trim()
  if (
    title
    && title.toLowerCase() !== b.brand_name.trim().toLowerCase()
    && title.toLowerCase() !== PRODUCT_NAME.toLowerCase()
    && !/one platform|plateforme|jukwaa/i.test(title)
  ) {
    return title
  }
  return t('hero.tagline')
})

const lede = computed(() => {
  const custom = branding.value?.marketing.hero_subtitle?.trim()
  if (custom && !/point de vente|point of sale|pos,/i.test(custom)) return custom
  return t('hero.lede')
})

const modules = computed(() => dict.value.modules.items)
const reasons = computed(() => dict.value.why.items)
const plans = computed(() => dict.value.pricing.plans)
const stats = computed(() => dict.value.stats)

/** Twinkling stars across the full navy hero block. */
const heroStars = [
  { x: 4, y: 8, s: 1.2, d: 0.1, c: 'amber' },
  { x: 12, y: 22, s: 1, d: 1.2, c: 'white' },
  { x: 18, y: 48, s: 1.5, d: 0.5, c: 'amber' },
  { x: 7, y: 68, s: 1.1, d: 2.0, c: 'white' },
  { x: 15, y: 86, s: 1.4, d: 1.6, c: 'amber' },
  { x: 28, y: 12, s: 1.3, d: 0.8, c: 'white' },
  { x: 34, y: 34, s: 1, d: 2.4, c: 'amber' },
  { x: 26, y: 58, s: 1.6, d: 0.3, c: 'white' },
  { x: 38, y: 78, s: 1.1, d: 1.9, c: 'amber' },
  { x: 46, y: 18, s: 1.4, d: 1.1, c: 'white' },
  { x: 52, y: 42, s: 1.2, d: 0.6, c: 'amber' },
  { x: 48, y: 64, s: 1, d: 2.7, c: 'white' },
  { x: 56, y: 88, s: 1.7, d: 1.4, c: 'amber' },
  { x: 64, y: 10, s: 1.1, d: 0.9, c: 'white' },
  { x: 70, y: 28, s: 1.5, d: 2.1, c: 'amber' },
  { x: 62, y: 52, s: 1, d: 0.4, c: 'white' },
  { x: 74, y: 70, s: 1.3, d: 1.7, c: 'amber' },
  { x: 68, y: 92, s: 1.2, d: 2.5, c: 'white' },
  { x: 82, y: 16, s: 1.6, d: 0.2, c: 'amber' },
  { x: 90, y: 36, s: 1.1, d: 1.5, c: 'white' },
  { x: 84, y: 54, s: 1.4, d: 2.2, c: 'amber' },
  { x: 94, y: 72, s: 1, d: 0.7, c: 'white' },
  { x: 88, y: 90, s: 1.5, d: 1.8, c: 'amber' },
  { x: 22, y: 40, s: 0.9, d: 2.8, c: 'white' },
  { x: 42, y: 50, s: 1.3, d: 1.0, c: 'amber' },
  { x: 78, y: 44, s: 1.1, d: 2.3, c: 'white' },
  { x: 10, y: 36, s: 1.8, d: 0.55, c: 'amber' },
  { x: 96, y: 12, s: 1.2, d: 1.3, c: 'white' },
  { x: 58, y: 6, s: 1, d: 2.6, c: 'amber' },
  { x: 32, y: 94, s: 1.4, d: 0.15, c: 'white' },
  { x: 50, y: 30, s: 1.1, d: 1.55, c: 'amber' },
  { x: 86, y: 62, s: 1.6, d: 0.95, c: 'white' },
  { x: 6, y: 54, s: 1.2, d: 2.15, c: 'amber' },
  { x: 76, y: 82, s: 1, d: 0.65, c: 'white' },
  { x: 40, y: 6, s: 1.3, d: 1.85, c: 'amber' },
  { x: 20, y: 74, s: 1.5, d: 2.35, c: 'white' },
]

const form = reactive({
  name: '',
  email: '',
  subject: '',
  message: '',
})
const formStatus = ref<'idle' | 'ok' | 'error'>('idle')
const sending = ref(false)

function withProduct(template: string) {
  return template.replaceAll('{product}', productName.value)
}

function submitContact() {
  formStatus.value = 'idle'
  if (!form.name.trim() || !form.email.trim() || !form.subject.trim() || !form.message.trim()) {
    formStatus.value = 'error'
    return
  }
  sending.value = true
  const to = branding.value?.support_email?.trim() || 'info@example.com'
  const body = [
    `${t('contact.mailName')}: ${form.name.trim()}`,
    `${t('contact.mailEmail')}: ${form.email.trim()}`,
    '',
    form.message.trim(),
  ].join('\n')
  const mailto = `mailto:${encodeURIComponent(to)}?subject=${encodeURIComponent(form.subject.trim())}&body=${encodeURIComponent(body)}`
  window.location.href = mailto
  formStatus.value = 'ok'
  sending.value = false
  form.name = ''
  form.email = ''
  form.subject = ''
  form.message = ''
}
</script>

<template>
  <template v-if="branding">
    <!-- Branding / Hero -->
    <section id="branding" class="hero">
      <div class="hero__stars" aria-hidden="true">
        <span
          v-for="(star, i) in heroStars"
          :key="i"
          class="hero__star"
          :class="`hero__star--${star.c}`"
          :style="{
            left: `${star.x}%`,
            top: `${star.y}%`,
            width: `${star.s * 3}px`,
            height: `${star.s * 3}px`,
            animationDelay: `${star.d}s`,
            animationDuration: `${2.4 + (star.s % 1) * 2.2}s`,
          }"
        />
      </div>
      <div class="hero__layout">
        <div class="hero__copy">
          <p class="hero__badge hero-animate">
            <strong>{{ productName }}</strong> · {{ t('hero.badgeSuffix') }}
          </p>
          <h1 class="hero-animate hero-animate--delay-1">{{ productName }}</h1>
          <p class="hero__tagline hero-animate hero-animate--delay-2">{{ headline }}</p>
          <p class="hero__lede hero-animate hero-animate--delay-3">{{ lede }}</p>
          <div class="hero__actions hero-animate hero-animate--delay-4">
            <a class="btn btn-accent" :href="ctaHref">{{ t('hero.cta') }}</a>
            <a class="btn btn-ghost" href="#modules">{{ t('hero.modules') }}</a>
          </div>
        </div>
        <div class="hero__visual hero-animate hero-animate--delay-3">
          <EcosystemDiagram :brand="productName" />
        </div>
      </div>
      <div class="hero__stats">
        <div
          v-for="stat in stats"
          :key="stat.label"
          class="hero__stat"
          :class="`hero__stat--${stat.icon.toLowerCase()}`"
        >
          <div class="hero__stat-icon" aria-hidden="true">
            <ModuleIcon :name="stat.icon" />
          </div>
          <div class="hero__stat-copy">
            <strong>{{ stat.label }}</strong>
            <span>{{ stat.hint }}</span>
          </div>
        </div>
      </div>
    </section>

    <!-- Business Suite -->
    <section id="suite" class="section wrap">
      <div class="section-head" data-reveal>
        <p class="eyebrow">{{ t('suite.eyebrow') }}</p>
        <h2>{{ t('suite.title') }}</h2>
        <p>{{ t('suite.lede') }}</p>
      </div>
      <div class="suite" data-reveal>
        <div class="suite__copy glass-panel">
          <h3>{{ t('suite.copyTitle') }}</h3>
          <p>{{ withProduct(t('suite.copyBody')) }}</p>
          <ul class="suite__list">
            <li v-for="item in dict.suite.items" :key="item">{{ item }}</li>
          </ul>
          <a class="btn btn-primary" :href="ctaHref">{{ t('suite.cta') }}</a>
        </div>
        <div class="suite__preview glass-panel glass-panel--dark">
          <PosPreview :title="productName" />
        </div>
      </div>
    </section>

    <!-- Our Modules -->
    <section id="modules" class="section section--surface">
      <div class="wrap">
        <div class="section-head" data-reveal>
          <p class="eyebrow">{{ t('modules.eyebrow') }}</p>
          <h2>{{ t('modules.title') }}</h2>
          <p>{{ t('modules.lede') }}</p>
        </div>
        <div class="grid-3">
          <article
            v-for="(mod, i) in modules"
            :key="mod.title"
            class="tile glass-card"
            data-reveal
            :style="{ '--reveal-delay': `${i * 60}ms` }"
          >
            <div
              class="tile__icon"
              :class="`tile__icon--${mod.icon.toLowerCase()}`"
              aria-hidden="true"
            >
              <ModuleIcon :name="mod.icon" />
            </div>
            <h3>{{ mod.title }}</h3>
            <p>{{ mod.text }}</p>
            <ul>
              <li v-for="item in mod.items" :key="item">{{ item }}</li>
            </ul>
          </article>
        </div>
      </div>
    </section>

    <!-- Why Choose Us -->
    <section id="why" class="section wrap">
      <div class="section-head" data-reveal>
        <p class="eyebrow">{{ t('why.eyebrow') }}</p>
        <h2>{{ t('why.title') }}</h2>
        <p>{{ t('why.lede') }}</p>
      </div>
      <div class="grid-3">
        <article
          v-for="(item, i) in reasons"
          :key="item.title"
          class="tile glass-card"
          data-reveal
          :style="{ '--reveal-delay': `${i * 60}ms` }"
        >
          <div
            class="tile__icon"
            :class="`tile__icon--${item.icon.toLowerCase()}`"
            aria-hidden="true"
          >
            <ModuleIcon :name="item.icon" />
          </div>
          <h3>{{ item.title }}</h3>
          <p>{{ item.text }}</p>
        </article>
      </div>
    </section>

    <!-- Pricing -->
    <section id="pricing" class="section section--surface">
      <div class="wrap">
        <div class="section-head" data-reveal>
          <p class="eyebrow">{{ t('pricing.eyebrow') }}</p>
          <h2>{{ t('pricing.title') }}</h2>
          <p>{{ t('pricing.lede') }}</p>
        </div>
        <div class="grid-pricing">
          <article
            v-for="(plan, i) in plans"
            :key="plan.name"
            class="price-card glass-card"
            data-reveal
            :style="{ '--reveal-delay': `${i * 80}ms` }"
            :class="{ 'is-featured': plan.featured }"
          >
            <span v-if="plan.featured" class="price-card__badge">{{ t('pricing.popular') }}</span>
            <h3>{{ plan.name }}</h3>
            <p class="lede">{{ plan.lede }}</p>
            <p class="price-card__amount">${{ plan.price }} <span>{{ t('pricing.perMonth') }}</span></p>
            <p class="price-card__note">{{ plan.note }}</p>
            <ul>
              <li v-for="f in plan.features" :key="f">{{ f }}</li>
            </ul>
            <a class="btn btn-block" :class="plan.featured ? 'btn-accent' : 'btn-primary'" :href="ctaHref">
              {{ t('pricing.trial') }}
            </a>
          </article>
        </div>
      </div>
    </section>

    <!-- Our Apps -->
    <section id="apps" class="section wrap">
      <div class="section-head" data-reveal>
        <p class="eyebrow">{{ t('apps.eyebrow') }}</p>
        <h2>{{ withProduct(t('apps.title')) }}</h2>
        <p>{{ t('apps.lede') }}</p>
      </div>
      <div class="grid-2">
        <article class="app-card glass-card" data-reveal>
          <p class="app-card__label">{{ t('apps.posLabel') }}</p>
          <h3>{{ withProduct(t('apps.posTitle')) }}</h3>
          <p>{{ t('apps.posText') }}</p>
          <ul>
            <li v-for="item in dict.apps.posItems" :key="item">{{ item }}</li>
          </ul>
          <div class="app-card__actions">
            <a class="btn btn-primary" href="#contact">{{ t('apps.posWin') }}</a>
            <a class="btn btn-light" href="#contact">{{ t('apps.posAndroid') }}</a>
          </div>
        </article>
        <article class="app-card glass-card" data-reveal style="--reveal-delay: 80ms">
          <p class="app-card__label">{{ t('apps.adminLabel') }}</p>
          <h3>{{ withProduct(t('apps.adminTitle')) }}</h3>
          <p>{{ t('apps.adminText') }}</p>
          <ul>
            <li v-for="item in dict.apps.adminItems" :key="item">{{ item }}</li>
          </ul>
          <div class="app-card__actions">
            <a class="btn btn-accent" :href="ctaHref">{{ t('apps.adminCta') }}</a>
          </div>
        </article>
      </div>
    </section>

    <!-- Contact -->
    <section id="contact" class="section section--contact">
      <div class="wrap">
        <div class="section-head section-head--center" data-reveal>
          <p class="eyebrow">{{ t('contact.eyebrow') }}</p>
          <h2>{{ t('contact.title') }}</h2>
          <p>{{ t('contact.lede') }}</p>
        </div>

        <div class="contact" data-reveal>
          <aside class="contact__aside">
            <div class="contact__hero glass-panel glass-panel--dark">
              <div class="contact__hero-icon" aria-hidden="true">
                <ModuleIcon name="SUP" />
              </div>
              <p class="contact__kicker">{{ t('contact.details') }}</p>
              <h3>{{ productName }}</h3>
              <p>{{ withProduct(t('contact.support')) }}</p>
              <button type="button" class="contact__badge" @click="openSupportBot">
                <span class="contact__badge-bot" aria-hidden="true">
                  <ModuleIcon name="SUP" />
                </span>
                <div>
                  <strong>{{ t('contact.response') }}</strong>
                  <span>{{ t('contact.responseHint') }} · {{ t('contact.responseCta') }}</span>
                </div>
              </button>
            </div>

            <div class="contact__channels">
              <p class="contact__channels-label">{{ t('contact.channels') }}</p>

              <a
                v-if="branding.support_email"
                class="contact__channel glass-card"
                :href="`mailto:${branding.support_email}`"
              >
                <span class="contact__channel-icon contact__channel-icon--mail" aria-hidden="true">
                  <ModuleIcon name="MAIL" />
                </span>
                <span class="contact__channel-copy">
                  <span class="contact__channel-label">{{ t('contact.email') }}</span>
                  <span class="contact__channel-value">{{ branding.support_email }}</span>
                </span>
              </a>

              <a
                v-if="branding.support_phone"
                class="contact__channel glass-card"
                :href="`tel:${branding.support_phone}`"
              >
                <span class="contact__channel-icon contact__channel-icon--phone" aria-hidden="true">
                  <ModuleIcon name="PHONE" />
                </span>
                <span class="contact__channel-copy">
                  <span class="contact__channel-label">{{ t('contact.phone') }}</span>
                  <span class="contact__channel-value">{{ branding.support_phone }}</span>
                </span>
              </a>

              <div class="contact__channel glass-card contact__channel--static">
                <span class="contact__channel-icon contact__channel-icon--tenant" aria-hidden="true">
                  <ModuleIcon name="ORG" />
                </span>
                <span class="contact__channel-copy">
                  <span class="contact__channel-label">{{ t('contact.tenant') }}</span>
                  <span class="contact__channel-value mono">{{ branding.slug }}</span>
                </span>
              </div>

              <p
                v-if="!branding.support_email && !branding.support_phone"
                class="contact__note"
              >
                <strong>{{ t('contact.note') }}</strong>
                {{ t('contact.noteBody') }}
              </p>
            </div>
          </aside>

          <form class="contact__form glass-card" @submit.prevent="submitContact">
            <div class="contact__form-head">
              <div class="contact__form-icon" aria-hidden="true">
                <ModuleIcon name="SEND" />
              </div>
              <div>
                <h3>{{ t('contact.formTitle') }}</h3>
                <p>{{ t('contact.formHint') }}</p>
              </div>
            </div>

            <div class="form-grid">
              <div class="field">
                <label for="contact-name">{{ t('contact.name') }}</label>
                <input id="contact-name" v-model="form.name" type="text" :placeholder="t('contact.namePh')" required />
              </div>
              <div class="field">
                <label for="contact-email">{{ t('contact.yourEmail') }}</label>
                <input id="contact-email" v-model="form.email" type="email" :placeholder="t('contact.emailPh')" required />
              </div>
              <div class="field field--full">
                <label for="contact-subject">{{ t('contact.subject') }}</label>
                <input id="contact-subject" v-model="form.subject" type="text" :placeholder="t('contact.subjectPh')" required />
              </div>
              <div class="field field--full">
                <label for="contact-message">{{ t('contact.message') }}</label>
                <textarea
                  id="contact-message"
                  v-model="form.message"
                  rows="5"
                  :placeholder="t('contact.messagePh')"
                  required
                />
              </div>
            </div>

            <div class="contact__form-foot">
              <button class="btn btn-primary contact__submit" type="submit" :disabled="sending">
                <ModuleIcon name="SEND" />
                {{ sending ? t('contact.sending') : t('contact.send') }}
              </button>
              <p v-if="formStatus === 'ok'" class="form-note">{{ t('contact.ok') }}</p>
              <p v-else-if="formStatus === 'error'" class="form-error">{{ t('contact.error') }}</p>
            </div>
          </form>
        </div>
      </div>
    </section>
  </template>
</template>
