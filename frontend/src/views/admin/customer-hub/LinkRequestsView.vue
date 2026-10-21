<script setup lang="ts">
import { computed, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import PageFrame from '../../../components/layout/PageFrame.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'

type StatusKey = 'matching' | 'pending' | 'linked' | 'rejected'

const { t } = useI18n()
const query = ref('')
const status = ref<StatusKey | ''>('')
const refreshing = ref(false)

const stats = computed(() => [
  { key: 'matching' as const, label: t('linkRequestsPage.matching'), value: 0 },
  { key: 'pending' as const, label: t('linkRequestsPage.pending'), value: 0 },
  { key: 'linked' as const, label: t('linkRequestsPage.linked'), value: 0 },
  { key: 'rejected' as const, label: t('linkRequestsPage.rejected'), value: 0 },
])

const total = computed(() => stats.value.reduce((sum, item) => sum + item.value, 0))

function selectStatus(key: StatusKey | '') {
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

    <div class="requests" :class="{ 'is-refreshing': refreshing }" :aria-busy="refreshing">
      <section class="stage" :aria-label="t('linkRequestsPage.status')">
        <article class="spot">
          <div class="spot__top">
            <button type="button" class="spot__pick" @click="selectStatus('')">{{ t('linkRequestsPage.all') }}</button>
            <button type="button" class="spot__refresh" :disabled="refreshing" @click="refresh">
              <AppIcon name="refresh" :size="15" :class="{ 'is-spin': refreshing }" />
              {{ t('linkRequestsPage.refresh') }}
            </button>
          </div>
          <button type="button" class="spot__body" @click="selectStatus('')">
            <span class="spot__amount">{{ total }}</span>
            <span class="spot__hint">{{ t('linkRequestsPage.subtitle') }}</span>
          </button>
        </article>

        <div class="tiles">
          <button
            v-for="stat in stats"
            :key="stat.key"
            type="button"
            class="tile"
            :class="{ 'is-on': status === stat.key }"
            :aria-pressed="status === stat.key"
            @click="selectStatus(stat.key)"
          >
            <span class="tile__value">{{ stat.value }}</span>
            <span class="tile__label">{{ stat.label }}</span>
          </button>
        </div>
      </section>

      <section class="panel">
        <label class="search">
          <span class="sr-only">{{ t('linkRequestsPage.search') }}</span>
          <AppIcon name="search" :size="15" class="search__icon" />
          <input
            v-model="query"
            class="field search__input"
            type="search"
            :placeholder="t('linkRequestsPage.search')"
          />
        </label>
        <p class="empty">
          <AppIcon name="note" :size="20" />
          <span>{{ t('linkRequestsPage.empty') }}</span>
        </p>
      </section>
    </div>
  </PageFrame>
</template>

<style scoped>
.requests {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  min-width: 0;
}
.requests.is-refreshing { opacity: 0.72; }

.stage {
  display: grid;
  grid-template-columns: minmax(16rem, 22rem) minmax(0, 1fr);
  gap: 0.75rem;
  align-items: stretch;
}
.spot {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 0.7rem;
  padding: 0.95rem 1.05rem;
  border: 1px solid var(--color-border);
  border-left: 6px solid var(--color-accent);
  border-radius: 18px;
  background: var(--color-surface);
  box-shadow: var(--shadow-xs);
}
.spot__top { display: flex; align-items: center; justify-content: space-between; gap: 0.75rem; width: 100%; }
.spot__pick, .spot__body {
  border: 0;
  background: transparent;
  color: inherit;
  font: inherit;
  text-align: left;
  cursor: pointer;
  padding: 0;
}
.spot__pick {
  font-size: 0.75rem;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--color-text-muted);
}
.spot__body { display: flex; flex-direction: column; align-items: flex-start; gap: 0.7rem; }
.spot__refresh {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  height: 2rem;
  padding: 0 0.7rem;
  border: 1px solid var(--color-border);
  border-radius: 999px;
  background: var(--color-surface);
  color: var(--color-text-primary);
  font: inherit;
  font-size: 0.78rem;
  font-weight: 650;
  cursor: pointer;
}
.spot__refresh:disabled { opacity: 0.6; cursor: default; }
.spot__refresh :deep(.is-spin) { animation: req-spin 0.7s linear infinite; }
.spot__amount {
  font-family: var(--font-display);
  font-size: clamp(1.7rem, 2.6vw, 2.15rem);
  font-weight: 680;
  letter-spacing: -0.045em;
  line-height: 1;
}
.spot__hint { color: var(--color-text-secondary); font-size: 0.86rem; line-height: 1.35; }

.tiles {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.75rem;
}
.tile {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  justify-content: center;
  gap: 0.25rem;
  padding: 0.75rem 0.9rem;
  border: 1px solid var(--color-border);
  border-radius: 14px;
  background: var(--color-surface);
  box-shadow: var(--shadow-xs);
  color: inherit;
  font: inherit;
  text-align: left;
  cursor: pointer;
}
.tile.is-on { border-color: var(--color-brand-600); }
.tile__value {
  font-family: var(--font-display);
  font-size: 1.15rem;
  font-weight: 700;
  letter-spacing: -0.03em;
  line-height: 1.15;
}
.tile__label { font-size: 0.84rem; font-weight: 650; }

.panel {
  padding: 0.9rem 1rem 1rem;
  border: 1px solid var(--color-border);
  border-radius: 18px;
  background: var(--color-surface);
  box-shadow: var(--shadow-xs);
}
.search { position: relative; display: block; }
.search__icon {
  position: absolute;
  left: 0.7rem;
  top: 50%;
  transform: translateY(-50%);
  color: var(--color-text-muted);
  pointer-events: none;
}
.search input.field { width: 100%; padding-left: 2.15rem !important; }
.empty {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 0.45rem;
  margin: 1.1rem 0 0.4rem;
  color: var(--color-text-muted);
  font-size: 0.88rem;
}

@keyframes req-spin { to { transform: rotate(-360deg); } }

@media (max-width: 980px) {
  .stage { grid-template-columns: 1fr; }
}
@media (max-width: 640px) {
  .tiles { grid-template-columns: 1fr; }
}
</style>
