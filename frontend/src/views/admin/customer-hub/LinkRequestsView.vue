<script setup lang="ts">
import { computed, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import PageFrame from '../../../components/layout/PageFrame.vue'

type StatusKey = 'matching' | 'pending' | 'linked' | 'rejected'

const { t } = useI18n()
const query = ref('')
const status = ref<StatusKey | ''>('')
const filtersOpen = ref(false)
const refreshing = ref(false)

const stats = computed(() => [
  { key: 'matching' as const, label: t('linkRequestsPage.matching'), value: 0 },
  { key: 'pending' as const, label: t('linkRequestsPage.pending'), value: 0 },
  { key: 'linked' as const, label: t('linkRequestsPage.linked'), value: 0 },
  { key: 'rejected' as const, label: t('linkRequestsPage.rejected'), value: 0 },
])

function selectStatus(key: StatusKey) {
  status.value = status.value === key ? '' : key
}

function refresh() {
  if (refreshing.value) return
  refreshing.value = true
  query.value = ''
  status.value = ''
  window.setTimeout(() => {
    refreshing.value = false
  }, 350)
}
</script>

<template>
  <PageFrame>
    <template #title>{{ t('linkRequestsPage.title') }}</template>
    <template #subtitle>{{ t('linkRequestsPage.subtitle') }}</template>

    <div class="requests">
      <section class="requests__stats" :aria-busy="refreshing">
        <button
          v-for="stat in stats"
          :key="stat.key"
          type="button"
          class="requests__stat"
          :class="{ 'is-on': status === stat.key }"
          :aria-pressed="status === stat.key"
          @click="selectStatus(stat.key)"
        >
          <span class="requests__value">{{ stat.value }}</span>
          <span class="requests__label">{{ stat.label }}</span>
        </button>
      </section>

      <div class="requests__toolbar">
        <label class="requests__search">
          <span class="sr-only">{{ t('linkRequestsPage.search') }}</span>
          <input
            v-model="query"
            class="field"
            type="search"
            :placeholder="t('linkRequestsPage.search')"
          />
        </label>
        <button
          type="button"
          class="btn-secondary"
          :aria-expanded="filtersOpen"
          @click="filtersOpen = !filtersOpen"
        >
          {{ filtersOpen ? t('linkRequestsPage.hideFilters') : t('linkRequestsPage.filters') }}
        </button>
        <button type="button" class="btn-secondary" :disabled="refreshing" @click="refresh">
          {{ t('linkRequestsPage.refresh') }}
        </button>
      </div>

      <div v-if="filtersOpen" class="requests__filters">
        <label>
          <span>{{ t('linkRequestsPage.status') }}</span>
          <select v-model="status" class="field">
            <option value="">{{ t('linkRequestsPage.allStatuses') }}</option>
            <option v-for="stat in stats" :key="stat.key" :value="stat.key">{{ stat.label }}</option>
          </select>
        </label>
      </div>

      <div class="requests__table-wrap">
        <table class="ui-table">
          <thead>
            <tr>
              <th>{{ t('linkRequestsPage.requester') }}</th>
              <th>{{ t('linkRequestsPage.status') }}</th>
              <th>{{ t('linkRequestsPage.linkType') }}</th>
              <th>{{ t('linkRequestsPage.companyLink') }}</th>
              <th>{{ t('linkRequestsPage.date') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td class="requests__empty" colspan="5">{{ t('linkRequestsPage.empty') }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </PageFrame>
</template>

<style scoped>
.requests {
  display: flex;
  flex-direction: column;
  gap: var(--space-5);
  max-width: 72rem;
}

.requests__stats {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  border: 1px solid var(--color-border);
  border-radius: 12px;
  background: var(--color-surface);
  overflow: hidden;
}

.requests__stat {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 0.15rem;
  min-width: 0;
  padding: var(--space-4) var(--space-5);
  border: 0;
  border-right: 1px solid var(--color-border);
  background: transparent;
  text-align: left;
  cursor: pointer;
}

.requests__stat:last-child {
  border-right: 0;
}

.requests__stat:hover {
  background: var(--color-table-header);}

.requests__stat.is-on {
  background: var(--color-canvas);
  box-shadow: inset 0 -2px 0 #1c2430;}

.requests__stat:focus-visible {
  outline: 2px solid #1c2430;
  outline-offset: -2px;
}

.requests__value {
  font-size: 1.5rem;
  font-weight: 650;
  letter-spacing: -0.02em;
  font-variant-numeric: tabular-nums;
  line-height: 1.15;
  color: var(--color-text-primary);
}

.requests__label {
  font-size: var(--text-sm);
  color: var(--color-text-muted);
}

.requests__toolbar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-2);
}

.requests__search {
  flex: 1;
  min-width: min(100%, 16rem);
}

.requests__search .field {
  width: 100%;
}

.requests__filters {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-3);
}

.requests__filters label {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
  min-width: 14rem;
  font-size: var(--text-xs);
  font-weight: 600;
  color: var(--color-text-secondary);
}

.requests__table-wrap {
  overflow-x: auto;
  border-top: 1px solid var(--color-border);
}

.requests__empty {
  color: var(--color-text-muted);
  font-weight: 450;
}

@media (max-width: 800px) {
  .requests__stats {
    grid-template-columns: 1fr 1fr;
  }

  .requests__stat:nth-child(2n) {
    border-right: 0;
  }

  .requests__stat:nth-child(-n + 2) {
    border-bottom: 1px solid var(--color-border);
  }
}

@media (max-width: 520px) {
  .requests__stats {
    grid-template-columns: 1fr;
  }

  .requests__stat {
    border-right: 0;
    border-bottom: 1px solid var(--color-border);
  }

  .requests__stat:last-child {
    border-bottom: 0;
  }
}
</style>
