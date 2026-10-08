<script setup lang="ts">
import { computed, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import PageFrame from '../../components/layout/PageFrame.vue'
import AppAlert from '../../components/ui/AppAlert.vue'
import AppButton from '../../components/ui/AppButton.vue'
import AppCard from '../../components/ui/AppCard.vue'
import AppChart from '../../components/ui/AppChart.vue'
import AppDrawer from '../../components/ui/AppDrawer.vue'
import AppDropdown from '../../components/ui/AppDropdown.vue'
import AppField from '../../components/ui/AppField.vue'
import AppLoading from '../../components/ui/AppLoading.vue'
import AppModal from '../../components/ui/AppModal.vue'
import AppSkeleton from '../../components/ui/AppSkeleton.vue'
import AppTabs from '../../components/ui/AppTabs.vue'
import Badge from '../../components/ui/Badge.vue'
import DataTableShell from '../../components/ui/DataTableShell.vue'
import EmptyState from '../../components/ui/EmptyState.vue'
import KpiCard from '../../components/ui/KpiCard.vue'
import LoadingBlock from '../../components/ui/LoadingBlock.vue'
import { useToast } from '../../composables/useToast'
import { formatMoney } from '../../utils/format'

const { t, locale } = useI18n()
const { push } = useToast()

const name = ref('')
const method = ref('cash')
const note = ref('')
const tab = ref('overview')
const modalOpen = ref(false)
const drawerOpen = ref(false)
const action = ref('')
const showLoading = ref(false)
const warningVisible = ref(true)

const sections = [
  'colors',
  'type',
  'space',
  'buttons',
  'inputs',
  'tables',
  'cards',
  'badges',
  'dropdowns',
  'modals',
  'drawers',
  'tabs',
  'alerts',
  'toasts',
  'charts',
  'empty',
  'loading',
  'skeletons',
] as const

const swatches = [
  { name: 'navy', token: '--color-brand-600' },
  { name: 'ink', token: '--color-text' },
  { name: 'canvas', token: '--color-canvas' },
  { name: 'surface', token: '--color-surface' },
  { name: 'muted', token: '--color-text-muted' },
  { name: 'border', token: '--color-border-strong' },
  { name: 'accent', token: '--color-accent' },
  { name: 'success', token: '--color-success' },
  { name: 'warning', token: '--color-warning' },
  { name: 'danger', token: '--color-danger' },
  { name: 'info', token: '--color-info' },
] as const

const steps = [4, 8, 12, 16, 24, 32, 48, 64]

const days = computed(() => {
  const format = new Intl.DateTimeFormat(locale.value, { weekday: 'short' })
  const monday = new Date(2026, 9, 5)
  return Array.from({ length: 7 }, (_, index) => {
    const date = new Date(monday)
    date.setDate(monday.getDate() + index)
    return format.format(date).replace(/\./g, '').slice(0, 3)
  })
})

const revenue = computed(() =>
  [420, 510, 380, 640, 590, 710, 680].map((value, index) => ({
    label: days.value[index] ?? '',
    value,
  })),
)

const covers = computed(() =>
  [42, 48, 36, 61, 55, 70, 66].map((value, index) => ({
    label: days.value[index] ?? '',
    value,
  })),
)

const menu = computed(() => [
  { id: 'edit', label: t('design.samples.edit') },
  { id: 'duplicate', label: t('design.samples.duplicate') },
  { id: 'archive', label: t('design.samples.archive'), danger: true },
])

const tabItems = computed(() => [
  { id: 'overview', label: t('design.samples.tabOverview') },
  { id: 'activity', label: t('design.samples.tabActivity') },
  { id: 'notes', label: t('design.samples.tabNotes') },
])

const methods = computed(() => [
  { value: 'cash', label: t('design.samples.cash') },
  { value: 'card', label: t('design.samples.card') },
  { value: 'transfer', label: t('design.samples.transfer') },
])

const rows = computed(() => [
  { customer: 'Maison Laurent', status: 'paid' as const, total: 12840000 },
  { customer: 'Atelier Kivu', status: 'open' as const, total: 4625000 },
])

function onMenu(id: string) {
  const item = menu.value.find((entry) => entry.id === id)
  action.value = item?.label ?? id
}

function notify(tone: 'info' | 'success' | 'warning' | 'danger') {
  const key = tone.charAt(0).toUpperCase() + tone.slice(1)
  push({ tone, title: t(`design.samples.toast${key}`), message: t('design.lead.toasts') })
}
</script>

<template>
  <PageFrame>
    <template #title>{{ t('design.title') }}</template>
    <template #subtitle>{{ t('design.subtitle') }}</template>

    <div class="ds">
      <nav class="ds__nav" :aria-label="t('design.title')">
        <a
          v-for="section in sections"
          :key="section"
          class="ds__link"
          :href="`#ds-${section}`"
        >
          {{ t(`design.sections.${section}`) }}
        </a>
      </nav>

      <div class="ds__main">
        <p class="ui-body ds__principles">{{ t('design.principles') }}</p>

        <section id="ds-colors" class="ds__section">
          <header class="ds__head">
            <h2 class="ui-heading">{{ t('design.sections.colors') }}</h2>
            <p class="ui-body">{{ t('design.lead.colors') }}</p>
          </header>
          <div class="ds-swatches">
            <div v-for="swatch in swatches" :key="swatch.token" class="ds-swatch">
              <span class="ds-swatch__chip" :style="{ background: `var(${swatch.token})` }" />
              <span class="ds-swatch__name">{{ t(`design.swatches.${swatch.name}`) }}</span>
              <span class="ds-swatch__token">{{ swatch.token }}</span>
            </div>
          </div>
        </section>

        <section id="ds-type" class="ds__section">
          <header class="ds__head">
            <h2 class="ui-heading">{{ t('design.sections.type') }}</h2>
            <p class="ui-body">{{ t('design.lead.type') }}</p>
          </header>
          <AppCard>
            <p class="ui-display">{{ t('design.type.display') }}</p>
            <p class="ui-title">{{ t('design.type.title') }}</p>
            <p class="ui-heading">{{ t('design.type.heading') }}</p>
            <p class="ui-body">{{ t('design.type.body') }}</p>
            <p class="ui-caption">{{ t('design.type.caption') }}</p>
          </AppCard>
        </section>

        <section id="ds-space" class="ds__section">
          <header class="ds__head">
            <h2 class="ui-heading">{{ t('design.sections.space') }}</h2>
            <p class="ui-body">{{ t('design.lead.space') }}</p>
          </header>
          <AppCard>
            <div class="ds-space">
              <div v-for="step in steps" :key="step" class="ds-space__row">
                <span class="ds-space__label">{{ step }}</span>
                <span class="ds-space__bar" :style="{ width: `${step * 4}px` }" />
              </div>
            </div>
          </AppCard>
        </section>

        <section id="ds-buttons" class="ds__section">
          <header class="ds__head">
            <h2 class="ui-heading">{{ t('design.sections.buttons') }}</h2>
            <p class="ui-body">{{ t('design.lead.buttons') }}</p>
          </header>
          <AppCard>
            <div class="ui-cluster">
              <AppButton>{{ t('design.samples.primary') }}</AppButton>
              <AppButton variant="secondary">{{ t('design.samples.secondary') }}</AppButton>
              <AppButton variant="ghost">{{ t('design.samples.ghost') }}</AppButton>
              <AppButton variant="danger">{{ t('design.samples.danger') }}</AppButton>
              <AppButton variant="link">{{ t('design.samples.link') }}</AppButton>
              <AppButton loading>{{ t('design.samples.loading') }}</AppButton>
              <AppButton size="sm" variant="secondary">{{ t('design.samples.secondary') }}</AppButton>
            </div>
          </AppCard>
        </section>

        <section id="ds-inputs" class="ds__section">
          <header class="ds__head">
            <h2 class="ui-heading">{{ t('design.sections.inputs') }}</h2>
            <p class="ui-body">{{ t('design.lead.inputs') }}</p>
          </header>
          <AppCard>
            <div class="ds-form">
              <AppField
                v-model="name"
                :label="t('design.samples.name')"
                :hint="t('design.samples.nameHint')"
                :placeholder="t('design.samples.name')"
              />
              <AppField
                model-value="atelier"
                :label="t('design.samples.email')"
                :error="t('design.samples.invalid')"
                type="email"
              />
              <AppField
                v-model="method"
                :label="t('design.samples.method')"
                :options="methods"
              />
              <AppField
                v-model="note"
                :label="t('design.samples.note')"
                type="textarea"
              />
            </div>
          </AppCard>
        </section>

        <section id="ds-tables" class="ds__section">
          <header class="ds__head">
            <h2 class="ui-heading">{{ t('design.sections.tables') }}</h2>
            <p class="ui-body">{{ t('design.lead.tables') }}</p>
          </header>
          <DataTableShell :title="t('design.samples.cardTitle')" :meta="t('design.lead.tables')">
            <table class="ui-table">
              <thead>
                <tr>
                  <th>{{ t('design.samples.colCustomer') }}</th>
                  <th>{{ t('design.samples.colStatus') }}</th>
                  <th class="num">{{ t('design.samples.colTotal') }}</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="row in rows" :key="row.customer">
                  <td class="font-medium">{{ row.customer }}</td>
                  <td>
                    <Badge :variant="row.status === 'paid' ? 'success' : 'warning'" dot>
                      {{ t(`design.samples.${row.status}`) }}
                    </Badge>
                  </td>
                  <td class="num">{{ formatMoney(row.total) }}</td>
                </tr>
              </tbody>
            </table>
          </DataTableShell>
        </section>

        <section id="ds-cards" class="ds__section">
          <header class="ds__head">
            <h2 class="ui-heading">{{ t('design.sections.cards') }}</h2>
            <p class="ui-body">{{ t('design.lead.cards') }}</p>
          </header>
          <div class="ds-cards">
            <KpiCard :label="t('design.samples.kpiSales')" :value="formatMoney(18420000)" icon="sales" delta="+8%" delta-tone="up" />
            <KpiCard :label="t('design.samples.kpiOrders')" value="46" icon="receipt" accent="var(--color-accent)" icon-bg="var(--color-accent-soft)" />
            <AppCard :title="t('design.samples.cardTitle')" :description="t('design.samples.cardBody')" />
          </div>
        </section>

        <section id="ds-badges" class="ds__section">
          <header class="ds__head">
            <h2 class="ui-heading">{{ t('design.sections.badges') }}</h2>
            <p class="ui-body">{{ t('design.lead.badges') }}</p>
          </header>
          <AppCard>
            <div class="ui-cluster">
              <Badge variant="neutral">{{ t('design.swatches.muted') }}</Badge>
              <Badge variant="brand" dot>{{ t('design.swatches.navy') }}</Badge>
              <Badge variant="success" dot>{{ t('design.samples.paid') }}</Badge>
              <Badge variant="warning" dot>{{ t('design.samples.open') }}</Badge>
              <Badge variant="danger" dot>{{ t('design.swatches.danger') }}</Badge>
              <Badge variant="info" dot>{{ t('design.swatches.info') }}</Badge>
            </div>
          </AppCard>
        </section>

        <section id="ds-dropdowns" class="ds__section">
          <header class="ds__head">
            <h2 class="ui-heading">{{ t('design.sections.dropdowns') }}</h2>
            <p class="ui-body">{{ t('design.lead.dropdowns') }}</p>
          </header>
          <AppCard>
            <div class="ui-stack">
              <AppDropdown :label="t('design.samples.openMenu')" :items="menu" @select="onMenu" />
              <p v-if="action" class="ui-caption">{{ t('design.samples.selected', { action }) }}</p>
            </div>
          </AppCard>
        </section>

        <section id="ds-modals" class="ds__section">
          <header class="ds__head">
            <h2 class="ui-heading">{{ t('design.sections.modals') }}</h2>
            <p class="ui-body">{{ t('design.lead.modals') }}</p>
          </header>
          <AppCard>
            <AppButton variant="secondary" @click="modalOpen = true">{{ t('design.samples.openModal') }}</AppButton>
          </AppCard>
          <AppModal
            :open="modalOpen"
            :title="t('design.samples.modalTitle')"
            :subtitle="t('design.samples.modalSubtitle')"
            size="md"
            icon="customers"
            presentation="dialog"
            @close="modalOpen = false"
          >
            <AppField v-model="name" :label="t('design.samples.name')" />
            <template #footer>
              <AppButton variant="secondary" @click="modalOpen = false">{{ t('design.samples.secondary') }}</AppButton>
              <AppButton @click="modalOpen = false">{{ t('design.samples.primary') }}</AppButton>
            </template>
          </AppModal>
        </section>

        <section id="ds-drawers" class="ds__section">
          <header class="ds__head">
            <h2 class="ui-heading">{{ t('design.sections.drawers') }}</h2>
            <p class="ui-body">{{ t('design.lead.drawers') }}</p>
          </header>
          <AppCard>
            <AppButton variant="secondary" @click="drawerOpen = true">{{ t('design.samples.openDrawer') }}</AppButton>
          </AppCard>
          <AppDrawer
            :open="drawerOpen"
            :title="t('design.samples.drawerTitle')"
            :subtitle="t('design.samples.drawerSubtitle')"
            icon="customers"
            @close="drawerOpen = false"
          >
            <p class="ui-body">{{ t('design.samples.cardBody') }}</p>
            <template #footer>
              <AppButton variant="secondary" @click="drawerOpen = false">{{ t('common.close') }}</AppButton>
            </template>
          </AppDrawer>
        </section>

        <section id="ds-tabs" class="ds__section">
          <header class="ds__head">
            <h2 class="ui-heading">{{ t('design.sections.tabs') }}</h2>
            <p class="ui-body">{{ t('design.lead.tabs') }}</p>
          </header>
          <AppCard>
            <AppTabs v-model="tab" :tabs="tabItems" :label="t('design.sections.tabs')">
              <p v-if="tab === 'overview'">{{ t('design.samples.tabOverviewBody') }}</p>
              <p v-else-if="tab === 'activity'">{{ t('design.samples.tabActivityBody') }}</p>
              <p v-else>{{ t('design.samples.tabNotesBody') }}</p>
            </AppTabs>
          </AppCard>
        </section>

        <section id="ds-alerts" class="ds__section">
          <header class="ds__head">
            <h2 class="ui-heading">{{ t('design.sections.alerts') }}</h2>
            <p class="ui-body">{{ t('design.lead.alerts') }}</p>
          </header>
          <div class="ui-stack">
            <AppAlert tone="info">{{ t('design.samples.alertInfo') }}</AppAlert>
            <AppAlert tone="success">{{ t('design.samples.alertSuccess') }}</AppAlert>
            <AppAlert v-if="warningVisible" tone="warning" dismissible @dismiss="warningVisible = false">
              {{ t('design.samples.alertWarning') }}
            </AppAlert>
            <AppAlert tone="danger">{{ t('design.samples.alertDanger') }}</AppAlert>
          </div>
        </section>

        <section id="ds-toasts" class="ds__section">
          <header class="ds__head">
            <h2 class="ui-heading">{{ t('design.sections.toasts') }}</h2>
            <p class="ui-body">{{ t('design.lead.toasts') }}</p>
          </header>
          <AppCard>
            <div class="ui-cluster">
              <AppButton variant="secondary" @click="notify('info')">{{ t('design.samples.toastInfo') }}</AppButton>
              <AppButton variant="secondary" @click="notify('success')">{{ t('design.samples.toastSuccess') }}</AppButton>
              <AppButton variant="secondary" @click="notify('warning')">{{ t('design.samples.toastWarning') }}</AppButton>
              <AppButton variant="secondary" @click="notify('danger')">{{ t('design.samples.toastDanger') }}</AppButton>
            </div>
          </AppCard>
        </section>

        <section id="ds-charts" class="ds__section">
          <header class="ds__head">
            <h2 class="ui-heading">{{ t('design.sections.charts') }}</h2>
            <p class="ui-body">{{ t('design.lead.charts') }}</p>
          </header>
          <div class="ds-cards">
            <AppCard :title="t('design.samples.chartCaption')">
              <AppChart variant="bar" :points="revenue" :caption="t('design.samples.chartCaption')" />
            </AppCard>
            <AppCard :title="t('design.samples.chartLine')">
              <AppChart variant="line" :points="covers" :caption="t('design.samples.chartLine')" />
            </AppCard>
          </div>
        </section>

        <section id="ds-empty" class="ds__section">
          <header class="ds__head">
            <h2 class="ui-heading">{{ t('design.sections.empty') }}</h2>
            <p class="ui-body">{{ t('design.lead.empty') }}</p>
          </header>
          <AppCard>
            <EmptyState icon="receipt" :title="t('design.samples.emptyTitle')" :description="t('design.samples.emptyBody')">
              <div class="empty-state__actions">
                <AppButton size="sm">{{ t('design.samples.create') }}</AppButton>
              </div>
            </EmptyState>
          </AppCard>
        </section>

        <section id="ds-loading" class="ds__section">
          <header class="ds__head">
            <h2 class="ui-heading">{{ t('design.sections.loading') }}</h2>
            <p class="ui-body">{{ t('design.lead.loading') }}</p>
          </header>
          <AppCard>
            <AppButton variant="secondary" @click="showLoading = !showLoading">
              {{ showLoading ? t('design.samples.hideLoading') : t('design.samples.showLoading') }}
            </AppButton>
            <AppLoading v-if="showLoading" :label="t('design.samples.loadingLabel')" />
          </AppCard>
        </section>

        <section id="ds-skeletons" class="ds__section">
          <header class="ds__head">
            <h2 class="ui-heading">{{ t('design.sections.skeletons') }}</h2>
            <p class="ui-body">{{ t('design.lead.skeletons') }}</p>
          </header>
          <div class="ds-cards">
            <AppCard :title="t('design.sections.type')">
              <AppSkeleton :lines="4" />
            </AppCard>
            <AppCard>
              <LoadingBlock variant="table" :rows="4" :label="t('common.loading')" />
            </AppCard>
          </div>
        </section>
      </div>
    </div>
  </PageFrame>
</template>

<style scoped>
.ds {
  display: grid;
  grid-template-columns: 196px minmax(0, 1fr);
  gap: var(--space-8);
  align-items: start;
}

.ds__nav {
  position: sticky;
  top: 0;
  display: flex;
  flex-direction: column;
  gap: 2px;
  max-height: calc(100vh - var(--topbar-height) - var(--space-8));
  overflow: auto;
  padding: var(--space-1) 0;
}

.ds__link {
  padding: 7px 10px;
  border-radius: var(--radius-sm);
  color: var(--color-text-muted);
  font-size: 13px;
  font-weight: 600;
  line-height: 18px;
  text-decoration: none;
}

.ds__link:hover {
  background: var(--color-table-row-hover);
  color: var(--color-text-primary);
}

.ds__main {
  min-width: 0;
  max-width: 920px;
}

.ds__principles {
  margin: 0 0 var(--space-8);
  max-width: 38rem;
}

.ds__section {
  display: flex;
  flex-direction: column;
  gap: var(--space-4);
  padding-bottom: var(--space-9);
  scroll-margin-top: var(--space-4);
}

.ds__head {
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
}

.ds__head .ui-body {
  margin: 0;
  max-width: 38rem;
}

.ds-swatches {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(148px, 1fr));
  gap: var(--space-3);
}

.ds-swatch {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.ds-swatch__chip {
  height: 52px;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
}

.ds-swatch__name {
  font-size: 13px;
  font-weight: 600;
  color: var(--color-text-primary);
}

.ds-swatch__token {
  font-size: 12px;
  color: var(--color-text-muted);
}

.ds-space {
  display: flex;
  flex-direction: column;
  gap: var(--space-3);
}

.ds-space__row {
  display: grid;
  grid-template-columns: 36px minmax(0, 1fr);
  align-items: center;
  gap: var(--space-3);
}

.ds-space__label {
  font-size: 12px;
  font-weight: 600;
  font-variant-numeric: tabular-nums;
  color: var(--color-text-muted);
}

.ds-space__bar {
  height: 8px;
  max-width: 100%;
  border-radius: 999px;
  background: var(--color-brand-600);
}

.ds-form {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0 var(--space-4);
}

.ds-form :deep(.ui-field:last-child) {
  grid-column: 1 / -1;
}

.ds-cards {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: var(--space-4);
}

.ds-cards > :last-child:nth-child(odd) {
  grid-column: 1 / -1;
}

.ui-display,
.ui-title,
.ui-heading,
.ui-body,
.ui-caption {
  margin: 0;
}

.ui-display + .ui-title,
.ui-title + .ui-heading,
.ui-heading + .ui-body,
.ui-body + .ui-caption {
  margin-top: var(--space-3);
}

@media (max-width: 900px) {
  .ds {
    grid-template-columns: 1fr;
    gap: var(--space-4);
  }

  .ds__nav {
    position: sticky;
    top: 0;
    z-index: 2;
    flex-direction: row;
    max-height: none;
    gap: var(--space-1);
    overflow-x: auto;
    padding: var(--space-2) 0;
    background: var(--color-canvas);
  }

  .ds__link {
    flex: 0 0 auto;
  }

  .ds-form,
  .ds-cards {
    grid-template-columns: 1fr;
  }
}
</style>
