import { createRouter, createWebHistory } from 'vue-router'
import HomePage from './pages/HomePage.vue'
import ProductPage from './pages/ProductPage.vue'
import FeaturesPage from './pages/FeaturesPage.vue'
import ContactPage from './pages/ContactPage.vue'

export const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', name: 'home', component: HomePage, meta: { nav: 'home' } },
    { path: '/product', name: 'product', component: ProductPage, meta: { nav: 'product' } },
    { path: '/features', name: 'features', component: FeaturesPage, meta: { nav: 'features' } },
    { path: '/contact', name: 'contact', component: ContactPage, meta: { nav: 'contact' } },
    { path: '/:slug', name: 'tenant-home', component: HomePage, meta: { nav: 'home' } },
    { path: '/:slug/product', name: 'tenant-product', component: ProductPage, meta: { nav: 'product' } },
    { path: '/:slug/features', name: 'tenant-features', component: FeaturesPage, meta: { nav: 'features' } },
    { path: '/:slug/contact', name: 'tenant-contact', component: ContactPage, meta: { nav: 'contact' } },
  ],
  scrollBehavior: () => ({ top: 0 }),
})
