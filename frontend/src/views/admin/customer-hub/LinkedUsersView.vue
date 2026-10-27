<script setup lang="ts">
import { computed, ref } from 'vue'
import CountUp from '../../../components/motion/CountUp.vue'
import { useI18n } from 'vue-i18n'
import PageFrame from '../../../components/layout/PageFrame.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'

type LinkKind = 'employee' | 'supplier' | 'customer'

type LinkedUser = {
  id: string
  name: string
  email: string
  kind: LinkKind
}

const kinds: LinkKind[] = ['employee', 'supplier', 'customer']

const { t } = useI18n()
const query = ref('')
const kind = ref<LinkKind | ''>('')
const refreshing = ref(false)
const users = ref<LinkedUser[]>([])

const counts = computed(() => ({
  all: users.value.length,
  employee: users.value.filter(user => user.kind === 'employee').length,
  supplier: users.value.filter(user => user.kind === 'supplier').length,
  customer: users.value.filter(user => user.kind === 'customer').length,
}))

const tabs = computed(() => [
  { key: '' as const, label: t('linkedUsersPage.all'), count: counts.value.all },
  ...kinds.map(key => ({
    key,
    label: t(`linkedUsersPage.${key}`),
    count: counts.value[key],
  })),
])

const visible = computed(() => {
  const q = query.value.trim().toLowerCase()
  return users.value.filter(user => {
    if (kind.value && user.kind !== kind.value) return false
    if (!q) return true
    return user.name.toLowerCase().includes(q) || user.email.toLowerCase().includes(q)
  })
})

function selectKind(next: LinkKind | '') {
  kind.value = kind.value === next ? '' : next
}

function initials(name: string) {
  return name
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map(part => part[0]?.toUpperCase() ?? '')
    .join('')
}

function refresh() {
  if (refreshing.value) return
  refreshing.value = true
  query.value = ''
  kind.value = ''
  window.setTimeout(() => {
    users.value = []
    refreshing.value = false
  }, 280)
}
</script>

<template>
  <PageFrame>
    <template #title>{{ t('linkedUsersPage.title') }}</template>
    <template #subtitle>{{ t('linkedUsersPage.subtitle') }}</template>

    <div class="links" :class="{ 'is-refreshing': refreshing }" :aria-busy="refreshing">
      <section class="stage" :aria-label="t('linkedUsersPage.type')">
        <article class="spot">
          <div class="spot__top">
            <button type="button" class="spot__pick" @click="selectKind('')">{{ t('linkedUsersPage.all') }}</button>
            <button type="button" class="spot__refresh" :disabled="refreshing" @click="refresh">
              <AppIcon name="refresh" :size="15" :class="{ 'is-spin': refreshing }" />
              {{ t('linkedUsersPage.refresh') }}
            </button>
          </div>
          <button type="button" class="spot__body" @click="selectKind('')">
            <span class="spot__amount"><CountUp :value="counts.all" /></span>
            <span class="spot__hint">{{ t('linkedUsersPage.subtitle') }}</span>
          </button>
        </article>

        <div class="tiles" role="tablist">
          <button
            v-for="tab in tabs.filter(item => item.key)"
            :key="tab.key"
            type="button"
            role="tab"
            class="tile"
            :class="{ 'is-on': kind === tab.key }"
            :aria-selected="kind === tab.key"
            @click="selectKind(tab.key)"
          >
            <span class="tile__value"><CountUp :value="tab.count" /></span>
            <span class="tile__label">{{ tab.label }}</span>
          </button>
        </div>
      </section>

      <section class="panel">
        <label class="search">
          <span class="sr-only">{{ t('linkedUsersPage.search') }}</span>
          <AppIcon name="search" :size="15" class="search__icon" />
          <input
            v-model="query"
            class="field search__input"
            type="search"
            :placeholder="t('linkedUsersPage.search')"
          />
        </label>

        <p v-if="!visible.length" class="empty">
          <AppIcon name="customers" :size="20" />
          <span>{{ t('linkedUsersPage.empty') }}</span>
        </p>

        <ul v-else class="rows">
          <li v-for="user in visible" :key="user.id" class="row">
            <span class="mark" aria-hidden="true">{{ initials(user.name) }}</span>
            <div class="who">
              <p class="name">{{ user.name }}</p>
              <p class="email">{{ user.email }}</p>
            </div>
            <span class="kind">{{ t(`linkedUsersPage.${user.kind}`) }}</span>
          </li>
        </ul>
      </section>
    </div>
  </PageFrame>
</template>

<style scoped>
.links {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  min-width: 0;
}
.links.is-refreshing { opacity: 0.72; }

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
.spot__refresh :deep(.is-spin) { animation: link-spin 0.7s linear infinite; }
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
  grid-template-columns: repeat(3, minmax(0, 1fr));
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

.rows { list-style: none; margin: 0.55rem 0 0; padding: 0; }
.row {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr) auto;
  gap: 0.85rem;
  align-items: center;
  padding: 0.75rem 0.15rem;
  border-top: 1px solid var(--color-border);
}
.mark {
  display: grid;
  place-items: center;
  width: 2.15rem;
  height: 2.15rem;
  border-radius: 10px;
  background: var(--color-canvas);
  font-size: 0.72rem;
  font-weight: 700;
}
.who { min-width: 0; }
.name, .email { margin: 0; }
.name { font-weight: 700; letter-spacing: -0.02em; }
.email { margin-top: 0.1rem; color: var(--color-text-muted); font-size: 0.78rem; }
.kind { font-size: 0.8rem; font-weight: 650; color: var(--color-text-secondary); }

@keyframes link-spin { to { transform: rotate(-360deg); } }

@media (max-width: 980px) {
  .stage, .tiles { grid-template-columns: 1fr 1fr; }
  .spot { grid-column: 1 / -1; }
}
@media (max-width: 720px) {
  .stage, .tiles, .row { grid-template-columns: 1fr; }
  .mark { display: none; }
}
</style>
