import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import { onQueueChanged } from '../offline/gateway'
import { listActive, listTransactions, updateTransaction } from '../offline/queue'
import { flushOfflineQueue, resolveOffline } from '../offline/sync'
import type { ConflictResolution, OfflineTransaction } from '../offline/types'

export const useOfflineStore = defineStore('offline', () => {
  const online = ref(typeof navigator === 'undefined' ? true : navigator.onLine)
  const syncing = ref(false)
  const transactions = ref<OfflineTransaction[]>([])
  let timer: ReturnType<typeof setInterval> | undefined
  let started = false
  let unsubscribe: (() => void) | undefined
  let onOnline: (() => void) | undefined
  let onOffline: (() => void) | undefined

  const pending = computed(() => transactions.value.filter((item) => item.status === 'pending' || item.status === 'syncing'))
  const conflicts = computed(() => transactions.value.filter((item) => item.status === 'conflict'))
  const failed = computed(() => transactions.value.filter((item) => item.status === 'failed'))

  async function refresh() {
    transactions.value = await listActive()
  }

  async function flush() {
    if (syncing.value || !online.value) return
    syncing.value = true
    try {
      await flushOfflineQueue()
    } finally {
      syncing.value = false
      await refresh()
    }
  }

  function start() {
    if (started || typeof window === 'undefined') return
    started = true
    onOnline = () => {
      online.value = true
      void flush()
    }
    onOffline = () => {
      online.value = false
    }
    window.addEventListener('online', onOnline)
    window.addEventListener('offline', onOffline)
    unsubscribe = onQueueChanged(() => {
      void refresh()
      if (online.value) void flush()
    })
    timer = window.setInterval(() => {
      online.value = navigator.onLine
      if (online.value) void flush()
    }, 20000)
    void refresh()
    if (online.value) void flush()
  }

  function stop() {
    if (timer) window.clearInterval(timer)
    timer = undefined
    if (onOnline) window.removeEventListener('online', onOnline)
    if (onOffline) window.removeEventListener('offline', onOffline)
    onOnline = undefined
    onOffline = undefined
    unsubscribe?.()
    unsubscribe = undefined
    started = false
  }

  async function resolve(uuid: string, resolution: ConflictResolution) {
    await resolveOffline(uuid, resolution)
    await refresh()
  }

  async function retry(uuid: string) {
    const row = (await listTransactions()).find((item) => item.uuid === uuid)
    if (!row) return
    row.status = 'pending'
    row.nextAttemptAt = null
    row.lastError = null
    await updateTransaction(row)
    await flush()
  }

  async function history() {
    return listTransactions()
  }

  return {
    online,
    syncing,
    transactions,
    pending,
    conflicts,
    failed,
    start,
    stop,
    refresh,
    flush,
    resolve,
    retry,
    history,
  }
})
