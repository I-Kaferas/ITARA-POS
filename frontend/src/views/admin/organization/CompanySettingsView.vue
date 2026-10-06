<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink, useRoute, useRouter } from 'vue-router'
import { extractApiErrorMessage } from '../../../api/client'
import PageFrame from '../../../components/layout/PageFrame.vue'
import CurrenciesView from './CurrenciesView.vue'
import PaymentMethodsView from './PaymentMethodsView.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import Badge from '../../../components/ui/Badge.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { isAppLocale } from '../../../i18n/locales'
import { useAuthStore } from '../../../stores/auth'
import { useBackofficeStore } from '../../../stores/backoffice'
import { useBrandingStore } from '../../../stores/branding'
import { useContextStore } from '../../../stores/context'
import { setAppCurrency, getAppCurrency } from '../../../utils/currency'
import { countryCode, countryOptions } from '../../../utils/geo'

const { t, locale } = useI18n()
const route = useRoute()
const router = useRouter()
const store = useBackofficeStore()
const context = useContextStore()
const auth = useAuthStore()
const brandingStore = useBrandingStore()

type CompanyTab = 'general' | 'contact' | 'business' | 'pos' | 'branding' | 'users'
const TABS: CompanyTab[] = ['general', 'contact', 'business', 'pos', 'branding', 'users']
const TAB_ICONS: Record<CompanyTab, string> = {
  general: 'building',
  contact: 'pin',
  business: 'coins',
  pos: 'device-pos',
  branding: 'sparkles',
  users: 'customers',
}
const VAT_STATUSES = ['inclus', 'active', 'exempt', 'none']
const COMPANY_TYPES = ['personne_morale', 'personne_physique']

const companyId = ref('')
const companiesReady = ref(false)
const countries = computed(() => countryOptions(locale.value))
const activeTab = ref<CompanyTab>(tabFromQuery(route.query.tab))
const saving = ref(false)
const logoBusy = ref(false)
const logoError = ref('')
const invoiceLogoUrl = ref('')
const invoiceLogoBusy = ref(false)
const invoiceLogoError = ref('')
const companyLogoInput = ref<HTMLInputElement | null>(null)
const invoiceLogoInput = ref<HTMLInputElement | null>(null)
const savedFlash = ref(false)
const saveError = ref('')

function tabFromQuery(value: unknown): CompanyTab {
  return TABS.includes(value as CompanyTab) ? value as CompanyTab : 'general'
}

function yesNo(value: unknown): '' | 'yes' | 'no' {
  if (value === true || value === 'yes' || value === '1') return 'yes'
  if (value === false || value === 'no' || value === '0') return 'no'
  return ''
}

function emptyForm() {
  return {
    name: '',
    trade_name: '',
    legal_name: '',
    legal_form: '',
    tax_id: '',
    registration_number: '',
    phone: '',
    email: '',
    website: '',
    logo_url: '',
    currency_code: getAppCurrency(),
    is_active: true,
    address: {
      street: '',
      number: '',
      avenue: '',
      quarter: '',
      commune: '',
      city: '',
      province: '',
      state: '',
      postal_code: '',
      country: 'BI',
    },
    settings: {
      timezone: 'Africa/Bujumbura',
      locale: 'fr',
      receipt_footer: '',
      legal_mentions: '',
      vat_registered: '' as '' | 'yes' | 'no',
      company_type: '',
      moral_person: '',
      subject_to_tc: '' as '' | 'yes' | 'no',
      subject_to_pf: '' as '' | 'yes' | 'no',
      fiscal_center: '',
      dpmc: '',
      activity_sector: '',
      vat_status: '',
      opening_hours: '',
      is_open_now: false,
      is_verified: false,
      display_rating: '' as number | '',
      review_count: '' as number | '',
      cover_image_url: '',
      cover_image_id: '',
      latitude: -3.3822,
      longitude: 29.3644,
    },
  }
}

const form = ref(emptyForm())
const formSnapshot = ref('')

const brandForm = ref({
  brand_name: '',
  tagline: '',
  primary_color: '#12243c',
  accent_color: '#E39B2B',
  support_email: '',
  support_phone: '',
})
const brandSnapshot = ref('')

const taxName = ref('')
const taxCode = ref('')
const taxRate = ref('18')
const taxError = ref('')

const tabs = computed(() => TABS.map(id => ({
  id,
  label: t(`org.settingsPage.tabs.${id}`),
  icon: TAB_ICONS[id],
})))

const planId = computed(() => auth.user?.subscription?.plan ?? 'enterprise')
const subscriptionStatus = computed(() => auth.user?.subscription?.status ?? 'active')
const statusLabel = computed(() => {
  if (subscriptionStatus.value === 'trial') return t('subscriptionPage.statusTrial')
  if (subscriptionStatus.value === 'past_due') return t('subscriptionPage.statusPastDue')
  if (subscriptionStatus.value === 'cancelled') return t('subscriptionPage.statusCancelled')
  return t('subscriptionPage.active')
})
const statusVariant = computed(() => {
  if (subscriptionStatus.value === 'past_due') return 'warning' as const
  if (subscriptionStatus.value === 'cancelled') return 'danger' as const
  if (subscriptionStatus.value === 'trial') return 'info' as const
  return 'success' as const
})

function rememberForm() {
  formSnapshot.value = JSON.stringify(form.value)
}

function rememberBrand() {
  brandSnapshot.value = JSON.stringify(brandForm.value)
}

function selectTab(id: CompanyTab) {
  activeTab.value = id
  const tab = id === 'general' ? undefined : id
  void router.replace({ query: { ...route.query, tab } })
}

watch(() => route.query.tab, value => {
  activeTab.value = tabFromQuery(value)
})

onMounted(async () => {
  try {
    await Promise.all([
      store.loadCompanies(),
      store.loadCurrencies(true),
      store.loadTaxes(false),
      auth.fetchMe().catch(() => undefined),
      syncBrand(),
    ])
  } finally {
    if (store.companies.length && !companyId.value) companyId.value = store.companies[0].id
    companiesReady.value = true
    if (companyId.value) void store.loadPaymentMethods(companyId.value)
  }
})

watch(companyId, async (id) => {
  if (!id) return
  const company = await store.loadCompanyDetail(id)
  const fiscal = company.settings?.fiscal_center || company.settings?.dpmc || ''
  form.value = {
    name: company.name,
    trade_name: company.trade_name ?? '',
    legal_name: company.legal_name ?? '',
    legal_form: company.legal_form ?? '',
    tax_id: company.tax_id ?? '',
    registration_number: company.registration_number ?? '',
    phone: company.phone ?? '',
    email: company.email ?? '',
    website: company.website ?? '',
    logo_url: company.logo_url ?? '',
    currency_code: company.currency_code || getAppCurrency(),
    is_active: company.is_active,
    address: {
      street: company.address?.street ?? '',
      number: company.address?.number ?? '',
      avenue: company.address?.avenue ?? '',
      quarter: company.address?.quarter ?? '',
      commune: company.address?.commune ?? '',
      city: company.address?.city ?? '',
      province: company.address?.province ?? company.address?.state ?? '',
      state: company.address?.state ?? company.address?.province ?? '',
      postal_code: company.address?.postal_code ?? '',
      country: countryCode(company.address?.country) || 'BI',
    },
    settings: {
      timezone: company.settings?.timezone ?? 'Africa/Bujumbura',
      locale: isAppLocale(company.settings?.locale) ? company.settings.locale : 'fr',
      receipt_footer: company.settings?.receipt_footer ?? '',
      legal_mentions: company.settings?.legal_mentions ?? '',
      vat_registered: yesNo(company.settings?.vat_registered),
      company_type: company.settings?.company_type ?? '',
      moral_person: company.settings?.moral_person ?? '',
      subject_to_tc: yesNo(company.settings?.subject_to_tc),
      subject_to_pf: yesNo(company.settings?.subject_to_pf),
      fiscal_center: fiscal,
      dpmc: company.settings?.dpmc ?? '',
      activity_sector: company.settings?.activity_sector ?? '',
      vat_status: normalizeVat(company.settings?.vat_status ?? ''),
      opening_hours: company.settings?.opening_hours ?? '',
      is_open_now: asBool(company.settings?.is_open_now),
      is_verified: asBool(company.settings?.is_verified),
      display_rating: asOptionalNumber(company.settings?.display_rating),
      review_count: asOptionalNumber(company.settings?.review_count),
      cover_image_url: company.settings?.cover_image_url ?? '',
      cover_image_id: company.settings?.cover_image_id ?? '',
      latitude: asCoordinate(company.settings?.latitude, -3.3822),
      longitude: asCoordinate(company.settings?.longitude, 29.3644),
    },
  }
  invoiceLogoUrl.value = company.settings?.invoice_logo_url ?? ''
  rememberForm()
  void store.loadPaymentMethods(id)
}, { immediate: true })

function asBool(value: unknown) {
  return value === true || value === 1 || value === '1' || value === 'true'
}

function asOptionalNumber(value: unknown): number | '' {
  if (value === null || value === undefined || value === '') return ''
  const number = Number(value)
  return Number.isFinite(number) ? number : ''
}

function asCoordinate(value: unknown, fallback: number) {
  const number = Number(value)
  return Number.isFinite(number) ? number : fallback
}

const FALLBACK_LAT = -3.3822
const FALLBACK_LNG = 29.3644
const MAP_ZOOM = 13
const MAP_W = 640
const MAP_H = 360
const TILE = 256

const galleryOpen = ref(false)
const mapOpen = ref(false)
const coverPick = ref<{ id: string; url: string } | null>(null)

const coverPreview = computed(() => coverPick.value?.url || form.value.settings.cover_image_url)

function project(lat: number, lng: number) {
  const scale = 2 ** MAP_ZOOM * TILE
  const x = ((lng + 180) / 360) * scale
  const sine = Math.sin((lat * Math.PI) / 180)
  const y = (0.5 - Math.log((1 + sine) / (1 - sine)) / (4 * Math.PI)) * scale
  return { x, y }
}

function unproject(x: number, y: number) {
  const scale = 2 ** MAP_ZOOM * TILE
  const lng = (x / scale) * 360 - 180
  const lat = (Math.atan(Math.sinh(Math.PI * (1 - (2 * y) / scale))) * 180) / Math.PI
  return { lat, lng }
}

const mapTiles = computed(() => {
  const center = project(Number(form.value.settings.latitude) || FALLBACK_LAT, Number(form.value.settings.longitude) || FALLBACK_LNG)
  const originX = center.x - MAP_W / 2
  const originY = center.y - MAP_H / 2
  const tiles: { url: string; left: number; top: number }[] = []
  const n = 2 ** MAP_ZOOM
  const x0 = Math.floor(originX / TILE)
  const x1 = Math.floor((originX + MAP_W - 1) / TILE)
  const y0 = Math.floor(originY / TILE)
  const y1 = Math.floor((originY + MAP_H - 1) / TILE)
  for (let x = x0; x <= x1; x += 1) {
    for (let y = y0; y <= y1; y += 1) {
      if (y < 0 || y >= n) continue
      const wrapped = ((x % n) + n) % n
      tiles.push({
        url: `https://tile.openstreetmap.org/${MAP_ZOOM}/${wrapped}/${y}.png`,
        left: x * TILE - originX,
        top: y * TILE - originY,
      })
    }
  }
  return tiles
})

function onMapClick(event: MouseEvent) {
  const stage = event.currentTarget as HTMLElement
  const rect = stage.getBoundingClientRect()
  const center = project(Number(form.value.settings.latitude) || FALLBACK_LAT, Number(form.value.settings.longitude) || FALLBACK_LNG)
  const originX = center.x - rect.width / 2
  const originY = center.y - rect.height / 2
  const point = unproject(originX + event.clientX - rect.left, originY + event.clientY - rect.top)
  form.value.settings.latitude = Math.round(point.lat * 10000) / 10000
  form.value.settings.longitude = Math.round(point.lng * 10000) / 10000
}

async function openGallery() {
  galleryOpen.value = true
  if (!store.galleryImages.length) await store.loadGalleryImages()
}

function chooseCover(id: string, url: string) {
  coverPick.value = { id, url }
  galleryOpen.value = false
}

function normalizeVat(value: string) {
  const key = value.trim().toLowerCase()
  if (key === 'tva inclus' || key === 'inclus' || key === 'inclusive' || key === 'ttc') return 'inclus'
  return value
}

async function syncBrand() {
  try {
    await brandingStore.loadCurrent()
  } catch {
    return
  }
  const branding = brandingStore.branding
  if (!branding) return
  brandForm.value = {
    brand_name: branding.brand_name,
    tagline: branding.tagline,
    primary_color: branding.primary_color,
    accent_color: branding.accent_color,
    support_email: branding.support_email ?? '',
    support_phone: branding.support_phone ?? '',
  }
  rememberBrand()
}

function resetForm() {
  if (formSnapshot.value) form.value = JSON.parse(formSnapshot.value)
  if (brandSnapshot.value) brandForm.value = JSON.parse(brandSnapshot.value)
  coverPick.value = null
  saveError.value = ''
  savedFlash.value = false
}

function rejectLogo(file: File): string {
  const ext = file.name.split('.').pop()?.toLowerCase() ?? ''
  if (!['jpg', 'jpeg', 'png', 'svg'].includes(ext) || file.size > 2 * 1024 * 1024) {
    return t('org.settingsPage.logoFileError')
  }
  return ''
}

async function onLogoSelected(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  input.value = ''
  if (!file || !companyId.value) return
  const invalid = rejectLogo(file)
  if (invalid) {
    logoError.value = invalid
    return
  }

  logoBusy.value = true
  logoError.value = ''
  try {
    const saved = await store.uploadCompanyLogo(companyId.value, file)
    form.value.logo_url = saved.logo_url ?? ''
    await context.loadStores()
  } catch {
    logoError.value = t('org.logoError')
  } finally {
    logoBusy.value = false
  }
}

async function onInvoiceLogoSelected(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  input.value = ''
  if (!file || !companyId.value) return
  const invalid = rejectLogo(file)
  if (invalid) {
    invoiceLogoError.value = invalid
    return
  }

  invoiceLogoBusy.value = true
  invoiceLogoError.value = ''
  try {
    const saved = await store.uploadInvoiceLogo(companyId.value, file)
    invoiceLogoUrl.value = saved.settings?.invoice_logo_url ?? ''
  } catch {
    invoiceLogoError.value = t('org.logoError')
  } finally {
    invoiceLogoBusy.value = false
  }
}

async function removeInvoiceLogo() {
  if (!companyId.value || !invoiceLogoUrl.value) return
  invoiceLogoBusy.value = true
  invoiceLogoError.value = ''
  try {
    await store.deleteInvoiceLogo(companyId.value)
    invoiceLogoUrl.value = ''
  } catch {
    invoiceLogoError.value = t('org.logoError')
  } finally {
    invoiceLogoBusy.value = false
  }
}

async function removeLogo() {
  if (!companyId.value || !form.value.logo_url) return
  logoBusy.value = true
  logoError.value = ''
  try {
    await store.deleteCompanyLogo(companyId.value)
    form.value.logo_url = ''
    await context.loadStores()
  } catch {
    logoError.value = t('org.logoError')
  } finally {
    logoBusy.value = false
  }
}

async function addTax() {
  taxError.value = ''
  if (!taxName.value.trim() || !taxCode.value.trim()) return
  saving.value = true
  try {
    await store.saveTax({
      name: taxName.value.trim(),
      code: taxCode.value.trim().toUpperCase(),
      rate: Number(taxRate.value) || 0,
      is_inclusive: false,
      is_active: true,
    })
    taxName.value = ''
    taxCode.value = ''
    taxRate.value = '18'
    await store.loadTaxes(false)
  } catch (e) {
    taxError.value = extractApiErrorMessage(e, t('common.error'))
  } finally {
    saving.value = false
  }
}

async function save() {
  saving.value = true
  savedFlash.value = false
  saveError.value = ''
  try {
    const saved = await store.saveCompany({
      ...form.value,
      trade_name: form.value.trade_name || null,
      legal_name: form.value.legal_name || null,
      legal_form: form.value.legal_form || null,
      tax_id: form.value.tax_id || null,
      registration_number: form.value.registration_number || null,
      phone: form.value.phone || null,
      email: form.value.email || null,
      website: form.value.website || null,
      logo_url: form.value.logo_url || null,
      address: {
        ...form.value.address,
        province: form.value.address.province || null,
        state: form.value.address.province || form.value.address.state || null,
        commune: form.value.address.commune || null,
        avenue: form.value.address.avenue || null,
        quarter: form.value.address.quarter || null,
        number: form.value.address.number || null,
      },
      settings: {
        ...form.value.settings,
        vat_registered: form.value.settings.vat_registered === 'yes',
        subject_to_tc: form.value.settings.subject_to_tc === 'yes',
        subject_to_pf: form.value.settings.subject_to_pf === 'yes',
        company_type: form.value.settings.company_type || null,
        moral_person: form.value.settings.moral_person || null,
        fiscal_center: form.value.settings.fiscal_center || null,
        dpmc: form.value.settings.dpmc || form.value.settings.fiscal_center || null,
        activity_sector: form.value.settings.activity_sector || null,
        vat_status: form.value.settings.vat_status || null,
        opening_hours: form.value.settings.opening_hours || null,
        is_open_now: form.value.settings.is_open_now,
        is_verified: form.value.settings.is_verified,
        display_rating: form.value.settings.display_rating === '' ? null : Number(form.value.settings.display_rating),
        review_count: form.value.settings.review_count === '' ? null : Math.trunc(Number(form.value.settings.review_count)),
        cover_image_id: coverPick.value?.id || form.value.settings.cover_image_id || null,
        cover_image_url: coverPick.value?.url || form.value.settings.cover_image_url || null,
        latitude: Number(form.value.settings.latitude),
        longitude: Number(form.value.settings.longitude),
      },
    }, companyId.value || undefined)
    companyId.value = saved.id
    await Promise.all([
      store.loadCompanies(),
      store.loadCurrencies(),
      brandingStore.save({
        brand_name: form.value.name.trim() || brandForm.value.brand_name,
        tagline: form.value.settings.activity_sector || brandForm.value.tagline,
        primary_color: brandForm.value.primary_color,
        accent_color: brandForm.value.accent_color,
        support_email: form.value.email || brandForm.value.support_email || null,
        support_phone: form.value.phone || brandForm.value.support_phone || null,
        marketing: brandingStore.branding?.marketing,
      }).catch(() => undefined),
    ])
    setAppCurrency(form.value.currency_code)
    await context.loadStores()
    if (coverPick.value) {
      form.value.settings.cover_image_url = coverPick.value.url
      form.value.settings.cover_image_id = coverPick.value.id
      coverPick.value = null
    }
    rememberForm()
    rememberBrand()
    savedFlash.value = true
    window.setTimeout(() => { savedFlash.value = false }, 2500)
  } catch (e) {
    saveError.value = extractApiErrorMessage(e, t('common.error'))
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <PageFrame>
    <template #title>{{ t('org.settingsPage.title') }}</template>
    <template #subtitle>{{ t('org.settingsPage.subtitle') }}</template>

    <form class="co co-fill" @submit.prevent="save">
      <div class="co__toolbar">
        <p class="co__note">{{ t('org.settingsPage.note') }}</p>
        <div class="co__actions">
          <span v-if="savedFlash" class="co__saved">{{ t('common.saved') }}</span>
          <button type="button" class="btn-secondary" :disabled="saving" @click="resetForm">
            <AppIcon name="transfer" :size="15" />
            {{ t('org.settingsPage.reset') }}
          </button>
          <button type="submit" class="btn-primary" :class="{ 'is-busy': saving }" :disabled="saving">
            <AppIcon name="check" :size="15" />
            {{ saving ? t('common.saving') : t('org.settingsPage.save') }}
          </button>
        </div>
      </div>

      <p v-if="saveError" class="co__error" role="alert">{{ saveError }}</p>

      <div v-if="store.companies.length > 1" class="ui-card ui-card--compact">
        <FieldLabel icon="building">{{ t('org.company') }}</FieldLabel>
        <select v-model="companyId" class="field max-w-md">
          <option v-for="c in store.companies" :key="c.id" :value="c.id">{{ c.name }}</option>
        </select>
      </div>

      <section class="ui-card co__card">
        <nav class="co__tabs" role="tablist">
          <button
            v-for="tab in tabs"
            :key="tab.id"
            type="button"
            role="tab"
            class="co__tab"
            :class="{ 'co__tab--active': activeTab === tab.id }"
            :aria-selected="activeTab === tab.id"
            @click="selectTab(tab.id)"
          >
            <span class="co__tab-icon">
              <AppIcon :name="tab.icon" :size="18" />
            </span>
            <span>{{ tab.label }}</span>
          </button>
        </nav>

        <div class="co__panel">
          <div v-show="activeTab === 'general'" role="tabpanel">
            <h2 class="co__heading">{{ t('org.settingsPage.generalTitle') }}</h2>
            <p class="co__hint">{{ t('org.settingsPage.generalHint') }}</p>
            <div class="co__grid">
              <div>
                <FieldLabel icon="account">{{ t('org.settingsPage.companyName') }} *</FieldLabel>
                <input v-model="form.name" required class="field" />
                <p class="co__field-hint">{{ t('org.settingsPage.companyNameHint') }}</p>
              </div>
              <div>
                <FieldLabel icon="percent">{{ t('org.settingsPage.taxId') }}</FieldLabel>
                <input v-model="form.tax_id" class="field" />
                <p class="co__field-hint">{{ t('org.settingsPage.taxIdHint') }}</p>
              </div>
              <div>
                <FieldLabel icon="tag">{{ t('org.settingsPage.registrationNumber') }}</FieldLabel>
                <input v-model="form.registration_number" class="field" />
              </div>
              <div>
                <FieldLabel icon="building">{{ t('org.settingsPage.type') }}</FieldLabel>
                <select v-model="form.settings.company_type" class="field">
                  <option value="">—</option>
                  <option v-for="type in COMPANY_TYPES" :key="type" :value="type">{{ t(`org.companyTypes.${type}`) }}</option>
                  <option
                    v-if="form.settings.company_type && !COMPANY_TYPES.includes(form.settings.company_type)"
                    :value="form.settings.company_type"
                  >
                    {{ form.settings.company_type }}
                  </option>
                </select>
              </div>
              <div>
                <FieldLabel icon="percent">{{ t('org.settingsPage.vatStatus') }}</FieldLabel>
                <select v-model="form.settings.vat_status" class="field">
                  <option value="">—</option>
                  <option v-for="status in VAT_STATUSES" :key="status" :value="status">{{ t(`org.vatStatuses.${status}`) }}</option>
                  <option
                    v-if="form.settings.vat_status && !VAT_STATUSES.includes(form.settings.vat_status)"
                    :value="form.settings.vat_status"
                  >
                    {{ form.settings.vat_status }}
                  </option>
                </select>
              </div>
              <div>
                <FieldLabel icon="building">{{ t('org.settingsPage.fiscalCenter') }}</FieldLabel>
                <input v-model="form.settings.fiscal_center" class="field" />
              </div>
              <div>
                <FieldLabel icon="layers">{{ t('org.settingsPage.activitySector') }}</FieldLabel>
                <input v-model="form.settings.activity_sector" class="field" />
              </div>
              <div>
                <FieldLabel icon="percent">{{ t('org.settingsPage.subjectToTc') }}</FieldLabel>
                <select v-model="form.settings.subject_to_tc" class="field">
                  <option value="">—</option>
                  <option value="yes">{{ t('org.yes') }}</option>
                  <option value="no">{{ t('org.no') }}</option>
                </select>
              </div>
              <div>
                <FieldLabel icon="percent">{{ t('org.settingsPage.subjectToPf') }}</FieldLabel>
                <select v-model="form.settings.subject_to_pf" class="field">
                  <option value="">—</option>
                  <option value="yes">{{ t('org.yes') }}</option>
                  <option value="no">{{ t('org.no') }}</option>
                </select>
              </div>
              <div>
                <FieldLabel icon="organization">{{ t('org.settingsPage.legalForm') }}</FieldLabel>
                <input v-model="form.legal_form" class="field" />
              </div>
            </div>

            <aside class="co__plan">
              <div>
                <h3>{{ t('org.settingsPage.subscriptionTitle') }}</h3>
                <p>{{ t('org.settingsPage.subscriptionOn', { plan: planId }) }}</p>
              </div>
              <p class="co__status">
                <span>{{ t('org.settingsPage.status') }}:</span>
                <Badge :variant="statusVariant" dot>{{ statusLabel }}</Badge>
              </p>
            </aside>
          </div>

          <div v-show="activeTab === 'contact'" role="tabpanel">
            <h2 class="co__heading">{{ t('org.settingsPage.contactTitle') }}</h2>
            <p class="co__hint">{{ t('org.settingsPage.contactHint') }}</p>
            <div class="co__grid">
              <div>
                <FieldLabel icon="phone">{{ t('org.phone') }}</FieldLabel>
                <input v-model="form.phone" class="field" />
              </div>
              <div>
                <FieldLabel icon="mail">{{ t('org.email') }}</FieldLabel>
                <input v-model="form.email" type="email" class="field" />
              </div>
              <div class="co__span">
                <FieldLabel icon="conn-network">{{ t('org.website') }}</FieldLabel>
                <input v-model="form.website" class="field" />
              </div>
              <div>
                <FieldLabel icon="pin">{{ t('org.postalCode') }}</FieldLabel>
                <input v-model="form.address.postal_code" class="field" />
              </div>
              <div>
                <FieldLabel icon="store-pin">{{ t('org.province') }}</FieldLabel>
                <input v-model="form.address.province" class="field" />
              </div>
              <div>
                <FieldLabel icon="building">{{ t('org.commune') }}</FieldLabel>
                <input v-model="form.address.commune" class="field" />
              </div>
              <div>
                <FieldLabel icon="pin">{{ t('org.city') }}</FieldLabel>
                <input v-model="form.address.city" class="field" />
              </div>
              <div>
                <FieldLabel icon="pin">{{ t('org.avenue') }}</FieldLabel>
                <input v-model="form.address.avenue" class="field" />
              </div>
              <div>
                <FieldLabel icon="pin">{{ t('org.quarter') }}</FieldLabel>
                <input v-model="form.address.quarter" class="field" />
              </div>
              <div>
                <FieldLabel icon="pin">{{ t('org.street') }}</FieldLabel>
                <input v-model="form.address.street" class="field" />
              </div>
              <div>
                <FieldLabel icon="pin">{{ t('org.number') }}</FieldLabel>
                <input v-model="form.address.number" class="field" />
              </div>
              <div class="co__span">
                <FieldLabel icon="store-pin">{{ t('org.country') }}</FieldLabel>
                <select v-model="form.address.country" class="field">
                  <option v-for="country in countries" :key="country.code" :value="country.code">{{ country.name }}</option>
                </select>
              </div>
            </div>
          </div>

          <div v-show="activeTab === 'business'" role="tabpanel">
            <h2 class="co__heading">{{ t('org.settingsPage.businessTitle') }}</h2>
            <p class="co__hint">{{ t('org.settingsPage.businessHint') }}</p>
            <div class="co__grid">
              <div>
                <FieldLabel icon="account">{{ t('org.tradeName') }}</FieldLabel>
                <input v-model="form.trade_name" class="field" />
              </div>
              <div>
                <FieldLabel icon="account">{{ t('org.legalName') }}</FieldLabel>
                <input v-model="form.legal_name" class="field" />
              </div>
              <div>
                <FieldLabel icon="coins">{{ t('org.appCurrency') }}</FieldLabel>
                <select v-model="form.currency_code" required class="field">
                  <option v-for="c in store.currencies" :key="c.id" :value="c.code">
                    {{ c.code }} — {{ c.name }}{{ c.is_default ? ` (${t('org.default')})` : '' }}
                  </option>
                </select>
                <p class="co__field-hint">{{ t('org.appCurrencyHint') }}</p>
              </div>
              <div>
                <FieldLabel icon="percent">{{ t('org.vatRegistered') }}</FieldLabel>
                <select v-model="form.settings.vat_registered" class="field">
                  <option value="">—</option>
                  <option value="yes">{{ t('org.yes') }}</option>
                  <option value="no">{{ t('org.no') }}</option>
                </select>
              </div>
              <div class="co__span">
                <FieldLabel icon="note">{{ t('org.legalMentions') }}</FieldLabel>
                <textarea v-model="form.settings.legal_mentions" rows="3" class="field" />
              </div>
            </div>

            <div class="co__block">
              <h3 class="co__subhead">{{ t('org.taxesTitle') }}</h3>
              <p class="co__hint">{{ t('org.taxesHint') }}</p>
              <div class="co__table">
                <table>
                  <thead>
                    <tr>
                      <th>{{ t('org.taxName') }}</th>
                      <th>{{ t('org.code') }}</th>
                      <th>{{ t('org.taxRate') }}</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="tax in store.taxes" :key="tax.id">
                      <td>{{ tax.name }}</td>
                      <td>{{ tax.code }}</td>
                      <td>{{ tax.rate }}%</td>
                    </tr>
                  </tbody>
                </table>
                <p v-if="!store.taxes.length" class="co__empty">{{ t('org.empty') }}</p>
              </div>
              <div class="co__tax-add">
                <input v-model="taxName" class="field" :placeholder="t('org.taxName')" />
                <input v-model="taxCode" class="field" :placeholder="t('org.code')" />
                <input v-model="taxRate" class="field" inputmode="decimal" :placeholder="t('org.taxRate')" />
                <button type="button" class="btn-secondary" :disabled="saving" @click="addTax">{{ t('org.addTax') }}</button>
              </div>
              <p v-if="taxError" class="co__error">{{ taxError }}</p>
            </div>

            <div class="co__block">
              <h3 class="co__subhead">{{ t('org.tabs.currencies') }}</h3>
              <CurrenciesView embedded />
            </div>

            <label class="co__active">
              <span class="field-icon"><AppIcon name="check" :size="14" /></span>
              <input v-model="form.is_active" type="checkbox" />
              {{ t('products.active') }}
            </label>
          </div>

          <div v-show="activeTab === 'pos'" role="tabpanel">
            <h2 class="co__heading">{{ t('org.settingsPage.posTitle') }}</h2>
            <p class="co__hint">{{ t('org.settingsPage.posHint') }}</p>
            <FieldLabel icon="receipt">{{ t('org.receiptFooter') }}</FieldLabel>
            <textarea v-model="form.settings.receipt_footer" rows="3" class="field" />
            <div class="co__block">
              <h3 class="co__subhead">{{ t('org.paymentMethodsTitle') }}</h3>
              <p class="co__hint">{{ t('org.paymentMethodsHint') }}</p>
              <PaymentMethodsView embedded />
            </div>
          </div>

          <div v-show="activeTab === 'branding'" role="tabpanel">
            <h2 class="co__heading">{{ t('org.settingsPage.brandingTitle') }}</h2>
            <p class="co__hint">{{ t('org.settingsPage.brandingHint') }}</p>

            <section class="logo-block">
              <div class="logo-block__head">
                <div class="logo-preview" :class="{ 'logo-preview--empty': !form.logo_url }">
                  <img v-if="form.logo_url" :src="form.logo_url" :alt="t('org.settingsPage.companyLogo')" />
                  <span v-else>{{ t('org.settingsPage.companyLogo') }}</span>
                </div>
                <div>
                  <h3>{{ t('org.settingsPage.companyLogo') }}</h3>
                  <button type="button" class="btn-secondary" :disabled="!companyId || logoBusy" @click="companyLogoInput?.click()">
                    {{ t('org.settingsPage.changeLogo') }}
                  </button>
                </div>
              </div>
              <div class="logo-reqs">
                <p>{{ t('org.settingsPage.logoRequirements') }}</p>
                <ul>
                  <li>{{ t('org.settingsPage.logoMax') }}</li>
                  <li>{{ t('org.settingsPage.logoDimensions') }}</li>
                  <li>{{ t('org.settingsPage.logoFormats') }}</li>
                  <li>{{ t('org.settingsPage.logoSquare') }}</li>
                </ul>
              </div>
              <div class="co__actions">
                <button type="button" class="btn-primary" :disabled="!companyId || logoBusy" @click="companyLogoInput?.click()">
                  {{ logoBusy ? t('common.loading') : t('org.settingsPage.uploadNewLogo') }}
                </button>
                <button v-if="form.logo_url" type="button" class="btn-secondary" :disabled="logoBusy" @click="removeLogo">
                  {{ t('org.settingsPage.removeLogo') }}
                </button>
              </div>
              <p v-if="companiesReady && !companyId" class="co__field-hint">{{ t('org.saveBeforeLogo') }}</p>
              <p v-else-if="logoError" class="co__error">{{ logoError }}</p>
              <input
                ref="companyLogoInput"
                type="file"
                accept="image/png,image/jpeg,.svg,image/svg+xml"
                class="sr-only"
                :disabled="!companyId || logoBusy"
                @change="onLogoSelected"
              />
            </section>

            <section class="logo-block">
              <h3>{{ t('org.settingsPage.invoiceLogo') }}</h3>
              <p class="logo-block__lead">{{ t('org.settingsPage.invoiceLogoHint') }}</p>
              <div class="logo-block__head">
                <div class="logo-preview logo-preview--round" :class="{ 'logo-preview--empty': !invoiceLogoUrl }">
                  <img v-if="invoiceLogoUrl" :src="invoiceLogoUrl" alt="" />
                  <span v-else>{{ t('org.settingsPage.noInvoiceLogo') }}</span>
                </div>
                <div>
                  <button type="button" class="btn-secondary" :disabled="!companyId || invoiceLogoBusy" @click="invoiceLogoInput?.click()">
                    {{ t('org.settingsPage.changeLogo') }}
                  </button>
                </div>
              </div>
              <div class="logo-reqs">
                <p>{{ t('org.settingsPage.logoRequirements') }}</p>
                <ul>
                  <li>{{ t('org.settingsPage.logoMax') }}</li>
                  <li>{{ t('org.settingsPage.logoDimensions') }}</li>
                  <li>{{ t('org.settingsPage.logoFormats') }}</li>
                  <li>{{ t('org.settingsPage.logoSquare') }}</li>
                </ul>
              </div>
              <div class="co__actions">
                <button type="button" class="btn-primary" :disabled="!companyId || invoiceLogoBusy" @click="invoiceLogoInput?.click()">
                  {{ invoiceLogoBusy ? t('common.loading') : t('org.settingsPage.uploadInvoiceLogo') }}
                </button>
                <button v-if="invoiceLogoUrl" type="button" class="btn-secondary" :disabled="invoiceLogoBusy" @click="removeInvoiceLogo">
                  {{ t('org.settingsPage.removeLogo') }}
                </button>
              </div>
              <p v-if="invoiceLogoError" class="co__error">{{ invoiceLogoError }}</p>
              <input
                ref="invoiceLogoInput"
                type="file"
                accept="image/png,image/jpeg,.svg,image/svg+xml"
                class="sr-only"
                :disabled="!companyId || invoiceLogoBusy"
                @change="onInvoiceLogoSelected"
              />
            </section>

            <aside class="co__plan">
              <div>
                <h3>{{ t('org.settingsPage.subscriptionTitle') }}</h3>
                <p>{{ t('org.settingsPage.subscriptionOn', { plan: planId }) }}</p>
              </div>
              <p class="co__status">
                <span>{{ t('org.settingsPage.status') }}:</span>
                <Badge :variant="statusVariant" dot>{{ statusLabel }}</Badge>
              </p>
            </aside>
          </div>

          <div v-show="activeTab === 'users'" role="tabpanel">
            <h2 class="co__heading">{{ t('org.settingsPage.usersTitle') }}</h2>
            <p class="co__hint">{{ t('org.settingsPage.usersHint') }}</p>
            <p class="co__note co__note--block">{{ t('org.settingsPage.usersNote') }}</p>

            <div class="co__grid">
              <div class="co__span">
                <FieldLabel icon="calendar">{{ t('org.settingsPage.openingHours') }}</FieldLabel>
                <input v-model="form.settings.opening_hours" class="field" :placeholder="t('org.settingsPage.openingHoursPlaceholder')" />
                <p class="co__field-hint">{{ t('org.settingsPage.openingHoursHint') }}</p>
              </div>
              <div>
                <label class="co__check">
                  <input v-model="form.settings.is_open_now" type="checkbox" />
                  <span>{{ t('org.settingsPage.openNow') }}</span>
                </label>
                <p class="co__field-hint">{{ t('org.settingsPage.openNowHint') }}</p>
              </div>
              <div>
                <label class="co__check">
                  <input v-model="form.settings.is_verified" type="checkbox" />
                  <span>{{ t('org.settingsPage.verified') }}</span>
                </label>
                <p class="co__field-hint">{{ t('org.settingsPage.verifiedHint') }}</p>
              </div>
              <div>
                <FieldLabel icon="sparkles">{{ t('org.settingsPage.displayRating') }}</FieldLabel>
                <input v-model="form.settings.display_rating" class="field" type="number" min="0" max="5" step="0.1" />
                <p class="co__field-hint">{{ t('org.settingsPage.displayRatingHint') }}</p>
              </div>
              <div>
                <FieldLabel icon="customers">{{ t('org.settingsPage.reviewCount') }}</FieldLabel>
                <input v-model="form.settings.review_count" class="field" type="number" min="0" step="1" />
                <p class="co__field-hint">{{ t('org.settingsPage.reviewCountHint') }}</p>
              </div>
            </div>

            <section class="logo-block">
              <h3>{{ t('org.settingsPage.coverImage') }}</h3>
              <div class="cover-preview" :class="{ 'cover-preview--empty': !coverPreview }">
                <img v-if="coverPreview" :src="coverPreview" alt="" />
                <span v-else>{{ t('org.settingsPage.noCoverImage') }}</span>
              </div>
              <div class="co__actions">
                <button type="button" class="btn-secondary" @click="openGallery">{{ t('org.settingsPage.chooseGallery') }}</button>
              </div>
              <div class="logo-reqs">
                <p>{{ t('org.settingsPage.coverRequirements') }}</p>
                <ul>
                  <li>{{ t('org.settingsPage.coverReqPick') }}</li>
                  <li>{{ t('org.settingsPage.coverReqBanner') }}</li>
                </ul>
              </div>
              <div class="co__block">
                <FieldLabel icon="conn-network">{{ t('org.settingsPage.coverUrl') }}</FieldLabel>
                <input class="field" readonly :value="form.settings.cover_image_url || t('org.settingsPage.coverUrlEmpty')" />
                <p class="co__field-hint">{{ t('org.settingsPage.coverUrlHint') }}</p>
              </div>
            </section>

            <div class="co__grid co__block">
              <div>
                <FieldLabel icon="pin">{{ t('org.settingsPage.latitude') }}</FieldLabel>
                <input v-model.number="form.settings.latitude" class="field" type="number" step="0.0001" />
              </div>
              <div>
                <FieldLabel icon="pin">{{ t('org.settingsPage.longitude') }}</FieldLabel>
                <input v-model.number="form.settings.longitude" class="field" type="number" step="0.0001" />
              </div>
              <div class="co__span">
                <button type="button" class="btn-secondary" @click="mapOpen = true">{{ t('org.settingsPage.pickOnMap') }}</button>
                <p class="co__field-hint">{{ t('org.settingsPage.gpsFallback', { lat: form.settings.latitude, lng: form.settings.longitude }) }}</p>
              </div>
            </div>
          </div>
        </div>
      </section>
    </form>

    <AppModal :open="galleryOpen" :title="t('org.settingsPage.chooseGallery')" size="xl" @close="galleryOpen = false">
      <div v-if="store.galleryImages.length" class="cover-grid">
        <button
          v-for="image in store.galleryImages"
          :key="image.id"
          type="button"
          class="cover-grid__item"
          :class="{ 'cover-grid__item--on': coverPick?.id === image.id || form.settings.cover_image_id === image.id }"
          @click="chooseCover(image.id, image.cdn_url)"
        >
          <img :src="image.cdn_url" :alt="image.original_filename || ''" />
        </button>
      </div>
      <p v-else class="co__empty">
        <RouterLink to="/admin/catalog/gallery">{{ t('nav.catalogGallery') }}</RouterLink>
      </p>
    </AppModal>

    <AppModal :open="mapOpen" :title="t('org.settingsPage.pickOnMap')" size="lg" icon="pin" @close="mapOpen = false">
      <button type="button" class="map-stage" @click="onMapClick">
        <img v-for="(tile, index) in mapTiles" :key="index" class="map-stage__tile" :src="tile.url" alt="" :style="{ left: `${tile.left}px`, top: `${tile.top}px` }" />
        <span class="map-stage__pin" aria-hidden="true" />
      </button>
      <p class="co__field-hint">{{ t('org.settingsPage.gpsFallback', { lat: form.settings.latitude, lng: form.settings.longitude }) }}</p>
      <p class="map-stage__credit">{{ t('org.settingsPage.mapAttribution') }}</p>
    </AppModal>
  </PageFrame>
</template>

<style scoped>
.co {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  width: 100%;
  height: 100%;
  min-height: 0;
}

.co-fill {
  gap: 0;
  background: var(--color-canvas);
}

.co-fill .co__toolbar {
  padding: 0.9rem 1.25rem;
  border-bottom: 1px solid var(--color-border);
  background: var(--color-surface);
}

.co-fill .co__error {
  margin: 0.75rem 1.25rem 0;
}

.co-fill > .ui-card:not(.co__card) {
  margin: 0.75rem 1.25rem 0;
}

.co-fill .co__card {
  flex: 1;
  border: 0;
  border-radius: 0;
  box-shadow: none;
}

.co__toolbar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 0.85rem 1.25rem;
}

.co__note {
  margin: 0;
  max-width: 42rem;
  font-size: var(--text-sm);
  line-height: 1.45;
  color: var(--color-text-muted);
}

.co__note--block {
  max-width: none;
  margin-bottom: 1rem;
}

.co__actions {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.65rem;
}

.co__saved {
  font-size: var(--text-sm);
  font-weight: 650;
  color: var(--color-success, light-dark(#047857, #96c6b8));}

.co__error {
  margin: 0;
  color: var(--color-danger, light-dark(#b91c1c, #e2a0a0));
  font-size: var(--text-sm);}

.co__card {
  display: flex;
  flex: 1;
  flex-direction: column;
  min-height: 0;
  overflow: hidden;
}

.co__tabs {
  display: flex;
  gap: 0.15rem;
  overflow-x: auto;
  padding: 0 0.85rem;
  border-bottom: 1px solid var(--color-border);
  background: color-mix(in srgb, var(--color-canvas) 70%, var(--color-surface));
}

.co__tab {
  display: inline-flex;
  align-items: center;
  gap: 0.55rem;
  margin-bottom: -1px;
  border: 0;
  border-bottom: 2px solid transparent;
  background: transparent;
  padding: 0.8rem 0.9rem;
  font-size: 0.875rem;
  font-weight: 650;
  color: var(--color-text-muted);
  white-space: nowrap;
  cursor: pointer;
}

.co__tab-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 1.75rem;
  height: 1.75rem;
  flex-shrink: 0;
  border-radius: 0.45rem;
  background: color-mix(in srgb, var(--color-text-muted) 14%, transparent);
  color: var(--color-text-secondary, var(--color-text-muted));
}

.co__tab:hover {
  color: var(--color-text-primary);
}

.co__tab--active {
  color: var(--color-ink-brand, var(--color-brand-700));
  border-bottom-color: var(--color-accent);}

.co__tab--active .co__tab-icon {
  background: color-mix(in srgb, var(--color-accent) 24%, transparent);
  color: var(--color-accent);
}

.co__panel {
  flex: 1;
  min-height: 0;
  overflow: auto;
  padding: 1.35rem 1.4rem 1.5rem;
}

.co__heading,
.co__subhead {
  margin: 0;
  font-weight: 680;
  letter-spacing: -0.02em;
  color: var(--color-text-primary);
}

.co__heading {
  font-size: 1.05rem;
}

.co__subhead {
  font-size: 0.95rem;
}

.co__hint,
.co__field-hint {
  margin: 0.3rem 0 0;
  font-size: 0.82rem;
  line-height: 1.4;
  color: var(--color-text-muted);
}

.co__hint {
  margin-bottom: 1.15rem;
}

.co__grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 1rem 1.25rem;
}

.co__span {
  grid-column: 1 / -1;
}

.co__plan {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 0.85rem 1.5rem;
  margin-top: 1.5rem;
  padding: 1rem 1.15rem;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  background: color-mix(in srgb, var(--color-canvas) 55%, var(--color-surface));
}

.co__plan h3 {
  margin: 0;
  font-size: 0.95rem;
  font-weight: 700;
}

.co__plan p {
  margin: 0.25rem 0 0;
  font-size: 0.875rem;
  color: var(--color-text-muted);
}

.co__status {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin: 0;
  font-size: 0.875rem;
  font-weight: 650;
  color: var(--color-text-primary);
}

.co__block {
  margin-top: 1.5rem;
}

.co__table {
  overflow: hidden;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
}

.co__table table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.875rem;
}

.co__table th,
.co__table td {
  padding: 0.55rem 0.75rem;
  text-align: left;
}

.co__table th {
  background: color-mix(in srgb, var(--color-canvas) 70%, var(--color-surface));
  color: var(--color-text-muted);
  font-weight: 650;
}

.co__table tr + tr td {
  border-top: 1px solid var(--color-border);
}

.co__empty {
  margin: 0;
  padding: 0.85rem;
  color: var(--color-text-muted);
  font-size: 0.875rem;
}

.co__tax-add {
  display: grid;
  grid-template-columns: 1.4fr 0.8fr 0.6fr auto;
  gap: 0.65rem;
  margin-top: 0.75rem;
}

.co__active {
  display: flex;
  align-items: center;
  gap: 0.45rem;
  margin-top: 1.25rem;
  font-size: 0.875rem;
}

.co__color {
  height: 2.6rem;
  padding: 0.25rem;
}

.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  border: 0;
}

.logo-block {
  margin-top: 1rem;
  padding: 1.1rem 1.15rem 1.2rem;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  background: var(--color-surface);
}

.logo-block h3 {
  margin: 0;
  font-size: 0.95rem;
  font-weight: 700;
}

.logo-block__lead,
.logo-block__empty {
  margin: 0.35rem 0 0;
  font-size: 0.84rem;
  line-height: 1.45;
  color: var(--color-text-muted);
}

.logo-block__head {
  display: flex;
  align-items: center;
  gap: 1rem;
  margin-top: 0.85rem;
}

.logo-preview {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 5.5rem;
  height: 5.5rem;
  flex-shrink: 0;
  overflow: hidden;
  padding: 0.35rem;
  border-radius: 0.85rem;
  border: 1px dashed var(--color-border-strong, #cbd5e1);
  background: color-mix(in srgb, var(--color-canvas) 70%, var(--color-surface));
  color: var(--color-text-muted);
  font-size: 0.72rem;
  font-weight: 650;
  text-align: center;
  line-height: 1.25;
}

.logo-preview--round {
  border-radius: 999px;
}

.logo-preview img {
  width: 100%;
  height: 100%;
  object-fit: contain;
}

.logo-preview--round img {
  border-radius: 999px;
}

.logo-reqs {
  margin-top: 1rem;
}

.logo-reqs p {
  margin: 0 0 0.35rem;
  font-size: 0.84rem;
  font-weight: 700;
}

.logo-reqs ul {
  margin: 0;
  padding-left: 1.1rem;
  color: var(--color-text-muted);
  font-size: 0.84rem;
  line-height: 1.55;
}

.logo-block .co__actions {
  margin-top: 0.9rem;
}

.co__check {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.9rem;
  font-weight: 650;
}

.cover-preview {
  display: flex;
  align-items: center;
  justify-content: center;
  margin-top: 0.85rem;
  min-height: 9rem;
  overflow: hidden;
  border: 1px dashed var(--color-border-strong, #cbd5e1);
  border-radius: var(--radius-lg);
  background: color-mix(in srgb, var(--color-canvas) 70%, var(--color-surface));
  color: var(--color-text-muted);
  font-size: 0.85rem;
}

.cover-preview img {
  width: 100%;
  max-height: 16rem;
  object-fit: cover;
  aspect-ratio: 16 / 9;
}

.cover-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(8rem, 1fr));
  gap: 0.65rem;
  max-height: 24rem;
  overflow: auto;
}

.cover-grid__item {
  overflow: hidden;
  padding: 0;
  border: 1px solid var(--color-border);
  border-radius: 0.7rem;
  background: var(--color-surface);
  cursor: pointer;
}

.cover-grid__item img {
  display: block;
  width: 100%;
  aspect-ratio: 16 / 9;
  object-fit: cover;
}

.cover-grid__item--on {
  border-color: var(--color-brand-500);
  box-shadow: 0 0 0 1px color-mix(in srgb, var(--color-brand-500) 45%, transparent);
}

.map-stage {
  position: relative;
  display: block;
  width: min(100%, 640px);
  height: 360px;
  overflow: hidden;
  padding: 0;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  background: #d7e3ea;
  cursor: crosshair;
}

.map-stage__tile {
  position: absolute;
  width: 256px;
  height: 256px;
  pointer-events: none;
}

.map-stage__pin {
  position: absolute;
  left: 50%;
  top: 50%;
  width: 14px;
  height: 14px;
  border: 2px solid white;
  border-radius: 999px;
  background: #c2410c;
  transform: translate(-50%, -50%);
  box-shadow: 0 0 0 4px rgba(194, 65, 12, 0.28);
  pointer-events: none;
}

.map-stage__credit {
  margin: 0.35rem 0 0;
  font-size: 0.75rem;
  color: var(--color-text-muted);
}

.btn-ghost {
  display: inline-flex;
  align-items: center;
  border: 0;
  background: transparent;
  color: light-dark(#b45309, #d49b70);
  border-radius: 0.5rem;
  padding: 0.45rem 0.85rem;
  font-size: 0.85rem;
  font-weight: 600;
  cursor: pointer;}

.is-disabled {
  opacity: 0.55;
  pointer-events: none;
}

.locale-picker {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 0.625rem;
  margin-top: 0.45rem;
}

.locale-picker__item {
  display: flex;
  align-items: center;
  gap: 0.7rem;
  padding: 0.8rem 0.85rem;
  border: 1px solid var(--color-border);
  border-radius: 1rem;
  background: var(--color-surface);
  text-align: left;
  cursor: pointer;
}

.locale-picker__item--active {
  border-color: color-mix(in srgb, var(--color-brand-500) 42%, white);
  background: color-mix(in srgb, var(--color-brand-100, #e4edf2) 80%, white);
}

.locale-picker__flag {
  display: block;
  width: 2.15rem;
  height: 1.45rem;
  flex-shrink: 0;
  overflow: hidden;
  border-radius: 0.28rem;
}

.locale-picker__name,
.locale-picker__region {
  display: block;
}

.locale-picker__name {
  font-size: 0.875rem;
  font-weight: 650;
  color: var(--color-text-primary);
}

.locale-picker__region {
  margin-top: 0.15rem;
  font-size: 0.6875rem;
  color: var(--color-text-muted);
}

@media (max-width: 760px) {
  .co__grid,
  .co__tax-add,
  .locale-picker {
    grid-template-columns: 1fr;
  }
}
</style>
