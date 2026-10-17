import tailwindcss from '@tailwindcss/vite'
import vue from '@vitejs/plugin-vue'
import { defineConfig } from 'vite'

export default defineConfig({
  // Vite 8 oxc: solution-style root tsconfig.json (files:[]) + project refs
  // fails discovery for src/* on Windows; pin the app config explicitly.
  tsconfig: './tsconfig.app.json',
  plugins: [vue(), tailwindcss()],
  build: {
    target: 'es2020',
    cssCodeSplit: true,
    modulePreload: { polyfill: false },
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (!id.includes('node_modules')) return
          if (id.includes('vue-router') || id.includes('pinia') || id.includes('/vue/')) {
            return 'vue-vendor'
          }
          if (id.includes('vue-i18n')) return 'i18n'
          if (id.includes('laravel-echo') || id.includes('pusher-js')) return 'realtime'
        },
      },
    },
  },
  server: {
    host: '127.0.0.1',
    port: 4173,
    proxy: {
      '/api': {
        target: 'http://127.0.0.1:8001',
        changeOrigin: true,
      },
      '/storage': {
        target: 'http://127.0.0.1:8001',
        changeOrigin: true,
      },
    },
  },
})
