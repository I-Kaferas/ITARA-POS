<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import PageFrame from '../../../components/layout/PageFrame.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import Badge from '../../../components/ui/Badge.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { extractApiErrorMessage } from '../../../api/client'
import { useBackofficeStore } from '../../../stores/backoffice'
import { getAppCurrency } from '../../../utils/currency'
import { intlLocale } from '../../../i18n/locales'
import { parseMoneyInput } from '../../../utils/money'

type Category = { id: string; name: string }
type FundSource = 'operating' | 'social' | 'main'
type RecurringRow = {
  id: string
  name: string
  amount: number
  frequency: string
  fund_source: FundSource
  next_due_on: string
  starts_on?: string | null
  ends_on?: string | null
  notes?: string | null
  is_active: boolean
  expense_category_id?: string | null
  user_id?: string | null
  expense_category?: { name: string } | null
  user?: { name: string } | null
}

const EXAMPLE_KEYS = ['water', 'internet', 'supplies', 'software', 'rent'] as const
const FREQUENCIES = ['daily', 'weekly', 'monthly', 'quarterly', 'yearly'] as const
const FUNDS: FundSource[] = ['operating', 'social', 'main']
const FUND_MARK: Record<FundSource, string> = {
  operating: '💰',
  social: '❤️',
  main: '🏦',
}
const MONTHLY_FACTOR: Record<string, number> = {
  daily: 30,
  weekly: 52 / 12,
  monthly: 1,
  quarterly: 1 / 3,
  yearly: 1 / 12,
}

const { t, locale } = useI18n()
const store = useBackofficeStore()

const rows = ref<RecurringRow[]>([])
const categories = ref<Category[]>([])
const currency = computed(() => getAppCurrency())
const query = ref('')
const loading = ref(false)
const saving = ref(false)
const showModal = ref(false)
const editing = ref<RecurringRow | null>(null)
const formError = ref('')
const form = ref(emptyForm())

const filtered = computed(() => {
  const q = query.value.trim().toLowerCase()
  if (!q) return rows.value
  return rows.value.filter((row) => {
    const haystack = [
      row.name,
      row.expense_category?.name,
      row.user?.name,
      fundLabel(row.fund_source),
      row.notes,
      row.is_active ? t('expenses.recurringView.statusActive') : t('expenses.recurringView.statusInactive'),
      weekday(row.next_due_on),
      formatDate(row.next_due_on),
    ].filter(Boolean).join(' ').toLowerCase()
    return haystack.includes(q)
  })
})

const activeCount = computed(() => rows.value.filter(row => row.is_active).length)
const inactiveCount = computed(() => rows.value.filter(row => !row.is_active).length)
const monthlyBudget = computed(() => rows.value.reduce((sum, row) => {
  if (!row.is_active) return sum
  const factor = MONTHLY_FACTOR[row.frequency] ?? 1
  return sum + Math.round(row.amount * factor)
}, 0))

onMounted(async () => {
  const [categoryRows] = await Promise.all([
    store.loadExpenseCategories().catch(() => []),
    store.loadUsers().catch(() => []),
  ])
  categories.value = categoryRows as Category[]
  await load()
})

function emptyForm(name = '') {
  return {
    name,
    amount: '',
    fund_source: 'operating' as FundSource,
    expense_category_id: '',
    user_id: '',
    starts_on: todayInput(),
    ends_on: '',
    frequency: 'monthly',
    notes: '',
  }
}

function fundLabel(source?: string | null) {
  if (source === 'operating' || source === 'social' || source === 'main') {
    return t(`expenses.recurringView.funds.${source}`)
  }
  return '—'
}

function frequencyLabel(value?: string | null) {
  if (value && FREQUENCIES.includes(value as typeof FREQUENCIES[number])) {
    return t(`expenses.recurringView.frequencies.${value}`)
  }
  return value || '—'
}

function todayInput() {
  const date = new Date()
  const pad = (part: number) => String(part).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`
}

function formatAmount(cents: number) {
  const major = (Number(cents) || 0) / 100
  const digits = Number.isInteger(major) ? 0 : 2
  const formatted = new Intl.NumberFormat(intlLocale(), {
    minimumFractionDigits: digits,
    maximumFractionDigits: digits,
  }).format(major)
  return `${formatted} ${getAppCurrency()}`
}

function formatDate(value?: string | null) {
  if (!value) return '—'
  return new Intl.DateTimeFormat(locale.value, {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  }).format(new Date(`${value.slice(0, 10)}T00:00:00`))
}

function weekday(value?: string | null) {
  if (!value) return ''
  return new Intl.DateTimeFormat(locale.value, { weekday: 'short' }).format(new Date(`${value.slice(0, 10)}T00:00:00`))
}

async function generateDue() {
  loading.value = true
  try {
    await store.generateRecurringExpenses()
    rows.value = (await store.loadRecurringExpenses()) as RecurringRow[]
  } finally {
    loading.value = false
  }
}

async function load() {
  loading.value = true
  try {
    rows.value = (await store.loadRecurringExpenses()) as RecurringRow[]
  } finally {
    loading.value = false
  }
}

function openCreate(name = '') {
  editing.value = null
  formError.value = ''
  form.value = emptyForm(name)
  showModal.value = true
}

function openEdit(row: RecurringRow) {
  editing.value = row
  formError.value = ''
  form.value = {
    name: row.name,
    amount: String((row.amount || 0) / 100),
    fund_source: row.fund_source || 'main',
    expense_category_id: row.expense_category_id ?? '',
    user_id: row.user_id ?? '',
    starts_on: row.starts_on?.slice(0, 10) || row.next_due_on?.slice(0, 10) || todayInput(),
    ends_on: row.ends_on?.slice(0, 10) ?? '',
    frequency: row.frequency || 'monthly',
    notes: row.notes ?? '',
  }
  showModal.value = true
}

async function save() {
  const amount = parseMoneyInput(form.value.amount)
  if (!form.value.name.trim() || !form.value.expense_category_id || !form.value.starts_on || !form.value.fund_source) return
  if (amount < 1) {
    formError.value = t('expenses.recurringView.amountInvalid')
    return
  }
  if (form.value.ends_on && form.value.ends_on < form.value.starts_on) return
  saving.value = true
  formError.value = ''
  try {
    await store.saveRecurringExpense({
      name: form.value.name.trim(),
      amount,
      fund_source: form.value.fund_source,
      expense_category_id: form.value.expense_category_id,
      user_id: form.value.user_id || null,
      starts_on: form.value.starts_on,
      ends_on: form.value.ends_on || null,
      frequency: form.value.frequency,
      notes: form.value.notes.trim() || null,
      currency_code: currency.value,
    }, editing.value?.id)
    showModal.value = false
    await load()
  } catch (error) {
    formError.value = extractApiErrorMessage(error)
  } finally {
    saving.value = false
  }
}

async function toggleActive(row: RecurringRow, close = false) {
  saving.value = true
  formError.value = ''
  try {
    await store.saveRecurringExpense({ is_active: !row.is_active }, row.id)
    if (close) showModal.value = false
    await load()
  } catch (error) {
    formError.value = extractApiErrorMessage(error)
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <PageFrame>
    <template #title>{{ t('expenses.recurringView.title') }}</template>
    <template #subtitle>{{ t('expenses.recurringView.subtitle') }}</template>

    <div class="recur">
      <div class="recur__toolbar">
        <button class="btn-secondary" type="button" :disabled="loading" @click="load">
          <AppIcon name="refresh" :size="16" />
          {{ t('expenses.recurringView.refresh') }}
        </button>
        <button class="btn-secondary" type="button" :disabled="loading" @click="generateDue">
          {{ t('expenses.recurringView.generate') }}
        </button>
        <button class="btn-primary" type="button" @click="openCreate()">
          <AppIcon name="plus" :size="16" />
          {{ t('expenses.recurringView.new') }}
        </button>
      </div>

      <section class="recur__stats">
        <article class="recur__stat recur__stat--active">
          <p>{{ t('expenses.recurringView.active') }}</p>
          <strong>{{ activeCount }}</strong>
        </article>
        <article class="recur__stat">
          <p>{{ t('expenses.recurringView.inactive') }}</p>
          <strong>{{ inactiveCount }}</strong>
        </article>
        <article class="recur__stat recur__stat--budget">
          <p>{{ t('expenses.recurringView.monthlyBudget') }}</p>
          <strong>{{ formatAmount(monthlyBudget) }}</strong>
        </article>
      </section>

      <section class="recur__examples">
        <h2>{{ t('expenses.recurringView.examplesTitle') }}</h2>
        <div class="recur__chips">
          <button
            v-for="key in EXAMPLE_KEYS"
            :key="key"
            type="button"
            class="recur__chip"
            @click="openCreate(t(`expenses.recurringView.examples.${key}`))"
          >
            {{ t(`expenses.recurringView.examples.${key}`) }}
          </button>
        </div>
      </section>

      <label class="recur__search">
        <span class="sr-only">{{ t('expenses.recurringView.search') }}</span>
        <AppIcon name="search" :size="16" class="recur__search-icon" />
        <input
          v-model="query"
          class="field"
          type="search"
          :placeholder="t('expenses.recurringView.search')"
        />
      </label>

      <div class="recur__cards">
        <p v-if="!filtered.length" class="recur__empty">{{ t('expenses.recurringView.empty') }}</p>
        <article v-for="row in filtered" :key="row.id" class="recur__card" @click="openEdit(row)">
          <header class="recur__card-head">
            <div>
              <div class="recur__name">{{ row.name }}</div>
              <div class="recur__freq">{{ frequencyLabel(row.frequency) }}</div>
            </div>
            <button type="button" class="recur__status" @click.stop="toggleActive(row)">
              <Badge :variant="row.is_active ? 'success' : 'neutral'" dot>
                {{ row.is_active ? t('expenses.recurringView.statusActive') : t('expenses.recurringView.statusInactive') }}
              </Badge>
            </button>
          </header>
          <p class="recur__card-amount">{{ formatAmount(row.amount) }}</p>
          <dl class="recur__facts">
            <div>
              <dt>{{ t('expenses.recurringView.columns.category') }}</dt>
              <dd>{{ row.expense_category?.name ?? '—' }}</dd>
            </div>
            <div>
              <dt>{{ t('expenses.recurringView.columns.register') }}</dt>
              <dd>{{ fundLabel(row.fund_source) }}</dd>
            </div>
            <div>
              <dt>{{ t('expenses.recurringView.columns.nextDate') }}</dt>
              <dd>{{ weekday(row.next_due_on) }} {{ formatDate(row.next_due_on) }}</dd>
            </div>
          </dl>
        </article>
      </div>

      <div class="recur__table">
        <table class="ui-table">
          <thead>
            <tr>
              <th>{{ t('expenses.recurringView.columns.expense') }}</th>
              <th>{{ t('expenses.recurringView.columns.amount') }}</th>
              <th>{{ t('expenses.recurringView.columns.category') }}</th>
              <th>{{ t('expenses.recurringView.columns.register') }}</th>
              <th>{{ t('expenses.recurringView.columns.nextDate') }}</th>
              <th>{{ t('expenses.recurringView.columns.status') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="!filtered.length">
              <td class="recur__empty" colspan="6">{{ t('expenses.recurringView.empty') }}</td>
            </tr>
            <tr v-for="row in filtered" :key="row.id" class="recur__row" @click="openEdit(row)">
              <td>
                <div class="recur__name">{{ row.name }}</div>
                <div class="recur__freq">{{ frequencyLabel(row.frequency) }}</div>
              </td>
              <td class="recur__amount">{{ formatAmount(row.amount) }}</td>
              <td>{{ row.expense_category?.name ?? '—' }}</td>
              <td>{{ fundLabel(row.fund_source) }}</td>
              <td>
                <div class="recur__weekday">{{ weekday(row.next_due_on) }}</div>
                <div>{{ formatDate(row.next_due_on) }}</div>
              </td>
              <td @click.stop>
                <button type="button" class="recur__status" @click="toggleActive(row)">
                  <Badge :variant="row.is_active ? 'success' : 'neutral'" dot>
                    {{ row.is_active ? t('expenses.recurringView.statusActive') : t('expenses.recurringView.statusInactive') }}
                  </Badge>
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <AppModal
      :open="showModal"
      :title="editing ? t('expenses.recurringView.edit') : t('expenses.recurringView.new')"
      :subtitle="t('expenses.recurringView.formSubtitle')"
      icon="calendar"
      tone="accent"
      size="md"
      @close="showModal = false"
    >
      <form class="recur-form" @submit.prevent="save">
        <p v-if="formError" class="recur-form__error">{{ formError }}</p>

        <fieldset class="recur-form__funds">
          <legend>{{ t('expenses.recurringView.fund') }} <span aria-hidden="true">*</span></legend>
          <button
            v-for="fund in FUNDS"
            :key="fund"
            type="button"
            class="recur-form__fund"
            :class="{ 'is-on': form.fund_source === fund }"
            @click="form.fund_source = fund"
          >
            <span class="recur-form__mark" aria-hidden="true">{{ FUND_MARK[fund] }}</span>
            {{ t(`expenses.recurringView.funds.${fund}`) }}
          </button>
        </fieldset>

        <div>
          <FieldLabel icon="tag">{{ t('expenses.recurringView.name') }} <span aria-hidden="true">*</span></FieldLabel>
          <input
            v-model="form.name"
            class="field"
            required
            maxlength="255"
            :placeholder="t('expenses.recurringView.namePlaceholder')"
          />
        </div>

        <div>
          <FieldLabel icon="coins">{{ t('expenses.amount') }} <span aria-hidden="true">*</span></FieldLabel>
          <div class="recur-form__money">
            <input
              v-model="form.amount"
              class="field"
              inputmode="decimal"
              required
              placeholder="0"
            />
            <span>{{ currency }}</span>
          </div>
        </div>

        <div>
          <FieldLabel icon="refresh">{{ t('expenses.recurringView.frequency') }} <span aria-hidden="true">*</span></FieldLabel>
          <select v-model="form.frequency" class="field" required>
            <option v-for="item in FREQUENCIES" :key="item" :value="item">{{ frequencyLabel(item) }}</option>
          </select>
        </div>

        <div>
          <FieldLabel icon="layers">{{ t('expenses.category') }} <span aria-hidden="true">*</span></FieldLabel>
          <select v-model="form.expense_category_id" class="field" required>
            <option value="" disabled>{{ t('expenses.recurringView.categoryPlaceholder') }}</option>
            <option v-for="category in categories" :key="category.id" :value="category.id">{{ category.name }}</option>
          </select>
        </div>

        <div>
          <FieldLabel icon="account">{{ t('expenses.recurringView.owner') }}</FieldLabel>
          <select v-model="form.user_id" class="field">
            <option value="">{{ t('expenses.recurringView.ownerPlaceholder') }}</option>
            <option v-for="user in store.users" :key="user.id" :value="user.id">{{ user.name }}</option>
          </select>
        </div>

        <div>
          <FieldLabel icon="calendar">{{ t('expenses.recurringView.startDate') }} <span aria-hidden="true">*</span></FieldLabel>
          <input v-model="form.starts_on" class="field" type="date" required />
        </div>

        <div>
          <FieldLabel icon="calendar">{{ t('expenses.recurringView.endDate') }}</FieldLabel>
          <input v-model="form.ends_on" class="field" type="date" />
        </div>

        <div>
          <FieldLabel icon="tag">{{ t('expenses.recurringView.notes') }}</FieldLabel>
          <textarea
            v-model="form.notes"
            class="field"
            rows="3"
            maxlength="1000"
            :placeholder="t('expenses.recurringView.notesPlaceholder')"
          />
        </div>

        <p class="recur-form__hint">{{ t('expenses.recurringView.hint') }}</p>

        <div class="recur-form__actions">
          <button
            v-if="editing"
            class="btn-secondary"
            type="button"
            :disabled="saving"
            @click="toggleActive(editing, true)"
          >
            {{ editing.is_active ? t('expenses.recurringView.deactivate') : t('expenses.recurringView.activate') }}
          </button>
          <button class="btn-secondary" type="button" @click="showModal = false">{{ t('expenses.cancel') }}</button>
          <button class="btn-primary" type="submit" :disabled="saving">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>
  </PageFrame>
</template>

<style scoped>
.recur {
  display: flex;
  flex-direction: column;
  gap: var(--space-4);
}

.recur__toolbar {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: var(--space-2);
}

.recur__toolbar :is(.btn-primary, .btn-secondary) {
  border-radius: 0;
}

.recur__stats {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: var(--space-3);
}

.recur__stat {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
  padding: var(--space-4);
  border: 1px solid var(--color-border);
  border-left: 4px solid var(--color-border-strong);
  background: var(--color-surface);
}

.recur__stat--active {
  border-left-color: var(--color-success);
}

.recur__stat--budget {
  border-left-color: var(--color-accent);
}

.recur__stat p {
  margin: 0;
  font-size: var(--text-xs);
  font-weight: 650;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--color-text-muted);
}

.recur__stat strong {
  font-size: 1.65rem;
  font-weight: 650;
  letter-spacing: -0.03em;
  color: var(--color-text-primary);
}

.recur__examples h2 {
  margin: 0 0 var(--space-3);
  font-size: var(--text-sm);
  font-weight: 650;
  color: var(--color-text-secondary);
}

.recur__chips {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
}

.recur__chip {
  padding: 0.45rem 0.7rem;
  border: 1px solid var(--color-border);
  background: var(--color-surface);
  color: var(--color-text-primary);
  font-size: var(--text-sm);
  font-weight: 600;
  text-align: left;
  cursor: pointer;
}

.recur__chip:hover {
  border-color: var(--color-brand-700);
  background: var(--color-surface-muted);
}

.recur__search {
  position: relative;
  max-width: 22rem;
}

.recur__search-icon {
  position: absolute;
  top: 50%;
  left: 0.75rem;
  color: var(--color-text-muted);
  transform: translateY(-50%);
  pointer-events: none;
}

.recur__search .field {
  width: 100%;
  padding-left: 2.25rem;
  border-radius: 0;
}

.recur__table {
  overflow-x: auto;
  border: 1px solid var(--color-border);
  background: var(--color-surface);
}

.recur__row {
  cursor: pointer;
}

.recur__name {
  font-weight: 650;
  color: var(--color-text-primary);
}

.recur__freq,
.recur__weekday {
  font-size: var(--text-xs);
  color: var(--color-text-muted);
}

.recur__weekday {
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: capitalize;
}

.recur__amount {
  font-variant-numeric: tabular-nums;
  font-weight: 650;
}

.recur__empty {
  padding: 2.5rem 1rem;
  text-align: center;
  color: var(--color-text-muted);
}

.recur__status {
  padding: 0;
  border: 0;
  background: transparent;
  cursor: pointer;
}

.recur-form {
  display: flex;
  flex-direction: column;
  gap: var(--space-4);
}

.recur-form__error {
  margin: 0;
  color: var(--color-danger);
  font-size: var(--text-sm);
}

.recur-form__funds {
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
  margin: 0;
  padding: 0;
  border: 0;
}

.recur-form__funds legend {
  margin-bottom: 0.35rem;
  font-size: var(--text-sm);
  font-weight: 650;
  color: var(--color-text-primary);
}

.recur-form__fund {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  width: 100%;
  padding: 0.75rem 0.85rem;
  border: 1px solid var(--color-border);
  background: var(--color-surface);
  color: var(--color-text-primary);
  font-size: var(--text-sm);
  font-weight: 650;
  text-align: left;
  cursor: pointer;
}

.recur-form__fund.is-on {
  border-color: var(--color-brand-700);
  background: var(--color-surface-muted);
  box-shadow: inset 4px 0 0 var(--color-brand-700);
}

.recur-form__mark {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 2rem;
  height: 2rem;
  background: var(--color-canvas);
  font-size: 1.05rem;
}

.recur-form__money {
  position: relative;
}

.recur-form__money .field {
  width: 100%;
  padding-right: 3.5rem;
}

.recur-form__money span {
  position: absolute;
  top: 50%;
  right: 0.85rem;
  color: var(--color-text-muted);
  font-size: var(--text-sm);
  font-weight: 650;
  pointer-events: none;
  transform: translateY(-50%);
}

.recur-form__hint {
  margin: 0;
  color: var(--color-text-muted);
  font-size: var(--text-sm);
  line-height: 1.45;
}

.recur-form__actions {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: var(--space-2);
}

.recur-form :is(.field, textarea) {
  border-radius: 0;
}

.recur__cards {
  display: none;
}

.recur__card {
  display: flex;
  flex-direction: column;
  gap: 0.65rem;
  padding: var(--space-4);
  border: 1px solid var(--color-border);
  border-left: 4px solid var(--color-brand-700);
  background: var(--color-surface);
  cursor: pointer;
}

.recur__card-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: var(--space-3);
}

.recur__card-amount {
  margin: 0;
  font-size: 1.35rem;
  font-weight: 650;
  letter-spacing: -0.03em;
  color: var(--color-text-primary);
}

.recur__facts {
  display: grid;
  gap: 0.45rem;
  margin: 0;
}

.recur__facts div {
  display: grid;
  grid-template-columns: 7.5rem minmax(0, 1fr);
  gap: 0.5rem;
  align-items: baseline;
}

.recur__facts dt {
  margin: 0;
  font-size: var(--text-xs);
  font-weight: 650;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--color-text-muted);
}

.recur__facts dd {
  margin: 0;
  font-size: var(--text-sm);
  font-weight: 600;
  color: var(--color-text-primary);
}

@media (max-width: 800px) {
  .recur__toolbar {
    flex-direction: column;
    align-items: stretch;
  }

  .recur__toolbar :is(.btn-primary, .btn-secondary) {
    justify-content: center;
    width: 100%;
    white-space: normal;
    text-align: center;
  }

  .recur__stats {
    grid-template-columns: 1fr;
  }

  .recur__stat {
    flex-direction: row;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-3);
    padding: 0.85rem 1rem;
  }

  .recur__stat strong {
    font-size: 1.25rem;
    text-align: right;
  }

  .recur__search {
    max-width: none;
  }

  .recur__cards {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }

  .recur__table {
    display: none;
  }

  .recur-form__actions {
    flex-direction: column-reverse;
    align-items: stretch;
  }

  .recur-form__actions :is(.btn-primary, .btn-secondary) {
    justify-content: center;
    width: 100%;
  }

  .recur-form :is(.field, textarea, select) {
    font-size: 1rem;
  }
}
</style>
