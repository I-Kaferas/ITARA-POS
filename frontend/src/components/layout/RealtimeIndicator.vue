<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import AppIcon from '../ui/AppIcon.vue'
import { useRealtimeStore } from '../../stores/realtime'

const { t } = useI18n()
const realtime = useRealtimeStore()

const label = computed(() => {
  if (realtime.status === 'connected') return t('realtime.connected')
  if (realtime.status === 'reconnecting' || realtime.status === 'connecting') return t('realtime.reconnecting')
  return t('realtime.disconnected')
})
</script>

<template>
  <span
    class="rt-dot"
    :class="`rt-dot--${realtime.status}`"
    :title="label"
    :aria-label="label"
  >
    <AppIcon name="wifi" :size="14" />
  </span>
</template>

<style scoped>
.rt-dot {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: var(--control-md);
  height: var(--control-md);
  min-width: var(--control-md);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  background: #fff;
  color: #94a3b8;
}
.rt-dot--connected { color: #0f766e; }
.rt-dot--connecting,
.rt-dot--reconnecting { color: #d97706; }
.rt-dot--disconnected { color: #94a3b8; }
</style>
