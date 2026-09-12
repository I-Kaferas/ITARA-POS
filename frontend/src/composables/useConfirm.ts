import { reactive } from 'vue'

export interface ConfirmLine {
  name: string
  detail?: string
  quantity?: string | number
}

export interface ConfirmOptions {
  title?: string
  confirmLabel?: string
  cancelLabel?: string
  danger?: boolean
  items?: ConfirmLine[]
}

interface ConfirmState {
  open: boolean
  mode: 'confirm' | 'notice'
  title: string
  message: string
  confirmLabel: string
  cancelLabel: string
  danger: boolean
  items: ConfirmLine[]
}

const state = reactive<ConfirmState>({
  open: false,
  mode: 'confirm',
  title: '',
  message: '',
  confirmLabel: '',
  cancelLabel: '',
  danger: true,
  items: [],
})

let resolver: ((value: boolean) => void) | null = null

function settle(value: boolean) {
  state.open = false
  resolver?.(value)
  resolver = null
}

export function useConfirm() {
  function confirm(message: string, options: ConfirmOptions = {}) {
    if (resolver) settle(false)

    state.mode = 'confirm'
    state.title = options.title ?? ''
    state.message = message
    state.confirmLabel = options.confirmLabel ?? ''
    state.cancelLabel = options.cancelLabel ?? ''
    state.danger = options.danger ?? true
    state.items = options.items ?? []
    state.open = true

    return new Promise<boolean>((resolve) => {
      resolver = resolve
    })
  }

  function notify(message: string, options: Pick<ConfirmOptions, 'title' | 'confirmLabel'> = {}) {
    if (resolver) settle(false)

    state.mode = 'notice'
    state.title = options.title ?? ''
    state.message = message
    state.confirmLabel = options.confirmLabel ?? ''
    state.cancelLabel = ''
    state.danger = false
    state.items = []
    state.open = true

    return new Promise<void>((resolve) => {
      resolver = () => resolve()
    })
  }

  return { confirm, notify, state, settle }
}
