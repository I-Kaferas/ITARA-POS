<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import OrganizationLayout from '../../../components/organization/OrganizationLayout.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
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
const status = ref('all')
const roleId = ref('')
const message = ref('')
const saving = ref(false)

const showUserModal = ref(false)
const showRoleModal = ref(false)
const showPasswordModal = ref(false)
const editingUser = ref<TenantUser | null>(null)
const selectedUser = ref<TenantUser | null>(null)
const sessions = ref<UserSession[]>([])

const userForm = ref({ name: '', email: '', phone: '', pin: '', password: '', is_active: true, role_id: '', store_id: '' })
const showPin = ref(false)
const revealedPins = ref<Record<string, boolean>>({})
const roleForm = ref({ role_id: '', store_id: '' })
const passwordForm = ref('')

const currentUserId = computed(() => auth.user?.id)
const activeCount = computed(() => store.users.filter(user => user.is_active !== false).length)
const inactiveCount = computed(() => store.users.filter(user => user.is_active === false).length)

onMounted(async () => {
  await Promise.all([reload(), store.loadRoles(), context.loadStores()])
})

watch([status, roleId], () => reload())

async function reload() {
  await store.loadUsers({
    search: search.value.trim(),
    status: status.value,
    role_id: roleId.value,
  })
}

function storeName(id?: string | null) {
  if (!id) return t('org.allAccess')
  return context.activeStores.find(storeItem => storeItem.id === id)
    ? context.storeLabel(context.activeStores.find(storeItem => storeItem.id === id)!)
    : id
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
    store_id: context.currentStoreId ?? '',
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
      if (userForm.value.role_id) payload.role_id = userForm.value.role_id
      if (userForm.value.store_id) payload.store_id = userForm.value.store_id
    }
    const saved = await store.saveUser(payload as never, editingUser.value?.id)
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
  sessions.value = await store.loadUserSessions(user.id)
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
        <button class="btn-primary" @click="openCreateUser">+ {{ t('org.addUser') }}</button>
      </div>

      <p v-if="message" class="users__notice">{{ message }}</p>

      <div class="users__stats">
        <div class="users__stat"><span>{{ store.users.length }}</span><small>{{ t('org.tabs.users') }}</small></div>
        <div class="users__stat"><span>{{ activeCount }}</span><small>{{ t('org.activeUsers') }}</small></div>
        <div class="users__stat"><span>{{ inactiveCount }}</span><small>{{ t('org.inactiveUsers') }}</small></div>
      </div>

      <div class="users__filters">
        <input v-model="search" class="field" :placeholder="t('org.searchUsers')" @keyup.enter="reload" />
        <select v-model="status" class="field">
          <option value="all">{{ t('org.allStatuses') }}</option>
          <option value="active">{{ t('org.activeUsers') }}</option>
          <option value="inactive">{{ t('org.inactiveUsers') }}</option>
        </select>
        <select v-model="roleId" class="field">
          <option value="">{{ t('rbac.roles') }}</option>
          <option v-for="role in store.roles" :key="role.id" :value="role.id">{{ role.name }}</option>
        </select>
        <button class="btn-secondary" @click="reload">{{ t('common.search') }}</button>
      </div>

      <div class="users__layout">
        <div class="users__table">
          <table>
            <thead>
              <tr>
                <th>{{ t('org.name') }}</th>
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
                  <p class="users__name">{{ user.name }}</p>
                  <p class="users__email">{{ user.email }}</p>
                </td>
                <td>
                  <button type="button" class="users__pin" @click.stop="revealedPins[user.id] = !revealedPins[user.id]">
                    {{ revealedPins[user.id] ? (user.pin || '—') : maskPin(user.pin) }}
                  </button>
                </td>
                <td><StatusBadge :active="user.is_active !== false" /></td>
                <td>
                  <span v-if="user.roles?.length">{{ user.roles.map(role => role.name).join(', ') }}</span>
                  <span v-else class="muted">{{ t('org.noRole') }}</span>
                </td>
                <td class="muted">{{ user.last_seen_at ? formatDate(user.last_seen_at) : t('org.neverSeen') }}</td>
              </tr>
            </tbody>
          </table>
          <p v-if="!store.users.length" class="users__empty">{{ t('org.empty') }}</p>
        </div>

        <aside v-if="selectedUser" class="users__detail">
          <div class="users__detail-head">
            <div>
              <h3>{{ selectedUser.name }}</h3>
              <p>{{ selectedUser.email }}</p>
            </div>
            <StatusBadge :active="selectedUser.is_active !== false" />
          </div>

          <dl class="users__meta">
            <div><dt>{{ t('common.phone') }}</dt><dd>{{ selectedUser.phone || '—' }}</dd></div>
            <div>
              <dt>{{ t('org.pin') }}</dt>
              <dd>
                <button type="button" class="users__pin" @click="revealedPins[selectedUser.id] = !revealedPins[selectedUser.id]">
                  {{ revealedPins[selectedUser.id] ? (selectedUser.pin || '—') : maskPin(selectedUser.pin) }}
                </button>
              </dd>
            </div>
            <div><dt>{{ t('org.lastSeen') }}</dt><dd>{{ selectedUser.last_seen_at ? formatDate(selectedUser.last_seen_at) : t('org.neverSeen') }}</dd></div>
            <div><dt>{{ t('org.sessionsCount') }}</dt><dd>{{ selectedUser.active_sessions_count ?? sessions.length }}</dd></div>
            <div><dt>{{ t('org.twoFactor') }}</dt><dd>{{ selectedUser.two_factor_enabled ? t('account.twoFactorOn') : t('account.twoFactorOff') }}</dd></div>
          </dl>

          <div class="users__roles">
            <div class="users__roles-head">
              <h4>{{ t('rbac.roles') }}</h4>
              <button type="button" @click="openAssign(selectedUser)">{{ t('org.assignRole') }}</button>
            </div>
            <div v-if="selectedUser.roles?.length" class="users__chips">
              <span v-for="role in selectedUser.roles" :key="role.id" class="users__chip">
                <strong>{{ role.name }}</strong>
                <small>{{ storeName(role.store_id) }}</small>
                <button type="button" @click="unassign(selectedUser, role.id)">×</button>
              </span>
            </div>
            <p v-else class="muted">{{ t('org.noRole') }}</p>
          </div>

          <div class="users__sessions">
            <h4>{{ t('account.sessions') }}</h4>
            <p v-if="!sessions.length" class="muted">{{ t('org.empty') }}</p>
            <div v-for="session in sessions" :key="session.id" class="users__session">
              <span>{{ session.device_name || t('account.unknownDevice') }}</span>
              <small>{{ session.ip_address }} · {{ session.last_used_at ? formatDate(session.last_used_at) : '—' }}</small>
            </div>
          </div>

          <div class="users__actions">
            <button class="btn-secondary" @click="openEditUser(selectedUser)">{{ t('common.edit') }}</button>
            <button class="btn-secondary" @click="showPasswordModal = true; passwordForm = ''">{{ t('org.resetPassword') }}</button>
            <button class="btn-secondary" @click="revokeSessions(selectedUser)">{{ t('org.revokeSessions') }}</button>
            <button class="btn-secondary" @click="toggleActive(selectedUser)">
              {{ selectedUser.is_active === false ? t('org.activate') : t('org.deactivate') }}
            </button>
            <button class="btn-danger" :disabled="selectedUser.id === currentUserId" @click="removeUser(selectedUser)">{{ t('common.delete') }}</button>
          </div>
        </aside>
      </div>
    </div>

    <AppModal :open="showUserModal" :title="editingUser ? t('org.editUser') : t('org.addUser')" size="xl" @close="showUserModal = false">
      <form class="space-y-3" @submit.prevent="saveUser">
        <div><FieldLabel icon="account">{{ t('org.name') }}</FieldLabel><input v-model="userForm.name" required class="field" /></div>
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
            <FieldLabel icon="stores">{{ t('org.roleScope') }}</FieldLabel>
            <select v-model="userForm.store_id" class="field">
              <option value="">{{ t('org.allStores') }}</option>
              <option v-for="item in context.activeStores" :key="item.id" :value="item.id">{{ context.storeLabel(item) }}</option>
            </select>
          </div>
        </template>
        <label class="flex items-center gap-2 text-sm"><span class="field-icon"><AppIcon name="check" :size="14" /></span><input v-model="userForm.is_active" type="checkbox" class="rounded" />{{ t('products.active') }}</label>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showUserModal = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">{{ t('common.save') }}</button>
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
            <option v-for="item in context.activeStores" :key="item.id" :value="item.id">{{ context.storeLabel(item) }}</option>
          </select>
        </div>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showRoleModal = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">{{ t('common.save') }}</button>
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
          <button type="button" class="btn-secondary" @click="showPasswordModal = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>
  </OrganizationLayout>
</template>

<style scoped>
.users { display: flex; flex-direction: column; gap: 1rem; }
.users__head, .users__roles-head, .users__detail-head { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; }
.users__title { margin: 0; font-family: var(--font-display); font-size: 1.15rem; letter-spacing: -0.02em; }
.users__subtitle, .users__email, .muted { margin: 0.15rem 0 0; color: #94a3b8; font-size: 0.8rem; }
.users__notice { margin: 0; border-radius: 0.8rem; background: #e4edf2; color: #1a2833; padding: 0.7rem 0.9rem; font-size: 0.85rem; }
.users__stats { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 0.75rem; }
.users__stat { border-radius: 1rem; background: #fff; border: 1px solid #e7e9f0; padding: 0.9rem 1rem; }
.users__stat span { display: block; font-family: var(--font-display); font-size: 1.35rem; font-weight: 700; }
.users__stat small { color: #64748b; }
.users__filters { display: grid; grid-template-columns: 1.6fr 0.8fr 0.9fr auto; gap: 0.6rem; }
.users__layout { display: grid; grid-template-columns: minmax(0, 1.6fr) minmax(18rem, 0.9fr); gap: 1rem; align-items: start; }
.users__table, .users__detail { background: #fff; border: 1px solid #e7e9f0; border-radius: 1.1rem; overflow: hidden; }
.users__table table { width: 100%; border-collapse: collapse; font-size: 0.85rem; }
.users__table th, .users__table td { padding: 0.85rem 1rem; text-align: left; border-bottom: 1px solid #f1f5f9; }
.users__table th { font-size: 0.7rem; letter-spacing: 0.05em; text-transform: uppercase; color: #94a3b8; }
.users__table tr { cursor: pointer; }
.users__table tr.is-selected { background: #f5f6ff; }
.users__name { margin: 0; font-weight: 600; }
.users__pin {
  border: 0;
  background: #f6f3ee;
  color: #1a2833;
  border-radius: 999px;
  padding: 0.28rem 0.7rem;
  font-family: var(--font-mono);
  letter-spacing: 0.12em;
  font-weight: 650;
  cursor: pointer;
}
.pin-field { grid-column: 1 / -1; }
.pin-field__row { display: flex; gap: 0.5rem; align-items: center; }
.pin-field__row .field { flex: 1; letter-spacing: 0.18em; font-family: var(--font-mono); }
.pin-field__hint { margin: 0.35rem 0 0; color: #64748b; font-size: 0.75rem; }
.pin-field__hint--error, .field--invalid { color: #b91c1c; }
.field--invalid { border-color: #fca5a5; }
.users__empty { padding: 2rem; text-align: center; color: #94a3b8; }
.users__detail { padding: 1rem; display: flex; flex-direction: column; gap: 1rem; }
.users__detail h3, .users__detail h4 { margin: 0; }
.users__detail-head p { margin: 0.2rem 0 0; color: #64748b; font-size: 0.8rem; }
.users__meta { display: grid; grid-template-columns: 1fr 1fr; gap: 0.7rem; margin: 0; }
.users__meta dt { color: #94a3b8; font-size: 0.72rem; }
.users__meta dd { margin: 0.1rem 0 0; font-weight: 600; }
.users__roles-head button { border: 0; background: transparent; color: var(--color-brand-600); font-weight: 600; cursor: pointer; }
.users__chips { display: flex; flex-direction: column; gap: 0.45rem; }
.users__chip { display: flex; align-items: center; gap: 0.5rem; border-radius: 0.8rem; background: #f8fafc; padding: 0.55rem 0.7rem; }
.users__chip small { color: #64748b; flex: 1; }
.users__chip button { border: 0; background: transparent; color: #dc2626; cursor: pointer; }
.users__session { display: flex; flex-direction: column; padding: 0.45rem 0; border-top: 1px solid #f1f5f9; font-size: 0.82rem; }
.users__session small { color: #94a3b8; }
.users__actions { display: flex; flex-wrap: wrap; gap: 0.45rem; }
.btn-danger { color: #fff; background: #dc2626; border: 0; }
@media (max-width: 1100px) {
  .users__layout, .users__filters, .users__stats { grid-template-columns: 1fr; }
}
</style>
