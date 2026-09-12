import { defineStore } from 'pinia'
import { computed, ref, watch } from 'vue'
import { api, clearStoreId, getStoreId, setStoreId, type ApiListResponse } from '../api/client'
import type { Store } from '../types'
import { resolveCompanyCurrency, setAppCurrency } from '../utils/currency'

export const useContextStore = defineStore('context', () => {
  const stores = ref<Store[]>([])
  const currentStoreId = ref<string | null>(getStoreId())
  const loading = ref(false)

  const currentStore = computed(() => stores.value.find(s => s.id === currentStoreId.value) ?? null)

  const activeStores = computed(() => stores.value.filter(s => s.is_active))

  const currencyCode = computed(() => {
    const fromCurrent = resolveCompanyCurrency(currentStore.value?.branch?.company)
    if (currentStore.value?.branch?.company?.currency_code) return fromCurrent

    const firstWithCompany = stores.value.find(s => s.branch?.company?.currency_code)
    return resolveCompanyCurrency(firstWithCompany?.branch?.company)
  })

  function syncAppCurrency() {
    setAppCurrency(currencyCode.value)
  }

  watch(currencyCode, syncAppCurrency, { immediate: true })

  async function loadStores() {
    loading.value = true
    try {
      const res = await api.get<ApiListResponse<Store>>('/stores')
      stores.value = res.data

      const saved = currentStoreId.value
      const savedValid = saved && stores.value.some(s => s.id === saved && s.is_active)

      if (!savedValid) {
        const firstActive = stores.value.find(s => s.is_active)
        selectStore(firstActive?.id ?? null)
      }

      syncAppCurrency()
    } finally {
      loading.value = false
    }
  }

  function selectStore(id: string | null) {
    currentStoreId.value = id
    if (id) setStoreId(id)
    else clearStoreId()
    syncAppCurrency()
  }

  function storeLabel(store: Store): string {
    const company = store.branch?.company?.name
    const branch = store.branch?.name
    return [store.name, branch, company].filter(Boolean).join(' · ')
  }

  function reset() {
    stores.value = []
    selectStore(null)
  }

  return {
    stores,
    currentStoreId,
    currentStore,
    activeStores,
    currencyCode,
    loading,
    loadStores,
    selectStore,
    storeLabel,
    syncAppCurrency,
    reset,
  }
})
