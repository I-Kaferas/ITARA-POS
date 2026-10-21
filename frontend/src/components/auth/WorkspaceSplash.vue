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
  const wait = reduced ? 0 : 220
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
      :class="{ 'splash--leaving': leaving }"
      :aria-busy="!failed && !leaving"
      aria-labelledby="workspace-splash-title"
    >
      <div class="splash__card">
        <div class="splash__logo" aria-hidden="true">
          <img
            v-if="showImage"
            class="splash__logo-img"
            :src="logoUrl"
            alt=""
            @error="logoFailed = true"
          />
          <span v-else class="splash__mark">{{ mark }}</span>
        </div>

        <p id="workspace-splash-title" class="splash__name">{{ brandName }}</p>

        <p v-if="failed" class="splash__status" role="alert">{{ statusText }}</p>
        <p v-else class="splash__status" role="status" aria-live="polite">{{ statusText }}</p>

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
    </div>
  </Teleport>
</template>

<style scoped>
.splash {
  position: fixed;
  top: 0;
  left: 0;
  z-index: 120;
  box-sizing: border-box;
  display: grid;
  place-items: center;
  /* html zoom shrinks 100vh, so divide it back out to cover the real window. */
  width: calc(100vw / var(--ui-zoom, 1));
  min-width: calc(100vw / var(--ui-zoom, 1));
  height: calc(100vh / var(--ui-zoom, 1));
  height: calc(100dvh / var(--ui-zoom, 1));
  min-height: calc(100vh / var(--ui-zoom, 1));
  min-height: calc(100dvh / var(--ui-zoom, 1));
  padding: 1.5rem;
  overflow: hidden;
  background: #e7edf3;
  color: #12243c;
}

.splash--leaving {
  pointer-events: none;
  animation: splash-out 220ms ease forwards;
}

.splash__card {
  display: flex;
  flex-direction: column;
  align-items: center;
  width: min(100%, 18rem);
  text-align: center;
}

.splash__logo {
  display: grid;
  place-items: center;
  width: 3.25rem;
  height: 3.25rem;
  margin-bottom: 0.9rem;
  border-radius: 0.8rem;
  background: #fff;
  box-shadow: 0 1px 2px rgba(18, 36, 60, 0.08);
}

.splash__logo-img {
  display: block;
  width: 2.1rem;
  height: 2.1rem;
  object-fit: contain;
}

.splash__mark {
  font-size: 1.15rem;
  font-weight: 650;
  color: #12243c;
}

.splash__name {
  margin: 0;
  font-size: 1.15rem;
  font-weight: 650;
  letter-spacing: -0.02em;
  line-height: 1.25;
  color: #12243c;
}

.splash__status {
  margin: 0.4rem 0 0;
  font-size: 0.9rem;
  line-height: 1.4;
  color: #5c6b7a;
}

.splash__meter {
  width: 8.5rem;
  height: 3px;
  margin-top: 1.1rem;
  overflow: hidden;
  border-radius: 999px;
  background: rgba(18, 36, 60, 0.12);
}

.splash__meter-fill {
  display: block;
  width: 100%;
  height: 100%;
  border-radius: inherit;
  background: #12243c;
  transform: scaleX(0.04);
  transform-origin: left center;
}

.splash__retry {
  margin-top: 1rem;
  padding: 0.55rem 0.9rem;
  border: 0;
  border-radius: 8px;
  background: #12243c;
  color: #fff;
  font: inherit;
  font-size: 0.9rem;
  font-weight: 600;
  cursor: pointer;
}

.splash__retry:disabled {
  opacity: 0.7;
  cursor: default;
}

@keyframes splash-out {
  to { opacity: 0; }
}

@media (prefers-reduced-motion: reduce) {
  .splash--leaving {
    animation: none;
  }
}
</style>
