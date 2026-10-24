<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import AppIcon from '../ui/AppIcon.vue'
import { getAppCurrency } from '../../utils/currency'
import { intlLocale } from '../../i18n/locales'
import { evaluateExpression, formatCalcNumber, type AngleMode } from '../../utils/calculator'

type Mode = 'standard' | 'scientific' | 'business'
type BusinessTab = 'margin' | 'tax' | 'discount' | 'change'

const { t } = useI18n()
const open = ref(false)
const root = ref<HTMLElement | null>(null)
const panel = ref<HTMLElement | null>(null)
const mode = ref<Mode>('standard')
const businessTab = ref<BusinessTab>('margin')
const angle = ref<AngleMode>('deg')
const expression = ref('')
const display = ref('0')
const justEvaluated = ref(false)
const memory = ref(0)

const cost = ref('')
const price = ref('')
const taxRate = ref('')
const discountRate = ref('')
const listPrice = ref('')
const tendered = ref('')
const due = ref('')

const modes: Mode[] = ['standard', 'scientific', 'business']

const standardKeys = [
  ['C', '⌫', '%', '÷'],
  ['7', '8', '9', '×'],
  ['4', '5', '6', '−'],
  ['1', '2', '3', '+'],
  ['±', '0', '.', '='],
]

const scientificKeys = ['sin', 'cos', 'tan', 'log', 'ln', '√', 'x²', 'xʸ', '1/x', 'π', 'e', '(', ')', 'n!']

function num(value: string) {
  const parsed = Number.parseFloat(value.replace(',', '.'))
  return Number.isFinite(parsed) ? parsed : 0
}

function money(value: number) {
  try {
    return new Intl.NumberFormat(intlLocale(), {
      style: 'currency',
      currency: getAppCurrency(),
      maximumFractionDigits: 2,
    }).format(value)
  } catch {
    return value.toFixed(2)
  }
}

const marginResult = computed(() => {
  const c = num(cost.value)
  const p = num(price.value)
  const profit = p - c
  return {
    profit,
    markup: c > 0 ? (profit / c) * 100 : 0,
    margin: p > 0 ? (profit / p) * 100 : 0,
  }
})

const taxResult = computed(() => {
  const amount = num(cost.value)
  const rate = num(taxRate.value)
  const tax = amount * (rate / 100)
  return { tax, ttc: amount + tax }
})

const discountResult = computed(() => {
  const amount = num(listPrice.value)
  const rate = num(discountRate.value)
  const savings = amount * (rate / 100)
  return { savings, net: amount - savings }
})

const changeResult = computed(() => num(tendered.value) - num(due.value))

function closeOnOutside(event: PointerEvent) {
  const target = event.target as Node
  if (root.value?.contains(target) || panel.value?.contains(target)) return
  open.value = false
}

function append(token: string) {
  if (justEvaluated.value && /[0-9.(]/.test(token)) {
    expression.value = ''
    display.value = '0'
  }
  justEvaluated.value = false
  expression.value += token
  display.value = currentEntry(expression.value)
}

function currentEntry(value: string) {
  const match = /(-?\d*\.?\d+)$/.exec(value)
  return match?.[1] || value || '0'
}

function clearAll() {
  expression.value = ''
  display.value = '0'
  justEvaluated.value = false
}

function backspace() {
  expression.value = expression.value.slice(0, -1)
  display.value = expression.value ? currentEntry(expression.value) : '0'
  justEvaluated.value = false
}

function toggleSign() {
  if (!expression.value || expression.value === '0') {
    expression.value = '-'
    display.value = '-'
    return
  }
  if (justEvaluated.value) {
    expression.value = expression.value.startsWith('-') ? expression.value.slice(1) : `-${expression.value}`
    display.value = expression.value
    return
  }
  append('-')
}

function evaluate() {
  if (!expression.value) return
  try {
    const value = evaluateExpression(expression.value, angle.value)
    const formatted = formatCalcNumber(value)
    display.value = formatted
    expression.value = formatted
    justEvaluated.value = true
  } catch {
    display.value = t('calculator.error')
    justEvaluated.value = true
  }
}

function press(key: string) {
  if (key === 'C') return clearAll()
  if (key === '⌫') return backspace()
  if (key === '=') return evaluate()
  if (key === '±') return toggleSign()
  if (key === '÷') return append('/')
  if (key === '×') return append('*')
  if (key === '−') return append('-')
  if (key === 'π') return append('pi')
  if (key === '√') return append('sqrt(')
  if (key === 'x²') return append('^2')
  if (key === 'xʸ') return append('^')
  if (key === 'n!') return append('!')
  if (key === '1/x') {
    const current = justEvaluated.value ? expression.value : currentEntry(expression.value)
    const base = current && current !== '0' ? current : expression.value || '0'
    expression.value = `1/(${base})`
    return evaluate()
  }
  if (['sin', 'cos', 'tan', 'log', 'ln'].includes(key)) return append(`${key}(`)
  append(key)
}

function onKeydown(event: KeyboardEvent) {
  if (!open.value || mode.value === 'business') return
  const target = event.target as HTMLElement | null
  if (target && ['INPUT', 'TEXTAREA', 'SELECT'].includes(target.tagName)) return

  if (event.key === 'Escape') {
    open.value = false
    return
  }
  if (event.key === 'Enter' || event.key === '=') {
    event.preventDefault()
    evaluate()
    return
  }
  if (event.key === 'Backspace') {
    event.preventDefault()
    backspace()
    return
  }
  if ('0123456789.+-*/()%^'.includes(event.key)) {
    event.preventDefault()
    press(event.key)
  }
}

function keyClass(key: string) {
  if (key === '=') return 'calc-key calc-key--eq'
  if ('÷×−+'.includes(key) || key === '^') return 'calc-key calc-key--op'
  if (key === 'C') return 'calc-key calc-key--clear'
  return 'calc-key'
}

watch(open, (value) => {
  if (value) {
    window.addEventListener('keydown', onKeydown)
    window.addEventListener('pointerdown', closeOnOutside)
    return
  }
  window.removeEventListener('keydown', onKeydown)
  window.removeEventListener('pointerdown', closeOnOutside)
})

onBeforeUnmount(() => {
  window.removeEventListener('pointerdown', closeOnOutside)
  window.removeEventListener('keydown', onKeydown)
})

function toggle() {
  open.value = !open.value
}
</script>

<template>
  <div ref="root" class="calc">
    <button
      type="button"
      class="calc-btn"
      :class="{ 'calc-btn--open': open }"
      :aria-label="t('calculator.title')"
      :title="t('calculator.title')"
      @click="toggle"
    >
      <AppIcon name="calculator" :size="16" />
    </button>
  </div>

  <Teleport to="body">
    <Transition name="menu-pop">
    <div
      v-if="open"
      ref="panel"
      class="calc-panel"
      role="dialog"
      :aria-label="t('calculator.title')"
    >
      <div class="calc-panel__head">
        <div class="calc-panel__brand">
          <span class="calc-panel__mark" aria-hidden="true" />
          <p class="calc-panel__title">{{ t('calculator.title') }}</p>
        </div>
        <button type="button" class="calc-panel__close" :aria-label="t('common.cancel')" @click="open = false">×</button>
      </div>

      <div class="calc-modes" role="tablist">
        <button
          v-for="item in modes"
          :key="item"
          type="button"
          class="calc-mode"
          role="tab"
          :aria-selected="mode === item"
          :class="{ 'is-active': mode === item }"
          @click="mode = item"
        >
          {{ t(`calculator.${item}`) }}
        </button>
      </div>

      <template v-if="mode !== 'business'">
        <div class="calc-screen">
          <p class="calc-screen__expr">{{ expression || '0' }}</p>
          <p class="calc-screen__value">{{ display }}</p>
          <div class="calc-memory">
            <span>M {{ formatCalcNumber(memory) }}</span>
            <button type="button" @click="memory = 0">MC</button>
            <button type="button" @click="append(formatCalcNumber(memory))">MR</button>
            <button type="button" @click="memory += Number(display) || 0">M+</button>
          </div>
        </div>

        <div v-if="mode === 'scientific'" class="calc-fns">
          <button
            type="button"
            class="calc-fn"
            :class="{ 'is-on': angle === 'rad' }"
            @click="angle = angle === 'deg' ? 'rad' : 'deg'"
          >
            {{ angle === 'deg' ? t('calculator.deg') : t('calculator.rad') }}
          </button>
          <button
            v-for="key in scientificKeys"
            :key="key"
            type="button"
            class="calc-fn"
            @click="press(key)"
          >
            {{ key }}
          </button>
        </div>

        <div class="calc-grid">
          <button
            v-for="key in standardKeys.flat()"
            :key="key"
            type="button"
            :class="keyClass(key)"
            @click="press(key)"
          >
            {{ key }}
          </button>
        </div>
      </template>

      <div v-else class="calc-business">
        <div class="calc-modes calc-modes--sub" role="tablist">
          <button
            v-for="tab in (['margin', 'tax', 'discount', 'change'] as BusinessTab[])"
            :key="tab"
            type="button"
            class="calc-mode"
            role="tab"
            :aria-selected="businessTab === tab"
            :class="{ 'is-active': businessTab === tab }"
            @click="businessTab = tab"
          >
            {{ t(`calculator.tabs.${tab}`) }}
          </button>
        </div>

        <template v-if="businessTab === 'margin'">
          <label class="calc-field">
            <span>{{ t('calculator.cost') }}</span>
            <input v-model="cost" inputmode="decimal" />
          </label>
          <label class="calc-field">
            <span>{{ t('calculator.price') }}</span>
            <input v-model="price" inputmode="decimal" />
          </label>
          <div class="calc-results">
            <p><span>{{ t('calculator.markup') }}</span><strong>{{ marginResult.markup.toFixed(2) }}%</strong></p>
            <p><span>{{ t('calculator.margin') }}</span><strong>{{ marginResult.margin.toFixed(2) }}%</strong></p>
            <p class="is-hero"><span>{{ t('calculator.profit') }}</span><strong>{{ money(marginResult.profit) }}</strong></p>
          </div>
        </template>

        <template v-else-if="businessTab === 'tax'">
          <label class="calc-field">
            <span>{{ t('calculator.amountHt') }}</span>
            <input v-model="cost" inputmode="decimal" />
          </label>
          <label class="calc-field">
            <span>{{ t('calculator.taxRate') }}</span>
            <input v-model="taxRate" inputmode="decimal" />
          </label>
          <div class="calc-results">
            <p><span>{{ t('calculator.taxAmount') }}</span><strong>{{ money(taxResult.tax) }}</strong></p>
            <p class="is-hero"><span>{{ t('calculator.amountTtc') }}</span><strong>{{ money(taxResult.ttc) }}</strong></p>
          </div>
        </template>

        <template v-else-if="businessTab === 'discount'">
          <label class="calc-field">
            <span>{{ t('calculator.price') }}</span>
            <input v-model="listPrice" inputmode="decimal" />
          </label>
          <label class="calc-field">
            <span>{{ t('calculator.discount') }} %</span>
            <input v-model="discountRate" inputmode="decimal" />
          </label>
          <div class="calc-results">
            <p><span>{{ t('calculator.savings') }}</span><strong>{{ money(discountResult.savings) }}</strong></p>
            <p class="is-hero"><span>{{ t('calculator.discounted') }}</span><strong>{{ money(discountResult.net) }}</strong></p>
          </div>
        </template>

        <template v-else>
          <label class="calc-field">
            <span>{{ t('calculator.total') }}</span>
            <input v-model="due" inputmode="decimal" />
          </label>
          <label class="calc-field">
            <span>{{ t('calculator.tendered') }}</span>
            <input v-model="tendered" inputmode="decimal" />
          </label>
          <div class="calc-results">
            <p class="is-hero"><span>{{ t('calculator.change') }}</span><strong>{{ money(changeResult) }}</strong></p>
          </div>
        </template>
      </div>
    </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.calc {
  position: relative;
}

.calc-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: var(--control-md);
  height: var(--control-md);
  min-width: var(--control-md);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  background: var(--color-surface);
  color: var(--color-ink-brand, var(--color-brand-600));
  cursor: pointer;
}

.calc-btn:hover,
.calc-btn--open {
  border-color: #e39b2b;
  background: color-mix(in srgb, #f0a010 18%, var(--color-surface));
  color: var(--color-ink-brand, var(--color-brand-600));
}
</style>

<style>
/* Unscoped: panel is teleported to body so it must pin to the viewport corner. */
.calc-panel {
  --calc-navy: #12243c;
  --calc-gold: #f0a010;
  --calc-ink: var(--color-text-primary);
  position: fixed !important;
  top: auto !important;
  left: auto !important;
  right: 16px !important;
  bottom: 16px !important;
  z-index: 9999 !important;
  display: flex;
  flex-direction: column;
  width: min(22.75rem, calc(100vw - 2rem));
  max-height: min(82dvh, 44rem);
  overflow: auto;
  border: 1px solid var(--color-border);
  border-radius: 1.25rem;
  background: var(--color-surface);
  box-shadow:
    0 24px 48px rgba(10, 21, 35, 0.18),
    0 2px 6px rgba(10, 21, 35, 0.06);
  color: var(--calc-ink);
  font-family: var(--font-sans, "IBM Plex Sans", sans-serif);
}

@media (max-width: 480px) {
  .calc-panel {
    right: 12px !important;
    bottom: 12px !important;
    left: 12px !important;
    width: auto;
  }
}

.calc-panel__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  padding: 0.85rem 0.9rem 0.35rem;
}

.calc-panel__brand {
  display: flex;
  align-items: center;
  gap: 0.55rem;
  min-width: 0;
}

.calc-panel__mark {
  width: 0.55rem;
  height: 0.55rem;
  flex-shrink: 0;
  border-radius: 999px;
  background: var(--calc-gold);
  box-shadow: 0 0 0 4px color-mix(in srgb, var(--calc-gold) 22%, transparent);
}

.calc-panel__title {
  margin: 0;
  font-size: 0.95rem;
  font-weight: 700;
  letter-spacing: -0.01em;
  color: var(--calc-ink);
}

.calc-panel__close {
  display: inline-flex;
  width: 1.85rem;
  height: 1.85rem;
  align-items: center;
  justify-content: center;
  border: 1px solid var(--color-border);
  border-radius: 999px;
  background: var(--color-canvas, #f4f6f8);
  color: var(--color-text-muted);
  font-size: 1.1rem;
  line-height: 1;
  cursor: pointer;
}

.calc-panel__close:hover {
  background: var(--calc-navy);
  border-color: var(--calc-navy);
  color: #fff;
}

.calc-modes {
  display: flex;
  gap: 0.2rem;
  margin: 0.45rem 0.75rem 0;
  padding: 0.2rem;
  border-radius: 999px;
  background: var(--color-canvas, #f4f6f8);
}

.calc-modes--sub {
  margin: 0 0 0.75rem;
}

.calc-mode {
  flex: 1;
  min-width: 0;
  border: 0;
  border-radius: 999px;
  background: transparent;
  color: var(--color-text-muted);
  padding: 0.42rem 0.35rem;
  font-size: 0.72rem;
  font-weight: 650;
  cursor: pointer;
}

.calc-mode.is-active {
  background: var(--calc-navy);
  color: #fff;
  box-shadow: 0 1px 2px rgba(18, 36, 60, 0.18);
}

.calc-screen {
  margin: 0.7rem 0.75rem 0.65rem;
  padding: 0.85rem 0.9rem 0.65rem;
  border-radius: 1rem;
  background:
    radial-gradient(120% 80% at 100% 0%, color-mix(in srgb, var(--calc-gold) 28%, transparent), transparent 55%),
    var(--calc-navy);
  color: #fff;
  text-align: right;
}

.calc-screen__expr {
  margin: 0;
  min-height: 1.05rem;
  overflow: hidden;
  color: rgba(255, 255, 255, 0.62);
  font-family: var(--font-mono, ui-monospace, monospace);
  font-size: 0.75rem;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.calc-screen__value {
  margin: 0.2rem 0 0.55rem;
  overflow: hidden;
  color: var(--calc-gold);
  font-family: var(--font-mono, ui-monospace, monospace);
  font-size: 1.85rem;
  font-weight: 650;
  font-variant-numeric: tabular-nums;
  letter-spacing: -0.04em;
  line-height: 1.1;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.calc-memory {
  display: flex;
  align-items: center;
  gap: 0.3rem;
  padding-top: 0.5rem;
  border-top: 1px solid rgba(255, 255, 255, 0.12);
  color: rgba(255, 255, 255, 0.72);
  font-family: var(--font-mono, ui-monospace, monospace);
  font-size: 0.68rem;
}

.calc-memory span {
  flex: 1;
  overflow: hidden;
  text-align: left;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.calc-memory button {
  border: 1px solid rgba(240, 160, 16, 0.45);
  border-radius: 999px;
  background: color-mix(in srgb, var(--calc-gold) 16%, transparent);
  color: var(--calc-gold);
  padding: 0.18rem 0.45rem;
  font-family: inherit;
  font-size: 0.66rem;
  font-weight: 700;
  cursor: pointer;
}

.calc-memory button:hover {
  background: var(--calc-gold);
  color: var(--calc-navy);
}

.calc-fns {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  gap: 0.3rem;
  padding: 0 0.75rem 0.55rem;
}

.calc-fn {
  height: 1.85rem;
  border: 1px solid var(--color-border);
  border-radius: 0.55rem;
  background: var(--color-canvas, #f4f6f8);
  color: var(--calc-navy);
  font-size: 0.68rem;
  font-weight: 700;
  cursor: pointer;
}

.calc-fn:hover,
.calc-fn.is-on {
  border-color: color-mix(in srgb, var(--calc-gold) 70%, var(--color-border));
  background: color-mix(in srgb, var(--calc-gold) 22%, var(--color-surface));
  color: var(--calc-navy);
}

.calc-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 0.4rem;
  padding: 0 0.75rem 0.85rem;
}

.calc-key {
  height: 2.85rem;
  border: 1px solid var(--color-border);
  border-radius: 0.85rem;
  background: var(--color-surface);
  color: var(--calc-ink);
  font-size: 1.05rem;
  font-weight: 650;
  font-variant-numeric: tabular-nums;
  cursor: pointer;
  transition: transform 80ms ease, background 120ms ease, border-color 120ms ease;
}

.calc-key:hover {
  background: var(--color-canvas, #f4f6f8);
}

.calc-key:active {
  transform: translateY(1px) scale(0.98);
}

.calc-key--op {
  border-color: var(--calc-navy);
  background: var(--calc-navy);
  color: #fff;
}

.calc-key--op:hover {
  background: #1b3354;
}

.calc-key--clear {
  border-color: transparent;
  background: var(--color-danger-bg, #fbedec);
  color: var(--color-danger, #c2413a);
}

.calc-key--eq {
  border-color: var(--calc-gold);
  background: var(--calc-gold);
  color: var(--calc-navy);
  font-size: 1.25rem;
}

.calc-key--eq:hover {
  background: #ffb11a;
}

.calc-key:focus-visible,
.calc-fn:focus-visible,
.calc-mode:focus-visible,
.calc-panel__close:focus-visible,
.calc-memory button:focus-visible,
.calc-field input:focus-visible {
  outline: none;
  box-shadow: 0 0 0 3px color-mix(in srgb, var(--calc-gold) 45%, transparent);
}

.calc-business {
  padding: 0.75rem;
}

.calc-field {
  display: flex;
  flex-direction: column;
  gap: 0.3rem;
  margin-bottom: 0.65rem;
  color: var(--color-text-muted);
  font-size: 0.72rem;
  font-weight: 650;
}

.calc-field input {
  border: 1px solid var(--color-border-strong, #d0d6dc);
  border-radius: 0.7rem;
  background: var(--color-surface);
  padding: 0.6rem 0.75rem;
  font-family: var(--font-mono, ui-monospace, monospace);
  font-size: 1rem;
  font-variant-numeric: tabular-nums;
  color: var(--calc-ink);
}

.calc-results {
  border-radius: 0.9rem;
  background: var(--color-canvas, #f4f6f8);
  padding: 0.35rem 0.85rem 0.7rem;
}

.calc-results p {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  gap: 0.75rem;
  margin: 0.45rem 0 0;
  color: var(--color-text-muted);
  font-size: 0.78rem;
}

.calc-results strong {
  color: var(--calc-ink);
  font-variant-numeric: tabular-nums;
}

.calc-results p.is-hero {
  margin-top: 0.65rem;
  padding-top: 0.65rem;
  border-top: 1px solid var(--color-border);
  color: var(--color-text-secondary, var(--color-text-muted));
  font-size: 0.8rem;
}

.calc-results p.is-hero strong {
  color: var(--calc-navy);
  font-family: var(--font-mono, ui-monospace, monospace);
  font-size: 1.25rem;
  font-weight: 700;
  letter-spacing: -0.03em;
}

html[data-theme="dark"] .calc-panel {
  background: var(--color-surface);
  border-color: var(--color-border-strong);
}

html[data-theme="dark"] .calc-panel .calc-key,
html[data-theme="dark"] .calc-panel .calc-fn,
html[data-theme="dark"] .calc-panel .calc-field input {
  background: color-mix(in srgb, var(--color-surface) 70%, #000);
  border-color: var(--color-border);
  color: var(--color-text-primary);
}

html[data-theme="dark"] .calc-panel .calc-key--op {
  background: #1c334c;
  border-color: #1c334c;
  color: #fff;
}

html[data-theme="dark"] .calc-panel .calc-key--eq {
  background: var(--calc-gold);
  border-color: var(--calc-gold);
  color: var(--calc-navy);
}

html[data-theme="dark"] .calc-panel .calc-key--clear {
  background: var(--color-danger-bg);
  color: #f3c7c4;
}

html[data-theme="dark"] .calc-panel .calc-mode.is-active {
  background: var(--calc-gold);
  color: var(--calc-navy);
}

html[data-theme="dark"] .calc-panel .calc-results p.is-hero strong {
  color: var(--calc-gold);
}
</style>
