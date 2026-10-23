<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import OrganizationLayout from '../../../components/organization/OrganizationLayout.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import FilterFold from '../../../components/ui/FilterFold.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import EmptyState from '../../../components/ui/EmptyState.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { watchLiveSearch } from '../../../composables/useLiveSearch'
import { extractApiErrorMessage } from '../../../api/client'
import { useAuthStore } from '../../../stores/auth'
import { useBackofficeStore } from '../../../stores/backoffice'
import { useContextStore } from '../../../stores/context'
import type { TenantUser, UserSession } from '../../../types'
import { formatDate } from '../../../utils/format'

const { t } = useI18n()
const store = useBackofficeStore()
const context = useContextStore()
const auth = useAuthStore()

const search = ref('')
const status = ref<'all' | 'active' | 'inactive'>('all')
const roleId = ref('')
const message = ref('')
const saving = ref(false)
const loading = ref(true)
const directory = ref({ total: 0, active: 0, inactive: 0 })

const showUserModal = ref(false)
const showRoleModal = ref(false)
const showPasswordModal = ref(false)
const editingUser = ref<TenantUser | null>(null)
const selectedUser = ref<TenantUser | null>(null)
const sessions = ref<UserSession[]>([])

const userForm = ref({ name: '', email: '', phone: '', pin: '', password: '', is_active: true, role_id: '', store_id: '', store_ids: [] as string[] })
const draftStoreIds = ref<string[]>([])
const showPin = ref(false)
const revealedPins = ref<Record<string, boolean>>({})
const roleForm = ref({ role_id: '', store_id: '' })
const passwordForm = ref('')

const currentUserId = computed(() => auth.user?.id)
const filtersActive = computed(() => Boolean(search.value.trim() || status.value !== 'all' || roleId.value))
const listedUser = computed(() => store.users.find(user => user.id === selectedUser.value?.id) ?? null)
const storesDirty = computed(() => {
  const saved = [...(selectedUser.value?.store_ids ?? [])].sort()
  const draft = [...draftStoreIds.value].sort()
  return saved.length !== draft.length || saved.some((id, index) => id !== draft[index])
})

function storeChanged(id: string) {
  const saved = selectedUser.value?.store_ids ?? []
  return saved.includes(id) !== draftStoreIds.value.includes(id)
}

onMounted(async () => {
  await Promise.all([reload(), store.loadRoles(), context.loadDirectoryStores()])
})

watch([status, roleId], () => reload())
watchLiveSearch(search, reload)

async function reload() {
  loading.value = true
  try {
    await store.loadUsers({
      search: search.value.trim(),
      status: status.value,
      role_id: roleId.value,
    })
    if (!filtersActive.value) {
      directory.value = {
        total: store.users.length,
        active: store.users.filter(user => user.is_active !== false).length,
        inactive: store.users.filter(user => user.is_active === false).length,
      }
    }
  } catch (error) {
    message.value = extractApiErrorMessage(error, t('common.error'))
  } finally {
    loading.value = false
  }
}

function setStatus(next: 'all' | 'active' | 'inactive') {
  status.value = status.value === next && next !== 'all' ? 'all' : next
}

function clearFilters() {
  search.value = ''
  status.value = 'all'
  roleId.value = ''
}

function initials(name: string) {
  return name
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map(part => part[0]?.toUpperCase() ?? '')
    .join('') || '?'
}

function storeName(id?: string | null) {
  if (!id) return t('org.allAccess')
  return context.activeDirectoryStores.find(storeItem => storeItem.id === id)
    ? context.storeLabel(context.activeDirectoryStores.find(storeItem => storeItem.id === id)!)
    : id
}

function assignedStoreLabel(user: TenantUser) {
  const names = (user.stores ?? []).map(item => item.name).filter(Boolean)
  return names.length ? names.join(', ') : t('org.allStores')
}

function toggleId(ids: string[], id: string) {
  return ids.includes(id) ? ids.filter(storeId => storeId !== id) : [...ids, id]
}

function usedPins(exceptId?: string) {
  return new Set(
    store.users
      .filter(user => user.id !== exceptId && user.pin)
      .map(user => user.pin as string),
  )
}

function nextUniquePin(exceptId?: string) {
  const used = usedPins(exceptId)
  for (let attempt = 0; attempt < 40; attempt += 1) {
    const pin = String(Math.floor(Math.random() * 10000)).padStart(4, '0')
    if (!used.has(pin)) return pin
  }
  return String(Math.floor(Math.random() * 1000000)).padStart(6, '0')
}

const pinError = computed(() => {
  const pin = userForm.value.pin.trim()
  if (!pin) return t('org.pinInvalid')
  if (!/^\d{4,6}$/.test(pin)) return t('org.pinInvalid')
  if (usedPins(editingUser.value?.id).has(pin)) return t('org.pinTaken')
  return ''
})

function maskPin(pin?: string | null) {
  if (!pin) return '—'
  return '•'.repeat(pin.length)
}

function openCreateUser() {
  editingUser.value = null
  showPin.value = true
  userForm.value = {
    name: '',
    email: '',
    phone: '',
    pin: nextUniquePin(),
    password: '',
    is_active: true,
    role_id: '',
    store_id: '',
    store_ids: context.currentStoreId ? [context.currentStoreId] : [],
  }
  showUserModal.value = true
}

function openEditUser(user: TenantUser) {
  editingUser.value = user
  showPin.value = false
  userForm.value = {
    name: user.name,
    email: user.email,
    phone: user.phone ?? '',
    pin: user.pin ?? nextUniquePin(user.id),
    password: '',
    is_active: user.is_active !== false,
    role_id: '',
    store_id: '',
    store_ids: [...(user.store_ids ?? [])],
  }
  showUserModal.value = true
}

function generatePin() {
  userForm.value.pin = nextUniquePin(editingUser.value?.id)
  showPin.value = true
}

async function saveUser() {
  if (pinError.value) {
    message.value = pinError.value
    return
  }
  saving.value = true
  message.value = ''
  try {
    const payload: Record<string, unknown> = {
      name: userForm.value.name,
      email: userForm.value.email,
      phone: userForm.value.phone || null,
      pin: userForm.value.pin.trim(),
      is_active: userForm.value.is_active,
    }
    if (userForm.value.password) payload.password = userForm.value.password
    if (!editingUser.value) {
      if (!userForm.value.password) return
      if (userForm.value.store_ids.length && !userForm.value.role_id) {
        message.value = t('org.storeRequiredRole')
        saving.value = false
        return
      }
      if (userForm.value.role_id) payload.role_id = userForm.value.role_id
    }
    const saved = await store.saveUser(payload as never, editingUser.value?.id)
    if (!editingUser.value && userForm.value.store_ids.length) {
      await store.assignUserStore(saved.id, userForm.value.store_ids, userForm.value.role_id || null)
    }
    await reload()
    showUserModal.value = false
    const pin = saved.pin ?? userForm.value.pin
    message.value = `${editingUser.value ? t('org.userSaved') : t('org.userCreated')} · PIN ${pin}`
    if (selectedUser.value?.id === saved.id) selectedUser.value = saved
  } catch (error) {
    message.value = extractApiErrorMessage(error, t('org.pinTaken'))
  } finally {
    saving.value = false
  }
}

async function openUser(user: TenantUser) {
  selectedUser.value = user
  draftStoreIds.value = [...(user.store_ids ?? [])]
  sessions.value = await store.loadUserSessions(user.id)
}

async function saveStores() {
  if (!selectedUser.value) return
  saving.value = true
  message.value = ''
  try {
    const saved = await store.assignUserStore(selectedUser.value.id, draftStoreIds.value)
    await reload()
    selectedUser.value = store.users.find(user => user.id === saved.id) ?? saved
    draftStoreIds.value = [...(selectedUser.value.store_ids ?? [])]
    message.value = t('org.storeAssigned')
    if (saved.id === auth.user?.id) {
      await auth.fetchMe()
      await context.loadStores()
    }
  } catch (error) {
    message.value = extractApiErrorMessage(error, t('org.storeRequiredRole'))
  } finally {
    saving.value = false
  }
}

async function assign() {
  if (!selectedUser.value || !roleForm.value.role_id) return
  saving.value = true
  try {
    await store.assignUserRole(selectedUser.value.id, roleForm.value.role_id, null, roleForm.value.store_id || null)
    await reload()
    selectedUser.value = store.users.find(user => user.id === selectedUser.value?.id) ?? selectedUser.value
    showRoleModal.value = false
    roleForm.value = { role_id: '', store_id: '' }
  } finally {
    saving.value = false
  }
}

async function unassign(user: TenantUser, roleIdToRemove: string) {
  if (!confirm(t('org.confirmDelete'))) return
  await store.removeUserRole(user.id, roleIdToRemove)
  await reload()
  if (selectedUser.value?.id === user.id) {
    selectedUser.value = store.users.find(item => user.id === item.id) ?? null
  }
}

async function toggleActive(user: TenantUser) {
  if (user.id === currentUserId.value) {
    message.value = t('org.cannotManageSelf')
    return
  }
  const next = user.is_active === false
  if (!next && !confirm(t('org.deactivate'))) return
  await store.setUserActive(user.id, next)
  await reload()
  if (selectedUser.value?.id === user.id) {
    selectedUser.value = store.users.find(item => item.id === user.id) ?? null
    sessions.value = await store.loadUserSessions(user.id)
  }
}

async function resetPassword() {
  if (!selectedUser.value || passwordForm.value.length < 8) return
  saving.value = true
  try {
    await store.resetUserPassword(selectedUser.value.id, passwordForm.value)
    passwordForm.value = ''
    showPasswordModal.value = false
    sessions.value = []
    message.value = t('org.passwordReset')
    await reload()
  } finally {
    saving.value = false
  }
}

async function revokeSessions(user: TenantUser) {
  if (!confirm(t('org.revokeSessions'))) return
  await store.revokeUserSessions(user.id)
  sessions.value = []
  await reload()
}

async function removeUser(user: TenantUser) {
  if (user.id === currentUserId.value) {
    message.value = t('org.cannotManageSelf')
    return
  }
  if (!confirm(t('org.confirmDelete'))) return
  await store.deleteUser(user.id)
  if (selectedUser.value?.id === user.id) selectedUser.value = null
  await reload()
}

function openAssign(user: TenantUser) {
  selectedUser.value = user
  roleForm.value = { role_id: '', store_id: context.currentStoreId ?? '' }
  showRoleModal.value = true
}
</script>

<template>
  <OrganizationLayout>
    <div class="users">
      <div class="users__head">
        <div>
          <h2 class="users__title">{{ t('org.usersTitle') }}</h2>
          <p class="users__subtitle">{{ t('org.usersSubtitle') }}</p>
        </div>
        <button class="btn-primary" @click="openCreateUser">
          <AppIcon name="plus" :size="16" />
          {{ t('org.addUser') }}
        </button>
      </div>

      <p v-if="message" class="users__notice" role="status">{{ message }}</p>

      <div class="users__stats">
        <button type="button" class="kpi-card users__kpi" :class="{ 'is-on': status === 'all' }" @click="setStatus('all')">
          <span class="users__kpi-value">{{ directory.total }}</span>
          <span class="users__kpi-label">{{ t('org.tabs.users') }}</span>
        </button>
        <button type="button" class="kpi-card users__kpi" :class="{ 'is-on': status === 'active' }" @click="setStatus('active')">
          <span class="users__kpi-value">{{ directory.active }}</span>
          <span class="users__kpi-label">{{ t('org.activeUsers') }}</span>
        </button>
        <button type="button" class="kpi-card users__kpi" :class="{ 'is-on': status === 'inactive' }" @click="setStatus('inactive')">
          <span class="users__kpi-value">{{ directory.inactive }}</span>
          <span class="users__kpi-label">{{ t('org.inactiveUsers') }}</span>
        </button>
      </div>

      <div class="users__layout" :class="{ 'is-single': !loading && !store.users.length && !listedUser }">
        <section class="users__directory">
          <FilterFold>
          <div class="users__filters">
            <label class="users__search">
              <AppIcon name="search" :size="16" />
              <input v-model="search" type="search" class="field" :placeholder="t('org.searchUsers')" />
            </label>
            <select v-model="status" class="field">
              <option value="all">{{ t('org.allStatuses') }}</option>
              <option value="active">{{ t('org.activeUsers') }}</option>
              <option value="inactive">{{ t('org.inactiveUsers') }}</option>
            </select>
            <select v-model="roleId" class="field">
              <option value="">{{ t('rbac.roles') }}</option>
              <option v-for="role in store.roles" :key="role.id" :value="role.id">{{ role.name }}</option>
            </select>
          </div>
          </FilterFold>

          <div v-if="loading && !store.users.length" class="users__loading" aria-hidden="true">
            <span /><span /><span />
          </div>

          <EmptyState
            v-else-if="!store.users.length && !filtersActive"
            icon="account"
            :title="t('org.directoryEmpty')"
            :description="t('org.directoryEmptyHint')"
          >
            <div class="empty-state__actions">
              <button class="btn-primary" @click="openCreateUser">
                <AppIcon name="plus" :size="16" />
                {{ t('org.addUser') }}
              </button>
            </div>
          </EmptyState>

          <EmptyState
            v-else-if="!store.users.length"
            icon="search"
            :title="t('common.noResults')"
            :description="t('org.noMatch')"
          >
            <div class="empty-state__actions">
              <button class="btn-secondary" @click="clearFilters"><AppIcon name="filter" :size="16" /> {{ t('org.clearFilters') }}</button>
            </div>
          </EmptyState>

          <div v-else class="users__table">
            <table class="ui-table">
              <thead>
                <tr>
                  <th>{{ t('org.person') }}</th>
                  <th>{{ t('org.pin') }}</th>
                  <th>{{ t('products.status') }}</th>
                  <th>{{ t('rbac.roles') }}</th>
                  <th>{{ t('org.lastSeen') }}</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="user in store.users"
                  :key="user.id"
                  :class="{ 'is-selected': selectedUser?.id === user.id }"
                  @click="openUser(user)"
                >
                  <td>
                    <div class="users__person">
                      <span class="users__avatar" aria-hidden="true">{{ initials(user.name) }}</span>
                      <div>
                        <p class="users__name">
                          {{ user.name }}
                          <span v-if="user.id === currentUserId" class="users__you">{{ t('org.you') }}</span>
                        </p>
                        <p class="users__email">{{ user.email }}</p>
                      </div>
                    </div>
                  </td>
                  <td>
                    <button
                      type="button"
                      class="users__pin"
                      :aria-label="revealedPins[user.id] ? t('org.hidePin') : t('org.showPin')"
                      @click.stop="revealedPins[user.id] = !revealedPins[user.id]"
                    >
                      {{ revealedPins[user.id] ? (user.pin || '—') : maskPin(user.pin) }}
                    </button>
                  </td>
                  <td><StatusBadge :active="user.is_active !== false" /></td>
                  <td>
                    <div class="users__roleline">
                      <span v-for="role in user.roles" :key="role.id" class="users__pill">{{ role.name }}</span>
                      <span v-if="!user.roles?.length" class="muted">{{ t('org.noRole') }}</span>
                    </div>
                    <p class="users__email">{{ assignedStoreLabel(user) }}</p>
                  </td>
                  <td class="muted">{{ user.last_seen_at ? formatDate(user.last_seen_at) : t('org.neverSeen') }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <aside v-if="listedUser || store.users.length" class="users__detail">
          <template v-if="listedUser">
            <header class="users__profile">
              <span class="users__avatar users__avatar--lg" aria-hidden="true">{{ initials(selectedUser.name) }}</span>
              <div class="users__profile-id">
                <h3>{{ selectedUser.name }}</h3>
                <p>{{ selectedUser.email }}</p>
              </div>
              <StatusBadge :active="selectedUser.is_active !== false" />
            </header>

            <div class="users__actions">
              <button class="btn-secondary" @click="openEditUser(selectedUser)"><AppIcon name="edit" :size="16" /> {{ t('common.edit') }}</button>
              <button class="btn-secondary" @click="showPasswordModal = true; passwordForm = ''">{{ t('org.resetPassword') }}</button>
              <button class="btn-secondary" @click="revokeSessions(selectedUser)"><AppIcon name="trash" :size="16" /> {{ t('org.revokeSessions') }}</button>
              <button class="btn-secondary" :disabled="selectedUser.id === currentUserId" @click="toggleActive(selectedUser)">
                <AppIcon name="check" :size="16" />
                {{ selectedUser.is_active === false ? t('org.activate') : t('org.deactivate') }}
              </button>
              <button class="btn-danger" :disabled="selectedUser.id === currentUserId" @click="removeUser(selectedUser)"><AppIcon name="trash" :size="16" /> {{ t('common.delete') }}</button>
            </div>
            <p v-if="selectedUser.id === currentUserId" class="muted">{{ t('org.cannotManageSelf') }}</p>

            <section class="users__section">
              <h4>{{ t('org.identity') }}</h4>
              <dl class="users__meta">
                <div><dt>{{ t('common.phone') }}</dt><dd>{{ selectedUser.phone || '—' }}</dd></div>
                <div>
                  <dt>{{ t('org.pin') }}</dt>
                  <dd>
                    <button
                      type="button"
                      class="users__pin"
                      :aria-label="revealedPins[selectedUser.id] ? t('org.hidePin') : t('org.showPin')"
                      @click="revealedPins[selectedUser.id] = !revealedPins[selectedUser.id]"
                    >
                      {{ revealedPins[selectedUser.id] ? (selectedUser.pin || '—') : maskPin(selectedUser.pin) }}
                    </button>
                  </dd>
                </div>
                <div><dt>{{ t('org.lastSeen') }}</dt><dd>{{ selectedUser.last_seen_at ? formatDate(selectedUser.last_seen_at) : t('org.neverSeen') }}</dd></div>
                <div><dt>{{ t('org.sessionsCount') }}</dt><dd>{{ selectedUser.active_sessions_count ?? sessions.length }}</dd></div>
                <div><dt>{{ t('org.twoFactor') }}</dt><dd>{{ selectedUser.two_factor_enabled ? t('account.twoFactorOn') : t('account.twoFactorOff') }}</dd></div>
              </dl>
            </section>

            <section class="users__section">
              <div class="users__roles-head">
                <h4>{{ t('org.assignStore') }}</h4>
                <button
                  type="button"
                  class="users__save"
                  :class="{ 'is-dirty': storesDirty }"
                  :disabled="saving || !storesDirty"
                  @click="saveStores"
                >{{ t('common.save') }}</button>
              </div>
              <p class="muted">{{ t('org.assignStoresHint') }}</p>
              <div class="users__store-list">
                <label v-for="item in context.activeDirectoryStores" :key="item.id" class="users__store-item" :class="{ 'is-changed': storeChanged(item.id) }">
                  <input
                    type="checkbox"
                    :checked="draftStoreIds.includes(item.id)"
                    @change="draftStoreIds = toggleId(draftStoreIds, item.id)"
                  />
                  <span>{{ context.storeLabel(item) }}</span>
                </label>
                <p v-if="!context.activeDirectoryStores.length" class="muted">{{ t('settings.noStore') }}</p>
              </div>
            </section>

            <section class="users__section">
              <div class="users__roles-head">
                <h4>{{ t('rbac.roles') }}</h4>
                <button type="button" @click="openAssign(selectedUser)">{{ t('org.assignRole') }}</button>
              </div>
              <div v-if="selectedUser.roles?.length" class="users__chips">
                <span v-for="role in selectedUser.roles" :key="role.id" class="users__chip">
                  <strong>{{ role.name }}</strong>
                  <small>{{ storeName(role.store_id) }}</small>
                  <button type="button" :aria-label="t('common.delete')" @click="unassign(selectedUser, role.id)">×</button>
                </span>
              </div>
              <p v-else class="muted">{{ t('org.noRole') }}</p>
            </section>

            <section class="users__section users__sessions">
              <h4>{{ t('account.sessions') }}</h4>
              <p v-if="!sessions.length" class="muted">{{ t('org.neverSeen') }}</p>
              <div v-for="session in sessions" :key="session.id" class="users__session">
                <span>{{ session.device_name || t('account.unknownDevice') }}</span>
                <small>{{ session.ip_address || '—' }} · {{ session.last_used_at ? formatDate(session.last_used_at) : '—' }}</small>
              </div>
            </section>
          </template>

          <EmptyState
            v-else
            icon="account"
            :title="t('org.selectUserTitle')"
            :description="t('org.selectUserHint')"
          />
        </aside>
      </div>
    </div>

    <AppModal :open="showUserModal" :title="editingUser ? t('org.editUser') : t('org.addUser')" size="xl" @close="showUserModal = false">
      <form class="space-y-3" @submit.prevent="saveUser">
        <div><FieldLabel icon="account">{{ t('org.person') }}</FieldLabel><input v-model="userForm.name" required class="field" /></div>
        <div><FieldLabel icon="mail">{{ t('auth.email') }}</FieldLabel><input v-model="userForm.email" type="email" required class="field" /></div>
        <div><FieldLabel icon="phone">{{ t('common.phone') }}</FieldLabel><input v-model="userForm.phone" class="field" /></div>
        <div class="pin-field">
          <FieldLabel icon="lock">{{ t('org.pin') }}</FieldLabel>
          <div class="pin-field__row">
            <input
              v-model="userForm.pin"
              :type="showPin ? 'text' : 'password'"
              inputmode="numeric"
              maxlength="6"
              autocomplete="off"
              required
              class="field"
              :class="{ 'field--invalid': pinError }"
            />
            <button type="button" class="btn-secondary" @click="showPin = !showPin">
              {{ showPin ? t('org.hidePin') : t('org.showPin') }}
            </button>
            <button type="button" class="btn-secondary" @click="generatePin">{{ t('org.generatePin') }}</button>
          </div>
          <p class="pin-field__hint" :class="{ 'pin-field__hint--error': pinError }">{{ pinError || t('org.pinHint') }}</p>
        </div>
        <div>
          <FieldLabel icon="lock">{{ t('auth.password') }} <span v-if="editingUser" class="text-slate-400">({{ t('common.optional') }})</span></FieldLabel>
          <input v-model="userForm.password" type="password" :required="!editingUser" minlength="8" class="field" />
        </div>
        <template v-if="!editingUser">
          <div>
            <FieldLabel icon="organization">{{ t('rbac.roles') }}</FieldLabel>
            <select v-model="userForm.role_id" class="field">
              <option value="">{{ t('org.selectRole') }}</option>
              <option v-for="role in store.roles" :key="role.id" :value="role.id">{{ role.name }}</option>
            </select>
          </div>
          <div>
            <FieldLabel icon="stores">{{ t('org.assignStore') }}</FieldLabel>
            <p class="pin-field__hint">{{ t('org.assignStoresHint') }}</p>
            <div class="users__store-list">
              <label v-for="item in context.activeDirectoryStores" :key="item.id" class="users__store-item">
                <input
                  type="checkbox"
                  :checked="userForm.store_ids.includes(item.id)"
                  @change="userForm.store_ids = toggleId(userForm.store_ids, item.id)"
                />
                <span>{{ context.storeLabel(item) }}</span>
              </label>
            </div>
          </div>
        </template>
        <label class="flex items-center gap-2 text-sm"><span class="field-icon"><AppIcon name="check" :size="14" /></span><input v-model="userForm.is_active" type="checkbox" class="rounded" />{{ t('products.active') }}</label>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showUserModal = false"><AppIcon name="close" :size="16" /> {{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :class="{ 'is-busy': saving }" :disabled="saving"><AppIcon name="check" :size="16" /> {{ saving ? t('common.saving') : t('common.save') }}</button>
        </div>
      </form>
    </AppModal>

    <AppModal :open="showRoleModal" :title="t('org.assignRole')" @close="showRoleModal = false">
      <form class="space-y-3" @submit.prevent="assign">
        <div>
          <FieldLabel icon="organization">{{ t('rbac.roles') }}</FieldLabel>
          <select v-model="roleForm.role_id" required class="field">
            <option value="">{{ t('org.selectRole') }}</option>
            <option v-for="role in store.roles" :key="role.id" :value="role.id">{{ role.name }}</option>
          </select>
        </div>
        <div>
          <FieldLabel icon="stores">{{ t('org.roleScope') }}</FieldLabel>
          <select v-model="roleForm.store_id" class="field">
            <option value="">{{ t('org.allStores') }}</option>
            <option v-for="item in context.activeDirectoryStores" :key="item.id" :value="item.id">{{ context.storeLabel(item) }}</option>
          </select>
        </div>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showRoleModal = false"><AppIcon name="close" :size="16" /> {{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :class="{ 'is-busy': saving }" :disabled="saving"><AppIcon name="check" :size="16" /> {{ saving ? t('common.saving') : t('common.save') }}</button>
        </div>
      </form>
    </AppModal>

    <AppModal :open="showPasswordModal" :title="t('org.resetPassword')" @close="showPasswordModal = false">
      <form class="space-y-3" @submit.prevent="resetPassword">
        <div>
          <FieldLabel icon="lock">{{ t('org.newPassword') }}</FieldLabel>
          <input v-model="passwordForm" type="password" required minlength="8" class="field" />
        </div>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showPasswordModal = false"><AppIcon name="close" :size="16" /> {{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :class="{ 'is-busy': saving }" :disabled="saving"><AppIcon name="check" :size="16" /> {{ saving ? t('common.saving') : t('common.save') }}</button>
        </div>
      </form>
    </AppModal>
  </OrganizationLayout>
</template>

<style scoped>
.users { display: flex; flex-direction: column; gap: var(--space-4); }
.users__head,
.users__roles-head { display: flex; align-items: flex-start; justify-content: space-between; gap: var(--space-3); }
.users__title { margin: 0; font-family: var(--font-display); font-size: var(--text-xl); letter-spacing: -0.02em; }
.users__subtitle,
.users__email,
.muted { margin: 0.15rem 0 0; color: var(--color-text-muted); font-size: var(--text-sm); }
.users__notice {
  margin: 0;
  border: 1px solid var(--color-border);
  border-left: 3px solid var(--color-brand-600);
  border-radius: var(--radius-md);
  background: var(--color-surface);
  color: var(--color-text-primary);
  padding: var(--space-3) var(--space-4);
  font-size: var(--text-sm);
}
.users__stats { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: var(--space-3); }
.users__kpi {
  gap: var(--space-2);
  width: 100%;
  text-align: left;
  cursor: pointer;
  font: inherit;
  color: inherit;
}
.users__kpi.is-on {
  --kpi-accent: var(--color-sidebar-mark, #e39b2b);
  border-color: var(--color-brand-600);
}
.users__kpi-value {
  font-family: var(--font-display);
  font-size: var(--text-2xl);
  font-weight: 700;
  letter-spacing: -0.03em;
  line-height: 1;
}
.users__kpi-label { color: var(--color-text-muted); font-size: var(--text-sm); }
.users__layout {
  display: grid;
  grid-template-columns: minmax(0, 1.7fr) minmax(20rem, 0.85fr);
  gap: var(--space-4);
  align-items: start;
}
.users__layout.is-single { grid-template-columns: 1fr; }
.users__directory,
.users__detail {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-xs);
}
.users__filters {
  display: grid;
  grid-template-columns: minmax(0, 1.6fr) minmax(9rem, 0.7fr) minmax(10rem, 0.8fr);
  gap: var(--space-3);
  padding: var(--space-4);
  border-bottom: 1px solid var(--color-border);
}
.users__search { position: relative; display: block; min-width: 0; }
.users__search > :first-child {
  position: absolute;
  left: 0.85rem;
  top: 50%;
  z-index: 1;
  transform: translateY(-50%);
  color: var(--color-text-faint);
  pointer-events: none;
}
.users__search .field { width: 100%; padding-left: 2.4rem; }
.users__table { overflow-x: auto; }
.users__table tr { cursor: pointer; }
.users__table tr.is-selected td {
  background: color-mix(in srgb, var(--color-brand-600) 7%, var(--color-surface));
}
.users__table tr.is-selected td:first-child {
  box-shadow: inset 3px 0 0 var(--color-sidebar-mark, #e39b2b);
}
.users__person { display: flex; align-items: center; gap: var(--space-3); min-width: 12rem; }
.users__avatar {
  display: grid;
  place-items: center;
  flex-shrink: 0;
  width: 2.25rem;
  height: 2.25rem;
  border-radius: 999px;
  background: var(--color-brand-600);
  color: #fff;
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0.04em;
}
.users__avatar--lg {
  width: 3rem;
  height: 3rem;
  font-size: 0.95rem;
  background: var(--color-sidebar);
  color: var(--color-sidebar-mark);
}
.users__name { display: flex; align-items: center; gap: 0.4rem; margin: 0; font-weight: 600; }
.users__you {
  border-radius: 999px;
  background: color-mix(in srgb, var(--color-sidebar-mark, #e39b2b) 22%, var(--color-surface));
  color: var(--color-text-primary);
  padding: 0.05rem 0.45rem;
  font-size: 0.68rem;
  font-weight: 700;
  letter-spacing: 0.02em;
}
.users__roleline { display: flex; flex-wrap: wrap; gap: 0.3rem; }
.users__pill {
  border-radius: 999px;
  background: var(--color-table-header);
  color: var(--color-text-primary);
  padding: 0.12rem 0.5rem;
  font-size: 0.75rem;
  font-weight: 600;
}
.users__pin {
  border: 1px solid var(--color-border);
  background: var(--color-canvas);
  color: var(--color-text-primary);
  border-radius: 999px;
  padding: 0.22rem 0.65rem;
  font-family: var(--font-mono);
  letter-spacing: 0.12em;
  font-weight: 600;
  cursor: pointer;
}
.users__pin:hover { border-color: var(--color-border-strong); }
.users__loading { display: grid; gap: var(--space-3); padding: var(--space-5); }
.users__loading span {
  display: block;
  height: 3.2rem;
  border-radius: var(--radius-md);
  border: 1px solid var(--color-border);
  background: var(--color-canvas);
}
.users__detail {
  position: sticky;
  top: var(--space-4);
  padding: var(--space-4);
  display: flex;
  flex-direction: column;
  gap: var(--space-4);
}
.users__profile { display: flex; align-items: flex-start; gap: var(--space-3); }
.users__profile-id { flex: 1; min-width: 0; }
.users__profile h3 { margin: 0; font-size: var(--text-lg); }
.users__profile p { margin: 0.15rem 0 0; color: var(--color-text-muted); font-size: var(--text-sm); word-break: break-word; }
.users__section h4 {
  margin: 0;
  font-size: 0.72rem;
  font-weight: 600;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--color-text-muted);
}
.users__meta { display: grid; grid-template-columns: 1fr 1fr; gap: var(--space-3); margin: var(--space-3) 0 0; }
.users__meta dt { color: var(--color-text-faint); font-size: 0.72rem; }
.users__meta dd { margin: 0.15rem 0 0; font-weight: 600; }
.users__store-list { display: grid; gap: 0.35rem; margin-top: var(--space-3); }
.users__store-item {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  padding: 0.45rem 0.65rem;
  font-size: var(--text-sm);
  cursor: pointer;
}
.users__store-item:hover { border-color: var(--color-border-strong); }
.users__store-item.is-changed {
  border-color: var(--color-sidebar-mark, #e39b2b);
  background: color-mix(in srgb, var(--color-sidebar-mark, #e39b2b) 18%, var(--color-surface));
}
.users__roles-head .users__save {
  border: 1px solid var(--color-border);
  background: var(--color-canvas);
  color: var(--color-text-faint);
  border-radius: var(--radius-md);
  min-height: 0;
  padding: 0.28rem 0.75rem;
  font-size: var(--text-sm);
  font-weight: 600;
}
.users__roles-head .users__save.is-dirty {
  border-color: var(--color-sidebar-mark, #e39b2b);
  background: var(--color-sidebar-mark, #e39b2b);
  color: var(--color-brand-800, #12243c);
}
.users__roles-head .users__save.is-dirty:hover:not(:disabled) {
  filter: brightness(1.05);
}
.users__roles-head { margin-bottom: var(--space-2); }
.users__roles-head button {
  border: 0;
  background: transparent;
  color: var(--color-ink-brand, var(--color-brand-600));
  font-weight: 600;
  cursor: pointer;
}
.users__roles-head button:disabled { opacity: 0.5; cursor: default; }
.users__chips { display: flex; flex-direction: column; gap: 0.45rem; }
.users__chip {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  background: var(--color-canvas);
  padding: 0.55rem 0.7rem;
}
.users__chip small { color: var(--color-text-muted); flex: 1; }
.users__chip button { border: 0; background: transparent; color: var(--color-danger, #b42318); cursor: pointer; font-size: 1rem; }
.users__sessions { max-height: 11rem; overflow: auto; }
.users__session {
  display: flex;
  flex-direction: column;
  min-width: 0;
  margin-top: var(--space-2);
  padding-top: var(--space-2);
  border-top: 1px solid var(--color-border);
  font-size: var(--text-sm);
}
.users__session span {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.users__session small { color: var(--color-text-faint); }
.users__actions { display: flex; flex-wrap: wrap; gap: var(--space-2); }
.pin-field { grid-column: 1 / -1; }
.pin-field__row { display: flex; gap: 0.5rem; align-items: center; }
.pin-field__row .field { flex: 1; letter-spacing: 0.18em; font-family: var(--font-mono); }
.pin-field__hint { margin: 0.35rem 0 0; color: var(--color-text-muted); font-size: 0.75rem; }
.pin-field__hint--error, .field--invalid { color: var(--color-danger, #b42318); }
.field--invalid { border-color: var(--color-danger, #fca5a5); }
@media (max-width: 1100px) {
  .users__layout,
  .users__filters,
  .users__stats { grid-template-columns: 1fr; }
  .users__detail { position: static; }
}
</style>
