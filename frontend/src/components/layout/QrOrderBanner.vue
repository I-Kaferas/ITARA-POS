<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { api, getStoreId } from '../../api/client'
import { realtimeTopics, useRealtimeSync } from '../../composables/useRealtimeSync'

const { t } = useI18n()
const count = ref(0)
let known = -1

function beep() {
  try {
    const ctx = new AudioContext()
    const osc = ctx.createOscillator()
    const gain = ctx.createGain()
    osc.frequency.value = 880
    osc.connect(gain)
    gain.connect(ctx.destination)
    gain.gain.setValueAtTime(0.0001, ctx.currentTime)
    gain.gain.exponentialRampToValueAtTime(0.05, ctx.currentTime + 0.02)
    gain.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + 0.3)
    osc.start()
    osc.stop(ctx.currentTime + 0.32)
  } catch {
    /* the browser may block sound until a click */
  }
}

async function load() {
  const storeId = getStoreId()
  if (!storeId) return
  try {
    const res = await api.get<{ data: { pending_count: number } }>(`/stores/${storeId}/qr-orders?status=submitted`)
    const next = res.data.pending_count
    if (known >= 0 && next > known) beep()
    known = next
    count.value = next
  } catch {
    count.value = 0
  }
}

onMounted(load)
useRealtimeSync(realtimeTopics.qrOrders, () => load())
</script>

<template>
  <RouterLink v-if="count > 0" to="/admin/pos/qr-orders" class="qr-banner">
    {{ count }} {{ t('qr.banner') }}
  </RouterLink>
</template>

<style scoped>
.qr-banner {
  display: block;
  margin: 0;
  padding: 0.55rem 1rem;
  background: var(--color-warning-bg, #fff4d6);
  color: var(--color-text-primary, #1c1917);
  text-decoration: none;
  font-weight: 650;
}
</style>
