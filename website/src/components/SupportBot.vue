<script setup lang="ts">
import { computed, nextTick, ref, watch } from 'vue'
import { botReply, botWelcome, isHumanHandoff, type BotContext } from '../bot'
import { useI18n } from '../i18n'
import ModuleIcon from './ModuleIcon.vue'

const props = defineProps<{
  open: boolean
  context: BotContext
}>()

const emit = defineEmits<{
  'update:open': [value: boolean]
  handoff: []
}>()

const { t, locale } = useI18n()

type ChatMessage = { id: number; role: 'bot' | 'user'; text: string }

const input = ref('')
const sending = ref(false)
const messages = ref<ChatMessage[]>([])
const suggestions = ref<string[]>([])
const listEl = ref<HTMLElement | null>(null)
let seq = 0

const title = computed(() =>
  t('bot.title').replaceAll('{product}', props.context.product || 'ITARA'),
)
const subtitle = computed(() => t('bot.subtitle'))

function push(role: 'bot' | 'user', text: string) {
  messages.value.push({ id: ++seq, role, text })
}

async function scrollBottom() {
  await nextTick()
  const el = listEl.value
  if (el) el.scrollTop = el.scrollHeight
}

function resetChat() {
  messages.value = []
  const welcome = botWelcome(locale.value, props.context)
  push('bot', welcome.text)
  suggestions.value = welcome.suggestions
  void scrollBottom()
}

function close() {
  emit('update:open', false)
}

async function ask(raw: string) {
  const text = raw.trim()
  if (!text || sending.value) return
  input.value = ''
  push('user', text)
  suggestions.value = []
  await scrollBottom()

  if (isHumanHandoff(text)) {
    push('bot', t('bot.handoff'))
    suggestions.value = []
    await scrollBottom()
    emit('handoff')
    return
  }

  sending.value = true
  await new Promise((r) => setTimeout(r, 320))
  const reply = botReply(text, locale.value, props.context)
  push('bot', reply.text)
  suggestions.value = reply.suggestions
  sending.value = false
  await scrollBottom()
}

function onSubmit() {
  void ask(input.value)
}

watch(
  () => props.open,
  (open) => {
    if (open && messages.value.length === 0) resetChat()
  },
)

watch(locale, () => {
  if (props.open) resetChat()
})
</script>

<template>
  <Teleport to="body">
    <div v-if="open" class="bot" role="dialog" aria-modal="true" :aria-label="title">
      <button type="button" class="bot__backdrop" aria-label="Close" @click="close" />
      <div class="bot__panel">
        <header class="bot__head">
          <div class="bot__avatar" aria-hidden="true">
            <ModuleIcon name="SUP" />
          </div>
          <div class="bot__head-copy">
            <strong>{{ title }}</strong>
            <span>
              <i class="bot__live" aria-hidden="true" />
              {{ subtitle }}
            </span>
          </div>
          <button type="button" class="bot__close" :aria-label="t('bot.close')" @click="close">
            ×
          </button>
        </header>

        <div ref="listEl" class="bot__messages">
          <div
            v-for="msg in messages"
            :key="msg.id"
            class="bot__bubble"
            :class="msg.role === 'user' ? 'bot__bubble--user' : 'bot__bubble--bot'"
          >
            {{ msg.text }}
          </div>
          <div v-if="sending" class="bot__bubble bot__bubble--bot bot__bubble--typing">
            <span /><span /><span />
          </div>
        </div>

        <div v-if="suggestions.length" class="bot__suggestions">
          <button
            v-for="chip in suggestions"
            :key="chip"
            type="button"
            class="bot__chip"
            @click="ask(chip)"
          >
            {{ chip }}
          </button>
        </div>

        <form class="bot__composer" @submit.prevent="onSubmit">
          <input
            v-model="input"
            type="text"
            :placeholder="t('bot.placeholder')"
            autocomplete="off"
            :disabled="sending"
          />
          <button type="submit" class="bot__send" :disabled="sending || !input.trim()">
            <ModuleIcon name="SEND" />
          </button>
        </form>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.bot {
  position: fixed;
  inset: 0;
  z-index: 80;
  display: grid;
  place-items: end;
  padding: 1rem;
  pointer-events: none;
}

.bot__backdrop {
  position: absolute;
  inset: 0;
  border: 0;
  background: rgba(8, 16, 28, 0.35);
  cursor: pointer;
  pointer-events: auto;
}

.bot__panel {
  position: relative;
  z-index: 1;
  display: flex;
  flex-direction: column;
  width: min(100%, 24.5rem);
  height: min(34rem, calc(100dvh - 2rem));
  overflow: hidden;
  border-radius: 1.1rem;
  background: var(--surface, #fff);
  border: 1px solid color-mix(in srgb, var(--brand-primary, #12243c) 14%, transparent);
  box-shadow:
    0 18px 50px rgba(15, 31, 52, 0.28),
    inset 0 1px 0 rgba(255, 255, 255, 0.5);
  pointer-events: auto;
  animation: bot-rise 280ms ease both;
}

@keyframes bot-rise {
  from {
    opacity: 0;
    transform: translateY(12px) scale(0.98);
  }
  to {
    opacity: 1;
    transform: translateY(0) scale(1);
  }
}

.bot__head {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.95rem 1rem;
  background: var(--brand-primary, #12243c);
  color: #fff;
}

.bot__avatar {
  display: grid;
  place-items: center;
  width: 2.5rem;
  height: 2.5rem;
  border-radius: 0.75rem;
  color: var(--brand-accent, #e39b2b);
  background: color-mix(in srgb, var(--brand-accent, #e39b2b) 18%, transparent);
  border: 1px solid color-mix(in srgb, var(--brand-accent, #e39b2b) 35%, transparent);
  transition: transform 340ms cubic-bezier(0.34, 1.45, 0.64, 1);
}

.bot__avatar :deep(svg) {
  width: 1.15rem;
  height: 1.15rem;
  transform-origin: center;
}

.bot__head:hover .bot__avatar {
  transform: translateY(-3px) scale(1.1);
}

.bot__head:hover .bot__avatar :deep(svg) {
  animation: icon-wiggle 520ms ease;
}

.bot__head-copy {
  flex: 1;
  min-width: 0;
}

.bot__head-copy strong {
  display: block;
  font-size: 0.95rem;
  font-weight: 700;
}

.bot__head-copy span {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  margin-top: 0.15rem;
  font-size: 0.75rem;
  color: rgba(255, 255, 255, 0.7);
}

.bot__live {
  width: 0.45rem;
  height: 0.45rem;
  border-radius: 999px;
  background: #4ade80;
  box-shadow: 0 0 0 3px color-mix(in srgb, #4ade80 30%, transparent);
}

.bot__close {
  width: 2rem;
  height: 2rem;
  border: 0;
  border-radius: 0.55rem;
  background: rgba(255, 255, 255, 0.1);
  color: #fff;
  font-size: 1.35rem;
  line-height: 1;
  cursor: pointer;
}

.bot__close:hover {
  background: rgba(255, 255, 255, 0.18);
}

.bot__messages {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 0.65rem;
  padding: 1rem;
  overflow-y: auto;
  background: color-mix(in srgb, var(--canvas, #f4f6f8) 88%, transparent);
}

.bot__bubble {
  max-width: 88%;
  padding: 0.7rem 0.85rem;
  border-radius: 0.9rem;
  font-size: 0.875rem;
  line-height: 1.45;
  white-space: pre-wrap;
}

.bot__bubble--bot {
  align-self: flex-start;
  background: var(--surface, #fff);
  color: var(--ink, #1a2433);
  border: 1px solid var(--border, #e3e7eb);
  border-bottom-left-radius: 0.35rem;
}

.bot__bubble--user {
  align-self: flex-end;
  background: var(--brand-primary, #12243c);
  color: #fff;
  border-bottom-right-radius: 0.35rem;
}

.bot__bubble--typing {
  display: inline-flex;
  gap: 0.28rem;
  padding: 0.85rem 1rem;
}

.bot__bubble--typing span {
  width: 0.35rem;
  height: 0.35rem;
  border-radius: 999px;
  background: var(--muted, #8a93a3);
  animation: bot-dot 1s ease infinite;
}

.bot__bubble--typing span:nth-child(2) { animation-delay: 0.15s; }
.bot__bubble--typing span:nth-child(3) { animation-delay: 0.3s; }

@keyframes bot-dot {
  0%, 80%, 100% { opacity: 0.35; transform: translateY(0); }
  40% { opacity: 1; transform: translateY(-2px); }
}

.bot__suggestions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.45rem;
  padding: 0 1rem 0.75rem;
  background: color-mix(in srgb, var(--canvas, #f4f6f8) 88%, transparent);
}

.bot__chip {
  padding: 0.4rem 0.7rem;
  border-radius: 999px;
  border: 1px solid color-mix(in srgb, var(--brand-primary, #12243c) 18%, var(--border, #e3e7eb));
  background: var(--surface, #fff);
  color: var(--ink-strong, #12243c);
  font-size: 0.75rem;
  font-weight: 600;
  cursor: pointer;
}

.bot__chip:hover {
  border-color: var(--brand-accent, #e39b2b);
  color: var(--brand-primary, #12243c);
}

.bot__composer {
  display: flex;
  gap: 0.55rem;
  padding: 0.85rem 1rem 1rem;
  border-top: 1px solid var(--border, #e3e7eb);
  background: var(--surface, #fff);
}

.bot__composer input {
  flex: 1;
  min-width: 0;
  height: 2.6rem;
  padding: 0 0.85rem;
  border-radius: 0.75rem;
  border: 1px solid var(--border-strong, #d7e0e8);
  background: var(--canvas, #f4f6f8);
  color: var(--ink, #1a2433);
  font: inherit;
  outline: none;
}

.bot__composer input:focus {
  border-color: var(--brand-primary, #12243c);
  box-shadow: 0 0 0 3px color-mix(in srgb, var(--brand-primary, #12243c) 14%, transparent);
}

.bot__send {
  display: grid;
  place-items: center;
  width: 2.6rem;
  height: 2.6rem;
  border: 0;
  border-radius: 0.75rem;
  background: var(--brand-primary, #12243c);
  color: #fff;
  cursor: pointer;
}

.bot__send:disabled {
  opacity: 0.45;
  cursor: not-allowed;
}

.bot__send :deep(svg) {
  width: 1.05rem;
  height: 1.05rem;
  transform-origin: center;
  transition: transform 340ms cubic-bezier(0.34, 1.45, 0.64, 1);
}

.bot__send:hover :deep(svg) {
  transform: translateY(-2px) scale(1.14) rotate(-10deg);
}

@media (max-width: 520px) {
  .bot {
    padding: 0;
    place-items: stretch;
  }

  .bot__panel {
    width: 100%;
    height: 100dvh;
    border-radius: 0;
  }
}
</style>
