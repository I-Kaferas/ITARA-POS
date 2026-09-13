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
      path: '/admin',
      name: 'dashboard',
      component: () => import('../views/admin/DashboardView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/products',
      name: 'products',
      component: () => import('../views/admin/ProductsView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/products/new',
      name: 'product-create',
      component: () => import('../views/admin/ProductFormView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/products/:id',
      name: 'product-edit',
      component: () => import('../views/admin/ProductFormView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/catalog/catalogs',
      name: 'catalog-catalogs',
      component: () => import('../views/admin/catalog/CatalogsView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/catalog/categories',
      name: 'catalog-categories',
      component: () => import('../views/admin/catalog/CategoriesView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/catalog/brands',
      name: 'catalog-brands',
      component: () => import('../views/admin/catalog/BrandsView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/catalog/units',
      name: 'catalog-units',
      component: () => import('../views/admin/catalog/UnitsView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/catalog/attributes',
      name: 'catalog-attributes',
      component: () => import('../views/admin/catalog/AttributesView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/catalog/taxes',
      name: 'catalog-taxes',
      component: () => import('../views/admin/catalog/TaxesView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/catalog/gallery',
      name: 'catalog-gallery',
      component: () => import('../views/admin/catalog/CatalogGalleryView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/catalog/beverages',
      name: 'catalog-beverages',
      component: () => import('../views/admin/catalog/BeveragesView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/catalog/options',
      name: 'catalog-options',
      component: () => import('../views/admin/catalog/ProductOptionsView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/catalog/prices',
      name: 'catalog-prices',
      component: () => import('../views/admin/catalog/PriceListsView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/pos',
      redirect: '/admin/pos/overview',
    },
    {
      path: '/admin/pos/overview',
      name: 'pos-overview',
      component: () => import('../views/admin/pos/PosOverviewView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/pos/terminal',
      name: 'pos',
      component: () => import('../views/admin/pos/PosView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/pos/orders',
      name: 'pos-orders',
      component: () => import('../views/admin/pos/PosOrdersView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/pos/shifts',
      name: 'pos-shifts',
      component: () => import('../views/admin/pos/PosShiftsView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/pos/shifts/:id',
      name: 'pos-shift-detail',
      component: () => import('../views/admin/pos/PosShiftDetailView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/pos/reservations',
      name: 'pos-reservations',
      component: () => import('../views/admin/pos/PosReservationsView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/sales',
      name: 'sales',
      redirect: '/admin/pos/orders',
    },
    {
      path: '/admin/sales/returns',
      name: 'sales-returns',
      component: () => import('../views/admin/sales/ReturnsView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/sales/:id',
      name: 'sale-detail',
      component: () => import('../views/admin/sales/SaleDetailView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/stores',
      name: 'stores',
      component: () => import('../views/admin/StoresView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/inventory',
      redirect: '/admin/inventory/stock',
    },
    {
      path: '/admin/inventory/stock',
      name: 'inventory-stock',
      component: () => import('../views/admin/inventory/StockView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/inventory/supplies',
      name: 'inventory-supplies',
      component: () => import('../views/admin/inventory/SuppliesView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/inventory/transfers',
      name: 'inventory-transfers',
      component: () => import('../views/admin/inventory/TransfersView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/inventory/adjustments',
      name: 'inventory-adjustments',
      component: () => import('../views/admin/inventory/AdjustmentsView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/inventory/issues',
      name: 'inventory-issues',
      component: () => import('../views/admin/inventory/IssuesView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/inventory/verifications',
      name: 'inventory-verifications',
      component: () => import('../views/admin/inventory/VerificationsView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/inventory/counts',
      name: 'inventory-counts',
      component: () => import('../views/admin/inventory/InventoriesView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/inventory/alerts',
      name: 'inventory-alerts',
      component: () => import('../views/admin/inventory/AlertsView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/inventory/batches',
      name: 'inventory-batches',
      component: () => import('../views/admin/inventory/BatchesView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/inventory/serials',
      name: 'inventory-serials',
      component: () => import('../views/admin/inventory/SerialsView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/reports',
      redirect: '/admin/reports/sales',
    },
    {
      path: '/admin/reports/sales',
      name: 'reports-sales',
      component: () => import('../views/admin/reports/SalesReportView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/reports/inventory',
      name: 'reports-inventory',
      component: () => import('../views/admin/reports/InventoryReportView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/reports/financial',
      name: 'reports-financial',
      component: () => import('../views/admin/reports/FinancialReportView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/expenses',
      name: 'expenses',
      component: () => import('../views/admin/expenses/ExpensesListView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/expenses/dashboard',
      name: 'expenses-dashboard',
      component: () => import('../views/admin/expenses/ExpensesDashboardView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/expenses/categories',
      name: 'expense-categories',
      component: () => import('../views/admin/expenses/ExpenseCategoriesView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/expenses/reports',
      name: 'expense-reports',
      component: () => import('../views/admin/expenses/ExpenseReportsView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/expenses/recurring',
      name: 'expense-recurring',
      component: () => import('../views/admin/expenses/RecurringExpensesView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/accounting',
      name: 'accounting',
      component: () => import('../views/admin/AccountingView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/audit',
      name: 'audit',
      component: () => import('../views/admin/AuditView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/import-export',
      name: 'import-export',
      component: () => import('../views/admin/ImportExportView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/suppliers',
      name: 'suppliers',
      component: () => import('../views/admin/suppliers/SuppliersView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/suppliers/:id',
      name: 'supplier-detail',
      component: () => import('../views/admin/suppliers/SupplierDetailView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/payables',
      name: 'payables',
      component: () => import('../views/admin/payables/PayablesView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/purchases',
      redirect: '/admin/purchases/overview',
    },
    {
      path: '/admin/purchases/overview',
      name: 'purchase-overview',
      component: () => import('../views/admin/purchases/PurchasesOverviewView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/purchases/requisitions',
      name: 'purchase-requisitions',
      component: () => import('../views/admin/purchases/PurchaseRequisitionsView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/purchases/proformas',
      name: 'purchase-proformas',
      component: () => import('../views/admin/purchases/PurchaseProformasView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/purchases/orders',
      name: 'purchase-orders',
      component: () => import('../views/admin/purchases/PurchasesView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/purchases/orders/:id',
      name: 'purchase-order-detail',
      component: () => import('../views/admin/purchases/PurchaseOrderDetailView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/purchases/invoices',
      name: 'purchase-invoices',
      component: () => import('../views/admin/purchases/PurchasesView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/purchases/payments',
      name: 'purchase-payments',
      component: () => import('../views/admin/purchases/PurchasePaymentsView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/purchases/returns',
      name: 'purchase-returns',
      component: () => import('../views/admin/purchases/PurchaseReturnsView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/customers',
      name: 'customers',
      component: () => import('../views/admin/customers/CustomersView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/customers/:id',
      name: 'customer-detail',
      component: () => import('../views/admin/customers/CustomerDetailView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/promotions',
      name: 'promotions',
      component: () => import('../views/admin/PromotionsView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/organization',
      redirect: '/admin/organization/company',
    },
    {
      path: '/admin/organization/company',
      name: 'org-company',
      component: () => import('../views/admin/organization/CompanySettingsView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/organization/branding',
      name: 'org-branding',
      component: () => import('../views/admin/organization/TenantBrandingView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/organization/currencies',
      name: 'org-currencies',
      component: () => import('../views/admin/organization/CurrenciesView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/organization/payment-methods',
      name: 'org-payment-methods',
      component: () => import('../views/admin/organization/PaymentMethodsView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/organization/branches',
      name: 'org-branches',
      component: () => import('../views/admin/organization/BranchesView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/organization/stores',
      name: 'org-stores',
      component: () => import('../views/admin/organization/OrgStoresView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/organization/warehouses',
      name: 'org-warehouses',
      component: () => import('../views/admin/organization/WarehousesView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/organization/terminals',
      name: 'org-terminals',
      component: () => import('../views/admin/organization/TerminalsView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/organization/devices',
      name: 'org-devices',
      component: () => import('../views/admin/organization/DevicesView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/organization/registers',
      name: 'org-registers',
      component: () => import('../views/admin/organization/CashRegistersView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/organization/users',
      name: 'org-users',
      component: () => import('../views/admin/organization/UserAssignmentView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/organization/roles',
      name: 'org-roles',
      component: () => import('../views/admin/organization/RolesView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/organization/permissions',
      name: 'org-permissions',
      component: () => import('../views/admin/organization/PermissionsView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/settings',
      name: 'settings',
      component: () => import('../views/admin/account/SettingsView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/profile',
      name: 'profile',
      component: () => import('../views/admin/account/ProfileView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/admin/account',
      name: 'account',
      component: () => import('../views/admin/account/AccountSettingsView.vue'),
      meta: { requiresAuth: true },
    },
  ],
})

router.beforeEach(async (to) => {
  const auth = useAuthStore()
  const context = useContextStore()

  if (to.meta.requiresAuth && !isAuthenticated()) {
    return { name: 'login' }
  }

  if (to.meta.guest && isAuthenticated()) {
    return { name: 'dashboard' }
  }

  if (isAuthenticated()) {
    if (!auth.user) {
      await auth.fetchMe()
    }
    if (!context.stores.length) {
      await context.loadStores()
    }
  }

  return true
})

export default router
