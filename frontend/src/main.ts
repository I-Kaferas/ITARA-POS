import { createApp } from 'vue'
import { createPinia } from 'pinia'
import App from './App.vue'
import i18n, { ensureI18nReady } from './i18n'
import router from './router'
import './style.css'

async function bootstrap() {
  await ensureI18nReady()

  const app = createApp(App)
  app.use(createPinia())
  app.use(router)
  app.use(i18n)
  app.mount('#app')
}

void bootstrap()
