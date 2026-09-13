<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import AppIcon from '../ui/AppIcon.vue'
import { api } from '../../api/client'
import type { InventoryAlert } from '../../types'

const { t } = useI18n()
const router = useRouter()
const open = ref(false)
const root = ref<HTMLElement | null>(null)
const alerts = ref<InventoryAlert[]>([])

const visible = computed(() =>
  alerts.value.filter(alert => alert.status !== 'resolved').slice(0, 8),
)

async function load() {
  try {
    const res = await api.get<{ data: { data?: InventoryAlert[] } | InventoryAlert[] }>('/inventory/alerts?per_page=8')
    const payload = res.data
    alerts.value = Array.isArray(payload) ? payload : payload.data ?? []
  } catch {
    alerts.value = []
  }
}

function typeLabel(type: string): string {
  if (type === 'LOW_STOCK') return t('stockAlerts.lowStock')
  if (type === 'OUT_OF_STOCK') return t('stockAlerts.outOfStock')
  return type.replaceAll('_', ' ').toLowerCase()
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
  document.addEventListener('click', onDocumentClick)
})

onBeforeUnmount(() => document.removeEventListener('click', onDocumentClick))
</script>

<template>
  <div ref="root" class="stock-bell">
    <div v-if="open" class="stock-bell__panel" role="dialog" :aria-label="t('stockAlerts.title')">
      <div class="stock-bell__head">
        <p class="stock-bell__title">{{ t('stockAlerts.title') }}</p>
        <p class="stock-bell__count">{{ t('stockAlerts.count', { count: visible.length }) }}</p>
      </div>

      <ul v-if="visible.length" class="stock-bell__list">
        <li v-for="alert in visible" :key="alert.id">
          <button type="button" class="stock-bell__item" @click="seeAll">
            <span class="stock-bell__name">{{ alert.product?.name || '—' }}</span>
            <span class="stock-bell__meta">
              {{ typeLabel(alert.alert_type) }}
              <template v-if="alert.warehouse?.name"> · {{ alert.warehouse.name }}</template>
            </span>
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
  width: 2.15rem;
  height: 2.15rem;
  border: 1px solid #e2e8f0;
  border-radius: 0.7rem;
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
  top: calc(100% + 0.45rem);
  right: 0;
  z-index: 40;
  width: 18.5rem;
  overflow: hidden;
  border: 1px solid #e2e8f0;
  border-radius: 0.85rem;
  background: #fff;
  box-shadow: 0 16px 40px rgba(15, 23, 42, 0.12);
}

.stock-bell__head {
  padding: 0.75rem 0.85rem 0.55rem;
  border-bottom: 1px solid #f1f5f9;
}

.stock-bell__title {
  margin: 0;
  font-size: 0.8125rem;
  font-weight: 650;
  color: #16324f;
}

.stock-bell__count,
.stock-bell__meta,
.stock-bell__empty {
  margin: 0.15rem 0 0;
  font-size: 0.72rem;
  color: #64748b;
}

.stock-bell__list {
  margin: 0;
  padding: 0.25rem 0;
  list-style: none;
}

.stock-bell__item {
  display: block;
  width: 100%;
  border: 0;
  background: transparent;
  text-align: left;
  padding: 0.45rem 0.85rem;
  cursor: pointer;
}

.stock-bell__item:hover { background: #f8fafc; }

.stock-bell__name {
  display: block;
  font-size: 0.8rem;
  font-weight: 600;
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
