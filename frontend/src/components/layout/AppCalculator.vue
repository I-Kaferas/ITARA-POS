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
    <div
      v-if="open"
      ref="panel"
      class="calc-panel"
      role="dialog"
      :aria-label="t('calculator.title')"
    >
      <div class="calc-panel__head">
        <p class="calc-panel__title">{{ t('calculator.title') }}</p>
        <button type="button" class="calc-panel__close" :aria-label="t('common.cancel')" @click="open = false">×</button>
      </div>

      <div class="calc-tabs">
        <button
          v-for="item in modes"
          :key="item"
          type="button"
          class="calc-tab"
          :class="{ 'calc-tab--active': mode === item }"
          @click="mode = item"
        >
          {{ t(`calculator.${item}`) }}
        </button>
      </div>

      <template v-if="mode !== 'business'">
        <div class="calc-screen">
          <p class="calc-screen__expr">{{ expression || '0' }}</p>
          <p class="calc-screen__value">{{ display }}</p>
        </div>

        <div v-if="mode === 'scientific'" class="calc-tools">
          <button type="button" class="calc-chip" @click="angle = angle === 'deg' ? 'rad' : 'deg'">
            {{ angle === 'deg' ? t('calculator.deg') : t('calculator.rad') }}
          </button>
          <button
            v-for="key in scientificKeys"
            :key="key"
            type="button"
            class="calc-chip"
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

        <div class="calc-memory">
          <span>M {{ formatCalcNumber(memory) }}</span>
          <button type="button" @click="memory = 0">MC</button>
          <button type="button" @click="append(formatCalcNumber(memory))">MR</button>
          <button type="button" @click="memory += Number(display) || 0">M+</button>
        </div>
      </template>

      <div v-else class="calc-business">
        <div class="calc-tabs calc-tabs--sub">
          <button
            v-for="tab in (['margin', 'tax', 'discount', 'change'] as BusinessTab[])"
            :key="tab"
            type="button"
            class="calc-tab"
            :class="{ 'calc-tab--active': businessTab === tab }"
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
            <p><span>{{ t('calculator.profit') }}</span><strong>{{ money(marginResult.profit) }}</strong></p>
            <p><span>{{ t('calculator.markup') }}</span><strong>{{ marginResult.markup.toFixed(2) }}%</strong></p>
            <p><span>{{ t('calculator.margin') }}</span><strong>{{ marginResult.margin.toFixed(2) }}%</strong></p>
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
            <p><span>{{ t('calculator.amountTtc') }}</span><strong>{{ money(taxResult.ttc) }}</strong></p>
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
            <p><span>{{ t('calculator.discounted') }}</span><strong>{{ money(discountResult.net) }}</strong></p>
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
            <p><span>{{ t('calculator.change') }}</span><strong>{{ money(changeResult) }}</strong></p>
          </div>
        </template>
      </div>
    </div>
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
  background: #fff;
  color: #3d5c73;
  cursor: pointer;
}

.calc-btn:hover,
.calc-btn--open {
  border-color: #4a6d86;
  background: #e8f0f5;
  color: #3d5c73;
}
</style>

<style>
/* Unscoped: panel is teleported to body so it must pin to the viewport corner. */
.calc-panel {
  position: fixed !important;
  top: auto !important;
  left: auto !important;
  right: 16px !important;
  bottom: 16px !important;
  z-index: 9999 !important;
  width: min(22.5rem, calc(100vw - 2rem));
  max-height: min(78dvh, 40rem);
  overflow: auto;
  border: 1px solid #e2e8f0;
  border-radius: 1rem;
  background: #fff;
  box-shadow: 0 18px 40px rgba(15, 23, 42, 0.16);
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
  padding: 0.75rem 0.85rem;
  border-top: 3px solid #4a6d86;
  background: #f7f9fb;
}

.calc-panel__title {
  margin: 0;
  font-size: 0.9rem;
  font-weight: 700;
  color: #1c2830;
}

.calc-panel__close {
  display: inline-flex;
  width: 1.6rem;
  height: 1.6rem;
  align-items: center;
  justify-content: center;
  border: 1px solid #fecaca;
  border-radius: 999px;
  background: #fef2f2;
  color: #dc2626;
  font-size: 1.05rem;
  font-weight: 700;
  line-height: 1;
  cursor: pointer;
}

.calc-panel__close:hover {
  background: #dc2626;
  border-color: #dc2626;
  color: #fff;
}

.calc-tabs {
  display: flex;
  gap: 0.35rem;
  padding: 0.7rem 0.75rem 0;
}

.calc-tabs--sub { padding-top: 0; }

.calc-tab {
  flex: 1;
  border: 1px solid #e2e8f0;
  border-radius: 999px;
  background: #fff;
  color: #64748b;
  padding: 0.35rem 0.4rem;
  font-size: 0.7rem;
  font-weight: 650;
  cursor: pointer;
}

.calc-tab--active {
  border-color: #4a6d86;
  background: #e8f0f5;
  color: #3d5c73;
}

.calc-screen {
  margin: 0.7rem 0.75rem 0.55rem;
  padding: 0.7rem 0.8rem;
  border-radius: 0.8rem;
  background: #1c2830;
  color: #fff;
  text-align: right;
}

.calc-screen__expr {
  margin: 0;
  min-height: 1rem;
  overflow: hidden;
  color: rgba(255, 255, 255, 0.55);
  font-size: 0.72rem;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.calc-screen__value {
  margin: 0.15rem 0 0;
  font-size: 1.45rem;
  font-weight: 700;
  letter-spacing: -0.03em;
}

.calc-tools {
  display: flex;
  flex-wrap: wrap;
  gap: 0.3rem;
  padding: 0 0.75rem 0.45rem;
}

.calc-chip {
  border: 1px solid #e2e8f0;
  border-radius: 0.45rem;
  background: #f7f9fb;
  color: #3d5c73;
  padding: 0.28rem 0.45rem;
  font-size: 0.68rem;
  font-weight: 650;
  cursor: pointer;
}

.calc-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 0.35rem;
  padding: 0 0.75rem 0.55rem;
}

.calc-key {
  height: 2.35rem;
  border: 1px solid #e2e8f0;
  border-radius: 0.65rem;
  background: #fff;
  color: #1c2830;
  font-size: 0.95rem;
  font-weight: 650;
  cursor: pointer;
}

.calc-key:hover { background: #f7f9fb; }
.calc-key--op { background: #e8f0f5; color: #3d5c73; }
.calc-key--clear { background: #fff8f8; color: #dc2626; }
.calc-key--eq { background: #4a6d86; border-color: #4a6d86; color: #fff; }

.calc-memory {
  display: flex;
  align-items: center;
  gap: 0.35rem;
  padding: 0 0.75rem 0.8rem;
  color: #64748b;
  font-size: 0.68rem;
}

.calc-memory span { flex: 1; }
.calc-memory button {
  border: 1px solid #e2e8f0;
  border-radius: 0.4rem;
  background: #fff;
  color: #3d5c73;
  padding: 0.2rem 0.4rem;
  font-size: 0.68rem;
  cursor: pointer;
}

.calc-business { padding: 0.75rem; }

.calc-field {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  margin-bottom: 0.55rem;
  color: #64748b;
  font-size: 0.72rem;
  font-weight: 650;
}

.calc-field input {
  border: 1px solid #cbd5e1;
  border-radius: 0.55rem;
  padding: 0.5rem 0.65rem;
  font-size: 0.9rem;
  color: #1c2830;
}

.calc-results {
  border-radius: 0.75rem;
  background: #f7f9fb;
  padding: 0.65rem 0.75rem;
}

.calc-results p {
  display: flex;
  justify-content: space-between;
  gap: 0.75rem;
  margin: 0.3rem 0;
  color: #64748b;
  font-size: 0.78rem;
}

.calc-results strong { color: #1c2830; }
</style>
