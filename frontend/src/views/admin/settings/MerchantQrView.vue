<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import PageFrame from '../../../components/layout/PageFrame.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import Badge from '../../../components/ui/Badge.vue'
import DataTableShell from '../../../components/ui/DataTableShell.vue'
import { api, extractApiErrorMessage, type ApiItemResponse, type ApiListResponse } from '../../../api/client'
import { useConfirm } from '../../../composables/useConfirm'
import { useContextStore } from '../../../stores/context'
import { formatDate } from '../../../utils/format'

type QrType = 'table' | 'pdf_menu' | 'external_link' | 'merchant' | 'payment' | 'company'
type ScanMode = 'browser' | 'app'
type ServiceMode = 'web' | 'mobile'
type TableStatus = 'available' | 'occupied' | 'reserved' | 'cleaning' | 'inactive'

interface MerchantQr {
  id: string
  label: string
  type: QrType
  scan: ScanMode
  service: ServiceMode
  scan_value: string
  company_public_id: string
  table_id?: string | null
  payload?: {
    filename?: string
    amount?: string | number
    currency?: string
    reference?: string | null
    display_name?: string
  } | null
  created_at?: string | null
}

interface FloorTable {
  id: string
  name: string
  code: string
  zone?: string | null
  status: TableStatus | string
}

const QR_TYPES: { id: QrType; icon: string }[] = [
  { id: 'table', icon: 'tables' },
  { id: 'pdf_menu', icon: 'note' },
  { id: 'external_link', icon: 'globe' },
  { id: 'merchant', icon: 'device-pos' },
  { id: 'payment', icon: 'card' },
  { id: 'company', icon: 'building' },
]

const { t } = useI18n()
const context = useContextStore()
const { confirm: confirmDialog } = useConfirm()

const codes = ref<MerchantQr[]>([])
const tables = ref<FloorTable[]>([])
const query = ref('')
const tableQuery = ref('')
const refreshing = ref(false)
const tablesLoading = ref(false)
const saving = ref(false)
const error = ref('')
const formError = ref('')
const editorOpen = ref(false)
const saved = ref<MerchantQr | null>(null)
const viewing = ref<MerchantQr | null>(null)
const downloading = ref(false)
const pdfFile = ref<File | null>(null)
const pdfInput = ref<HTMLInputElement | null>(null)
const PDF_MAX_BYTES = 10 * 1024 * 1024
const form = ref({
  label: '',
  type: 'table' as QrType,
  url: '',
  tableId: '',
  amount: '',
  currency: 'BIF',
  reference: '',
  displayName: '',
})

const companyId = computed(() => context.currentStore?.branch?.company?.id ?? '')
const companyName = computed(() => context.currentStore?.branch?.company?.name ?? '')
const locked = computed(() => saved.value !== null)
const needsUrl = computed(() => form.value.type === 'external_link')
const needsLabel = computed(() => form.value.type !== 'payment')
const pdfName = computed(() => pdfFile.value?.name || saved.value?.payload?.filename || '')
const previewReady = computed(() => {
  if (saved.value?.scan_value) return true
  const type = form.value.type
  if (type === 'pdf_menu') return Boolean(pdfFile.value)
  if (type === 'merchant') return Boolean(form.value.displayName.trim() || form.value.label.trim())
  if (type === 'payment') {
    const amount = Number(form.value.amount)
    return Boolean(form.value.amount.trim()) && !Number.isNaN(amount) && amount >= 0
  }
  return Boolean(form.value.label.trim())
})
const previewCaption = computed(() => {
  if (saved.value) return saved.value.label
  if (form.value.type === 'pdf_menu') return form.value.label.trim() || pdfName.value
  if (form.value.type === 'merchant') return form.value.displayName.trim() || form.value.label.trim()
  if (form.value.type === 'payment') {
    const reference = form.value.reference.trim()
    if (reference) return reference
    return `${form.value.amount.trim()} ${form.value.currency.trim().toUpperCase()}`
  }
  return form.value.label.trim()
})
const previewScan = computed(() => {
  if (saved.value?.scan_value) return saved.value.scan_value
  if (!previewReady.value || !companyId.value) return ''

  const type = form.value.type
  const label = form.value.label.trim()
  if (type === 'external_link' && isHttpUrl(form.value.url.trim())) return form.value.url.trim()

  const payload: Record<string, unknown> = {
    v: 1,
    kind: type,
    company_public_id: companyId.value,
    company_name: companyName.value,
    label: previewCaption.value,
  }
  if (type === 'pdf_menu') payload.filename = pdfName.value
  if (type === 'payment') {
    payload.amount = form.value.amount.trim()
    payload.currency = form.value.currency.trim().toUpperCase() || 'BIF'
    payload.reference = form.value.reference.trim() || null
  }
  if (type === 'merchant') payload.display_name = form.value.displayName.trim() || label
  if (type === 'table' && form.value.tableId) {
    const table = tables.value.find((item) => item.id === form.value.tableId)
    payload.table_id = form.value.tableId
    payload.table_name = table?.name ?? null
  }

  return JSON.stringify(payload)
})
const dirty = computed(() => !saved.value && Boolean(
  form.value.label.trim()
  || form.value.url.trim()
  || form.value.tableId
  || form.value.amount.trim()
  || form.value.reference.trim()
  || form.value.displayName.trim()
  || pdfFile.value,
))

const filtered = computed(() => {
  const q = query.value.trim().toLowerCase()
  if (!q) return codes.value
  return codes.value.filter((item) => {
    const haystack = [
      item.label,
      t(`merchantQrPage.types.${item.type}`),
      t(`merchantQrPage.scan.${item.scan}`),
      t(`merchantQrPage.service.${item.service}`),
    ].join(' ').toLowerCase()
    return haystack.includes(q)
  })
})

const filteredTables = computed(() => {
  const q = tableQuery.value.trim().toLowerCase()
  if (!q) return tables.value
  return tables.value.filter((table) => {
    const haystack = [table.name, table.code, table.zone ?? '', statusLabel(table.status)].join(' ').toLowerCase()
    return haystack.includes(q)
  })
})

const emptyTitle = computed(() => (
  codes.value.length && query.value.trim()
    ? t('merchantQrPage.noMatch')
    : t('merchantQrPage.empty')
))

function statusLabel(status: string) {
  const key = `merchantQrPage.statuses.${status}`
  const label = t(key)
  return label === key ? status : label
}

function selectTable(id: string) {
  if (locked.value) return
  form.value.tableId = id
}

function selectType(type: QrType) {
  if (locked.value) return
  form.value.type = type
}

function clearPdf() {
  pdfFile.value = null
  if (pdfInput.value) pdfInput.value.value = ''
}

function onPdf(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (!file) {
    pdfFile.value = null
    return
  }
  const isPdf = file.type === 'application/pdf' || file.name.toLowerCase().endsWith('.pdf')
  if (!isPdf || file.size > PDF_MAX_BYTES) {
    formError.value = t('merchantQrPage.pdfInvalid')
    clearPdf()
    return
  }
  formError.value = ''
  pdfFile.value = file
}

function statusVariant(status: string): 'success' | 'warning' | 'brand' | 'neutral' {
  if (status === 'available') return 'success'
  if (status === 'occupied') return 'warning'
  if (status === 'reserved') return 'brand'
  return 'neutral'
}

function qrImageUrl(value: string, size = 280) {
  return `https://api.qrserver.com/v1/create-qr-code/?size=${size}x${size}&margin=16&data=${encodeURIComponent(value)}`
}

function qrFileName(label: string) {
  const safe = label
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
  return `${safe || 'merchant-qr'}.png`
}

async function downloadQr(scanValue: string, label: string) {
  if (!scanValue || downloading.value) return
  downloading.value = true
  error.value = ''
  try {
    const response = await fetch(qrImageUrl(scanValue, 640))
    if (!response.ok) throw new Error('download')
    const blob = await response.blob()
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = qrFileName(label)
    document.body.appendChild(link)
    link.click()
    link.remove()
    URL.revokeObjectURL(url)
  } catch {
    error.value = t('merchantQrPage.downloadError')
  } finally {
    downloading.value = false
  }
}

function isHttpUrl(value: string) {
  try {
    const url = new URL(value)
    return url.protocol === 'http:' || url.protocol === 'https:'
  } catch {
    return false
  }
}

function escapeHtml(value: string) {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
}

function blankForm(type: QrType = 'table') {
  return {
    label: '',
    type,
    url: '',
    tableId: '',
    amount: '',
    currency: (context.currencyCode || 'BIF').toUpperCase(),
    reference: '',
    displayName: '',
  }
}

function resetForm() {
  form.value = blankForm()
  tableQuery.value = ''
  formError.value = ''
  saved.value = null
  clearPdf()
}

function openCreate() {
  resetForm()
  editorOpen.value = true
  void loadTables()
}

function openSaved(code: MerchantQr) {
  saved.value = code
  form.value = {
    ...blankForm(code.type),
    label: code.label,
    url: code.scan === 'browser' && code.type !== 'table' && code.type !== 'pdf_menu' ? code.scan_value : '',
    tableId: code.table_id ?? '',
    amount: code.payload?.amount != null ? String(code.payload.amount) : '',
    currency: (code.payload?.currency || context.currencyCode || 'BIF').toUpperCase(),
    reference: code.payload?.reference ?? '',
    displayName: code.payload?.display_name ?? '',
  }
  formError.value = ''
  editorOpen.value = true
  if (code.type === 'table') void loadTables()
}

function closeEditor() {
  editorOpen.value = false
  resetForm()
}

async function refresh() {
  if (!companyId.value || refreshing.value) return
  refreshing.value = true
  error.value = ''
  try {
    const res = await api.get<ApiListResponse<MerchantQr>>(`/companies/${companyId.value}/merchant-qr-codes`)
    codes.value = res.data ?? []
  } catch (e) {
    error.value = extractApiErrorMessage(e, t('merchantQrPage.loadError'))
  } finally {
    refreshing.value = false
  }
}

async function loadTables() {
  if (!companyId.value) {
    tables.value = []
    return
  }
  tablesLoading.value = true
  try {
    const res = await api.get<ApiListResponse<FloorTable>>(`/companies/${companyId.value}/merchant-qr-tables`)
    tables.value = res.data ?? []
  } catch (e) {
    formError.value = extractApiErrorMessage(e, t('merchantQrPage.tablesError'))
  } finally {
    tablesLoading.value = false
  }
}

function validate(): boolean {
  formError.value = ''
  if (!companyId.value) {
    formError.value = t('merchantQrPage.noCompany')
    return false
  }
  if (needsLabel.value && form.value.type !== 'merchant' && !form.value.label.trim()) {
    formError.value = t('merchantQrPage.labelRequired')
    return false
  }
  if (form.value.type === 'merchant' && !form.value.displayName.trim()) {
    formError.value = t('merchantQrPage.displayNameRequired')
    return false
  }
  if (form.value.type === 'payment') {
    const amount = Number(form.value.amount)
    if (!form.value.amount.trim() || Number.isNaN(amount) || amount < 0) {
      formError.value = t('merchantQrPage.amountRequired')
      return false
    }
    if (!/^[A-Za-z]{3}$/.test(form.value.currency.trim())) {
      formError.value = t('merchantQrPage.currencyInvalid')
      return false
    }
  }
  if (form.value.type === 'table' && !form.value.tableId) {
    formError.value = t('merchantQrPage.tableRequired')
    return false
  }
  if (form.value.type === 'pdf_menu' && !pdfFile.value) {
    formError.value = t('merchantQrPage.pdfRequired')
    return false
  }
  if (needsUrl.value) {
    const url = form.value.url.trim()
    if (!url) {
      formError.value = t('merchantQrPage.urlRequired')
      return false
    }
    if (!isHttpUrl(url)) {
      formError.value = t('merchantQrPage.urlInvalid')
      return false
    }
  }
  return true
}

async function save() {
  if (locked.value || saving.value || !validate() || !companyId.value) return
  saving.value = true
  formError.value = ''
  try {
    let res: ApiItemResponse<MerchantQr>
    if (form.value.type === 'pdf_menu' && pdfFile.value) {
      const body = new FormData()
      body.append('label', form.value.label.trim())
      body.append('type', 'pdf_menu')
      body.append('pdf', pdfFile.value)
      res = await api.upload<ApiItemResponse<MerchantQr>>(`/companies/${companyId.value}/merchant-qr-codes`, body)
    } else {
      const body: Record<string, string> = {
        type: form.value.type,
      }
      const label = form.value.label.trim()
      if (label) body.label = label
      if (form.value.type === 'table') body.table_id = form.value.tableId
      if (needsUrl.value) body.url = form.value.url.trim()
      if (form.value.type === 'payment') {
        body.amount = form.value.amount.trim()
        body.currency = form.value.currency.trim().toUpperCase()
        if (form.value.reference.trim()) body.reference = form.value.reference.trim()
      }
      if (form.value.type === 'merchant') body.display_name = form.value.displayName.trim()
      res = await api.post<ApiItemResponse<MerchantQr>>(`/companies/${companyId.value}/merchant-qr-codes`, body)
    }
    saved.value = res.data
    await refresh()
  } catch (e) {
    formError.value = extractApiErrorMessage(e, t('merchantQrPage.saveError'))
  } finally {
    saving.value = false
  }
}

function preview() {
  const code = saved.value
  if (!code) return
  const popup = window.open('', '_blank', 'noopener,noreferrer,width=520,height=720')
  if (!popup) return
  const title = escapeHtml(code.label)
  const type = escapeHtml(t(`merchantQrPage.types.${code.type}`))
  const image = escapeHtml(qrImageUrl(code.scan_value))
  popup.document.write(`<!doctype html><html><head><meta charset="utf-8"><title>${title}</title>
    <style>
      body { margin: 0; font-family: sans-serif; text-align: center; padding: 40px 24px; color: #1c2428; }
      h1 { margin: 0 0 8px; font-size: 22px; }
      p { margin: 0 0 24px; color: #5c6b73; }
      img { width: 280px; height: 280px; }
    </style></head><body>
    <h1>${title}</h1>
    <p>${type}</p>
    <img id="qr" src="${image}" alt="" />
    </body></html>`)
  popup.document.close()
  const imageNode = popup.document.getElementById('qr')
  if (imageNode instanceof HTMLImageElement) {
    imageNode.addEventListener('load', () => popup.print())
  }
}

async function remove(code: MerchantQr) {
  const ok = await confirmDialog(t('merchantQrPage.deleteConfirm'), {
    title: t('common.delete'),
    confirmLabel: t('common.delete'),
    danger: true,
  })
  if (!ok) return
  try {
    await api.delete(`/merchant-qr-codes/${code.id}`)
    if (saved.value?.id === code.id) closeEditor()
    await refresh()
  } catch (e) {
    error.value = extractApiErrorMessage(e, t('merchantQrPage.saveError'))
  }
}

watch(() => form.value.type, () => {
  if (locked.value) return
  form.value.url = ''
  form.value.tableId = ''
  formError.value = ''
  clearPdf()
})

watch(companyId, () => {
  void refresh()
  if (editorOpen.value && form.value.type === 'table') void loadTables()
})

onMounted(async () => {
  if (!context.stores.length) await context.loadStores()
  await refresh()
})
</script>

<template>
  <PageFrame>
    <template #title>{{ t('nav.settingsItems.merchantQr') }}</template>
    <template #subtitle>{{ t('merchantQrPage.subtitle') }}</template>

    <div class="merchant-qr">
      <div class="merchant-qr__toolbar">
        <button type="button" class="btn-secondary" :disabled="refreshing || !companyId" @click="refresh">
          {{ t('common.refresh') }}
        </button>
        <button type="button" class="btn-primary" :disabled="!companyId" @click="openCreate">
          {{ t('merchantQrPage.create') }}
        </button>
        <label class="merchant-qr__search">
          <span class="sr-only">{{ t('common.search') }}</span>
          <input
            v-model="query"
            class="field"
            type="search"
            :placeholder="t('merchantQrPage.searchPlaceholder')"
          />
        </label>
      </div>

      <p v-if="!companyId" class="form-alert form-alert--error" role="status">{{ t('merchantQrPage.noCompany') }}</p>
      <p v-else-if="error" class="form-alert form-alert--error" role="alert">{{ error }}</p>

      <DataTableShell
        :loading="refreshing"
        :empty="!filtered.length"
        :empty-title="emptyTitle"
        empty-icon="tag"
      >
        <table class="ui-table">
          <thead>
            <tr>
              <th>{{ t('merchantQrPage.columns.label') }}</th>
              <th>{{ t('merchantQrPage.columns.type') }}</th>
              <th>{{ t('merchantQrPage.columns.scan') }}</th>
              <th>{{ t('merchantQrPage.columns.service') }}</th>
              <th>{{ t('merchantQrPage.columns.created') }}</th>
              <th>{{ t('merchantQrPage.columns.actions') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="item in filtered" :key="item.id" class="merchant-qr__row" @click="viewing = item">
              <td>
                <button type="button" class="merchant-qr__label" @click.stop="openSaved(item)">
                  {{ item.label }}
                </button>
              </td>
              <td>{{ t(`merchantQrPage.types.${item.type}`) }}</td>
              <td>
                <Badge :variant="item.scan === 'browser' ? 'brand' : 'neutral'">
                  {{ t(`merchantQrPage.scan.${item.scan}`) }}
                </Badge>
              </td>
              <td>{{ t(`merchantQrPage.service.${item.service}`) }}</td>
              <td>{{ formatDate(item.created_at) }}</td>
              <td>
                <div class="merchant-qr__actions">
                  <button type="button" class="btn-secondary merchant-qr__action" @click.stop="viewing = item">
                    {{ t('merchantQrPage.view') }}
                  </button>
                  <button
                    type="button"
                    class="btn-secondary merchant-qr__action"
                    :disabled="downloading"
                    @click.stop="downloadQr(item.scan_value, item.label)"
                  >
                    {{ t('merchantQrPage.download') }}
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </DataTableShell>
    </div>

    <AppModal
      :open="editorOpen"
      :title="t('merchantQrPage.createTitle')"
      :subtitle="t('merchantQrPage.createSubtitle')"
      icon="tag"
      tone="accent"
      size="xl"
      presentation="dialog"
      :dirty="dirty"
      @close="closeEditor"
    >
      <div class="merchant-qr-form">
        <div class="merchant-qr-form__main">
          <p class="merchant-qr__note">{{ t('merchantQrPage.notice') }}</p>
          <p v-if="formError" class="form-alert form-alert--error" role="alert">{{ formError }}</p>

          <div class="merchant-qr__field">
            <span id="merchant-qr-type-label">{{ t('merchantQrPage.qrType') }}</span>
            <div class="merchant-qr__types" role="radiogroup" aria-labelledby="merchant-qr-type-label">
              <button
                v-for="type in QR_TYPES"
                :key="type.id"
                type="button"
                role="radio"
                class="merchant-qr-type"
                :class="[`merchant-qr-type--${type.id}`, { 'is-selected': form.type === type.id }]"
                :aria-checked="form.type === type.id"
                :disabled="locked"
                @click="selectType(type.id)"
              >
                <span class="merchant-qr-type__icon">
                  <AppIcon :name="type.icon" :size="20" />
                </span>
                <span class="merchant-qr-type__label">{{ t(`merchantQrPage.types.${type.id}`) }}</span>
              </button>
            </div>
          </div>

          <label v-if="form.type === 'table' || form.type === 'pdf_menu' || form.type === 'external_link'" class="merchant-qr__field">
            <span>{{ t('merchantQrPage.label') }}</span>
            <input
              v-model="form.label"
              class="field"
              type="text"
              maxlength="120"
              :disabled="locked"
              :placeholder="t('merchantQrPage.labelPlaceholder')"
            />
          </label>

          <section v-if="form.type === 'table'" class="merchant-qr__section">
            <h4>{{ t('merchantQrPage.tableTitle') }}</h4>
            <p>{{ t('merchantQrPage.tableHint') }}</p>
            <div class="merchant-qr__section-tools">
              <button type="button" class="btn-secondary" :disabled="tablesLoading || locked" @click="loadTables">
                {{ t('common.refresh') }}
              </button>
              <span>{{ t('merchantQrPage.chooseRow') }}</span>
            </div>
            <input
              v-model="tableQuery"
              class="field"
              type="search"
              :placeholder="t('merchantQrPage.searchTables')"
              :disabled="locked"
            />
            <div class="merchant-qr__tables">
              <table class="ui-table">
                <thead>
                  <tr>
                    <th>{{ t('merchantQrPage.tableColumns.table') }}</th>
                    <th>{{ t('merchantQrPage.tableColumns.zone') }}</th>
                    <th>{{ t('merchantQrPage.tableColumns.status') }}</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-if="tablesLoading">
                    <td colspan="3">{{ t('common.loading') }}</td>
                  </tr>
                  <tr v-else-if="!filteredTables.length">
                    <td colspan="3">{{ t('merchantQrPage.noTables') }}</td>
                  </tr>
                  <template v-else>
                    <tr
                      v-for="table in filteredTables"
                      :key="table.id"
                      :class="{ 'is-selected': form.tableId === table.id }"
                      @click="selectTable(table.id)"
                    >
                      <td>{{ table.name }}</td>
                      <td>{{ table.zone || '—' }}</td>
                      <td>
                        <Badge :variant="statusVariant(table.status)">{{ statusLabel(table.status) }}</Badge>
                      </td>
                    </tr>
                  </template>
                </tbody>
              </table>
            </div>
          </section>

          <section v-else-if="form.type === 'pdf_menu'" class="merchant-qr__section">
            <h4>{{ t('merchantQrPage.pdfUpload') }}</h4>
            <p>{{ t('merchantQrPage.pdfHint') }}</p>
            <label v-if="!locked" class="merchant-qr-upload" :class="{ 'is-filled': pdfName }">
              <AppIcon name="upload" :size="22" />
              <span class="merchant-qr-upload__name">{{ pdfName || t('merchantQrPage.pdfChoose') }}</span>
              <span class="merchant-qr-upload__action">{{ t('merchantQrPage.pdfBrowse') }}</span>
              <input
                ref="pdfInput"
                class="merchant-qr-upload__input"
                type="file"
                accept="application/pdf,.pdf"
                @change="onPdf"
              />
            </label>
            <a
              v-else-if="saved?.scan_value"
              class="merchant-qr-upload merchant-qr-upload--locked is-filled"
              :href="saved.scan_value"
              target="_blank"
              rel="noopener noreferrer"
            >
              <AppIcon name="note" :size="22" />
              <span class="merchant-qr-upload__name">{{ pdfName || t('merchantQrPage.pdfUpload') }}</span>
            </a>
          </section>

          <label v-else-if="form.type === 'external_link'" class="merchant-qr__field">
            <span>{{ t('merchantQrPage.externalUrl') }}</span>
            <input v-model="form.url" class="field" type="url" inputmode="url" :disabled="locked" placeholder="https://" />
            <small>{{ t('merchantQrPage.externalHint') }}</small>
          </label>

          <section v-else-if="form.type === 'company'" class="merchant-qr__section">
            <h4>{{ t('merchantQrPage.types.company') }}</h4>
            <label class="merchant-qr__field">
              <span>{{ t('merchantQrPage.label') }}</span>
              <input
                v-model="form.label"
                class="field"
                type="text"
                maxlength="120"
                :disabled="locked"
                :placeholder="t('merchantQrPage.labelPlaceholder')"
              />
            </label>
          </section>

          <section v-else-if="form.type === 'payment'" class="merchant-qr__section">
            <h4>{{ t('merchantQrPage.types.payment') }}</h4>
            <div class="merchant-qr__pair">
              <label class="merchant-qr__field">
                <span>{{ t('merchantQrPage.paymentAmount') }}</span>
                <input
                  v-model="form.amount"
                  class="field"
                  type="number"
                  min="0"
                  step="0.01"
                  inputmode="decimal"
                  :disabled="locked"
                />
              </label>
              <label class="merchant-qr__field">
                <span>{{ t('merchantQrPage.paymentCurrency') }}</span>
                <input
                  v-model="form.currency"
                  class="field"
                  type="text"
                  maxlength="3"
                  :disabled="locked"
                  placeholder="BIF"
                  @change="form.currency = form.currency.trim().toUpperCase()"
                />
              </label>
            </div>
            <label class="merchant-qr__field">
              <span>{{ t('merchantQrPage.paymentReference') }}</span>
              <input
                v-model="form.reference"
                class="field"
                type="text"
                maxlength="120"
                :disabled="locked"
              />
            </label>
          </section>

          <section v-else-if="form.type === 'merchant'" class="merchant-qr__section">
            <label class="merchant-qr__field">
              <span>{{ t('merchantQrPage.labelOptional') }}</span>
              <input
                v-model="form.label"
                class="field"
                type="text"
                maxlength="120"
                :disabled="locked"
                :placeholder="t('merchantQrPage.labelExample')"
              />
            </label>
            <label class="merchant-qr__field">
              <span>{{ t('merchantQrPage.companyPublicId') }}</span>
              <input class="field" type="text" :value="companyId" readonly />
              <small>{{ t('merchantQrPage.companyPublicIdHint') }}</small>
              <small v-if="companyName">{{ companyName }}</small>
            </label>
            <h4>{{ t('merchantQrPage.types.merchant') }}</h4>
            <label class="merchant-qr__field">
              <span>{{ t('merchantQrPage.displayName') }}</span>
              <input
                v-model="form.displayName"
                class="field"
                type="text"
                maxlength="120"
                :disabled="locked"
              />
            </label>
          </section>
        </div>

        <aside class="merchant-qr-preview">
          <h4>{{ t('merchantQrPage.previewTitle') }}</h4>
          <div v-if="previewScan" class="merchant-qr-preview__sheet">
            <img :src="qrImageUrl(previewScan)" :alt="previewCaption" />
            <strong>{{ previewCaption }}</strong>
            <span>{{ t(`merchantQrPage.types.${form.type}`) }}</span>
          </div>
          <p v-else class="merchant-qr-preview__empty">{{ t('merchantQrPage.previewEmpty') }}</p>
          <div class="merchant-qr-preview__actions">
            <button type="button" class="btn-secondary" :disabled="!saved" @click="preview">
              {{ t('merchantQrPage.preview') }}
            </button>
            <button
              type="button"
              class="btn-secondary"
              :disabled="!previewScan || downloading"
              @click="downloadQr(previewScan, previewCaption)"
            >
              {{ t('merchantQrPage.download') }}
            </button>
          </div>
        </aside>
      </div>

      <template #footer>
        <button v-if="saved" type="button" class="btn-secondary merchant-qr__delete" @click="remove(saved)">
          {{ t('common.delete') }}
        </button>
        <button type="button" class="btn-secondary" @click="closeEditor">
          {{ locked ? t('common.close') : t('common.cancel') }}
        </button>
        <button v-if="!locked" type="button" class="btn-primary" :disabled="saving || !companyId" @click="save">
          {{ saving ? t('common.saving') : t('common.save') }}
        </button>
      </template>
    </AppModal>

    <AppModal
      :open="viewing !== null"
      :title="viewing?.label ?? ''"
      :subtitle="viewing ? t(`merchantQrPage.types.${viewing.type}`) : ''"
      icon="tag"
      tone="accent"
      size="md"
      presentation="dialog"
      @close="viewing = null"
    >
      <div v-if="viewing" class="merchant-qr-viewer">
        <img :src="qrImageUrl(viewing.scan_value, 360)" :alt="viewing.label" />
        <p>{{ t(`merchantQrPage.service.${viewing.service}`) }}</p>
      </div>
      <template #footer>
        <button type="button" class="btn-secondary" @click="viewing = null">
          {{ t('common.close') }}
        </button>
        <button
          v-if="viewing"
          type="button"
          class="btn-primary"
          :disabled="downloading"
          @click="downloadQr(viewing.scan_value, viewing.label)"
        >
          {{ t('merchantQrPage.download') }}
        </button>
      </template>
    </AppModal>
  </PageFrame>
</template>

<style scoped>
.merchant-qr {
  display: flex;
  flex-direction: column;
  gap: var(--space-4);
}

.merchant-qr__toolbar,
.merchant-qr__section-tools {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-3);
}

.merchant-qr__search {
  flex: 1;
  min-width: 16rem;
}

.merchant-qr__search .field {
  width: 100%;
}

.merchant-qr__row {
  cursor: pointer;
}

.merchant-qr__label {
  padding: 0;
  border: 0;
  background: transparent;
  color: var(--color-text-primary);
  font: inherit;
  font-weight: 600;
  cursor: pointer;
}

.merchant-qr__delete {
  margin-right: auto;
}

.merchant-qr__actions,
.merchant-qr-preview__actions {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
}

.merchant-qr__action {
  min-height: var(--control-md);
  padding-inline: var(--space-3);
}

.merchant-qr-viewer {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--space-3);
  text-align: center;
}

.merchant-qr-viewer img {
  width: min(280px, 100%);
  height: auto;
}

.merchant-qr-viewer p {
  margin: 0;
  color: var(--color-text-muted);
  font-size: var(--text-sm);
}

.merchant-qr-form {
  display: grid;
  grid-template-columns: minmax(0, 1.4fr) minmax(16rem, 0.8fr);
  gap: var(--space-6);
  align-items: start;
}

.merchant-qr-form__main,
.merchant-qr__field,
.merchant-qr__section,
.merchant-qr-preview {
  display: flex;
  flex-direction: column;
  gap: var(--space-3);
}

.merchant-qr__pair {
  display: grid;
  grid-template-columns: minmax(0, 1.4fr) minmax(6rem, 0.6fr);
  gap: var(--space-3);
}

.merchant-qr__field > span,
.merchant-qr__section h4,
.merchant-qr-preview h4 {
  font-size: var(--text-sm);
  font-weight: 600;
  color: var(--color-text-primary);
}

.merchant-qr__types {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: var(--space-2);
}

.merchant-qr-type {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: var(--space-2);
  min-height: 5.75rem;
  padding: var(--space-3) var(--space-2);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  background: var(--color-surface);
  color: var(--color-text-secondary);
  text-align: center;
  cursor: pointer;
}

.merchant-qr-type:hover:not(:disabled) {
  border-color: color-mix(in srgb, var(--tone) 45%, var(--color-border));
  background: color-mix(in srgb, var(--tone) 6%, var(--color-surface));
}

.merchant-qr-type:disabled {
  cursor: default;
}

.merchant-qr-type:disabled:not(.is-selected) {
  opacity: 0.55;
}

.merchant-qr-type__icon {
  display: grid;
  place-items: center;
  width: 2.25rem;
  height: 2.25rem;
  flex-shrink: 0;
  border-radius: var(--radius-md);
  background: color-mix(in srgb, var(--tone) 14%, var(--color-surface));
  color: var(--tone);
}

.merchant-qr-type__label {
  font-size: var(--text-xs);
  font-weight: 600;
  line-height: 1.3;
}

.merchant-qr-type--table { --tone: #0f766e; }
.merchant-qr-type--pdf_menu { --tone: #d97706; }
.merchant-qr-type--external_link { --tone: #0284c7; }
.merchant-qr-type--merchant { --tone: #2563eb; }
.merchant-qr-type--payment { --tone: #db2777; }
.merchant-qr-type--company { --tone: var(--color-brand-600); }

.merchant-qr-type.is-selected {
  border-color: var(--tone);
  background: color-mix(in srgb, var(--tone) 8%, var(--color-surface));
  color: var(--tone);
  box-shadow: 0 0 0 1px var(--tone);
}

.merchant-qr-type.is-selected .merchant-qr-type__icon {
  background: var(--tone);
  color: #fff;
}

.merchant-qr__field small,
.merchant-qr__section p,
.merchant-qr__section-tools span,
.merchant-qr-preview__empty,
.merchant-qr-preview__sheet span {
  color: var(--color-text-muted);
  font-size: var(--text-xs);
}

.merchant-qr__section h4,
.merchant-qr-preview h4,
.merchant-qr__section p {
  margin: 0;
}

.merchant-qr__note {
  margin: 0;
  padding: var(--space-3);
  border-radius: var(--radius-md);
  background: var(--color-info-bg);
  color: var(--color-text-secondary);
  font-size: var(--text-sm);
}

.merchant-qr-upload {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--space-2);
  padding: var(--space-5) var(--space-4);
  border: 1px dashed var(--color-border);
  border-radius: var(--radius-md);
  background: var(--color-surface);
  color: var(--color-text-secondary);
  text-align: center;
  cursor: pointer;
}

.merchant-qr-upload:hover {
  border-color: var(--color-accent);
  background: var(--color-accent-soft);
}

.merchant-qr-upload.is-filled {
  border-style: solid;
  border-color: var(--color-accent);
}

.merchant-qr-upload--locked {
  text-decoration: none;
}

.merchant-qr-upload__name {
  font-size: var(--text-sm);
  font-weight: 600;
  color: var(--color-text-primary);
  word-break: break-word;
}

.merchant-qr-upload__action {
  font-size: var(--text-xs);
  font-weight: 600;
  color: var(--color-accent);
}

.merchant-qr-upload__input {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}

.merchant-qr__tables {
  max-height: 16rem;
  overflow: auto;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
}

.merchant-qr__tables tr {
  cursor: pointer;
}

.merchant-qr__tables tr.is-selected {
  background: var(--color-info-bg);
}

.merchant-qr-preview {
  position: sticky;
  top: 0;
  padding: var(--space-4);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  background: var(--color-surface);
}

.merchant-qr-preview__sheet {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--space-2);
  text-align: center;
}

.merchant-qr-preview__sheet img {
  width: 220px;
  height: 220px;
}

.merchant-qr-preview__sheet strong {
  color: var(--color-text-primary);
}

.merchant-qr-preview__empty {
  margin: 0;
  min-height: 8rem;
}

@media (max-width: 800px) {
  .merchant-qr-form {
    grid-template-columns: 1fr;
  }

  .merchant-qr-preview {
    position: static;
  }

  .merchant-qr__types {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}
</style>
