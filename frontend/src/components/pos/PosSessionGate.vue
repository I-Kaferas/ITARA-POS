<script setup lang="ts">
import { computed, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { formatMoney } from '../../utils/money'

const props = defineProps<{
  registers: { id: string; name: string; code?: string }[]
  cashierName?: string | null
  expectedCash?: number | null
  open: boolean
}>()

const emit = defineEmits<{
  openShift: [payload: { pin: string; registerId: string; opening: number }]
  closeShift: [payload: { pin: string; counted: number; notes: string }]
  switch: []
}>()

const { t } = useI18n()
const pin = ref('')
const registerId = ref(props.registers[0]?.id ?? '')
const opening = ref('0')
const counted = ref('')
const notes = ref('')
const error = ref('')

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
  emit('closeShift', { pin: pin.value, counted: countedMinor.value, notes: notes.value })
}
</script>

<template>
  <div v-if="!open" class="gate">
    <form class="card" @submit.prevent="submitOpen">
      <h2>{{ t('pos.openShift') }}</h2>
      <p>{{ t('pos.openShiftHint') }}</p>
      <label>{{ t('pos.register') }}
        <select v-model="registerId" required>
          <option v-for="item in registers" :key="item.id" :value="item.id">{{ item.name }}</option>
        </select>
      </label>
      <label>{{ t('org.pin') }}
        <input v-model="pin" inputmode="numeric" maxlength="6" autocomplete="off" required />
      </label>
      <label>{{ t('pos.openingFloat') }}
        <input v-model="opening" type="number" min="0" step="0.01" />
      </label>
      <p v-if="error" class="error">{{ error }}</p>
      <button type="submit">{{ t('pos.openShift') }}</button>
    </form>
  </div>
  <form v-else class="close" @submit.prevent="submitClose">
    <div>
      <strong>{{ cashierName }}</strong>
      <span>{{ t('pos.expectedCash') }}: {{ formatMoney(expectedCash ?? 0) }}</span>
    </div>
    <input v-model="counted" type="number" min="0" step="0.01" :placeholder="t('pos.countedCash')" required />
    <input v-model="notes" :placeholder="t('pos.note')" />
    <input v-model="pin" inputmode="numeric" maxlength="6" :placeholder="t('org.pin')" required />
    <span v-if="variance !== null">{{ t('pos.variance') }}: {{ formatMoney(variance) }}</span>
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
label { display: flex; flex-direction: column; gap: 0.3rem; font-size: 0.82rem; font-weight: 600; }
input, select, button { border: 1px solid #cbd5e1; border-radius: 0.55rem; padding: 0.5rem 0.7rem; }
button { background: #4a6d86; color: white; border: 0; font-weight: 650; cursor: pointer; }
</style>
