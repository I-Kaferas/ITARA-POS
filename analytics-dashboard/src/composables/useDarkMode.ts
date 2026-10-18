import { onMounted, ref, watch } from 'vue'

const STORAGE_KEY = 'itara-analytics-theme'

export function useDarkMode() {
  const isDark = ref(false)

  function apply(dark: boolean) {
    document.documentElement.classList.toggle('dark', dark)
    localStorage.setItem(STORAGE_KEY, dark ? 'dark' : 'light')
  }

  function toggle() {
    isDark.value = !isDark.value
  }

  onMounted(() => {
    const stored = localStorage.getItem(STORAGE_KEY)
    if (stored === 'dark' || stored === 'light') {
      isDark.value = stored === 'dark'
    } else {
      isDark.value = window.matchMedia('(prefers-color-scheme: dark)').matches
    }
    apply(isDark.value)
  })

  watch(isDark, (v) => apply(v))

  return { isDark, toggle }
}
