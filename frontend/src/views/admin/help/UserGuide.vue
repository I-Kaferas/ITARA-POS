<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import AppIcon from '../../../components/ui/AppIcon.vue'
import {
  guideChapters as frChapters,
  hotelQuickStart as frHotelQuickStart,
  quickStart as frQuickStart,
  type GuideChapter,
  type GuideTopic,
} from './userGuide.fr'
import { guideChapters as enChapters, hotelQuickStart as enHotelQuickStart, quickStart as enQuickStart } from './userGuide.en'
import { guideChapters as swChapters, hotelQuickStart as swHotelQuickStart, quickStart as swQuickStart } from './userGuide.sw'

const packs = {
  fr: { chapters: frChapters, quickStart: frQuickStart, hotelQuickStart: frHotelQuickStart },
  en: { chapters: enChapters, quickStart: enQuickStart, hotelQuickStart: enHotelQuickStart },
  sw: { chapters: swChapters, quickStart: swQuickStart, hotelQuickStart: swHotelQuickStart },
} as const

const { t, locale } = useI18n()
const pack = computed(() => packs[locale.value as keyof typeof packs] ?? packs.fr)
const quickStart = computed(() => pack.value.quickStart)
const hotelQuickStart = computed(() => pack.value.hotelQuickStart)
const query = ref('')
const activeId = ref(pack.value.chapters[0]?.id ?? '')
const root = ref<HTMLElement | null>(null)
let observer: IntersectionObserver | null = null

function normalize(value: string) {
  return value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase()
}

function topicText(chapter: GuideChapter, topic: GuideTopic) {
  return normalize([
    chapter.title,
    topic.title,
    topic.summary,
    ...(topic.steps ?? []),
    ...(topic.tips ?? []),
    topic.warning ?? '',
  ].join(' '))
}

const terms = computed(() => normalize(query.value).split(/\s+/).filter(Boolean))
const searching = computed(() => terms.value.length > 0)

const chapters = computed(() => {
  const guideChapters = pack.value.chapters
  if (!searching.value) return guideChapters
  return guideChapters
    .map(chapter => ({
      ...chapter,
      topics: chapter.topics.filter(topic => {
        const text = topicText(chapter, topic)
        return terms.value.every(term => text.includes(term))
      }),
    }))
    .filter(chapter => chapter.topics.length > 0)
})

const resultCount = computed(() => chapters.value.reduce((sum, chapter) => sum + chapter.topics.length, 0))

/** Splits a sentence so the « screen labels » can be styled without v-html. */
function segments(text: string) {
  return text.split(/(«[^»]*»)/g).filter(Boolean).map(part => ({
    text: part.startsWith('«') ? part.slice(1, -1).trim() : part,
    label: part.startsWith('«'),
  }))
}

function scrollTo(id: string) {
  activeId.value = id
  root.value?.querySelector(`[data-guide-id="${id}"]`)?.scrollIntoView({ behavior: 'smooth', block: 'start' })
}

function printGuide() {
  window.print()
}

function observe() {
  observer?.disconnect()
  if (!root.value || typeof IntersectionObserver === 'undefined') return
  observer = new IntersectionObserver(
    (entries) => {
      const visible = entries
        .filter(entry => entry.isIntersecting)
        .sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top)
      const id = (visible[0]?.target as HTMLElement | undefined)?.dataset.guideId
      if (id) activeId.value = id
    },
    { rootMargin: '0px 0px -70% 0px', threshold: 0 },
  )
  root.value.querySelectorAll<HTMLElement>('.guide-chapter').forEach(el => observer?.observe(el))
}

watch(chapters, () => nextTick(observe))
onMounted(observe)
onBeforeUnmount(() => observer?.disconnect())
</script>

<template>
  <div ref="root" class="guide">
    <header class="guide-head">
      <label class="guide-search">
        <AppIcon name="search" :size="16" />
        <input v-model="query" type="search" :placeholder="t('helpCenter.userGuide.searchPlaceholder')" />
      </label>
      <button type="button" class="guide-print" @click="printGuide">
        <AppIcon name="download" :size="16" />
        {{ t('helpCenter.userGuide.print') }}
      </button>
    </header>

    <div class="guide-layout">
      <nav class="guide-toc" :aria-label="t('helpCenter.userGuide.toc')">
        <p class="guide-toc__label">{{ t('helpCenter.userGuide.toc') }}</p>
        <ul>
          <li v-if="!searching">
            <button type="button" :class="{ 'is-active': activeId === 'quick-start' }" @click="scrollTo('quick-start')">
              <AppIcon name="sparkles" :size="16" />
              <span>{{ t('helpCenter.userGuide.quickStart') }}</span>
            </button>
          </li>
          <li v-if="!searching">
            <button type="button" :class="{ 'is-active': activeId === 'hotel-start' }" @click="scrollTo('hotel-start')">
              <AppIcon name="bed" :size="16" />
              <span>{{ t('helpCenter.userGuide.hotelQuickStart') }}</span>
            </button>
          </li>
          <li v-for="chapter in chapters" :key="chapter.id">
            <button type="button" :class="{ 'is-active': activeId === chapter.id }" @click="scrollTo(chapter.id)">
              <AppIcon :name="chapter.icon" :size="16" />
              <span>{{ chapter.title }}</span>
              <small>{{ chapter.topics.length }}</small>
            </button>
          </li>
        </ul>
      </nav>

      <div class="guide-body">
        <p v-if="searching" class="guide-results">
          {{ resultCount ? t('helpCenter.userGuide.results', { count: resultCount }) : t('helpCenter.userGuide.noResults') }}
        </p>

        <section v-if="!searching" class="guide-chapter guide-quick" data-guide-id="quick-start">
          <header class="guide-chapter__head">
            <span class="guide-chapter__icon"><AppIcon name="sparkles" :size="20" /></span>
            <div>
              <h2>{{ t('helpCenter.userGuide.quickStart') }}</h2>
              <p>{{ t('helpCenter.userGuide.quickStartIntro') }}</p>
            </div>
          </header>
          <ol class="guide-quick__list">
            <li v-for="(step, index) in quickStart" :key="step.route + index">
              <span class="guide-num">{{ index + 1 }}</span>
              <div>
                <strong>{{ step.title }}</strong>
                <p>
                  <template v-for="(part, i) in segments(step.text)" :key="i">
                    <span v-if="part.label" class="guide-ui">{{ part.text }}</span>
                    <template v-else>{{ part.text }}</template>
                  </template>
                </p>
              </div>
              <RouterLink :to="step.route" class="guide-link" :aria-label="`${t('helpCenter.userGuide.openPage')} : ${step.title}`">
                <AppIcon name="chevron-right" :size="16" />
              </RouterLink>
            </li>
          </ol>
        </section>

        <section v-if="!searching" class="guide-chapter guide-quick" data-guide-id="hotel-start">
          <header class="guide-chapter__head">
            <span class="guide-chapter__icon"><AppIcon name="bed" :size="20" /></span>
            <div>
              <h2>{{ t('helpCenter.userGuide.hotelQuickStart') }}</h2>
              <p>{{ t('helpCenter.userGuide.hotelQuickStartIntro') }}</p>
            </div>
          </header>
          <ol class="guide-quick__list">
            <li v-for="(step, index) in hotelQuickStart" :key="step.route + index">
              <span class="guide-num">{{ index + 1 }}</span>
              <div>
                <strong>{{ step.title }}</strong>
                <p>
                  <template v-for="(part, i) in segments(step.text)" :key="i">
                    <span v-if="part.label" class="guide-ui">{{ part.text }}</span>
                    <template v-else>{{ part.text }}</template>
                  </template>
                </p>
              </div>
              <RouterLink :to="step.route" class="guide-link" :aria-label="`${t('helpCenter.userGuide.openPage')} : ${step.title}`">
                <AppIcon name="chevron-right" :size="16" />
              </RouterLink>
            </li>
          </ol>
        </section>

        <section
          v-for="chapter in chapters"
          :key="chapter.id"
          class="guide-chapter"
          :data-guide-id="chapter.id"
        >
          <header class="guide-chapter__head">
            <span class="guide-chapter__icon"><AppIcon :name="chapter.icon" :size="20" /></span>
            <div>
              <h2>{{ chapter.title }}</h2>
              <p>{{ chapter.intro }}</p>
            </div>
          </header>

          <article v-for="topic in chapter.topics" :key="topic.id" class="guide-topic">
            <div class="guide-topic__head">
              <h3>{{ topic.title }}</h3>
              <RouterLink v-if="topic.route" :to="topic.route" class="guide-open">
                {{ t('helpCenter.userGuide.openPage') }}
                <AppIcon name="chevron-right" :size="14" />
              </RouterLink>
            </div>
            <p class="guide-topic__summary">
              <template v-for="(part, i) in segments(topic.summary)" :key="i">
                <span v-if="part.label" class="guide-ui">{{ part.text }}</span>
                <template v-else>{{ part.text }}</template>
              </template>
            </p>

            <ol v-if="topic.steps?.length" class="guide-steps">
              <li v-for="(step, index) in topic.steps" :key="index">
                <span class="guide-num">{{ index + 1 }}</span>
                <p>
                  <template v-for="(part, i) in segments(step)" :key="i">
                    <span v-if="part.label" class="guide-ui">{{ part.text }}</span>
                    <template v-else>{{ part.text }}</template>
                  </template>
                </p>
              </li>
            </ol>

            <div v-for="(tip, index) in topic.tips ?? []" :key="`tip-${index}`" class="guide-callout guide-callout--tip">
              <AppIcon name="info" :size="16" />
              <p>
                <strong>{{ t('helpCenter.userGuide.tip') }} : </strong>
                <template v-for="(part, i) in segments(tip)" :key="i">
                  <span v-if="part.label" class="guide-ui">{{ part.text }}</span>
                  <template v-else>{{ part.text }}</template>
                </template>
              </p>
            </div>

            <div v-if="topic.warning" class="guide-callout guide-callout--warn">
              <AppIcon name="alert" :size="16" />
              <p>
                <strong>{{ t('helpCenter.userGuide.warning') }} : </strong>
                <template v-for="(part, i) in segments(topic.warning)" :key="i">
                  <span v-if="part.label" class="guide-ui">{{ part.text }}</span>
                  <template v-else>{{ part.text }}</template>
                </template>
              </p>
            </div>
          </article>
        </section>
      </div>
    </div>
  </div>
</template>

<style scoped>
.guide {
  --guide-accent: #12243c;
  --guide-gold: #e39b2b;
  --guide-on-accent: #fff;
  --guide-card: 0 1px 2px rgba(15, 23, 42, 0.04), 0 14px 32px -18px rgba(15, 23, 42, 0.18);
  display: flex;
  flex-direction: column;
  gap: 1rem;
  width: 100%;
  min-width: 0;
}

html[data-theme="dark"] .guide {
  --guide-accent: var(--color-accent, #f5a524);
  --guide-on-accent: #0f172a;
}

.guide-head {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: flex-start;
  gap: 12px;
  padding: 0.85rem 1rem;
  border: 1px solid rgba(15, 23, 42, 0.06);
  border-radius: 20px;
  background: #fff;
  box-shadow: var(--guide-card);
}

.guide-search {
  display: flex;
  align-items: center;
  gap: 8px;
  width: min(30rem, 100%);
  height: 42px;
  padding: 0 12px;
  border: 1px solid var(--color-border);
  border-radius: 12px;
  background: var(--color-canvas, #f6f7f9);
  color: var(--color-text-muted);
}

.guide-search:focus-within {
  border-color: var(--guide-accent);
}

.guide-search input {
  width: 100%;
  height: auto;
  min-height: 0;
  padding: 0;
  border: 0;
  outline: none;
  background: transparent;
  color: var(--color-text-primary);
  font-size: 14px;
}

.guide-print {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  height: 42px;
  padding: 0 16px;
  border: 0;
  border-radius: 12px;
  background: #12243c;
  color: #fff;
  font-size: 13px;
  font-weight: 650;
  cursor: pointer;
}

.guide-print:hover {
  background: #1b3354;
}

.guide-lang {
  display: flex;
  align-items: center;
  gap: 8px;
  margin: 0;
  padding: 10px 14px;
  border-radius: 12px;
  background: var(--color-accent-soft, var(--color-canvas));
  color: var(--color-text-secondary);
  font-size: 13px;
}

.guide-layout {
  display: grid;
  grid-template-columns: 17.5rem minmax(0, 1fr);
  gap: 20px;
  align-items: start;
}

.guide-toc {
  position: sticky;
  top: 12px;
  max-height: calc(100dvh / var(--ui-zoom, 1) - 8rem);
  overflow-y: auto;
  padding: 14px;
  border: 1px solid rgba(15, 23, 42, 0.06);
  border-radius: 20px;
  background: #fff;
  box-shadow: var(--guide-card);
}

.guide-toc__label {
  margin: 4px 8px 8px;
  color: var(--color-text-muted);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.guide-toc ul {
  display: flex;
  flex-direction: column;
  gap: 2px;
  margin: 0;
  padding: 0;
  list-style: none;
}

.guide-toc button {
  display: flex;
  align-items: center;
  gap: 10px;
  width: 100%;
  padding: 7px 10px;
  border: 0;
  border-radius: 10px;
  background: transparent;
  color: var(--color-text-secondary);
  font: inherit;
  font-size: 13.5px;
  font-weight: 550;
  text-align: left;
  cursor: pointer;
}

.guide-toc button span {
  flex: 1;
  min-width: 0;
}

.guide-toc button small {
  color: var(--color-text-muted);
  font-size: 11px;
  font-weight: 650;
}

.guide-toc button:hover {
  background: var(--color-canvas);
  color: var(--color-text-primary);
}

.guide-toc button.is-active {
  background: #12243c;
  color: #fff;
}

.guide-toc button.is-active small {
  color: inherit;
  opacity: 0.75;
}

.guide-body {
  display: flex;
  flex-direction: column;
  gap: 20px;
  min-width: 0;
}

.guide-results {
  margin: 0;
  color: var(--color-text-muted);
  font-size: 13px;
  font-weight: 600;
}

.guide-chapter {
  display: flex;
  flex-direction: column;
  gap: 12px;
  scroll-margin-top: 12px;
}

.guide-chapter__head {
  display: flex;
  align-items: flex-start;
  gap: 14px;
  padding: 4px 2px;
}

.guide-chapter__icon {
  display: grid;
  place-items: center;
  flex: 0 0 auto;
  width: 42px;
  height: 42px;
  border-radius: 12px;
  background: #12243c;
  color: #fff;
  box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.16), 0 6px 14px -6px rgba(18, 36, 60, 0.45);
}

.guide-body > .guide-chapter:nth-of-type(6n + 1) .guide-chapter__icon { background: #6366f1; }
.guide-body > .guide-chapter:nth-of-type(6n + 2) .guide-chapter__icon { background: #ea8a12; }
.guide-body > .guide-chapter:nth-of-type(6n + 3) .guide-chapter__icon { background: #f0643f; }
.guide-body > .guide-chapter:nth-of-type(6n + 4) .guide-chapter__icon { background: #0d9488; }
.guide-body > .guide-chapter:nth-of-type(6n + 5) .guide-chapter__icon { background: #2f6fed; }
.guide-body > .guide-chapter:nth-of-type(6n + 6) .guide-chapter__icon { background: #12243c; }
.guide-quick .guide-chapter__icon { background: #e39b2b; color: #12243c; }

.guide-chapter__head h2 {
  margin: 0;
  color: var(--color-text-primary);
  font-size: 1.25rem;
  font-weight: 750;
  letter-spacing: -0.02em;
}

.guide-chapter__head p {
  margin: 4px 0 0;
  max-width: 72ch;
  color: var(--color-text-muted);
  font-size: 14px;
  line-height: 1.5;
}

.guide-topic,
.guide-quick__list {
  padding: 18px 20px;
  border: 1px solid rgba(15, 23, 42, 0.06);
  border-radius: 20px;
  background: #fff;
  box-shadow: var(--guide-card);
}

.guide-topic {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.guide-topic__head {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 8px 12px;
}

.guide-topic h3 {
  margin: 0;
  color: var(--color-text-primary);
  font-size: 1.02rem;
  font-weight: 700;
  letter-spacing: -0.01em;
}

.guide-open {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 5px 10px;
  border-radius: 999px;
  background: rgba(227, 155, 43, 0.16);
  color: #12243c;
  font-size: 12.5px;
  font-weight: 650;
  text-decoration: none;
  white-space: nowrap;
}

.guide-open:hover {
  background: #12243c;
  color: #fff;
}

.guide-topic__summary {
  margin: 0;
  color: var(--color-text-secondary);
  font-size: 14px;
  line-height: 1.55;
}

.guide-steps,
.guide-quick__list {
  display: flex;
  flex-direction: column;
  gap: 10px;
  margin: 0;
  list-style: none;
}

.guide-steps {
  padding: 4px 0 0;
}

.guide-steps li,
.guide-quick__list li {
  display: flex;
  align-items: flex-start;
  gap: 12px;
}

.guide-steps p,
.guide-quick__list p {
  margin: 0;
  color: var(--color-text-primary);
  font-size: 14px;
  line-height: 1.55;
}

.guide-num {
  display: grid;
  place-items: center;
  flex: 0 0 auto;
  width: 26px;
  height: 26px;
  margin-top: -1px;
  border-radius: 8px;
  background: rgba(227, 155, 43, 0.16);
  color: #12243c;
  font-size: 12.5px;
  font-weight: 750;
}

.guide-ui {
  display: inline;
  padding: 1px 4px;
  border-radius: 5px;
  background: var(--color-canvas);
  color: var(--color-text-primary);
  font-weight: 650;
  white-space: normal;
  box-decoration-break: clone;
  -webkit-box-decoration-break: clone;
}

.guide-quick__list li {
  align-items: center;
  padding-bottom: 10px;
  border-bottom: 1px solid var(--color-border);
}

.guide-quick__list li:last-child {
  padding-bottom: 0;
  border-bottom: 0;
}

.guide-quick__list li > div {
  flex: 1;
  min-width: 0;
}

.guide-quick__list strong {
  display: block;
  color: var(--color-text-primary);
  font-size: 14px;
  font-weight: 700;
}

.guide-quick__list p {
  margin-top: 2px;
  color: var(--color-text-muted);
  font-size: 13px;
}

.guide-quick .guide-num {
  background: #12243c;
  color: #fff;
}

.guide-link {
  display: grid;
  place-items: center;
  flex: 0 0 auto;
  width: 32px;
  height: 32px;
  border: 1px solid var(--color-border);
  border-radius: 999px;
  color: var(--color-text-muted);
}

.guide-link:hover {
  border-color: #12243c;
  background: #12243c;
  color: #fff;
}

.guide-callout {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  padding: 10px 12px;
  border-radius: 10px;
  border-left: 3px solid;
}

.guide-callout svg {
  flex: 0 0 auto;
  margin-top: 2px;
}

.guide-callout p {
  margin: 0;
  color: var(--color-text-primary);
  font-size: 13.5px;
  line-height: 1.5;
}

.guide-callout--tip {
  border-color: #12243c;
  background: rgba(18, 36, 60, 0.05);
  color: #12243c;
}

.guide-callout--warn {
  border-color: #d97706;
  background: color-mix(in srgb, #f59e0b 12%, var(--color-surface));
  color: #b45309;
}

.guide-callout .guide-ui {
  background: var(--color-surface);
}

@media (max-width: 960px) {
  .guide-layout {
    grid-template-columns: minmax(0, 1fr);
  }

  .guide-toc {
    position: static;
    max-height: none;
  }

  .guide-toc ul {
    flex-direction: row;
    flex-wrap: wrap;
  }

  .guide-toc li {
    flex: 1 1 12rem;
  }
}

@media print {
  .guide-head,
  .guide-toc,
  .guide-lang,
  .guide-open,
  .guide-link {
    display: none !important;
  }

  .guide-layout {
    display: block;
  }

  .guide-chapter {
    break-before: page;
  }

  .guide-chapter:first-child {
    break-before: auto;
  }

  .guide-topic {
    break-inside: avoid;
    border-color: #ccc;
  }

  .guide-chapter__icon,
  .guide-quick .guide-num {
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
  }
}
</style>

<style>
@media print {
  html:has(.guide) {
    zoom: 1;
  }

  html:has(.guide),
  html:has(.guide) body,
  html:has(.guide) #app,
  .app-shell:has(.guide),
  .app-main:has(.guide),
  .app-content:has(.guide),
  .page-stage:has(.guide) {
    height: auto !important;
    max-height: none !important;
    overflow: visible !important;
  }

  .app-shell:has(.guide) :is(.app-sidebar, .app-sidebar-backdrop, .app-topbar) {
    display: none !important;
  }
}
</style>
