import { computed, ref } from 'vue'

export type ThemeMode = 'light' | 'dark'

const STORAGE_KEY = 'itara_website_theme'

function readTheme(): ThemeMode {
  const stored = localStorage.getItem(STORAGE_KEY)
  if (stored === 'light' || stored === 'dark') return stored
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
}

const theme = ref<ThemeMode>('light')

export function applyTheme(mode: ThemeMode) {
  const root = document.documentElement
  if (mode === 'dark') root.setAttribute('data-theme', 'dark')
  else root.removeAttribute('data-theme')
  root.style.colorScheme = mode
}

export function initTheme() {
  theme.value = readTheme()
  applyTheme(theme.value)
}

export function useTheme() {
  const isDark = computed(() => theme.value === 'dark')

  function setTheme(mode: ThemeMode) {
    theme.value = mode
    localStorage.setItem(STORAGE_KEY, mode)
    applyTheme(mode)
  }

  function toggleTheme() {
    setTheme(theme.value === 'dark' ? 'light' : 'dark')
  }

  return { theme, isDark, setTheme, toggleTheme }
}
