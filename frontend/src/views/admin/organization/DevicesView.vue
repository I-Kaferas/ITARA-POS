<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import OrganizationLayout from '../../../components/organization/OrganizationLayout.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import ModuleFilters from '../../../components/ui/ModuleFilters.vue'
import { extractApiErrorMessage } from '../../../api/client'
import { useBackofficeStore } from '../../../stores/backoffice'
import { useContextStore } from '../../../stores/context'
import type { Device, DeviceCategory, DeviceConnection, DeviceRole } from '../../../types'
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
  const branchId = context.activeStores.find(item => item.id === id)?.branch_id
  await Promise.all([
    store.loadDevices(id, props.deviceType ?? undefined),
    branchId ? store.loadWarehouses(branchId) : Promise.resolve(),
  ])
})

function emptyForm() {
  return {
    name: '',
    category: (props.deviceType && props.deviceType !== 'scanner' ? props.deviceType : 'pos') as DeviceCategory,
    pos_role: 'master' as DeviceRole,
    connection_type: 'network' as DeviceConnection,
    ip_address: '',
    port: 9100,
    warehouse_ids: [] as string[],
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
    warehouse_ids: device.warehouse_ids ?? device.warehouses?.map(item => item.id) ?? [],
    description: device.description ?? '',
    is_active: device.is_active,
    sync_token: device.sync_token ?? '',
    registration_status: device.registration_status ?? 'pending',
  }
  showModal.value = true
}

async function save() {
  saveError.value = ''
  saveNotice.value = ''

  if (!storeId.value) {
    saveError.value = t('pos.selectStore')
    return
  }

  const ip = form.value.ip_address.trim()
  if (form.value.connection_type === 'network' && ip && !/^(\d{1,3}\.){3}\d{1,3}$/.test(ip) && !ip.includes(':')) {
    saveError.value = t('org.deviceSaveFailed')
    return
  }

  saving.value = true
  const creating = !editing.value
  try {
    const saved = await store.saveDevice(storeId.value, {
      name: form.value.name.trim(),
      category: form.value.category,
      device_type: form.value.category,
      pos_role: form.value.pos_role,
      connection_type: form.value.connection_type,
      ip_address: form.value.connection_type === 'network' ? ip || null : null,
      port: form.value.connection_type === 'network' ? Number(form.value.port) || 9100 : null,
      warehouse_ids: form.value.warehouse_ids,
      description: form.value.description.trim() || null,
      is_active: form.value.is_active,
    }, editing.value?.id)
    await store.loadDevices(storeId.value, props.deviceType ?? undefined)
    saveNotice.value = t('org.deviceSaved')
    if (creating && saved) {
      openEdit(saved)
      saveNotice.value = t('org.deviceSaved')
      return
    }
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

function toggleWarehouse(id: string, checked: boolean) {
  form.value.warehouse_ids = checked
    ? [...form.value.warehouse_ids, id]
    : form.value.warehouse_ids.filter(item => item !== id)
}

function categoryLabel(category: string) {
  return t(`org.deviceCategories.${category}`)
}

function categoryIcon(category: string) {
  return `device-${category}`
}

function connectionIcon(connection: string) {
  return `conn-${connection}`
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
          + {{ t('org.addDevice') }}
        </button>
      </div>

      <ModuleFilters v-model="filters" :show-period="false" show-search show-active />

      <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <table class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.deviceCode') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.deviceName') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.deviceCategory') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.deviceRole') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.registration') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.syncToken') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('products.status') }}</th>
              <th class="px-4 py-3 text-right">{{ t('common.edit') }}</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="device in filtered" :key="device.id" class="hover:bg-slate-50">
              <td class="px-4 py-3 font-mono text-xs">{{ device.code || '—' }}</td>
              <td class="px-4 py-3">
                <p class="m-0 font-medium">{{ device.name }}</p>
                <p class="m-0 text-xs text-slate-400">
                  {{ device.user?.name || '—' }} · {{ device.branch?.name || '—' }}
                  <template v-if="device.app_version"> · {{ device.app_version }}</template>
                </p>
                <p v-if="device.connection_type" class="m-0 text-xs text-slate-400">
                  {{ t(`org.connections.${device.connection_type}`) }}
                  <template v-if="device.ip_address"> · {{ device.ip_address }}<span v-if="device.port">:{{ device.port }}</span></template>
                </p>
              </td>
              <td class="px-4 py-3 text-slate-600">{{ categoryLabel(device.category ?? device.device_type) }}</td>
              <td class="px-4 py-3 text-slate-600">{{ t(`org.roles.${device.pos_role ?? 'standalone'}`) }}</td>
              <td class="px-4 py-3">
                <span class="reg-pill" :class="deviceStatus(device) === 'active' ? 'reg-pill--ok' : 'reg-pill--pending'">
                  {{ registrationLabel(deviceStatus(device)) }}
                </span>
                <p v-if="device.local_server" class="m-0 mt-1 text-xs text-slate-400">{{ device.local_server }}</p>
                <p v-if="device.last_sync || device.last_sync_at" class="m-0 mt-1 text-xs text-slate-400">
                  {{ t('org.lastSync') }} · {{ device.last_sync || device.last_sync_at }}
                </p>
              </td>
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
              <td class="px-4 py-3 text-right space-x-2">
                <button class="text-brand-600" @click="openEdit(device)">{{ t('common.edit') }}</button>
                <button v-if="deviceStatus(device) !== 'revoked'" class="text-amber-700" @click="revoke(device)">{{ t('org.revokeDevice') }}</button>
                <button class="text-red-600" @click="remove(device)">{{ t('common.delete') }}</button>
              </td>
            </tr>
          </tbody>
        </table>
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
                <input v-model="form.ip_address" class="field w-full" placeholder="192.168.1.100" />
              </div>
              <div>
                <FieldLabel icon="conn-network">{{ t('org.port') }}</FieldLabel>
                <input v-model.number="form.port" type="number" min="1" max="65535" class="field w-full" />
              </div>
            </template>
          </div>
        </fieldset>

        <div>
          <FieldLabel icon="inventory">{{ t('org.assignWarehouses') }}</FieldLabel>
          <div class="warehouse-box">
            <label v-for="warehouse in store.warehouses" :key="warehouse.id" class="warehouse-option">
              <input
                type="checkbox"
                :checked="form.warehouse_ids.includes(warehouse.id)"
                @change="toggleWarehouse(warehouse.id, ($event.target as HTMLInputElement).checked)"
              />
              <span>{{ warehouse.name }}</span>
              <span class="text-xs text-slate-400">{{ warehouse.code }}</span>
            </label>
            <p v-if="!store.warehouses.length" class="m-0 text-sm text-slate-400">{{ t('org.noWarehouses') }}</p>
          </div>
          <p class="mt-1 text-xs text-slate-500">{{ t('org.assignWarehousesHint') }}</p>
        </div>

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
              {{ copied ? t('org.copied') : t('org.copyToken') }}
            </button>
            <button type="button" class="btn-secondary" :disabled="saving" @click="regenerate">
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
          <button type="button" class="btn-secondary" @click="showModal = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving || !storeId">{{ saving ? t('common.loading') : t('common.save') }}</button>
        </div>
      </form>
    </AppModal>
  </OrganizationLayout>
</template>

<style scoped>


.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.45rem 0.75rem; font-size: 0.8125rem; background: white; }
.text-brand-600 { color: var(--color-brand-600); }
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
  background: #fff;
  color: #334155;
  text-align: left;
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
}
.choice-card:hover {
  border-color: #c5d4df;
  background: #f8fafc;
}
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
  background: #f1f5f9;
}
.choice-card--pos { --tone: #2563eb; }
.choice-card--printer { --tone: #d97706; }
.choice-card--tablet { --tone: #7c3aed; }
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
  color: #334155;
}
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
.device-panel legend { padding: 0 0.35rem; font-size: 0.8125rem; font-weight: 600; color: #3d5c73; }
.warehouse-box { display: grid; gap: 0.4rem; max-height: 9rem; overflow: auto; border: 1px solid #e4e8ec; border-radius: 0.75rem; padding: 0.55rem; }
.warehouse-option { display: flex; align-items: center; gap: 0.5rem; font-size: 0.875rem; }
.token-cell { display: flex; align-items: center; gap: 0.55rem; }
.token-reveal { border: 0; background: transparent; padding: 0; color: var(--color-brand-600); font-size: 0.75rem; font-weight: 600; cursor: pointer; }
.token-reveal:hover { color: var(--color-brand-700); }
.token-box { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 0.75rem; border-radius: 0.75rem; background: #f3f6f8; padding: 0.85rem; }
.token-value { margin: 0.2rem 0; font-family: ui-monospace, monospace; font-size: 0.95rem; font-weight: 700; letter-spacing: 0.04em; color: #1a2833; }
.reg-pill { display: inline-flex; border-radius: 999px; padding: 0.15rem 0.55rem; font-size: 0.75rem; font-weight: 600; }
.reg-pill--pending { background: #f8efdc; color: #9a6810; }
.reg-pill--ok { background: #ecfdf5; color: #047857; }
.save-banner { margin: 0; border-radius: 0.65rem; padding: 0.65rem 0.75rem; font-size: 0.8125rem; }
.save-banner--error { background: #fef2f2; color: #b91c1c; }
.save-banner--ok { background: #ecfdf5; color: #047857; }
</style>
