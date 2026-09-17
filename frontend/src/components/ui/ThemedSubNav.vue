<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import SubNav from './SubNav.vue'

export type ThemeTab = { to: string; label: string }
export type ThemeGroup = { label: string; tabs: ThemeTab[] }

const props = withDefaults(defineProps<{
  groups: ThemeGroup[]
  /** Custom path matcher (e.g. catalog products). */
  matchPath?: (path: string, routePath: string) => boolean
}>(), {
  matchPath: undefined,
})

const route = useRoute()

function isPathActive(path: string) {
  if (props.matchPath) return props.matchPath(path, route.path)
  return route.path === path || route.path.startsWith(`${path}/`)
}

function matchScore(path: string) {
  if (!isPathActive(path)) return -1
  return path.length
}

const activeGroup = computed(() => {
  let best: { group: ThemeGroup; score: number } | null = null
  for (const group of props.groups) {
    for (const item of group.tabs) {
      const score = matchScore(item.to)
      if (score > (best?.score ?? -1)) best = { group, score }
    }
  }
  return best?.group ?? props.groups[0] ?? null
})

const themeTabs = computed(() =>
  props.groups.map(group => ({
    to: group.tabs[0]?.to ?? '/',
    label: group.label,
    active: group === activeGroup.value,
  })),
)

const linkTabs = computed(() => {
  const group = activeGroup.value
  if (!group) return []
  let bestTo = ''
  let bestScore = -1
  for (const item of group.tabs) {
    const score = matchScore(item.to)
    if (score > bestScore) {
      bestScore = score
      bestTo = item.to
    }
  }
  return group.tabs.map(item => ({
    to: item.to,
    label: item.label,
    active: item.to === bestTo,
  }))
})

const showLinks = computed(() => linkTabs.value.length > 1)
</script>

<template>
  <div class="themed-sub-nav">
    <SubNav :tabs="themeTabs" />
    <SubNav v-if="showLinks" :tabs="linkTabs" variant="secondary" />
  </div>
</template>

<style scoped>
.themed-sub-nav {
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
  margin-bottom: var(--space-5);
}

.themed-sub-nav :deep(.sub-nav) {
  margin-bottom: 0;
}

.themed-sub-nav :deep(.sub-nav--secondary) {
  margin-top: 0;
  margin-bottom: 0;
}
</style>
