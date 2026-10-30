<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import OrganizationLayout from '../../../components/organization/OrganizationLayout.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import ListPager from '../../../components/ui/ListPager.vue'
import ModuleFilters from '../../../components/ui/ModuleFilters.vue'
import { useClientPager } from '../../../composables/useClientPager'
import { extractApiErrorMessage } from '../../../api/client'
import { useBackofficeStore } from '../../../stores/backoffice'
import { useContextStore } from '../../../stores/context'
import type { Device, DeviceCategory, DeviceConnection, DeviceRole } from '../../../types'
import { formatRelativePast } from '../../../utils/format'
import { emptyListFilters, matchesActive, matchesSearch, type ListFilters } from '../../../utils/listFilters'

const props = withDefaults(defineProps<{ deviceType?: DeviceCategory | null }>(), {
  deviceType: null,
})

const { t } = useI18n()
const store = useBackofficeStore()
const context = useContextStore()

const categories: DeviceCategory[] = ['pos', 'printer', 'tablet', 'computer', 'other']
const connections: DeviceConnection[] = ['network', 'usb', 'bluetooth']
const roles: DeviceRole[] = ['master', 'slave', 'standalone']

const storeId = ref('')
const showModal = ref(false)
const editing = ref<Device | null>(null)
const saving = ref(false)
const saveError = ref('')
const filters = ref<ListFilters>(emptyListFilters('all'))
const filtered = computed(() => store.devices.filter(device =>
  matchesSearch(
    `${device.code ?? ''} ${device.name} ${device.user?.name ?? ''} ${device.branch?.name ?? ''} ${device.category ?? ''} ${device.device_type ?? ''}`,
    filters.value.search,
  )
  && matchesActive(device.is_active, filters.value.active),
))
const { page, lastPage, total, perPage, paged, setPage } = useClientPager(filtered)
const saveNotice = ref('')
const copied = ref(false)
const showFormToken = ref(false)
const visibleTokenIds = ref<string[]>([])
const form = ref(emptyForm())

const selectedStore = computed(() => context.activeStores.find(item => item.id === storeId.value) ?? null)
const categoryHint = computed(() =>
  form.value.category === 'pos' ? t('org.deviceCategoryPosHint') : '',
)

onMounted(async () => {
  await context.loadStores()
  storeId.value = context.currentStoreId ?? context.activeStores[0]?.id ?? ''
})

watch(storeId, async (id) => {
  if (!id) return
  await store.loadDevices(id, props.deviceType ?? undefined)
})

function emptyForm() {
  return {
    name: '',
    category: (props.deviceType && props.deviceType !== 'scanner' ? props.deviceType : 'pos') as DeviceCategory,
    pos_role: 'master' as DeviceRole,
    connection_type: 'network' as DeviceConnection,
    ip_address: '',
    port: 9100,
    description: '',
    is_active: true,
    sync_token: '',
    registration_status: 'pending' as 'pending' | 'registered',
  }
}

function maskToken(token?: string | null) {
  if (!token) return '—'
  return '•'.repeat(Math.min(Math.max(token.length, 12), 24))
}

function isTokenVisible(id: string) {
  return visibleTokenIds.value.includes(id)
}

function toggleToken(id: string) {
  visibleTokenIds.value = isTokenVisible(id)
    ? visibleTokenIds.value.filter(item => item !== id)
    : [...visibleTokenIds.value, id]
}

function openCreate() {
  editing.value = null
  copied.value = false
  showFormToken.value = false
  saveError.value = ''
  saveNotice.value = ''
  form.value = emptyForm()
  showModal.value = true
}

function openEdit(device: Device) {
  editing.value = device
  copied.value = false
  showFormToken.value = false
  form.value = {
    name: device.name,
    category: device.category ?? device.device_type,
    pos_role: device.pos_role ?? 'master',
    connection_type: device.connection_type ?? 'network',
    ip_address: device.ip_address ?? '',
    port: device.port ?? 9100,
    description: device.description ?? '',
    is_active: device.is_active,
    sync_token: device.sync_token ?? '',
    registration_status: device.registration_status ?? 'pending',
  }
  showModal.value = true
}

function isHostOrIp(value: string): boolean {
  const host = value.trim()
  if (!host) return false
  // IPv4
  if (/^(\d{1,3}\.){3}\d{1,3}$/.test(host)) {
    return host.split('.').every((part) => {
      const n = Number(part)
      return Number.isInteger(n) && n >= 0 && n <= 255
    })
  }
  // IPv6 (loose) or hostname / localhost / CAISSE-01
  if (host.includes(':')) return true
  return /^(?=.{1,253}$)([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)(\.([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?))*$/.test(host)
}

async function save() {
  saveError.value = ''
  saveNotice.value = ''

  if (!storeId.value) {
    saveError.value = t('pos.selectStore')
    return
  }

  const name = form.value.name.trim()
  if (!name) {
    saveError.value = t('org.deviceNameRequired')
    return
  }

  const ip = form.value.ip_address.trim()
  if (form.value.connection_type === 'network' && ip && !isHostOrIp(ip)) {
    saveError.value = t('org.deviceIpInvalid')
    return
  }

  saving.value = true
  try {
    await store.saveDevice(storeId.value, {
      name,
      category: form.value.category,
      device_type: form.value.category,
      pos_role: form.value.pos_role,
      connection_type: form.value.connection_type,
      ip_address: form.value.connection_type === 'network' ? ip || null : null,
      port: form.value.connection_type === 'network' ? Number(form.value.port) || 9100 : null,
      description: form.value.description.trim() || null,
      is_active: form.value.is_active,
    }, editing.value?.id)
    await store.loadDevices(storeId.value, props.deviceType ?? undefined)
    showModal.value = false
  } catch (error) {
    saveError.value = extractApiErrorMessage(error, t('org.deviceSaveFailed'))
  } finally {
    saving.value = false
  }
}

async function remove(device: Device) {
  if (!confirm(t('org.confirmDelete'))) return
  await store.deleteDevice(device.id)
  await store.loadDevices(storeId.value, props.deviceType ?? undefined)
}

async function regenerate() {
  if (!editing.value) return
  saving.value = true
  try {
    const saved = await store.regenerateDeviceToken(editing.value.id)
    form.value.sync_token = saved.sync_token ?? ''
    showFormToken.value = true
    form.value.registration_status = 'pending'
    await store.loadDevices(storeId.value, props.deviceType ?? undefined)
  } finally {
    saving.value = false
  }
}

async function copyToken() {
  if (!form.value.sync_token) return
  await navigator.clipboard.writeText(form.value.sync_token)
  copied.value = true
  window.setTimeout(() => { copied.value = false }, 1600)
}

function categoryLabel(category: string) {
  return t(`org.deviceCategories.${category}`)
}

function categoryIcon(category: string) {
  const map: Record<string, string> = {
    pos: 'device-pos',
    printer: 'device-printer',
    tablet: 'device-tablet',
    computer: 'device-computer',
    other: 'device-other',
    scanner: 'device-other',
  }
  return map[category] ?? 'device-other'
}

function connectionIcon(connection: string) {
  return `conn-${connection}`
}

function deviceCategory(device: Device) {
  return device.category ?? device.device_type ?? 'other'
}

function registrationAt(device: Device) {
  return device.registered_at || device.last_sync_at || device.last_sync || null
}

function registrationAgo(device: Device) {
  return formatRelativePast(registrationAt(device))
}

function registrationLabel(status?: string) {
  if (status === 'registered' || status === 'active') return t('org.registrationRegistered')
  if (status === 'revoked') return t('org.deviceRevoked')
  return t('org.registrationPending')
}

function deviceStatus(device: Device) {
  return device.status ?? (device.registration_status === 'registered' ? 'active' : device.registration_status)
}

async function revoke(device: Device) {
  if (!confirm(t('org.confirmRevokeDevice'))) return
  await store.revokeDevice(device.id)
  if (storeId.value) await store.loadDevices(storeId.value)
}
</script>

<template>
  <OrganizationLayout>
    <div class="space-y-4">
      <div class="flex flex-wrap items-center justify-between gap-4">
        <div>
          <FieldLabel icon="stores">{{ t('stores.select') }}</FieldLabel>
          <select v-model="storeId" class="field w-auto min-w-[240px]">
            <option v-for="s in context.activeStores" :key="s.id" :value="s.id">
              {{ context.storeLabel(s) }}
            </option>
          </select>
        </div>
        <button class="btn-primary" :disabled="!storeId" @click="openCreate">
          <AppIcon name="plus" :size="16" />
          {{ t('org.addDevice') }}
        </button>
      </div>

      <ModuleFilters v-model="filters" :show-period="false" show-search show-active />

      <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <table class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.deviceName') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.deviceCategory') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.deviceRole') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.syncToken') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('products.status') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.registration') }}</th>
              <th class="px-4 py-3 text-right">{{ t('common.actions') }}</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="device in paged" :key="device.id" class="hover:bg-slate-50">
              <td class="px-4 py-3">
                <div class="device-entry">
                  <span
                    class="device-entry__icon"
                    :class="`device-entry__icon--${deviceCategory(device)}`"
                    aria-hidden="true"
                  >
                    <AppIcon :name="categoryIcon(deviceCategory(device))" :size="18" />
                  </span>
                  <div class="device-entry__body">
                    <p class="m-0 font-medium">{{ device.name }}</p>
                    <p class="m-0 text-xs text-slate-400">
                      {{ device.user?.name || '—' }} · {{ device.branch?.name || '—' }}
                      <template v-if="device.app_version"> · {{ device.app_version }}</template>
                    </p>
                    <p v-if="device.connection_type" class="device-entry__conn m-0 text-xs text-slate-400">
                      <AppIcon :name="connectionIcon(device.connection_type)" :size="12" />
                      {{ t(`org.connections.${device.connection_type}`) }}
                      <template v-if="device.ip_address"> · {{ device.ip_address }}<span v-if="device.port">:{{ device.port }}</span></template>
                    </p>
                  </div>
                </div>
              </td>
              <td class="px-4 py-3">
                <span class="device-type" :class="`device-type--${deviceCategory(device)}`">
                  <AppIcon :name="categoryIcon(deviceCategory(device))" :size="14" />
                  {{ categoryLabel(deviceCategory(device)) }}
                </span>
              </td>
              <td class="px-4 py-3 text-slate-600">{{ t(`org.roles.${device.pos_role ?? 'standalone'}`) }}</td>
              <td class="px-4 py-3">
                <div v-if="device.sync_token" class="token-cell">
                  <span class="font-mono text-xs text-slate-500">
                    {{ isTokenVisible(device.id) ? device.sync_token : maskToken(device.sync_token) }}
                  </span>
                  <button type="button" class="token-reveal" @click="toggleToken(device.id)">
                    {{ isTokenVisible(device.id) ? t('org.hideToken') : t('org.showToken') }}
                  </button>
                </div>
                <span v-else class="text-xs text-slate-400">—</span>
              </td>
              <td class="px-4 py-3"><StatusBadge :active="device.is_active" /></td>
              <td class="px-4 py-3">
                <span class="reg-pill" :class="deviceStatus(device) === 'active' ? 'reg-pill--ok' : 'reg-pill--pending'">
                  {{ registrationLabel(deviceStatus(device)) }}
                </span>
                <p class="m-0 mt-1 text-xs text-slate-500">{{ registrationAgo(device) }}</p>
                <p v-if="device.local_server" class="m-0 mt-1 text-xs text-slate-400">{{ device.local_server }}</p>
              </td>
              <td class="px-4 py-3 text-right space-x-2">
                <button class="text-brand-600" @click="openEdit(device)"><AppIcon name="edit" :size="16" /> {{ t('common.edit') }}</button>
                <button v-if="deviceStatus(device) !== 'revoked'" class="text-amber-700" @click="revoke(device)">{{ t('org.revokeDevice') }}</button>
                <button class="text-red-600" @click="remove(device)"><AppIcon name="trash" :size="16" /> {{ t('common.delete') }}</button>
              </td>
            </tr>
          </tbody>
        </table>
        <ListPager :page="page" :last-page="lastPage" :total="total" :per-page="perPage" @change="setPage" />
        <p v-if="!filtered.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
      </div>
    </div>

    <AppModal
      :open="showModal"
      size="xl"
      :title="editing ? t('org.editDevice') : t('org.addDevice')"
      @close="showModal = false"
    >
      <form class="space-y-4" @submit.prevent="save">
        <div>
          <FieldLabel icon="device-pos">{{ t('org.deviceCategory') }}</FieldLabel>
          <div class="choice-grid">
            <button
              v-for="category in categories"
              :key="category"
              type="button"
              class="choice-card"
              :class="[`choice-card--${category}`, { 'choice-card--active': form.category === category }]"
              @click="form.category = category"
            >
              <span class="choice-card__icon"><AppIcon :name="categoryIcon(category)" :size="20" /></span>
              <span>{{ categoryLabel(category) }}</span>
            </button>
          </div>
          <p v-if="categoryHint" class="mt-1 text-xs text-slate-500">{{ categoryHint }}</p>
        </div>

        <div>
          <FieldLabel icon="device-pos">{{ t('org.deviceName') }} *</FieldLabel>
          <input v-model="form.name" required class="field w-full" :placeholder="t('org.deviceNamePlaceholder')" />
        </div>

        <fieldset class="device-panel">
          <legend>{{ t('org.connectionConfig') }}</legend>
          <div class="grid gap-3 sm:grid-cols-2">
            <div class="sm:col-span-2">
              <FieldLabel icon="conn-network">{{ t('org.connectionType') }}</FieldLabel>
              <div class="choice-grid choice-grid--connections">
                <button
                  v-for="connection in connections"
                  :key="connection"
                  type="button"
                  class="choice-card"
                  :class="[`choice-card--${connection}`, { 'choice-card--active': form.connection_type === connection }]"
                  @click="form.connection_type = connection"
                >
                  <span class="choice-card__icon"><AppIcon :name="connectionIcon(connection)" :size="20" /></span>
                  <span>{{ t(`org.connections.${connection}`) }}</span>
                </button>
              </div>
            </div>
            <template v-if="form.connection_type === 'network'">
              <div>
                <FieldLabel icon="conn-network">{{ t('org.ipAddress') }}</FieldLabel>
                <input v-model="form.ip_address" class="field w-full" placeholder="192.168.1.100 ou localhost" />
              </div>
              <div>
                <FieldLabel icon="conn-network">{{ t('org.port') }}</FieldLabel>
                <input v-model.number="form.port" type="number" min="1" max="65535" class="field w-full" />
              </div>
            </template>
          </div>
        </fieldset>

        <div>
          <FieldLabel icon="note">{{ t('org.descriptionOptional') }}</FieldLabel>
          <textarea v-model="form.description" rows="2" class="field w-full" :placeholder="t('org.descriptionPlaceholder')" />
        </div>

        <div class="grid gap-3 sm:grid-cols-3">
          <div>
            <FieldLabel icon="organization">{{ t('org.deviceRole') }}</FieldLabel>
            <select v-model="form.pos_role" class="field w-full">
              <option v-for="role in roles" :key="role" :value="role">{{ t(`org.roles.${role}`) }}</option>
            </select>
          </div>
          <div>
            <FieldLabel icon="tag">{{ t('org.registration') }}</FieldLabel>
            <input class="field w-full" :value="registrationLabel(form.registration_status)" disabled />
          </div>
          <div>
            <FieldLabel icon="device-pos">{{ t('org.deviceCategory') }}</FieldLabel>
            <input class="field w-full" :value="form.category" disabled />
          </div>
        </div>

        <div v-if="form.sync_token" class="token-box">
          <div>
            <p class="m-0 text-xs font-semibold uppercase tracking-wide text-slate-500">{{ t('org.syncToken') }}</p>
            <p class="token-value">{{ showFormToken ? form.sync_token : maskToken(form.sync_token) }}</p>
            <p class="m-0 text-xs text-slate-500">{{ t('org.syncTokenHint') }}</p>
          </div>
          <div class="flex shrink-0 gap-2">
            <button type="button" class="btn-secondary" @click="showFormToken = !showFormToken">
              {{ showFormToken ? t('org.hideToken') : t('org.showToken') }}
            </button>
            <button type="button" class="btn-secondary" :disabled="!showFormToken" @click="copyToken">
              <AppIcon name="layers" :size="16" />
              {{ copied ? t('org.copied') : t('org.copyToken') }}
            </button>
            <button type="button" class="btn-secondary" :class="{ 'is-busy': saving }" :disabled="saving" @click="regenerate">
              {{ t('org.regenerateToken') }}
            </button>
          </div>
        </div>
        <p v-else class="text-xs text-slate-500">{{ t('org.syncTokenCreatedHint') }}</p>

        <label class="flex items-center gap-2 text-sm">
          <span class="field-icon"><AppIcon name="check" :size="14" /></span>
          <input v-model="form.is_active" type="checkbox" class="rounded" />
          {{ t('products.active') }}
        </label>

        <p v-if="saveError" class="save-banner save-banner--error">{{ saveError }}</p>
        <p v-if="saveNotice" class="save-banner save-banner--ok">{{ saveNotice }}</p>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showModal = false"><AppIcon name="close" :size="16" /> {{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :class="{ 'is-busy': saving }" :disabled="saving || !storeId"><AppIcon name="check" :size="16" /> {{ saving ? t('common.saving') : t('common.save') }}</button>
        </div>
      </form>
    </AppModal>
  </OrganizationLayout>
</template>

<style scoped>


.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.45rem 0.75rem; font-size: 0.8125rem; background: var(--color-surface);}
.text-brand-600 { color: var(--color-ink-brand, var(--color-brand-600));}

.device-entry {
  display: flex;
  align-items: flex-start;
  gap: 0.7rem;
}

.device-entry__icon {
  display: grid;
  place-items: center;
  width: 2.25rem;
  height: 2.25rem;
  flex-shrink: 0;
  border-radius: 0.65rem;
  background: #eef2f6;
  color: #64748b;
}

.device-entry__icon--pos { background: color-mix(in srgb, #2563eb 14%, white); color: #2563eb; }
.device-entry__icon--printer { background: color-mix(in srgb, #d97706 14%, white); color: #d97706; }
.device-entry__icon--tablet { background: color-mix(in srgb, var(--color-brand-600, #12243c) 14%, white); color: var(--color-brand-600, #12243c); }
.device-entry__icon--computer { background: color-mix(in srgb, #0f766e 14%, white); color: #0f766e; }
.device-entry__icon--other,
.device-entry__icon--scanner { background: color-mix(in srgb, #64748b 14%, white); color: #64748b; }

.device-entry__body {
  min-width: 0;
}

.device-entry__conn {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  margin-top: 0.15rem;
}

.device-type {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  padding: 0.2rem 0.55rem 0.2rem 0.35rem;
  border-radius: 999px;
  font-size: 0.75rem;
  font-weight: 600;
  background: #eef2f6;
  color: #475569;
  white-space: nowrap;
}

.device-type--pos { background: color-mix(in srgb, #2563eb 12%, white); color: #1d4ed8; }
.device-type--printer { background: color-mix(in srgb, #d97706 12%, white); color: #b45309; }
.device-type--tablet { background: color-mix(in srgb, var(--color-brand-600, #12243c) 12%, white); color: var(--color-brand-600, #12243c); }
.device-type--computer { background: color-mix(in srgb, #0f766e 12%, white); color: #0f766e; }
.device-type--other,
.device-type--scanner { background: color-mix(in srgb, #64748b 12%, white); color: #475569; }
.choice-grid {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  gap: 0.55rem;
}
.choice-grid--connections {
  grid-template-columns: repeat(3, minmax(0, 1fr));
}
@media (max-width: 720px) {
  .choice-grid,
  .choice-grid--connections {
    grid-template-columns: 1fr;
  }
}
.choice-card {
  display: flex;
  align-items: center;
  gap: 0.55rem;
  min-height: 3.1rem;
  padding: 0.55rem 0.7rem;
  border: 1px solid #e2e8f0;
  border-radius: 0.8rem;
  background: var(--color-surface);
  color: var(--color-text-secondary);
  text-align: left;
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;}
.choice-card:hover {
  border-color: #c5d4df;
  background: var(--color-table-header);}
.choice-card--active {
  box-shadow: 0 0 0 1px currentColor;
}
.choice-card__icon {
  display: grid;
  place-items: center;
  width: 2rem;
  height: 2rem;
  flex-shrink: 0;
  border-radius: 0.6rem;
  background: var(--color-table-header);}
.choice-card--pos { --tone: #2563eb; }
.choice-card--printer { --tone: #d97706; }
.choice-card--tablet { --tone: var(--color-brand-600); }
.choice-card--computer { --tone: #0f766e; }
.choice-card--other { --tone: #64748b; }
.choice-card--network { --tone: #0284c7; }
.choice-card--usb { --tone: #db2777; }
.choice-card--bluetooth { --tone: #4f46e5; }
.choice-card--pos,
.choice-card--printer,
.choice-card--tablet,
.choice-card--computer,
.choice-card--other,
.choice-card--network,
.choice-card--usb,
.choice-card--bluetooth {
  color: var(--color-text-secondary);}
.choice-card--pos .choice-card__icon,
.choice-card--printer .choice-card__icon,
.choice-card--tablet .choice-card__icon,
.choice-card--computer .choice-card__icon,
.choice-card--other .choice-card__icon,
.choice-card--network .choice-card__icon,
.choice-card--usb .choice-card__icon,
.choice-card--bluetooth .choice-card__icon {
  background: color-mix(in srgb, var(--tone) 14%, white);
  color: var(--tone);
}
.choice-card--active.choice-card--pos,
.choice-card--active.choice-card--printer,
.choice-card--active.choice-card--tablet,
.choice-card--active.choice-card--computer,
.choice-card--active.choice-card--other,
.choice-card--active.choice-card--network,
.choice-card--active.choice-card--usb,
.choice-card--active.choice-card--bluetooth {
  border-color: var(--tone);
  background: color-mix(in srgb, var(--tone) 8%, white);
  color: var(--tone);
  box-shadow: 0 0 0 1px var(--tone);
}
.choice-card--active .choice-card__icon {
  background: var(--tone);
  color: white;
}
.device-panel { margin: 0; border: 1px solid #e4e8ec; border-radius: 0.75rem; padding: 0.85rem; }
.device-panel legend { padding: 0 0.35rem; font-size: 0.8125rem; font-weight: 600; color: var(--color-ink-brand, var(--color-brand-600));}
.token-cell { display: flex; align-items: center; gap: 0.55rem; }
.token-reveal { border: 0; background: transparent; padding: 0; color: var(--color-ink-brand, var(--color-brand-600)); font-size: 0.75rem; font-weight: 600; cursor: pointer;}
.token-reveal:hover { color: var(--color-ink-brand, var(--color-brand-700));}
.token-box { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 0.75rem; border-radius: 0.75rem; background: #f3f6f8; padding: 0.85rem; }
.token-value { margin: 0.2rem 0; font-family: var(--font-sans); font-size: 0.95rem; font-weight: 700; letter-spacing: 0.04em; color: var(--color-text-primary);}
.reg-pill { display: inline-flex; border-radius: 999px; padding: 0.15rem 0.55rem; font-size: 0.75rem; font-weight: 600; }
.reg-pill--pending { background: #f8efdc; color: light-dark(#9a6810, #c4a774);}
.reg-pill--ok { background: var(--color-success-bg); color: light-dark(#047857, #96c6b8);}
.save-banner { margin: 0; border-radius: 0.65rem; padding: 0.65rem 0.75rem; font-size: 0.8125rem; }
.save-banner--error { background: var(--color-danger-bg); color: light-dark(#b91c1c, #e2a0a0);}
.save-banner--ok { background: var(--color-success-bg); color: light-dark(#047857, #96c6b8);}
</style>
