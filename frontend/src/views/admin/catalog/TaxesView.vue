<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { extractApiErrorMessage } from '../../../api/client'
import CatalogLayout from '../../../components/catalog/CatalogLayout.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import ModuleFilters from '../../../components/ui/ModuleFilters.vue'
import { useConfirm } from '../../../composables/useConfirm'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { Tax, TaxClass, TaxGroup, TaxRegisterRow, TaxReportRow, TaxRule } from '../../../types'
import { formatDateTime } from '../../../utils/format'
import { emptyListFilters, matchesActive, matchesSearch, type ListFilters } from '../../../utils/listFilters'
import { formatMoney, parseMoneyInput } from '../../../utils/money'

type Tab = 'report' | 'register' | 'groups' | 'classes' | 'rules' | 'calculator'

const COUNTRIES = [
  { code: '', label: 'all' },
  { code: 'CD', label: 'CD' },
  { code: 'CG', label: 'CG' },
  { code: 'RW', label: 'RW' },
  { code: 'BI', label: 'BI' },
  { code: 'UG', label: 'UG' },
  { code: 'TZ', label: 'TZ' },
  { code: 'ZM', label: 'ZM' },
  { code: 'AO', label: 'AO' },
  { code: 'KE', label: 'KE' },
  { code: 'FR', label: 'FR' },
  { code: 'BE', label: 'BE' },
]

const { t } = useI18n()
const { confirm: confirmDialog, notify } = useConfirm()
const store = useBackofficeStore()

const tab = ref<Tab>('register')
const saving = ref(false)
const showTax = ref(false)
const editingTax = ref<Tax | null>(null)
const showGroup = ref(false)
const editingGroup = ref<TaxGroup | null>(null)
const showClass = ref(false)
const editingClass = ref<TaxClass | null>(null)
const showRule = ref(false)
const editingRule = ref<TaxRule | null>(null)

const groups = ref<TaxGroup[]>([])
const classes = ref<TaxClass[]>([])
const rules = ref<TaxRule[]>([])
const reportRows = ref<TaxReportRow[]>([])
const reportTotals = ref({ taxable_amount: 0, tax_amount: 0, lines: 0 })
const journal = ref<TaxRegisterRow[]>([])
const period = ref({ from: monthStart(), to: today() })

const taxForm = ref(emptyTax())
const groupForm = ref(emptyGroup())
const classForm = ref(emptyClass())
const ruleForm = ref(emptyRule())
const calc = ref({
  amount: '',
  amount_is_inclusive: true,
  tax_ids: [] as string[],
  tax_group_id: '',
})
const calcResult = ref<{ net: number; tax_total: number; total: number; lines: { tax_id: string; name: string; code: string; rate: number; priority: number; is_inclusive: boolean; is_compound: boolean; taxable_amount: number; tax_amount: number }[] } | null>(null)

const tabs = computed(() => [
  { id: 'report' as Tab, label: t('catalog.tax.tabs.report') },
  { id: 'register' as Tab, label: t('catalog.tax.tabs.register') },
  { id: 'groups' as Tab, label: t('catalog.tax.tabs.groups') },
  { id: 'classes' as Tab, label: t('catalog.tax.tabs.classes') },
  { id: 'rules' as Tab, label: t('catalog.tax.tabs.rules') },
  { id: 'calculator' as Tab, label: t('catalog.tax.tabs.calculator') },
])

const activeTaxes = computed(() => store.taxes.filter(tax => tax.is_active))
const registerFilters = ref<ListFilters>(emptyListFilters('all'))
const filteredTaxes = computed(() => store.taxes.filter(tax =>
  matchesSearch(`${tax.name} ${tax.code}`, registerFilters.value.search)
  && matchesActive(tax.is_active, registerFilters.value.active),
))

function today() {
  const now = new Date()
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`
}

function monthStart() {
  const now = new Date()
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`
}

function emptyTax() {
  return {
    name: '',
    code: '',
    rate: 0,
    type: 'percentage',
    priority: 1,
    country: '',
    region: '',
    is_inclusive: false,
    is_compound: false,
    is_active: true,
    description: '',
  }
}

function emptyGroup() {
  return { name: '', code: '', description: '', is_active: true, tax_ids: [] as string[] }
}

function emptyClass() {
  return { name: '', code: '', description: '', is_active: true }
}

function emptyRule() {
  return {
    name: '',
    tax_class_id: '',
    tax_id: '',
    tax_group_id: '',
    country: '',
    region: '',
    priority: 1,
    is_active: true,
    description: '',
  }
}

function countryLabel(code?: string | null) {
  if (!code) return t('catalog.tax.allCountries')
  return t(`catalog.tax.countries.${code}`)
}

onMounted(async () => {
  await refreshDefinitions()
  await refreshFiscal()
})

async function refreshDefinitions() {
  await store.loadTaxes(false)
  groups.value = await store.loadTaxGroups()
  classes.value = await store.loadTaxClasses()
  rules.value = await store.loadTaxRules()
}

async function refreshFiscal() {
  const report = await store.loadTaxReport(period.value.from, period.value.to)
  reportRows.value = report.summary
  reportTotals.value = {
    taxable_amount: report.taxable_amount,
    tax_amount: report.tax_amount,
    lines: report.lines,
  }
  journal.value = await store.loadTaxRegister(period.value.from, period.value.to)
}

function openTax(tax?: Tax) {
  editingTax.value = tax ?? null
  taxForm.value = tax
    ? {
        name: tax.name,
        code: tax.code,
        rate: Number(tax.rate),
        type: tax.type || 'percentage',
        priority: tax.priority || 1,
        country: tax.country || '',
        region: tax.region || '',
        is_inclusive: tax.is_inclusive,
        is_compound: Boolean(tax.is_compound),
        is_active: tax.is_active,
        description: tax.description || '',
      }
    : emptyTax()
  showTax.value = true
}

function openGroup(group?: TaxGroup) {
  editingGroup.value = group ?? null
  groupForm.value = group
    ? {
        name: group.name,
        code: group.code,
        description: group.description || '',
        is_active: group.is_active,
        tax_ids: (group.taxes ?? []).map(tax => tax.id),
      }
    : emptyGroup()
  showGroup.value = true
}

function openClass(row?: TaxClass) {
  editingClass.value = row ?? null
  classForm.value = row
    ? { name: row.name, code: row.code, description: row.description || '', is_active: row.is_active }
    : emptyClass()
  showClass.value = true
}

function openRule(row?: TaxRule) {
  editingRule.value = row ?? null
  ruleForm.value = row
    ? {
        name: row.name,
        tax_class_id: row.tax_class_id || '',
        tax_id: row.tax_id || '',
        tax_group_id: row.tax_group_id || '',
        country: row.country || '',
        region: row.region || '',
        priority: row.priority || 1,
        is_active: row.is_active,
        description: row.description || '',
      }
    : emptyRule()
  showRule.value = true
}

function taxPayload() {
  return {
    ...taxForm.value,
    country: taxForm.value.country || null,
    region: taxForm.value.region || null,
    description: taxForm.value.description || null,
  }
}

async function saveTax() {
  saving.value = true
  try {
    await store.saveTax(taxPayload(), editingTax.value?.id)
    await store.loadTaxes(false)
    showTax.value = false
  } catch (error) {
    await notify(extractApiErrorMessage(error))
  } finally {
    saving.value = false
  }
}

async function removeTax(tax: Tax) {
  if (!(await confirmDialog(t('org.confirmDelete')))) return
  await store.deleteTax(tax.id)
  await store.loadTaxes(false)
}

async function saveGroup() {
  saving.value = true
  try {
    await store.saveTaxGroup({
      name: groupForm.value.name,
      code: groupForm.value.code,
      description: groupForm.value.description || null,
      is_active: groupForm.value.is_active,
      tax_ids: groupForm.value.tax_ids,
    }, editingGroup.value?.id)
    groups.value = await store.loadTaxGroups()
    showGroup.value = false
  } catch (error) {
    await notify(extractApiErrorMessage(error))
  } finally {
    saving.value = false
  }
}

async function removeGroup(group: TaxGroup) {
  if (!(await confirmDialog(t('org.confirmDelete')))) return
  await store.deleteTaxGroup(group.id)
  groups.value = await store.loadTaxGroups()
}

async function saveClass() {
  saving.value = true
  try {
    await store.saveTaxClass({
      ...classForm.value,
      description: classForm.value.description || null,
    }, editingClass.value?.id)
    classes.value = await store.loadTaxClasses()
    showClass.value = false
  } catch (error) {
    await notify(extractApiErrorMessage(error))
  } finally {
    saving.value = false
  }
}

async function removeClass(row: TaxClass) {
  if (!(await confirmDialog(t('org.confirmDelete')))) return
  await store.deleteTaxClass(row.id)
  classes.value = await store.loadTaxClasses()
}

async function saveRule() {
  saving.value = true
  try {
    await store.saveTaxRule({
      ...ruleForm.value,
      tax_class_id: ruleForm.value.tax_class_id || null,
      tax_id: ruleForm.value.tax_id || null,
      tax_group_id: ruleForm.value.tax_group_id || null,
      country: ruleForm.value.country || null,
      region: ruleForm.value.region || null,
      description: ruleForm.value.description || null,
    }, editingRule.value?.id)
    rules.value = await store.loadTaxRules()
    showRule.value = false
  } catch (error) {
    await notify(extractApiErrorMessage(error))
  } finally {
    saving.value = false
  }
}

async function removeRule(row: TaxRule) {
  if (!(await confirmDialog(t('org.confirmDelete')))) return
  await store.deleteTaxRule(row.id)
  rules.value = await store.loadTaxRules()
}

async function runCalculator() {
  saving.value = true
  calcResult.value = null
  try {
    calcResult.value = await store.calculateTaxes({
      amount: parseMoneyInput(calc.value.amount),
      amount_is_inclusive: calc.value.amount_is_inclusive,
      tax_ids: calc.value.tax_ids,
      tax_group_id: calc.value.tax_group_id || undefined,
    })
  } catch (error) {
    await notify(extractApiErrorMessage(error))
  } finally {
    saving.value = false
  }
}

function toggleCalcTax(id: string, checked: boolean) {
  calc.value.tax_ids = checked
    ? [...calc.value.tax_ids, id]
    : calc.value.tax_ids.filter(item => item !== id)
}
</script>

<template>
  <CatalogLayout>
    <div class="space-y-4">
      <nav class="tax-tabs">
        <button
          v-for="item in tabs"
          :key="item.id"
          type="button"
          class="tax-tab"
          :class="{ 'tax-tab--active': tab === item.id }"
          @click="tab = item.id"
        >
          {{ item.label }}
        </button>
      </nav>

      <section v-if="tab === 'report'" class="space-y-4">
        <div class="flex flex-wrap items-end justify-between gap-3">
          <div class="flex flex-wrap gap-3">
            <div>
              <FieldLabel icon="calendar">{{ t('catalog.tax.from') }}</FieldLabel>
              <input v-model="period.from" type="date" class="field" />
            </div>
            <div>
              <FieldLabel icon="calendar">{{ t('catalog.tax.to') }}</FieldLabel>
              <input v-model="period.to" type="date" class="field" />
            </div>
          </div>
          <button type="button" class="btn-primary" @click="refreshFiscal">{{ t('catalog.tax.refresh') }}</button>
        </div>
        <div class="stats">
          <div><span>{{ t('catalog.tax.taxable') }}</span><strong>{{ formatMoney(reportTotals.taxable_amount) }}</strong></div>
          <div><span>{{ t('catalog.tax.collected') }}</span><strong>{{ formatMoney(reportTotals.tax_amount) }}</strong></div>
          <div><span>{{ t('catalog.tax.lines') }}</span><strong>{{ reportTotals.lines }}</strong></div>
        </div>
        <div class="panel">
          <table class="min-w-full text-sm">
            <thead class="bg-slate-50">
              <tr>
                <th>{{ t('catalog.tax.name') }}</th>
                <th>{{ t('catalog.tax.code') }}</th>
                <th>{{ t('catalog.rate') }}</th>
                <th>{{ t('catalog.tax.lines') }}</th>
                <th>{{ t('catalog.tax.taxable') }}</th>
                <th>{{ t('catalog.tax.collected') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in reportRows" :key="row.tax_id || row.name">
                <td>{{ row.name || '—' }}</td>
                <td class="font-mono">{{ row.code || '—' }}</td>
                <td>{{ row.rate }}%</td>
                <td>{{ row.lines }}</td>
                <td>{{ formatMoney(row.taxable_amount) }}</td>
                <td>{{ formatMoney(row.tax_amount) }}</td>
              </tr>
            </tbody>
          </table>
          <p v-if="!reportRows.length" class="empty">{{ t('catalog.tax.reportEmpty') }}</p>
        </div>
      </section>

      <section v-else-if="tab === 'register'" class="space-y-4">
        <div class="flex justify-end">
          <button class="btn-primary" @click="openTax()">+ {{ t('catalog.addTax') }}</button>
        </div>
        <ModuleFilters v-model="registerFilters" :show-period="false" show-search show-active />
        <div class="panel">
          <table class="min-w-full text-sm">
            <thead class="bg-slate-50">
              <tr>
                <th>{{ t('catalog.tax.name') }}</th>
                <th>{{ t('catalog.tax.code') }}</th>
                <th>{{ t('catalog.rate') }}</th>
                <th>{{ t('catalog.tax.priority') }}</th>
                <th>{{ t('catalog.tax.country') }}</th>
                <th>{{ t('catalog.tax.behavior') }}</th>
                <th>{{ t('products.status') }}</th>
                <th />
              </tr>
            </thead>
            <tbody>
              <tr v-for="tax in filteredTaxes" :key="tax.id">
                <td class="font-medium">{{ tax.name }}</td>
                <td class="font-mono">{{ tax.code }}</td>
                <td>{{ tax.rate }}%</td>
                <td>{{ tax.priority || 1 }}</td>
                <td>{{ countryLabel(tax.country) }}<span v-if="tax.region" class="block text-xs text-slate-500">{{ tax.region }}</span></td>
                <td>
                  <span v-if="tax.is_inclusive">{{ t('catalog.tax.inclusiveShort') }}</span>
                  <span v-if="tax.is_compound"> · {{ t('catalog.tax.compoundShort') }}</span>
                  <span v-if="!tax.is_inclusive && !tax.is_compound">—</span>
                </td>
                <td>{{ tax.is_active ? t('products.active') : t('catalog.tax.inactive') }}</td>
                <td class="text-right space-x-2">
                  <button class="text-brand-600" @click="openTax(tax)">{{ t('common.edit') }}</button>
                  <button class="text-red-600" @click="removeTax(tax)">{{ t('common.delete') }}</button>
                </td>
              </tr>
            </tbody>
          </table>
          <p v-if="!filteredTaxes.length" class="empty">{{ t('org.empty') }}</p>
        </div>
        <div class="panel">
          <h3 class="px-4 py-3 text-sm font-medium">{{ t('catalog.tax.journal') }}</h3>
          <table class="min-w-full text-sm">
            <thead class="bg-slate-50">
              <tr>
                <th>{{ t('catalog.tax.when') }}</th>
                <th>{{ t('catalog.tax.reference') }}</th>
                <th>{{ t('catalog.tax.name') }}</th>
                <th>{{ t('catalog.tax.taxable') }}</th>
                <th>{{ t('catalog.tax.collected') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in journal" :key="row.id">
                <td>{{ row.occurred_at ? formatDateTime(row.occurred_at) : '—' }}</td>
                <td class="font-mono">{{ row.reference || '—' }}</td>
                <td>{{ row.name || '—' }} <span class="text-xs text-slate-500">{{ row.rate }}%</span></td>
                <td>{{ formatMoney(row.taxable_amount) }}</td>
                <td>{{ formatMoney(row.tax_amount) }}</td>
              </tr>
            </tbody>
          </table>
          <p v-if="!journal.length" class="empty">{{ t('catalog.tax.journalEmpty') }}</p>
        </div>
      </section>

      <section v-else-if="tab === 'groups'" class="space-y-4">
        <div class="flex justify-end">
          <button class="btn-primary" @click="openGroup()">+ {{ t('catalog.tax.addGroup') }}</button>
        </div>
        <div class="panel">
          <table class="min-w-full text-sm">
            <thead class="bg-slate-50">
              <tr>
                <th>{{ t('catalog.tax.name') }}</th>
                <th>{{ t('catalog.tax.code') }}</th>
                <th>{{ t('catalog.tax.members') }}</th>
                <th>{{ t('products.status') }}</th>
                <th />
              </tr>
            </thead>
            <tbody>
              <tr v-for="group in groups" :key="group.id">
                <td class="font-medium">{{ group.name }}</td>
                <td class="font-mono">{{ group.code }}</td>
                <td>{{ (group.taxes ?? []).map(tax => tax.code).join(', ') || '—' }}</td>
                <td>{{ group.is_active ? t('products.active') : t('catalog.tax.inactive') }}</td>
                <td class="text-right space-x-2">
                  <button class="text-brand-600" @click="openGroup(group)">{{ t('common.edit') }}</button>
                  <button class="text-red-600" @click="removeGroup(group)">{{ t('common.delete') }}</button>
                </td>
              </tr>
            </tbody>
          </table>
          <p v-if="!groups.length" class="empty">{{ t('catalog.tax.groupsEmpty') }}</p>
        </div>
      </section>

      <section v-else-if="tab === 'classes'" class="space-y-4">
        <div class="flex justify-end">
          <button class="btn-primary" @click="openClass()">+ {{ t('catalog.tax.addClass') }}</button>
        </div>
        <div class="panel">
          <table class="min-w-full text-sm">
            <thead class="bg-slate-50">
              <tr>
                <th>{{ t('catalog.tax.name') }}</th>
                <th>{{ t('catalog.tax.code') }}</th>
                <th>{{ t('catalog.tax.description') }}</th>
                <th>{{ t('products.status') }}</th>
                <th />
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in classes" :key="row.id">
                <td class="font-medium">{{ row.name }}</td>
                <td class="font-mono">{{ row.code }}</td>
                <td>{{ row.description || '—' }}</td>
                <td>{{ row.is_active ? t('products.active') : t('catalog.tax.inactive') }}</td>
                <td class="text-right space-x-2">
                  <button class="text-brand-600" @click="openClass(row)">{{ t('common.edit') }}</button>
                  <button class="text-red-600" @click="removeClass(row)">{{ t('common.delete') }}</button>
                </td>
              </tr>
            </tbody>
          </table>
          <p v-if="!classes.length" class="empty">{{ t('catalog.tax.classesEmpty') }}</p>
        </div>
      </section>

      <section v-else-if="tab === 'rules'" class="space-y-4">
        <div class="flex justify-end">
          <button class="btn-primary" @click="openRule()">+ {{ t('catalog.tax.addRule') }}</button>
        </div>
        <div class="panel">
          <table class="min-w-full text-sm">
            <thead class="bg-slate-50">
              <tr>
                <th>{{ t('catalog.tax.name') }}</th>
                <th>{{ t('catalog.tax.class') }}</th>
                <th>{{ t('catalog.tax.applies') }}</th>
                <th>{{ t('catalog.tax.country') }}</th>
                <th>{{ t('catalog.tax.priority') }}</th>
                <th />
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in rules" :key="row.id">
                <td class="font-medium">{{ row.name }}</td>
                <td>{{ row.tax_class?.name || '—' }}</td>
                <td>{{ row.tax?.code || row.tax_group?.code || '—' }}</td>
                <td>{{ countryLabel(row.country) }}<span v-if="row.region" class="block text-xs text-slate-500">{{ row.region }}</span></td>
                <td>{{ row.priority }}</td>
                <td class="text-right space-x-2">
                  <button class="text-brand-600" @click="openRule(row)">{{ t('common.edit') }}</button>
                  <button class="text-red-600" @click="removeRule(row)">{{ t('common.delete') }}</button>
                </td>
              </tr>
            </tbody>
          </table>
          <p v-if="!rules.length" class="empty">{{ t('catalog.tax.rulesEmpty') }}</p>
        </div>
      </section>

      <section v-else class="panel p-4 space-y-4">
        <p class="text-sm text-slate-600">{{ t('catalog.tax.calculatorHint') }}</p>
        <div class="grid gap-3 sm:grid-cols-2">
          <div>
            <FieldLabel icon="coins">{{ t('catalog.tax.amount') }}</FieldLabel>
            <input v-model="calc.amount" class="field" placeholder="0.00" />
          </div>
          <div>
            <FieldLabel icon="percent">{{ t('catalog.tax.group') }}</FieldLabel>
            <select v-model="calc.tax_group_id" class="field">
              <option value="">—</option>
              <option v-for="group in groups.filter(item => item.is_active)" :key="group.id" :value="group.id">{{ group.name }}</option>
            </select>
          </div>
        </div>
        <label class="flex items-center gap-2 text-sm">
          <span class="field-icon"><AppIcon name="check" :size="14" /></span>
          <input v-model="calc.amount_is_inclusive" type="checkbox" />
          {{ t('catalog.tax.amountInclusive') }}
        </label>
        <div class="grid gap-2 sm:grid-cols-2">
          <label v-for="tax in activeTaxes" :key="tax.id" class="flex items-center gap-2 text-sm">
            <input type="checkbox" :checked="calc.tax_ids.includes(tax.id)" @change="toggleCalcTax(tax.id, ($event.target as HTMLInputElement).checked)" />
            {{ tax.name }} ({{ tax.rate }}%)
          </label>
        </div>
        <button type="button" class="btn-primary" :disabled="saving" @click="runCalculator">{{ t('catalog.tax.calculate') }}</button>
        <div v-if="calcResult" class="space-y-2 text-sm">
          <div class="stats">
            <div><span>{{ t('catalog.tax.net') }}</span><strong>{{ formatMoney(calcResult.net) }}</strong></div>
            <div><span>{{ t('catalog.tax.collected') }}</span><strong>{{ formatMoney(calcResult.tax_total) }}</strong></div>
            <div><span>{{ t('catalog.tax.total') }}</span><strong>{{ formatMoney(calcResult.total) }}</strong></div>
          </div>
          <table class="min-w-full">
            <thead class="bg-slate-50">
              <tr>
                <th>{{ t('catalog.tax.name') }}</th>
                <th>{{ t('catalog.tax.taxable') }}</th>
                <th>{{ t('catalog.tax.collected') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="line in calcResult.lines" :key="line.tax_id">
                <td>{{ line.name }} <span class="text-xs text-slate-500">{{ line.rate }}%</span></td>
                <td>{{ formatMoney(line.taxable_amount) }}</td>
                <td>{{ formatMoney(line.tax_amount) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </div>

    <AppModal :open="showTax" :title="editingTax ? t('catalog.editTax') : t('catalog.addTax')" icon="percent" tone="warning" size="lg" @close="showTax = false">
      <form class="space-y-3" @submit.prevent="saveTax">
        <div class="grid gap-3 sm:grid-cols-2">
          <div>
            <FieldLabel icon="account">{{ t('catalog.tax.name') }} *</FieldLabel>
            <input v-model="taxForm.name" required class="field" :placeholder="t('catalog.tax.nameHint')" />
          </div>
          <div>
            <FieldLabel icon="tag">{{ t('catalog.tax.code') }} *</FieldLabel>
            <input v-model="taxForm.code" required class="field" :placeholder="t('catalog.tax.codeHint')" />
          </div>
          <div>
            <FieldLabel icon="percent">{{ t('catalog.tax.rate') }}</FieldLabel>
            <span class="rate-field">
              <input v-model.number="taxForm.rate" type="number" min="0" max="100" step="0.01" required class="field" />
              <span>%</span>
            </span>
          </div>
          <div>
            <FieldLabel icon="catalog">{{ t('catalog.tax.type') }}</FieldLabel>
            <select v-model="taxForm.type" class="field">
              <option value="percentage">{{ t('catalog.tax.percentage') }}</option>
            </select>
          </div>
          <div>
            <FieldLabel icon="layers">{{ t('catalog.tax.priority') }}</FieldLabel>
            <input v-model.number="taxForm.priority" type="number" min="1" class="field" />
          </div>
          <div>
            <FieldLabel icon="store-pin">{{ t('catalog.tax.country') }}</FieldLabel>
            <select v-model="taxForm.country" class="field">
              <option v-for="country in COUNTRIES" :key="country.code || 'all'" :value="country.code">{{ countryLabel(country.code) }}</option>
            </select>
          </div>
          <div class="sm:col-span-2">
            <FieldLabel icon="pin">{{ t('catalog.tax.region') }}</FieldLabel>
            <input v-model="taxForm.region" class="field" :placeholder="t('catalog.tax.regionHint')" />
          </div>
        </div>

        <fieldset class="behavior">
          <legend>{{ t('catalog.tax.behavior') }}</legend>
          <label class="flex items-start gap-2 text-sm">
            <span class="field-icon"><AppIcon name="check" :size="14" /></span>
            <input v-model="taxForm.is_inclusive" type="checkbox" class="mt-1" />
            <span>
              <span class="block font-medium">{{ t('catalog.tax.inclusive') }}</span>
              <span class="text-slate-500">{{ t('catalog.tax.inclusiveHint') }}</span>
            </span>
          </label>
          <label class="flex items-start gap-2 text-sm">
            <span class="field-icon"><AppIcon name="check" :size="14" /></span>
            <input v-model="taxForm.is_compound" type="checkbox" class="mt-1" />
            <span>
              <span class="block font-medium">{{ t('catalog.tax.compound') }}</span>
              <span class="text-slate-500">{{ t('catalog.tax.compoundHint') }}</span>
            </span>
          </label>
        </fieldset>

        <label class="flex items-start gap-2 text-sm">
          <span class="field-icon"><AppIcon name="check" :size="14" /></span>
          <input v-model="taxForm.is_active" type="checkbox" class="mt-1" />
          <span>
            <span class="block font-medium">{{ t('products.active') }}</span>
            <span class="text-slate-500">{{ t('catalog.tax.activeHint') }}</span>
          </span>
        </label>

        <div>
          <FieldLabel icon="note">{{ t('catalog.tax.description') }}</FieldLabel>
          <textarea v-model="taxForm.description" rows="3" class="field" />
        </div>

        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showTax = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>

    <AppModal :open="showGroup" :title="editingGroup ? t('catalog.tax.editGroup') : t('catalog.tax.addGroup')" icon="percent" tone="warning" size="lg" @close="showGroup = false">
      <form class="space-y-3" @submit.prevent="saveGroup">
        <div class="grid gap-3 sm:grid-cols-2">
          <div><FieldLabel icon="account">{{ t('catalog.tax.name') }} *</FieldLabel><input v-model="groupForm.name" required class="field" /></div>
          <div><FieldLabel icon="tag">{{ t('catalog.tax.code') }} *</FieldLabel><input v-model="groupForm.code" required class="field" /></div>
        </div>
        <div><FieldLabel icon="note">{{ t('catalog.tax.description') }}</FieldLabel><textarea v-model="groupForm.description" rows="2" class="field" /></div>
        <div class="space-y-1">
          <p class="text-sm font-medium">{{ t('catalog.tax.members') }}</p>
          <label v-for="tax in store.taxes" :key="tax.id" class="flex items-center gap-2 text-sm">
            <input v-model="groupForm.tax_ids" type="checkbox" :value="tax.id" />
            {{ tax.name }} ({{ tax.code }})
          </label>
        </div>
        <label class="flex items-center gap-2 text-sm"><span class="field-icon"><AppIcon name="check" :size="14" /></span><input v-model="groupForm.is_active" type="checkbox" />{{ t('products.active') }}</label>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showGroup = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>

    <AppModal :open="showClass" :title="editingClass ? t('catalog.tax.editClass') : t('catalog.tax.addClass')" icon="percent" tone="warning" @close="showClass = false">
      <form class="space-y-3" @submit.prevent="saveClass">
        <div><FieldLabel icon="account">{{ t('catalog.tax.name') }} *</FieldLabel><input v-model="classForm.name" required class="field" /></div>
        <div><FieldLabel icon="tag">{{ t('catalog.tax.code') }} *</FieldLabel><input v-model="classForm.code" required class="field" /></div>
        <div><FieldLabel icon="note">{{ t('catalog.tax.description') }}</FieldLabel><textarea v-model="classForm.description" rows="2" class="field" /></div>
        <label class="flex items-center gap-2 text-sm"><span class="field-icon"><AppIcon name="check" :size="14" /></span><input v-model="classForm.is_active" type="checkbox" />{{ t('products.active') }}</label>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showClass = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>

    <AppModal :open="showRule" :title="editingRule ? t('catalog.tax.editRule') : t('catalog.tax.addRule')" icon="percent" tone="warning" size="lg" @close="showRule = false">
      <form class="space-y-3" @submit.prevent="saveRule">
        <div><FieldLabel icon="account">{{ t('catalog.tax.name') }} *</FieldLabel><input v-model="ruleForm.name" required class="field" /></div>
        <div class="grid gap-3 sm:grid-cols-2">
          <div>
            <FieldLabel icon="layers">{{ t('catalog.tax.class') }}</FieldLabel>
            <select v-model="ruleForm.tax_class_id" class="field">
              <option value="">—</option>
              <option v-for="row in classes" :key="row.id" :value="row.id">{{ row.name }}</option>
            </select>
          </div>
          <div>
            <FieldLabel icon="layers">{{ t('catalog.tax.priority') }}</FieldLabel>
            <input v-model.number="ruleForm.priority" type="number" min="1" class="field" />
          </div>
          <div>
            <FieldLabel icon="percent">{{ t('catalog.tabs.taxes') }}</FieldLabel>
            <select v-model="ruleForm.tax_id" class="field">
              <option value="">—</option>
              <option v-for="tax in store.taxes" :key="tax.id" :value="tax.id">{{ tax.name }}</option>
            </select>
          </div>
          <div>
            <FieldLabel icon="percent">{{ t('catalog.tax.group') }}</FieldLabel>
            <select v-model="ruleForm.tax_group_id" class="field">
              <option value="">—</option>
              <option v-for="group in groups" :key="group.id" :value="group.id">{{ group.name }}</option>
            </select>
          </div>
          <div>
            <FieldLabel icon="store-pin">{{ t('catalog.tax.country') }}</FieldLabel>
            <select v-model="ruleForm.country" class="field">
              <option v-for="country in COUNTRIES" :key="country.code || 'all'" :value="country.code">{{ countryLabel(country.code) }}</option>
            </select>
          </div>
          <div>
            <FieldLabel icon="pin">{{ t('catalog.tax.region') }}</FieldLabel>
            <input v-model="ruleForm.region" class="field" :placeholder="t('catalog.tax.regionHint')" />
          </div>
        </div>
        <div><FieldLabel icon="note">{{ t('catalog.tax.description') }}</FieldLabel><textarea v-model="ruleForm.description" rows="2" class="field" /></div>
        <label class="flex items-center gap-2 text-sm"><span class="field-icon"><AppIcon name="check" :size="14" /></span><input v-model="ruleForm.is_active" type="checkbox" />{{ t('products.active') }}</label>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showRule = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>
  </CatalogLayout>
</template>

<style scoped>
.field { width: 100%; border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 0.75rem; }
.btn-primary { border-radius: 0.5rem; padding: 0.5rem 1rem; font-weight: 500; color: white; background-color: var(--color-brand-600); }
.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; }
.text-brand-600 { color: var(--color-brand-600); }
.tax-tabs { display: flex; flex-wrap: wrap; gap: 0.4rem; }
.tax-tab { border-radius: 999px; border: 1px solid #e2e8f0; background: white; padding: 0.4rem 0.85rem; font-size: 0.8125rem; color: #475569; }
.tax-tab--active { background: #4a6d86; color: white; border-color: #4a6d86; }
.panel { overflow: hidden; border-radius: 0.75rem; background: white; box-shadow: 0 1px 2px rgb(15 23 42 / 0.05); }
.panel th, .panel td { padding: 0.75rem 1rem; text-align: left; }
.panel tbody tr { border-top: 1px solid #f1f5f9; }
.empty { padding: 2rem 1rem; text-align: center; color: #64748b; }
.stats { display: grid; gap: 0.75rem; grid-template-columns: repeat(auto-fit, minmax(10rem, 1fr)); }
.stats div { border-radius: 0.75rem; background: white; padding: 0.85rem 1rem; box-shadow: 0 1px 2px rgb(15 23 42 / 0.05); }
.stats span { display: block; font-size: 0.75rem; color: #64748b; }
.rate-field { display: flex; align-items: center; gap: 0.4rem; }
.behavior { display: grid; gap: 0.75rem; border-radius: 0.75rem; border: 1px solid #e2e8f0; padding: 0.85rem; }
.behavior legend { padding: 0 0.25rem; font-size: 0.875rem; font-weight: 600; }
</style>
