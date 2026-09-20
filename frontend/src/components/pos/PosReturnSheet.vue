<script setup lang="ts">
import { computed, ref } from 'vue'
import { watchLiveSearch } from '../../composables/useLiveSearch'
import { useI18n } from 'vue-i18n'
import { api, extractApiErrorMessage } from '../../api/client'
import { formatMoney } from '../../utils/money'

type SaleLine = {
  id: string
  product_name?: string | null
  quantity: number
  quantity_returnable?: number
  line_total: number
}

const props = defineProps<{
  storeId: string
  cashRegisterId?: string | null
}>()

const emit = defineEmits<{
  close: []
  done: [message: string]
}>()

const { t } = useI18n()
const reference = ref('')
const saleId = ref('')
const lines = ref<Array<SaleLine & { returning: number }>>([])
const method = ref('original')
const busy = ref(false)
const error = ref('')

const refundEstimate = computed(() => lines.value.reduce((sum, line) => {
  const qty = Math.min(line.returning, line.quantity_returnable ?? line.quantity)
  if (!line.quantity || qty < 1) return sum
  return sum + Math.round(line.line_total * qty / line.quantity)
}, 0))

const isPartial = computed(() => lines.value.some(line => {
  const max = line.quantity_returnable ?? line.quantity
  return line.returning > 0 && line.returning < max
}))

async function search() {
  error.value = ''
  lines.value = []
  saleId.value = ''
  const code = reference.value.trim()
  if (!code) return
  busy.value = true
  try {
    const list = await api.get<{ data: { id: string; reference: string }[] }>(
      `/stores/${props.storeId}/sales?q=${encodeURIComponent(code)}&status=completed`,
    )
    const match = list.data.find(item => item.reference === code) ?? list.data[0]
    if (!match) {
      error.value = t('pos.saleNotFound')
      return
    }
    const sale = await api.get<{ data: { id: string; items: SaleLine[] } }>(`/sales/${match.id}`)
    saleId.value = sale.data.id
    lines.value = (sale.data.items ?? [])
      .map(item => ({
        ...item,
        quantity_returnable: item.quantity_returnable ?? item.quantity,
        returning: item.quantity_returnable ?? item.quantity,
      }))
      .filter(item => item.quantity_returnable > 0)
    if (!lines.value.length) error.value = t('pos.nothingToReturn')
  } catch (e) {
    error.value = extractApiErrorMessage(e, t('pos.saleNotFound'))
  } finally {
    busy.value = false
  }
}

function returnAll() {
  lines.value = lines.value.map(line => ({ ...line, returning: line.quantity_returnable ?? line.quantity }))
}

async function submit() {
  const items = lines.value
    .filter(line => line.returning > 0)
    .map(line => ({ sale_item_id: line.id, quantity: line.returning }))
  if (!saleId.value || !items.length) return
  busy.value = true
  error.value = ''
  try {
    const created = await api.post<{ data: { sale_return: { return_number: string; total: number; stock_corrected?: boolean } } }>(
      `/sales/${saleId.value}/returns`,
      {
        reason: 'customer_changed_mind',
        refund_method: method.value,
        cash_register_id: props.cashRegisterId || undefined,
        items,
      },
    )
    const row = created.data.sale_return
    emit('done', `${row.return_number} · ${formatMoney(row.total)} · ${t('pos.stockCorrected')}`)
    emit('close')
  } catch (e) {
    error.value = extractApiErrorMessage(e, t('pos.refundRefused'))
  } finally {
    busy.value = false
  }
}
watchLiveSearch(reference, search)
</script>

<template>
  <form class="sheet" @submit.prevent="saleId ? submit() : undefined">
    <div class="sheet__head">
      <strong>{{ t('pos.returnTitle') }}</strong>
      <button type="button" @click="emit('close')">×</button>
    </div>
    <p class="sheet__hint">{{ t('pos.returnHint') }}</p>
    <div class="sheet__search">
      <input v-model="reference" type="search" :placeholder="t('pos.refundSale')" />
    </div>
    <div v-if="lines.length" class="sheet__lines">
      <div v-for="line in lines" :key="line.id" class="sheet__line">
        <span>{{ line.product_name }}</span>
        <input v-model.number="line.returning" type="number" min="0" :max="line.quantity_returnable" />
        <span>/ {{ line.quantity_returnable }}</span>
      </div>
      <p class="sheet__hint">
        {{ isPartial ? t('pos.partialRefund') : t('pos.fullRefund') }}
        · {{ formatMoney(refundEstimate) }}
        · {{ t('pos.stockCorrected') }}
      </p>
      <div class="sheet__search">
        <select v-model="method">
          <option value="original">{{ t('sales.refundOriginal') }}</option>
          <option value="cash">{{ t('sales.methodCash') }}</option>
          <option value="mobile_money">Mobile Money</option>
          <option value="card">{{ t('sales.methodCard') }}</option>
          <option value="bank_transfer">{{ t('sales.methodBankTransfer') }}</option>
          <option value="credit">{{ t('sales.refundStoreCredit') }}</option>
        </select>
        <button type="button" @click="returnAll">{{ t('pos.returnAll') }}</button>
        <button type="submit" :disabled="busy">{{ t('pos.refund') }}</button>
      </div>
    </div>
    <p v-if="error" class="sheet__error">{{ error }}</p>
  </form>
</template>

<style scoped>
.sheet { display: flex; flex-direction: column; gap: 0.55rem; margin: 0.4rem 0.85rem 0; padding: 0.75rem; border-radius: 0.75rem; background: white; border: 1px solid #e2e8f0; }
.sheet__head, .sheet__search, .sheet__line { display: flex; gap: 0.45rem; align-items: center; }
.sheet__head { justify-content: space-between; }
.sheet__hint, .sheet__error { margin: 0; font-size: 0.78rem; color: #64748b; }
.sheet__error { color: #b91c1c; }
.sheet__lines { display: flex; flex-direction: column; gap: 0.35rem; }
.sheet__line span:first-child { flex: 1; min-width: 0; }
input, select, button { border: 1px solid #cbd5e1; border-radius: 0.45rem; padding: 0.4rem 0.55rem; }
.sheet__line input { width: 4.5rem; }
button { background: var(--color-brand-600); color: white; border: 0; font-weight: 650; cursor: pointer; }
</style>
