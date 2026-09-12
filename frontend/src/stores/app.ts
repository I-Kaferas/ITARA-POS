import { defineStore } from 'pinia'
import { ref } from 'vue'

interface HealthResponse {
  status: string
  service: string
  version: string
  timestamp: string
}

export const useAppStore = defineStore('app', () => {
  const apiHealth = ref<HealthResponse | null>(null)
  const apiError = ref<string | null>(null)
  const loading = ref(false)

  async function checkApiHealth() {
    loading.value = true
    apiError.value = null

    try {
      const baseUrl = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:8000/api/v1'
      const response = await fetch(`${baseUrl}/health`)

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`)
      }

      apiHealth.value = await response.json()
    } catch (error) {
      apiHealth.value = null
      apiError.value = error instanceof Error ? error.message : 'Unknown error'
    } finally {
      loading.value = false
    }
  }

  return { apiHealth, apiError, loading, checkApiHealth }
})
