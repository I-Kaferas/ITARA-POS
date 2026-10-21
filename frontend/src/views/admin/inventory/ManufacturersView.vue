<script setup lang="ts">
import { computed, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import PageFrame from '../../../components/layout/PageFrame.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import Badge from '../../../components/ui/Badge.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import FilterFold from '../../../components/ui/FilterFold.vue'
import { useConfirm } from '../../../composables/useConfirm'
import { useClientPager } from '../../../composables/useClientPager'
import ListPager from '../../../components/ui/ListPager.vue'

type Manufacturer = {
  id: string
  name: string
  description: string
  contactPerson: string
  email: string
  phone: string
  address: string
  city: string
  country: string
  website: string
  active: boolean
}

const manufacturers = ref<Manufacturer[]>([])

const { t } = useI18n()
const { confirm: confirmDialog } = useConfirm()
const query = ref('')
const creating = ref(false)
const editingId = ref<string | null>(null)
const form = ref(blankForm())
const baseline = ref('')

const dirty = computed(() => creating.value && JSON.stringify(form.value) !== baseline.value)

const filtered = computed(() => {
  const q = query.value.trim().toLowerCase()
  if (!q) return manufacturers.value
  return manufacturers.value.filter((item) =>
    [item.name, item.description, item.contactPerson, item.email, item.phone, item.address, item.city, item.country, item.website]
      .join(' ')
      .toLowerCase()
      .includes(q),
  )
})
const { page, lastPage, total, perPage, paged, setPage } = useClientPager(filtered)

function blankForm() {
  return {
    name: '',
    description: '',
    contactPerson: '',
    email: '',
    phone: '',
    address: '',
    city: '',
    country: '',
    website: '',
    active: true,
  }
}

function contactLabel(item: Manufacturer) {
  return item.contactPerson || item.email || item.phone
}

function locationLabel(item: Manufacturer) {
  return [item.city, item.country].filter(Boolean).join(', ') || item.address
}

function snapshotForm() {
  baseline.value = JSON.stringify(form.value)
}

function openCreate() {
  editingId.value = null
  form.value = blankForm()
  snapshotForm()
  creating.value = true
}

function openEdit(item: Manufacturer) {
  editingId.value = item.id
  form.value = {
    name: item.name,
    description: item.description,
    contactPerson: item.contactPerson,
    email: item.email,
    phone: item.phone,
    address: item.address,
    city: item.city,
    country: item.country,
    website: item.website,
    active: item.active,
  }
  snapshotForm()
  creating.value = true
}

function closeCreate() {
  creating.value = false
  editingId.value = null
}

function payloadFromForm(): Omit<Manufacturer, 'id'> {
  return {
    name: form.value.name.trim(),
    description: form.value.description.trim(),
    contactPerson: form.value.contactPerson.trim(),
    email: form.value.email.trim(),
    phone: form.value.phone.trim(),
    address: form.value.address.trim(),
    city: form.value.city.trim(),
    country: form.value.country.trim(),
    website: form.value.website.trim(),
    active: form.value.active,
  }
}

function save() {
  const next = payloadFromForm()
  if (!next.name) return
  if (editingId.value) {
    manufacturers.value = manufacturers.value.map((item) => (
      item.id === editingId.value ? { ...item, ...next } : item
    ))
  } else {
    manufacturers.value.unshift({ id: `${Date.now()}`, ...next })
  }
  closeCreate()
}

async function remove(item: Manufacturer) {
  if (!(await confirmDialog(t('org.confirmDelete'), { danger: true }))) return
  manufacturers.value = manufacturers.value.filter((row) => row.id !== item.id)
}
</script>

<template>
  <PageFrame>
    <template #title>{{ t('nav.inventoryItems.manufacturers') }}</template>
    <template #subtitle>{{ t('orgManufacturers.subtitle') }}</template>

    <div class="manufacturers">
      <div class="manufacturers__toolbar">
        <button type="button" class="btn-primary" @click="openCreate">
          <AppIcon name="plus" :size="16" />
          {{ t('orgManufacturers.add') }}
        </button>
        <FilterFold>
        <label class="manufacturers__search">
          <span class="sr-only">{{ t('orgManufacturers.search') }}</span>
          <input
            v-model="query"
            class="field"
            type="search"
            :placeholder="t('orgManufacturers.searchPlaceholder')"
          />
        </label>
        </FilterFold>
      </div>

      <div class="ui-table-wrap">
        <div class="overflow-x-auto">
          <table class="ui-table manufacturers__table">
            <thead>
              <tr>
                <th>{{ t('orgManufacturers.columns.name') }}</th>
                <th>{{ t('orgManufacturers.columns.contact') }}</th>
                <th>{{ t('orgManufacturers.columns.location') }}</th>
                <th>{{ t('orgManufacturers.columns.status') }}</th>
                <th>{{ t('orgManufacturers.columns.actions') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-if="!filtered.length">
                <td colspan="5" class="manufacturers__empty">{{ t('orgManufacturers.empty') }}</td>
              </tr>
              <tr v-for="item in paged" :key="item.id">
                <td class="manufacturers__name">{{ item.name }}</td>
                <td :class="{ 'manufacturers__muted': !contactLabel(item) }">{{ contactLabel(item) || '—' }}</td>
                <td :class="{ 'manufacturers__muted': !locationLabel(item) }">{{ locationLabel(item) || '—' }}</td>
                <td>
                  <Badge :variant="item.active ? 'success' : 'neutral'" dot>
                    {{ item.active ? t('orgManufacturers.active') : t('orgManufacturers.inactive') }}
                  </Badge>
                </td>
                <td class="manufacturers__actions">
                  <button type="button" class="text-brand-600" @click="openEdit(item)">
                    <AppIcon name="edit" :size="16" /> {{ t('common.edit') }}
                  </button>
                  <button type="button" class="text-red-600" @click="remove(item)">
                    <AppIcon name="trash" :size="16" /> {{ t('common.delete') }}
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
          <ListPager :page="page" :last-page="lastPage" :total="total" :per-page="perPage" @change="setPage" />
        </div>
      </div>
    </div>

    <AppModal
      :open="creating"
      :title="editingId ? t('common.edit') : t('orgManufacturers.add')"
      icon="organization"
      tone="accent"
      size="lg"
      :dirty="dirty"
      @close="closeCreate"
    >
      <form id="manufacturer-form" class="manufacturers-form" @submit.prevent="save">
        <div>
          <FieldLabel icon="organization">{{ t('orgManufacturers.fields.name') }}</FieldLabel>
          <input v-model="form.name" class="field" required maxlength="120" :placeholder="t('orgManufacturers.placeholders.name')" />
        </div>
        <div>
          <FieldLabel icon="note">{{ t('orgManufacturers.fields.description') }}</FieldLabel>
          <textarea v-model="form.description" class="field" rows="3" maxlength="400" :placeholder="t('orgManufacturers.placeholders.description')" />
        </div>
        <div>
          <FieldLabel icon="account">{{ t('orgManufacturers.fields.contactPerson') }}</FieldLabel>
          <input v-model="form.contactPerson" class="field" maxlength="80" />
        </div>
        <div>
          <FieldLabel icon="mail">{{ t('orgManufacturers.fields.email') }}</FieldLabel>
          <input v-model="form.email" class="field" type="email" maxlength="120" :placeholder="t('orgManufacturers.placeholders.email')" />
        </div>
        <div>
          <FieldLabel icon="phone">{{ t('orgManufacturers.fields.phone') }}</FieldLabel>
          <input v-model="form.phone" class="field" type="tel" maxlength="40" :placeholder="t('orgManufacturers.placeholders.phone')" />
        </div>
        <div>
          <FieldLabel icon="building">{{ t('orgManufacturers.fields.address') }}</FieldLabel>
          <input v-model="form.address" class="field" maxlength="160" />
        </div>
        <div>
          <FieldLabel icon="building">{{ t('orgManufacturers.fields.city') }}</FieldLabel>
          <input v-model="form.city" class="field" maxlength="80" />
        </div>
        <div>
          <FieldLabel icon="building">{{ t('orgManufacturers.fields.country') }}</FieldLabel>
          <input v-model="form.country" class="field" maxlength="80" />
        </div>
        <div>
          <FieldLabel icon="globe">{{ t('orgManufacturers.fields.website') }}</FieldLabel>
          <input v-model="form.website" class="field" type="url" maxlength="200" :placeholder="t('orgManufacturers.placeholders.website')" />
        </div>
        <label class="manufacturers-form__check">
          <input v-model="form.active" type="checkbox" />
          {{ t('orgManufacturers.active') }}
        </label>
      </form>
      <template #footer>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="closeCreate"><AppIcon name="close" :size="16" /> {{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" form="manufacturer-form"><AppIcon name="check" :size="16" /> {{ t('common.save') }}</button>
        </div>
      </template>
    </AppModal>
  </PageFrame>
</template>

<style scoped>
.manufacturers {
  display: flex;
  flex-direction: column;
  gap: var(--space-4);
}

.manufacturers__toolbar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-3);
}

.manufacturers__search {
  display: flex;
  flex: 1;
  min-width: 16rem;
}

.manufacturers__search .field {
  width: 100%;
}

.manufacturers__table td {
  height: auto;
  padding-top: var(--space-3);
  padding-bottom: var(--space-3);
}

.manufacturers__name {
  font-weight: 600;
  color: var(--color-text-primary);
}

.manufacturers__actions {
  display: flex;
  justify-content: flex-end;
  gap: var(--space-2);
  white-space: nowrap;
}

.manufacturers__muted,
.manufacturers__empty {
  color: var(--color-text-muted);
}

.manufacturers__empty {
  text-align: center;
  padding-block: var(--space-8);
}

.manufacturers-form {
  display: flex;
  flex-direction: column;
  gap: var(--space-4);
}

.manufacturers-form__check {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  font-size: var(--text-sm);
  font-weight: 600;
  color: var(--color-text-primary);
}
</style>
