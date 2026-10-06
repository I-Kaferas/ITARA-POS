<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import AppIcon from '../ui/AppIcon.vue'
import EmptyState from '../ui/EmptyState.vue'

type ModuleItem = {
  to: string
  label: string
  group: string
  keywords: string
}

const open = ref(false)
const query = ref('')
const activeIndex = ref(0)
const inputRef = ref<HTMLInputElement | null>(null)
const listRef = ref<HTMLElement | null>(null)

const { t } = useI18n()
const router = useRouter()

const modules = computed<ModuleItem[]>(() => [
  { to: '/admin', label: t('nav.dashboard'), group: t('nav.section.main'), keywords: 'accueil tableau board' },
  { to: '/admin/pos/overview', label: t('nav.posOverview'), group: t('nav.group.posOps'), keywords: 'apercu caisse pos dashboard' },
  { to: '/admin/pos/terminal', label: t('nav.posTerminal'), group: t('nav.group.posOps'), keywords: 'caisse terminal vente encaisser pos' },
  { to: '/admin/pos/orders', label: t('nav.posOrders'), group: t('nav.group.posOps'), keywords: 'commandes ventes factures tickets' },
  { to: '/admin/pos/shifts', label: t('nav.posShifts'), group: t('nav.group.posOps'), keywords: 'shift caisse caissier ouverture cloture' },
  { to: '/admin/pos/reservations', label: t('nav.posReservations'), group: t('nav.group.posOps'), keywords: 'reservation table' },
  { to: '/admin/hospitality', label: t('nav.restaurant'), group: t('nav.group.posOps'), keywords: 'tables restaurant salle commande hospitality' },
  { to: '/admin/sales/returns', label: t('sales.tabs.returns'), group: t('nav.group.posSales'), keywords: 'retours remboursement' },
  { to: '/admin/products', label: t('nav.products'), group: t('nav.catalog'), keywords: 'produit catalogue article' },
  { to: '/admin/accompaniments', label: t('nav.accompaniments'), group: t('nav.group.products'), keywords: 'accompagnement gratuit produit frites side' },
  { to: '/admin/catalog/options', label: t('nav.productOptions'), group: t('nav.group.products'), keywords: 'options variantes taille couleur transformer' },
  { to: '/admin/catalog/beverages', label: t('nav.beverages'), group: t('nav.group.products'), keywords: 'boisson whisky verre bouteille dose bar' },
  { to: '/admin/catalog/gallery', label: t('nav.catalogGallery'), group: t('nav.catalog'), keywords: 'galerie images photos' },
  { to: '/admin/catalog/catalogs', label: t('catalog.tabs.catalogs'), group: t('nav.group.reference'), keywords: 'catalogues' },
  { to: '/admin/catalog/categories', label: t('nav.inventoryItems.categories'), group: t('nav.inventoryHub'), keywords: 'categories' },
  { to: '/admin/catalog/brands', label: t('nav.inventoryItems.brands'), group: t('nav.inventoryHub'), keywords: 'marque brand crud' },
  { to: '/admin/catalog/units', label: t('nav.inventoryItems.units'), group: t('nav.inventoryHub'), keywords: 'unite mesure unit kg piece' },
  { to: '/admin/catalog/attributes', label: t('nav.attributes'), group: t('nav.group.reference'), keywords: 'attributs couleur taille variantes' },
  { to: '/admin/catalog/prices', label: t('nav.priceLists'), group: t('nav.catalog'), keywords: 'prix tarif liste' },
  { to: '/admin/catalog/taxes', label: t('nav.inventoryItems.taxes'), group: t('nav.inventoryHub'), keywords: 'taxes tva' },
  { to: '/admin/customers', label: t('nav.customers'), group: t('nav.catalog'), keywords: 'clients' },
  { to: '/admin/hotel/room-config', label: t('hotel.tabs.roomConfig'), group: t('nav.hotel'), keywords: 'chambre type configuration hotel' },
  { to: '/admin/hotel/room-config/amenities', label: t('hotel.roomConfig.amenities'), group: t('nav.hotel'), keywords: 'equipements amenities wifi tv minibar' },
  { to: '/admin/hotel/room-config/room-types', label: t('hotel.roomConfig.roomTypes'), group: t('nav.hotel'), keywords: 'types chambres room types suite standard' },
  { to: '/admin/hotel/room-config/buildings', label: t('hotel.roomConfig.buildings'), group: t('nav.hotel'), keywords: 'batiments buildings immeuble' },
  { to: '/admin/hotel/room-config/wings', label: t('hotel.roomConfig.wings'), group: t('nav.hotel'), keywords: 'ailes zones wings' },
  { to: '/admin/hotel/room-config/floors', label: t('hotel.roomConfig.floors'), group: t('nav.hotel'), keywords: 'etages floors niveau' },
  { to: '/admin/hotel/rooms', label: t('hotel.tabs.rooms'), group: t('nav.hotel'), keywords: 'chambres rooms hotel' },
  { to: '/admin/hotel/reservations', label: t('hotel.tabs.reservations'), group: t('nav.hotel'), keywords: 'reservation hotel booking' },
  { to: '/admin/hotel/stays', label: t('hotel.tabs.stays'), group: t('nav.hotel'), keywords: 'sejour stay checkin checkout' },
  { to: '/admin/hotel/invoices', label: t('hotel.tabs.invoices'), group: t('nav.hotel'), keywords: 'facture folio hotel' },
  { to: '/admin/hotel/guests', label: t('hotel.tabs.guests'), group: t('nav.hotel'), keywords: 'client hotel guest' },
  { to: '/admin/hotel/housekeeping', label: t('hotel.tabs.housekeeping'), group: t('nav.hotel'), keywords: 'housekeeping menage nettoyage' },
  { to: '/admin/hotel/calendar', label: t('hotel.tabs.calendar'), group: t('nav.hotel'), keywords: 'calendrier planning hotel' },
  { to: '/admin/hotel/concierge', label: t('hotel.tabs.concierge'), group: t('nav.hotel'), keywords: 'concierge services' },
  { to: '/admin/hotel/reports', label: t('hotel.tabs.reports'), group: t('nav.hotel'), keywords: 'rapports hotel occupancy' },
  { to: '/admin/hotel/settings', label: t('hotel.tabs.settings'), group: t('nav.hotel'), keywords: 'configuration hotel settings' },
  { to: '/admin/stores', label: t('nav.stores'), group: t('nav.section.main'), keywords: 'magasins' },
  { to: '/admin/inventory/stock', label: t('nav.inventoryItems.products'), group: t('nav.inventoryHub'), keywords: 'stock inventaire produits' },
  { to: '/admin/reports/inventory', label: t('nav.inventoryItems.overview'), group: t('nav.inventoryHub'), keywords: 'apercu inventaire overview' },
  { to: '/admin/inventory/manufacturers', label: t('nav.inventoryItems.manufacturers'), group: t('nav.inventoryHub'), keywords: 'fabricant manufacturer' },
  { to: '/admin/inventory/departments', label: t('nav.inventoryItems.departments'), group: t('nav.inventoryHub'), keywords: 'departement department' },
  { to: '/admin/inventory/alerts', label: t('inventory.tabs.alerts'), group: t('nav.group.stockStatus'), keywords: 'alertes' },
  { to: '/admin/inventory/supplies', label: t('inventory.tabs.supplies'), group: t('nav.group.movements'), keywords: 'approvisionnement achat reception' },
  { to: '/admin/inventory/transfers', label: t('nav.inventoryItems.transfers'), group: t('nav.inventoryHub'), keywords: 'transferts' },
  { to: '/admin/inventory/adjustments', label: t('nav.inventoryItems.movements'), group: t('nav.inventoryHub'), keywords: 'ajustements mouvements' },
  { to: '/admin/inventory/issues', label: t('nav.inventoryItems.exits'), group: t('nav.inventoryHub'), keywords: 'sortie sorties issue' },
  { to: '/admin/inventory/counts', label: t('nav.inventoryItems.counts'), group: t('nav.inventoryHub'), keywords: 'inventaire inventaires comptage' },
  { to: '/admin/inventory/verifications', label: t('inventory.tabs.verifications'), group: t('nav.group.controls'), keywords: 'verification controle anomalies' },
  { to: '/admin/inventory/batches', label: t('inventory.tabs.batches'), group: t('nav.group.traceability'), keywords: 'lots' },
  { to: '/admin/inventory/serials', label: t('inventory.tabs.serials'), group: t('nav.group.traceability'), keywords: 'series numeros' },
  { to: '/admin/suppliers', label: t('nav.inventoryItems.suppliers'), group: t('nav.inventoryHub'), keywords: 'fournisseurs' },
  { to: '/admin/purchases/overview', label: t('purchases.hub.overview'), group: t('nav.purchasingHub'), keywords: 'achats apercu dashboard purchasing overview' },
  { to: '/admin/purchases/requisitions', label: t('purchases.hub.requisitions'), group: t('nav.purchasingHub'), keywords: 'requisition demande achat' },
  { to: '/admin/purchases/proformas', label: t('purchases.hub.proformas'), group: t('nav.purchasingHub'), keywords: 'proforma' },
  { to: '/admin/purchases/orders', label: t('purchases.hub.orders'), group: t('nav.purchasingHub'), keywords: 'achats commandes purchase orders' },
  { to: '/admin/purchases/invoices', label: t('purchases.hub.invoices'), group: t('nav.purchasingHub'), keywords: 'factures fournisseurs supplier invoices' },
  { to: '/admin/purchases/payments', label: t('purchases.hub.payments'), group: t('nav.purchasingHub'), keywords: 'paiements fournisseurs supplier payments' },
  { to: '/admin/purchases/returns', label: t('purchases.hub.returns'), group: t('nav.purchasingHub'), keywords: 'retours achats purchase returns' },
  { to: '/admin/expenses/dashboard', label: t('expenses.tabs.dashboard'), group: t('nav.expenseTrackerHub'), keywords: 'depenses dashboard expense tracker' },
  { to: '/admin/expenses', label: t('expenses.tabs.list'), group: t('nav.expenseTrackerHub'), keywords: 'depenses charges expenses' },
  { to: '/admin/expenses/categories', label: t('expenses.tabs.categories'), group: t('nav.expenseTrackerHub'), keywords: 'categories depenses' },
  { to: '/admin/expenses/reports', label: t('expenses.tabs.reports'), group: t('nav.expenseTrackerHub'), keywords: 'rapports depenses reports' },
  { to: '/admin/expenses/recurring', label: t('expenses.tabs.recurring'), group: t('nav.expenseTrackerHub'), keywords: 'depenses recurrentes loyer recurring' },
  { to: '/admin/payables', label: t('nav.payables'), group: t('nav.section.purchasing'), keywords: 'dettes fournisseurs' },
  { to: '/admin/promotions', label: t('nav.promotions'), group: t('nav.section.catalog'), keywords: 'promotions remises' },
  { to: '/admin/barcodes', label: t('nav.barcodes'), group: t('nav.section.catalog'), keywords: 'code barre scanner etiquette' },
  { to: '/admin/services', label: t('nav.services'), group: t('nav.section.catalog'), keywords: 'services salon garage reparation rendez-vous' },
  { to: '/admin/reports/dashboard', label: t('reports.tabs.dashboard'), group: t('nav.reports'), keywords: 'rapports dashboard tableau bord' },
  { to: '/admin/reports/sales', label: t('reports.tabs.sales'), group: t('nav.reports'), keywords: 'rapports ventes' },
  { to: '/admin/reports/inventory', label: t('reports.tabs.inventory'), group: t('nav.reports'), keywords: 'rapport inventaire stocks' },
  { to: '/admin/reports/store-stock', label: t('reports.tabs.storeStock'), group: t('nav.reports'), keywords: 'rapport stock boutique magasin rupture rotation' },
  { to: '/admin/reports/purchases', label: t('reports.tabs.purchases'), group: t('nav.reports'), keywords: 'rapports achats' },
  { to: '/admin/reports/forecasts', label: t('reports.tabs.forecasts'), group: t('nav.reports'), keywords: 'previsions forecast' },
  { to: '/admin/reports/financial', label: t('reports.tabs.revenue'), group: t('nav.reports'), keywords: 'rapport recette finance' },
  { to: '/admin/reports/condensed', label: t('reports.tabs.condensed'), group: t('nav.reports'), keywords: 'rapport condense' },
  { to: '/admin/reports/daily', label: t('reports.tabs.daily'), group: t('nav.reports'), keywords: 'rapport journalier daily' },
  { to: '/admin/reports/user-performance', label: t('reports.tabs.userPerformance'), group: t('nav.reports'), keywords: 'performance utilisateur caissier' },
  { to: '/admin/accounting', label: t('nav.accounting'), group: t('nav.section.finance'), keywords: 'comptabilite' },
  { to: '/admin/import-export', label: t('nav.importExport'), group: t('nav.section.system'), keywords: 'import export csv' },
  { to: '/admin/sync', label: t('nav.sync'), group: t('nav.section.system'), keywords: 'synchronisation terminal mobile windows' },
  { to: '/admin/production', label: t('nav.production'), group: t('nav.section.stock'), keywords: 'production recette fabrication' },
  { to: '/admin/organization/company', label: t('org.tabs.company'), group: t('nav.group.company'), keywords: 'entreprise societe' },
  { to: '/admin/organization/branding', label: t('org.tabs.branding'), group: t('nav.group.company'), keywords: 'logo image marque branding' },
  { to: '/admin/organization/currencies', label: t('nav.settingsItems.currency'), group: t('nav.settingsHub'), keywords: 'devises currency' },
  { to: '/admin/organization/payment-methods', label: t('org.tabs.paymentMethods'), group: t('nav.group.company'), keywords: 'paiements' },
  { to: '/admin/organization/branches', label: t('org.tabs.branches'), group: t('nav.group.sites'), keywords: 'succursales' },
  { to: '/admin/organization/stores', label: t('org.tabs.stores'), group: t('nav.group.sites'), keywords: 'magasins org' },
  { to: '/admin/organization/warehouses', label: t('nav.inventoryItems.warehouses'), group: t('nav.inventoryHub'), keywords: 'entrepots' },
  { to: '/admin/organization/terminals', label: t('org.tabs.terminals'), group: t('nav.group.posHardware'), keywords: 'terminaux pos' },
  { to: '/admin/organization/devices', label: t('org.tabs.devices'), group: t('nav.syncDevicesHub'), keywords: 'appareils devices sync' },
  { to: '/admin/settings/subscription', label: t('nav.settingsItems.subscription'), group: t('nav.settingsHub'), keywords: 'abonnement subscription' },
  { to: '/admin/customer-hub/dashboard', label: t('nav.customerHubItems.dashboard'), group: t('nav.customerHub'), keywords: 'customer hub dashboard clients' },
  { to: '/admin/customer-hub/link-requests', label: t('nav.customerHubItems.linkRequests'), group: t('nav.customerHub'), keywords: 'link requests liaison clients' },
  { to: '/admin/customer-hub/linked-users', label: t('nav.customerHubItems.linkedUsers'), group: t('nav.customerHub'), keywords: 'linked users utilisateurs lies' },
  { to: '/admin/customer-hub/mobile-orders', label: t('nav.customerHubItems.mobileOrders'), group: t('nav.customerHub'), keywords: 'mobile orders commandes mobiles' },
  { to: '/admin/customer-hub/payments', label: t('nav.customerHubItems.payments'), group: t('nav.customerHub'), keywords: 'payments paiements customer hub' },
  { to: '/admin/settings/orders', label: t('nav.settingsItems.orders'), group: t('nav.spaceOrdersHub'), keywords: 'itara space commandes orders' },
  { to: '/admin/settings/analytics', label: t('nav.settingsItems.analytics'), group: t('nav.spaceOrdersHub'), keywords: 'itara space analytics analytique' },
  { to: '/admin/settings/merchant-qr', label: t('nav.settingsItems.merchantQr'), group: t('nav.settingsHub'), keywords: 'qr marchand merchant settings parametres' },
  { to: '/admin/settings/app-versions', label: t('nav.settingsItems.appVersions'), group: t('nav.settingsHub'), keywords: 'versions application app' },
  { to: '/admin/organization/registers', label: t('org.tabs.registers'), group: t('nav.group.posHardware'), keywords: 'caisses' },
  { to: '/admin/organization/users', label: t('org.tabs.users'), group: t('nav.group.access'), keywords: 'utilisateurs' },
  { to: '/admin/organization/roles', label: t('org.tabs.roles'), group: t('nav.group.access'), keywords: 'roles permissions' },
  { to: '/admin/organization/permissions', label: t('org.tabs.permissions'), group: t('nav.group.access'), keywords: 'permissions droits' },
  { to: '/admin/audit', label: t('nav.audit'), group: t('nav.section.system'), keywords: 'audit logs' },
  { to: '/admin/account', label: t('nav.account'), group: t('nav.section.system'), keywords: 'compte profil' },
])

const results = computed(() => {
  const q = query.value.trim().toLowerCase()
  if (!q) return modules.value
  return modules.value.filter((item) =>
    `${item.label} ${item.group} ${item.keywords}`.toLowerCase().includes(q),
  )
})

const groupedResults = computed(() => {
  const groups: { label: string; items: { item: ModuleItem; index: number }[] }[] = []
  const indexByGroup = new Map<string, number>()
  results.value.forEach((item, index) => {
    let groupIndex = indexByGroup.get(item.group)
    if (groupIndex === undefined) {
      groupIndex = groups.length
      indexByGroup.set(item.group, groupIndex)
      groups.push({ label: item.group, items: [] })
    }
    groups[groupIndex].items.push({ item, index })
  })
  return groups
})

watch(query, () => {
  activeIndex.value = 0
})

watch(open, async (value) => {
  document.body.style.overflow = value ? 'hidden' : ''
  if (value) {
    query.value = ''
    activeIndex.value = 0
    await nextTick()
    inputRef.value?.focus()
  }
})

watch(activeIndex, async () => {
  if (!open.value) return
  await nextTick()
  listRef.value?.querySelector<HTMLElement>('[data-active="true"]')?.scrollIntoView({
    block: 'nearest',
  })
})

function iconFor(to: string): string {
  if (to === '/admin') return 'dashboard'
  if (to.includes('/pos/shifts')) return 'shift'
  if (to.includes('/pos/reservations')) return 'calendar'
  if (to.includes('/pos/orders') || to.includes('/sales/returns')) return 'sales'
  if (to.includes('/pos/terminal')) return 'device-pos'
  if (to.startsWith('/admin/pos')) return 'store-pin'
  if (to.includes('/catalog/options')) return 'layers'
  if (to.includes('/catalog/beverages')) return 'sparkles'
  if (to.includes('/catalog/gallery')) return 'catalog'
  if (to.includes('/catalog/taxes') || to.includes('/catalog/prices')) return 'tag'
  if (to.startsWith('/admin/accompaniments')) return 'sparkles'
  if (to.startsWith('/admin/products') || to.startsWith('/admin/catalog')) return 'products'
  if (to.startsWith('/admin/customers')) return 'customers'
  if (to.includes('/hotel/housekeeping')) return 'broom'
  if (to.includes('/hotel/calendar')) return 'calendar'
  if (to.includes('/hotel/guests')) return 'account'
  if (to.includes('/hotel/invoices')) return 'receipt'
  if (to.includes('/hotel/rooms') || to.includes('/room-config') || to.includes('/hotel/stays')) return 'bed'
  if (to.startsWith('/admin/hotel')) return 'building'
  if (to.startsWith('/admin/hospitality') || to.startsWith('/admin/pos/tables')) return 'tables'
  if (to.startsWith('/admin/stores')) return 'stores'
  if (to.includes('/inventory/alerts')) return 'alert'
  if (to.includes('/inventory/transfers')) return 'transfer'
  if (to.includes('/inventory/adjustments')) return 'adjust'
  if (to.startsWith('/admin/inventory')) return 'inventory'
  if (to.startsWith('/admin/suppliers')) return 'suppliers'
  if (to.startsWith('/admin/purchases')) return 'purchases'
  if (to.startsWith('/admin/expenses')) return 'coins'
  if (to.startsWith('/admin/payables')) return 'receipt'
  if (to.startsWith('/admin/promotions')) return 'percent'
  if (to.startsWith('/admin/barcodes')) return 'tag'
  if (to.startsWith('/admin/services')) return 'sparkles'
  if (to.startsWith('/admin/reports')) return 'note'
  if (to.startsWith('/admin/accounting')) return 'coins'
  if (to.startsWith('/admin/import-export')) return 'import'
  if (to.startsWith('/admin/sync')) return 'wifi'
  if (to.startsWith('/admin/production')) return 'layers'
  if (to.includes('/organization/users') || to.includes('/organization/roles') || to.includes('/organization/permissions')) return 'lock'
  if (to.includes('/organization/terminals') || to.includes('/organization/devices') || to.includes('/organization/registers')) return 'device-pos'
  if (to.startsWith('/admin/organization')) return 'organization'
  if (to.startsWith('/admin/audit')) return 'lock'
  if (to.startsWith('/admin/account')) return 'account'
  return 'search'
}

function show() {
  open.value = true
}

function close() {
  open.value = false
}

function go(index = activeIndex.value) {
  const item = results.value[index]
  if (!item) return
  close()
  router.push(item.to)
}

function onWindowKeydown(event: KeyboardEvent) {
  const key = event.key.toLowerCase()
  if ((event.ctrlKey || event.metaKey) && key === 'k') {
    event.preventDefault()
    open.value = !open.value
    return
  }
  if (!open.value) return
  if (event.key === 'Escape') {
    event.preventDefault()
    close()
  } else if (event.key === 'ArrowDown' || event.key === 'ArrowRight') {
    event.preventDefault()
    activeIndex.value = Math.min(activeIndex.value + 1, Math.max(results.value.length - 1, 0))
  } else if (event.key === 'ArrowUp' || event.key === 'ArrowLeft') {
    event.preventDefault()
    activeIndex.value = Math.max(activeIndex.value - 1, 0)
  } else if (event.key === 'Enter') {
    event.preventDefault()
    go()
  }
}

onMounted(() => window.addEventListener('keydown', onWindowKeydown))
onBeforeUnmount(() => {
  window.removeEventListener('keydown', onWindowKeydown)
  document.body.style.overflow = ''
})

defineExpose({ show })
</script>

<template>
  <Teleport to="body">
    <Transition name="cmdk">
      <div
        v-if="open"
        class="cmdk"
        @click.self="close"
      >
        <div
          class="cmdk__panel"
          role="dialog"
          aria-modal="true"
          :aria-label="t('command.title')"
        >
          <header class="cmdk__header">
            <div class="cmdk__heading">
              <span class="cmdk__mark">
                <AppIcon name="search" :size="20" />
              </span>
              <div>
                <h2 class="cmdk__title">{{ t('command.title') }}</h2>
                <p class="cmdk__subtitle">{{ t('command.hint') }}</p>
              </div>
            </div>
            <button
              type="button"
              class="cmdk__close"
              :aria-label="t('command.close')"
              @click="close"
            >
              ×
            </button>
          </header>

          <div class="cmdk__search">
            <AppIcon name="search" :size="20" class="cmdk__search-icon" />
            <input
              ref="inputRef"
              v-model="query"
              type="search"
              class="cmdk__input"
              autocomplete="off"
              spellcheck="false"
              :placeholder="t('command.placeholder')"
            />
            <kbd class="cmdk__chip">Esc</kbd>
          </div>

          <div ref="listRef" class="cmdk__body">
            <div v-if="results.length" class="cmdk__groups">
              <section v-for="group in groupedResults" :key="group.label" class="cmdk__group">
                <h3 class="cmdk__group-title">{{ group.label }}</h3>
                <ul class="cmdk__grid">
                  <li v-for="{ item, index } in group.items" :key="item.to">
                    <button
                      type="button"
                      class="cmdk__item"
                      :class="{ 'cmdk__item--active': index === activeIndex }"
                      :data-active="index === activeIndex"
                      @mouseenter="activeIndex = index"
                      @click="go(index)"
                    >
                      <span class="cmdk__item-icon">
                        <AppIcon :name="iconFor(item.to)" :size="18" />
                      </span>
                      <span class="cmdk__label">{{ item.label }}</span>
                      <AppIcon
                        v-if="index === activeIndex"
                        name="chevron-right"
                        :size="16"
                        class="cmdk__item-arrow"
                      />
                    </button>
                  </li>
                </ul>
              </section>
            </div>
            <div v-else class="cmdk__empty">
              <EmptyState icon="search" :title="t('command.empty')" />
            </div>
          </div>

          <footer class="cmdk__footer">
            <div class="cmdk__shortcuts">
              <span><kbd class="cmdk__chip">↑</kbd><kbd class="cmdk__chip">↓</kbd> {{ t('command.navigate') }}</span>
              <span><kbd class="cmdk__chip">↵</kbd> {{ t('command.select') }}</span>
              <span><kbd class="cmdk__chip">Esc</kbd> {{ t('command.close') }}</span>
            </div>
            <p class="cmdk__count">{{ t('command.results', { count: results.length }) }}</p>
          </footer>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.cmdk {
  position: fixed;
  inset: 0;
  z-index: 420;
  display: flex;
  align-items: stretch;
  justify-content: center;
  padding: var(--card-pad);
  background: rgba(15, 23, 42, 0.32);
}

.cmdk__panel {
  display: flex;
  flex-direction: column;
  width: min(42rem, 100%);
  height: 100%;
  overflow: hidden;
  border: 1px solid #e4e8ec;
  border-radius: 16px;
  background: var(--color-surface);
  box-shadow: 0 18px 48px rgba(15, 23, 42, 0.12);
}

.cmdk__header {
  display: flex;
  flex-shrink: 0;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-4);
  padding: var(--card-pad) var(--space-6) var(--space-4);
  border-bottom: 1px solid #e4e8ec;
  background: var(--color-surface);
}

.cmdk__heading {
  display: flex;
  align-items: center;
  gap: var(--space-4);
  min-width: 0;
}

.cmdk__mark {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 44px;
  height: 44px;
  flex-shrink: 0;
  border-radius: var(--radius-md);
  background: var(--color-canvas);
  color: var(--color-ink-brand, var(--color-brand-500));
  box-shadow: inset 0 0 0 1px #e4e8ec;}

.cmdk__title {
  margin: 0;
  font-size: var(--text-xl);
  font-weight: 700;
  line-height: var(--leading-title);
  color: var(--color-text-primary);
}

.cmdk__subtitle {
  margin: var(--title-gap) 0 0;
  font-size: var(--text-sm);
  font-weight: 600;
  line-height: var(--line-sm);
  color: var(--color-text-muted);
}

.cmdk__close {
  display: inline-flex;
  height: var(--control-md);
  width: var(--control-md);
  min-width: var(--control-md);
  flex-shrink: 0;
  align-items: center;
  justify-content: center;
  border: 1px solid #e4e8ec;
  border-radius: var(--radius-md);
  background: var(--color-surface);
  color: var(--color-text-muted);
  font-size: var(--text-xl);
  font-weight: 600;
  line-height: 1;
  cursor: pointer;
}

.cmdk__close:hover {
  background: var(--color-table-header);
  border-color: #cfd6dc;
  color: var(--color-text-secondary);}

.cmdk__search {
  display: flex;
  flex-shrink: 0;
  align-items: center;
  gap: var(--space-3);
  margin: var(--space-4) var(--space-6) 0;
  padding: 0 var(--space-4);
  min-height: 56px;
  border: 1px solid #e4e8ec;
  border-radius: var(--radius-lg);
  background: var(--color-surface);
}

.cmdk__search:focus-within {
  border-color: #cfd6dc;
  background: var(--color-surface);
  box-shadow: 0 0 0 3px rgba(92, 127, 150, 0.1);
}

.cmdk__search-icon {
  flex-shrink: 0;
  color: var(--color-ink-brand, var(--color-brand-500));}

.cmdk__input {
  flex: 1;
  min-width: 0;
  height: 56px;
  border: 0;
  outline: none;
  background: transparent;
  font-size: 19px;
  font-weight: 600;
  line-height: 24px;
  color: var(--color-text-primary);
}

.cmdk__input::placeholder {
  font-weight: 500;
  color: var(--color-text-faint);
}

.cmdk__input::-webkit-search-cancel-button {
  display: none;
}

.cmdk__body {
  flex: 1;
  min-height: 0;
  overflow: auto;
  padding: var(--card-pad) var(--space-6) var(--space-2);
}

.cmdk__groups {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: var(--space-5) var(--space-4);
  align-content: start;
}

.cmdk__group-title {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  margin: 0 0 var(--title-gap);
  font-size: var(--text-xs);
  font-weight: 600;
  line-height: var(--line-xs);
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--color-ink-brand, var(--color-brand-500));}

.cmdk__group-title::before {
  content: "";
  width: 8px;
  height: 2px;
  border-radius: 999px;
  background: #c5d4df;
}

.cmdk__grid {
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
  margin: 0;
  padding: 0;
  list-style: none;
}

.cmdk__item {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  width: 100%;
  min-height: 52px;
  padding: var(--overlay-item-pad-y) var(--overlay-item-pad-x);
  border: 1px solid #e4e8ec;
  border-radius: var(--radius-lg);
  background: var(--color-surface);
  color: var(--color-text);
  text-align: left;
  cursor: pointer;
  transition: background 0.12s ease, border-color 0.12s ease;
}

.cmdk__item:hover {
  background: var(--color-canvas);
  border-color: #dbe3ea;}

.cmdk__item--active {
  background: #eef2f5;
  border-color: #c5d4df;
}

.cmdk__item-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 40px;
  height: 40px;
  flex-shrink: 0;
  border-radius: var(--radius-md);
  background: var(--color-canvas);
  color: var(--color-ink-brand, var(--color-brand-500));
  box-shadow: inset 0 0 0 1px #e4e8ec;}

.cmdk__item--active .cmdk__item-icon {
  background: #e4edf2;
  color: var(--color-ink-brand, var(--color-brand-600));
  box-shadow: none;}

.cmdk__label {
  min-width: 0;
  flex: 1;
  overflow: hidden;
  font-size: var(--text-md);
  font-weight: 700;
  line-height: var(--line-sm);
  color: var(--color-text-primary);
  text-overflow: ellipsis;
  white-space: nowrap;
}

.cmdk__item-arrow {
  flex-shrink: 0;
  color: var(--color-ink-brand, var(--color-brand-500));}

.cmdk__empty :deep(.empty-state__icon) {
  background: var(--color-canvas);
  color: var(--color-ink-brand, var(--color-brand-500));
  box-shadow: inset 0 0 0 1px #e4e8ec;}

.cmdk__empty :deep(.empty-state__title) {
  color: var(--color-text-muted);}

.cmdk__footer {
  display: flex;
  flex-shrink: 0;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-4);
  padding: var(--space-3) var(--space-6);
  border-top: 1px solid #e4e8ec;
  background: var(--color-surface);
}

.cmdk__shortcuts {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-4);
  font-size: var(--text-xs);
  font-weight: 600;
  color: var(--color-text-muted);
}

.cmdk__shortcuts span {
  display: inline-flex;
  align-items: center;
  gap: var(--label-gap);
}

.cmdk__chip {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 24px;
  height: 22px;
  padding: 0 var(--label-gap);
  border: 1px solid #e4e8ec;
  border-radius: 6px;
  background: var(--color-surface);
  box-shadow: none;
  font-family: var(--font-mono);
  font-size: 12px;
  font-weight: 600;
  color: var(--color-text-muted);
}

.cmdk__count {
  margin: 0;
  font-size: var(--text-xs);
  font-weight: 600;
  color: var(--color-ink-brand, var(--color-brand-500));}

.cmdk-enter-active,
.cmdk-leave-active {
  transition: opacity var(--motion-fast) var(--ease-in-out);
}

.cmdk-enter-active .cmdk__panel,
.cmdk-leave-active .cmdk__panel {
  transition: transform var(--motion-page) var(--ease-out), opacity var(--motion-page) var(--ease-in-out);
}

.cmdk-enter-from,
.cmdk-leave-to {
  opacity: 0;
}

.cmdk-enter-from .cmdk__panel,
.cmdk-leave-to .cmdk__panel {
  transform: translateY(10px) scale(0.985);
  opacity: 0;
}

@media (max-width: 767px) {
  .cmdk {
    padding: 0;
  }

  .cmdk__panel {
    border-radius: 0;
  }

  .cmdk__header,
  .cmdk__search,
  .cmdk__body,
  .cmdk__footer {
    margin-left: 0;
    margin-right: 0;
  }

  .cmdk__header,
  .cmdk__body,
  .cmdk__footer {
    padding-left: var(--space-4);
    padding-right: var(--space-4);
  }

  .cmdk__search {
    margin: var(--space-3) var(--space-4) 0;
  }

  .cmdk__subtitle,
  .cmdk__count {
    display: none;
  }

  .cmdk__groups {
    grid-template-columns: 1fr;
  }
}
</style>
