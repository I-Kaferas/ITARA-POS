<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import OrganizationLayout from '../../../components/organization/OrganizationLayout.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { Permission, Role } from '../../../types'

type CrudAction = 'create' | 'read' | 'update' | 'delete'

interface ExtraAction {
  slug: string
  name: string
}

interface CrudResource {
  key: string
  group: string
  label: string
  actions: Partial<Record<CrudAction | 'manage', string>>
  extras: ExtraAction[]
}

const CRUD: CrudAction[] = ['create', 'read', 'update', 'delete']
const ACTION_SUFFIXES = [
  '.discount.apply',
  '.movement.record',
  '.session.open',
  '.session.close',
  '.view',
  '.create',
  '.update',
  '.delete',
  '.manage',
  '.void',
  '.refund',
  '.return',
  '.adjust',
  '.transfer',
  '.receive',
  '.export',
  '.open',
  '.close',
]

const { t, te } = useI18n()
const store = useBackofficeStore()

const selectedRoleId = ref<string | null>(null)
const selectedSlugs = ref<string[]>([])
const search = ref('')
const saving = ref(false)
const dirty = ref(false)

const selectedRole = computed(() =>
  store.roles.find(role => role.id === selectedRoleId.value) ?? null,
)

const resources = computed(() => buildResources(store.permissions))

const filteredGroups = computed(() => {
  const q = search.value.trim().toLowerCase()
  const groups = new Map<string, CrudResource[]>()

  for (const resource of resources.value) {
    if (q) {
      const extra = resource.extras.map(item => `${item.name} ${item.slug}`).join(' ')
      const haystack = `${resource.label} ${resource.key} ${resource.group} ${extra}`.toLowerCase()
      if (!haystack.includes(q)) continue
    }
    const list = groups.get(resource.group) ?? []
    list.push(resource)
    groups.set(resource.group, list)
  }

  return [...groups.entries()]
})

onMounted(async () => {
  await Promise.all([store.loadRoles(), store.loadPermissions()])
  const first = store.roles.find(role => !role.is_system) ?? store.roles[0]
  if (first) selectRole(first)
})

watch(() => store.roles, (roles) => {
  if (selectedRoleId.value && !roles.some(role => role.id === selectedRoleId.value)) {
    const next = roles.find(role => !role.is_system) ?? roles[0]
    if (next) selectRole(next)
  }
})

function selectRole(role: Role) {
  selectedRoleId.value = role.id
  selectedSlugs.value = role.permissions?.map(permission => permission.slug) ?? []
  dirty.value = false
}

function groupLabel(group: string) {
  const key = `rbac.groups.${group}`
  return te(key) ? t(key) : humanize(group)
}

function isChecked(resource: CrudResource, action: CrudAction) {
  const slug = resource.actions[action]
  return !!slug && selectedSlugs.value.includes(slug)
}

function isLocked() {
  return !selectedRole.value
}

function isExtraChecked(slug: string) {
  return selectedSlugs.value.includes(slug)
}

function toggleAction(resource: CrudResource, action: CrudAction) {
  if (isLocked() || !resource.actions[action]) return
  const slug = resource.actions[action]
  if (!slug) return
  const next = !selectedSlugs.value.includes(slug)
  let slugs = withoutManage([...selectedSlugs.value], resource)
  slugs = next ? addSlug(slugs, slug) : slugs.filter(item => item !== slug)
  selectedSlugs.value = slugs
  dirty.value = true
}

function toggleExtra(slug: string) {
  if (isLocked()) return
  const next = !selectedSlugs.value.includes(slug)
  selectedSlugs.value = next
    ? addSlug(selectedSlugs.value, slug)
    : selectedSlugs.value.filter(item => item !== slug)
  dirty.value = true
}

function toggleResource(resource: CrudResource, checked: boolean) {
  if (checked) selectAllModule([resource])
  else clearAllModule([resource])
}

function toggleGroup(items: CrudResource[], checked: boolean) {
  if (checked) selectAllModule(items)
  else clearAllModule(items)
}

function selectAllModule(items: CrudResource[]) {
  if (isLocked()) return
  let slugs = [...selectedSlugs.value]
  for (const resource of items) {
    slugs = explodeManage(slugs, resource)
    for (const slug of selectableSlugs(resource)) slugs = addSlug(slugs, slug)
  }
  selectedSlugs.value = [...new Set(slugs)]
  dirty.value = true
}

function clearAllModule(items: CrudResource[]) {
  if (isLocked()) return
  const remove = new Set<string>()
  for (const resource of items) {
    for (const slug of availableSlugs(resource)) remove.add(slug)
    if (resource.actions.manage) remove.add(resource.actions.manage)
  }
  selectedSlugs.value = selectedSlugs.value.filter(slug => !remove.has(slug))
  dirty.value = true
}

function hasAnySelected(items: CrudResource[]) {
  return items.some(resource => isResourceChecked(resource) || isResourceIndeterminate(resource))
}

function isResourceChecked(resource: CrudResource) {
  const slugs = availableSlugs(resource)
  return slugs.length > 0 && slugs.every(slug => impliesSlug(resource, slug))
}

function isResourceIndeterminate(resource: CrudResource) {
  const slugs = availableSlugs(resource)
  const count = slugs.filter(slug => impliesSlug(resource, slug)).length
  return count > 0 && count < slugs.length
}

function isGroupChecked(items: CrudResource[]) {
  return items.length > 0 && items.every(resource => isResourceChecked(resource))
}

function isGroupIndeterminate(items: CrudResource[]) {
  const any = items.some(resource => isResourceChecked(resource) || isResourceIndeterminate(resource))
  return any && !isGroupChecked(items)
}

async function save() {
  const role = selectedRole.value
  if (!role || !dirty.value) return
  saving.value = true
  try {
    await store.saveRole(
      { name: role.name, slug: role.slug, permissions: selectedSlugs.value },
      role.id,
    )
    await store.loadRoles()
    const refreshed = store.roles.find(item => item.id === role.id)
    if (refreshed) selectRole(refreshed)
  } finally {
    saving.value = false
  }
}

function withoutManage(slugs: string[], resource: CrudResource) {
  const manage = resource.actions.manage
  if (!manage) return slugs
  return slugs.filter(slug => slug !== manage)
}

function explodeManage(slugs: string[], resource: CrudResource) {
  const manage = resource.actions.manage
  if (!manage || !slugs.includes(manage)) return slugs
  const next = slugs.filter(slug => slug !== manage)
  for (const action of ['create', 'update', 'delete'] as const) {
    const slug = resource.actions[action]
    if (slug) next.push(slug)
  }
  return [...new Set(next)]
}

function selectableSlugs(resource: CrudResource) {
  const slugs = availableSlugs(resource)
  const manage = resource.actions.manage
  if (manage && !resource.actions.create && !resource.actions.update && !resource.actions.delete) {
    return addSlug(slugs, manage)
  }
  return slugs
}

function availableSlugs(resource: CrudResource) {
  return [
    ...CRUD.map(action => resource.actions[action]).filter((slug): slug is string => !!slug),
    ...resource.extras.map(extra => extra.slug),
  ]
}

function impliesSlug(_resource: CrudResource, slug: string) {
  return selectedSlugs.value.includes(slug)
}

function addSlug(slugs: string[], slug: string) {
  return slugs.includes(slug) ? slugs : [...slugs, slug]
}

function buildResources(permissions: Permission[]): CrudResource[] {
  const map = new Map<string, CrudResource>()

  for (const permission of permissions) {
    const parsed = parseSlug(permission.slug)
    if (!parsed) continue
    const key = parsed.resource
    const current = map.get(key) ?? {
      key,
      group: permission.group,
      label: resourceLabel(key),
      actions: {},
      extras: [],
    }

    if (parsed.kind === 'read') current.actions.read = permission.slug
    else if (parsed.kind === 'create') current.actions.create = permission.slug
    else if (parsed.kind === 'update') current.actions.update = permission.slug
    else if (parsed.kind === 'delete') current.actions.delete = permission.slug
    else if (parsed.kind === 'manage') current.actions.manage = permission.slug
    else current.extras.push({ slug: permission.slug, name: actionLabel(parsed.kind) })

    map.set(key, current)
  }

  return [...map.values()].sort((a, b) => a.group.localeCompare(b.group) || a.label.localeCompare(b.label))
}

function parseSlug(slug: string): { resource: string; kind: CrudAction | 'manage' | string } | null {
  for (const suffix of ACTION_SUFFIXES) {
    if (!slug.endsWith(suffix)) continue
    const resource = slug.slice(0, -suffix.length)
    if (!resource) return null
    const kind = suffix.slice(1)
    if (kind === 'view') return { resource, kind: 'read' }
    return { resource, kind }
  }
  const parts = slug.split('.')
  if (parts.length < 2) return null
  return { resource: parts.slice(0, -1).join('.'), kind: parts.at(-1) ?? slug }
}

function actionLabel(kind: string) {
  const token = kind.split('.').at(-1) ?? kind
  const key = `rbac.extra.${token}`
  return te(key) ? t(key) : humanize(token)
}

function resourceLabel(key: string) {
  const token = key.split('.').at(-1) ?? key
  const i18nKey = `rbac.resources.${token}`
  return te(i18nKey) ? t(i18nKey) : humanize(token)
}

function humanize(value: string) {
  return value
    .replace(/[._-]+/g, ' ')
    .replace(/\b\w/g, letter => letter.toUpperCase())
}
</script>

<template>
  <OrganizationLayout>
    <div class="grid gap-4 lg:grid-cols-[240px_1fr]">
      <aside class="rounded-xl bg-white p-3 shadow-sm ring-1 ring-slate-200">
        <p class="mb-2 px-1 text-xs font-semibold uppercase tracking-wide text-slate-500">
          {{ t('rbac.roles') }}
        </p>
        <div class="space-y-1">
          <button
            v-for="role in store.roles"
            :key="role.id"
            type="button"
            class="flex w-full items-center justify-between rounded-lg px-3 py-2 text-left text-sm transition"
            :class="selectedRoleId === role.id ? 'bg-brand-50 text-brand-700 font-medium' : 'hover:bg-slate-50 text-slate-700'"
            @click="selectRole(role)"
          >
            <span class="truncate">{{ role.name }}</span>
            <span class="ml-2 shrink-0 text-xs text-slate-400">{{ role.permissions?.length ?? 0 }}</span>
          </button>
        </div>
      </aside>

      <section class="space-y-4">
        <div class="flex flex-wrap items-center justify-between gap-3 rounded-xl bg-white px-4 py-3 shadow-sm ring-1 ring-slate-200">
          <div>
            <h2 class="text-sm font-semibold text-slate-900">
              {{ selectedRole ? selectedRole.name : t('rbac.permissions') }}
            </h2>
            <p class="text-xs text-slate-500">
              {{ selectedRole?.is_system ? t('rbac.systemRolePermissions') : t('rbac.assignPermissionsHint') }}
            </p>
          </div>
          <div class="flex items-center gap-2">
            <input
              v-model="search"
              type="search"
              class="field w-56"
              :placeholder="t('rbac.searchPermissions')"
            />
            <button
              type="button"
              class="btn-primary"
              :disabled="!dirty || saving || !selectedRole"
              @click="save"
            >
              {{ t('common.save') }}
            </button>
          </div>
        </div>

        <div v-if="!selectedRole" class="rounded-xl bg-white p-8 text-center text-sm text-slate-500 shadow-sm ring-1 ring-slate-200">
          {{ t('org.selectRole') }}
        </div>

        <div v-else class="space-y-4">
          <div
            v-for="[group, items] in filteredGroups"
            :key="group"
            class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200"
          >
            <div class="flex flex-wrap items-center gap-2 border-b border-slate-100 bg-slate-50 px-4 py-2.5">
              <input
                type="checkbox"
                class="rounded border-slate-300"
                :checked="isGroupChecked(items)"
                :indeterminate="isGroupIndeterminate(items)"
                @click.prevent="toggleGroup(items, !isGroupChecked(items))"
              />
              <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">{{ groupLabel(group) }}</p>
              <span class="text-xs text-slate-400">({{ items.length }})</span>
              <div class="ml-auto flex items-center gap-2">
                <button
                  type="button"
                  class="btn-module"
                  :disabled="isGroupChecked(items)"
                  @click="toggleGroup(items, true)"
                >
                  {{ t('rbac.selectAllModule') }}
                </button>
                <button
                  type="button"
                  class="btn-module"
                  :disabled="!hasAnySelected(items)"
                  @click="toggleGroup(items, false)"
                >
                  {{ t('rbac.clearAllModule') }}
                </button>
              </div>
            </div>

            <div class="overflow-x-auto">
              <table class="crud-table">
                <thead>
                  <tr>
                    <th class="crud-table__module">{{ t('rbac.module') }}</th>
                    <th>{{ t('rbac.create') }}</th>
                    <th>{{ t('rbac.read') }}</th>
                    <th>{{ t('rbac.update') }}</th>
                    <th>{{ t('rbac.delete') }}</th>
                    <th class="crud-table__actions">{{ t('rbac.actions') }}</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="resource in items" :key="resource.key">
                    <td>
                      <div class="crud-module">
                        <input
                          type="checkbox"
                          class="rounded border-slate-300"
                          :checked="isResourceChecked(resource)"
                          :indeterminate="isResourceIndeterminate(resource)"
                          @click.prevent="toggleResource(resource, !isResourceChecked(resource))"
                        />
                        <span>{{ resource.label }}</span>
                        <button
                          type="button"
                          class="btn-module"
                          @click="toggleResource(resource, !isResourceChecked(resource))"
                        >
                          {{ isResourceChecked(resource) ? t('rbac.clearAllModule') : t('rbac.selectAllModule') }}
                        </button>
                      </div>
                    </td>
                    <td v-for="action in CRUD" :key="action" class="crud-cell">
                      <input
                        v-if="resource.actions[action]"
                        type="checkbox"
                        class="rounded border-slate-300"
                        :checked="isChecked(resource, action)"
                        :aria-label="`${resource.label} ${t(`rbac.${action}`)}`"
                        @click.prevent="toggleAction(resource, action)"
                      />
                      <span v-else class="crud-empty">—</span>
                    </td>
                    <td>
                      <div v-if="resource.extras.length" class="crud-extras">
                        <label v-for="extra in resource.extras" :key="extra.slug" class="crud-extra">
                          <input
                            type="checkbox"
                            class="rounded border-slate-300"
                            :checked="isExtraChecked(extra.slug)"
                            @click.prevent="toggleExtra(extra.slug)"
                          />
                          <span>{{ extra.name }}</span>
                        </label>
                      </div>
                      <span v-else class="crud-empty">—</span>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <div
            v-if="filteredGroups.length === 0"
            class="rounded-xl bg-white p-8 text-center text-sm text-slate-500 shadow-sm ring-1 ring-slate-200"
          >
            {{ t('common.noResults') }}
          </div>
        </div>
      </section>
    </div>
  </OrganizationLayout>
</template>

<style scoped>



.btn-module {
  border-radius: 999px;
  border: 1px solid #cbd5e1;
  background: white;
  padding: 0.2rem 0.65rem;
  font-size: 0.6875rem;
  font-weight: 600;
  color: #334155;
  white-space: nowrap;
}
.btn-module:hover:not(:disabled) {
  border-color: var(--color-brand-600);
  color: var(--color-brand-600);
}
.btn-module:disabled {
  opacity: 0.45;
  cursor: not-allowed;
}
.bg-brand-50 { background-color: color-mix(in srgb, var(--color-brand-600) 12%, white); }
.text-brand-700 { color: color-mix(in srgb, var(--color-brand-600) 85%, black); }

.crud-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.875rem;
}
.crud-table th {
  padding: 0.7rem 0.75rem;
  text-align: center;
  font-size: 0.6875rem;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: #64748b;
  border-bottom: 1px solid #f1f5f9;
}
.crud-table__module,
.crud-table td:first-child {
  text-align: left;
  width: 28%;
}
.crud-table__actions {
  text-align: left;
  width: 28%;
}
.crud-table td {
  padding: 0.7rem 0.75rem;
  border-top: 1px solid #f8fafc;
  vertical-align: middle;
}
.crud-cell {
  text-align: center;
  width: 4.5rem;
}
.crud-module {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  font-weight: 600;
  color: #1c2830;
}
.crud-extras {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem 0.75rem;
}
.crud-extra {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  font-size: 0.75rem;
  color: #475569;
}
.crud-empty {
  color: #cbd5e1;
}
</style>
