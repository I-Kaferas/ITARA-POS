<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRoute } from 'vue-router'
import PageFrame from '../../../components/layout/PageFrame.vue'
import { intlLocale } from '../../../i18n/locales'
import UserGuide from './UserGuide.vue'

const sections = ['guide', 'tutorials', 'faqs', 'support', 'about'] as const
type Section = (typeof sections)[number]

const route = useRoute()
const { t, locale } = useI18n()
const openFaq = ref('q1')
const subject = ref('')
const message = ref('')
const articleQuery = ref('')
const watchingId = ref<string | null>(null)

const section = computed<Section>(() => {
  const value = String(route.params.section || 'guide')
  return (sections as readonly string[]).includes(value) ? (value as Section) : 'guide'
})

function openWatch(id: string) {
  watchingId.value = id
}

function closeWatch() {
  watchingId.value = null
}

function onWatchKey(event: KeyboardEvent) {
  if (event.key === 'Escape') closeWatch()
}

watch(watchingId, (id) => {
  document.body.style.overflow = id ? 'hidden' : ''
  if (id) window.addEventListener('keydown', onWatchKey)
  else window.removeEventListener('keydown', onWatchKey)
})

onBeforeUnmount(() => {
  document.body.style.overflow = ''
  window.removeEventListener('keydown', onWatchKey)
})

watch(section, () => {
  openFaq.value = 'q1'
  articleQuery.value = ''
  closeWatch()
})

const visibleFaqs = computed(() => {
  const q = articleQuery.value.trim().toLowerCase()
  return faqKeys.filter(key => {
    if (!q) return true
    const question = t(`helpCenter.faq.${key}`).toLowerCase()
    const answer = t(`helpCenter.faq.a${key.slice(1)}`).toLowerCase()
    return question.includes(q) || answer.includes(q)
  })
})

function articleDate(iso: string) {
  return new Intl.DateTimeFormat(intlLocale(locale.value), {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  }).format(new Date(`${iso}T12:00:00`))
}

function newsParts(iso: string) {
  const date = new Date(`${iso}T12:00:00`)
  const loc = intlLocale(locale.value)
  return {
    day: new Intl.DateTimeFormat(loc, { day: '2-digit' }).format(date),
    month: new Intl.DateTimeFormat(loc, { month: 'short' }).format(date),
    year: new Intl.DateTimeFormat(loc, { year: 'numeric' }).format(date),
  }
}

const videos = computed(() => [
  {
    id: 'dashboard',
    title: t('helpCenter.videos.dashboard.title'),
    body: t('helpCenter.videos.dashboard.body'),
    date: '2026-03-01',
  },
  {
    id: 'account',
    title: t('helpCenter.videos.account.title'),
    body: t('helpCenter.videos.account.body'),
    date: '2026-03-01',
  },
])

const visibleVideos = computed(() => {
  const q = articleQuery.value.trim().toLowerCase()
  if (!q) return videos.value
  return videos.value.filter(video => `${video.title} ${video.body}`.toLowerCase().includes(q))
})

const watching = computed(() => videos.value.find(video => video.id === watchingId.value) ?? null)

const announcements = computed(() => [
  {
    id: 'performance',
    title: t('helpCenter.announcements.performance.title'),
    body: t('helpCenter.announcements.performance.body'),
    kind: t('helpCenter.kinds.update'),
    tags: ['performance', 'update'],
    date: '2026-03-01',
  },
  {
    id: 'language',
    title: t('helpCenter.announcements.language.title'),
    body: t('helpCenter.announcements.language.body'),
    kind: t('helpCenter.kinds.new'),
    tags: ['language', 'localization', 'new-feature'],
    date: '2026-02-10',
  },
])

const visibleAnnouncements = computed(() => {
  const q = articleQuery.value.trim().toLowerCase()
  if (!q) return announcements.value
  return announcements.value.filter(item =>
    [item.title, item.body, ...item.tags].join(' ').toLowerCase().includes(q),
  )
})
const faqKeys = ['q1', 'q2', 'q3', 'q4', 'q5', 'q6'] as const

const canSend = computed(() => subject.value.trim().length > 0 && message.value.trim().length > 0)

function sendMail() {
  if (!canSend.value) return
  const href = `mailto:?subject=${encodeURIComponent(subject.value.trim())}&body=${encodeURIComponent(message.value.trim())}`
  window.location.href = href
}

function toggleFaq(key: string) {
  openFaq.value = openFaq.value === key ? '' : key
}
</script>

<template>
  <PageFrame>
    <template #title>{{ t(`helpCenter.${section}Title`) }}</template>
    <template #subtitle>{{ t(`helpCenter.${section}Subtitle`) }}</template>

    <div class="help">
      <UserGuide v-if="section === 'guide'" />

      <section v-else-if="section === 'tutorials'" class="help-center">
        <header class="help-center__head">
          <div>
            <h2>{{ t('helpCenter.centerTitle') }}</h2>
            <p>{{ t('helpCenter.tutorialsSubtitle') }}</p>
          </div>
          <label class="help-search">
            <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
              <circle cx="11" cy="11" r="7" />
              <path d="M20 20l-3.5-3.5" stroke-linecap="round" />
            </svg>
            <input v-model="articleQuery" type="search" :placeholder="t('helpCenter.searchPlaceholder')" />
          </label>
        </header>
        <ul v-if="visibleVideos.length" class="help-articles help-videos">
          <li v-for="video in visibleVideos" :key="video.id">
            <button type="button" class="help-poster" :aria-label="t('helpCenter.watchVideo')" @click="openWatch(video.id)">
              <span class="help-video-badge">{{ t('helpCenter.videoBadge') }}</span>
              <span class="help-play" aria-hidden="true">
                <svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor">
                  <path d="M9 7.5v9l8-4.5-8-4.5z" />
                </svg>
              </span>
            </button>
            <div class="help-video-body">
              <h3>{{ video.title }}</h3>
              <p>{{ video.body }}</p>
              <div class="help-articles__meta">
                <time :datetime="video.date">{{ articleDate(video.date) }}</time>
                <button type="button" class="help-watch" @click="openWatch(video.id)">
                  <svg viewBox="0 0 24 24" width="14" height="14" fill="currentColor" aria-hidden="true">
                    <path d="M9 7.5v9l8-4.5-8-4.5z" />
                  </svg>
                  {{ t('helpCenter.watchVideo') }}
                </button>
              </div>
            </div>
          </li>
        </ul>
        <p v-else class="help-empty">{{ t('helpCenter.noArticles') }}</p>
      </section>

      <section v-if="section === 'faqs'" class="help-center">
        <header class="help-center__head">
          <div>
            <h2>{{ t('helpCenter.centerTitle') }}</h2>
            <p>{{ t('helpCenter.faqsSubtitle') }}</p>
          </div>
          <label class="help-search">
            <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
              <circle cx="11" cy="11" r="7" />
              <path d="M20 20l-3.5-3.5" stroke-linecap="round" />
            </svg>
            <input v-model="articleQuery" type="search" :placeholder="t('helpCenter.searchPlaceholder')" />
          </label>
        </header>
        <ul v-if="visibleFaqs.length" class="help-faq-grid">
          <li v-for="(key, index) in visibleFaqs" :key="key" :class="{ 'is-open': openFaq === key }">
            <h3>
              <button type="button" :aria-expanded="openFaq === key" @click="toggleFaq(key)">
                <span class="help-faq-index" aria-hidden="true">{{ String(index + 1).padStart(2, '0') }}</span>
                <span>{{ t(`helpCenter.faq.${key}`) }}</span>
                <svg class="help-faq-chevron" viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
                  <path d="M6 9l6 6 6-6" stroke-linecap="round" stroke-linejoin="round" />
                </svg>
              </button>
            </h3>
            <div class="fold-panel" :class="{ 'is-open': openFaq === key }">
              <div class="fold-panel__body" :inert="openFaq !== key">
                <p>{{ t(`helpCenter.faq.a${key.slice(1)}`) }}</p>
              </div>
            </div>
          </li>
        </ul>
        <p v-else class="help-empty">{{ t('helpCenter.noArticles') }}</p>
      </section>

      <div v-else-if="section === 'support'" class="help-support">
        <section>
          <h2>{{ t('helpCenter.support.channelTitle') }}</h2>
          <p>{{ t('helpCenter.support.channelBody') }}</p>
        </section>
        <form @submit.prevent="sendMail">
          <p>{{ t('helpCenter.support.intro') }}</p>
          <label>
            <span>{{ t('helpCenter.support.subject') }}</span>
            <input v-model="subject" type="text" required :placeholder="t('helpCenter.support.subjectPh')" />
          </label>
          <label>
            <span>{{ t('helpCenter.support.message') }}</span>
            <textarea v-model="message" rows="5" required :placeholder="t('helpCenter.support.messagePh')" />
          </label>
          <button type="submit" :disabled="!canSend">{{ t('helpCenter.support.send') }}</button>
        </form>
      </div>

      <section v-else-if="section === 'about'" class="help-center">
        <header class="help-center__head">
          <div>
            <h2>{{ t('helpCenter.aboutTitle') }}</h2>
            <p>{{ t('helpCenter.aboutSubtitle') }}</p>
          </div>
          <label class="help-search">
            <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
              <circle cx="11" cy="11" r="7" />
              <path d="M20 20l-3.5-3.5" stroke-linecap="round" />
            </svg>
            <input v-model="articleQuery" type="search" :placeholder="t('helpCenter.searchPlaceholder')" />
          </label>
        </header>
        <ol v-if="visibleAnnouncements.length" class="news">
          <li v-for="item in visibleAnnouncements" :key="item.id">
            <time :datetime="item.date">
              <span>{{ newsParts(item.date).month }}</span>
              <strong>{{ newsParts(item.date).day }}</strong>
              <span>{{ newsParts(item.date).year }}</span>
            </time>
            <div class="news__body">
              <span class="news__kind">{{ item.kind }}</span>
              <h3>{{ item.title }}</h3>
              <p>{{ item.body }}</p>
              <ul>
                <li v-for="tag in item.tags" :key="tag">{{ tag }}</li>
              </ul>
            </div>
          </li>
        </ol>
        <p v-else class="help-empty">{{ t('helpCenter.noArticles') }}</p>
      </section>
    </div>

    <Teleport to="body">
      <Transition name="modal">
        <div v-if="watching" class="watch-backdrop" @mousedown.self="closeWatch">
          <div class="watch" role="dialog" aria-modal="true" :aria-labelledby="`watch-${watching.id}`">
            <div class="watch__stage">
              <span class="help-video-badge">{{ t('helpCenter.videoBadge') }}</span>
              <button type="button" class="watch__close" :aria-label="t('common.close')" @click="closeWatch">
                <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
                  <path d="M6 6l12 12M18 6L6 18" stroke-linecap="round" />
                </svg>
              </button>
              <span class="help-play help-play--stage" aria-hidden="true">
                <svg viewBox="0 0 24 24" width="28" height="28" fill="currentColor">
                  <path d="M9 7.5v9l8-4.5-8-4.5z" />
                </svg>
              </span>
            </div>
            <div class="watch__copy">
              <h3 :id="`watch-${watching.id}`">{{ watching.title }}</h3>
              <p>{{ watching.body }}</p>
              <p class="watch__note">{{ t('helpCenter.tutorialNote') }}</p>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>
  </PageFrame>
</template>

<style scoped>
.help {
  display: flex;
  flex-direction: column;
  gap: 12px;
  width: 100%;
}

.help h2 {
  margin: 0;
  color: var(--color-text-primary);
  font-size: 15px;
  font-weight: 750;
  letter-spacing: -0.02em;
}

.help p,
.help li {
  margin: 0;
  color: var(--color-text-muted);
  font-size: 14px;
  line-height: 1.45;
}

.help-lessons,
.help-about ul {
  display: grid;
  gap: 12px;
  margin: 0;
  padding: 0;
  list-style: none;
}

.help-center {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.help-center__head {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-end;
  justify-content: space-between;
  gap: 14px;
}

.help-center h2 {
  font-size: 1.15rem;
}

.help-center__head p {
  margin-top: 4px;
}

.help-search {
  display: flex;
  align-items: center;
  gap: 8px;
  width: min(320px, 100%);
  height: 42px;
  padding: 0 12px;
  border: 1px solid var(--color-border);
  border-radius: 12px;
  background: var(--color-surface);
  color: var(--color-text-muted);
}

.help-search input {
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

.help-articles {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 12px;
  margin: 0;
  padding: 0;
  list-style: none;
}

.help-articles > li {
  display: flex;
  flex-direction: column;
  min-width: 0;
  padding: 16px 18px;
  border: 1px solid var(--color-border);
  border-radius: 16px;
  background: var(--color-surface);
}

.help-articles h3 {
  margin: 0;
  color: var(--color-text-primary);
  font-size: 16px;
  font-weight: 750;
  letter-spacing: -0.02em;
}

.help-articles p {
  margin-top: 6px;
}

.help-articles__meta {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  margin-top: auto;
  padding-top: 14px;
}

.help-articles__meta ul {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin: 0;
  padding: 0;
  list-style: none;
}

.help-articles__meta li {
  padding: 3px 8px;
  border-radius: 999px;
  background: var(--color-canvas);
  color: var(--color-text-muted);
  font-size: 12px;
  font-weight: 650;
}

.help-articles time {
  color: var(--color-text-muted);
  font-size: 12px;
  font-weight: 650;
}

.help-videos {
  grid-template-columns: repeat(auto-fill, minmax(15rem, 17.5rem));
  justify-content: start;
}

.news {
  display: flex;
  flex-direction: column;
  gap: 12px;
  margin: 0;
  padding: 0;
  list-style: none;
}

.news > li {
  display: grid;
  grid-template-columns: 92px minmax(0, 1fr);
  min-width: 0;
  border: 1px solid var(--color-border);
  border-radius: 16px;
  background: var(--color-surface);
  overflow: hidden;
}

.news time {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 2px;
  padding: 16px 8px;
  background: #12243c;
  color: #fff;
  text-align: center;
}

.news time span {
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: rgba(255, 255, 255, 0.72);
}

.news time strong {
  font-size: 1.55rem;
  font-weight: 750;
  letter-spacing: -0.03em;
  line-height: 1;
}

.news__body {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 6px;
  min-width: 0;
  padding: 16px 18px;
}

.news__kind {
  padding: 3px 8px;
  border-radius: 999px;
  background: rgba(227, 155, 43, 0.16);
  color: #9a6412;
  font-size: 11px;
  font-weight: 750;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

.news__body h3 {
  margin: 0;
  color: var(--color-text-primary);
  font-size: 1.05rem;
  font-weight: 750;
  letter-spacing: -0.02em;
}

.news__body p {
  margin: 0;
  max-width: 68ch;
}

.news__body ul {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin: 6px 0 0;
  padding: 0;
  list-style: none;
}

.news__body li {
  padding: 3px 8px;
  border-radius: 999px;
  background: var(--color-canvas);
  color: var(--color-text-muted);
  font-size: 12px;
  font-weight: 650;
}

.help-videos > li {
  padding: 0;
  overflow: hidden;
}

.help-poster {
  position: relative;
  display: grid;
  place-items: center;
  width: 100%;
  aspect-ratio: 16 / 9;
  border: 0;
  border-bottom: 1px solid var(--color-border);
  background: #12243c;
  color: #fff;
  cursor: pointer;
}

.help-play {
  display: grid;
  place-items: center;
  width: 40px;
  height: 40px;
  border-radius: 999px;
  background: #fff;
  color: #12243c;
}

.help-play svg {
  width: 16px;
  height: 16px;
}

.help-poster .help-video-badge {
  position: absolute;
  top: 12px;
  left: 12px;
  margin: 0;
  background: rgba(255, 255, 255, 0.16);
  color: #fff;
}

.help-video-body {
  display: flex;
  flex-direction: column;
  flex: 1;
  gap: 6px;
  padding: 10px 12px 12px;
}

.help-video-body h3 {
  font-size: 14px;
}

.help-video-body p {
  font-size: 12px;
  line-height: 1.4;
}

.help-video-badge {
  display: inline-flex;
  align-items: center;
  width: fit-content;
  padding: 3px 8px;
  border-radius: 999px;
  background: color-mix(in srgb, var(--color-brand-600) 12%, var(--color-canvas));
  color: var(--color-brand-600);
  font-size: 11px;
  font-weight: 750;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.help-video-body .help-articles__meta {
  flex-direction: column;
  align-items: stretch;
  gap: 8px;
  padding-top: 4px;
}

.help-watch {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  width: 100%;
  height: 32px;
  padding: 0 12px;
  border: 0;
  border-radius: 10px;
  background: var(--color-brand-600);
  color: #fff;
  font-size: 12px;
  font-weight: 650;
  line-height: 1;
  cursor: pointer;
  transition: transform 150ms cubic-bezier(0.22, 1, 0.36, 1), background-color 150ms cubic-bezier(0.22, 1, 0.36, 1);
}

.help-watch:hover {
  background: var(--color-brand-700);
  transform: translateY(-1px);
}

.help-watch:active {
  transform: scale(0.98);
}

.help-watch:focus-visible {
  outline: 2px solid var(--color-brand-600);
  outline-offset: 2px;
}

.help-play--stage {
  width: 64px;
  height: 64px;
}

.help-play--stage svg {
  width: 28px;
  height: 28px;
}

.watch-backdrop {
  position: fixed;
  inset: 0;
  z-index: 80;
  display: grid;
  place-items: center;
  padding: 24px;
  background: rgba(18, 36, 60, 0.46);
}

.watch {
  width: min(40rem, 100%);
  overflow: hidden;
  border-radius: 16px;
  background: var(--color-surface);
  box-shadow: 0 24px 60px rgba(18, 36, 60, 0.28);
}

.watch__stage .help-video-badge {
  position: absolute;
  top: 12px;
  left: 12px;
  background: rgba(255, 255, 255, 0.16);
  color: #fff;
}

.watch__stage {
  position: relative;
  display: grid;
  place-items: center;
  aspect-ratio: 16 / 9;
  background:
    radial-gradient(circle at 50% 42%, rgba(240, 160, 16, 0.22), transparent 42%),
    #12243c;
  color: #fff;
}

.watch__close {
  position: absolute;
  top: 12px;
  right: 12px;
  display: grid;
  place-items: center;
  width: 32px;
  height: 32px;
  border: 0;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.16);
  color: #fff;
  cursor: pointer;
}

.watch__close:hover {
  background: rgba(255, 255, 255, 0.28);
}

.watch__copy {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 16px 18px 18px;
}

.watch__copy h3 {
  margin: 0;
  color: var(--color-text-primary);
  font-size: 1.15rem;
  font-weight: 750;
  letter-spacing: -0.02em;
}

.watch__copy p {
  margin: 0;
  color: var(--color-text-muted);
  font-size: 14px;
  line-height: 1.5;
}

.watch__note {
  padding: 10px 12px;
  border-radius: 10px;
  background: var(--color-canvas);
  color: var(--color-text-secondary);
  font-size: 13px;
}

.help-empty {
  margin: 0;
  padding: 28px 16px;
  border: 1px solid var(--color-border);
  border-radius: 16px;
  background: var(--color-surface);
  text-align: center;
}

.help-lessons li,
.help-faqs article,
.help-support section,
.help-support form,
.help-about {
  padding: 16px;
  border: 1px solid var(--color-border);
  border-radius: 16px;
  background: var(--color-surface);
}

.help-steps li {
  display: flex;
  gap: 12px;
  align-items: flex-start;
}

.help-steps li > span {
  display: grid;
  place-items: center;
  width: 28px;
  height: 28px;
  flex: 0 0 auto;
  border-radius: 9px;
  background: var(--color-brand-600);
  color: #fff;
  font-size: 13px;
  font-weight: 750;
}

.help-lessons p,
.help-about p,
.help-support p {
  margin-top: 6px;
}

.help-note {
  margin: 0;
}

.help-lessons {
  grid-template-columns: repeat(3, minmax(0, 1fr));
}

.help-faq-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
  margin: 0;
  padding: 0;
  list-style: none;
  align-items: start;
}

.help-faq-grid > li {
  border: 1px solid var(--color-border);
  border-radius: 16px;
  background: var(--color-surface);
  overflow: hidden;
}

.help-faq-grid > li.is-open {
  border-color: color-mix(in srgb, var(--color-brand-600) 45%, var(--color-border));
}

.help-faq-grid h3 {
  margin: 0;
}

.help-faq-grid button {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr) auto;
  gap: 12px;
  align-items: center;
  width: 100%;
  padding: 16px;
  border: 0;
  background: transparent;
  color: var(--color-text-primary);
  font: inherit;
  font-size: 15px;
  font-weight: 750;
  letter-spacing: -0.02em;
  line-height: 1.35;
  text-align: left;
  cursor: pointer;
}

.help-faq-index {
  display: grid;
  place-items: center;
  width: 32px;
  height: 32px;
  border-radius: 10px;
  background: #12243c;
  color: #fff;
  font-size: 12px;
  font-weight: 750;
}

.help-faq-chevron {
  color: var(--color-text-muted);
  transition: transform 280ms cubic-bezier(0.22, 1, 0.36, 1);
}

.help-faq-grid button[aria-expanded='true'] .help-faq-chevron {
  transform: rotate(180deg);
}

.help-faq-grid p {
  margin: 0;
  padding: 0 16px 16px 60px;
  color: var(--color-text-muted);
  font-size: 14px;
  line-height: 1.5;
}

.help-support {
  display: grid;
  grid-template-columns: minmax(220px, 0.7fr) minmax(0, 1.3fr);
  gap: 12px;
  align-items: start;
}

.help-support form {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.help-support label {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.help-support label span {
  color: var(--color-text-primary);
  font-size: 13px;
  font-weight: 650;
}

.help-support button {
  align-self: flex-start;
  height: 40px;
  padding: 0 14px;
  border: 0;
  border-radius: 12px;
  background: var(--color-brand-600);
  color: #fff;
  font-size: 13px;
  font-weight: 750;
  cursor: pointer;
}

.help-support button:disabled {
  opacity: 0.45;
  cursor: not-allowed;
}

.help-about ul {
  margin-top: 14px;
}

.help-about li {
  padding: 12px 14px;
  border-radius: 12px;
  background: var(--color-canvas);
  color: var(--color-text-primary);
  font-weight: 650;
}

@media (max-width: 1100px) {
  .help-articles {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 900px) {
  .help-lessons,
  .help-support,
  .help-articles,
  .help-faq-grid {
    grid-template-columns: 1fr;
  }

  .help-videos {
    grid-template-columns: repeat(auto-fill, minmax(14rem, 16.5rem));
  }

  .news > li {
    grid-template-columns: 76px minmax(0, 1fr);
  }
}
</style>
