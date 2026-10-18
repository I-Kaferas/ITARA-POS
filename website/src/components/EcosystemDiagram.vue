<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useI18n } from '../i18n'

defineProps<{ brand?: string }>()

const { t, dict } = useI18n()

type ArchMode = 'master' | 'slave' | 'standalone'

const modes = computed(() => [
  { id: 'master' as const, label: t('eco.master'), blurb: t('eco.masterBlurb') },
  { id: 'slave' as const, label: t('eco.slave'), blurb: t('eco.slaveBlurb') },
  { id: 'standalone' as const, label: t('eco.standalone'), blurb: t('eco.standaloneBlurb') },
])

const mode = ref<ArchMode>('master')
const modeIndex = computed(() => modes.value.findIndex((m) => m.id === mode.value))
const activeMeta = computed(() => modes.value[modeIndex.value] ?? modes.value[0])
const eco = computed(() => dict.value.eco)
const stage = ref<HTMLElement | null>(null)
const hoverNode = ref<string | null>(null)
const reduced = ref(false)
const parallax = ref({ x: 0, y: 0 })

let timer: number | undefined

function selectMode(id: ArchMode) {
  mode.value = id
  hoverNode.value = null
  restartTimer()
}

function nextMode() {
  const i = (modeIndex.value + 1) % modes.value.length
  mode.value = modes.value[i].id
  hoverNode.value = null
}

function restartTimer() {
  window.clearInterval(timer)
  if (reduced.value) return
  timer = window.setInterval(nextMode, 6200)
}

function onPointerMove(event: PointerEvent) {
  if (reduced.value || !stage.value) return
  const rect = stage.value.getBoundingClientRect()
  const nx = ((event.clientX - rect.left) / rect.width - 0.5) * 2
  const ny = ((event.clientY - rect.top) / rect.height - 0.5) * 2
  parallax.value = { x: nx * 8, y: ny * 6 }
}

function onPointerLeave() {
  parallax.value = { x: 0, y: 0 }
  hoverNode.value = null
}

function focusNode(id: string) {
  hoverNode.value = id
  restartTimer()
}

function blurNode(id: string) {
  if (hoverNode.value === id) hoverNode.value = null
}

onMounted(() => {
  reduced.value = window.matchMedia('(prefers-reduced-motion: reduce)').matches
  restartTimer()
})
onBeforeUnmount(() => window.clearInterval(timer))
</script>

<template>
  <div
    class="eco"
    role="img"
    :aria-label="`${brand || 'POS'} — ${activeMeta.label}: ${activeMeta.blurb}`"
  >
    <div class="eco__tabs" role="tablist" :aria-label="t('eco.modesLabel')">
      <button
        v-for="m in modes"
        :key="m.id"
        type="button"
        role="tab"
        class="eco__tab"
        :class="{ 'is-active': mode === m.id }"
        :aria-selected="mode === m.id"
        @click="selectMode(m.id)"
      >
        {{ m.label }}
      </button>
    </div>
    <p class="eco__blurb">{{ activeMeta.blurb }}</p>

    <div
      ref="stage"
      class="eco__stage"
      @pointermove="onPointerMove"
      @pointerleave="onPointerLeave"
    >
      <div
        class="eco__parallax"
        :style="{
          transform: `translate3d(${parallax.x}px, ${parallax.y}px, 0)`,
        }"
      >
        <!-- MASTER -->
        <svg
          v-show="mode === 'master'"
          class="eco__svg"
          viewBox="0 0 520 360"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
        >
          <g
            class="eco__wires"
            :class="{ 'is-dim': hoverNode }"
            stroke="currentColor"
            stroke-width="1.5"
            opacity="0.4"
          >
            <path
              class="eco__wire"
              :class="{ 'is-lit': !hoverNode || hoverNode === 'cloud' || hoverNode === 'hub' }"
              d="M260 88 L260 132"
            />
            <path
              class="eco__wire eco__wire--delay"
              :class="{ 'is-lit': !hoverNode || hoverNode === 'hub' || hoverNode === 'pos-a' }"
              d="M260 168 L120 220"
            />
            <path
              class="eco__wire eco__wire--delay2"
              :class="{ 'is-lit': !hoverNode || hoverNode === 'hub' || hoverNode === 'pos-b' }"
              d="M260 168 L400 220"
            />
          </g>
          <g class="eco__packets" aria-hidden="true">
            <circle class="eco__packet eco__packet--m1" r="3.5" fill="var(--brand-accent, #e39b2b)" />
            <circle class="eco__packet eco__packet--m2" r="3.5" fill="var(--brand-accent, #e39b2b)" />
            <circle class="eco__packet eco__packet--m3" r="3.5" fill="#ffffff" opacity="0.9" />
          </g>

          <g transform="translate(180 28)">
            <g
              class="eco__float eco__float--1 eco__node"
              :class="{ 'is-hot': hoverNode === 'cloud', 'is-dim': hoverNode && hoverNode !== 'cloud' }"
              tabindex="0"
              role="button"
              @pointerenter="focusNode('cloud')"
              @pointerleave="blurNode('cloud')"
              @focus="focusNode('cloud')"
              @blur="blurNode('cloud')"
            >
              <rect width="160" height="60" rx="12" fill="rgba(255,255,255,0.08)" stroke="rgba(255,255,255,0.28)" />
              <rect x="18" y="16" width="28" height="28" rx="6" fill="var(--brand-accent, #e39b2b)" />
              <text x="56" y="28" fill="#fff" font-size="11" font-weight="700" font-family="system-ui,sans-serif">{{ eco.backoffice }}</text>
              <text x="56" y="44" fill="rgba(255,255,255,0.55)" font-size="9" font-family="system-ui,sans-serif">{{ eco.cloudAdmin }}</text>
            </g>
          </g>

          <g transform="translate(190 132)">
            <g
              class="eco__float eco__float--2 eco__node"
              :class="{ 'is-hot': hoverNode === 'hub', 'is-dim': hoverNode && hoverNode !== 'hub' }"
              tabindex="0"
              role="button"
              @pointerenter="focusNode('hub')"
              @pointerleave="blurNode('hub')"
              @focus="focusNode('hub')"
              @blur="blurNode('hub')"
            >
              <rect width="140" height="56" rx="12" fill="rgba(255,255,255,0.1)" stroke="var(--brand-accent, #e39b2b)" stroke-width="1.5" />
              <circle cx="28" cy="28" r="10" fill="var(--brand-accent, #e39b2b)" />
              <circle class="eco__pulse" cx="28" cy="28" r="10" fill="none" stroke="var(--brand-accent, #e39b2b)" stroke-width="1.5" />
              <text x="48" y="26" fill="#fff" font-size="11" font-weight="700" font-family="system-ui,sans-serif">{{ eco.masterHub }}</text>
              <text x="48" y="40" fill="rgba(255,255,255,0.55)" font-size="9" font-family="system-ui,sans-serif">{{ eco.syncLocal }}</text>
            </g>
          </g>

          <g transform="translate(48 220)">
            <g
              class="eco__float eco__float--3 eco__node"
              :class="{ 'is-hot': hoverNode === 'pos-a', 'is-dim': hoverNode && hoverNode !== 'pos-a' }"
              tabindex="0"
              role="button"
              @pointerenter="focusNode('pos-a')"
              @pointerleave="blurNode('pos-a')"
              @focus="focusNode('pos-a')"
              @blur="blurNode('pos-a')"
            >
              <rect width="144" height="72" rx="12" fill="rgba(255,255,255,0.07)" stroke="rgba(255,255,255,0.22)" />
              <rect x="14" y="14" width="40" height="28" rx="4" fill="rgba(255,255,255,0.12)" stroke="rgba(255,255,255,0.2)" />
              <rect x="18" y="18" width="14" height="8" rx="1" fill="rgba(255,255,255,0.35)" />
              <rect x="34" y="18" width="14" height="8" rx="1" fill="rgba(255,255,255,0.2)" />
              <rect x="18" y="29" width="30" height="8" rx="1" fill="var(--brand-accent, #e39b2b)" opacity="0.75" />
              <text x="64" y="28" fill="#fff" font-size="11" font-weight="700" font-family="system-ui,sans-serif">{{ eco.posSlave }}</text>
              <text x="64" y="44" fill="rgba(255,255,255,0.5)" font-size="9" font-family="system-ui,sans-serif">{{ eco.windowsLan }}</text>
            </g>
          </g>

          <g transform="translate(328 220)">
            <g
              class="eco__float eco__float--4 eco__node"
              :class="{ 'is-hot': hoverNode === 'pos-b', 'is-dim': hoverNode && hoverNode !== 'pos-b' }"
              tabindex="0"
              role="button"
              @pointerenter="focusNode('pos-b')"
              @pointerleave="blurNode('pos-b')"
              @focus="focusNode('pos-b')"
              @blur="blurNode('pos-b')"
            >
              <rect width="144" height="72" rx="12" fill="rgba(255,255,255,0.07)" stroke="rgba(255,255,255,0.22)" />
              <rect x="22" y="12" width="24" height="40" rx="5" fill="rgba(255,255,255,0.12)" stroke="rgba(255,255,255,0.2)" />
              <rect x="26" y="18" width="16" height="24" rx="2" fill="rgba(255,255,255,0.18)" />
              <circle cx="34" cy="46" r="2" fill="rgba(255,255,255,0.4)" />
              <text x="58" y="28" fill="#fff" font-size="11" font-weight="700" font-family="system-ui,sans-serif">{{ eco.posSlave }}</text>
              <text x="58" y="44" fill="rgba(255,255,255,0.5)" font-size="9" font-family="system-ui,sans-serif">{{ eco.androidLan }}</text>
            </g>
          </g>

          <g transform="translate(160 308)">
            <g
              class="eco__float eco__float--5 eco__node"
              :class="{ 'is-hot': hoverNode === 'stock', 'is-dim': hoverNode && hoverNode !== 'stock' }"
              tabindex="0"
              role="button"
              @pointerenter="focusNode('stock')"
              @pointerleave="blurNode('stock')"
              @focus="focusNode('stock')"
              @blur="blurNode('stock')"
            >
              <rect width="200" height="36" rx="8" fill="rgba(255,255,255,0.06)" stroke="rgba(255,255,255,0.18)" />
              <text x="100" y="22" text-anchor="middle" fill="#fff" font-size="10" font-weight="600" font-family="system-ui,sans-serif">{{ eco.stockCatalog }}</text>
            </g>
          </g>
        </svg>

        <!-- ESCLAVE -->
        <svg
          v-show="mode === 'slave'"
          class="eco__svg"
          viewBox="0 0 520 360"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
        >
          <g
            class="eco__wires"
            :class="{ 'is-dim': hoverNode }"
            stroke="currentColor"
            stroke-width="1.5"
            opacity="0.4"
          >
            <path
              class="eco__wire"
              :class="{ 'is-lit': !hoverNode || hoverNode === 'hub' || hoverNode === 'pos' }"
              d="M160 160 L360 160"
            />
            <path
              class="eco__wire eco__wire--delay"
              :class="{ 'is-lit': !hoverNode || hoverNode === 'cloud' || hoverNode === 'hub' }"
              d="M100 88 L100 128"
            />
            <path
              class="eco__wire eco__wire--delay2"
              :class="{ 'is-lit': !hoverNode || hoverNode === 'hub' || hoverNode === 'stock' }"
              d="M100 200 L100 248"
            />
          </g>
          <g class="eco__packets" aria-hidden="true">
            <circle class="eco__packet eco__packet--s1" r="3.5" fill="var(--brand-accent, #e39b2b)" />
            <circle class="eco__packet eco__packet--s2" r="3.5" fill="#ffffff" opacity="0.9" />
          </g>

          <g transform="translate(28 48)">
            <g
              class="eco__float eco__float--1 eco__node"
              :class="{ 'is-hot': hoverNode === 'cloud', 'is-dim': hoverNode && hoverNode !== 'cloud' }"
              tabindex="0"
              role="button"
              @pointerenter="focusNode('cloud')"
              @pointerleave="blurNode('cloud')"
              @focus="focusNode('cloud')"
              @blur="blurNode('cloud')"
            >
              <rect width="144" height="52" rx="12" fill="rgba(255,255,255,0.08)" stroke="rgba(255,255,255,0.22)" />
              <text x="72" y="22" text-anchor="middle" fill="#fff" font-size="11" font-weight="700" font-family="system-ui,sans-serif">{{ eco.backoffice }}</text>
              <text x="72" y="38" text-anchor="middle" fill="rgba(255,255,255,0.5)" font-size="9" font-family="system-ui,sans-serif">{{ eco.viaMaster }}</text>
            </g>
          </g>

          <g transform="translate(36 128)">
            <g
              class="eco__float eco__float--2 eco__node"
              :class="{ 'is-hot': hoverNode === 'hub', 'is-dim': hoverNode && hoverNode !== 'hub' }"
              tabindex="0"
              role="button"
              @pointerenter="focusNode('hub')"
              @pointerleave="blurNode('hub')"
              @focus="focusNode('hub')"
              @blur="blurNode('hub')"
            >
              <rect width="128" height="72" rx="12" fill="rgba(255,255,255,0.1)" stroke="var(--brand-accent, #e39b2b)" stroke-width="1.5" />
              <circle cx="24" cy="36" r="8" fill="var(--brand-accent, #e39b2b)" />
              <circle class="eco__pulse" cx="24" cy="36" r="8" fill="none" stroke="var(--brand-accent, #e39b2b)" stroke-width="1.5" />
              <text x="42" y="32" fill="#fff" font-size="11" font-weight="700" font-family="system-ui,sans-serif">{{ eco.masterShort }}</text>
              <text x="42" y="48" fill="rgba(255,255,255,0.55)" font-size="9" font-family="system-ui,sans-serif">{{ eco.lanWifi }}</text>
            </g>
          </g>

          <g transform="translate(340 118)">
            <g
              class="eco__float eco__float--3 eco__node"
              :class="{ 'is-hot': hoverNode === 'pos', 'is-dim': hoverNode && hoverNode !== 'pos' }"
              tabindex="0"
              role="button"
              @pointerenter="focusNode('pos')"
              @pointerleave="blurNode('pos')"
              @focus="focusNode('pos')"
              @blur="blurNode('pos')"
            >
              <rect width="152" height="92" rx="12" fill="rgba(255,255,255,0.1)" stroke="rgba(255,255,255,0.32)" stroke-width="1.5" />
              <rect x="14" y="16" width="36" height="26" rx="4" fill="rgba(255,255,255,0.12)" stroke="rgba(255,255,255,0.2)" />
              <rect x="18" y="20" width="12" height="7" rx="1" fill="rgba(255,255,255,0.35)" />
              <rect x="32" y="20" width="12" height="7" rx="1" fill="rgba(255,255,255,0.2)" />
              <rect x="18" y="30" width="26" height="7" rx="1" fill="var(--brand-accent, #e39b2b)" opacity="0.8" />
              <text x="62" y="30" fill="#fff" font-size="12" font-weight="700" font-family="system-ui,sans-serif">{{ eco.posSlave }}</text>
              <text x="62" y="46" fill="rgba(255,255,255,0.55)" font-size="9" font-family="system-ui,sans-serif">{{ eco.salesPay }}</text>
              <text x="14" y="74" fill="rgba(255,255,255,0.45)" font-size="9" font-family="system-ui,sans-serif">{{ eco.slaveNote }}</text>
            </g>
          </g>

          <g transform="translate(36 248)">
            <g
              class="eco__float eco__float--4 eco__node"
              :class="{ 'is-hot': hoverNode === 'stock', 'is-dim': hoverNode && hoverNode !== 'stock' }"
              tabindex="0"
              role="button"
              @pointerenter="focusNode('stock')"
              @pointerleave="blurNode('stock')"
              @focus="focusNode('stock')"
              @blur="blurNode('stock')"
            >
              <rect width="128" height="44" rx="10" fill="rgba(255,255,255,0.06)" stroke="rgba(255,255,255,0.18)" />
              <text x="64" y="18" text-anchor="middle" fill="#fff" font-size="10" font-weight="600" font-family="system-ui,sans-serif">{{ eco.sharedStock }}</text>
              <text x="64" y="34" text-anchor="middle" fill="rgba(255,255,255,0.45)" font-size="9" font-family="system-ui,sans-serif">{{ eco.realtimeCatalog }}</text>
            </g>
          </g>

          <g transform="translate(340 248)">
            <g
              class="eco__float eco__float--5 eco__node"
              :class="{ 'is-hot': hoverNode === 'queue', 'is-dim': hoverNode && hoverNode !== 'queue' }"
              tabindex="0"
              role="button"
              @pointerenter="focusNode('queue')"
              @pointerleave="blurNode('queue')"
              @focus="focusNode('queue')"
              @blur="blurNode('queue')"
            >
              <rect width="152" height="44" rx="10" fill="rgba(255,255,255,0.06)" stroke="rgba(255,255,255,0.18)" />
              <text x="76" y="18" text-anchor="middle" fill="#fff" font-size="10" font-weight="600" font-family="system-ui,sans-serif">{{ eco.offlineQueue }}</text>
              <text x="76" y="34" text-anchor="middle" fill="rgba(255,255,255,0.45)" font-size="9" font-family="system-ui,sans-serif">{{ eco.syncWhenBack }}</text>
            </g>
          </g>
        </svg>

        <!-- STANDALONE -->
        <svg
          v-show="mode === 'standalone'"
          class="eco__svg"
          viewBox="0 0 520 360"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
        >
          <g
            class="eco__wires"
            :class="{ 'is-dim': hoverNode }"
            stroke="currentColor"
            stroke-width="1.5"
            opacity="0.4"
          >
            <path
              class="eco__wire"
              :class="{ 'is-lit': !hoverNode || hoverNode === 'cloud' || hoverNode === 'pos' }"
              d="M260 98 L260 148"
            />
            <path
              class="eco__wire eco__wire--delay"
              :class="{ 'is-lit': !hoverNode || hoverNode === 'pos' || hoverNode === 'stock' }"
              d="M180 250 L140 300"
            />
            <path
              class="eco__wire eco__wire--delay2"
              :class="{ 'is-lit': !hoverNode || hoverNode === 'pos' || hoverNode === 'catalog' }"
              d="M340 250 L380 300"
            />
          </g>
          <g class="eco__packets" aria-hidden="true">
            <circle class="eco__packet eco__packet--a1" r="3.5" fill="var(--brand-accent, #e39b2b)" />
            <circle class="eco__packet eco__packet--a2" r="3.5" fill="#ffffff" opacity="0.9" />
          </g>

          <g transform="translate(180 28)">
            <g
              class="eco__float eco__float--1 eco__node"
              :class="{ 'is-hot': hoverNode === 'cloud', 'is-dim': hoverNode && hoverNode !== 'cloud' }"
              tabindex="0"
              role="button"
              @pointerenter="focusNode('cloud')"
              @pointerleave="blurNode('cloud')"
              @focus="focusNode('cloud')"
              @blur="blurNode('cloud')"
            >
              <rect width="160" height="60" rx="12" fill="rgba(255,255,255,0.08)" stroke="rgba(255,255,255,0.28)" />
              <rect x="18" y="16" width="28" height="28" rx="6" fill="var(--brand-accent, #e39b2b)" />
              <text x="56" y="28" fill="#fff" font-size="11" font-weight="700" font-family="system-ui,sans-serif">{{ eco.backoffice }}</text>
              <text x="56" y="44" fill="rgba(255,255,255,0.55)" font-size="9" font-family="system-ui,sans-serif">{{ eco.cloudDirect }}</text>
            </g>
          </g>

          <g transform="translate(150 148)">
            <g
              class="eco__float eco__float--2 eco__node"
              :class="{ 'is-hot': hoverNode === 'pos', 'is-dim': hoverNode && hoverNode !== 'pos' }"
              tabindex="0"
              role="button"
              @pointerenter="focusNode('pos')"
              @pointerleave="blurNode('pos')"
              @focus="focusNode('pos')"
              @blur="blurNode('pos')"
            >
              <rect width="220" height="100" rx="14" fill="rgba(255,255,255,0.1)" stroke="var(--brand-accent, #e39b2b)" stroke-width="1.5" />
              <rect x="22" y="22" width="44" height="32" rx="5" fill="rgba(255,255,255,0.12)" stroke="rgba(255,255,255,0.22)" />
              <rect x="28" y="28" width="14" height="8" rx="1" fill="rgba(255,255,255,0.4)" />
              <rect x="46" y="28" width="14" height="8" rx="1" fill="rgba(255,255,255,0.22)" />
              <rect x="28" y="40" width="32" height="8" rx="1" fill="var(--brand-accent, #e39b2b)" opacity="0.8" />
              <circle class="eco__pulse" cx="44" cy="38" r="18" fill="none" stroke="var(--brand-accent, #e39b2b)" stroke-width="1.2" opacity="0.5" />
              <text x="82" y="38" fill="#fff" font-size="13" font-weight="700" font-family="system-ui,sans-serif">{{ eco.posStandalone }}</text>
              <text x="82" y="56" fill="rgba(255,255,255,0.55)" font-size="10" font-family="system-ui,sans-serif">{{ eco.winOrAndroid }}</text>
              <text x="22" y="84" fill="rgba(255,255,255,0.45)" font-size="9" font-family="system-ui,sans-serif">{{ eco.noMaster }}</text>
            </g>
          </g>

          <g transform="translate(70 300)">
            <g
              class="eco__float eco__float--3 eco__node"
              :class="{ 'is-hot': hoverNode === 'stock', 'is-dim': hoverNode && hoverNode !== 'stock' }"
              tabindex="0"
              role="button"
              @pointerenter="focusNode('stock')"
              @pointerleave="blurNode('stock')"
              @focus="focusNode('stock')"
              @blur="blurNode('stock')"
            >
              <rect width="120" height="40" rx="10" fill="rgba(255,255,255,0.06)" stroke="rgba(255,255,255,0.18)" />
              <text x="60" y="24" text-anchor="middle" fill="#fff" font-size="10" font-weight="600" font-family="system-ui,sans-serif">{{ eco.localStock }}</text>
            </g>
          </g>

          <g transform="translate(330 300)">
            <g
              class="eco__float eco__float--4 eco__node"
              :class="{ 'is-hot': hoverNode === 'catalog', 'is-dim': hoverNode && hoverNode !== 'catalog' }"
              tabindex="0"
              role="button"
              @pointerenter="focusNode('catalog')"
              @pointerleave="blurNode('catalog')"
              @focus="focusNode('catalog')"
              @blur="blurNode('catalog')"
            >
              <rect width="120" height="40" rx="10" fill="rgba(255,255,255,0.06)" stroke="rgba(255,255,255,0.18)" />
              <text x="60" y="24" text-anchor="middle" fill="#fff" font-size="10" font-weight="600" font-family="system-ui,sans-serif">{{ eco.catalog }}</text>
            </g>
          </g>
        </svg>
      </div>
    </div>
  </div>
</template>

<style scoped>
.eco {
  width: min(100%, 34rem);
  margin-inline: auto;
  color: rgba(255, 255, 255, 0.55);
  text-align: center;
}

.eco__tabs {
  display: inline-flex;
  gap: 0.25rem;
  padding: 0.25rem;
  margin-bottom: 0.55rem;
  border-radius: 999px;
  background: color-mix(in srgb, #fff 8%, transparent);
  border: 1px solid color-mix(in srgb, #fff 16%, transparent);
  box-shadow: none;
}

.eco__tab {
  min-height: 2rem;
  padding: 0.35rem 0.9rem;
  border: 0;
  border-radius: 999px;
  background: transparent;
  color: rgba(255, 255, 255, 0.62);
  font-size: 0.75rem;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  cursor: pointer;
  transition: background 180ms ease, color 180ms ease, box-shadow 180ms ease, transform 180ms ease;
}

.eco__tab:hover {
  color: #fff;
  background: color-mix(in srgb, #fff 8%, transparent);
  transform: translateY(-1px);
}

.eco__tab.is-active {
  color: var(--brand-primary-900, #0a1523);
  background: var(--brand-accent, #e39b2b);
  box-shadow: none;
}

.eco__blurb {
  margin: 0 0 0.65rem;
  min-height: 2.4em;
  font-size: 0.8rem;
  color: rgba(255, 255, 255, 0.58);
  transition: opacity 220ms ease, transform 220ms ease;
}

.eco__stage {
  position: relative;
  min-height: 0;
  overflow: visible;
  background: transparent;
  border: 0;
  border-radius: 0;
  box-shadow: none;
  touch-action: pan-y;
}

.eco__glow {
  position: absolute;
  border-radius: 50%;
  pointer-events: none;
  filter: blur(28px);
  opacity: 0.55;
  animation: eco-glow 7s ease-in-out infinite;
}

.eco__glow--a {
  width: 42%;
  height: 38%;
  left: 8%;
  top: 18%;
  background: color-mix(in srgb, var(--brand-accent, #e39b2b) 45%, transparent);
}

.eco__glow--b {
  width: 36%;
  height: 34%;
  right: 6%;
  bottom: 12%;
  background: color-mix(in srgb, #7eb8ff 35%, transparent);
  animation-delay: -3.2s;
}

.eco__parallax {
  position: relative;
  z-index: 1;
  will-change: transform;
  transition: transform 180ms ease-out;
}

.eco__svg {
  display: block;
  width: 100%;
  height: auto;
  padding: 0.55rem 0.35rem 0.85rem;
  animation: eco-fade 420ms ease;
}

.eco__float {
  animation: eco-float 4.8s ease-in-out infinite;
  cursor: pointer;
  outline: none;
  transform-box: fill-box;
  transform-origin: center;
  transition: transform 320ms cubic-bezier(0.34, 1.45, 0.64, 1), opacity 220ms ease, filter 220ms ease;
}

.eco__float:hover {
  transform: scale(1.16) rotate(-8deg);
  filter: drop-shadow(0 8px 10px color-mix(in srgb, var(--brand-accent, #e39b2b) 50%, transparent));
}

.eco__float--1 { animation-delay: 0s; }
.eco__float--2 { animation-delay: 0.3s; }
.eco__float--3 { animation-delay: 0.6s; }
.eco__float--4 { animation-delay: 0.9s; }
.eco__float--5 { animation-delay: 1.1s; }

.eco__node.is-hot {
  filter: drop-shadow(0 0 10px color-mix(in srgb, var(--brand-accent, #e39b2b) 70%, transparent));
  animation-duration: 2.8s;
}

.eco__node.is-dim {
  opacity: 0.38;
}

.eco__wires.is-dim {
  opacity: 0.22;
}

.eco__wire {
  stroke-dasharray: 5 7;
  animation: eco-dash 1.35s linear infinite;
  transition: stroke 200ms ease, opacity 200ms ease;
}

.eco__wire.is-lit {
  stroke: var(--brand-accent, #e39b2b);
  opacity: 0.9;
}

.eco__wire--delay { animation-delay: 0.15s; }
.eco__wire--delay2 { animation-delay: 0.3s; }

.eco__pulse {
  transform-box: fill-box;
  transform-origin: center;
  animation: eco-ring 2.4s ease-out infinite;
}

.eco__packet--m1 {
  offset-path: path("M260 88 L260 152");
  offset-rotate: 0deg;
  animation: eco-travel 2.2s linear infinite;
}

.eco__packet--m2 {
  offset-path: path("M260 168 L120 240");
  offset-rotate: 0deg;
  animation: eco-travel 2.8s linear infinite;
  animation-delay: 0.55s;
}

.eco__packet--m3 {
  offset-path: path("M260 168 L400 240");
  offset-rotate: 0deg;
  animation: eco-travel 2.8s linear infinite;
  animation-delay: 1.05s;
}

.eco__packet--s1 {
  offset-path: path("M360 160 L160 160");
  offset-rotate: 0deg;
  animation: eco-travel 2.4s linear infinite;
}

.eco__packet--s2 {
  offset-path: path("M160 160 L360 160");
  offset-rotate: 0deg;
  animation: eco-travel 2.4s linear infinite;
  animation-delay: 1.2s;
}

.eco__packet--a1 {
  offset-path: path("M260 98 L260 168");
  offset-rotate: 0deg;
  animation: eco-travel 2.2s linear infinite;
}

.eco__packet--a2 {
  offset-path: path("M260 168 L260 98");
  offset-rotate: 0deg;
  animation: eco-travel 2.2s linear infinite;
  animation-delay: 1.1s;
}

@keyframes eco-fade {
  from { opacity: 0; transform: translateY(6px) scale(0.985); }
  to { opacity: 1; transform: none; }
}

@keyframes eco-float {
  0%, 100% { translate: 0 0; }
  50% { translate: 0 -6px; }
}

@keyframes eco-dash {
  to { stroke-dashoffset: -24; }
}

@keyframes eco-ring {
  0% { opacity: 0.65; transform: scale(1); }
  100% { opacity: 0; transform: scale(2.35); }
}

@keyframes eco-travel {
  0% { offset-distance: 0%; opacity: 0; }
  10% { opacity: 1; }
  90% { opacity: 1; }
  100% { offset-distance: 100%; opacity: 0; }
}

@keyframes eco-glow {
  0%, 100% { opacity: 0.35; transform: scale(1); }
  50% { opacity: 0.7; transform: scale(1.08); }
}

@media (prefers-reduced-motion: reduce) {
  .eco__float,
  .eco__wire,
  .eco__pulse,
  .eco__packet--m1,
  .eco__packet--m2,
  .eco__packet--m3,
  .eco__packet--s1,
  .eco__packet--s2,
  .eco__packet--a1,
  .eco__packet--a2,
  .eco__svg,
  .eco__glow,
  .eco__parallax {
    animation: none !important;
    transition: none !important;
  }

  .eco__wire { stroke-dasharray: none; }
  .eco__packets { display: none; }
  .eco__parallax { transform: none !important; }
  .eco__float:hover { transform: none; filter: none; }
}
</style>
