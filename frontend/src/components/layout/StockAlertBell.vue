<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import AppIcon from '../ui/AppIcon.vue'
import { api } from '../../api/client'
import { realtimeTopics, useRealtimeSync } from '../../composables/useRealtimeSync'
import { useRealtimeStore } from '../../stores/realtime'

type InboxItem = {
  id: string
  event: string
  title: string
  body: string
  context?: { link?: string } | null
  read_at: string | null
}

const { t } = useI18n()
const router = useRouter()
const open = ref(false)
const root = ref<HTMLElement | null>(null)
const alerts = ref<InboxItem[]>([])
const unread = ref(0)
const realtime = useRealtimeStore()
let timer: ReturnType<typeof setInterval> | undefined

useRealtimeSync(realtimeTopics.notifications, () => load())

const visible = computed(() => alerts.value.slice(0, 8))

async function load() {
  try {
    const payload = await api.get<{ data: InboxItem[]; meta?: { unread?: number } }>('/notification-center?per_page=8')
    alerts.value = payload.data ?? []
    unread.value = payload.meta?.unread ?? alerts.value.filter(item => !item.read_at).length
  } catch {
    alerts.value = []
    unread.value = 0
  }
}

function typeLabel(event: string): string {
  const key = `notifications.events.${event}`
  const label = t(key)
  return label === key ? event : label
}

function openItem(item: InboxItem) {
  open.value = false
  if (!item.read_at) void api.post(`/notification-center/${item.id}/read`).catch(() => undefined)
  void router.push(item.context?.link || '/admin/notifications')
}

function onDocumentClick(event: MouseEvent) {
  if (!root.value?.contains(event.target as Node)) open.value = false
}

function seeAll() {
  open.value = false
  void router.push('/admin/notifications')
}

watch(open, (isOpen) => {
  if (isOpen) void load()
})

onMounted(() => {
  void load()
  timer = setInterval(() => {
    if (realtime.status !== 'connected') void load()
  }, 60_000)
  document.addEventListener('click', onDocumentClick)
})

onBeforeUnmount(() => {
  if (timer) clearInterval(timer)
  document.removeEventListener('click', onDocumentClick)
})
</script>

<template>
  <div ref="root" class="stock-bell">
    <div v-if="open" class="stock-bell__panel" role="dialog" :aria-label="t('stockAlerts.title')">
      <div class="stock-bell__head">
        <p class="stock-bell__title">{{ t('notifications.title') }}</p>
        <p class="stock-bell__count">{{ t('notifications.unread', { count: unread }) }}</p>
      </div>

      <ul v-if="visible.length" class="stock-bell__list">
        <li v-for="alert in visible" :key="alert.id">
          <button type="button" class="stock-bell__item" @click="openItem(alert)">
            <span class="stock-bell__name">{{ alert.title }}</span>
            <span class="stock-bell__meta">{{ typeLabel(alert.event) }} · {{ alert.body }}</span>
          </button>
        </li>
      </ul>
      <p v-else class="stock-bell__empty">{{ t('notifications.empty') }}</p>

      <button type="button" class="stock-bell__all" @click="seeAll">
        {{ t('notifications.openCenter') }}
      </button>
    </div>

    <button
      type="button"
      class="stock-bell__btn"
      :class="{ 'stock-bell__btn--open': open }"
      :aria-label="t('notifications.title')"
      :title="t('notifications.title')"
      @click="open = !open"
    >
      <AppIcon name="bell" :size="16" />
      <span v-if="unread" class="stock-bell__badge">{{ unread > 9 ? '9+' : unread }}</span>
    </button>
  </div>
</template>

<style scoped>
.stock-bell { position: relative; }

.stock-bell__btn {
  position: relative;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: var(--control-md);
  height: var(--control-md);
  min-width: var(--control-md);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  background: var(--color-surface);
  color: var(--color-ink-brand, var(--color-brand-600));
  cursor: pointer;}

.stock-bell__btn--open,
.stock-bell__btn:hover {
  border-color: #c5d4e0;
  color: var(--color-text-primary);}

.stock-bell__badge {
  position: absolute;
  top: -0.3rem;
  right: -0.3rem;
  min-width: 1rem;
  height: 1rem;
  padding: 0 0.25rem;
  border-radius: 999px;
  background: #c2410c;
  color: #fff;
  font-size: 0.625rem;
  line-height: 1rem;
  font-weight: 700;
}

.stock-bell__panel {
  position: absolute;
  top: calc(100% + var(--space-2));
  right: 0;
  z-index: 40;
  width: 18.5rem;
  overflow: hidden;
  padding: var(--space-1);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  background: var(--color-surface);
  box-shadow: var(--shadow-md);}

.stock-bell__head {
  padding: 0.75rem 0.85rem 0.55rem;
  border-bottom: 1px solid #f1f5f9;
}

.stock-bell__title {
  margin: 0;
  font-size: var(--text-lg);
  font-weight: 600;
  line-height: var(--line-md);
  color: var(--color-text-primary);}

.stock-bell__count,
.stock-bell__meta,
.stock-bell__empty {
  margin: var(--space-1) 0 0;
  font-size: var(--text-xs);
  line-height: var(--line-xs);
  color: var(--color-text-muted);}

.stock-bell__list {
  margin: 0;
  padding: 0.25rem 0;
  list-style: none;
}

.stock-bell__item {
  display: flex;
  flex-direction: column;
  justify-content: center;
  width: 100%;
  min-height: var(--control-md);
  border: 0;
  border-radius: var(--radius-sm);
  background: transparent;
  text-align: left;
  padding: var(--space-2) var(--space-3);
  cursor: pointer;
}

.stock-bell__item:hover { background: var(--color-table-header);}

.stock-bell__name {
  display: block;
  font-size: var(--text-md);
  font-weight: 500;
  line-height: var(--line-sm);
  color: var(--color-text-primary);}

.stock-bell__empty { padding: 0.85rem; }

.stock-bell__all {
  display: block;
  width: 100%;
  border: 0;
  border-top: 1px solid #f1f5f9;
  background: var(--color-table-header);
  color: light-dark(#1d4e89, #a0b5cd);
  font-size: 0.75rem;
  font-weight: 650;
  padding: 0.65rem 0.85rem;
  cursor: pointer;
  text-align: left;}
</style>
