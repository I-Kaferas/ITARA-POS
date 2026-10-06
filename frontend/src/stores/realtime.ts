import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import { api, getStoreId, getTenantId } from '../api/client'
import { connectEcho, disconnectEcho, getEcho, type RealtimePayload } from '../realtime/echoClient'

export type RealtimeStatus = 'disconnected' | 'connecting' | 'connected' | 'reconnecting'

type Handler = (payload: RealtimePayload | { type: 'resync' }) => void

export const useRealtimeStore = defineStore('realtime', () => {
  const status = ref<RealtimeStatus>('disconnected')
  const lastEvent = ref<RealtimePayload | null>(null)
  const lastSyncAt = ref<string | null>(null)
  const onlineCount = ref(0)
  const notice = ref('')
  const handlers = new Set<Handler>()
  const seenIds = new Set<string>()
  const seenOrder: string[] = []
  let subscribedTenant: string | null = null
  let subscribedStore: string | null = null
  let wasConnected = false
  let fallbackTimer: ReturnType<typeof setInterval> | undefined

  const isLive = computed(() => status.value === 'connected')

  function remember(eventId?: string): boolean {
    if (!eventId) return true
    if (seenIds.has(eventId)) return false
    seenIds.add(eventId)
    seenOrder.push(eventId)
    if (seenOrder.length > 400) {
      const oldest = seenOrder.shift()
      if (oldest) seenIds.delete(oldest)
    }
    return true
  }

  function emit(payload: RealtimePayload | { type: 'resync' }) {
    if ('event_id' in payload && !remember(payload.event_id)) return
    if ('tenant_id' in payload) {
      lastEvent.value = payload
      if (payload.occurred_at) lastSyncAt.value = payload.occurred_at
      if (payload.type === 'stock.low') notice.value = 'stock.low'
      if (payload.type === 'stock.out') notice.value = 'stock.out'
    }
    handlers.forEach((handler) => {
      try {
        handler(payload)
      } catch {
        // A view refresh error must not break other listeners.
      }
    })
  }

  function bindConnection() {
    const echo = getEcho()
    const connection = echo?.connector?.pusher?.connection
    if (!connection) return

    connection.bind('connecting', () => {
      status.value = wasConnected ? 'reconnecting' : 'connecting'
    })
    connection.bind('connected', () => {
      const shouldResync = wasConnected
      status.value = 'connected'
      wasConnected = true
      if (shouldResync) void catchUp()
    })
    connection.bind('unavailable', () => {
      status.value = 'reconnecting'
    })
    connection.bind('disconnected', () => {
      status.value = 'disconnected'
    })
    connection.bind('failed', () => {
      status.value = 'disconnected'
    })
  }

  function listen(channelName: string) {
    const echo = getEcho()
    if (!echo) return
    const channel = echo.private(channelName)
    const deliver = (eventName: string, payload: RealtimePayload) => {
      if (eventName.startsWith('pusher:')) return
      const type = payload?.type || eventName.replace(/^\./, '')
      emit({ ...payload, type })
    }
    if (typeof channel.listenToAll === 'function') {
      channel.listenToAll(deliver)
      return
    }
    channel.listen('.domain.changed', (payload: RealtimePayload) => deliver('domain.changed', payload))
  }

  async function catchUp() {
    const since = lastSyncAt.value
    if (!since || !getTenantId()) return
    try {
      const storeId = getStoreId()
      const query = new URLSearchParams({ since })
      if (storeId) query.set('store_id', storeId)
      const response = await api.get<{ data: RealtimePayload[] }>(`/realtime/sync?${query.toString()}`)
      for (const event of response?.data ?? []) emit(event)
      lastSyncAt.value = new Date().toISOString()
    } catch {
      // The socket stays the primary path. The next reconnect retries the gap.
    }
  }

  function leaveCurrent() {
    const echo = getEcho()
    if (!echo) return
    if (subscribedTenant) {
      echo.leave(`tenant.${subscribedTenant}`)
      echo.leave(`tenant.${subscribedTenant}.online`)
    }
    if (subscribedTenant && subscribedStore) echo.leave(`tenant.${subscribedTenant}.store.${subscribedStore}`)
  }

  function subscribeChannels() {
    const tenantId = getTenantId()
    const storeId = getStoreId()
    if (!tenantId || !getEcho()) return

    leaveCurrent()
    subscribedTenant = tenantId
    subscribedStore = storeId
    listen(`tenant.${tenantId}`)
    if (storeId) listen(`tenant.${tenantId}.store.${storeId}`)
    const echo = getEcho()
    echo?.join(`tenant.${tenantId}.online`)
      ?.here((users: unknown[]) => { onlineCount.value = users.length })
      ?.joining(() => { onlineCount.value += 1 })
      ?.leaving(() => { onlineCount.value = Math.max(0, onlineCount.value - 1) })
  }

  function connect() {
    status.value = 'connecting'
    const echo = connectEcho()
    if (!echo) {
      status.value = 'disconnected'
      return
    }
    bindConnection()
    subscribeChannels()
    if (fallbackTimer) clearInterval(fallbackTimer)
    fallbackTimer = setInterval(() => {
      if (status.value !== 'connected') void catchUp()
    }, 30_000)
  }

  function disconnect() {
    leaveCurrent()
    subscribedTenant = null
    subscribedStore = null
    wasConnected = false
    onlineCount.value = 0
    if (fallbackTimer) clearInterval(fallbackTimer)
    fallbackTimer = undefined
    disconnectEcho()
    status.value = 'disconnected'
  }

  function resubscribe() {
    if (status.value === 'disconnected' && !getEcho()) {
      connect()
      return
    }
    subscribeChannels()
  }

  function subscribe(handler: Handler): () => void {
    handlers.add(handler)
    return () => {
      handlers.delete(handler)
    }
  }

  return {
    status,
    lastEvent,
    lastSyncAt,
    onlineCount,
    notice,
    isLive,
    connect,
    disconnect,
    resubscribe,
    subscribe,
  }
})
