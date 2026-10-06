<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import AppIcon from '../ui/AppIcon.vue'
import { useRealtimeStore } from '../../stores/realtime'

const { t } = useI18n()
const realtime = useRealtimeStore()
const open = ref(false)
const pulse = ref(false)
let pulseTimer: ReturnType<typeof setTimeout> | undefined

watch(() => realtime.lastEvent, (event) => {
  if (!event) return
  pulse.value = false
  window.requestAnimationFrame(() => {
    pulse.value = true
  })
  if (pulseTimer) window.clearTimeout(pulseTimer)
  pulseTimer = window.setTimeout(() => {
    pulse.value = false
  }, 420)
})

const label = computed(() => {
  if (realtime.status === 'connected') return t('realtime.connected')
  if (realtime.status === 'reconnecting' || realtime.status === 'connecting') return t('realtime.reconnecting')
  return t('realtime.disconnected')
})

const lastType = computed(() => realtime.lastEvent?.type || '—')
</script>

<template>
  <span class="rt">
    <button
      type="button"
      class="rt-dot"
      :class="[`rt-dot--${realtime.status}`, { 'rt-dot--ack': pulse }]"
      :title="label"
      :aria-label="label"
      :aria-expanded="open"
      @click="open = !open"
    >
      <AppIcon name="wifi" :size="14" />
    </button>
    <div v-if="open" class="rt-panel" role="status">
      <p class="rt-panel__status">{{ label }}</p>
      <p>{{ t('realtime.lastEvent') }}: {{ lastType }}</p>
      <p>{{ t('realtime.lastSync') }}: {{ realtime.lastSyncAt || '—' }}</p>
      <p>{{ t('realtime.online') }}: {{ realtime.onlineCount }}</p>
      <p v-if="realtime.notice">{{ t(`realtime.${realtime.notice === 'stock.out' ? 'stockOut' : 'stockLow'}`) }}</p>
    </div>
  </span>
</template>

<style scoped>
.rt { position: relative; }
.rt-dot {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: var(--control-md);
  height: var(--control-md);
  min-width: var(--control-md);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  background: var(--color-surface);
  color: var(--color-text-muted);
  cursor: pointer;
}
.rt-dot--connected { color: light-dark(#0f766e, #9ac5c2);}
.rt-dot--ack { animation: rt-ack var(--motion-slow, 250ms) var(--ease-out, ease); }
@keyframes rt-ack {
  0% { transform: scale(1); }
  35% { transform: scale(1.06); }
  100% { transform: scale(1); }
}
.rt-dot--connecting,
.rt-dot--reconnecting { color: light-dark(#d97706, #e9b06f);}
.rt-dot--disconnected { color: var(--color-text-faint);}
.rt-panel {
  position: absolute;
  top: calc(100% + 8px);
  right: 0;
  z-index: 30;
  width: 16rem;
  padding: 12px;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  background: var(--color-surface);
  box-shadow: var(--shadow-md);
  color: var(--color-text-secondary);
  font-size: 13px;
  line-height: 1.4;
}
.rt-panel p { margin: 0 0 6px; }
.rt-panel__status { font-weight: 600; color: var(--color-text-primary); }
</style>
