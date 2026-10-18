<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'

const props = defineProps<{
  modelValue: string
}>()

const emit = defineEmits<{
  'update:modelValue': [value: string]
}>()

const mapEl = ref<HTMLElement | null>(null)
const addressInput = ref(props.modelValue)
const resolving = ref(false)
const locating = ref(false)

let map: L.Map | null = null
let marker: L.Marker | null = null
let geocodeTimer: ReturnType<typeof setTimeout> | null = null

const DEFAULT = L.latLng(-3.3822, 29.3644)

function parseLatLng(raw: string): L.LatLng | null {
  const match = raw.match(/(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)/)
  if (!match) return null
  const lat = Number(match[1])
  const lng = Number(match[2])
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null
  return L.latLng(lat, lng)
}

const pinIcon = L.divIcon({
  className: 'delivery-map-pin',
  html: '<span class="delivery-map-pin__dot"></span>',
  iconSize: [28, 28],
  iconAnchor: [14, 28],
})

function setMarker(latlng: L.LatLng) {
  if (!map) return
  if (!marker) {
    marker = L.marker(latlng, { draggable: true, icon: pinIcon }).addTo(map)
    marker.on('dragend', () => {
      const pos = marker?.getLatLng()
      if (pos) void resolveAndCommit(pos)
    })
  } else {
    marker.setLatLng(latlng)
  }
  map.setView(latlng, Math.max(map.getZoom(), 15))
}

async function resolveAndCommit(latlng: L.LatLng) {
  resolving.value = true
  const fallback = `${latlng.lat.toFixed(5)}, ${latlng.lng.toFixed(5)}`
  let address = fallback
  try {
    const url = new URL('https://nominatim.openstreetmap.org/reverse')
    url.searchParams.set('format', 'jsonv2')
    url.searchParams.set('lat', String(latlng.lat))
    url.searchParams.set('lon', String(latlng.lng))
    url.searchParams.set('zoom', '18')
    const res = await fetch(url.toString(), {
      headers: { Accept: 'application/json' },
    })
    if (res.ok) {
      const body = (await res.json()) as { display_name?: string }
      if (body.display_name?.trim()) address = body.display_name.trim()
    }
  } catch {
    /* keep coordinates offline */
  }
  if (address.length > 255) address = address.slice(0, 255)
  addressInput.value = address
  emit('update:modelValue', address)
  resolving.value = false
}

function onMapClick(e: L.LeafletMouseEvent) {
  setMarker(e.latlng)
  if (geocodeTimer) clearTimeout(geocodeTimer)
  geocodeTimer = setTimeout(() => void resolveAndCommit(e.latlng), 250)
}

function commitTyped() {
  const value = addressInput.value.trim()
  if (!value) return
  emit('update:modelValue', value.slice(0, 255))
}

async function useMyLocation() {
  if (!navigator.geolocation) return
  locating.value = true
  navigator.geolocation.getCurrentPosition(
    (pos) => {
      locating.value = false
      const latlng = L.latLng(pos.coords.latitude, pos.coords.longitude)
      setMarker(latlng)
      void resolveAndCommit(latlng)
    },
    () => {
      locating.value = false
    },
    { enableHighAccuracy: true, timeout: 8000 },
  )
}

onMounted(() => {
  if (!mapEl.value) return
  const start = parseLatLng(props.modelValue) ?? DEFAULT
  map = L.map(mapEl.value, { zoomControl: true }).setView(start, 14)
  L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 19,
    attribution: '&copy; OpenStreetMap',
  }).addTo(map)
  map.on('click', onMapClick)
  if (props.modelValue.trim()) {
    setMarker(start)
    addressInput.value = props.modelValue
  }
  requestAnimationFrame(() => map?.invalidateSize())
})

watch(
  () => props.modelValue,
  (value) => {
    if (value.trim() === addressInput.value.trim()) return
    addressInput.value = value
    const parsed = parseLatLng(value)
    if (parsed) setMarker(parsed)
  },
)

onBeforeUnmount(() => {
  if (geocodeTimer) clearTimeout(geocodeTimer)
  map?.remove()
  map = null
  marker = null
})
</script>

<template>
  <div class="delivery-map">
    <div class="delivery-map__head">
      <strong>{{ $t('pos.chooseLocation') }}</strong>
      <button type="button" class="delivery-map__locate" :disabled="locating" @click="useMyLocation">
        {{ locating ? '…' : $t('pos.useMyLocation') }}
      </button>
    </div>
    <p class="delivery-map__hint">{{ $t('pos.chooseLocationMapHint') }}</p>
    <div ref="mapEl" class="delivery-map__canvas" role="application" aria-label="map" />
    <div class="delivery-map__address">
      <input
        v-model="addressInput"
        type="text"
        :placeholder="$t('pos.deliveryAddressPlaceholder')"
        @keydown.enter.prevent="commitTyped"
      />
      <button type="button" @click="commitTyped">OK</button>
    </div>
    <p v-if="modelValue.trim()" class="delivery-map__selected">
      {{ $t('pos.deliveryTo', { address: modelValue }) }}
      <span v-if="resolving">…</span>
    </p>
  </div>
</template>

<style scoped>
.delivery-map {
  border: 1px solid color-mix(in srgb, var(--pos-accent, #0ea5e9) 55%, transparent);
  border-radius: 16px;
  background: var(--pos-card, #111827);
  padding: 12px 14px 14px;
  box-shadow: 0 8px 24px rgb(0 0 0 / 0.28);
}

.delivery-map__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}

.delivery-map__head strong {
  font-size: 15px;
  font-weight: 700;
}

.delivery-map__locate {
  border: 0;
  background: transparent;
  color: var(--pos-accent, #0ea5e9);
  font-weight: 600;
  font-size: 13px;
  cursor: pointer;
}

.delivery-map__hint {
  margin: 4px 0 10px;
  font-size: 12.5px;
  opacity: 0.72;
}

.delivery-map__canvas {
  height: 220px;
  border-radius: 12px;
  overflow: hidden;
  z-index: 0;
}

.delivery-map__address {
  display: flex;
  gap: 8px;
  margin-top: 10px;
}

.delivery-map__address input {
  flex: 1;
  min-width: 0;
  border-radius: 10px;
  border: 1px solid rgb(255 255 255 / 0.12);
  background: rgb(0 0 0 / 0.25);
  color: inherit;
  padding: 9px 12px;
  font-size: 13px;
}

.delivery-map__address button {
  border: 0;
  border-radius: 10px;
  padding: 0 14px;
  font-weight: 700;
  background: var(--pos-accent, #0ea5e9);
  color: #0b1220;
  cursor: pointer;
}

.delivery-map__selected {
  margin: 8px 0 0;
  font-size: 12.5px;
  font-weight: 600;
  color: var(--pos-accent, #0ea5e9);
}

:deep(.delivery-map-pin) {
  background: transparent;
  border: 0;
}

:deep(.delivery-map-pin__dot) {
  display: block;
  width: 22px;
  height: 22px;
  margin: 3px auto 0;
  border-radius: 50% 50% 50% 0;
  transform: rotate(-45deg);
  background: #e11d48;
  box-shadow: 0 2px 8px rgb(0 0 0 / 0.45);
}
</style>
