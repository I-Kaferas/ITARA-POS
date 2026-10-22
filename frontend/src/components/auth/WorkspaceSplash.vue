<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref } from 'vue'
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
  minDurationMs: 900,
  timeoutMs: 10_000,
  messages: () => [],
})

const emit = defineEmits<{ done: [] }>()

const { t } = useI18n()

const logoFailed = ref(false)
const leaving = ref(false)
const failed = ref(false)
const bootDone = ref(false)
const announced = ref(4)
const retrying = ref(false)
const bar = ref<HTMLElement | null>(null)
const retryButton = ref<HTMLButtonElement | null>(null)
const showImage = computed(() => Boolean(props.logoUrl) && !logoFailed.value)
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
      <div class="splash__stage" aria-hidden="true">
        <span class="splash__corner splash__corner--tl" />
        <span class="splash__corner splash__corner--tr" />
        <span class="splash__corner splash__corner--bl" />
        <span class="splash__corner splash__corner--br" />
        <span class="splash__rail splash__rail--v splash__rail--left" />
        <span class="splash__rail splash__rail--v splash__rail--right" />
        <span class="splash__rail splash__rail--h splash__rail--top" />
        <span class="splash__rail splash__rail--h splash__rail--bottom" />
      </div>

      <div class="splash__core">
        <div class="splash__mark-wrap" aria-hidden="true">
          <div class="splash__logo">
            <img
              v-if="showImage"
              class="splash__logo-img"
              :src="logoUrl"
              alt=""
              @error="logoFailed = true"
            />
            <span v-else class="splash__glyph">{{ mark }}</span>
          </div>
        </div>

        <p id="workspace-splash-title" class="splash__name">{{ brandName }}</p>
        <span class="splash__rule" aria-hidden="true" />

        <p v-if="line" class="splash__tagline">{{ line }}</p>

        <p
          v-if="failed"
          class="splash__status splash__status--alert"
          role="alert"
        >{{ statusText }}</p>
        <p
          v-else
          class="splash__status"
          role="status"
          aria-live="polite"
        >{{ statusText }}</p>

        <div
          v-if="!failed"
          class="splash__meter"
          role="progressbar"
          aria-valuemin="0"
          aria-valuemax="100"
          :aria-valuenow="announced"
          :aria-label="t('auth.splashLoadingLabel')"
        >
          <span ref="bar" class="splash__meter-fill" />
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
      </div>

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
  --splash-ink: #0a1523;
  --splash-ink-lift: #12243c;
  --splash-paper: #f4f6f8;
  --splash-mute: rgba(244, 246, 248, 0.48);
  --splash-line: rgba(244, 246, 248, 0.14);
  --splash-gold: #e39b2b;
  --splash-ease: cubic-bezier(0.22, 1, 0.36, 1);

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
  padding: clamp(1.5rem, 4vw, 3rem);
  overflow: hidden;
  background: var(--splash-ink);
  color: var(--splash-paper);
  font-family: var(--font-display, "Plus Jakarta Sans", "IBM Plex Sans", sans-serif);
}

.splash--leaving {
  pointer-events: none;
  animation: splash-out 320ms var(--splash-ease) forwards;
}

.splash__stage {
  position: absolute;
  inset: clamp(1rem, 2.8vw, 2rem);
  pointer-events: none;
}

.splash__corner {
  position: absolute;
  width: 1.15rem;
  height: 1.15rem;
  border-color: var(--splash-line);
  border-style: solid;
  border-width: 0;
  opacity: 0;
  animation: splash-rise 700ms var(--splash-ease) 40ms forwards;
}

.splash__corner--tl {
  top: 0;
  left: 0;
  border-top-width: 1px;
  border-left-width: 1px;
}

.splash__corner--tr {
  top: 0;
  right: 0;
  border-top-width: 1px;
  border-right-width: 1px;
}

.splash__corner--bl {
  bottom: 0;
  left: 0;
  border-bottom-width: 1px;
  border-left-width: 1px;
}

.splash__corner--br {
  bottom: 0;
  right: 0;
  border-bottom-width: 1px;
  border-right-width: 1px;
}

.splash__rail {
  position: absolute;
  background: var(--splash-line);
  opacity: 0;
  animation: splash-fade 900ms var(--splash-ease) 120ms forwards;
}

.splash__rail--v {
  top: 1.65rem;
  bottom: 1.65rem;
  width: 1px;
}

.splash__rail--h {
  left: 1.65rem;
  right: 1.65rem;
  height: 1px;
}

.splash__rail--left { left: 0; }
.splash__rail--right { right: 0; }
.splash__rail--top { top: 0; }
.splash__rail--bottom { bottom: 0; }

.splash__core {
  position: relative;
  z-index: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  width: min(100%, 28rem);
  text-align: center;
}

.splash__mark-wrap {
  margin-bottom: 1.65rem;
  opacity: 0;
  animation: splash-rise 720ms var(--splash-ease) 80ms forwards;
}

.splash__logo {
  display: grid;
  place-items: center;
  width: 4.25rem;
  height: 4.25rem;
  border: 1px solid var(--splash-line);
  background: var(--splash-ink-lift);
}

.splash__logo-img {
  display: block;
  width: 2.55rem;
  height: 2.55rem;
  object-fit: contain;
}

.splash__glyph {
  font-size: 1.55rem;
  font-weight: 600;
  letter-spacing: 0.04em;
  color: var(--splash-paper);
  line-height: 1;
}

.splash__name {
  margin: 0;
  max-width: 100%;
  font-size: clamp(1.85rem, 4.2vw, 2.85rem);
  font-weight: 650;
  letter-spacing: -0.045em;
  line-height: 1.05;
  color: var(--splash-paper);
  opacity: 0;
  animation: splash-rise 760ms var(--splash-ease) 160ms forwards;
}

.splash__rule {
  display: block;
  width: 2rem;
  height: 2px;
  margin-top: 1.15rem;
  background: var(--splash-gold);
  opacity: 0;
  animation: splash-rule 700ms var(--splash-ease) 280ms forwards;
}

.splash__tagline {
  margin: 0.95rem 0 0;
  max-width: 22rem;
  font-size: 0.95rem;
  font-weight: 450;
  letter-spacing: 0.01em;
  line-height: 1.45;
  color: var(--splash-mute);
  opacity: 0;
  animation: splash-rise 720ms var(--splash-ease) 320ms forwards;
}

.splash__status {
  margin: 1.35rem 0 0;
  font-size: 0.72rem;
  font-weight: 550;
  letter-spacing: 0.18em;
  text-transform: uppercase;
  color: var(--splash-mute);
  opacity: 0;
  animation: splash-rise 700ms var(--splash-ease) 380ms forwards;
}

.splash__status--alert {
  color: #f0b4af;
  letter-spacing: 0.08em;
  text-transform: none;
  font-size: 0.9rem;
}

.splash__meter {
  width: 9.5rem;
  height: 1px;
  margin-top: 1.45rem;
  overflow: hidden;
  background: rgba(244, 246, 248, 0.16);
  opacity: 0;
  animation: splash-fade 700ms var(--splash-ease) 420ms forwards;
}

.splash__meter-fill {
  display: block;
  width: 100%;
  height: 100%;
  background: var(--splash-paper);
  transform: scaleX(0.04);
  transform-origin: left center;
}

.splash__retry {
  margin-top: 1.4rem;
  padding: 0.72rem 1.35rem;
  border: 1px solid rgba(244, 246, 248, 0.28);
  background: var(--splash-paper);
  color: var(--splash-ink);
  font: inherit;
  font-size: 0.88rem;
  font-weight: 650;
  letter-spacing: 0.02em;
  cursor: pointer;
  opacity: 0;
  animation: splash-rise 560ms var(--splash-ease) 120ms forwards;
}

.splash__retry:disabled {
  opacity: 0.65;
  cursor: default;
}

.splash__retry:focus-visible {
  outline: 2px solid var(--splash-gold);
  outline-offset: 3px;
}

.splash__foot {
  position: absolute;
  bottom: clamp(1.35rem, 3.5vh, 2.4rem);
  left: 50%;
  z-index: 1;
  display: flex;
  align-items: center;
  gap: 0.55rem;
  transform: translateX(-50%);
  opacity: 0;
  animation: splash-fade 800ms var(--splash-ease) 480ms forwards;
}

.splash__product {
  font-size: 0.68rem;
  font-weight: 650;
  letter-spacing: 0.28em;
  text-transform: uppercase;
  color: rgba(244, 246, 248, 0.38);
}

.splash__sep {
  width: 1px;
  height: 0.7rem;
  background: rgba(244, 246, 248, 0.22);
}

.splash__edition {
  font-size: 0.68rem;
  font-weight: 500;
  letter-spacing: 0.12em;
  color: rgba(244, 246, 248, 0.32);
}

@keyframes splash-rise {
  from {
    opacity: 0;
    transform: translateY(10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

@keyframes splash-fade {
  from { opacity: 0; }
  to { opacity: 1; }
}

@keyframes splash-rule {
  from {
    opacity: 0;
    transform: scaleX(0.2);
  }
  to {
    opacity: 1;
    transform: scaleX(1);
  }
}

@keyframes splash-out {
  to {
    opacity: 0;
    transform: scale(1.015);
  }
}

@media (prefers-reduced-motion: reduce) {
  .splash__corner,
  .splash__rail,
  .splash__mark-wrap,
  .splash__name,
  .splash__rule,
  .splash__tagline,
  .splash__status,
  .splash__meter,
  .splash__retry,
  .splash__foot {
    animation: none;
    opacity: 1;
    transform: none;
  }

  .splash--leaving {
    animation: none;
  }
}
</style>
