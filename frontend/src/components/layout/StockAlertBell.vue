<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import AppIcon from '../ui/AppIcon.vue'
import { api } from '../../api/client'

type WatchItem = { kind: string; title: string; detail: string }

const { t } = useI18n()
const router = useRouter()
const open = ref(false)
const root = ref<HTMLElement | null>(null)
const alerts = ref<WatchItem[]>([])
let timer: ReturnType<typeof setInterval> | undefined

const visible = computed(() => alerts.value.slice(0, 12))

const targets: Record<string, string> = {
  low_stock: '/admin/inventory/alerts',
  expired: '/admin/inventory/alerts',
  sync_failed: '/admin/organization/devices',
  cash_open: '/admin/pos/shifts',
  credit_overdue: '/admin/customers',
  order_pending: '/admin/pos/orders',
}

async function load() {
  try {
    alerts.value = (await api.get<{ data: WatchItem[] }>('/notifications')).data ?? []
  } catch {
    alerts.value = []
  }
}

function typeLabel(kind: string): string {
  const labels: Record<string, string> = {
    low_stock: t('stockAlerts.lowStock'),
    expired: t('stockAlerts.expired'),
    sync_failed: t('stockAlerts.syncFailed'),
    cash_open: t('stockAlerts.cashOpen'),
    credit_overdue: t('stockAlerts.creditOverdue'),
    order_pending: t('stockAlerts.orderPending'),
  }
  return labels[kind] ?? kind
}

function openItem(item: WatchItem) {
  open.value = false
  void router.push(targets[item.kind] ?? '/admin/inventory/alerts')
}

function onDocumentClick(event: MouseEvent) {
  if (!root.value?.contains(event.target as Node)) open.value = false
}

function seeAll() {
  open.value = false
  void router.push('/admin/inventory/alerts')
}

onMounted(() => {
  void load()
  timer = setInterval(() => void load(), 60_000)
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
        <p class="stock-bell__title">{{ t('stockAlerts.title') }}</p>
        <p class="stock-bell__count">{{ t('stockAlerts.count', { count: visible.length }) }}</p>
      </div>

      <ul v-if="visible.length" class="stock-bell__list">
        <li v-for="(alert, index) in visible" :key="`${alert.kind}-${index}`">
          <button type="button" class="stock-bell__item" @click="openItem(alert)">
            <span class="stock-bell__name">{{ alert.title }}</span>
            <span class="stock-bell__meta">{{ typeLabel(alert.kind) }} · {{ alert.detail }}</span>
          </button>
        </li>
      </ul>
      <p v-else class="stock-bell__empty">{{ t('stockAlerts.empty') }}</p>

      <button type="button" class="stock-bell__all" @click="seeAll">
        {{ t('stockAlerts.seeAll') }}
      </button>
    </div>

    <button
      type="button"
      class="stock-bell__btn"
      :class="{ 'stock-bell__btn--open': open }"
      :aria-label="t('stockAlerts.title')"
      :title="t('stockAlerts.title')"
      @click="open = !open"
    >
      <AppIcon name="bell" :size="16" />
      <span v-if="visible.length" class="stock-bell__badge">{{ visible.length > 9 ? '9+' : visible.length }}</span>
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
  background: #fff;
  color: #3d5c73;
  cursor: pointer;
}

.stock-bell__btn--open,
.stock-bell__btn:hover {
  border-color: #c5d4e0;
  color: #16324f;
}

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
  background: #fff;
  box-shadow: var(--shadow-md);
}

.stock-bell__head {
  padding: 0.75rem 0.85rem 0.55rem;
  border-bottom: 1px solid #f1f5f9;
}

.stock-bell__title {
  margin: 0;
  font-size: var(--text-lg);
  font-weight: 600;
  line-height: var(--line-md);
  color: #16324f;
}

.stock-bell__count,
.stock-bell__meta,
.stock-bell__empty {
  margin: var(--space-1) 0 0;
  font-size: var(--text-xs);
  line-height: var(--line-xs);
  color: #64748b;
}

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

.stock-bell__item:hover { background: #f8fafc; }

.stock-bell__name {
  display: block;
  font-size: var(--text-md);
  font-weight: 500;
  line-height: var(--line-sm);
  color: #1e293b;
}

.stock-bell__empty { padding: 0.85rem; }

.stock-bell__all {
  display: block;
  width: 100%;
  border: 0;
  border-top: 1px solid #f1f5f9;
  background: #f8fafc;
  color: #1d4e89;
  font-size: 0.75rem;
  font-weight: 650;
  padding: 0.65rem 0.85rem;
  cursor: pointer;
  text-align: left;
}
</style>
