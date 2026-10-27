import { api, getTenantId, getToken } from '../api/client'

export type RealtimePayload = {
  event_id?: string
  type: string
  event_name?: string
  tenant_id: string
  store_id?: string | null
  user_id?: string | null
  entity?: string | null
  entity_id?: string | null
  id?: string | null
  status?: string | null
  occurred_at?: string
  data?: Record<string, unknown>
}

type EchoChannel = {
  listenToAll?: (cb: (eventName: string, payload: RealtimePayload) => void) => void
  listen: (event: string, cb: (payload: RealtimePayload) => void) => void
}

type EchoPresence = {
  here: (cb: (users: unknown[]) => void) => EchoPresence
  joining: (cb: () => void) => EchoPresence
  leaving: (cb: () => void) => EchoPresence
}

type EchoInstance = {
  disconnect: () => void
  connector?: { pusher?: { connection?: { bind: (event: string, handler: () => void) => void } } }
  private: (name: string) => EchoChannel
  leave: (name: string) => void
  join: (name: string) => EchoPresence
}

let echo: EchoInstance | null = null
let generation = 0

function canConnect(): boolean {
  return Boolean(import.meta.env.VITE_REVERB_APP_KEY && getToken() && getTenantId())
}

export function getEcho(): EchoInstance | null {
  return echo
}

export function disconnectEcho(): void {
  generation += 1
  try {
    echo?.disconnect()
  } catch {
    // POS must keep working if the socket is already gone.
  }
  echo = null
}

export async function connectEcho(): Promise<EchoInstance | null> {
  if (!canConnect()) {
    disconnectEcho()
    return null
  }

  const ticket = ++generation
  const [{ default: Echo }, { default: Pusher }] = await Promise.all([
    import('laravel-echo'),
    import('pusher-js'),
  ])
  if (ticket !== generation) return null

  try {
    echo?.disconnect()
  } catch {
    // Replace a previous socket.
  }

  try {
    const next = new Echo({
      broadcaster: 'reverb',
      key: String(import.meta.env.VITE_REVERB_APP_KEY),
      wsHost: String(import.meta.env.VITE_REVERB_HOST || 'localhost'),
      wsPort: Number(import.meta.env.VITE_REVERB_PORT || 8080),
      wssPort: Number(import.meta.env.VITE_REVERB_PORT || 8080),
      forceTLS: String(import.meta.env.VITE_REVERB_SCHEME || 'http') === 'https',
      enabledTransports: ['ws', 'wss'],
      Pusher,
      authEndpoint: '/api/v1/broadcasting/auth',
      authorizer: (channel: { name: string }) => ({
        authorize: (socketId: string, callback: (error: Error | null, data: unknown) => void) => {
          api.post('/broadcasting/auth', {
            socket_id: socketId,
            channel_name: channel.name,
          })
            .then((data) => callback(null, data))
            .catch((error: unknown) => callback(error instanceof Error ? error : new Error('auth failed'), null))
        },
      }),
    }) as EchoInstance
    if (ticket !== generation) {
      next.disconnect()
      return null
    }
    echo = next
    return echo
  } catch {
    if (ticket === generation) echo = null
    return null
  }
}
