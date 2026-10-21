import { computed, ref, toValue, watch, type MaybeRefOrGetter } from 'vue'

const DEFAULT_PER_PAGE = 25
const EMPTY: never[] = []

/**
 * Client-side pagination for in-memory filtered lists.
 * Resets to page 1 whenever the filtered source list changes (filters / reload).
 */
export function useClientPager<T>(source: MaybeRefOrGetter<T[]>, perPageInput = DEFAULT_PER_PAGE) {
  const page = ref(1)
  const perPage = ref(Math.max(1, perPageInput))

  const rows = computed(() => {
    const value = toValue(source)
    return value ?? (EMPTY as T[])
  })
  const total = computed(() => rows.value.length)
  const lastPage = computed(() => Math.max(1, Math.ceil(total.value / perPage.value)))

  const paged = computed(() => {
    const start = (page.value - 1) * perPage.value
    return rows.value.slice(start, start + perPage.value)
  })

  function setPage(next: number) {
    const clamped = Math.min(Math.max(1, Math.floor(next)), lastPage.value)
    page.value = clamped
  }

  function resetPage() {
    page.value = 1
  }

  watch(
    rows,
    (next, prev) => {
      if (prev === undefined) return
      if (next === prev) return
      page.value = 1
    },
  )

  watch(lastPage, (max) => {
    if (page.value > max) page.value = max
  })

  return {
    page,
    perPage,
    total,
    lastPage,
    paged,
    setPage,
    resetPage,
  }
}
