<script setup lang="ts">
import { Bell, Menu, Moon, Settings, Store, Sun } from 'lucide-vue-next'

defineProps<{
  isDark: boolean
  filtersOpen: boolean
}>()

const emit = defineEmits<{
  toggleDark: []
  toggleFilters: []
}>()
</script>

<template>
  <header
    class="sticky top-0 z-20 border-b border-border bg-white/80 py-3 backdrop-blur-md dark:border-slate-800 dark:bg-slate-950/80"
  >
    <div class="mx-auto flex max-w-[1600px] items-center justify-between px-4 sm:px-6 lg:px-8">
      <div class="flex items-center gap-3">
        <div
          class="gradient-brand flex h-9 w-9 shrink-0 items-center justify-center rounded-xl shadow-md shadow-brand-500/20"
        >
          <Store class="h-4 w-4 text-white" :stroke-width="2" />
        </div>
        <div>
          <h1 class="text-base font-bold tracking-tight text-ink sm:text-lg">ITARA NEXUS</h1>
          <p class="hidden text-xs text-muted sm:block">POS Analytics Dashboard</p>
        </div>
      </div>

      <div class="flex items-center gap-2">
        <button
          type="button"
          class="hidden h-9 w-9 items-center justify-center rounded-lg p-2 text-muted hover:bg-slate-100 dark:hover:bg-slate-800 sm:inline-flex"
          aria-label="Notifications"
        >
          <Bell class="h-4 w-4" />
        </button>
        <button
          type="button"
          class="hidden h-9 w-9 items-center justify-center rounded-lg p-2 text-muted hover:bg-slate-100 dark:hover:bg-slate-800 sm:inline-flex"
          aria-label="Settings"
        >
          <Settings class="h-4 w-4" />
        </button>
        <button
          type="button"
          class="inline-flex h-9 w-9 items-center justify-center rounded-lg border border-border p-2 text-muted hover:bg-slate-100 dark:hover:bg-slate-800"
          :aria-label="isDark ? 'Switch to light mode' : 'Switch to dark mode'"
          @click="emit('toggleDark')"
        >
          <Sun v-if="isDark" class="h-4 w-4" />
          <Moon v-else class="h-4 w-4" />
        </button>
        <button
          type="button"
          class="inline-flex h-9 w-9 items-center justify-center rounded-lg border border-border p-2 text-muted hover:bg-slate-100 dark:hover:bg-slate-800 sm:hidden"
          aria-label="Toggle filters"
          @click="emit('toggleFilters')"
        >
          <Menu class="h-4 w-4" />
        </button>
        <div class="ml-1 flex items-center gap-2.5">
          <div class="gradient-avatar h-9 w-9 shrink-0 rounded-full" />
          <div class="hidden leading-tight lg:block">
            <p class="text-sm font-semibold text-ink">Admin User</p>
            <p class="text-xs text-muted">admin@itara.io</p>
          </div>
        </div>
      </div>
    </div>
  </header>
</template>
