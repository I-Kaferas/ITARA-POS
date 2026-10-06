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
  minDurationMs: 1500,
  timeoutMs: 10_000,
  messages: () => [],
})

const emit = defineEmits<{ done: [] }>()

const { t } = useI18n()

const logoFailed = ref(false)
const leaving = ref(false)
const failed = ref(false)
const bootDone = ref(false)
const step = ref(0)
const announced = ref(4)
const retrying = ref(false)
const bar = ref<HTMLElement | null>(null)
const retryButton = ref<HTMLButtonElement | null>(null)
const longName = computed(() => props.brandName.trim().length > 18)
const showImage = computed(() => Boolean(props.logoUrl) && !logoFailed.value)

const lines = computed(() => {
  if (props.messages.length > 0) return props.messages
  return [
    t('auth.splashStatusSecure'),
    t('auth.splashStatusModules'),
    t('auth.splashStatusWorkspace'),
  ]
})

const statusText = computed(() => {
  if (failed.value) return t('auth.splashError')
  if (bootDone.value) return t('auth.splashStatusReady')
  const list = lines.value
  return list[Math.min(step.value, list.length - 1)] ?? ''
})

const welcomeText = computed(() =>
  props.firstName
    ? t('auth.splashWelcome', { name: props.firstName })
    : t('auth.splashWelcomePlain'),
)

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

function milestone(ratio: number, nextStep?: number) {
  if (failed.value || leaving.value || runId !== generation) return
  const next = Math.max(target, Math.min(1, ratio))
  target = next
  if (typeof nextStep === 'number') step.value = nextStep
  else if (next >= 0.9) step.value = 2
  else if (next >= 0.45) step.value = 1
  else step.value = 0
}

function applyBar() {
  const value = Math.max(0.04, Math.min(1, shown))
  if (bar.value) bar.value.style.transform = `scaleX(${value})`
  const next = Math.round(value * 100)
  if (next !== announced.value) announced.value = next
}

function stallCap() {
  const waited = Math.max(0, elapsed() - 500)
  return Math.min(0.92, target + (waited / props.timeoutMs) * 0.28)
}

function tick() {
  const cap = bootDone.value ? 1 : stallCap()
  const delta = cap - shown
  if (Math.abs(delta) < 0.004) shown = cap
  else shown += delta * (reduced ? 1 : 0.085)
  applyBar()

  if (bootDone.value && !failed.value && shown >= 0.985 && elapsed() >= props.minDurationMs) {
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
  const wait = reduced ? 0 : 380
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
  step.value = 0
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
    step.value = Math.max(step.value, 2)
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
      <div class="splash__motif" aria-hidden="true" />

      <div class="splash__stage">
        <div class="splash__logo" aria-hidden="true">
          <img
            v-if="showImage"
            class="splash__logo-img"
            :src="logoUrl"
            alt=""
            @error="logoFailed = true"
          />
          <svg v-else class="splash__mark" viewBox="0 0 64 78" fill="none">
            <path
              d="M32 3.5c13.2 0 23.5 9.6 23.5 22.2 0 8.6-4.4 15.1-10.6 19-.9.6-1.5 1.5-1.5 2.6V52H20.6v-4.7c0-1.1-.6-2-1.5-2.6-6.2-3.9-10.6-10.4-10.6-19C8.5 13.1 18.8 3.5 32 3.5Z"
              stroke="currentColor"
              stroke-width="1.75"
            />
            <path
              d="M24 57.5h16M26.5 62.5h11M29.5 67.5h5"
              stroke="currentColor"
              stroke-width="1.75"
              stroke-linecap="round"
            />
            <g class="splash__filament">
              <path
                d="M32 38V24.5M32 30.5H23.5M32 30.5H40.5M32 24.5H25.5M32 24.5H38.5"
                stroke="currentColor"
                stroke-width="1.5"
                stroke-linecap="round"
                stroke-linejoin="round"
              />
              <circle cx="32" cy="38" r="1.7" fill="currentColor" />
              <circle cx="23.5" cy="30.5" r="1.45" fill="currentColor" />
              <circle cx="40.5" cy="30.5" r="1.45" fill="currentColor" />
              <circle cx="25.5" cy="24.5" r="1.3" fill="currentColor" />
              <circle cx="38.5" cy="24.5" r="1.3" fill="currentColor" />
            </g>
          </svg>
        </div>

        <div class="splash__copy">
          <p id="workspace-splash-title" class="splash__name" :class="{ 'is-long': longName }">
            {{ brandName }}
          </p>
          <p v-if="tagline" class="splash__tagline">{{ tagline }}</p>
        </div>

        <div class="splash__welcome">
          <p class="splash__hello">{{ welcomeText }}</p>
          <p class="splash__company" :class="{ 'is-in': companyName }">{{ companyName }}</p>
        </div>

        <div v-if="!failed" class="splash__progress">
          <div
            class="splash__meter"
            role="progressbar"
            aria-valuemin="0"
            aria-valuemax="100"
            :aria-valuenow="announced"
            :aria-label="t('auth.splashLoadingLabel')"
          >
            <span ref="bar" class="splash__meter-fill" />
          </div>
          <p class="splash__status" role="status" aria-live="polite" aria-atomic="true">
            <span :key="statusText" class="splash__status-line">{{ statusText }}</span>
          </p>
        </div>

        <div v-else class="splash__error" role="alert">
          <p>{{ statusText }}</p>
          <button
            ref="retryButton"
            type="button"
            class="btn-primary splash__retry"
            :disabled="retrying"
            @click="retry"
          >
            {{ t('auth.splashRetry') }}
          </button>
        </div>
      </div>

      <footer class="splash__foot">
        <span>{{ t('auth.splashVersion', { version }) }}</span>
        <span class="splash__secure">
          <svg viewBox="0 0 16 16" aria-hidden="true">
            <path
              fill="currentColor"
              d="M8 1.25a3.25 3.25 0 0 0-3.25 3.25V6H4.2A1.7 1.7 0 0 0 2.5 7.7v5.1A1.7 1.7 0 0 0 4.2 14.5h7.6a1.7 1.7 0 0 0 1.7-1.7V7.7A1.7 1.7 0 0 0 11.8 6h-.55V4.5A3.25 3.25 0 0 0 8 1.25Zm-1.9 3.25a1.9 1.9 0 0 1 3.8 0V6H6.1V4.5Z"
            />
          </svg>
          {{ t('auth.splashSecure') }}
        </span>
      </footer>
    </div>
  </Teleport>
</template>

<style scoped>
.splash {
  position: fixed;
  inset: 0;
  z-index: 120;
  display: grid;
  grid-template-rows: minmax(0, 1fr) auto;
  width: 100%;
  height: 100vh;
  height: 100dvh;
  overflow: hidden;
  background:
    radial-gradient(120% 70% at 50% -12%, color-mix(in srgb, var(--color-brand-600) 9%, transparent), transparent 58%),
    radial-gradient(70% 45% at 100% 100%, color-mix(in srgb, var(--color-accent) 7%, transparent), transparent 52%),
    var(--color-canvas);
  color: var(--color-text);
}

.splash--leaving {
  pointer-events: none;
}

.splash--leaving .splash__stage,
.splash--leaving .splash__foot {
  animation: splash-shift 380ms var(--ease-in) forwards;
}

.splash__motif {
  position: absolute;
  inset: 0;
  pointer-events: none;
  background-image:
    linear-gradient(to right, color-mix(in srgb, var(--color-brand-600) 7%, transparent) 1px, transparent 1px),
    linear-gradient(to bottom, color-mix(in srgb, var(--color-brand-600) 7%, transparent) 1px, transparent 1px);
  background-size: 56px 56px;
  mask-image: radial-gradient(ellipse 70% 60% at 50% 42%, #000 0%, transparent 74%);
  opacity: 0.9;
}

.splash__stage {
  position: relative;
  z-index: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 0;
  padding: clamp(1.5rem, 6vh, 4rem) clamp(1.25rem, 5vw, 2.5rem) 1rem;
  text-align: center;
}

.splash__logo {
  display: grid;
  place-items: center;
  height: 4.75rem;
  animation: splash-logo 500ms var(--ease-out) both;
}

.splash__logo-img {
  display: block;
  width: auto;
  max-width: min(12rem, 70vw);
  height: 4.75rem;
  object-fit: contain;
}

.splash__mark {
  width: 3.35rem;
  height: 4.15rem;
  color: var(--color-ink-brand, var(--color-brand-700));}

.splash__filament {
  color: var(--color-accent);
}

.splash__copy {
  display: flex;
  flex-direction: column;
  align-items: center;
  max-width: 28rem;
  margin-top: 1.15rem;
}

.splash__name {
  margin: 0;
  font-family: var(--font-brand);
  font-size: clamp(1.15rem, 2.2vw, 1.45rem);
  font-weight: 600;
  letter-spacing: 0.16em;
  line-height: 1.25;
  text-transform: uppercase;
  animation: splash-rise 500ms var(--ease-out) 300ms both;
}

.splash__name.is-long {
  font-size: clamp(1.25rem, 2.6vw, 1.7rem);
  letter-spacing: -0.03em;
  text-transform: none;
}

.splash__tagline {
  margin: 0.55rem 0 0;
  max-width: 34ch;
  font-size: 0.95rem;
  font-weight: 450;
  line-height: 1.45;
  color: var(--color-text-secondary);
  animation: splash-rise 500ms var(--ease-out) 420ms both;
}

.splash__welcome {
  max-width: 26rem;
  margin-top: 1.75rem;
  animation: splash-rise 500ms var(--ease-out) 560ms both;
}

.splash__hello {
  margin: 0;
  font-size: 1.05rem;
  font-weight: 550;
  letter-spacing: -0.02em;
  line-height: 1.35;
}

.splash__company {
  min-height: 1.35em;
  margin: 0.3rem 0 0;
  font-size: 0.875rem;
  line-height: 1.4;
  color: var(--color-text-secondary);
  overflow-wrap: anywhere;
  opacity: 0;
  transform: translateY(6px);
  transition:
    opacity 400ms var(--ease-out),
    transform 400ms var(--ease-out);
}

.splash__company.is-in {
  opacity: 1;
  transform: none;
}

.splash__progress,
.splash__error {
  display: flex;
  flex-direction: column;
  align-items: center;
  width: min(18rem, 78vw);
  margin-top: 1.85rem;
  animation: splash-rise 500ms var(--ease-out) 680ms both;
}

.splash__meter {
  width: 100%;
  height: 2px;
  overflow: hidden;
  border-radius: 99px;
  background: color-mix(in srgb, var(--color-brand-600) 16%, transparent);
}

.splash__meter-fill {
  display: block;
  width: 100%;
  height: 100%;
  border-radius: inherit;
  background: var(--color-accent);
  transform: scaleX(0.04);
  transform-origin: left center;
  will-change: transform;
}

.splash__status,
.splash__error p {
  margin: 0.85rem 0 0;
  min-height: 1.35em;
  font-size: 0.8125rem;
  line-height: 1.4;
  color: var(--color-text-secondary);
}

.splash__status-line {
  display: inline-block;
  animation: splash-status 420ms var(--ease-out);
}

.splash__retry {
  margin-top: 1rem;
  min-width: 8.5rem;
}

.splash__retry:focus-visible {
  outline: 2px solid var(--color-brand-600);
  outline-offset: 3px;
}

.splash__foot {
  position: relative;
  z-index: 1;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  padding:
    0.75rem
    max(1.25rem, env(safe-area-inset-right))
    max(1.15rem, env(safe-area-inset-bottom))
    max(1.25rem, env(safe-area-inset-left));
  font-size: 0.75rem;
  line-height: 1.4;
  color: var(--color-text-secondary);
  animation: splash-rise 500ms var(--ease-out) 720ms both;
}

.splash__secure {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
}

.splash__secure svg {
  width: 0.85rem;
  height: 0.85rem;
  flex: none;
}

@keyframes splash-shift {
  to {
    opacity: 0;
    transform: translateY(-10px);
  }
}

@keyframes splash-logo {
  from { opacity: 0; transform: scale(0.94); }
  to { opacity: 1; transform: scale(1); }
}

@keyframes splash-rise {
  from { opacity: 0; transform: translateY(8px); }
  to { opacity: 1; transform: translateY(0); }
}

@keyframes splash-status {
  from { opacity: 0; }
  to { opacity: 1; }
}

@media (max-width: 640px) {
  .splash__logo {
    height: 4.15rem;
  }

  .splash__mark {
    width: 2.9rem;
    height: 3.6rem;
  }

  .splash__welcome {
    margin-top: 1.35rem;
  }

  .splash__progress,
  .splash__error {
    margin-top: 1.45rem;
  }

  .splash__foot {
    flex-direction: column;
    align-items: center;
    text-align: center;
  }
}

@media (prefers-reduced-motion: reduce) {
  .splash--leaving,
  .splash--leaving .splash__stage,
  .splash--leaving .splash__foot,
  .splash__logo,
  .splash__name,
  .splash__tagline,
  .splash__welcome,
  .splash__progress,
  .splash__error,
  .splash__status-line,
  .splash__foot {
    animation: none;
  }

  .splash__company {
    transition: none;
  }
}

[data-theme="dark"] .splash__mark {
  color: var(--color-ink-brand, #d7e4f4);
}

[data-theme="dark"] .splash__motif {
  background-image:
    linear-gradient(to right, color-mix(in srgb, #e7eef3 10%, transparent) 1px, transparent 1px),
    linear-gradient(to bottom, color-mix(in srgb, #e7eef3 10%, transparent) 1px, transparent 1px);
}

[data-theme="dark"] .splash__meter {
  background: color-mix(in srgb, #d7e4f4 18%, transparent);
}
</style>
