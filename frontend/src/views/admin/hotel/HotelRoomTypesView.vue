<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { api, extractApiErrorMessage } from '../../../api/client'
import { useConfirm } from '../../../composables/useConfirm'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import LoadingBlock from '../../../components/ui/LoadingBlock.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import { formatMoney, parseMoneyInput } from '../../../utils/money'
import { getAppCurrency } from '../../../utils/currency'
import HotelChrome from './HotelChrome.vue'

type DeskDoc = Record<string, any>
type SpaceKind = 'guest_room' | 'conference' | 'reception'

type RoomTypeForm = {
  id: string | null
  name: string
  code: string
  space_kind: SpaceKind
  base_price: string
  max_adults: number
  bed_type: string
  bed_count: number
  surface_m2: string
  is_active: boolean
  description: string
  marketing_hook: string
  highlights: string[]
  amenity_ids: string[]
  photo_urls: string[]
}

const { t } = useI18n()
const { confirm: confirmDialog } = useConfirm()
const store = useBackofficeStore()

const docs = ref<DeskDoc[]>([])
const loading = ref(false)
const saving = ref(false)
const error = ref('')
const message = ref('')
const amenityQuery = ref('')
const galleryOpen = ref(false)
const formOpen = ref(false)

const spaceKinds: { id: SpaceKind; titleKey: string; hintKey: string }[] = [
  { id: 'guest_room', titleKey: 'hotel.roomTypes.space.guest', hintKey: 'hotel.roomTypes.space.guestHint' },
  { id: 'conference', titleKey: 'hotel.roomTypes.space.conference', hintKey: 'hotel.roomTypes.space.conferenceHint' },
  { id: 'reception', titleKey: 'hotel.roomTypes.space.reception', hintKey: 'hotel.roomTypes.space.receptionHint' },
]

const bedTypes = ['Single', 'Twin', 'Double', 'Queen', 'King', 'Sofa']

const form = reactive<RoomTypeForm>(emptyForm())

const roomTypes = computed(() =>
  docs.value
    .filter(doc => doc.kind === 'room_type')
    .slice()
    .sort((a, b) => String(a.name ?? '').localeCompare(String(b.name ?? ''), undefined, { sensitivity: 'base' })),
)
const amenities = computed(() => docs.value.filter(doc => doc.kind === 'amenity'))
const filteredAmenities = computed(() => {
  const q = amenityQuery.value.trim().toLowerCase()
  if (!q) return amenities.value
  return amenities.value.filter(item => String(item.name ?? '').toLowerCase().includes(q))
})

const galleryItems = computed(() =>
  store.products
    .flatMap(product => (product.images ?? []).map(image => ({
      product,
      url: image.cdn_url,
      label: product.name,
    })))
    .filter(item => Boolean(item.url)),
)

function slugCode(name: string) {
  return name
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toUpperCase()
    .replace(/[^A-Z0-9]+/g, '_')
    .replace(/^_|_$/g, '')
}

const generatedCode = computed(() => slugCode(form.name) || 'TYPE')

function typeCode(row: DeskDoc) {
  const code = String(row.code ?? '').trim()
  if (code && code !== String(row.id ?? '')) return code
  return slugCode(String(row.name ?? '')) || '—'
}

watch(() => form.name, () => {
  if (!form.id) form.code = generatedCode.value
})

onMounted(async () => {
  await Promise.all([load(), loadGallery()])
})

function emptyForm(): RoomTypeForm {
  return {
    id: null,
    name: '',
    code: 'TYPE',
    space_kind: 'guest_room',
    base_price: '0',
    max_adults: 2,
    bed_type: 'Queen',
    bed_count: 1,
    surface_m2: '',
    is_active: true,
    description: '',
    marketing_hook: '',
    highlights: [''],
    amenity_ids: [],
    photo_urls: [],
  }
}

function resetForm() {
  Object.assign(form, emptyForm())
  error.value = ''
}

function openCreate() {
  resetForm()
  formOpen.value = true
}

function closeForm() {
  galleryOpen.value = false
  formOpen.value = false
  resetForm()
}

function editType(row: DeskDoc) {
  error.value = ''
  message.value = ''
  formOpen.value = true
  Object.assign(form, {
    id: String(row.id),
    name: String(row.name ?? ''),
    code: typeCode(row) === '—' ? slugCode(String(row.name ?? '')) || 'TYPE' : typeCode(row),
    space_kind: (row.space_kind as SpaceKind) || 'guest_room',
    base_price: String(((row.base_price_cents ?? row.rate ?? 0) as number) / 100),
    max_adults: Number(row.max_adults ?? 2),
    bed_type: String(row.bed_type ?? 'Queen'),
    bed_count: Number(row.bed_count ?? 1),
    surface_m2: row.surface_m2 != null ? String(row.surface_m2) : '',
    is_active: row.is_active !== false && row.status !== 'inactive',
    description: String(row.description ?? ''),
    marketing_hook: String(row.marketing_hook ?? ''),
    highlights: Array.isArray(row.highlights) && row.highlights.length ? [...row.highlights] : [''],
    amenity_ids: Array.isArray(row.amenity_ids) ? [...row.amenity_ids] : [],
    photo_urls: Array.isArray(row.photo_urls) ? [...row.photo_urls] : [],
  })
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    docs.value = (await api.get<{ data: { docs: DeskDoc[] } }>('/hospitality')).data.docs
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    loading.value = false
  }
}

async function loadGallery() {
  try {
    await store.loadCompanies()
    const company = store.companies[0]
    if (!company) return
    const catalogs = await store.loadCatalogs(company.id)
    const catalog = catalogs.find(c => c.is_default) ?? catalogs[0]
    if (catalog) await store.loadProducts(catalog.id)
  } catch {
    // gallery optional
  }
}

async function run(action: Record<string, unknown>) {
  docs.value = (await api.post<{ data: { docs: DeskDoc[] } }>('/hospitality/actions', action)).data.docs
}

async function save() {
  saving.value = true
  error.value = ''
  message.value = ''
  try {
    await run({
      action: 'upsert_room_type',
      id: form.id ?? undefined,
      name: form.name,
      code: form.code || generatedCode.value,
      space_kind: form.space_kind,
      base_price_cents: parseMoneyInput(form.base_price),
      currency: getAppCurrency(),
      max_adults: form.max_adults,
      bed_type: form.bed_type,
      bed_count: form.bed_count,
      surface_m2: form.surface_m2 === '' ? null : Number(form.surface_m2),
      is_active: form.is_active,
      description: form.description,
      marketing_hook: form.marketing_hook,
      highlights: form.highlights.map(h => h.trim()).filter(Boolean),
      amenity_ids: form.amenity_ids,
      photo_urls: form.photo_urls,
    })
    message.value = t('hotel.roomTypes.saved')
    closeForm()
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    saving.value = false
  }
}

async function removeType(row: DeskDoc) {
  if (!(await confirmDialog(t('org.confirmDelete')))) return
  error.value = ''
  try {
    await run({ action: 'delete_room_type', id: row.id })
    if (form.id === row.id) closeForm()
    message.value = t('hotel.roomTypes.deleted')
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  }
}

function toggleAmenity(id: string) {
  const idx = form.amenity_ids.indexOf(id)
  if (idx >= 0) form.amenity_ids.splice(idx, 1)
  else form.amenity_ids.push(id)
}

function addHighlight() {
  form.highlights.push('')
}

function removeHighlight(index: number) {
  form.highlights.splice(index, 1)
  if (!form.highlights.length) form.highlights.push('')
}

function togglePhoto(url: string) {
  const idx = form.photo_urls.indexOf(url)
  if (idx >= 0) form.photo_urls.splice(idx, 1)
  else form.photo_urls.push(url)
}

function priceLabel(row: DeskDoc) {
  return formatMoney(Number(row.base_price_cents ?? row.rate ?? 0))
}

function spaceLabel(row: DeskDoc) {
  const kind = (row.space_kind as SpaceKind) || 'guest_room'
  if (kind === 'conference') return t('hotel.roomTypes.space.conference')
  if (kind === 'reception') return t('hotel.roomTypes.space.reception')
  return t('hotel.roomTypes.space.guest')
}
</script>

<template>
  <HotelChrome>
    <div class="rt">
      <div class="rt__toolbar">
        <p>{{ t('hotel.roomTypes.intro') }}</p>
        <button type="button" class="ui-btn ui-btn--primary" @click="openCreate">
          {{ t('hotel.roomTypes.new') }}
        </button>
      </div>

      <p v-if="error && !formOpen" class="rt__alert" role="alert">{{ error }}</p>
      <p v-else-if="message" class="rt__ok">{{ message }}</p>
      <LoadingBlock v-if="loading" variant="table" :label="t('common.loading')" />

      <div v-else class="rt__list">
        <div class="ui-table-wrap">
          <table class="ui-table">
            <thead>
              <tr>
                <th>{{ t('hotel.roomTypes.name') }}</th>
                <th>{{ t('hotel.roomTypes.code') }}</th>
                <th>{{ t('hotel.roomTypes.price') }}</th>
                <th>{{ t('hotel.roomTypes.spaceTitle') }}</th>
                <th>{{ t('hotel.roomTypes.maxAdults') }}</th>
                <th>{{ t('products.status') }}</th>
                <th />
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in roomTypes" :key="row.id">
                <td class="font-semibold">{{ row.name }}</td>
                <td class="font-mono">{{ typeCode(row) }}</td>
                <td>{{ priceLabel(row) }}</td>
                <td>{{ spaceLabel(row) }}</td>
                <td>{{ row.max_adults ?? '—' }}</td>
                <td><StatusBadge :active="row.is_active !== false && row.status !== 'inactive'" /></td>
                <td class="rt__row-actions">
                  <button type="button" class="text-brand-600" @click="editType(row)">{{ t('common.edit') }}</button>
                  <button type="button" class="text-red-600" @click="removeType(row)">{{ t('common.delete') }}</button>
                </td>
              </tr>
            </tbody>
          </table>
          <p v-if="!roomTypes.length" class="rt__muted">{{ t('hotel.roomTypes.empty') }}</p>
        </div>
      </div>
    </div>

    <AppModal
      :open="formOpen"
      :title="form.id ? t('hotel.roomTypes.editTitle') : t('hotel.roomTypes.new')"
      icon="bed"
      size="xl"
      @close="closeForm"
    >
      <form class="rt__form" @submit.prevent="save">
        <p class="rt__intro">{{ t('hotel.roomTypes.intro') }}</p>
        <p v-if="error" class="rt__alert" role="alert">{{ error }}</p>

        <section class="rt__block">
          <h3>{{ t('hotel.roomTypes.spaceTitle') }}</h3>
          <div class="rt__spaces">
            <label
              v-for="kind in spaceKinds"
              :key="kind.id"
              class="rt__space"
              :class="{ 'rt__space--on': form.space_kind === kind.id }"
            >
              <input v-model="form.space_kind" type="radio" :value="kind.id" />
              <strong>{{ t(kind.titleKey) }}</strong>
              <span>{{ t(kind.hintKey) }}</span>
            </label>
          </div>
        </section>

        <section class="rt__block">
          <div class="rt__grid">
            <div class="ui-field">
              <FieldLabel icon="note">{{ t('hotel.roomTypes.name') }}</FieldLabel>
              <input v-model="form.name" class="ui-input" :placeholder="t('hotel.roomTypes.namePh')" required />
            </div>
            <div class="ui-field">
              <FieldLabel icon="layers">{{ t('hotel.roomTypes.code') }}</FieldLabel>
              <input :value="form.code || generatedCode" class="ui-input" readonly />
              <p class="rt__hint">{{ t('hotel.roomTypes.codeHint') }}</p>
            </div>
            <div class="ui-field">
              <FieldLabel icon="coins">{{ t('hotel.roomTypes.price') }}</FieldLabel>
              <div class="rt__money">
                <span>$</span>
                <input v-model="form.base_price" class="ui-input" inputmode="decimal" />
              </div>
            </div>
            <div class="ui-field">
              <FieldLabel icon="customers">{{ t('hotel.roomTypes.maxAdults') }}</FieldLabel>
              <input v-model.number="form.max_adults" class="ui-input" type="number" min="1" max="20" />
            </div>
            <div class="ui-field">
              <FieldLabel icon="bed">{{ t('hotel.roomTypes.bedType') }}</FieldLabel>
              <select v-model="form.bed_type" class="ui-select">
                <option v-for="bed in bedTypes" :key="bed" :value="bed">{{ bed }}</option>
              </select>
            </div>
            <div class="ui-field">
              <FieldLabel icon="bed">{{ t('hotel.roomTypes.bedCount') }}</FieldLabel>
              <input v-model.number="form.bed_count" class="ui-input" type="number" min="1" max="10" />
            </div>
            <div class="ui-field">
              <FieldLabel icon="adjust">{{ t('hotel.roomTypes.surface') }}</FieldLabel>
              <input v-model="form.surface_m2" class="ui-input" :placeholder="t('hotel.roomTypes.surfacePh')" inputmode="decimal" />
            </div>
            <label class="rt__check">
              <input v-model="form.is_active" type="checkbox" />
              <span>{{ t('hotel.roomTypes.active') }}</span>
            </label>
          </div>

          <div class="ui-field">
            <FieldLabel icon="note">{{ t('hotel.roomTypes.description') }}</FieldLabel>
            <textarea v-model="form.description" class="ui-input" rows="3" :placeholder="t('hotel.roomTypes.descriptionPh')"></textarea>
          </div>
          <div class="ui-field">
            <FieldLabel icon="sparkles">{{ t('hotel.roomTypes.hook') }}</FieldLabel>
            <input v-model="form.marketing_hook" class="ui-input" :placeholder="t('hotel.roomTypes.hookPh')" />
          </div>
        </section>

        <section class="rt__block">
          <div class="rt__section-head">
            <div>
              <h3>{{ t('hotel.roomTypes.photos') }}</h3>
              <p>{{ t('hotel.roomTypes.photosHint') }}</p>
            </div>
            <button type="button" class="ui-btn" @click="galleryOpen = true">
              {{ t('hotel.roomTypes.addFromGallery') }}
            </button>
          </div>
          <div v-if="form.photo_urls.length" class="rt__photos">
            <figure v-for="(url, index) in form.photo_urls" :key="url" class="rt__photo">
              <img :src="url" alt="" />
              <span v-if="index === 0" class="rt__cover">{{ t('hotel.roomTypes.cover') }}</span>
              <button type="button" @click="togglePhoto(url)">×</button>
            </figure>
          </div>
          <div v-else class="rt__empty-photos">
            <p>{{ t('hotel.roomTypes.noPhotos') }}</p>
            <small>{{ t('hotel.roomTypes.noPhotosHint') }}</small>
          </div>
        </section>

        <section class="rt__block">
          <h3>{{ t('hotel.roomTypes.highlights') }}</h3>
          <div v-for="(_, index) in form.highlights" :key="index" class="rt__highlight">
            <input
              v-model="form.highlights[index]"
              class="ui-input"
              :placeholder="t('hotel.roomTypes.highlightPh')"
            />
            <button type="button" class="ui-btn" @click="removeHighlight(index)">{{ t('common.delete') }}</button>
          </div>
          <button type="button" class="ui-btn" @click="addHighlight">{{ t('hotel.roomTypes.addHighlight') }}</button>
        </section>

        <section class="rt__block">
          <h3>{{ t('hotel.roomTypes.amenities') }}</h3>
          <input
            v-model="amenityQuery"
            class="ui-input"
            :placeholder="t('hotel.roomTypes.amenitiesSearch')"
          />
          <div class="rt__amenities">
            <label
              v-for="item in filteredAmenities"
              :key="item.id"
              class="rt__amenity"
              :class="{ 'rt__amenity--on': form.amenity_ids.includes(item.id) }"
            >
              <input
                type="checkbox"
                :checked="form.amenity_ids.includes(item.id)"
                @change="toggleAmenity(item.id)"
              />
              {{ item.name }}
            </label>
          </div>
        </section>

        <div class="rt__actions">
          <button type="button" class="ui-btn" @click="closeForm">{{ t('common.cancel') }}</button>
          <button type="submit" class="ui-btn ui-btn--primary" :disabled="saving || !form.name.trim()">
            {{ saving ? t('common.loading') : t('common.save') }}
          </button>
        </div>
      </form>
    </AppModal>

    <AppModal
      :open="galleryOpen"
      :title="t('hotel.roomTypes.addFromGallery')"
      size="xl"
      @close="galleryOpen = false"
    >
      <div v-if="galleryItems.length" class="rt__gallery">
        <button
          v-for="item in galleryItems"
          :key="item.url"
          type="button"
          class="rt__gallery-item"
          :class="{ 'rt__gallery-item--on': form.photo_urls.includes(item.url) }"
          @click="togglePhoto(item.url)"
        >
          <img :src="item.url" :alt="item.label" />
          <span>{{ item.label }}</span>
        </button>
      </div>
      <p v-else class="rt__muted">{{ t('hotel.roomTypes.noPhotosHint') }}</p>
      <div class="rt__actions">
        <button type="button" class="ui-btn ui-btn--primary" @click="galleryOpen = false">{{ t('common.ok') }}</button>
      </div>
    </AppModal>
  </HotelChrome>
</template>

<style scoped>
.rt { margin-top: 1rem; display: flex; flex-direction: column; gap: 1rem; }
.rt__toolbar { display: flex; align-items: flex-start; justify-content: space-between; gap: 1rem; }
.rt__toolbar p, .rt__intro { margin: 0; max-width: 40rem; color: #66727c; font-size: 0.85rem; line-height: 1.45; }
.rt__alert { margin: 0; padding: 0.65rem 0.8rem; border-radius: 0.55rem; background: #fef2f2; color: #b91c1c; }
.rt__ok { margin: 0; padding: 0.65rem 0.8rem; border-radius: 0.55rem; background: #ecfdf5; color: #047857; }
.rt__muted { margin: 0; color: #7b8d9a; font-size: 0.875rem; }
.rt__list { min-height: 0; }
.rt__row-actions { text-align: right; white-space: nowrap; }
.rt__row-actions button + button { margin-left: 0.7rem; }
.font-semibold { font-weight: 600; }
.font-mono { font-family: var(--font-mono); }
.text-brand-600 { color: var(--color-brand-600); }
.text-red-600 { color: #dc2626; }
.rt__form { display: flex; flex-direction: column; }
.rt__block { display: flex; flex-direction: column; gap: 0.75rem; margin-bottom: 1.25rem; }
.rt__block h3 { margin: 0; font-size: 0.95rem; color: #1c2830; }
.rt__section-head { display: flex; justify-content: space-between; gap: 1rem; align-items: flex-start; }
.rt__section-head p { margin: 0.25rem 0 0; color: #7b8d9a; font-size: 0.8rem; }
.rt__spaces { display: grid; grid-template-columns: 1fr; gap: 0.65rem; }
@media (min-width: 720px) {
  .rt__spaces { grid-template-columns: repeat(3, minmax(0, 1fr)); }
}
.rt__space { position: relative; display: flex; flex-direction: column; gap: 0.25rem; padding: 0.8rem; border: 1px solid #d7e2ea; border-radius: 0.75rem; cursor: pointer; }
.rt__space input { position: absolute; opacity: 0; pointer-events: none; }
.rt__space strong { font-size: 0.85rem; color: #1c2830; }
.rt__space span { font-size: 0.75rem; color: #7b8d9a; line-height: 1.35; }
.rt__space--on { border-color: var(--color-brand-500, var(--color-brand-500)); background: #f3f6f8; }
.rt__grid { display: grid; grid-template-columns: 1fr; gap: 0.75rem 1rem; }
@media (min-width: 640px) {
  .rt__grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
}
.rt__money { display: grid; grid-template-columns: auto 1fr; align-items: center; gap: 0.4rem; }
.rt__money span { font-weight: 700; color: #3d5c73; }
.rt__hint { margin: 0.3rem 0 0; font-size: 0.72rem; color: #94a3b8; }
.rt__check { display: flex; align-items: center; gap: 0.45rem; margin-top: 1.55rem; font-size: 0.875rem; color: #1c2830; }
.rt__photos { display: grid; grid-template-columns: repeat(auto-fill, minmax(7.5rem, 1fr)); gap: 0.65rem; }
.rt__photo { position: relative; margin: 0; aspect-ratio: 1; border-radius: 0.65rem; overflow: hidden; border: 1px solid #e4e8ec; }
.rt__photo img { width: 100%; height: 100%; object-fit: cover; display: block; }
.rt__photo button { position: absolute; top: 0.3rem; right: 0.3rem; width: 1.4rem; height: 1.4rem; border: 0; border-radius: 999px; background: rgba(15,23,42,0.7); color: #fff; cursor: pointer; }
.rt__cover { position: absolute; left: 0.3rem; bottom: 0.3rem; padding: 0.1rem 0.35rem; border-radius: 999px; background: rgba(255,255,255,0.92); font-size: 0.65rem; font-weight: 700; }
.rt__empty-photos { padding: 1rem; border: 1px dashed #d7e2ea; border-radius: 0.75rem; background: #f8fafc; }
.rt__empty-photos p { margin: 0; font-weight: 600; color: #1c2830; }
.rt__empty-photos small { color: #7b8d9a; }
.rt__highlight { display: grid; grid-template-columns: 1fr auto; gap: 0.5rem; }
.rt__amenities { display: flex; flex-wrap: wrap; gap: 0.45rem; margin-top: 0.55rem; }
.rt__amenity { display: inline-flex; align-items: center; gap: 0.35rem; padding: 0.35rem 0.6rem; border: 1px solid #d7e2ea; border-radius: 999px; font-size: 0.78rem; cursor: pointer; background: #fff; }
.rt__amenity input { accent-color: var(--color-brand-600); }
.rt__amenity--on { border-color: var(--color-brand-500); background: #f3f6f8; color: #2c4556; }
.rt__actions { display: flex; justify-content: flex-end; gap: 0.55rem; margin-top: 0.5rem; }
.rt__gallery { display: grid; grid-template-columns: repeat(auto-fill, minmax(8rem, 1fr)); gap: 0.65rem; max-height: 24rem; overflow: auto; }
.rt__gallery-item { display: flex; flex-direction: column; gap: 0.35rem; border: 1px solid #e2e8f0; border-radius: 0.65rem; overflow: hidden; background: #fff; padding: 0; text-align: left; cursor: pointer; }
.rt__gallery-item img { aspect-ratio: 1; width: 100%; object-fit: cover; }
.rt__gallery-item span { padding: 0 0.5rem 0.5rem; font-size: 0.75rem; color: #334155; }
.rt__gallery-item--on { border-color: var(--color-brand-500); box-shadow: 0 0 0 1px color-mix(in srgb, var(--color-brand-500) 40%, transparent); }
</style>
