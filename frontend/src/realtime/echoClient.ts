import Echo from 'laravel-echo'
import Pusher from 'pusher-js'
import { api, getTenantId, getToken } from '../api/client'

export type RealtimePayload = {
  type: string
  tenant_id: string
  store_id?: string | null
  entity?: string | null
  id?: string | null
  status?: string | null
  occurred_at?: string
}

type EchoInstance = InstanceType<typeof Echo>

let echo: EchoInstance | null = null

function canConnect(): boolean {
  return Boolean(import.meta.env.VITE_REVERB_APP_KEY && getToken() && getTenantId())
}

export function getEcho(): EchoInstance | null {
  return echo
}

export function disconnectEcho(): void {
  try {
    echo?.disconnect()
  } catch {
    // POS must keep working if the socket is already gone.
  }
  echo = null
}

export function connectEcho(): EchoInstance | null {
  if (!canConnect()) {
    disconnectEcho()
    return null
  }

  disconnectEcho()

  try {
    echo = new Echo({
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
    })
    return echo
  } catch {
    echo = null
    return null
  }
}
