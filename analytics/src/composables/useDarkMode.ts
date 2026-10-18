import { onMounted, ref } from 'vue'

const STORAGE_KEY = 'itara-analytics-theme'
const dark = ref(false)
let initialized = false

function apply(value: boolean) {
  dark.value = value
  document.documentElement.classList.toggle('dark', value)
  localStorage.setItem(STORAGE_KEY, value ? 'dark' : 'light')
}

export function useDarkMode() {
  onMounted(() => {
    if (initialized) return
    initialized = true
    const stored = localStorage.getItem(STORAGE_KEY)
    if (stored === 'dark' || stored === 'light') {
      apply(stored === 'dark')
      return
    }
    apply(window.matchMedia('(prefers-color-scheme: dark)').matches)
  })

  function toggle() {
    apply(!dark.value)
  }

  return { dark, toggle, apply }
}
