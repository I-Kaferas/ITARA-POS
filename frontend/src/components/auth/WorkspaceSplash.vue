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
  minDurationMs: 4000,
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
  if (bootDone.value && step.value >= lines.value.length - 1) return t('auth.splashStatusReady')
  const list = lines.value
  return list[Math.min(step.value, list.length - 1)] ?? ''
})

const welcomeText = computed(() =>
  props.firstName
    ? t('auth.splashWelcome', { name: props.firstName })
    : t('auth.splashWelcomePlain'),
)

const ghost = computed(() => String(Math.min(step.value, lines.value.length - 1) + 1).padStart(2, '0'))

function stepState(index: number) {
  if (failed.value) return 'wait'
  if (bootDone.value || index < step.value) return 'done'
  if (index === Math.min(step.value, lines.value.length - 1)) return 'on'
  return 'wait'
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

function milestone(ratio: number, nextStep?: number) {
  if (failed.value || leaving.value || runId !== generation) return
  target = Math.max(target, Math.min(1, ratio))
  void nextStep
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
  if (!failed.value) {
    const paced = Math.min(1, elapsed() / props.minDurationMs)
    const visualStep = paced >= 0.66 ? 2 : paced >= 0.33 ? 1 : 0
    if (step.value !== visualStep) step.value = visualStep
  }

  const timeCap = Math.min(1, Math.max(0.04, elapsed() / props.minDurationMs))
  const cap = bootDone.value ? timeCap : Math.min(stallCap(), timeCap)
  const delta = cap - shown
  if (delta > 0) {
    if (delta < 0.004) shown = cap
    else shown += delta * (reduced ? 1 : 0.12)
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
      <div class="splash__sheet">
        <header class="splash__rail">
          <div class="splash__identity">
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
            <div class="splash__brand">
              <p id="workspace-splash-title" class="splash__name" :class="{ 'is-long': longName }">
                {{ brandName }}
              </p>
              <p v-if="tagline" class="splash__tagline">{{ tagline }}</p>
            </div>
          </div>
          <p class="splash__meta">
            <span>{{ t('auth.splashVersion', { version }) }}</span>
            <span class="splash__dot" aria-hidden="true" />
            <span class="splash__secure">
              <svg viewBox="0 0 16 16" aria-hidden="true">
                <path
                  fill="currentColor"
                  d="M8 1.25a3.25 3.25 0 0 0-3.25 3.25V6H4.2A1.7 1.7 0 0 0 2.5 7.7v5.1A1.7 1.7 0 0 0 4.2 14.5h7.6a1.7 1.7 0 0 0 1.7-1.7V7.7A1.7 1.7 0 0 0 11.8 6h-.55V4.5A3.25 3.25 0 0 0 8 1.25Zm-1.9 3.25a1.9 1.9 0 0 1 3.8 0V6H6.1V4.5Z"
                />
              </svg>
              {{ t('auth.splashSecure') }}
            </span>
          </p>
        </header>

        <section class="splash__stage">
          <p class="splash__ghost" aria-hidden="true">{{ ghost }}</p>
          <div class="splash__welcome">
            <span class="splash__rule" aria-hidden="true" />
            <p class="splash__hello">
              <template v-if="firstName">
                <span class="splash__hello-kicker">{{ t('auth.splashWelcomePlain') }}</span>
                <span class="splash__hello-name">{{ firstName }}</span>
              </template>
              <template v-else>{{ welcomeText }}</template>
            </p>
            <p class="splash__company" :class="{ 'is-in': companyName }">{{ companyName }}</p>
          </div>
        </section>

        <footer v-if="!failed" class="splash__deck">
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
          <ol class="splash__steps">
            <li
              v-for="(line, index) in lines"
              :key="line"
              class="splash__step"
              :class="`is-${stepState(index)}`"
            >
              <span class="splash__index">{{ String(index + 1).padStart(2, '0') }}</span>
              <span class="splash__step-label">{{ line }}</span>
            </li>
          </ol>
          <p class="splash__live" role="status" aria-live="polite" aria-atomic="true">{{ statusText }}</p>
        </footer>

        <footer v-else class="splash__error" role="alert">
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
        </footer>
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
  /* html zoom shrinks 100vh, so divide it back out to cover the real window. */
  width: calc(100vw / var(--ui-zoom, 1));
  min-width: calc(100vw / var(--ui-zoom, 1));
  height: calc(100vh / var(--ui-zoom, 1));
  height: calc(100dvh / var(--ui-zoom, 1));
  min-height: calc(100vh / var(--ui-zoom, 1));
  min-height: calc(100dvh / var(--ui-zoom, 1));
  padding: 0;
  overflow: hidden;
  background: #f6f3ec;
  color: #14202b;
}

.splash--leaving {
  pointer-events: none;
}

.splash--leaving .splash__sheet {
  animation: splash-shift 380ms var(--ease-in) forwards;
}

.splash__sheet {
  display: grid;
  grid-template-rows: auto minmax(0, 1fr) auto;
  width: 100%;
  height: 100%;
  min-height: 0;
  overflow: hidden;
  background: #f6f3ec;
}

.splash__rail {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1.5rem;
  padding: 1.15rem 1.5rem 1.05rem;
  border-bottom: 1px solid #e4ddd2;
}

.splash__identity {
  display: flex;
  align-items: center;
  gap: 0.9rem;
  min-width: 0;
}

.splash__logo {
  display: grid;
  place-items: center;
  width: 3.15rem;
  height: 3.15rem;
  flex: none;
  border-radius: 0.8rem;
  background: #fff;
  color: #12243c;
  box-shadow: inset 0 0 0 1px #e4ddd2;
  animation:
    splash-logo 640ms var(--ease-out) both,
    splash-logo-glow 2.2s ease-in-out 640ms infinite;
}

.splash__logo-img {
  display: block;
  width: 2.05rem;
  height: 2.05rem;
  object-fit: contain;
}

.splash__mark {
  width: 1.35rem;
  height: 1.7rem;
  color: #12243c;
}

.splash__filament {
  color: #e39b2b;
}

.splash__brand {
  min-width: 0;
}

.splash__name {
  margin: 0;
  font-family: var(--font-brand);
  font-size: 1.05rem;
  font-weight: 650;
  letter-spacing: -0.02em;
  line-height: 1.2;
  color: #12243c;
}

.splash__name.is-long {
  font-size: 0.95rem;
}

.splash__tagline {
  margin: 0.15rem 0 0;
  max-width: 42ch;
  overflow: hidden;
  font-size: 0.82rem;
  line-height: 1.35;
  color: #5c6874;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
}

.splash__meta {
  display: flex;
  align-items: center;
  gap: 0.65rem;
  margin: 0;
  flex: none;
  font-size: 0.75rem;
  line-height: 1.3;
  color: #5c6874;
}

.splash__dot {
  width: 4px;
  height: 4px;
  border-radius: 99px;
  background: #e39b2b;
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

.splash__stage {
  position: relative;
  display: flex;
  align-items: flex-end;
  justify-content: center;
  width: 100%;
  min-height: 0;
  padding: clamp(1.5rem, 5vh, 3.5rem) clamp(1.25rem, 4vw, 3rem) clamp(1.75rem, 6vh, 3.25rem);
  overflow: hidden;
  text-align: center;
}

.splash__ghost {
  position: absolute;
  top: 28%;
  left: 50%;
  margin: 0;
  font-family: var(--font-brand);
  font-size: clamp(6rem, 16vw, 11rem);
  font-weight: 650;
  letter-spacing: -0.08em;
  line-height: 0.8;
  color: #12243c;
  transform: translate(-50%, -50%);
  pointer-events: none;
  user-select: none;
  animation: splash-ghost 4s ease-in-out both;
}

.splash__welcome {
  position: absolute;
  z-index: 1;
  left: 50%;
  /* Splash is taller than the window (100dvh / zoom). Pin the greeting to the visible bottom, under the step number. */
  bottom: calc((1 / var(--ui-zoom, 1) - 1) * 100dvh + clamp(0.85rem, 2.5vh, 1.75rem));
  display: flex;
  flex-direction: column;
  align-items: center;
  width: min(16em, 92%);
  margin: 0;
  font-size: clamp(3.2rem, 6vw, 5.8rem);
  text-align: center;
  transform: translateX(-50%);
}

.splash__rule {
  display: block;
  width: 2.75rem;
  height: 3px;
  margin: 0 auto 1.15rem;
  background: #e39b2b;
  transform-origin: center;
  animation: splash-rule 700ms var(--ease-out) 160ms both;
}

.splash__hello {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.06em;
  margin: 0;
  font-family: var(--font-brand);
  font-size: 1em;
  font-weight: 650;
  letter-spacing: -0.055em;
  line-height: 0.9;
  color: #12243c;
  text-align: center;
}

.splash__hello-kicker {
  font-size: 0.38em;
  font-weight: 550;
  letter-spacing: -0.03em;
  line-height: 1;
  color: #5c6874;
  animation: splash-rise 520ms var(--ease-out) 240ms both;
}

.splash__hello-name {
  display: block;
  animation: splash-rise 620ms var(--ease-out) 380ms both;
}

.splash__company {
  min-height: 1.4em;
  margin: 0.85rem 0 0;
  font-size: 1.05rem;
  line-height: 1.4;
  color: #5c6874;
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

.splash__deck {
  position: relative;
  background: #fff;
  border-top: 1px solid #e4ddd2;
}

.splash__meter {
  height: 3px;
  overflow: hidden;
  background: #efeae2;
}

.splash__meter-fill {
  display: block;
  width: 100%;
  height: 100%;
  background: #e39b2b;
  transform: scaleX(0.04);
  transform-origin: left center;
  will-change: transform;
}

.splash__steps {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  margin: 0;
  padding: 0;
  list-style: none;
}

.splash__step {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 0.45rem;
  min-height: 6.5rem;
  padding: 1.15rem 1.35rem 1.25rem;
  border-right: 1px solid #e4ddd2;
  background: #fff;
  color: #5c6874;
  text-align: center;
  animation: splash-step 560ms var(--ease-out) both;
}

.splash__step:nth-child(2) {
  animation-delay: 140ms;
}

.splash__step:nth-child(3) {
  animation-delay: 280ms;
}

.splash__step:last-child {
  border-right: 0;
}

.splash__step.is-on {
  background: #e39b2b;
  color: #12243c;
  border-right-color: #d08918;
}

.splash__step.is-on .splash__index {
  animation: splash-tick 1.15s ease-in-out infinite;
}

.splash__step.is-done {
  background: #12243c;
  color: #f4f7fb;
  border-right-color: #0d1a2b;
}

.splash__index {
  font-size: 0.75rem;
  font-weight: 700;
  letter-spacing: 0.16em;
}

.splash__step.is-done .splash__index {
  color: #e39b2b;
}

.splash__step-label {
  font-size: 0.92rem;
  font-weight: 550;
  line-height: 1.35;
}

.splash__live {
  position: absolute;
  width: 1px;
  height: 1px;
  overflow: hidden;
  clip: rect(0 0 0 0);
}

.splash__error {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  padding: 1.15rem 1.5rem;
  background: #fbedec;
  color: #8d2e28;
}

.splash__error p {
  margin: 0;
  font-size: 0.95rem;
  line-height: 1.4;
}

.splash__retry {
  flex: none;
  min-width: 8.5rem;
}

.splash__retry:focus-visible {
  outline: 2px solid #12243c;
  outline-offset: 3px;
}

@keyframes splash-shift {
  to {
    opacity: 0;
    transform: translateY(-8px);
  }
}

@keyframes splash-logo {
  from { opacity: 0; transform: scale(0.94); }
  to { opacity: 1; transform: scale(1); }
}

@keyframes splash-rise {
  from { opacity: 0; transform: translateY(14px); }
  to { opacity: 1; transform: translateY(0); }
}

@keyframes splash-rule {
  from { transform: scaleX(0); }
  to { transform: scaleX(1); }
}

@keyframes splash-logo-glow {
  0%, 100% { box-shadow: inset 0 0 0 1px #e4ddd2; }
  50% { box-shadow: inset 0 0 0 2px #e39b2b; }
}

@keyframes splash-ghost {
  0% { opacity: 0; transform: translate(-50%, -42%); }
  20% { opacity: 0.1; transform: translate(-50%, -50%); }
  60% { opacity: 0.12; transform: translate(-50%, -56%); }
  100% { opacity: 0.1; transform: translate(-50%, -50%); }
}

@keyframes splash-step {
  from { opacity: 0; transform: translateY(16px); }
  to { opacity: 1; transform: translateY(0); }
}

@keyframes splash-tick {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.4; }
}

@media (max-width: 800px) {
  .splash {
    padding: 0;
  }

  .splash__rail {
    align-items: flex-start;
    flex-direction: column;
    gap: 0.75rem;
  }

  .splash__welcome {
    max-width: 100%;
    font-size: 3.1rem;
  }

  .splash__ghost {
    top: 22%;
    font-size: 7rem;
    opacity: 0.06;
  }

  .splash__stage {
    align-items: flex-end;
    padding: 1.35rem 1.15rem 1.5rem;
  }

  .splash__steps {
    grid-template-columns: 1fr;
  }

  .splash__step {
    flex-direction: row;
    align-items: center;
    justify-content: flex-start;
    min-height: 0;
    border-right: 0;
    border-top: 1px solid #e4ddd2;
  }

  .splash__step.is-on,
  .splash__step.is-done {
    border-top-color: transparent;
  }

  .splash__error {
    flex-direction: column;
    align-items: flex-start;
  }
}

@media (prefers-reduced-motion: reduce) {
  .splash--leaving,
  .splash--leaving .splash__sheet,
  .splash__logo,
  .splash__welcome,
  .splash__rule,
  .splash__hello-kicker,
  .splash__hello-name,
  .splash__ghost,
  .splash__step,
  .splash__step.is-on .splash__index {
    animation: none;
  }

  .splash__ghost {
    opacity: 0.1;
    transform: translate(-50%, -50%);
  }

  .splash__company {
    transition: none;
  }
}

[data-theme="dark"] .splash__sheet {
  background: var(--color-canvas);
  color: var(--color-text);
}

[data-theme="dark"] .splash__rail,
[data-theme="dark"] .splash__step {
  border-color: var(--color-border);
}

[data-theme="dark"] .splash__name,
[data-theme="dark"] .splash__hello,
[data-theme="dark"] .splash__ghost {
  color: var(--color-text-primary);
}

[data-theme="dark"] .splash__tagline,
[data-theme="dark"] .splash__company,
[data-theme="dark"] .splash__meta,
[data-theme="dark"] .splash__step {
  color: var(--color-text-secondary);
}

[data-theme="dark"] .splash__deck,
[data-theme="dark"] .splash__step {
  background: var(--color-surface);
}

[data-theme="dark"] .splash__step.is-on {
  background: #e39b2b;
  color: #12243c;
}

[data-theme="dark"] .splash__step.is-done {
  background: #12243c;
  color: #f4f7fb;
}

[data-theme="dark"] .splash__meter {
  background: var(--color-border);
}
</style>
