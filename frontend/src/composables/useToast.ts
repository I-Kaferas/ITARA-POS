import { ref } from 'vue'

export type ToastTone = 'info' | 'success' | 'warning' | 'danger'

export interface ToastInput {
  tone?: ToastTone
  title?: string
  message: string
  duration?: number
}

export interface ToastRecord {
  id: number
  tone: ToastTone
  title: string
  message: string
}

const toasts = ref<ToastRecord[]>([])
const timers = new Map<number, ReturnType<typeof setTimeout>>()
let sequence = 0

export function dismissToast(id: number) {
  const timer = timers.get(id)
  if (timer) clearTimeout(timer)
  timers.delete(id)
  toasts.value = toasts.value.filter((item) => item.id !== id)
}

export function pushToast(input: ToastInput) {
  const id = ++sequence
  const tone = input.tone ?? 'info'
  toasts.value = [
    ...toasts.value,
    { id, tone, title: input.title ?? '', message: input.message },
  ].slice(-3)
  const duration = input.duration ?? (tone === 'danger' ? 6400 : 4200)
  if (duration > 0) {
    timers.set(id, setTimeout(() => dismissToast(id), duration))
  }
  return id
}

export function useToast() {
  return { toasts, push: pushToast, dismiss: dismissToast }
}
