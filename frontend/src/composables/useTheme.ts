import { ref } from 'vue'

export type ThemePreference = 'light' | 'dark' | 'system'

const STORAGE_KEY = 'pos_theme'
const preference = ref<ThemePreference>('light')

function systemIsDark() {
  return window.matchMedia('(prefers-color-scheme: dark)').matches
}

export function readThemePreference(): ThemePreference {
  const stored = localStorage.getItem(STORAGE_KEY)
  if (stored === 'light' || stored === 'dark' || stored === 'system') return stored
  return 'light'
}

export function resolvedTheme(pref: ThemePreference = preference.value): 'light' | 'dark' {
  if (pref === 'system') return systemIsDark() ? 'dark' : 'light'
  return pref
}

export function applyTheme(pref: ThemePreference = preference.value, animate = false) {
  const root = document.documentElement
  const next = resolvedTheme(pref)
  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches
  if (animate && !reduce) {
    root.setAttribute('data-theme-switching', '')
    window.setTimeout(() => root.removeAttribute('data-theme-switching'), 240)
  }
  if (next === 'dark') root.setAttribute('data-theme', 'dark')
  else root.removeAttribute('data-theme')
  root.style.colorScheme = next
}

export function initTheme() {
  preference.value = readThemePreference()
  applyTheme(preference.value, false)
  window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
    if (preference.value === 'system') applyTheme('system', true)
  })
}

export function useTheme() {
  function setTheme(next: ThemePreference) {
    preference.value = next
    localStorage.setItem(STORAGE_KEY, next)
    applyTheme(next, true)
  }

  function cycleTheme() {
    const order: ThemePreference[] = ['light', 'dark', 'system']
    const index = order.indexOf(preference.value)
    setTheme(order[(index + 1) % order.length])
  }

  return { preference, setTheme, cycleTheme }
}
