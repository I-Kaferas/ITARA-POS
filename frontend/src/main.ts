import { createApp } from 'vue'
import { createPinia } from 'pinia'
import App from './App.vue'
import i18n, { ensureI18nReady } from './i18n'
import router from './router'
import './style.css'
import { initTheme } from './composables/useTheme'
import { resolveApiError } from './errors/resolveApiError'
import { pushToast } from './composables/useToast'

initTheme()

function reportUnexpected(error: unknown, source: string) {
  if (import.meta.env.DEV) {
    console.error(`[${source}]`, error)
  }
  const resolved = resolveApiError(error, 'errors.unexpected')
  pushToast({
    tone: 'danger',
    title: i18n.global.t('common.error'),
    message: resolved.message,
  })
}

async function bootstrap() {
  await ensureI18nReady()

  const app = createApp(App)
  app.config.errorHandler = (error) => {
    reportUnexpected(error, 'vue')
  }

  window.addEventListener('unhandledrejection', (event) => {
    // Avoid double-toasting intentional ApiError flows that callers may still handle.
    const reason = event.reason
    if (reason && typeof reason === 'object' && 'status' in reason) return
    reportUnexpected(reason, 'unhandledrejection')
  })

  app.use(createPinia())
  app.use(router)
  app.use(i18n)
  app.mount('#app')
}

void bootstrap()
