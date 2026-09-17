<script setup lang="ts">
import { computed, nextTick, onMounted, onBeforeUnmount, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRoute } from 'vue-router'
import { extractApiErrorMessage } from '../../api/client'
import { setAppLocale } from '../../i18n'
import type { AppLocale } from '../../i18n/locales'

type StayHotel = {
  brand_name?: string
  logo_url?: string | null
  primary_color?: string
}

type StaySign = {
  id: string
  guest_name: string
  room_number?: string
  stay_code?: string
  type_name?: string
  arrive_on?: string
  depart_on?: string
  checked_in_at?: string | null
  adults?: number
  children?: number
  nights?: number
  purpose?: string
  amount_due_cents?: number
  type_currency?: string
  guest_signed_at?: string | null
  has_signature?: boolean
  hotel?: StayHotel
}

const { t, locale } = useI18n()
const route = useRoute()
const token = computed(() => String(route.params.token || ''))

const stay = ref<StaySign | null>(null)
const loading = ref(true)
const saving = ref(false)
const error = ref('')
const done = ref(false)
const drawing = ref(false)

const canvasRef = ref<HTMLCanvasElement | null>(null)
let ctx: CanvasRenderingContext2D | null = null
let painting = false

const API_BASE = import.meta.env.VITE_API_BASE_URL ?? '/api/v1'

const brandName = computed(() => stay.value?.hotel?.brand_name || 'Hotel')
const logoUrl = computed(() => stay.value?.hotel?.logo_url || null)
const brandColor = computed(() => stay.value?.hotel?.primary_color || '#6D28D9')

const roomLine = computed(() => {
  if (!stay.value) return '—'
  const parts = [
    stay.value.room_number || null,
    stay.value.type_name || null,
  ].filter(Boolean)
  return parts.join(' · ') || '—'
})

const nightsGuests = computed(() => {
  if (!stay.value) return '—'
  let nights = Number(stay.value.nights ?? 0)
  if (!nights && stay.value.arrive_on && stay.value.depart_on) {
    const a = new Date(`${String(stay.value.arrive_on).slice(0, 10)}T00:00:00`)
    const b = new Date(`${String(stay.value.depart_on).slice(0, 10)}T00:00:00`)
    nights = Math.max(0, Math.round((b.getTime() - a.getTime()) / 86400000))
  }
  const adults = Number(stay.value.adults ?? 1)
  const children = Number(stay.value.children ?? 0)
  const nightPart = t('hotel.stays.sign.nightsCount', { count: nights })
  const guestPart = children > 0
    ? t('hotel.stays.sign.guestsWithChildren', { adults, children })
    : t('hotel.stays.sign.adultsCount', { count: adults })
  return `${nightPart} · ${guestPart}`
})

const pageStyle = computed(() => ({
  '--sign-brand': brandColor.value,
  '--sign-brand-soft': hexToRgba(brandColor.value, 0.12),
}))

function hexToRgba(hex: string, alpha: number) {
  const raw = hex.replace('#', '')
  if (raw.length !== 6) return `rgba(109, 40, 217, ${alpha})`
  const r = Number.parseInt(raw.slice(0, 2), 16)
  const g = Number.parseInt(raw.slice(2, 4), 16)
  const b = Number.parseInt(raw.slice(4, 6), 16)
  return `rgba(${r}, ${g}, ${b}, ${alpha})`
}

function applyLangFromQuery() {
  const raw = String(route.query.lang || '').toLowerCase().slice(0, 2)
  if (raw === 'en' || raw === 'fr' || raw === 'sw') {
    void setAppLocale(raw as AppLocale)
  }
}

function formatDateTime(value?: string | null, withTime = true) {
  if (!value) return '—'
  const iso = String(value)
  const hasTime = iso.includes('T') || iso.includes(' ')
  const d = new Date(hasTime ? iso : `${iso.slice(0, 10)}T${withTime ? '12:00:00' : '00:00:00'}`)
  if (Number.isNaN(d.getTime())) return iso.slice(0, 10)
  const loc = String(locale.value || 'fr')
  if (withTime && hasTime) {
    return d.toLocaleString(loc, {
      year: 'numeric',
      month: 'numeric',
      day: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
      second: '2-digit',
    })
  }
  return d.toLocaleString(loc, {
    year: 'numeric',
    month: 'numeric',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
    second: '2-digit',
  })
}

onMounted(async () => {
  applyLangFromQuery()
  await load()
  await nextTick()
  setupCanvas()
  window.addEventListener('resize', setupCanvas)
})

onBeforeUnmount(() => {
  window.removeEventListener('resize', setupCanvas)
})

watch(done, async (isDone) => {
  if (!isDone) {
    await nextTick()
    setupCanvas()
  }
})

async function load() {
  loading.value = true
  error.value = ''
  try {
    const res = await fetch(`${API_BASE}/public/stay-sign/${encodeURIComponent(token.value)}`, {
      headers: {
        Accept: 'application/json',
        'Accept-Language': String(locale.value || localStorage.getItem('pos_locale') || 'fr'),
      },
    })
    const payload = await res.json().catch(() => null)
    if (!res.ok) throw new Error(payload?.message || payload?.errors?.token?.[0] || `HTTP ${res.status}`)
    stay.value = payload.data as StaySign
    done.value = Boolean(stay.value.has_signature)
  } catch (err) {
    error.value = extractApiErrorMessage(err, t('hotel.stays.sign.invalidLink'))
  } finally {
    loading.value = false
  }
}

function setupCanvas() {
  const canvas = canvasRef.value
  if (!canvas) return
  const ratio = window.devicePixelRatio || 1
  const width = canvas.clientWidth || 320
  const height = 200
  canvas.width = Math.floor(width * ratio)
  canvas.height = Math.floor(height * ratio)
  ctx = canvas.getContext('2d')
  if (!ctx) return
  ctx.setTransform(ratio, 0, 0, ratio, 0, 0)
  ctx.lineWidth = 2.4
  ctx.lineCap = 'round'
  ctx.lineJoin = 'round'
  ctx.strokeStyle = '#111827'
  ctx.fillStyle = '#ffffff'
  ctx.fillRect(0, 0, width, height)
  drawing.value = false
}

function pointerPos(event: PointerEvent) {
  const canvas = canvasRef.value!
  const rect = canvas.getBoundingClientRect()
  return { x: event.clientX - rect.left, y: event.clientY - rect.top }
}

function startDraw(event: PointerEvent) {
  if (done.value || !ctx) return
  painting = true
  drawing.value = true
  const p = pointerPos(event)
  ctx.beginPath()
  ctx.moveTo(p.x, p.y)
  canvasRef.value?.setPointerCapture(event.pointerId)
}

function moveDraw(event: PointerEvent) {
  if (!painting || !ctx) return
  const p = pointerPos(event)
  ctx.lineTo(p.x, p.y)
  ctx.stroke()
}

function endDraw(event: PointerEvent) {
  if (!painting) return
  painting = false
  canvasRef.value?.releasePointerCapture(event.pointerId)
}

function clearCanvas() {
  setupCanvas()
}

async function submit() {
  if (!canvasRef.value || !drawing.value) {
    error.value = t('hotel.stays.sign.drawFirst')
    return
  }
  saving.value = true
  error.value = ''
  try {
    const dataUrl = canvasRef.value.toDataURL('image/png')
    const res = await fetch(`${API_BASE}/public/stay-sign/${encodeURIComponent(token.value)}`, {
      method: 'POST',
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
        'Accept-Language': String(locale.value || 'fr'),
      },
      body: JSON.stringify({ guest_signature_data: dataUrl }),
    })
    const payload = await res.json().catch(() => null)
    if (!res.ok) throw new Error(payload?.message || payload?.errors?.guest_signature_data?.[0] || `HTTP ${res.status}`)
    stay.value = { ...stay.value, ...(payload.data as StaySign) }
    done.value = true
    try {
      const channel = new BroadcastChannel('itara-stay-sign')
      channel.postMessage({
        type: 'stay.signed',
        id: stay.value?.id,
        guest_signed_at: stay.value?.guest_signed_at,
      })
      channel.close()
    } catch {
      // Admin page will still pick this up via polling / realtime.
    }
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <div class="sign-page" :style="pageStyle">
    <div class="sign-page__shell">
      <header class="sign-page__brand">
        <div class="sign-page__logo">
          <img v-if="logoUrl" :src="logoUrl" :alt="brandName">
          <span v-else class="sign-page__logo-fallback">{{ brandName.slice(0, 2).toUpperCase() }}</span>
        </div>
        <h1>{{ brandName }}</h1>
        <p>{{ t('hotel.stays.sign.pageTitle') }}</p>
      </header>

      <p v-if="loading" class="sign-page__state">{{ t('common.loading') }}</p>
      <p v-else-if="error && !stay" class="sign-page__state sign-page__state--error">{{ error }}</p>

      <template v-else-if="stay">
        <section class="sign-card">
          <h2>{{ t('hotel.stays.sign.stayDetails') }}</h2>
          <dl class="sign-card__rows">
            <div>
              <dt>{{ t('hotel.stays.sign.guest') }}</dt>
              <dd>{{ stay.guest_name }}</dd>
            </div>
            <div>
              <dt>{{ t('hotel.stays.sign.stayCode') }}</dt>
              <dd>{{ stay.stay_code || '—' }}</dd>
            </div>
            <div>
              <dt>{{ t('hotel.rooms.room') }}</dt>
              <dd>{{ roomLine }}</dd>
            </div>
            <div>
              <dt>{{ t('hotel.stays.sign.checkIn') }}</dt>
              <dd>{{ formatDateTime(stay.checked_in_at || stay.arrive_on) }}</dd>
            </div>
            <div>
              <dt>{{ t('hotel.stays.sign.expectedOut') }}</dt>
              <dd>{{ formatDateTime(stay.depart_on) }}</dd>
            </div>
            <div>
              <dt>{{ t('hotel.stays.sign.nightsGuests') }}</dt>
              <dd>{{ nightsGuests }}</dd>
            </div>
          </dl>
        </section>

        <section v-if="!done" class="sign-card sign-card--pad">
          <div class="sign-card__pad-head">
            <h2>{{ t('hotel.stays.sign.yourSignature') }}</h2>
            <button type="button" class="sign-card__clear" @click="clearCanvas">
              {{ t('hotel.stays.sign.clear') }}
            </button>
          </div>
          <canvas
            ref="canvasRef"
            class="sign-card__canvas"
            @pointerdown="startDraw"
            @pointermove="moveDraw"
            @pointerup="endDraw"
            @pointercancel="endDraw"
          />
          <p class="sign-card__hint">{{ t('hotel.stays.sign.padHint') }}</p>
          <p v-if="error" class="sign-page__state sign-page__state--error">{{ error }}</p>
          <button
            type="button"
            class="sign-card__confirm"
            :disabled="saving || !drawing"
            @click="submit"
          >
            {{ t('hotel.stays.sign.confirm') }}
          </button>
        </section>

        <section v-else class="sign-card sign-card--done">
          <h2>{{ t('hotel.stays.sign.doneTitle') }}</h2>
          <p>{{ t('hotel.stays.sign.doneHint') }}</p>
        </section>
      </template>
    </div>
  </div>
</template>

<style scoped>
.sign-page {
  --sign-brand: #6d28d9;
  --sign-brand-soft: rgba(109, 40, 217, 0.12);
  min-height: 100dvh;
  padding: 1.25rem 1rem 2rem;
  background:
    radial-gradient(120% 70% at 50% -10%, var(--sign-brand-soft), transparent 55%),
    linear-gradient(180deg, #f7f5fb 0%, #f3f4f6 42%, #eef0f4 100%);
  color: #111827;
  font-family: "Segoe UI", "Helvetica Neue", Arial, sans-serif;
}

.sign-page__shell {
  width: min(28rem, 100%);
  margin: 0 auto;
  display: flex;
  flex-direction: column;
  gap: 0.9rem;
}

.sign-page__brand {
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  gap: 0.45rem;
  padding: 0.35rem 0 0.15rem;
}

.sign-page__logo {
  width: 4.25rem;
  height: 4.25rem;
  border-radius: 1rem;
  overflow: hidden;
  background: #fff;
  border: 1px solid #e5e7eb;
  box-shadow: 0 8px 24px rgba(17, 24, 39, 0.08);
  display: grid;
  place-items: center;
}

.sign-page__logo img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.sign-page__logo-fallback {
  font-size: 1.15rem;
  font-weight: 800;
  color: var(--sign-brand);
  letter-spacing: 0.04em;
}

.sign-page__brand h1 {
  margin: 0.15rem 0 0;
  font-size: 1.05rem;
  font-weight: 800;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  line-height: 1.25;
}

.sign-page__brand p {
  margin: 0;
  font-size: 0.92rem;
  color: #6b7280;
  font-weight: 500;
}

.sign-card {
  background: #fff;
  border-radius: 1rem;
  padding: 1rem 1.05rem 1.05rem;
  box-shadow: 0 10px 28px rgba(17, 24, 39, 0.06);
  border: 1px solid rgba(229, 231, 235, 0.9);
}

.sign-card h2 {
  margin: 0 0 0.75rem;
  font-size: 1.05rem;
  font-weight: 750;
  color: #111827;
}

.sign-card__rows {
  margin: 0;
  display: grid;
  gap: 0.7rem;
}

.sign-card__rows > div {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  gap: 1rem;
}

.sign-card__rows dt {
  font-size: 0.88rem;
  color: #6b7280;
  font-weight: 500;
}

.sign-card__rows dd {
  margin: 0;
  text-align: right;
  font-size: 0.92rem;
  font-weight: 700;
  color: #111827;
  word-break: break-word;
}

.sign-card__pad-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  margin-bottom: 0.65rem;
}

.sign-card__pad-head h2 {
  margin: 0;
}

.sign-card__clear {
  border: 0;
  background: transparent;
  color: var(--sign-brand);
  font-weight: 700;
  font-size: 0.92rem;
  cursor: pointer;
  padding: 0.2rem 0.1rem;
}

.sign-card__canvas {
  width: 100%;
  height: 12.5rem;
  border: 1.5px dashed #d1d5db;
  border-radius: 0.85rem;
  background: #fff;
  touch-action: none;
  cursor: crosshair;
  display: block;
}

.sign-card__hint {
  margin: 0.7rem 0 0.9rem;
  font-size: 0.8rem;
  line-height: 1.45;
  color: #9ca3af;
}

.sign-card__confirm {
  width: 100%;
  border: 0;
  border-radius: 0.85rem;
  padding: 0.9rem 1rem;
  background: var(--sign-brand);
  color: #fff;
  font-size: 1rem;
  font-weight: 750;
  cursor: pointer;
}

.sign-card__confirm:disabled {
  opacity: 0.45;
  cursor: not-allowed;
}

.sign-card--done p {
  margin: 0;
  color: #047857;
  font-weight: 650;
  line-height: 1.45;
}

.sign-page__state {
  margin: 0;
  text-align: center;
  padding: 1rem;
  border-radius: 0.85rem;
  background: #fff;
  color: #6b7280;
  box-shadow: 0 8px 20px rgba(17, 24, 39, 0.05);
}

.sign-page__state--error {
  color: #b91c1c;
  background: #fef2f2;
}
</style>
