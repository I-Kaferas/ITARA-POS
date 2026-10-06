<script setup lang="ts">
import { computed, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import PageFrame from '../../../components/layout/PageFrame.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import Badge from '../../../components/ui/Badge.vue'
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
      <div class="versions__toolbar">
        <button type="button" class="btn-secondary" :disabled="refreshing" @click="refresh">
          {{ t('appVersions.refresh') }}
        </button>
        <label class="versions__field">
          <span>{{ t('appVersions.platform') }}</span>
          <select v-model="platform" class="field">
            <option value="all">{{ t('appVersions.allPlatforms') }}</option>
            <option v-for="item in platforms" :key="item" :value="item">
              {{ t(`appVersions.platforms.${item}`) }}
            </option>
          </select>
        </label>
        <label class="versions__search">
          <span class="sr-only">{{ t('appVersions.search') }}</span>
          <input
            v-model="query"
            class="field"
            type="search"
            :placeholder="t('appVersions.searchPlaceholder')"
          />
        </label>
      </div>

      <p class="versions__count">{{ t('appVersions.count', { n: filtered.length }) }}</p>

      <DataTableShell
        :loading="refreshing"
        :empty="!filtered.length"
        :empty-title="t('appVersions.empty')"
        empty-icon="device-tablet"
      >
        <table class="ui-table versions__table">
          <thead>
            <tr>
              <th>{{ t('appVersions.columns.version') }}</th>
              <th>{{ t('appVersions.columns.platform') }}</th>
              <th>{{ t('appVersions.columns.status') }}</th>
              <th>{{ t('appVersions.columns.active') }}</th>
              <th>{{ t('appVersions.columns.releaseDate') }}</th>
              <th>{{ t('appVersions.columns.size') }}</th>
              <th>{{ t('appVersions.columns.actions') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="item in filtered" :key="item.id">
              <td>
                <div class="versions__name">{{ t(item.nameKey) }}</div>
                <div class="versions__build">
                  v{{ item.version }} • {{ t('appVersions.build', { n: item.build }) }}
                </div>
              </td>
              <td>
                <Badge variant="neutral">{{ t(`appVersions.platforms.${item.platform}`) }}</Badge>
              </td>
              <td>
                <Badge variant="success" dot>{{ t('appVersions.released') }}</Badge>
              </td>
              <td>
                <Badge variant="success" dot>{{ t('appVersions.active') }}</Badge>
              </td>
              <td>{{ formatDate(item.releasedOn) }}</td>
              <td>{{ item.size ?? t('appVersions.na') }}</td>
              <td>
                <button type="button" class="btn-secondary versions__view" @click="selected = item">
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
      size="lg"
      @close="selected = null"
    >
      <div v-if="selected" class="versions-detail">
        <div class="versions-detail__badges">
          <Badge variant="success" dot>{{ t('appVersions.released') }}</Badge>
          <Badge variant="success" dot>{{ t('appVersions.active') }}</Badge>
        </div>

        <section class="versions-detail__section">
          <h4>{{ t('appVersions.details') }}</h4>
          <dl>
            <div>
              <dt>{{ t('appVersions.platform') }}</dt>
              <dd>{{ t(`appVersions.platforms.${selected.platform}`) }}</dd>
            </div>
            <div>
              <dt>{{ t('appVersions.columns.releaseDate') }}</dt>
              <dd>{{ formatDate(selected.releasedOn) }}</dd>
            </div>
            <div>
              <dt>{{ t('appVersions.minOs') }}</dt>
              <dd>{{ selected.minOs ?? t('appVersions.na') }}</dd>
            </div>
          </dl>
        </section>

        <section v-if="selected.files.length" class="versions-detail__section">
          <h4>{{ t('appVersions.files') }}</h4>
          <ul class="versions-detail__files">
            <li v-for="file in selected.files" :key="file.name">
              <span class="versions-detail__file">{{ file.name }}</span>
              <span class="versions-detail__meta">{{ file.size }} · {{ formatDate(file.date) }}</span>
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

.versions__toolbar {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-end;
  gap: var(--space-3);
}

.versions__field,
.versions__search {
  display: flex;
  flex-direction: column;
  gap: var(--label-gap);
  min-width: 0;
  font-size: var(--text-xs);
  font-weight: 600;
  color: var(--color-text-secondary);
}

.versions__field .field,
.versions__search .field {
  min-width: 14rem;
}

.versions__search {
  flex: 1;
}

.versions__search .field {
  width: 100%;
  min-width: 16rem;
}

.versions__count {
  margin: 0;
  font-size: var(--text-sm);
  font-weight: 600;
  color: var(--color-text-secondary);
}

.versions__table td {
  height: auto;
  padding-top: var(--space-3);
  padding-bottom: var(--space-3);
}

.versions__name {
  font-weight: 600;
  color: var(--color-text-primary);
}

.versions__build {
  margin-top: 2px;
  font-size: var(--text-xs);
  color: var(--color-text-muted);
}

.versions__view {
  min-height: var(--control-md);
  padding-inline: var(--space-3);
}

.versions-detail {
  display: flex;
  flex-direction: column;
  gap: var(--space-6);
}

.versions-detail__badges {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
}

.versions-detail__section h4 {
  margin: 0 0 var(--space-3);
  font-size: var(--text-sm);
  font-weight: 600;
  color: var(--color-text-primary);
}

.versions-detail__section dl {
  display: grid;
  gap: var(--space-3);
  margin: 0;
}

.versions-detail__section dl div {
  display: grid;
  grid-template-columns: 9rem 1fr;
  gap: var(--space-3);
  align-items: baseline;
}

.versions-detail__section dt {
  margin: 0;
  font-size: var(--text-sm);
  color: var(--color-text-muted);
}

.versions-detail__section dd {
  margin: 0;
  font-size: var(--text-sm);
  font-weight: 600;
  color: var(--color-text-primary);
}

.versions-detail__files {
  display: flex;
  flex-direction: column;
  gap: var(--space-3);
  margin: 0;
  padding: 0;
  list-style: none;
}

.versions-detail__files li {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding-bottom: var(--space-3);
  border-bottom: 1px solid var(--color-border);
}

.versions-detail__files li:last-child {
  padding-bottom: 0;
  border-bottom: 0;
}

.versions-detail__file {
  font-size: var(--text-sm);
  font-weight: 600;
  color: var(--color-text-primary);
}

.versions-detail__meta {
  font-size: var(--text-xs);
  color: var(--color-text-muted);
}
</style>
