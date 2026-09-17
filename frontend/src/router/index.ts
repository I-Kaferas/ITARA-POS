import { createRouter, createWebHistory } from 'vue-router'
import { isAuthenticated } from '../api/client'
import { useAuthStore } from '../stores/auth'
import { useContextStore } from '../stores/context'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', redirect: '/admin' },
    {
      path: '/login',
      name: 'login',
      component: () => import('../views/admin/LoginView.vue'),
      meta: { guest: true },
    },
    {
      path: '/forgot-password',
      name: 'forgot-password',
      component: () => import('../views/admin/auth/ForgotPasswordView.vue'),
      meta: { guest: true },
    },
    {
      path: '/reset-password',
      name: 'reset-password',
      component: () => import('../views/admin/auth/ResetPasswordView.vue'),
      meta: { guest: true },
    },
    {
      path: '/sign/stay/:token',
      name: 'stay-sign',
      component: () => import('../views/public/StaySignView.vue'),
      meta: { guest: true },
    },
    {
      path: '/admin',
      component: () => import('../components/layout/AdminLayout.vue'),
      meta: { requiresAuth: true },
      children: [
        {
              path: '',
              name: 'dashboard',
              component: () => import('../views/admin/DashboardView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'products',
              name: 'products',
              component: () => import('../views/admin/ProductsView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'products/new',
              name: 'product-create',
              component: () => import('../views/admin/ProductFormView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'products/:id',
              name: 'product-edit',
              component: () => import('../views/admin/ProductFormView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'catalog/catalogs',
              name: 'catalog-catalogs',
              component: () => import('../views/admin/catalog/CatalogsView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'catalog/categories',
              name: 'catalog-categories',
              component: () => import('../views/admin/catalog/CategoriesView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'catalog/brands',
              name: 'catalog-brands',
              component: () => import('../views/admin/catalog/BrandsView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'catalog/units',
              name: 'catalog-units',
              component: () => import('../views/admin/catalog/UnitsView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'catalog/attributes',
              name: 'catalog-attributes',
              component: () => import('../views/admin/catalog/AttributesView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'catalog/taxes',
              name: 'catalog-taxes',
              component: () => import('../views/admin/catalog/TaxesView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'catalog/gallery',
              name: 'catalog-gallery',
              component: () => import('../views/admin/catalog/CatalogGalleryView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'catalog/beverages',
              name: 'catalog-beverages',
              component: () => import('../views/admin/catalog/BeveragesView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'catalog/options',
              name: 'catalog-options',
              component: () => import('../views/admin/catalog/ProductOptionsView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'catalog/prices',
              name: 'catalog-prices',
              component: () => import('../views/admin/catalog/PriceListsView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'pos',
              redirect: '/admin/pos/overview',
            },
        {
              path: 'pos/overview',
              name: 'pos-overview',
              component: () => import('../views/admin/pos/PosOverviewView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'pos/terminal',
              name: 'pos',
              component: () => import('../views/admin/pos/PosView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'pos/tables',
              name: 'pos-tables',
              redirect: '/admin/hospitality',
            },
        {
              path: 'pos/orders',
              name: 'pos-orders',
              component: () => import('../views/admin/pos/PosOrdersView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'pos/shifts',
              name: 'pos-shifts',
              component: () => import('../views/admin/pos/PosShiftsView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'pos/shifts/:id',
              name: 'pos-shift-detail',
              component: () => import('../views/admin/pos/PosShiftDetailView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'pos/reservations',
              name: 'pos-reservations',
              component: () => import('../views/admin/pos/PosReservationsView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'sales',
              name: 'sales',
              redirect: '/admin/pos/orders',
            },
        {
              path: 'sales/returns',
              name: 'sales-returns',
              component: () => import('../views/admin/sales/ReturnsView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'sales/:id',
              name: 'sale-detail',
              component: () => import('../views/admin/sales/SaleDetailView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'stores',
              name: 'stores',
              component: () => import('../views/admin/StoresView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'inventory',
              redirect: '/admin/inventory/stock',
            },
        {
              path: 'inventory/stock',
              name: 'inventory-stock',
              component: () => import('../views/admin/inventory/StockView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'inventory/supplies',
              name: 'inventory-supplies',
              component: () => import('../views/admin/inventory/SuppliesView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'inventory/transfers',
              name: 'inventory-transfers',
              component: () => import('../views/admin/inventory/TransfersView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'inventory/adjustments',
              name: 'inventory-adjustments',
              component: () => import('../views/admin/inventory/AdjustmentsView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'inventory/issues',
              name: 'inventory-issues',
              component: () => import('../views/admin/inventory/IssuesView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'inventory/verifications',
              name: 'inventory-verifications',
              component: () => import('../views/admin/inventory/VerificationsView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'inventory/counts',
              name: 'inventory-counts',
              component: () => import('../views/admin/inventory/InventoriesView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'inventory/alerts',
              name: 'inventory-alerts',
              component: () => import('../views/admin/inventory/AlertsView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'inventory/batches',
              name: 'inventory-batches',
              component: () => import('../views/admin/inventory/BatchesView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'inventory/serials',
              name: 'inventory-serials',
              component: () => import('../views/admin/inventory/SerialsView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'reports',
              redirect: '/admin/reports/sales',
            },
        {
              path: 'reports/sales',
              name: 'reports-sales',
              component: () => import('../views/admin/reports/SalesReportView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'reports/inventory',
              name: 'reports-inventory',
              component: () => import('../views/admin/reports/InventoryReportView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'reports/financial',
              name: 'reports-financial',
              component: () => import('../views/admin/reports/FinancialReportView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'expenses',
              name: 'expenses',
              component: () => import('../views/admin/expenses/ExpensesListView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'expenses/dashboard',
              name: 'expenses-dashboard',
              component: () => import('../views/admin/expenses/ExpensesDashboardView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'expenses/categories',
              name: 'expense-categories',
              component: () => import('../views/admin/expenses/ExpenseCategoriesView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'expenses/reports',
              name: 'expense-reports',
              component: () => import('../views/admin/expenses/ExpenseReportsView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'expenses/recurring',
              name: 'expense-recurring',
              component: () => import('../views/admin/expenses/RecurringExpensesView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'accounting',
              name: 'accounting',
              component: () => import('../views/admin/AccountingView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'audit',
              name: 'audit',
              component: () => import('../views/admin/AuditView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'import-export',
              name: 'import-export',
              component: () => import('../views/admin/ImportExportView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'suppliers',
              name: 'suppliers',
              component: () => import('../views/admin/suppliers/SuppliersView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'suppliers/:id',
              name: 'supplier-detail',
              component: () => import('../views/admin/suppliers/SupplierDetailView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'payables',
              name: 'payables',
              component: () => import('../views/admin/payables/PayablesView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'purchases',
              redirect: '/admin/purchases/overview',
            },
        {
              path: 'purchases/overview',
              name: 'purchase-overview',
              component: () => import('../views/admin/purchases/PurchasesOverviewView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'purchases/requisitions',
              name: 'purchase-requisitions',
              component: () => import('../views/admin/purchases/PurchaseRequisitionsView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'purchases/proformas',
              name: 'purchase-proformas',
              component: () => import('../views/admin/purchases/PurchaseProformasView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'purchases/orders',
              name: 'purchase-orders',
              component: () => import('../views/admin/purchases/PurchasesView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'purchases/orders/:id',
              name: 'purchase-order-detail',
              component: () => import('../views/admin/purchases/PurchaseOrderDetailView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'purchases/invoices',
              name: 'purchase-invoices',
              component: () => import('../views/admin/purchases/PurchasesView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'purchases/payments',
              name: 'purchase-payments',
              component: () => import('../views/admin/purchases/PurchasePaymentsView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'purchases/returns',
              name: 'purchase-returns',
              component: () => import('../views/admin/purchases/PurchaseReturnsView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'customers',
              name: 'customers',
              component: () => import('../views/admin/customers/CustomersView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'customers/:id',
              name: 'customer-detail',
              component: () => import('../views/admin/customers/CustomerDetailView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'hospitality',
              name: 'hospitality',
              component: () => import('../views/admin/HospitalityView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'hotel',
              redirect: '/admin/hotel/rooms',
            },
        {
              path: 'hotel/room-config',
              redirect: '/admin/hotel/room-config/amenities',
            },
        {
              path: 'hotel/room-config/amenities',
              name: 'hotel-room-config-amenities',
              component: () => import('../views/admin/hotel/HotelSectionView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'hotel/room-config/room-types',
              name: 'hotel-room-config-room-types',
              component: () => import('../views/admin/hotel/HotelRoomTypesView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'hotel/room-config/buildings',
              name: 'hotel-room-config-buildings',
              component: () => import('../views/admin/hotel/HotelBuildingsView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'hotel/room-config/wings',
              name: 'hotel-room-config-wings',
              component: () => import('../views/admin/hotel/HotelWingsView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'hotel/room-config/floors',
              name: 'hotel-room-config-floors',
              component: () => import('../views/admin/hotel/HotelFloorsView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'hotel/rooms',
              name: 'hotel-rooms',
              component: () => import('../views/admin/hotel/HotelRoomsView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'hotel/reservations',
              name: 'hotel-reservations',
              component: () => import('../views/admin/hotel/HotelReservationsView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'hotel/stays',
              name: 'hotel-stays',
              component: () => import('../views/admin/hotel/HotelStaysView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'hotel/invoices',
              name: 'hotel-invoices',
              component: () => import('../views/admin/hotel/HotelSectionView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'hotel/guests',
              name: 'hotel-guests',
              component: () => import('../views/admin/hotel/HotelSectionView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'hotel/housekeeping',
              name: 'hotel-housekeeping',
              component: () => import('../views/admin/hotel/HotelHousekeepingView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'hotel/calendar',
              name: 'hotel-calendar',
              component: () => import('../views/admin/hotel/HotelCalendarView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'hotel/concierge',
              name: 'hotel-concierge',
              component: () => import('../views/admin/hotel/HotelConciergeView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'hotel/reports',
              name: 'hotel-reports',
              component: () => import('../views/admin/hotel/HotelReportsView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'hotel/settings',
              name: 'hotel-settings',
              component: () => import('../views/admin/hotel/HotelSettingsView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'production',
              name: 'production',
              component: () => import('../views/admin/ProductionView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'barcodes',
              name: 'barcodes',
              component: () => import('../views/admin/BarcodesView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'sync',
              name: 'sync',
              component: () => import('../views/admin/SyncView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'services',
              name: 'services',
              component: () => import('../views/admin/ServicesView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'accompaniments',
              name: 'product-accompaniments',
              component: () => import('../views/admin/catalog/ProductAccompanimentsView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'promotions',
              name: 'promotions',
              component: () => import('../views/admin/PromotionsView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'organization',
              redirect: '/admin/organization/company',
            },
        {
              path: 'organization/company',
              name: 'org-company',
              component: () => import('../views/admin/organization/CompanySettingsView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'organization/branding',
              name: 'org-branding',
              component: () => import('../views/admin/organization/TenantBrandingView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'organization/currencies',
              name: 'org-currencies',
              component: () => import('../views/admin/organization/CurrenciesView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'organization/payment-methods',
              name: 'org-payment-methods',
              component: () => import('../views/admin/organization/PaymentMethodsView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'organization/branches',
              name: 'org-branches',
              component: () => import('../views/admin/organization/BranchesView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'organization/stores',
              name: 'org-stores',
              component: () => import('../views/admin/organization/OrgStoresView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'organization/warehouses',
              name: 'org-warehouses',
              component: () => import('../views/admin/organization/WarehousesView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'organization/terminals',
              name: 'org-terminals',
              component: () => import('../views/admin/organization/TerminalsView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'organization/devices',
              name: 'org-devices',
              component: () => import('../views/admin/organization/DevicesView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'organization/registers',
              name: 'org-registers',
              component: () => import('../views/admin/organization/CashRegistersView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'organization/users',
              name: 'org-users',
              component: () => import('../views/admin/organization/UserAssignmentView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'organization/roles',
              name: 'org-roles',
              component: () => import('../views/admin/organization/RolesView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'organization/permissions',
              name: 'org-permissions',
              component: () => import('../views/admin/organization/PermissionsView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'platform',
              name: 'platform',
              component: () => import('../views/admin/platform/PlatformView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'settings',
              name: 'settings',
              component: () => import('../views/admin/account/SettingsView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'profile',
              name: 'profile',
              component: () => import('../views/admin/account/ProfileView.vue'),
              meta: { requiresAuth: true },
            },
        {
              path: 'account',
              name: 'account',
              component: () => import('../views/admin/account/AccountSettingsView.vue'),
              meta: { requiresAuth: true },
            }
      ],
    }
  ],
})

router.beforeEach(async (to) => {
  const auth = useAuthStore()
  const context = useContextStore()

  if (to.meta.requiresAuth && !isAuthenticated()) {
    return { name: 'login' }
  }

  // Public signing links must stay reachable even when staff is logged in.
  if (to.meta.guest && isAuthenticated() && to.name !== 'stay-sign') {
    return { name: 'dashboard' }
  }

  if (isAuthenticated()) {
    if (!auth.user) {
      await auth.fetchMe()
    }
    if (auth.user?.is_super_admin && !auth.user.tenant_id && to.name !== 'platform') {
      return { name: 'platform' }
    }
    if (auth.user?.tenant_id && !context.stores.length) {
      await context.loadStores()
    }
  }

  return true
})

export default router
