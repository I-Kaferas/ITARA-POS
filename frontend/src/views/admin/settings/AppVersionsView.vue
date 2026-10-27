<script setup lang="ts">
import { computed, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import PageFrame from '../../../components/layout/PageFrame.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import Badge from '../../../components/ui/Badge.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import DataTableShell from '../../../components/ui/DataTableShell.vue'

type Platform = 'android' | 'desktop'

type ReleaseFile = {
  name: string
  size: string
  date: string
}

type AppRelease = {
  id: string
  nameKey: string
  version: string
  build: string
  platform: Platform
  releasedOn: string
  size: string | null
  minOs: string | null
  files: ReleaseFile[]
}

const desktopFiles: ReleaseFile[] = [
  { name: 'itara-v2.0.3.zip', size: '18.38 MB', date: '2026-06-04' },
  { name: 'itara-v.2.0.2.zip', size: '18.38 MB', date: '2026-06-04' },
  { name: 'itara-v1.0.9.zip', size: '18.35 MB', date: '2026-06-01' },
  { name: 'itara-v1.0.7.zip', size: '18.29 MB', date: '2026-05-28' },
  { name: 'itara-v1.0.6.zip', size: '18.28 MB', date: '2026-05-23' },
  { name: 'itara-v1.0.5.zip', size: '18.27 MB', date: '2026-05-22' },
  { name: 'itara-v1.0.4.zip', size: '18.22 MB', date: '2026-05-21' },
  { name: 'itara-v1.0.2.zip', size: '18.22 MB', date: '2026-05-21' },
  { name: 'itara.zip', size: '18.17 MB', date: '2026-05-15' },
]

const releases: AppRelease[] = [
  {
    id: 'android-1.0.1-1',
    nameKey: 'appVersions.firstRelease',
    version: '1.0.1',
    build: '1',
    platform: 'android',
    releasedOn: '2026-05-21',
    size: null,
    minOs: null,
    files: [],
  },
  {
    id: 'desktop-1.0.1-91271',
    nameKey: 'appVersions.firstRelease',
    version: '1.0.1',
    build: '91271',
    platform: 'desktop',
    releasedOn: '2026-05-15',
    size: '18.17 MB',
    minOs: '64bit',
    files: desktopFiles,
  },
]

const { t, locale } = useI18n()
const query = ref('')
const platform = ref<'all' | Platform>('all')
const refreshing = ref(false)
const selected = ref<AppRelease | null>(null)

const platforms: Platform[] = ['android', 'desktop']

const latest = computed(() =>
  platforms
    .map((item) => releases.find((release) => release.platform === item))
    .filter((release): release is AppRelease => Boolean(release)),
)

const filtered = computed(() => {
  const q = query.value.trim().toLowerCase()
  return releases.filter((item) => {
    if (platform.value !== 'all' && item.platform !== platform.value) return false
    if (!q) return true
    const haystack = [
      t(item.nameKey),
      item.version,
      item.build,
      item.platform,
      t(`appVersions.platforms.${item.platform}`),
      t('appVersions.released'),
      t('appVersions.active'),
    ].join(' ').toLowerCase()
    return haystack.includes(q)
  })
})

function formatDate(value: string) {
  return new Intl.DateTimeFormat(locale.value, {
    month: 'numeric',
    day: 'numeric',
    year: 'numeric',
  }).format(new Date(`${value}T00:00:00`))
}

function platformIcon(item: Platform) {
  return item === 'android' ? 'device-tablet' : 'device-pos'
}

function pickPlatform(value: 'all' | Platform) {
  platform.value = value
}

function refresh() {
  if (refreshing.value) return
  refreshing.value = true
  window.setTimeout(() => {
    refreshing.value = false
  }, 350)
}
</script>

<template>
  <PageFrame>
    <template #title>{{ t('nav.settingsItems.appVersions') }}</template>
    <template #subtitle>{{ t('appVersions.subtitle') }}</template>

    <div class="versions">
      <div class="versions__cards">
        <button
          v-for="item in latest"
          :key="item.id"
          type="button"
          class="versions__card"
          :class="[`versions__card--${item.platform}`, { 'is-on': platform === item.platform }]"
          @click="pickPlatform(platform === item.platform ? 'all' : item.platform)"
        >
          <span class="versions__mark">
            <AppIcon :name="platformIcon(item.platform)" :size="18" />
          </span>
          <span class="versions__card-copy">
            <span class="versions__kicker">{{ t(`appVersions.platforms.${item.platform}`) }}</span>
            <span class="versions__version">v{{ item.version }}</span>
            <span class="versions__meta">
              {{ t('appVersions.build', { n: item.build }) }}
              · {{ formatDate(item.releasedOn) }}
              · {{ item.size ?? t('appVersions.na') }}
            </span>
          </span>
          <Badge variant="success" dot>{{ t('appVersions.active') }}</Badge>
        </button>
      </div>

      <div class="versions__toolbar">
        <div class="versions__tabs" role="tablist">
          <button
            type="button"
            class="versions__tab"
            :class="{ 'is-on': platform === 'all' }"
            @click="pickPlatform('all')"
          >
            {{ t('appVersions.all') }}
          </button>
          <button
            v-for="item in platforms"
            :key="item"
            type="button"
            class="versions__tab"
            :class="{ 'is-on': platform === item }"
            @click="pickPlatform(item)"
          >
            {{ t(`appVersions.platforms.${item}`) }}
          </button>
        </div>

        <label class="versions__search">
          <span class="sr-only">{{ t('appVersions.search') }}</span>
          <AppIcon name="search" :size="16" class="versions__search-icon" />
          <input
            v-model="query"
            class="field versions__search-input"
            type="search"
            :placeholder="t('appVersions.searchPlaceholder')"
          />
        </label>

        <button type="button" class="btn-secondary versions__refresh" :disabled="refreshing" @click="refresh">
          <AppIcon name="refresh" :size="16" />
          {{ t('appVersions.refresh') }}
        </button>
      </div>

      <DataTableShell
        :title="t('appVersions.count', { n: filtered.length })"
        :loading="refreshing"
        :empty="!filtered.length"
        :empty-title="t('appVersions.empty')"
        empty-icon="device-tablet"
      >
        <table class="ui-table">
          <thead>
            <tr>
              <th>{{ t('appVersions.columns.version') }}</th>
              <th>{{ t('appVersions.columns.platform') }}</th>
              <th>{{ t('appVersions.columns.status') }}</th>
              <th>{{ t('appVersions.columns.releaseDate') }}</th>
              <th>{{ t('appVersions.columns.size') }}</th>
              <th>{{ t('appVersions.files') }}</th>
              <th class="num">{{ t('appVersions.columns.actions') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="item in filtered" :key="item.id" class="versions__row" @click="selected = item">
              <td>
                <div class="versions__name">{{ t(item.nameKey) }}</div>
                <div class="versions__build">
                  v{{ item.version }} · {{ t('appVersions.build', { n: item.build }) }}
                </div>
              </td>
              <td>
                <span class="versions__platform">
                  <AppIcon :name="platformIcon(item.platform)" :size="14" />
                  {{ t(`appVersions.platforms.${item.platform}`) }}
                </span>
              </td>
              <td>
                <Badge variant="success" dot>{{ t('appVersions.released') }}</Badge>
              </td>
              <td>{{ formatDate(item.releasedOn) }}</td>
              <td class="versions__size">{{ item.size ?? t('appVersions.na') }}</td>
              <td>{{ item.files.length }}</td>
              <td class="num" @click.stop>
                <button type="button" class="btn-secondary versions__view" @click="selected = item">
                  <AppIcon name="eye" :size="16" />
                  {{ t('appVersions.view') }}
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </DataTableShell>
    </div>

    <AppModal
      :open="selected !== null"
      :title="selected ? t(selected.nameKey) : ''"
      :subtitle="selected ? t('appVersions.versionLine', { version: selected.version, build: selected.build }) : ''"
      icon="device-tablet"
      tone="accent"
      size="md"
      @close="selected = null"
    >
      <div v-if="selected" class="versions-detail">
        <div class="versions-detail__badges">
          <Badge variant="neutral">{{ t(`appVersions.platforms.${selected.platform}`) }}</Badge>
          <Badge variant="success" dot>{{ t('appVersions.released') }}</Badge>
          <Badge variant="success" dot>{{ t('appVersions.active') }}</Badge>
        </div>

        <dl class="versions-detail__facts">
          <div>
            <dt>{{ t('appVersions.columns.releaseDate') }}</dt>
            <dd>{{ formatDate(selected.releasedOn) }}</dd>
          </div>
          <div>
            <dt>{{ t('appVersions.columns.size') }}</dt>
            <dd>{{ selected.size ?? t('appVersions.na') }}</dd>
          </div>
          <div>
            <dt>{{ t('appVersions.minOs') }}</dt>
            <dd>{{ selected.minOs ?? t('appVersions.na') }}</dd>
          </div>
        </dl>

        <section class="versions-detail__section">
          <h4>{{ t('appVersions.files') }}</h4>
          <p v-if="!selected.files.length" class="versions-detail__empty">{{ t('appVersions.na') }}</p>
          <ul v-else class="versions-detail__files">
            <li v-for="file in selected.files" :key="file.name">
              <AppIcon name="package" :size="16" />
              <span class="versions-detail__file">{{ file.name }}</span>
              <span class="versions-detail__meta">{{ file.size }}</span>
              <span class="versions-detail__meta">{{ formatDate(file.date) }}</span>
            </li>
          </ul>
        </section>
      </div>
    </AppModal>
  </PageFrame>
</template>

<style scoped>
.versions {
  display: flex;
  flex-direction: column;
  gap: var(--space-4);
}

.versions__cards {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: var(--space-3);
}

.versions__card {
  display: flex;
  align-items: center;
  gap: var(--space-4);
  width: 100%;
  padding: var(--space-4);
  border: 1px solid var(--color-border);
  border-radius: 0;
  background: var(--color-surface);
  color: inherit;
  text-align: left;
  cursor: pointer;
}

.versions__card--android {
  border-left: 4px solid var(--color-brand-700);
}

.versions__card--desktop {
  border-left: 4px solid var(--color-accent);
}

.versions__card.is-on {
  border-color: var(--color-brand-700);
  background: var(--color-surface-muted);
}

.versions__card:hover {
  border-color: var(--color-brand-700);
}

.versions__card:focus-visible {
  outline: 2px solid var(--color-brand-700);
  outline-offset: 2px;
}

.versions__mark {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 40px;
  height: 40px;
  flex-shrink: 0;
  background: var(--color-brand-700);
  color: #fff;
}

.versions__card--desktop .versions__mark {
  background: var(--color-accent);
  color: var(--color-brand-900);
}

.versions__card-copy {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 2px;
}

.versions__kicker {
  font-size: var(--text-xs);
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--color-text-muted);
}

.versions__version {
  font-size: 1.25rem;
  font-weight: 650;
  letter-spacing: -0.02em;
  color: var(--color-text-primary);
}

.versions__meta,
.versions__build {
  font-size: var(--text-xs);
  color: var(--color-text-muted);
}

.versions__name {
  font-weight: 650;
  color: var(--color-text-primary);
}

.versions__toolbar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-3);
}

.versions__tabs {
  display: flex;
  flex-wrap: wrap;
  gap: 0;
  border: 1px solid var(--color-border-strong);
  background: var(--color-surface);
}

.versions__tab {
  min-height: 2.5rem;
  padding: 0.35rem 0.9rem;
  border: 0;
  border-right: 1px solid var(--color-border);
  background: transparent;
  color: var(--color-text-secondary);
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
}

.versions__tab:last-child {
  border-right: 0;
}

.versions__tab.is-on {
  background: var(--color-brand-700);
  color: #fff;
}

.versions__tab:focus-visible {
  outline: 2px solid var(--color-brand-700);
  outline-offset: -2px;
}

.versions__search {
  position: relative;
  flex: 1;
  min-width: min(100%, 16rem);
}

.versions__search-icon {
  position: absolute;
  top: 50%;
  left: 0.75rem;
  color: var(--color-text-muted);
  transform: translateY(-50%);
  pointer-events: none;
}

.versions__search-input {
  width: 100%;
  padding-left: 2.25rem;
  border-radius: 0;
}

.versions__refresh,
.versions__view {
  border-radius: 0;
}

.versions__row {
  cursor: pointer;
}

.versions__platform {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  font-weight: 600;
}

.versions__size {
  font-variant-numeric: tabular-nums;
}

.versions-detail {
  display: flex;
  flex-direction: column;
  gap: var(--space-5);
}

.versions-detail__badges {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
}

.versions-detail__facts {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: var(--space-3);
  margin: 0;
}

.versions-detail__facts div {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
  padding: var(--space-3);
  border: 1px solid var(--color-border);
  background: var(--color-surface);
}

.versions-detail__facts dt {
  margin: 0;
  font-size: var(--text-xs);
  color: var(--color-text-muted);
}

.versions-detail__facts dd {
  margin: 0;
  font-size: var(--text-sm);
  font-weight: 650;
  color: var(--color-text-primary);
}

.versions-detail__section h4 {
  margin: 0 0 var(--space-3);
  font-size: var(--text-xs);
  font-weight: 650;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--color-text-muted);
}

.versions-detail__empty {
  margin: 0;
  color: var(--color-text-muted);
}

.versions-detail__files {
  display: flex;
  flex-direction: column;
  margin: 0;
  padding: 0;
  list-style: none;
  border: 1px solid var(--color-border);
  background: var(--color-surface);
}

.versions-detail__files li {
  display: grid;
  grid-template-columns: 1.25rem minmax(0, 1fr) auto auto;
  align-items: center;
  gap: var(--space-3);
  padding: 0.7rem 0.85rem;
  border-bottom: 1px solid var(--color-border);
  color: var(--color-text-muted);
}

.versions-detail__files li:last-child {
  border-bottom: 0;
}

.versions-detail__file {
  overflow: hidden;
  font-size: var(--text-sm);
  font-weight: 600;
  color: var(--color-text-primary);
  text-overflow: ellipsis;
  white-space: nowrap;
}

.versions-detail__meta {
  font-size: var(--text-xs);
  font-variant-numeric: tabular-nums;
  color: var(--color-text-muted);
}

@media (max-width: 800px) {
  .versions__cards,
  .versions-detail__facts {
    grid-template-columns: 1fr;
  }

  .versions-detail__files li {
    grid-template-columns: 1.25rem minmax(0, 1fr);
  }
}
</style>
