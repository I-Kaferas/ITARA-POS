import { defineStore } from 'pinia'
import { type Slot, shallowRef } from 'vue'

export const usePageHeaderStore = defineStore('pageHeader', () => {
  const titleSlot = shallowRef<Slot | null>(null)
  const subtitleSlot = shallowRef<Slot | null>(null)
  let clearTimer: ReturnType<typeof setTimeout> | null = null

  function setSlots(title?: Slot | null, subtitle?: Slot | null) {
    if (clearTimer) {
      clearTimeout(clearTimer)
      clearTimer = null
    }
    titleSlot.value = title ?? null
    subtitleSlot.value = subtitle ?? null
  }

  function clear() {
    if (clearTimer) clearTimeout(clearTimer)
    // Delay so the next page can register before titles flash empty.
    clearTimer = setTimeout(() => {
      titleSlot.value = null
      subtitleSlot.value = null
      clearTimer = null
    }, 40)
  }

  return { titleSlot, subtitleSlot, setSlots, clear }
})
