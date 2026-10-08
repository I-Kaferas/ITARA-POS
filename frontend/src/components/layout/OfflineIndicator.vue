<script setup lang="ts">
import { computed, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import AppIcon from '../ui/AppIcon.vue'
import { humanizeErrorText } from '../../errors/resolveApiError'
import { useOfflineStore } from '../../stores/offline'

const { t } = useI18n()
const offline = useOfflineStore()
const open = ref(false)

const tone = computed(() => {
  if (!offline.online) return 'offline'
  if (offline.conflicts.length) return 'conflict'
  if (offline.syncing || offline.pending.length) return 'syncing'
  return 'online'
})

const label = computed(() => {
  if (!offline.online) return t('offline.offline')
  if (offline.syncing) return t('offline.syncing')
  if (offline.conflicts.length) return t('offline.conflicts')
  if (offline.pending.length) return t('offline.pending')
  return t('offline.online')
})
</script>

<template>
  <span class="off">
    <button
      type="button"
      class="off-btn"
      :class="`off-btn--${tone}`"
      :title="label"
      :aria-label="label"
      :aria-expanded="open"
      @click="open = !open"
    >
      <AppIcon name="wifi" :size="14" />
      <span v-if="offline.pending.length || offline.conflicts.length" class="off-count">
        {{ offline.pending.length + offline.conflicts.length }}
      </span>
    </button>
    <div v-if="open" class="off-panel" role="status">
      <p class="off-panel__title">{{ label }}</p>
      <p class="off-panel__hint">{{ t('offline.architecture') }}</p>
      <p v-if="!offline.transactions.length" class="off-empty">{{ t('offline.empty') }}</p>
      <ul v-else class="off-list">
        <li v-for="item in offline.transactions" :key="item.uuid">
          <div>
            <strong>{{ t(`offline.domain.${item.domain}`) }}</strong>
            <span>{{ item.operation }}</span>
          </div>
          <small>{{ t('offline.uuid') }} {{ item.uuid }}</small>
          <p v-if="item.conflict" class="off-error">{{ humanizeErrorText(item.conflict.message) }}</p>
          <p v-else-if="item.lastError" class="off-error">{{ humanizeErrorText(item.lastError) }}</p>
          <div v-if="item.status === 'conflict'" class="off-actions">
            <button type="button" @click="offline.resolve(item.uuid, 'keep_local')">{{ t('offline.keepLocal') }}</button>
            <button type="button" @click="offline.resolve(item.uuid, 'accept_server')">{{ t('offline.acceptServer') }}</button>
            <button type="button" @click="offline.resolve(item.uuid, 'discard')">{{ t('offline.discard') }}</button>
          </div>
          <div v-else-if="item.status === 'failed'" class="off-actions">
            <button type="button" @click="offline.retry(item.uuid)">{{ t('offline.retry') }}</button>
            <button type="button" @click="offline.resolve(item.uuid, 'discard')">{{ t('offline.discard') }}</button>
          </div>
        </li>
      </ul>
    </div>
  </span>
</template>

<style scoped>
.off { position: relative; }
.off-btn {
  position: relative;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: var(--control-md);
  height: var(--control-md);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  background: var(--color-surface);
  color: var(--color-text-muted);
  cursor: pointer;
}
.off-btn--online { color: light-dark(#0f766e, #9ac5c2); }
.off-btn--syncing { color: light-dark(#d97706, #e9b06f); }
.off-btn--offline,
.off-btn--conflict { color: light-dark(#b91c1c, #f0a8a8); }
.off-count {
  position: absolute;
  top: -6px;
  right: -6px;
  min-width: 16px;
  height: 16px;
  padding: 0 4px;
  border-radius: 999px;
  background: light-dark(#b45309, #d4a574);
  color: white;
  font-size: 10px;
  line-height: 16px;
}
.off-panel {
  position: absolute;
  top: calc(100% + 8px);
  right: 0;
  z-index: 40;
  width: min(360px, 80vw);
  max-height: 420px;
  overflow: auto;
  padding: 12px;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  background: var(--color-surface);
  box-shadow: var(--shadow-md, 0 8px 24px rgb(0 0 0 / 12%));
}
.off-panel__title { margin: 0; font-weight: 650; }
.off-panel__hint, .off-empty { margin: 6px 0 0; color: var(--color-text-muted); font-size: 12px; }
.off-list { list-style: none; margin: 10px 0 0; padding: 0; display: grid; gap: 10px; }
.off-list li { display: grid; gap: 4px; font-size: 13px; }
.off-list small { color: var(--color-text-muted); word-break: break-all; }
.off-error { margin: 0; color: light-dark(#b91c1c, #f0a8a8); }
.off-actions { display: flex; flex-wrap: wrap; gap: 6px; }
.off-actions button {
  border: 1px solid var(--color-border);
  border-radius: var(--radius-sm, 6px);
  background: transparent;
  padding: 4px 8px;
  cursor: pointer;
}
</style>
