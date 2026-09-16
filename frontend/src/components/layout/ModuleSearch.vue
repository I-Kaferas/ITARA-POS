<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'

const open = ref(false)
const query = ref('')
const activeIndex = ref(0)
const inputRef = ref<HTMLInputElement | null>(null)

const { t } = useI18n()
const router = useRouter()

const modules = computed(() => [
  { to: '/admin', label: t('nav.dashboard'), group: t('nav.section.main'), keywords: 'accueil tableau board' },
  { to: '/admin/pos/overview', label: t('nav.posOverview'), group: t('nav.group.posOps'), keywords: 'apercu caisse pos dashboard' },
  { to: '/admin/pos/terminal', label: t('nav.posTerminal'), group: t('nav.group.posOps'), keywords: 'caisse encaissement vente terminal' },
  { to: '/admin/pos/shifts', label: t('nav.posShifts'), group: t('nav.group.posOps'), keywords: 'shift caisse caissier' },
  { to: '/admin/pos/reservations', label: t('nav.posReservations'), group: t('nav.group.posOps'), keywords: 'reservation table' },
  { to: '/admin/pos/orders', label: t('nav.posOrders'), group: t('nav.group.posSales'), keywords: 'commandes ventes factures tickets' },
  { to: '/admin/sales/returns', label: t('sales.tabs.returns'), group: t('nav.group.posSales'), keywords: 'retours remboursement' },
  { to: '/admin/products', label: t('nav.productCatalog'), group: t('nav.group.products'), keywords: 'produit catalogue article' },
  { to: '/admin/catalog/options', label: t('nav.productOptions'), group: t('nav.group.products'), keywords: 'options variantes taille couleur transformer' },
  { to: '/admin/catalog/beverages', label: t('nav.beverages'), group: t('nav.group.products'), keywords: 'boisson whisky verre bouteille dose bar' },
  { to: '/admin/catalog/gallery', label: t('nav.catalogGallery'), group: t('nav.group.products'), keywords: 'galerie images photos' },
  { to: '/admin/catalog/catalogs', label: t('catalog.tabs.catalogs'), group: t('nav.group.reference'), keywords: 'catalogues' },
  { to: '/admin/catalog/categories', label: t('catalog.tabs.categories'), group: t('nav.group.reference'), keywords: 'categories' },
  { to: '/admin/catalog/brands', label: t('nav.brands'), group: t('nav.group.reference'), keywords: 'marque brand crud' },
  { to: '/admin/catalog/units', label: t('nav.units'), group: t('nav.group.reference'), keywords: 'unite mesure unit kg piece' },
  { to: '/admin/catalog/attributes', label: t('nav.attributes'), group: t('nav.group.reference'), keywords: 'attributs couleur taille variantes' },
  { to: '/admin/catalog/prices', label: t('nav.priceLists'), group: t('nav.group.pricing'), keywords: 'prix tarif liste' },
  { to: '/admin/catalog/taxes', label: t('catalog.tabs.taxes'), group: t('nav.group.pricing'), keywords: 'taxes tva' },
  { to: '/admin/customers', label: t('nav.customers'), group: t('nav.section.main'), keywords: 'clients' },
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
  { to: '/admin/hospitality', label: t('nav.restaurant'), group: t('nav.section.main'), keywords: 'restaurant tables cuisine' },
  { to: '/admin/stores', label: t('nav.stores'), group: t('nav.section.main'), keywords: 'magasins' },
  { to: '/admin/inventory/stock', label: t('inventory.tabs.stock'), group: t('nav.group.stockStatus'), keywords: 'stock inventaire' },
  { to: '/admin/inventory/alerts', label: t('inventory.tabs.alerts'), group: t('nav.group.stockStatus'), keywords: 'alertes' },
  { to: '/admin/inventory/supplies', label: t('inventory.tabs.supplies'), group: t('nav.group.movements'), keywords: 'approvisionnement achat reception' },
  { to: '/admin/inventory/transfers', label: t('inventory.tabs.transfers'), group: t('nav.group.movements'), keywords: 'transferts' },
  { to: '/admin/inventory/adjustments', label: t('inventory.tabs.adjustments'), group: t('nav.group.movements'), keywords: 'ajustements' },
  { to: '/admin/inventory/issues', label: t('inventory.tabs.issues'), group: t('nav.group.movements'), keywords: 'sortie sorties issue' },
  { to: '/admin/inventory/counts', label: t('inventory.tabs.inventories'), group: t('nav.group.controls'), keywords: 'inventaire inventaires comptage' },
  { to: '/admin/inventory/verifications', label: t('inventory.tabs.verifications'), group: t('nav.group.controls'), keywords: 'verification controle anomalies' },
  { to: '/admin/inventory/batches', label: t('inventory.tabs.batches'), group: t('nav.group.traceability'), keywords: 'lots' },
  { to: '/admin/inventory/serials', label: t('inventory.tabs.serials'), group: t('nav.group.traceability'), keywords: 'series numeros' },
  { to: '/admin/suppliers', label: t('nav.suppliers'), group: t('nav.section.purchasing'), keywords: 'fournisseurs' },
  { to: '/admin/purchases/overview', label: t('purchases.hub.overview'), group: t('nav.group.purchaseCycle'), keywords: 'achats apercu dashboard' },
  { to: '/admin/purchases/requisitions', label: t('purchases.hub.requisitions'), group: t('nav.group.purchaseCycle'), keywords: 'requisition demande achat' },
  { to: '/admin/purchases/proformas', label: t('purchases.hub.proformas'), group: t('nav.group.purchaseCycle'), keywords: 'proforma' },
  { to: '/admin/purchases/orders', label: t('purchases.hub.orders'), group: t('nav.group.purchaseCycle'), keywords: 'achats commandes' },
  { to: '/admin/purchases/invoices', label: t('purchases.hub.invoices'), group: t('nav.group.purchaseBilling'), keywords: 'factures fournisseurs' },
  { to: '/admin/purchases/payments', label: t('purchases.hub.payments'), group: t('nav.group.purchaseBilling'), keywords: 'paiements fournisseurs' },
  { to: '/admin/purchases/returns', label: t('purchases.hub.returns'), group: t('nav.group.purchaseBilling'), keywords: 'retours achats' },
  { to: '/admin/expenses/dashboard', label: t('expenses.tabs.dashboard'), group: t('nav.expenses'), keywords: 'depenses dashboard' },
  { to: '/admin/expenses', label: t('expenses.tabs.list'), group: t('nav.expenses'), keywords: 'depenses charges' },
  { to: '/admin/expenses/categories', label: t('expenses.tabs.categories'), group: t('nav.expenses'), keywords: 'categories depenses' },
  { to: '/admin/expenses/reports', label: t('expenses.tabs.reports'), group: t('nav.expenses'), keywords: 'rapports depenses' },
  { to: '/admin/expenses/recurring', label: t('expenses.tabs.recurring'), group: t('nav.expenses'), keywords: 'depenses recurrentes loyer' },
  { to: '/admin/payables', label: t('nav.payables'), group: t('nav.section.purchasing'), keywords: 'dettes fournisseurs' },
  { to: '/admin/promotions', label: t('nav.promotions'), group: t('nav.section.catalog'), keywords: 'promotions remises' },
  { to: '/admin/barcodes', label: t('nav.barcodes'), group: t('nav.section.catalog'), keywords: 'code barre scanner etiquette' },
  { to: '/admin/services', label: t('nav.services'), group: t('nav.section.catalog'), keywords: 'services salon garage reparation rendez-vous' },
  { to: '/admin/reports/sales', label: t('reports.tabs.sales'), group: t('nav.reports'), keywords: 'rapports ventes' },
  { to: '/admin/reports/inventory', label: t('reports.tabs.inventory'), group: t('nav.reports'), keywords: 'rapport inventaire' },
  { to: '/admin/reports/financial', label: t('reports.tabs.financial'), group: t('nav.reports'), keywords: 'rapport finance' },
  { to: '/admin/accounting', label: t('nav.accounting'), group: t('nav.section.finance'), keywords: 'comptabilite' },
  { to: '/admin/import-export', label: t('nav.importExport'), group: t('nav.section.system'), keywords: 'import export csv' },
  { to: '/admin/sync', label: t('nav.sync'), group: t('nav.section.system'), keywords: 'synchronisation terminal mobile windows' },
  { to: '/admin/production', label: t('nav.production'), group: t('nav.section.stock'), keywords: 'production recette fabrication' },
  { to: '/admin/organization/company', label: t('org.tabs.company'), group: t('nav.group.company'), keywords: 'entreprise societe' },
  { to: '/admin/organization/branding', label: t('org.tabs.branding'), group: t('nav.group.company'), keywords: 'logo image marque branding' },
  { to: '/admin/organization/currencies', label: t('org.tabs.currencies'), group: t('nav.group.company'), keywords: 'devises' },
  { to: '/admin/organization/payment-methods', label: t('org.tabs.paymentMethods'), group: t('nav.group.company'), keywords: 'paiements' },
  { to: '/admin/organization/branches', label: t('org.tabs.branches'), group: t('nav.group.sites'), keywords: 'succursales' },
  { to: '/admin/organization/stores', label: t('org.tabs.stores'), group: t('nav.group.sites'), keywords: 'magasins org' },
  { to: '/admin/organization/warehouses', label: t('org.tabs.warehouses'), group: t('nav.group.sites'), keywords: 'entrepots' },
  { to: '/admin/organization/terminals', label: t('org.tabs.terminals'), group: t('nav.group.posHardware'), keywords: 'terminaux pos' },
  { to: '/admin/organization/devices', label: t('org.tabs.devices'), group: t('nav.group.posHardware'), keywords: 'appareils devices' },
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

watch(query, () => {
  activeIndex.value = 0
})

watch(open, async (value) => {
  if (value) {
    query.value = ''
    activeIndex.value = 0
    await nextTick()
    inputRef.value?.focus()
  }
})

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
  } else if (event.key === 'ArrowDown') {
    event.preventDefault()
    activeIndex.value = Math.min(activeIndex.value + 1, Math.max(results.value.length - 1, 0))
  } else if (event.key === 'ArrowUp') {
    event.preventDefault()
    activeIndex.value = Math.max(activeIndex.value - 1, 0)
  } else if (event.key === 'Enter') {
    event.preventDefault()
    go()
  }
}

onMounted(() => window.addEventListener('keydown', onWindowKeydown))
onBeforeUnmount(() => window.removeEventListener('keydown', onWindowKeydown))

defineExpose({ show })
</script>

<template>
  <Teleport to="body">
    <div v-if="open" class="cmdk" @click.self="close">
      <div class="cmdk__panel" role="dialog" aria-modal="true">
        <div class="cmdk__head">
          <input
            ref="inputRef"
            v-model="query"
            type="search"
            class="cmdk__input"
            :placeholder="t('command.placeholder')"
          />
          <kbd>Esc</kbd>
        </div>
        <p class="cmdk__hint">{{ t('command.hint') }}</p>
        <ul v-if="results.length" class="cmdk__list">
          <li v-for="(item, index) in results" :key="item.to">
            <button
              type="button"
              class="cmdk__item"
              :class="{ 'cmdk__item--active': index === activeIndex }"
              @mouseenter="activeIndex = index"
              @click="go(index)"
            >
              <span>
                <span class="cmdk__label">{{ item.label }}</span>
                <span class="cmdk__group">{{ item.group }}</span>
              </span>
            </button>
          </li>
        </ul>
        <p v-else class="cmdk__empty">{{ t('command.empty') }}</p>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.cmdk {
  position: fixed;
  inset: 0;
  z-index: 80;
  display: flex;
  align-items: flex-start;
  justify-content: center;
  padding: 12vh 1rem 2rem;
  background: rgba(15, 23, 42, 0.45);
}

.cmdk__panel {
  width: min(36rem, 100%);
  overflow: hidden;
  border-radius: 1rem;
  background: #fff;
  box-shadow: 0 24px 60px rgba(15, 23, 42, 0.2);
}

.cmdk__head {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.875rem 1rem;
  border-bottom: 1px solid #e2e8f0;
}

.cmdk__input {
  flex: 1;
  border: 0;
  outline: none;
  font-size: 0.95rem;
}

.cmdk__head kbd,
.cmdk__hint {
  font-size: 0.75rem;
  color: #64748b;
}

.cmdk__hint,
.cmdk__empty {
  margin: 0;
  padding: 0.5rem 1rem;
}

.cmdk__empty {
  padding-bottom: 1rem;
}

.cmdk__list {
  max-height: 22rem;
  margin: 0;
  padding: 0.35rem;
  overflow: auto;
  list-style: none;
}

.cmdk__item {
  display: flex;
  width: 100%;
  border: 0;
  border-radius: 0.65rem;
  background: transparent;
  padding: 0.65rem 0.75rem;
  text-align: left;
  cursor: pointer;
}

.cmdk__item--active {
  background: #e4edf2;
}

.cmdk__label {
  display: block;
  font-size: 0.875rem;
  font-weight: 600;
  color: #0f172a;
}

.cmdk__group {
  display: block;
  margin-top: 0.1rem;
  font-size: 0.75rem;
  color: #64748b;
}
</style>
