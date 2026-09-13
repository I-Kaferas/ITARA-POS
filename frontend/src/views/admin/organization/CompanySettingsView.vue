<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { extractApiErrorMessage } from '../../../api/client'
import OrganizationLayout from '../../../components/organization/OrganizationLayout.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import { useContextStore } from '../../../stores/context'
import { LOCALE_META, SUPPORTED_LOCALES, isAppLocale } from '../../../i18n/locales'
import LanguageFlag from '../../../components/ui/LanguageFlag.vue'
import { setAppCurrency } from '../../../utils/currency'
import { countryCode, countryOptions, timezones } from '../../../utils/geo'

const { t, locale } = useI18n()
const store = useBackofficeStore()
const context = useContextStore()

type CompanyTab = 'identity' | 'contact' | 'address' | 'invoices' | 'taxes'

const companyId = ref('')
const countries = computed(() => countryOptions(locale.value))
const timezoneOptions = timezones()
const activeTab = ref<CompanyTab>('identity')
const saving = ref(false)
const logoBusy = ref(false)
const logoError = ref('')
const savedFlash = ref(false)

function yesNo(value: unknown): '' | 'yes' | 'no' {
  if (value === true || value === 'yes' || value === '1') return 'yes'
  if (value === false || value === 'no' || value === '0') return 'no'
  return ''
}

const form = ref({
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
  currency_code: 'FBU',
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
  },
})

const taxName = ref('')
const taxCode = ref('')
const taxRate = ref('18')
const taxError = ref('')

const tabs = computed(() => [
  { id: 'identity' as const, label: t('org.identity') },
  { id: 'contact' as const, label: t('org.contact') },
  { id: 'address' as const, label: t('org.address') },
  { id: 'invoices' as const, label: t('org.receiptSettings') },
  { id: 'taxes' as const, label: t('org.taxesTitle') },
])

onMounted(async () => {
  await Promise.all([store.loadCompanies(), store.loadCurrencies(true), store.loadTaxes(false)])
  if (store.companies.length) companyId.value = store.companies[0].id
})

watch(companyId, async (id) => {
  if (!id) return
  activeTab.value = 'identity'
  const company = await store.loadCompanyDetail(id)
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
    currency_code: company.currency_code || 'FBU',
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
      fiscal_center: company.settings?.fiscal_center ?? '',
      dpmc: company.settings?.dpmc ?? '',
      activity_sector: company.settings?.activity_sector ?? '',
      vat_status: company.settings?.vat_status ?? '',
    },
  }
}, { immediate: true })

async function onLogoSelected(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  input.value = ''
  if (!file || !companyId.value) return

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
        dpmc: form.value.settings.dpmc || null,
        activity_sector: form.value.settings.activity_sector || null,
        vat_status: form.value.settings.vat_status || null,
      },
    }, companyId.value || undefined)
    companyId.value = saved.id
    await store.loadCompanies()
    setAppCurrency(form.value.currency_code)
    await context.loadStores()
    savedFlash.value = true
    window.setTimeout(() => { savedFlash.value = false }, 2500)
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <OrganizationLayout>
    <div class="mx-auto max-w-4xl space-y-5">
      <div v-if="store.companies.length > 1" class="rounded-xl bg-white p-4 shadow-sm ring-1 ring-slate-200">
        <label class="mb-1 block text-sm font-medium">{{ t('org.company') }}</label>
        <select v-model="companyId" class="field max-w-md">
          <option v-for="c in store.companies" :key="c.id" :value="c.id">{{ c.name }}</option>
        </select>
      </div>

      <form class="overflow-hidden rounded-2xl bg-white shadow-sm ring-1 ring-slate-200" @submit.prevent="save">
        <div class="border-b border-slate-200 bg-slate-50/80 px-4 pt-3 sm:px-5">
          <nav class="flex flex-wrap gap-1" role="tablist">
            <button
              v-for="tab in tabs"
              :key="tab.id"
              type="button"
              role="tab"
              class="company-tab"
              :class="{ 'company-tab--active': activeTab === tab.id }"
              :aria-selected="activeTab === tab.id"
              @click="activeTab = tab.id"
            >
              {{ tab.label }}
            </button>
          </nav>
        </div>

        <div class="p-5 sm:p-6">
          <div v-show="activeTab === 'identity'" class="space-y-4" role="tabpanel">
            <div class="brand-card">
              <div class="brand-card__preview">
                <img v-if="form.logo_url" :src="form.logo_url" :alt="form.name" />
                <span v-else>{{ t('org.logo') }}</span>
              </div>
              <div class="min-w-0 flex-1">
                <p class="m-0 text-sm font-semibold text-slate-800">{{ t('org.invoiceBranding') }}</p>
                <p class="mt-1 mb-3 text-sm text-slate-500">{{ t('org.invoiceBrandingHint') }}</p>
                <div class="flex flex-wrap items-center gap-2">
                  <label class="btn-secondary" :class="{ 'is-disabled': !companyId || logoBusy }">
                    {{ logoBusy ? t('common.loading') : t('org.uploadLogo') }}
                    <input
                      type="file"
                      accept="image/png,image/jpeg,image/webp,image/gif"
                      class="sr-only"
                      :disabled="!companyId || logoBusy"
                      @change="onLogoSelected"
                    />
                  </label>
                  <button
                    v-if="form.logo_url"
                    type="button"
                    class="btn-ghost"
                    :disabled="logoBusy"
                    @click="removeLogo"
                  >
                    {{ t('org.removeLogo') }}
                  </button>
                </div>
                <p v-if="!companyId" class="mt-2 mb-0 text-xs text-slate-500">{{ t('org.saveBeforeLogo') }}</p>
                <p v-else-if="logoError" class="mt-2 mb-0 text-xs text-red-600">{{ logoError }}</p>
              </div>
            </div>
            <div class="grid gap-4 sm:grid-cols-2">
              <div class="sm:col-span-2">
                <label class="mb-1 block text-sm font-medium">{{ t('org.name') }} *</label>
                <input v-model="form.name" required class="field" />
                <p class="mt-1 mb-0 text-xs text-slate-500">{{ t('org.nameInvoiceHint') }}</p>
              </div>
              <div>
                <label class="mb-1 block text-sm font-medium">{{ t('org.taxId') }}</label>
                <input v-model="form.tax_id" class="field" />
              </div>
              <div>
                <label class="mb-1 block text-sm font-medium">{{ t('org.companyType') }} *</label>
                <select v-model="form.settings.company_type" required class="field">
                  <option value="">—</option>
                  <option value="personne_morale">{{ t('org.companyTypes.personne_morale') }}</option>
                  <option value="personne_physique">{{ t('org.companyTypes.personne_physique') }}</option>
                </select>
              </div>
              <div>
                <label class="mb-1 block text-sm font-medium">{{ t('org.moralPerson') }}</label>
                <input v-model="form.settings.moral_person" class="field" />
              </div>
              <div>
                <label class="mb-1 block text-sm font-medium">{{ t('org.registrationNumber') }}</label>
                <input v-model="form.registration_number" class="field" />
              </div>
              <div>
                <label class="mb-1 block text-sm font-medium">{{ t('org.vatRegistered') }} *</label>
                <select v-model="form.settings.vat_registered" required class="field">
                  <option value="">—</option>
                  <option value="yes">{{ t('org.yes') }}</option>
                  <option value="no">{{ t('org.no') }}</option>
                </select>
              </div>
              <div>
                <label class="mb-1 block text-sm font-medium">{{ t('org.subjectToTc') }} *</label>
                <select v-model="form.settings.subject_to_tc" required class="field">
                  <option value="">—</option>
                  <option value="yes">{{ t('org.yes') }}</option>
                  <option value="no">{{ t('org.no') }}</option>
                </select>
              </div>
              <div>
                <label class="mb-1 block text-sm font-medium">{{ t('org.subjectToPf') }} *</label>
                <select v-model="form.settings.subject_to_pf" required class="field">
                  <option value="">—</option>
                  <option value="yes">{{ t('org.yes') }}</option>
                  <option value="no">{{ t('org.no') }}</option>
                </select>
              </div>
              <div>
                <label class="mb-1 block text-sm font-medium">{{ t('org.fiscalCenter') }} *</label>
                <input v-model="form.settings.fiscal_center" required class="field" />
              </div>
              <div>
                <label class="mb-1 block text-sm font-medium">{{ t('org.dpmc') }}</label>
                <input v-model="form.settings.dpmc" class="field" />
              </div>
              <div>
                <label class="mb-1 block text-sm font-medium">{{ t('org.activitySector') }}</label>
                <input v-model="form.settings.activity_sector" class="field" />
              </div>
              <div>
                <label class="mb-1 block text-sm font-medium">{{ t('org.legalForm') }}</label>
                <input v-model="form.legal_form" class="field" />
              </div>
              <div>
                <label class="mb-1 block text-sm font-medium">{{ t('org.vatStatus') }}</label>
                <select v-model="form.settings.vat_status" class="field">
                  <option value="">—</option>
                  <option value="active">{{ t('org.vatStatuses.active') }}</option>
                  <option value="exempt">{{ t('org.vatStatuses.exempt') }}</option>
                  <option value="none">{{ t('org.vatStatuses.none') }}</option>
                </select>
              </div>
              <div>
                <label class="mb-1 block text-sm font-medium">{{ t('org.tradeName') }}</label>
                <input v-model="form.trade_name" class="field" />
              </div>
              <div>
                <label class="mb-1 block text-sm font-medium">{{ t('org.legalName') }}</label>
                <input v-model="form.legal_name" class="field" />
              </div>
              <div>
                <label class="mb-1 block text-sm font-medium">{{ t('org.currency') }}</label>
                <select v-model="form.currency_code" required class="field">
                  <option v-for="c in store.currencies" :key="c.id" :value="c.code">
                    {{ c.code }} — {{ c.name }}{{ c.is_default ? ` (${t('org.default')})` : '' }}
                  </option>
                </select>
              </div>
            </div>
          </div>

          <div v-show="activeTab === 'contact'" class="space-y-4" role="tabpanel">
            <div class="grid gap-4 sm:grid-cols-2">
              <div>
                <label class="mb-1 block text-sm font-medium">{{ t('org.phone') }}</label>
                <input v-model="form.phone" class="field" />
              </div>
              <div>
                <label class="mb-1 block text-sm font-medium">{{ t('org.email') }}</label>
                <input v-model="form.email" type="email" class="field" />
              </div>
              <div class="sm:col-span-2">
                <label class="mb-1 block text-sm font-medium">{{ t('org.website') }}</label>
                <input v-model="form.website" class="field" />
              </div>
            </div>
          </div>

          <div v-show="activeTab === 'address'" class="space-y-4" role="tabpanel">
            <div class="grid gap-4 sm:grid-cols-2">
              <div>
                <label class="mb-1 block text-sm font-medium">{{ t('org.postalCode') }}</label>
                <input v-model="form.address.postal_code" class="field" />
              </div>
              <div>
                <label class="mb-1 block text-sm font-medium">{{ t('org.province') }}</label>
                <input v-model="form.address.province" class="field" />
              </div>
              <div>
                <label class="mb-1 block text-sm font-medium">{{ t('org.commune') }}</label>
                <input v-model="form.address.commune" class="field" />
              </div>
              <div>
                <label class="mb-1 block text-sm font-medium">{{ t('org.avenue') }}</label>
                <input v-model="form.address.avenue" class="field" />
              </div>
              <div>
                <label class="mb-1 block text-sm font-medium">{{ t('org.quarter') }}</label>
                <input v-model="form.address.quarter" class="field" />
              </div>
              <div>
                <label class="mb-1 block text-sm font-medium">{{ t('org.street') }}</label>
                <input v-model="form.address.street" class="field" />
              </div>
              <div>
                <label class="mb-1 block text-sm font-medium">{{ t('org.number') }}</label>
                <input v-model="form.address.number" class="field" />
              </div>
              <div class="sm:col-span-2">
                <label class="mb-1 block text-sm font-medium">{{ t('org.country') }}</label>
                <select v-model="form.address.country" class="field">
                  <option v-for="country in countries" :key="country.code" :value="country.code">{{ country.name }}</option>
                </select>
              </div>
            </div>
          </div>

          <div v-show="activeTab === 'taxes'" class="space-y-4" role="tabpanel">
            <p class="text-sm text-slate-600">{{ t('org.taxesHint') }}</p>
            <div class="overflow-hidden rounded-xl ring-1 ring-slate-200">
              <table class="min-w-full text-sm">
                <thead class="bg-slate-50 text-left text-slate-500">
                  <tr>
                    <th class="px-3 py-2 font-medium">{{ t('org.taxName') }}</th>
                    <th class="px-3 py-2 font-medium">{{ t('org.code') }}</th>
                    <th class="px-3 py-2 font-medium">{{ t('org.taxRate') }}</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="tax in store.taxes" :key="tax.id" class="border-t border-slate-100">
                    <td class="px-3 py-2">{{ tax.name }}</td>
                    <td class="px-3 py-2">{{ tax.code }}</td>
                    <td class="px-3 py-2">{{ tax.rate }}%</td>
                  </tr>
                </tbody>
              </table>
              <p v-if="!store.taxes.length" class="px-3 py-4 text-sm text-slate-500">{{ t('org.empty') }}</p>
            </div>
            <div class="grid gap-3 sm:grid-cols-4">
              <input v-model="taxName" class="field sm:col-span-2" :placeholder="t('org.taxName')" />
              <input v-model="taxCode" class="field" :placeholder="t('org.code')" />
              <input v-model="taxRate" class="field" inputmode="decimal" :placeholder="t('org.taxRate')" />
            </div>
            <p v-if="taxError" class="text-sm text-red-700">{{ taxError }}</p>
            <button type="button" class="btn-secondary" :disabled="saving" @click="addTax">{{ t('org.addTax') }}</button>
          </div>

          <div v-show="activeTab === 'invoices'" class="space-y-4" role="tabpanel">
            <div class="grid gap-4 sm:grid-cols-2">
              <div>
                <label class="mb-1 block text-sm font-medium">{{ t('org.timezone') }}</label>
                <select v-model="form.settings.timezone" class="field">
                  <option v-for="zone in timezoneOptions" :key="zone.id" :value="zone.id">{{ zone.label }}</option>
                </select>
              </div>
              <div class="sm:col-span-2">
                <p class="mb-2 text-sm font-medium">{{ t('org.locale') }}</p>
                <div class="locale-picker" role="radiogroup" :aria-label="t('org.locale')">
                  <button
                    v-for="code in SUPPORTED_LOCALES"
                    :key="code"
                    type="button"
                    class="locale-picker__item"
                    :class="{ 'locale-picker__item--active': form.settings.locale === code }"
                    role="radio"
                    :aria-checked="form.settings.locale === code"
                    @click="form.settings.locale = code"
                  >
                    <span class="locale-picker__flag" aria-hidden="true">
                      <LanguageFlag :locale="code" />
                    </span>
                    <span>
                      <span class="locale-picker__name">{{ LOCALE_META[code].native }}</span>
                      <span class="locale-picker__region">{{ LOCALE_META[code].region }}</span>
                    </span>
                  </button>
                </div>
              </div>
              <div class="sm:col-span-2">
                <label class="mb-1 block text-sm font-medium">{{ t('org.receiptFooter') }}</label>
                <textarea v-model="form.settings.receipt_footer" rows="3" class="field" />
              </div>
              <div class="sm:col-span-2">
                <label class="mb-1 block text-sm font-medium">{{ t('org.legalMentions') }}</label>
                <textarea v-model="form.settings.legal_mentions" rows="3" class="field" />
              </div>
            </div>
          </div>
        </div>

        <div class="flex flex-wrap items-center justify-between gap-3 border-t border-slate-100 bg-slate-50/60 px-5 py-4">
          <label class="flex items-center gap-2 text-sm">
            <input v-model="form.is_active" type="checkbox" class="rounded" />
            {{ t('products.active') }}
            <StatusBadge :active="form.is_active" />
          </label>
          <div class="flex items-center gap-3">
            <span v-if="savedFlash" class="text-sm font-medium text-emerald-600">{{ t('common.saved') }}</span>
            <button type="submit" class="btn-primary" :disabled="saving">
              {{ saving ? t('common.loading') : t('common.save') }}
            </button>
          </div>
        </div>
      </form>
    </div>
  </OrganizationLayout>
</template>

<style scoped>
.field {
  width: 100%;
  border-radius: 0.5rem;
  border: 1px solid #cbd5e1;
  padding: 0.5rem 0.75rem;
  background: white;
}

.btn-primary {
  border-radius: 0.5rem;
  padding: 0.5rem 1rem;
  font-weight: 500;
  color: white;
  background-color: var(--color-brand-600);
}

.btn-primary:disabled {
  opacity: 0.6;
  cursor: not-allowed;
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

.brand-card {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 1rem;
  border: 1px solid #e2e8f0;
  border-radius: 0.9rem;
  background: #f8fafc;
}

.brand-card__preview {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 5.5rem;
  height: 5.5rem;
  flex-shrink: 0;
  overflow: hidden;
  border-radius: 0.75rem;
  border: 1px dashed #cbd5e1;
  background: white;
  color: #94a3b8;
  font-size: 0.75rem;
  font-weight: 650;
}

.brand-card__preview img {
  width: 100%;
  height: 100%;
  object-fit: contain;
}

.btn-secondary,
.btn-ghost {
  display: inline-flex;
  align-items: center;
  border-radius: 0.5rem;
  padding: 0.45rem 0.85rem;
  font-size: 0.85rem;
  font-weight: 550;
  cursor: pointer;
}

.btn-secondary {
  border: 1px solid #cbd5e1;
  background: white;
  color: #1c2830;
}

.btn-ghost {
  border: 0;
  background: transparent;
  color: #b45309;
}

.is-disabled {
  opacity: 0.55;
  pointer-events: none;
}

.company-tab {
  margin-bottom: -1px;
  border-radius: 0.625rem 0.625rem 0 0;
  padding: 0.65rem 1rem;
  font-size: 0.8125rem;
  font-weight: 600;
  color: #64748b;
  border: 1px solid transparent;
  border-bottom: none;
  transition: color 0.15s ease, background 0.15s ease;
}

.company-tab:hover {
  color: #0f172a;
  background: rgba(255, 255, 255, 0.7);
}

.company-tab--active {
  color: var(--color-brand-700);
  background: white;
  border-color: #e2e8f0;
}

.locale-picker {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 0.625rem;
}

.locale-picker__item {
  position: relative;
  display: flex;
  align-items: center;
  gap: 0.7rem;
  padding: 0.8rem 0.85rem;
  border: 1px solid #e6e8ee;
  border-radius: 1rem;
  background: #fff;
  text-align: left;
  cursor: pointer;
  box-shadow: 0 1px 0 rgba(255, 255, 255, 0.9) inset;
  transition: border-color 0.16s ease, box-shadow 0.16s ease, transform 0.16s ease;
}

.locale-picker__item:hover {
  border-color: #d7dbe6;
  transform: translateY(-1px);
}

.locale-picker__item--active {
  border-color: color-mix(in srgb, var(--color-brand-500) 42%, white);
  background: #e4edf2;
  box-shadow:
    0 0 0 3px rgba(74, 109, 134, 0.12),
    0 1px 0 rgba(255, 255, 255, 0.9) inset;
}

.locale-picker__flag {
  display: block;
  width: 2.15rem;
  height: 1.45rem;
  flex-shrink: 0;
  overflow: hidden;
  border-radius: 0.28rem;
  border: 1px solid rgba(15, 23, 42, 0.12);
}

.locale-picker__name,
.locale-picker__region {
  display: block;
}

.locale-picker__name {
  font-family: var(--font-display);
  font-size: 0.875rem;
  font-weight: 600;
  letter-spacing: -0.02em;
  color: #0f172a;
  line-height: 1.15;
}

.locale-picker__region {
  margin-top: 0.15rem;
  font-size: 0.6875rem;
  color: #94a3b8;
}

@media (max-width: 640px) {
  .locale-picker {
    grid-template-columns: 1fr;
  }
}
</style>
