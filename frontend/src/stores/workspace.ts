import { getStoreId } from '../api/client'
import { useBackofficeStore } from './backoffice'
import { useBrandingStore } from './branding'
import { useContextStore } from './context'
import { usePosStore } from './pos'
import { useRealtimeStore } from './realtime'

/** Drop in-memory business data so a new session cannot see the previous tenant. */
export function resetTenantWorkspace() {
  const context = useContextStore()
  context.stores = []
  if (!getStoreId()) context.selectStore(null)
  usePosStore().reset()
  useBrandingStore().clear()
  const realtime = useRealtimeStore()
  realtime.disconnect()
  realtime.clearSensitive()
  useBackofficeStore().clearTenantState()
}
