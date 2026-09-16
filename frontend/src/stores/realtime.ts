import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import { getStoreId, getTenantId } from '../api/client'
import { connectEcho, disconnectEcho, getEcho, type RealtimePayload } from '../realtime/echoClient'

export type RealtimeStatus = 'disconnected' | 'connecting' | 'connected' | 'reconnecting'

type Handler = (payload: RealtimePayload | { type: 'resync' }) => void

export const useRealtimeStore = defineStore('realtime', () => {
  const status = ref<RealtimeStatus>('disconnected')
  const lastEvent = ref<RealtimePayload | null>(null)
  const handlers = new Set<Handler>()
  let subscribedTenant: string | null = null
  let subscribedStore: string | null = null
  let wasConnected = false

  const isLive = computed(() => status.value === 'connected')

  function emit(payload: RealtimePayload | { type: 'resync' }) {
    if ('tenant_id' in payload) lastEvent.value = payload
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
      if (shouldResync) emit({ type: 'resync' })
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
    echo.private(channelName).listen('.domain.changed', (payload: RealtimePayload) => {
      emit(payload)
    })
  }

  function leaveCurrent() {
    const echo = getEcho()
    if (!echo) return
    if (subscribedTenant) echo.leave(`tenant.${subscribedTenant}`)
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
  }

  function disconnect() {
    leaveCurrent()
    subscribedTenant = null
    subscribedStore = null
    wasConnected = false
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
    isLive,
    connect,
    disconnect,
    resubscribe,
    subscribe,
  }
})
