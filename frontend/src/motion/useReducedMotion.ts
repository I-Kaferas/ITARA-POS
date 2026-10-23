import { onMounted, onUnmounted, ref } from 'vue'

export function useReducedMotion() {
  const reduced = ref(false)
  let query: MediaQueryList | null = null

  function sync() {
    reduced.value = query?.matches ?? false
  }

  onMounted(() => {
    query = window.matchMedia('(prefers-reduced-motion: reduce)')
    sync()
    query.addEventListener('change', sync)
  })

  onUnmounted(() => {
    query?.removeEventListener('change', sync)
  })

  return reduced
}
