<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { api, extractApiErrorMessage } from '../../api/client'
import PageFrame from '../../components/layout/PageFrame.vue'
import AppIcon from '../../components/ui/AppIcon.vue'
import AppModal from '../../components/ui/AppModal.vue'
import FieldLabel from '../../components/ui/FieldLabel.vue'
import { useConfirm } from '../../composables/useConfirm'
import { pushToast } from '../../composables/useToast'
import { formatDateTime } from '../../utils/format'
import { formatMoney } from '../../utils/money'

type RecipeLine = {
  product_id: string
  name: string
  unit: string
  quantity: number
  on_hand: number
  unit_cost: number
  batch_cost: number
  max_batches: number | null
}
type Recipe = {
  id: string
  name: string
  sku?: string
  unit: string
  yield_quantity: number
  on_hand: number
  price: number
  batch_cost: number
  unit_cost: number
  max_batches: number
  in_store: boolean
  lines: RecipeLine[]
}
type Run = {
  id: string
  status: 'done' | 'reversed'
  recipe_name: string
  unit?: string
  batches: number
  finished_quantity: number
  total_cost?: number
  unit_cost?: number
  performed_by_name?: string | null
  reversed_by_name?: string | null
  reversed_at?: string
  produced_at?: string
  ingredients: { product_id: string; name: string; unit?: string; quantity: number; cost?: number }[]
}
type ProductOption = {
  id: string
  name: string
  sku?: string
  unit: string
  cost_price: number
  quantity_on_hand: number
  in_store: boolean
  is_recipe: boolean
}
type Snapshot = {
  warehouse?: { id: string; name: string }
  recipes: Recipe[]
  runs: Run[]
  products: ProductOption[]
  stats?: { runs_today: number; units_today: number; cost_today: number }
}

const { t } = useI18n()
const { confirm: confirmDialog, notify } = useConfirm()

const recipes = ref<Recipe[]>([])
const runs = ref<Run[]>([])
const products = ref<ProductOption[]>([])
const stats = ref({ runs_today: 0, units_today: 0, cost_today: 0 })
const warehouseName = ref('')
const batches = ref<Record<string, number>>({})
const search = ref('')
const loading = ref(false)
const loaded = ref(false)
const error = ref('')
const busyId = ref('')
const openRunId = ref('')

const showEditor = ref(false)
const editingId = ref('')
const saving = ref(false)
const formError = ref('')
const form = ref<{ product_id: string; yield_quantity: number; lines: { product_id: string; quantity: number }[] }>({
  product_id: '',
  yield_quantity: 1,
  lines: [{ product_id: '', quantity: 1 }],
})

onMounted(load)

function apply(data: Snapshot) {
  recipes.value = data.recipes ?? []
  runs.value = data.runs ?? []
  products.value = data.products ?? []
  stats.value = data.stats ?? { runs_today: 0, units_today: 0, cost_today: 0 }
  warehouseName.value = data.warehouse?.name ?? ''
  for (const recipe of recipes.value) {
    if (!(batches.value[recipe.id] >= 1)) batches.value[recipe.id] = 1
  }
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    apply((await api.get<{ data: Snapshot }>('/production')).data)
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    loading.value = false
    loaded.value = true
  }
}

async function send(payload: Record<string, unknown>) {
  const data = (await api.post<{ data: Snapshot }>('/production/actions', payload)).data
  apply(data)
}

const filteredRecipes = computed(() => {
  const q = search.value.trim().toLowerCase()
  if (!q) return recipes.value
  return recipes.value.filter(recipe =>
    `${recipe.name} ${recipe.sku ?? ''} ${recipe.lines.map(line => line.name).join(' ')}`.toLowerCase().includes(q),
  )
})

const readyCount = computed(() => recipes.value.filter(recipe => recipe.max_batches > 0).length)

function qty(value: number) {
  return Number.isInteger(value) ? String(value) : value.toLocaleString(undefined, { maximumFractionDigits: 3 })
}

function batchCount(recipe: Recipe) {
  const value = Math.trunc(Number(batches.value[recipe.id]) || 0)
  return Math.min(500, Math.max(0, value))
}

function step(recipe: Recipe, delta: number) {
  batches.value[recipe.id] = Math.min(500, Math.max(1, batchCount(recipe) + delta))
}

function need(line: RecipeLine, count: number) {
  return Math.max(1, Math.round(line.quantity * count))
}

function needs(recipe: Recipe) {
  const count = Math.max(1, batchCount(recipe))
  return recipe.lines.map(line => {
    const required = need(line, count)
    return {
      ...line,
      required,
      enough: line.on_hand >= required,
      coverage: Math.min(100, Math.round((line.on_hand / required) * 100)),
    }
  })
}

function canProduce(recipe: Recipe) {
  const count = batchCount(recipe)
  return count >= 1 && count <= recipe.max_batches
}

function margin(recipe: Recipe) {
  if (!recipe.price || !recipe.unit_cost) return null
  return Math.round(((recipe.price - recipe.unit_cost) / recipe.price) * 100)
}

async function produce(recipe: Recipe) {
  const count = batchCount(recipe)
  if (!canProduce(recipe) || busyId.value) return
  const finished = count * recipe.yield_quantity
  const ok = await confirmDialog(
    t('desk.prod.confirmMessage', { qty: finished, unit: recipe.unit, name: recipe.name }),
    {
      title: t('desk.prod.confirmTitle'),
      confirmLabel: t('desk.produce'),
      items: needs(recipe).map(line => ({ name: line.name, detail: t('desk.prod.consumed'), quantity: `−${line.required} ${line.unit}` })),
    },
  )
  if (!ok) return
  busyId.value = recipe.id
  try {
    await send({ action: 'produce', recipe_id: recipe.id, batches: count })
    batches.value[recipe.id] = 1
    pushToast({ tone: 'success', message: t('desk.prod.produced', { qty: finished, unit: recipe.unit, name: recipe.name }) })
  } catch (err) {
    notify(extractApiErrorMessage(err))
  } finally {
    busyId.value = ''
  }
}

async function reverse(run: Run) {
  const ok = await confirmDialog(
    t('desk.prod.reverseMessage', { qty: run.finished_quantity, unit: run.unit ?? '', name: run.recipe_name }),
    { title: t('desk.prod.reverseTitle'), confirmLabel: t('desk.prod.reverseTitle'), cancelLabel: t('desk.prod.keep'), danger: true },
  )
  if (!ok) return
  busyId.value = run.id
  try {
    await send({ action: 'reverse_run', run_id: run.id })
    pushToast({ tone: 'success', message: t('desk.prod.reversed') })
  } catch (err) {
    notify(extractApiErrorMessage(err))
  } finally {
    busyId.value = ''
  }
}

async function removeRecipe(recipe: Recipe) {
  const ok = await confirmDialog(t('desk.prod.deleteMessage', { name: recipe.name }), {
    title: t('desk.prod.deleteTitle'),
    confirmLabel: t('common.delete'),
    danger: true,
  })
  if (!ok) return
  busyId.value = recipe.id
  try {
    await send({ action: 'delete_recipe', recipe_id: recipe.id })
    pushToast({ tone: 'success', message: t('desk.prod.deleted') })
  } catch (err) {
    notify(extractApiErrorMessage(err))
  } finally {
    busyId.value = ''
  }
}

function openCreate() {
  editingId.value = ''
  formError.value = ''
  form.value = { product_id: '', yield_quantity: 1, lines: [{ product_id: '', quantity: 1 }] }
  showEditor.value = true
}

function openEdit(recipe: Recipe) {
  editingId.value = recipe.id
  formError.value = ''
  form.value = {
    product_id: recipe.id,
    yield_quantity: recipe.yield_quantity,
    lines: recipe.lines.map(line => ({ product_id: line.product_id, quantity: line.quantity })),
  }
  showEditor.value = true
}

const productById = computed(() => new Map(products.value.map(product => [product.id, product])))

const finishedOptions = computed(() =>
  products.value.filter(product => !product.is_recipe || product.id === editingId.value),
)

function ingredientOptions(index: number) {
  const used = new Set(form.value.lines.filter((_, i) => i !== index).map(line => line.product_id))
  return products.value.filter(product => product.id !== form.value.product_id && !used.has(product.id))
}

function addLine() {
  form.value.lines.push({ product_id: '', quantity: 1 })
}

function removeLine(index: number) {
  form.value.lines.splice(index, 1)
  if (!form.value.lines.length) addLine()
}

const draftCost = computed(() =>
  form.value.lines.reduce((sum, line) => {
    const product = productById.value.get(line.product_id)
    return sum + (product ? product.cost_price * (Number(line.quantity) || 0) : 0)
  }, 0),
)

const draftUnitCost = computed(() => Math.round(draftCost.value / Math.max(1, Math.trunc(form.value.yield_quantity) || 1)))

async function saveRecipe() {
  formError.value = ''
  const lines = form.value.lines
    .filter(line => line.product_id && Number(line.quantity) > 0)
    .map(line => ({ product_id: line.product_id, quantity: Number(line.quantity) }))
  if (!form.value.product_id) {
    formError.value = t('desk.prod.needFinished')
    return
  }
  if (!lines.length) {
    formError.value = t('desk.prod.needLines')
    return
  }
  saving.value = true
  try {
    await send({
      action: 'save_recipe',
      product_id: form.value.product_id,
      yield_quantity: Math.max(1, Math.trunc(form.value.yield_quantity) || 1),
      lines,
    })
    showEditor.value = false
    pushToast({ tone: 'success', message: t('desk.prod.saved') })
  } catch (err) {
    formError.value = extractApiErrorMessage(err)
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <PageFrame>
    <template #title>{{ t('desk.production') }}</template>
    <template #subtitle>{{ t('desk.productionHint') }}</template>

    <div class="prod">
      <div class="prod-toolbar">
        <div class="prod-search">
          <AppIcon name="search" :size="16" />
          <input v-model="search" type="search" :placeholder="t('desk.prod.search')" :aria-label="t('desk.prod.search')" />
        </div>
        <span v-if="warehouseName" class="prod-store"><AppIcon name="inventory" :size="15" /> {{ warehouseName }}</span>
        <div class="prod-toolbar__actions">
          <button type="button" class="btn-secondary" :class="{ 'is-busy': loading }" :disabled="loading" @click="load">
            <AppIcon name="refresh" :size="16" /> {{ t('desk.prod.refresh') }}
          </button>
          <button type="button" class="btn-primary" @click="openCreate">
            <AppIcon name="plus" :size="16" /> {{ t('desk.prod.newRecipe') }}
          </button>
        </div>
      </div>

      <p v-if="error" class="prod-error">{{ error }}</p>

      <div class="prod-kpis">
        <div class="prod-kpi">
          <span class="prod-kpi__icon"><AppIcon name="layers" :size="18" /></span>
          <div><strong>{{ recipes.length }}</strong><small>{{ t('desk.prod.kpiRecipes') }}</small></div>
        </div>
        <div class="prod-kpi">
          <span class="prod-kpi__icon prod-kpi__icon--ok"><AppIcon name="check" :size="18" /></span>
          <div><strong>{{ readyCount }}</strong><small>{{ t('desk.prod.kpiReady') }}</small></div>
        </div>
        <div class="prod-kpi">
          <span class="prod-kpi__icon prod-kpi__icon--accent"><AppIcon name="package" :size="18" /></span>
          <div><strong>{{ stats.units_today }}</strong><small>{{ t('desk.prod.kpiUnits', { runs: stats.runs_today }) }}</small></div>
        </div>
        <div class="prod-kpi">
          <span class="prod-kpi__icon prod-kpi__icon--info"><AppIcon name="coins" :size="18" /></span>
          <div><strong>{{ formatMoney(stats.cost_today) }}</strong><small>{{ t('desk.prod.kpiCost') }}</small></div>
        </div>
      </div>

      <div v-if="loaded && !recipes.length" class="prod-empty">
        <span class="prod-empty__icon"><AppIcon name="layers" :size="28" /></span>
        <h3>{{ t('desk.prod.emptyTitle') }}</h3>
        <p>{{ t('desk.noRecipes') }}</p>
        <button type="button" class="btn-primary" @click="openCreate"><AppIcon name="plus" :size="16" /> {{ t('desk.prod.newRecipe') }}</button>
      </div>
      <p v-else-if="loaded && !filteredRecipes.length" class="prod-empty prod-empty--small">{{ t('desk.prod.noMatch') }}</p>

      <div class="prod-grid">
        <article
          v-for="recipe in filteredRecipes"
          :key="recipe.id"
          class="prod-card"
          :class="{ 'prod-card--blocked': recipe.max_batches < 1 }"
        >
          <header class="prod-card__head">
            <div class="prod-card__title">
              <h3>{{ recipe.name }}</h3>
              <p>
                <span v-if="recipe.sku" class="prod-sku">{{ recipe.sku }}</span>
                {{ t('desk.prod.yieldLine', { qty: recipe.yield_quantity, unit: recipe.unit }) }}
              </p>
            </div>
            <div class="prod-card__stock">
              <strong :class="{ 'is-negative': recipe.on_hand < 0 }">{{ recipe.on_hand }}</strong>
              <small>{{ recipe.unit }} {{ t('desk.prod.inStock') }}</small>
            </div>
          </header>

          <div class="prod-card__status">
            <span v-if="recipe.max_batches > 0" class="prod-pill prod-pill--ok">
              <AppIcon name="check" :size="13" /> {{ t('desk.prod.capacity', { count: recipe.max_batches, qty: recipe.max_batches * recipe.yield_quantity, unit: recipe.unit }) }}
            </span>
            <span v-else class="prod-pill prod-pill--danger"><AppIcon name="alert" :size="13" /> {{ t('desk.prod.missing') }}</span>
            <span v-if="!recipe.in_store" class="prod-pill prod-pill--warn">{{ t('desk.prod.notInStore') }}</span>
          </div>

          <table class="prod-lines">
            <thead>
              <tr>
                <th>{{ t('desk.prod.ingredient') }}</th>
                <th class="num">{{ t('desk.prod.needed') }}</th>
                <th class="num">{{ t('desk.onHand') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="line in needs(recipe)" :key="line.product_id" :class="{ 'is-short': !line.enough }">
                <td>
                  <span class="prod-lines__name">{{ line.name }}</span>
                  <span class="prod-bar"><span :style="{ width: `${line.coverage}%` }" /></span>
                </td>
                <td class="num">{{ line.required }} <small>{{ line.unit }}</small></td>
                <td class="num">{{ line.on_hand }} <small>{{ line.unit }}</small></td>
              </tr>
            </tbody>
          </table>

          <dl class="prod-costs">
            <div><dt>{{ t('desk.prod.batchCost') }}</dt><dd>{{ formatMoney(recipe.batch_cost) }}</dd></div>
            <div><dt>{{ t('desk.prod.unitCost') }}</dt><dd>{{ formatMoney(recipe.unit_cost) }}</dd></div>
            <div v-if="recipe.price"><dt>{{ t('desk.prod.price') }}</dt><dd>{{ formatMoney(recipe.price) }}<small v-if="margin(recipe) != null" :class="{ 'is-negative': (margin(recipe) ?? 0) < 0 }"> · {{ margin(recipe) }}%</small></dd></div>
          </dl>

          <footer class="prod-card__foot">
            <div class="prod-stepper" :aria-label="t('desk.batches')">
              <button type="button" :disabled="batchCount(recipe) <= 1" @click="step(recipe, -1)">−</button>
              <input v-model.number="batches[recipe.id]" type="number" min="1" max="500" inputmode="numeric" />
              <button type="button" :disabled="batchCount(recipe) >= 500" @click="step(recipe, 1)">+</button>
            </div>
            <span class="prod-result">
              {{ t('desk.prod.batchesShort', { count: batchCount(recipe) }) }} → <strong>{{ batchCount(recipe) * recipe.yield_quantity }} {{ recipe.unit }}</strong>
            </span>
            <button
              type="button"
              class="btn-primary prod-go"
              :class="{ 'is-busy': busyId === recipe.id }"
              :disabled="!canProduce(recipe) || !!busyId"
              :title="canProduce(recipe) ? '' : t('desk.prod.cannot')"
              @click="produce(recipe)"
            >
              <AppIcon name="check" :size="16" /> {{ t('desk.produce') }}
            </button>
          </footer>
          <div class="row-actions prod-card__tools">
            <button type="button" class="row-action row-action--edit" @click="openEdit(recipe)"><AppIcon name="edit" :size="15" /> {{ t('common.edit') }}</button>
            <button type="button" class="row-action row-action--danger" :disabled="!!busyId" @click="removeRecipe(recipe)"><AppIcon name="trash" :size="15" /> {{ t('common.delete') }}</button>
          </div>
        </article>
      </div>

      <section class="prod-history">
        <header>
          <h3><AppIcon name="clock" :size="17" /> {{ t('desk.runs') }}</h3>
          <small>{{ t('desk.prod.historyHint') }}</small>
        </header>
        <p v-if="!runs.length" class="prod-empty prod-empty--small">{{ t('desk.prod.noRuns') }}</p>
        <div v-else class="prod-history__scroll">
          <table class="min-w-full text-sm">
            <thead>
              <tr>
                <th>{{ t('desk.recipe') }}</th>
                <th class="num">{{ t('desk.finished') }}</th>
                <th class="num">{{ t('desk.prod.cost') }}</th>
                <th>{{ t('desk.prod.by') }}</th>
                <th>{{ t('desk.when') }}</th>
                <th>{{ t('desk.prod.status') }}</th>
                <th class="text-right">{{ t('common.actions') }}</th>
              </tr>
            </thead>
            <tbody>
              <template v-for="run in runs" :key="run.id">
                <tr :class="{ 'is-reversed': run.status === 'reversed' }">
                  <td class="font-medium">{{ run.recipe_name }}</td>
                  <td class="num">
                    {{ run.finished_quantity }} {{ run.unit ?? '' }}
                    <small class="muted">· {{ t('desk.prod.batchesShort', { count: run.batches }) }}</small>
                  </td>
                  <td class="num">{{ run.total_cost != null ? formatMoney(run.total_cost) : '—' }}</td>
                  <td>{{ run.performed_by_name || '—' }}</td>
                  <td class="whitespace-nowrap">{{ formatDateTime(run.produced_at) }}</td>
                  <td>
                    <span v-if="run.status === 'reversed'" class="prod-pill prod-pill--muted">{{ t('desk.prod.statusReversed') }}</span>
                    <span v-else class="prod-pill prod-pill--ok">{{ t('desk.prod.statusDone') }}</span>
                  </td>
                  <td>
                    <div class="row-actions">
                      <button type="button" class="row-action row-action--view" @click="openRunId = openRunId === run.id ? '' : run.id">
                        <AppIcon name="eye" :size="15" /> {{ t('inventory.viewDetails') }}
                      </button>
                      <button
                        v-if="run.status !== 'reversed'"
                        type="button"
                        class="row-action row-action--danger"
                        :disabled="!!busyId"
                        @click="reverse(run)"
                      >
                        <AppIcon name="close" :size="15" /> {{ t('desk.prod.reverse') }}
                      </button>
                    </div>
                  </td>
                </tr>
                <tr v-if="openRunId === run.id" class="prod-history__detail">
                  <td colspan="7">
                    <div class="prod-detail">
                      <span v-for="line in run.ingredients" :key="line.product_id" class="prod-chip">
                        −{{ line.quantity }} {{ line.unit ?? '' }} {{ line.name }}
                        <small v-if="line.cost">{{ formatMoney(line.cost) }}</small>
                      </span>
                      <span class="prod-chip prod-chip--in">+{{ run.finished_quantity }} {{ run.unit ?? '' }} {{ run.recipe_name }}</span>
                      <span v-if="run.status === 'reversed'" class="muted">
                        {{ t('desk.prod.reversedBy', { name: run.reversed_by_name || '—', at: formatDateTime(run.reversed_at) }) }}
                      </span>
                    </div>
                  </td>
                </tr>
              </template>
            </tbody>
          </table>
        </div>
      </section>
    </div>

    <AppModal
      :open="showEditor"
      :title="editingId ? t('desk.prod.editRecipe') : t('desk.prod.newRecipe')"
      :subtitle="t('desk.prod.editorHint')"
      icon="layers"
      tone="brand"
      size="lg"
      @close="showEditor = false"
    >
      <form class="prod-form" @submit.prevent="saveRecipe">
        <div class="prod-form-head">
          <div>
            <FieldLabel icon="products">{{ t('desk.finished') }}</FieldLabel>
            <select v-model="form.product_id" class="field" :disabled="!!editingId" required>
              <option value="">—</option>
              <option v-for="product in finishedOptions" :key="product.id" :value="product.id">
                {{ product.name }}{{ product.sku ? ` · ${product.sku}` : '' }}
              </option>
            </select>
          </div>
          <div>
            <FieldLabel icon="package">{{ t('desk.prod.yield') }}</FieldLabel>
            <div class="prod-unit-field">
              <input v-model.number="form.yield_quantity" type="number" min="1" step="1" class="field" required />
              <span>{{ productById.get(form.product_id)?.unit ?? '' }}</span>
            </div>
          </div>
        </div>
        <p class="text-xs text-slate-500">{{ t('desk.prod.yieldHint') }}</p>

        <div class="prod-form-lines">
          <div class="prod-form-row prod-form-row--head">
            <span>{{ t('desk.prod.ingredient') }}</span>
            <span>{{ t('desk.prod.perBatch') }}</span>
            <span>{{ t('desk.onHand') }}</span>
            <span></span>
          </div>
          <div v-for="(line, index) in form.lines" :key="index" class="prod-form-row">
            <select v-model="line.product_id" class="field" required>
              <option value="">—</option>
              <option v-for="product in ingredientOptions(index)" :key="product.id" :value="product.id">{{ product.name }}</option>
            </select>
            <div class="prod-unit-field">
              <input v-model.number="line.quantity" type="number" min="0.001" step="any" class="field" required />
              <span>{{ productById.get(line.product_id)?.unit ?? '' }}</span>
            </div>
            <span class="prod-form-row__stock">{{ productById.get(line.product_id)?.quantity_on_hand ?? '—' }}</span>
            <button type="button" class="row-action row-action--danger" :title="t('inventory.removeLine')" @click="removeLine(index)">
              <AppIcon name="trash" :size="15" />
            </button>
          </div>
          <button type="button" class="row-action row-action--edit" @click="addLine"><AppIcon name="plus" :size="15" /> {{ t('desk.prod.addIngredient') }}</button>
        </div>

        <dl class="prod-costs prod-costs--form">
          <div><dt>{{ t('desk.prod.batchCost') }}</dt><dd>{{ formatMoney(draftCost) }}</dd></div>
          <div><dt>{{ t('desk.prod.unitCost') }}</dt><dd>{{ formatMoney(draftUnitCost) }}</dd></div>
        </dl>

        <p v-if="formError" class="text-sm text-red-600">{{ formError }}</p>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showEditor = false"><AppIcon name="close" :size="16" /> {{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :class="{ 'is-busy': saving }" :disabled="saving">
            <AppIcon name="check" :size="16" /> {{ editingId ? t('common.saveChanges') : t('desk.prod.createRecipe') }}
          </button>
        </div>
      </form>
    </AppModal>
  </PageFrame>
</template>

<style scoped>
.prod {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}
.prod-toolbar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.75rem;
}
.prod-search {
  position: relative;
  flex: 1 1 18rem;
  max-width: 26rem;
}
.prod-search > svg {
  position: absolute;
  top: 50%;
  left: 0.8rem;
  z-index: 1;
  transform: translateY(-50%);
  color: var(--color-text-muted, #64748b);
  pointer-events: none;
}
.prod-search input {
  padding-left: 2.4rem !important;
}
.prod-store {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  padding: 0.3rem 0.7rem;
  border-radius: 999px;
  background: var(--color-brand-50);
  color: var(--color-ink-brand, var(--color-brand-600));
  font-size: 0.8rem;
  font-weight: 600;
}
.prod-toolbar__actions {
  display: flex;
  gap: 0.5rem;
  margin-left: auto;
}
.prod-error {
  margin: 0;
  padding: 0.75rem 1rem;
  border-radius: var(--radius-lg);
  background: var(--color-danger-bg);
  color: var(--color-danger);
  font-size: 0.875rem;
}

.prod-kpis {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(12rem, 1fr));
  gap: 0.75rem;
}
.prod-kpi {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.85rem 1rem;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-xl);
  background: var(--color-surface);
  box-shadow: var(--shadow-xs);
}
.prod-kpi strong {
  display: block;
  font-family: var(--font-display);
  font-size: 1.25rem;
  line-height: 1.2;
  color: var(--color-text-primary, var(--color-brand-600));
  font-variant-numeric: tabular-nums;
}
.prod-kpi small {
  color: var(--color-text-muted, #64748b);
  font-size: 0.75rem;
}
.prod-kpi__icon {
  display: grid;
  place-items: center;
  width: 2.4rem;
  height: 2.4rem;
  flex: none;
  border-radius: var(--radius-lg);
  background: var(--color-brand-50);
  color: var(--color-ink-brand, var(--color-brand-600));
}
.prod-kpi__icon--ok { background: var(--color-success-bg); color: var(--color-success); }
.prod-kpi__icon--accent { background: var(--color-accent-soft); color: var(--color-accent); }
.prod-kpi__icon--info { background: var(--color-info-bg); color: var(--color-info); }

.prod-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.5rem;
  margin: 0;
  padding: 2.5rem 1rem;
  border: 1px dashed var(--color-border-strong);
  border-radius: var(--radius-xl);
  background: var(--color-surface);
  text-align: center;
  color: var(--color-text-muted, #64748b);
}
.prod-empty h3 { margin: 0; color: var(--color-text-primary, var(--color-brand-600)); }
.prod-empty p { margin: 0 0 0.5rem; max-width: 32rem; font-size: 0.875rem; }
.prod-empty--small { padding: 1.25rem 1rem; font-size: 0.875rem; }
.prod-empty__icon {
  display: grid;
  place-items: center;
  width: 3.5rem;
  height: 3.5rem;
  border-radius: 999px;
  background: var(--color-accent-soft);
  color: var(--color-accent);
}

.prod-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(min(100%, 23rem), 1fr));
  gap: 1rem;
}
.prod-card {
  display: flex;
  flex-direction: column;
  gap: 0.85rem;
  padding: 1rem 1.1rem;
  border: 1px solid var(--color-border);
  border-top: 3px solid var(--color-success);
  border-radius: var(--radius-xl);
  background: var(--color-surface);
  box-shadow: var(--shadow-sm);
  transition: box-shadow 0.15s ease, transform 0.15s ease;
}
.prod-card:hover { box-shadow: var(--shadow-md); }
.prod-card--blocked { border-top-color: var(--color-danger); }
.prod-card__head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 0.75rem;
}
.prod-card__title h3 {
  margin: 0;
  font-family: var(--font-display);
  font-size: 1.05rem;
  color: var(--color-text-primary, var(--color-brand-600));
}
.prod-card__title p {
  margin: 0.15rem 0 0;
  font-size: 0.78rem;
  color: var(--color-text-muted, #64748b);
}
.prod-sku {
  margin-right: 0.35rem;
  padding: 0.05rem 0.4rem;
  border-radius: var(--radius-sm);
  background: var(--color-canvas);
  font-family: var(--font-mono);
  font-size: 0.7rem;
}
.prod-card__stock {
  flex: none;
  min-width: 5rem;
  padding: 0.35rem 0.65rem;
  border-radius: var(--radius-lg);
  background: var(--color-brand-50);
  text-align: right;
}
.prod-card__stock strong {
  display: block;
  font-size: 1.15rem;
  line-height: 1.1;
  color: var(--color-ink-brand, var(--color-brand-600));
  font-variant-numeric: tabular-nums;
}
.prod-card__stock small { font-size: 0.7rem; color: var(--color-text-muted, #64748b); }
.is-negative { color: var(--color-danger) !important; }

.prod-card__status { display: flex; flex-wrap: wrap; gap: 0.4rem; }
.prod-pill {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  padding: 0.2rem 0.6rem;
  border-radius: 999px;
  font-size: 0.75rem;
  font-weight: 600;
  white-space: nowrap;
}
.prod-pill--ok { background: var(--color-success-bg); color: var(--color-success); }
.prod-pill--danger { background: var(--color-danger-bg); color: var(--color-danger); }
.prod-pill--warn { background: var(--color-warning-bg); color: var(--color-warning); }
.prod-pill--muted { background: var(--color-canvas); color: var(--color-text-muted, #64748b); }

.prod-lines {
  width: 100%;
  border: 0;
  border-collapse: collapse;
  font-size: 0.83rem;
}
.prod .prod-lines > * > tr > :is(th, td),
.prod .prod-history table > * > tr > :is(th, td) {
  border-left: 0 !important;
  border-right: 0 !important;
}
.prod .prod-lines > thead > tr > th {
  position: static;
  height: auto;
  padding: 0 0 0.35rem;
  background: transparent;
  font-size: 0.68rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  text-align: left;
  color: var(--color-text-muted, #64748b);
}
.prod .prod-lines > tbody > tr > td {
  height: auto;
  padding: 0.45rem 0;
  border-top: 1px solid var(--color-border);
  border-bottom: 0;
  font-size: 0.83rem;
  font-weight: 500;
  color: var(--color-text-primary, inherit);
  vertical-align: middle;
}
.prod .prod-lines > tbody > tr:hover > td { background: transparent; }
.prod-lines .num,
.prod-history .num {
  text-align: right;
  white-space: nowrap;
  font-variant-numeric: tabular-nums;
}
.prod .prod-lines > * > tr > .num { padding-left: 0.75rem; text-align: right; }
.prod .prod-history table > * > tr > .num { text-align: right; }
.prod-lines small { color: var(--color-text-muted, #64748b); }
.prod-lines__name { display: block; }
.prod-bar {
  display: block;
  height: 4px;
  margin-top: 0.3rem;
  max-width: 9rem;
  border-radius: 999px;
  background: var(--color-canvas);
  overflow: hidden;
}
.prod-bar span {
  display: block;
  height: 100%;
  border-radius: inherit;
  background: var(--color-success);
}
.prod .prod-lines > tbody > tr.is-short > td { color: var(--color-danger); }
.prod-lines tr.is-short .prod-bar span { background: var(--color-danger); }

.prod-costs {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem 1.25rem;
  margin: 0;
  padding: 0.6rem 0.75rem;
  border-radius: var(--radius-lg);
  background: var(--color-canvas);
}
.prod-costs dt { font-size: 0.7rem; color: var(--color-text-muted, #64748b); }
.prod-costs dd {
  margin: 0;
  font-weight: 600;
  font-size: 0.875rem;
  color: var(--color-text-primary, var(--color-brand-600));
  font-variant-numeric: tabular-nums;
}
.prod-costs dd small { font-weight: 600; color: var(--color-success); }

.prod-card__foot {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.6rem;
  margin-top: auto;
}
.prod-stepper {
  display: inline-flex;
  align-items: stretch;
  height: 2.4rem;
  border: 1px solid var(--color-border-strong);
  border-radius: var(--radius-lg);
  overflow: hidden;
  background: var(--color-surface);
}
.prod-stepper button {
  width: 2.2rem;
  border: 0;
  background: var(--color-canvas);
  color: var(--color-text-primary, var(--color-brand-600));
  font-size: 1.1rem;
  font-weight: 600;
  cursor: pointer;
}
.prod-stepper button:hover:not(:disabled) { background: var(--color-brand-50); }
.prod-stepper button:disabled { opacity: 0.4; cursor: not-allowed; }
.prod-stepper input {
  width: 3.2rem !important;
  min-height: 0 !important;
  height: 100% !important;
  padding: 0 !important;
  border: 0 !important;
  border-radius: 0 !important;
  box-shadow: none !important;
  outline: 0;
  text-align: center;
  background: transparent !important;
  color: var(--color-text-primary, inherit);
  font-weight: 600;
  font-variant-numeric: tabular-nums;
  -moz-appearance: textfield;
}
.prod-stepper input::-webkit-outer-spin-button,
.prod-stepper input::-webkit-inner-spin-button { -webkit-appearance: none; margin: 0; }
.prod-result {
  font-size: 0.8rem;
  color: var(--color-text-muted, #64748b);
  white-space: nowrap;
}
.prod-result strong { color: var(--color-text-primary, var(--color-brand-600)); }
.prod-go { margin-left: auto; }
.prod-card__tools {
  justify-content: flex-end;
  padding-top: 0.6rem;
  border-top: 1px dashed var(--color-border);
}

.prod-history {
  border: 1px solid var(--color-border);
  border-radius: var(--radius-xl);
  background: var(--color-surface);
  box-shadow: var(--shadow-xs);
  overflow: hidden;
}
.prod-history > header {
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  justify-content: space-between;
  gap: 0.5rem;
  padding: 0.9rem 1rem 0.6rem;
}
.prod-history h3 {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  margin: 0;
  font-size: 1rem;
  color: var(--color-text-primary, var(--color-brand-600));
}
.prod-history > header small { color: var(--color-text-muted, #64748b); }
.prod-history .prod-empty { border: 0; border-top: 1px solid var(--color-border); border-radius: 0; }
.prod-history__scroll { overflow-x: auto; }
.prod .prod-history table > thead > tr > th {
  position: static;
  height: auto;
  padding: 0.6rem 0.75rem;
  background: var(--color-table-header, var(--color-canvas));
  font-size: 0.75rem;
  font-weight: 600;
  text-align: left;
  color: var(--color-text-muted, #64748b);
}
.prod .prod-history table > tbody > tr > td {
  height: auto;
  padding: 0.6rem 0.75rem;
  font-size: 0.85rem;
  border-top: 1px solid var(--color-border);
  border-bottom: 0;
}
.prod-history tr.is-reversed td:not(:last-child) { opacity: 0.6; }
.prod-history tr.is-reversed td:first-child { text-decoration: line-through; }
.prod .prod-history table > tbody > tr.prod-history__detail > td { background: var(--color-canvas); }
.prod-detail { display: flex; flex-wrap: wrap; align-items: center; gap: 0.4rem; }
.prod-chip {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  padding: 0.2rem 0.6rem;
  border-radius: 999px;
  background: var(--color-danger-bg);
  color: var(--color-danger);
  font-size: 0.75rem;
  font-weight: 600;
}
.prod-chip small { font-weight: 500; opacity: 0.85; }
.prod-chip--in { background: var(--color-success-bg); color: var(--color-success); }
.muted { color: var(--color-text-muted, #64748b); font-size: 0.75rem; }

.prod-form {
  display: flex !important;
  flex-direction: column;
  gap: 1rem;
}
.prod-form > p { margin: -0.5rem 0 0; }
.prod-form-lines {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}
.prod-form-lines > .row-action { align-self: flex-start; }
.prod-form-head {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 10rem;
  gap: 0.75rem;
}
.prod-unit-field {
  display: flex;
  align-items: center;
  gap: 0.4rem;
}
.prod-unit-field .field { min-width: 0; text-align: center; font-variant-numeric: tabular-nums; }
.prod-unit-field span { min-width: 1.5rem; font-size: 0.75rem; color: var(--color-text-muted, #64748b); }
.prod-form-row {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 8.5rem 4.5rem auto;
  gap: 0.5rem;
  align-items: center;
}
.prod-form-row--head {
  font-size: 0.75rem;
  font-weight: 600;
  color: var(--color-text-muted, #64748b);
}
.prod-form-row--head span:nth-child(n + 2),
.prod-form-row__stock {
  text-align: center;
  font-variant-numeric: tabular-nums;
}
.prod-form-row__stock { font-size: 0.85rem; color: var(--color-text-muted, #64748b); }
.prod-costs--form { justify-content: flex-end; }

:global(html[data-theme="dark"] .prod .prod-lines > tbody > tr.is-short > td),
:global(html[data-theme="dark"] .prod .prod-pill--danger),
:global(html[data-theme="dark"] .prod .prod-chip:not(.prod-chip--in)),
:global(html[data-theme="dark"] .prod .is-negative) {
  color: #f6c2be !important;
}
:global(html[data-theme="dark"] .prod .prod-pill--ok),
:global(html[data-theme="dark"] .prod .prod-chip--in) {
  color: #9fe3c1;
}

@media (max-width: 640px) {
  .prod-toolbar__actions { margin-left: 0; width: 100%; }
  .prod-toolbar__actions > * { flex: 1; }
  .prod-form-head { grid-template-columns: 1fr; }
  .prod-form-row { grid-template-columns: minmax(0, 1fr) 7rem auto; }
  .prod-form-row__stock,
  .prod-form-row--head span:nth-child(3) { display: none; }
  .prod-go { margin-left: 0; width: 100%; }
}
</style>
