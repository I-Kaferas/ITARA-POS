<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { formatMoney } from '../../utils/money'
import FieldLabel from '../ui/FieldLabel.vue'

const props = defineProps<{
  registers: { id: string; name: string; code?: string }[]
  cashierName?: string | null
  expectedCash?: number | null
  open: boolean
}>()

const emit = defineEmits<{
  openShift: [payload: { pin: string; registerId: string; opening: number }]
  closeShift: [payload: { pin: string; counted: number; notes: string; reason: string }]
  dismiss: []
  switch: []
}>()

const { t } = useI18n()
const pin = ref('')
const registerId = ref('')
const opening = ref('0')
const counted = ref('')
const notes = ref('')
const reason = ref('')
const error = ref('')

watch(
  () => props.registers,
  (list) => {
    if (!list.some(item => item.id === registerId.value)) {
      registerId.value = list[0]?.id ?? ''
    }
  },
  { immediate: true },
)

const countedMinor = computed(() => Math.round((Number(counted.value) || 0) * 100))
const variance = computed(() => props.expectedCash == null ? null : countedMinor.value - props.expectedCash)

async function submitOpen() {
  error.value = ''
  if (!/^\d{4,6}$/.test(pin.value) || !registerId.value) {
    error.value = t('pos.pinInvalid')
    return
  }
  emit('openShift', {
    pin: pin.value,
    registerId: registerId.value,
    opening: Math.round((Number(opening.value) || 0) * 100),
  })
}

function submitClose() {
  error.value = ''
  if (!/^\d{4,6}$/.test(pin.value)) {
    error.value = t('pos.pinInvalid')
    return
  }
  if (variance.value !== 0 && !reason.value.trim()) {
    error.value = t('pos.varianceReasonRequired')
    return
  }
  emit('closeShift', { pin: pin.value, counted: countedMinor.value, notes: notes.value, reason: reason.value.trim() })
}
</script>

<template>
  <div v-if="!open" class="gate" @click.self="emit('dismiss')">
    <form class="card" @submit.prevent="submitOpen">
      <h2>{{ t('pos.openShift') }}</h2>
      <p>{{ t('pos.openShiftHint') }}</p>
      <div class="gate-field">
        <FieldLabel icon="shift">{{ t('pos.register') }}</FieldLabel>
        <select v-model="registerId" required :disabled="!registers.length">
          <option v-if="!registers.length" value="">{{ t('pos.noRegister') }}</option>
          <option v-for="item in registers" :key="item.id" :value="item.id">
            {{ item.name }}<template v-if="item.code"> ({{ item.code }})</template>
          </option>
        </select>
        <p v-if="!registers.length" class="error">{{ t('pos.noRegister') }}</p>
      </div>
      <div class="gate-field">
        <FieldLabel icon="lock">{{ t('org.pin') }}</FieldLabel>
        <input v-model="pin" inputmode="numeric" maxlength="6" autocomplete="off" required />
      </div>
      <div class="gate-field">
        <FieldLabel icon="coins">{{ t('pos.openingFloat') }}</FieldLabel>
        <input v-model="opening" type="number" min="0" step="0.01" />
      </div>
      <p v-if="error" class="error">{{ error }}</p>
      <div class="gate-actions">
        <button type="button" class="gate-cancel" @click="emit('dismiss')">{{ t('common.cancel') }}</button>
        <button type="submit">{{ t('pos.openShift') }}</button>
      </div>
    </form>
  </div>
  <form v-else class="close" @submit.prevent="submitClose">
    <div>
      <strong>{{ cashierName }}</strong>
      <span>{{ t('pos.theoreticalCash') }}: {{ formatMoney(expectedCash ?? 0) }}</span>
    </div>
    <input v-model="counted" type="number" min="0" step="0.01" :placeholder="t('pos.actualCash')" required />
    <span v-if="variance !== null">{{ t('pos.difference') }}: {{ formatMoney(variance) }}</span>
    <input
      v-model="reason"
      :placeholder="t('pos.varianceReason')"
      :required="variance !== 0"
    />
    <input v-model="notes" :placeholder="t('pos.note')" />
    <input v-model="pin" inputmode="numeric" maxlength="6" :placeholder="t('org.pin')" required />
    <button type="submit">{{ t('pos.closeShift') }}</button>
  </form>
</template>

<style scoped>
.gate { position: absolute; inset: 0; z-index: 30; display: grid; place-items: center; background: rgba(15, 23, 42, 0.45); }
.card, .close { display: flex; flex-wrap: wrap; gap: 0.6rem; align-items: end; background: white; border-radius: 1rem; padding: 1rem; }
.card { width: min(24rem, 92vw); flex-direction: column; align-items: stretch; }
.card h2, .card p { margin: 0; }
.card p, .error { color: #64748b; font-size: 0.85rem; }
.error { color: #b91c1c; }
.gate-field { display: flex; flex-direction: column; gap: 0.3rem; }
input, select, button { border: 1px solid #cbd5e1; border-radius: 0.55rem; padding: 0.5rem 0.7rem; }
button { background: var(--color-brand-600); color: white; border: 0; font-weight: 650; cursor: pointer; }
.gate-actions { display: flex; gap: 0.5rem; }
.gate-actions button { flex: 1; }
.gate-cancel { background: #fff !important; color: #334155 !important; border: 1px solid #cbd5e1 !important; }
</style>
