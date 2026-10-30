<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import AppModal from '../ui/AppModal.vue'
import { formatMoney, parseMoneyInput } from '../../utils/money'
import type { PosCartLine } from '../../types/pos'

const props = defineProps<{
  line: PosCartLine | null
  currency?: string
  maxQuantity: number | null
  error?: string
}>()

const emit = defineEmits<{
  close: []
  save: [payload: { quantity: number; unitPrice: number }]
}>()

const { t } = useI18n()
const qtyText = ref('1')
const priceText = ref('0')
const localError = ref('')

const shownError = computed(() => localError.value || props.error || '')
const previewQty = computed(() => {
  const parsed = Math.trunc(Number(qtyText.value))
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 0
})
const previewPrice = computed(() => parseMoneyInput(priceText.value))
const previewTotal = computed(() => previewQty.value * previewPrice.value)
const atMax = computed(() => props.maxQuantity != null && previewQty.value >= props.maxQuantity)
const dirty = computed(() => {
  const line = props.line
  if (!line) return false
  const price = line.unitPrice ?? line.product.price
  return previewQty.value !== line.quantity || previewPrice.value !== price
})

function majorAmount(minor: number) {
  const major = (Number(minor) || 0) / 100
  return Number.isInteger(major) ? String(major) : major.toFixed(2)
}

watch(
  () => props.line,
  (line) => {
    if (!line) return
    qtyText.value = String(line.quantity)
    priceText.value = majorAmount(line.unitPrice ?? line.product.price)
    localError.value = ''
  },
  { immediate: true },
)

function clampQty(next: number) {
  if (props.maxQuantity != null && next > props.maxQuantity) {
    localError.value = t('pos.quantityMax', { max: props.maxQuantity })
    return props.maxQuantity
  }
  localError.value = ''
  return next
}

function onQtyInput(event: Event) {
  const input = event.target as HTMLInputElement
  const raw = input.value.replace(/\D/g, '')
  if (!raw) {
    qtyText.value = ''
    localError.value = ''
    return
  }
  const next = String(clampQty(Number(raw)))
  qtyText.value = next
  input.value = next
}

function bump(delta: number) {
  const current = Math.max(1, Math.trunc(Number(qtyText.value) || 1))
  const next = clampQty(current + delta)
  if (next < 1) return
  qtyText.value = String(next)
}

function save() {
  const qty = Math.trunc(Number(qtyText.value))
  if (!Number.isFinite(qty) || qty < 1) {
    localError.value = t('pos.quantityMin')
    return
  }
  if (props.maxQuantity != null && qty > props.maxQuantity) {
    localError.value = t('pos.quantityMax', { max: props.maxQuantity })
    qtyText.value = String(props.maxQuantity)
    return
  }
  const price = parseMoneyInput(priceText.value)
  if (price < 0) {
    localError.value = t('pos.priceInvalid')
    return
  }
  localError.value = ''
  emit('save', { quantity: qty, unitPrice: price })
}
</script>

<template>
  <AppModal
    :open="line != null"
    :title="t('pos.editLine')"
    :subtitle="t('pos.editLineHint')"
    size="sm"
    presentation="dialog"
    icon="edit"
    tone="accent"
    :dirty="dirty"
    @close="emit('close')"
  >
    <div v-if="line" class="edit-line">
      <div class="edit-line__summary">
        <p class="edit-line__name">{{ line.product.name }}</p>
        <p v-if="line.product.unit" class="edit-line__unit">{{ line.product.unit }}</p>
        <p class="edit-line__total">
          <span>{{ previewQty || line.quantity }} × {{ formatMoney(previewPrice, currency) }}</span>
          <strong>{{ formatMoney(previewTotal, currency) }}</strong>
        </p>
      </div>

      <label class="edit-line__field">
        <span>{{ t('pos.quantityTitle') }}</span>
        <div class="edit-line__qty">
          <button type="button" :disabled="previewQty <= 1" @click="bump(-1)">−</button>
          <input
            :value="qtyText"
            inputmode="numeric"
            autocomplete="off"
            :max="maxQuantity ?? undefined"
            @input="onQtyInput"
          />
          <button type="button" :disabled="atMax" @click="bump(1)">+</button>
        </div>
        <small v-if="maxQuantity != null">{{ t('pos.quantityAvailable', { max: maxQuantity }) }}</small>
      </label>

      <label class="edit-line__field">
        <span>{{ t('pos.unitPrice') }}</span>
        <div class="edit-line__price">
          <input
            v-model="priceText"
            inputmode="decimal"
            autocomplete="off"
            @input="localError = ''"
          />
          <em v-if="currency">{{ currency }}</em>
        </div>
      </label>

      <p v-if="shownError" class="edit-line__error">{{ shownError }}</p>
    </div>

    <template #footer>
      <button type="button" class="btn-secondary" @click="emit('close')">{{ t('common.cancel') }}</button>
      <button type="button" class="btn-primary" @click="save">{{ t('common.save') }}</button>
    </template>
  </AppModal>
</template>

<style scoped>
.edit-line {
  display: flex;
  flex-direction: column;
  gap: 0.9rem;
}

.edit-line__summary {
  padding: 0.85rem 0.95rem;
  border: 1px solid var(--color-border);
  border-radius: 14px;
  background: var(--color-canvas, #f4f7fb);
}

.edit-line__name {
  margin: 0;
  font-weight: 750;
  color: var(--color-text-primary);
}

.edit-line__unit {
  margin: 0.15rem 0 0;
  font-size: 0.78rem;
  color: var(--color-text-faint);
}

.edit-line__total {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  margin: 0.7rem 0 0;
  padding-top: 0.7rem;
  border-top: 1px solid var(--color-border);
  font-size: 0.85rem;
  color: var(--color-text-secondary);
}

.edit-line__total strong {
  font-size: 1.05rem;
  color: var(--color-text-primary);
}

.edit-line__field {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
  font-size: 0.78rem;
  font-weight: 700;
  color: var(--color-text-secondary);
}

.edit-line__field small {
  font-weight: 600;
  color: var(--color-text-faint);
}

.edit-line__qty,
.edit-line__price {
  display: flex;
  align-items: center;
  border: 1px solid var(--color-border);
  border-radius: 12px;
  background: var(--color-surface, #fff);
  overflow: hidden;
}

.edit-line__qty button {
  width: 2.6rem;
  height: 2.7rem;
  border: 0;
  background: var(--color-canvas, #eef1f5);
  color: var(--color-text-primary);
  font-size: 1.15rem;
  cursor: pointer;
}

.edit-line__qty button:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}

.edit-line__qty input,
.edit-line__price input {
  width: 100%;
  border: 0;
  background: transparent;
  text-align: center;
  font-size: 1.25rem;
  font-weight: 750;
  padding: 0.65rem 0.75rem;
  color: var(--color-text-primary);
}

.edit-line__price em {
  flex-shrink: 0;
  padding-right: 0.85rem;
  font-style: normal;
  font-size: 0.75rem;
  font-weight: 700;
  color: var(--color-text-faint);
}

.edit-line__error {
  margin: 0;
  padding: 0.65rem 0.75rem;
  border-radius: 10px;
  background: color-mix(in srgb, #dc2626 10%, transparent);
  color: #b91c1c;
  font-size: 0.8rem;
  font-weight: 650;
}
</style>
