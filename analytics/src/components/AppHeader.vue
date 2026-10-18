<script setup lang="ts">
import { Bell, Menu, Moon, Settings, Store, Sun } from 'lucide-vue-next'

defineProps<{
  dark: boolean
  filtersOpen: boolean
}>()

const emit = defineEmits<{
  toggleDark: []
  toggleFilters: []
}>()
</script>

<template>
  <header
    class="sticky top-0 z-20 border-b border-[var(--color-border)] bg-white/80 py-3 backdrop-blur-md dark:bg-slate-950/80"
  >
    <div class="mx-auto flex max-w-[1600px] items-center justify-between px-4 sm:px-6 lg:px-8">
      <div class="flex items-center gap-3">
        <div
          class="gradient-brand flex h-9 w-9 items-center justify-center rounded-xl text-white shadow-md shadow-brand-500/20"
        >
          <Store :size="18" />
        </div>
        <div>
          <h1 class="text-base font-bold tracking-tight text-[var(--color-ink)] sm:text-lg">
            ITARA NEXUS
          </h1>
          <p class="hidden text-xs text-slate-500 sm:block dark:text-slate-400">
            POS Analytics Dashboard
          </p>
        </div>
      </div>

      <div class="flex items-center gap-2">
        <button
          type="button"
          class="hidden h-9 w-9 items-center justify-center rounded-lg p-2 text-slate-500 hover:bg-slate-100 sm:inline-flex dark:hover:bg-slate-800"
          aria-label="Notifications"
        >
          <Bell :size="16" />
        </button>
        <button
          type="button"
          class="hidden h-9 w-9 items-center justify-center rounded-lg p-2 text-slate-500 hover:bg-slate-100 sm:inline-flex dark:hover:bg-slate-800"
          aria-label="Settings"
        >
          <Settings :size="16" />
        </button>
        <button
          type="button"
          class="inline-flex h-9 w-9 items-center justify-center rounded-lg border border-slate-200 text-slate-500 dark:border-slate-700 dark:hover:bg-slate-800"
          :aria-label="dark ? 'Switch to light mode' : 'Switch to dark mode'"
          @click="emit('toggleDark')"
        >
          <Sun v-if="dark" :size="16" />
          <Moon v-else :size="16" />
        </button>
        <button
          type="button"
          class="inline-flex h-9 w-9 items-center justify-center rounded-lg border border-slate-200 text-slate-500 sm:hidden dark:border-slate-700"
          :aria-expanded="filtersOpen"
          aria-label="Toggle filters"
          @click="emit('toggleFilters')"
        >
          <Menu :size="16" />
        </button>
        <div class="ml-1 hidden items-center gap-2 lg:flex">
          <div class="gradient-avatar h-9 w-9 rounded-full" />
          <div class="leading-tight">
            <p class="text-sm font-semibold text-[var(--color-ink)]">Admin User</p>
            <p class="text-xs text-slate-500 dark:text-slate-400">admin@itara.io</p>
          </div>
        </div>
      </div>
    </div>
  </header>
</template>
