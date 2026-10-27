<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'

export type SplashReport = {
  /** Real milestone from 0 to 1. The bar eases toward it and only reaches 1 when boot resolves. */
  milestone: (ratio: number, step?: number) => void
}

const props = withDefaults(defineProps<{
  brandName: string
  tagline?: string
  logoUrl?: string
  firstName?: string
  companyName?: string
  version?: string
  minDurationMs?: number
  timeoutMs?: number
  messages?: string[]
  boot: (report: SplashReport) => Promise<void>
}>(), {
  tagline: '',
  logoUrl: '',
  firstName: '',
  companyName: '',
  version: '1.0.1',
  minDurationMs: 4500,
  timeoutMs: 10_000,
  messages: () => [],
})

const emit = defineEmits<{ done: [] }>()

const { t } = useI18n()

const PRODUCT_LOGO_URL = '/brand/itara-nexus-logo.png?v=3'

const logoStep = ref(0)
const leaving = ref(false)
const failed = ref(false)
const bootDone = ref(false)
const announced = ref(4)
const retrying = ref(false)
const bar = ref<HTMLElement | null>(null)
const retryButton = ref<HTMLButtonElement | null>(null)

const logoSources = computed(() => {
  const tenant = props.logoUrl.trim()
  return tenant && tenant !== PRODUCT_LOGO_URL ? [tenant, PRODUCT_LOGO_URL] : [PRODUCT_LOGO_URL]
})
const logoSrc = computed(() => logoSources.value[logoStep.value] ?? '')
const mark = computed(() => (props.brandName.trim().charAt(0) || 'I').toUpperCase())
const line = computed(() => props.tagline.trim())
const edition = computed(() => {
  const v = props.version.trim()
  return v ? `v${v.replace(/^v/i, '')}` : ''
})

const statusText = computed(() => {
  if (failed.value) return t('auth.splashError')
  if (bootDone.value) return t('auth.splashStatusReady')
  return t('auth.splashLoadingLabel')
})

watch(() => props.logoUrl, () => { logoStep.value = 0 })

function onLogoError() {
  logoStep.value += 1
}

let frame = 0
let timeoutId = 0
let leaveId = 0
let started = 0
let target = 0.08
let shown = 0.04
let generation = 0
let runId = 0
let reduced = false
let finished = false

function prefersReduced() {
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches
}

function elapsed() {
  return performance.now() - started
}

function milestone(ratio: number, _nextStep?: number) {
  if (failed.value || leaving.value || runId !== generation) return
  target = Math.max(target, Math.min(1, ratio))
}

function applyBar() {
  const value = Math.max(0.04, Math.min(1, shown))
  if (bar.value) bar.value.style.transform = `scaleX(${value})`
  const next = Math.round(value * 100)
  if (next !== announced.value) announced.value = next
}

function stallCap() {
  const waited = Math.max(0, elapsed() - 400)
  return Math.min(0.92, target + (waited / props.timeoutMs) * 0.28)
}

function tick() {
  const timeCap = Math.min(1, Math.max(0.04, elapsed() / props.minDurationMs))
  const cap = bootDone.value ? timeCap : Math.min(stallCap(), timeCap)
  const delta = cap - shown
  if (delta > 0) {
    if (delta < 0.004) shown = cap
    else shown += delta * (reduced ? 1 : 0.16)
  }
  applyBar()

  if (bootDone.value && !failed.value && elapsed() >= props.minDurationMs) {
    shown = 1
    applyBar()
    beginLeave()
    return
  }

  frame = requestAnimationFrame(tick)
}

function stopClock() {
  if (frame) cancelAnimationFrame(frame)
  frame = 0
  window.clearTimeout(timeoutId)
  timeoutId = 0
}

function beginLeave() {
  if (leaving.value || finished || failed.value) return
  stopClock()
  leaving.value = true
  const wait = reduced ? 0 : 320
  leaveId = window.setTimeout(() => {
    if (finished) return
    finished = true
    emit('done')
  }, wait)
}

function fail(gen: number) {
  if (failed.value || gen !== generation) return
  failed.value = true
  bootDone.value = false
  generation += 1
  runId = generation
  stopClock()
  void nextTick(() => retryButton.value?.focus())
}

async function run() {
  const gen = ++generation
  runId = gen
  failed.value = false
  bootDone.value = false
  shown = 0.04
  target = 0.08
  announced.value = 4
  started = performance.now()
  stopClock()
  await nextTick()
  applyBar()

  timeoutId = window.setTimeout(() => {
    if (gen !== generation || bootDone.value || failed.value) return
    fail(gen)
  }, props.timeoutMs)

  frame = requestAnimationFrame(tick)

  try {
    await props.boot({ milestone })
    if (gen !== generation || failed.value) return
    bootDone.value = true
    target = 1
  } catch {
    if (gen !== generation || failed.value) return
    fail(gen)
  }
}

async function retry() {
  if (retrying.value) return
  retrying.value = true
  try {
    await run()
  } finally {
    retrying.value = false
  }
}

onMounted(() => {
  reduced = prefersReduced()
  void run()
})

onBeforeUnmount(() => {
  generation += 1
  stopClock()
  window.clearTimeout(leaveId)
})
</script>

<template>
  <Teleport to="body">
    <div
      class="splash"
      :class="{ 'splash--leaving': leaving, 'splash--failed': failed }"
      :aria-busy="!failed && !leaving"
      aria-labelledby="workspace-splash-title"
    >
      <main class="splash__core">
        <div class="splash__mark" aria-hidden="true">
          <span v-if="!failed" class="splash__orbit" />
          <img
            v-if="logoSrc"
            :key="logoSrc"
            class="splash__logo"
            :src="logoSrc"
            alt=""
            width="168"
            height="168"
            @error="onLogoError"
          />
          <span v-else class="splash__logo splash__glyph">{{ mark }}</span>
        </div>

        <p id="workspace-splash-title" class="splash__name">{{ brandName }}</p>
        <p v-if="line" class="splash__tagline">{{ line }}</p>

        <p v-if="failed" class="splash__alert" role="alert">{{ statusText }}</p>
        <p v-else class="splash__status" role="status" aria-live="polite">{{ statusText }}</p>

        <div
          v-if="!failed"
          class="splash__track"
          role="progressbar"
          aria-valuemin="0"
          aria-valuemax="100"
          :aria-valuenow="announced"
          :aria-label="t('auth.splashLoadingLabel')"
        >
          <span ref="bar" class="splash__track-fill" />
        </div>

        <button
          v-else
          ref="retryButton"
          type="button"
          class="splash__retry"
          :disabled="retrying"
          @click="retry"
        >
          {{ t('auth.splashRetry') }}
        </button>
      </main>

      <footer class="splash__foot">
        <span class="splash__product">ITARA</span>
        <span v-if="edition" class="splash__sep" aria-hidden="true" />
        <span v-if="edition" class="splash__edition">{{ edition }}</span>
      </footer>
    </div>
  </Teleport>
</template>

<style scoped>
.splash {
  --splash-bg: #f6f7f9;
  --splash-ink: #12243c;
  --splash-accent: #e39b2b;
  --splash-muted: #5c6d7c;
  --splash-line: rgba(18, 36, 60, 0.08);

  position: fixed;
  inset: 0;
  z-index: 120;
  box-sizing: border-box;
  display: grid;
  place-items: center;
  width: calc(100vw / var(--ui-zoom, 1));
  min-width: calc(100vw / var(--ui-zoom, 1));
  height: calc(100vh / var(--ui-zoom, 1));
  height: calc(100dvh / var(--ui-zoom, 1));
  min-height: calc(100vh / var(--ui-zoom, 1));
  min-height: calc(100dvh / var(--ui-zoom, 1));
  padding: 2rem 1.25rem 3rem;
  overflow: hidden;
  background: var(--splash-bg);
  color: var(--splash-ink);
  font-family: var(--font-display, "Plus Jakarta Sans", "IBM Plex Sans", sans-serif);
  animation: splash-in 240ms ease-out both;
}

.splash--leaving {
  pointer-events: none;
  animation: splash-out 320ms ease forwards;
}

.splash__core {
  display: grid;
  justify-items: center;
  gap: 0.9rem;
  max-width: min(100%, 34rem);
  text-align: center;
}

.splash__mark {
  position: relative;
  display: grid;
  place-items: center;
  width: 11.5rem;
  height: 11.5rem;
  margin-bottom: 0.9rem;
}

.splash__orbit {
  position: absolute;
  inset: 0;
  border-radius: 50%;
  border: 3px solid var(--splash-line);
  border-top-color: var(--splash-accent);
  border-right-color: var(--splash-ink);
  animation: splash-spin 0.95s cubic-bezier(0.45, 0.05, 0.25, 1) infinite;
}

.splash__logo {
  position: relative;
  z-index: 1;
  box-sizing: border-box;
  width: calc(100% - 8px);
  height: calc(100% - 8px);
  padding: 0;
  border-radius: 50%;
  background: transparent;
  object-fit: cover;
  object-position: center;
}

.splash__glyph {
  display: grid;
  place-items: center;
  font-size: 2.6rem;
  font-weight: 700;
}

.splash__name {
  margin: 0;
  max-width: 100%;
  overflow: hidden;
  font-size: 1.85rem;
  font-weight: 700;
  letter-spacing: -0.02em;
  line-height: 1.25;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.splash__tagline {
  margin: -0.35rem 0 0;
  font-size: 1.1rem;
  line-height: 1.45;
  color: var(--splash-muted);
}

.splash__status {
  margin: 0.25rem 0 0;
  font-size: 0.85rem;
  font-weight: 650;
  letter-spacing: 0.18em;
  text-transform: uppercase;
  color: var(--splash-muted);
}

.splash__alert {
  margin: 0.15rem 0 0;
  max-width: 22rem;
  font-size: 0.95rem;
  font-weight: 500;
  color: #b42318;
}

.splash__track {
  width: 12.5rem;
  height: 4px;
  margin-top: 0.5rem;
  overflow: hidden;
  border-radius: 999px;
  background: var(--splash-line);
}

.splash__track-fill {
  display: block;
  width: 100%;
  height: 100%;
  border-radius: inherit;
  background: var(--splash-accent);
  transform: scaleX(0.04);
  transform-origin: left center;
}

.splash__retry {
  min-height: 44px;
  margin-top: 0.4rem;
  padding: 0 1.4rem;
  border: 1px solid var(--splash-ink);
  border-radius: 999px;
  background: var(--splash-ink);
  color: #fff;
  font: inherit;
  font-size: 0.92rem;
  font-weight: 600;
  cursor: pointer;
  transition: background-color 160ms ease, transform 160ms ease;
}

.splash__retry:hover:not(:disabled) {
  background: #0f1f34;
}

.splash__retry:active:not(:disabled) {
  transform: translateY(1px);
}

.splash__retry:disabled {
  opacity: 0.65;
  cursor: default;
}

.splash__retry:focus-visible {
  outline: 2px solid var(--splash-accent);
  outline-offset: 3px;
}

.splash__foot {
  position: absolute;
  bottom: clamp(1.1rem, 3vh, 2rem);
  left: 50%;
  display: flex;
  align-items: center;
  gap: 0.55rem;
  transform: translateX(-50%);
}

.splash__product,
.splash__edition {
  font-size: 0.72rem;
  font-weight: 600;
  letter-spacing: 0.22em;
  text-transform: uppercase;
  color: rgba(18, 36, 60, 0.5);
}

.splash__sep {
  width: 1px;
  height: 0.7rem;
  background: rgba(18, 36, 60, 0.2);
}

@keyframes splash-spin {
  to { transform: rotate(360deg); }
}

@keyframes splash-in {
  from { opacity: 0; }
}

@keyframes splash-out {
  to { opacity: 0; }
}

@media (prefers-reduced-motion: reduce) {
  .splash,
  .splash--leaving,
  .splash__orbit {
    animation: none;
  }
}
</style>
