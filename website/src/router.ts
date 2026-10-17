import { createRouter, createWebHistory } from 'vue-router'
import HomePage from './pages/HomePage.vue'

export const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', name: 'home', component: HomePage },
    { path: '/:slug', name: 'tenant-home', component: HomePage },
    { path: '/product', redirect: '/#suite' },
    { path: '/features', redirect: '/#modules' },
    { path: '/contact', redirect: '/#contact' },
    { path: '/:slug/product', redirect: (to) => `/${to.params.slug}#suite` },
    { path: '/:slug/features', redirect: (to) => `/${to.params.slug}#modules` },
    { path: '/:slug/contact', redirect: (to) => `/${to.params.slug}#contact` },
  ],
  scrollBehavior(to) {
    if (to.hash) return { el: to.hash, behavior: 'smooth', top: 72 }
    return { top: 0 }
  },
})
