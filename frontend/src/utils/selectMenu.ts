import i18n from '../i18n'

/*
 * Replaces the browser's native <select> popup with the app's dropdown panel
 * (same look as the language / store switchers in the top bar).
 *
 * The native <select> stays in the DOM as the trigger, so v-model, labels,
 * `required` validation and page-specific sizing keep working unchanged.
 * Opt out per element with `data-native` (or on any ancestor with
 * `data-native-selects`). Multi-selects and list boxes (size > 1) stay native.
 */

interface MenuItem {
  option: HTMLOptionElement
  el: HTMLButtonElement
  text: string
  key: string
}

interface OpenMenu {
  select: HTMLSelectElement
  panel: HTMLDivElement
  list: HTMLDivElement
  search: HTMLInputElement | null
  empty: HTMLParagraphElement
  items: MenuItem[]
  visible: MenuItem[]
  active: number
  watchdog: number
}

const SEARCH_THRESHOLD = 8
const PANEL_GAP = 6
const VIEWPORT_PAD = 12
const SVG_NS = 'http://www.w3.org/2000/svg'

let menu: OpenMenu | null = null
let uid = 0
let touchStart: { x: number; y: number; target: EventTarget | null } | null = null
let typeahead = ''
let typeaheadTimer = 0

function t(key: string, fallback: string): string {
  const value = i18n.global.t(key)
  return value && value !== key ? value : fallback
}

function normalize(value: string): string {
  return value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().trim()
}

function isEnhanced(target: EventTarget | null): target is HTMLSelectElement {
  return target instanceof HTMLSelectElement
    && !target.multiple
    && target.size <= 1
    && !target.disabled
    && !target.hasAttribute('data-native')
    && !target.closest('[data-native-selects]')
}

function zoomFactor(): number {
  return Number.parseFloat(getComputedStyle(document.documentElement).zoom) || 1
}

function ownText(el: Element | null | undefined): string {
  if (!el) return ''
  const clone = el.cloneNode(true) as Element
  clone.querySelectorAll('select, option, input, textarea, button, svg').forEach(node => node.remove())
  return clone.textContent ?? ''
}

const LABEL_SELECTOR = 'label, .ui-label, .field-label'

function labelFor(select: HTMLSelectElement): string {
  const previous = select.previousElementSibling
  const fromLabel = ownText(select.labels?.[0])
    || ownText(previous?.matches(LABEL_SELECTOR) ? previous : previous?.querySelector(LABEL_SELECTOR))
    || ownText(select.parentElement?.querySelector(`:scope > :is(${LABEL_SELECTOR})`))
    || ownText(select.closest('.ui-field, .field-group, .form-field')?.querySelector(LABEL_SELECTOR))
  const raw = select.getAttribute('aria-label') || fromLabel || select.title || ''
  return raw.replace(/\s*\*\s*$/, '').replace(/\s+/g, ' ').trim()
}

function icon(paths: string[], className: string): SVGSVGElement {
  const svg = document.createElementNS(SVG_NS, 'svg')
  svg.setAttribute('viewBox', '0 0 24 24')
  svg.setAttribute('fill', 'none')
  svg.setAttribute('stroke', 'currentColor')
  svg.setAttribute('stroke-width', '2')
  svg.setAttribute('stroke-linecap', 'round')
  svg.setAttribute('stroke-linejoin', 'round')
  svg.setAttribute('aria-hidden', 'true')
  svg.setAttribute('class', className)
  for (const d of paths) {
    const path = document.createElementNS(SVG_NS, 'path')
    path.setAttribute('d', d)
    svg.appendChild(path)
  }
  return svg
}

function buildPanel(select: HTMLSelectElement): OpenMenu {
  const panel = document.createElement('div')
  panel.className = 'select-pop'
  panel.id = `select-pop-${++uid}`
  if (select.closest('.pos-root')) panel.classList.add('select-pop--pos')

  const label = labelFor(select)
  if (label) {
    const head = document.createElement('div')
    head.className = 'select-pop__head'
    const kicker = document.createElement('span')
    kicker.className = 'select-pop__kicker'
    kicker.textContent = label
    head.appendChild(kicker)
    panel.appendChild(head)
  }

  const options = Array.from(select.options).filter(option => !option.hidden)

  let search: HTMLInputElement | null = null
  if (options.length > SEARCH_THRESHOLD) {
    const wrap = document.createElement('div')
    wrap.className = 'select-pop__search'
    wrap.appendChild(icon(['M21 21l-4.3-4.3', 'M11 18a7 7 0 1 0 0-14 7 7 0 0 0 0 14z'], 'select-pop__search-icon'))
    search = document.createElement('input')
    search.type = 'search'
    search.className = 'select-pop__search-input'
    search.placeholder = t('selectMenu.search', 'Rechercher…')
    search.setAttribute('aria-label', search.placeholder)
    search.setAttribute('aria-controls', `${panel.id}-list`)
    search.autocomplete = 'off'
    search.spellcheck = false
    wrap.appendChild(search)
    panel.appendChild(wrap)
  }

  const list = document.createElement('div')
  list.className = 'select-pop__list'
  list.id = `${panel.id}-list`
  list.setAttribute('role', 'listbox')
  if (label) list.setAttribute('aria-label', label)

  const items: MenuItem[] = []
  let group: HTMLOptGroupElement | null = null
  for (const option of options) {
    const parent = option.parentElement instanceof HTMLOptGroupElement ? option.parentElement : null
    if (parent && parent !== group) {
      group = parent
      const heading = document.createElement('div')
      heading.className = 'select-pop__group'
      heading.setAttribute('role', 'presentation')
      heading.textContent = parent.label
      heading.dataset.group = parent.label
      list.appendChild(heading)
    }

    const text = (option.label || option.textContent || '').replace(/\s+/g, ' ').trim()
    const el = document.createElement('button')
    el.type = 'button'
    el.tabIndex = -1
    el.className = 'select-pop__option'
    el.id = `${panel.id}-opt-${items.length}`
    el.setAttribute('role', 'option')
    el.setAttribute('aria-selected', String(option.selected))
    if (option.selected) el.classList.add('select-pop__option--active')
    if (option.value === '') el.classList.add('select-pop__option--placeholder')
    const disabled = option.disabled || Boolean(parent?.disabled)
    if (disabled) {
      el.disabled = true
      el.setAttribute('aria-disabled', 'true')
    }

    const name = document.createElement('span')
    name.className = 'select-pop__name'
    name.textContent = text || '—'
    el.appendChild(name)
    el.appendChild(icon(['M20 6L9 17l-5-5'], 'select-pop__check'))

    const item: MenuItem = { option, el, text, key: normalize(text) }
    items.push(item)
    list.appendChild(el)
  }
  panel.appendChild(list)

  const empty = document.createElement('p')
  empty.className = 'select-pop__empty'
  empty.textContent = t('selectMenu.empty', 'Aucun résultat')
  empty.hidden = true
  panel.appendChild(empty)

  return {
    select,
    panel,
    list,
    search,
    empty,
    items,
    visible: items,
    active: Math.max(0, items.findIndex(item => item.option.selected)),
    watchdog: 0,
  }
}

function place(state: OpenMenu) {
  const { select, panel } = state
  const rect = select.getBoundingClientRect()
  const zoom = zoomFactor()
  const layoutWidth = window.innerWidth / zoom
  const layoutHeight = window.innerHeight / zoom

  const maxWidth = Math.min(Math.max(416, rect.width), layoutWidth - VIEWPORT_PAD * 2)
  panel.style.width = ''
  panel.style.minWidth = `${Math.min(Math.max(rect.width, 224), maxWidth)}px`
  panel.style.maxWidth = `${maxWidth}px`
  const width = panel.offsetWidth
  const left = Math.min(Math.max(VIEWPORT_PAD, rect.left), layoutWidth - width - VIEWPORT_PAD)
  panel.style.left = `${left}px`

  const below = layoutHeight - rect.bottom - PANEL_GAP - VIEWPORT_PAD
  const above = rect.top - PANEL_GAP - VIEWPORT_PAD
  const natural = Math.min(panel.scrollHeight, 352)
  const flip = below < Math.min(natural, 220) && above > below
  const room = Math.max(160, flip ? above : below)
  panel.style.maxHeight = `${Math.min(352, room)}px`
  panel.classList.toggle('select-pop--above', flip)
  if (flip) {
    panel.style.top = ''
    panel.style.bottom = `${layoutHeight - rect.top + PANEL_GAP}px`
  } else {
    panel.style.bottom = ''
    panel.style.top = `${rect.bottom + PANEL_GAP}px`
  }
}

function paintActive(state: OpenMenu, scroll = true) {
  state.items.forEach(item => item.el.classList.remove('select-pop__option--focus'))
  const item = state.visible[state.active]
  if (!item) {
    state.select.removeAttribute('aria-activedescendant')
    state.search?.removeAttribute('aria-activedescendant')
    return
  }
  item.el.classList.add('select-pop__option--focus')
  ;(state.search ?? state.select).setAttribute('aria-activedescendant', item.el.id)
  if (scroll) item.el.scrollIntoView({ block: 'nearest' })
}

function move(state: OpenMenu, step: number) {
  const count = state.visible.length
  if (!count) return
  let next = state.active
  for (let i = 0; i < count; i += 1) {
    next = (next + step + count) % count
    if (!state.visible[next]?.option.disabled) break
  }
  state.active = next
  paintActive(state)
}

function jump(state: OpenMenu, toEnd: boolean) {
  const order = toEnd ? [...state.visible].reverse() : state.visible
  const target = order.find(item => !item.option.disabled)
  if (!target) return
  state.active = state.visible.indexOf(target)
  paintActive(state)
}

function filter(state: OpenMenu) {
  const query = normalize(state.search?.value ?? '')
  state.visible = query ? state.items.filter(item => item.key.includes(query)) : state.items
  const shown = new Set(state.visible)
  for (const item of state.items) item.el.hidden = !shown.has(item)
  state.list.querySelectorAll<HTMLElement>('.select-pop__group').forEach((heading) => {
    heading.hidden = !state.visible.some(item => item.option.parentElement instanceof HTMLOptGroupElement
      && item.option.parentElement.label === heading.dataset.group)
  })
  state.empty.hidden = state.visible.length > 0
  const selected = state.visible.findIndex(item => item.option.selected)
  state.active = selected >= 0 && !query ? selected : Math.max(0, state.visible.findIndex(item => !item.option.disabled))
  paintActive(state)
}

function choose(state: OpenMenu, item: MenuItem) {
  if (item.option.disabled) return
  const { select } = state
  const changed = !item.option.selected
  item.option.selected = true
  close(true)
  if (changed) {
    select.dispatchEvent(new Event('input', { bubbles: true }))
    select.dispatchEvent(new Event('change', { bubbles: true }))
  }
}

function open(select: HTMLSelectElement) {
  if (menu?.select === select) return
  close(false)

  const state = buildPanel(select)
  menu = state
  document.body.appendChild(state.panel)

  select.setAttribute('aria-expanded', 'true')
  select.setAttribute('aria-controls', state.list.id)
  select.dataset.selectOpen = ''

  state.panel.addEventListener('mousedown', (event) => {
    if (event.target !== state.search) event.preventDefault()
  })
  state.list.addEventListener('click', (event) => {
    const button = (event.target as Element).closest<HTMLButtonElement>('.select-pop__option')
    const item = state.items.find(entry => entry.el === button)
    if (item) choose(state, item)
  })
  state.list.addEventListener('mousemove', (event) => {
    const button = (event.target as Element).closest<HTMLButtonElement>('.select-pop__option')
    const index = state.visible.findIndex(entry => entry.el === button)
    if (index >= 0 && index !== state.active) {
      state.active = index
      paintActive(state, false)
    }
  })
  state.search?.addEventListener('input', () => filter(state))

  place(state)
  paintActive(state)
  state.search?.focus({ preventScroll: true })

  state.watchdog = window.setInterval(() => {
    if (!select.isConnected || select.disabled) close(false)
  }, 300)
}

function close(restoreFocus: boolean) {
  const state = menu
  if (!state) return
  menu = null
  window.clearInterval(state.watchdog)
  const { select, panel } = state
  select.removeAttribute('aria-expanded')
  select.removeAttribute('aria-controls')
  select.removeAttribute('aria-activedescendant')
  delete select.dataset.selectOpen

  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches
  if (reduce) {
    panel.remove()
  } else {
    panel.classList.add('select-pop--leaving')
    window.setTimeout(() => panel.remove(), 120)
  }
  if (restoreFocus && select.isConnected) select.focus({ preventScroll: true })
}

function toggle(select: HTMLSelectElement) {
  if (menu?.select === select) close(true)
  else open(select)
}

function typeaheadTo(state: OpenMenu, char: string) {
  window.clearTimeout(typeaheadTimer)
  typeahead += normalize(char)
  typeaheadTimer = window.setTimeout(() => { typeahead = '' }, 600)
  const start = state.active + (typeahead.length === 1 ? 1 : 0)
  const ordered = [...state.visible.slice(start), ...state.visible.slice(0, start)]
  const hit = ordered.find(item => !item.option.disabled && item.key.startsWith(typeahead))
  if (!hit) return
  state.active = state.visible.indexOf(hit)
  paintActive(state)
}

function onMouseDown(event: MouseEvent) {
  if (event.button !== 0) return
  const target = event.target
  if (isEnhanced(target)) {
    event.preventDefault()
    target.focus({ preventScroll: true })
    toggle(target)
    return
  }
  if (menu && !menu.panel.contains(target as Node)) close(false)
}

function onTouchStart(event: TouchEvent) {
  const touch = event.touches[0]
  touchStart = touch ? { x: touch.clientX, y: touch.clientY, target: event.target } : null
  if (menu && !menu.panel.contains(event.target as Node) && event.target !== menu.select) close(false)
}

function onTouchEnd(event: TouchEvent) {
  const start = touchStart
  touchStart = null
  const target = event.target
  if (!start || start.target !== target || !isEnhanced(target)) return
  const touch = event.changedTouches[0]
  if (touch && Math.hypot(touch.clientX - start.x, touch.clientY - start.y) > 10) return
  event.preventDefault()
  target.focus({ preventScroll: true })
  toggle(target)
}

function onKeyDown(event: KeyboardEvent) {
  const state = menu
  if (!state) {
    const target = event.target
    if (!isEnhanced(target)) return
    const opens = event.key === 'Enter' || event.key === ' ' || event.key === 'F4'
      || ((event.key === 'ArrowDown' || event.key === 'ArrowUp') && (event.altKey || !event.ctrlKey))
    if (opens) {
      event.preventDefault()
      open(target)
    }
    return
  }

  const fromSearch = event.target === state.search
  switch (event.key) {
    case 'Escape':
      event.preventDefault()
      event.stopPropagation()
      close(true)
      return
    case 'Tab':
      close(false)
      return
    case 'ArrowDown':
      event.preventDefault()
      move(state, 1)
      return
    case 'ArrowUp':
      event.preventDefault()
      if (event.altKey) close(true)
      else move(state, -1)
      return
    case 'Home':
    case 'End':
      if (fromSearch) return
      event.preventDefault()
      jump(state, event.key === 'End')
      return
    case 'PageDown':
    case 'PageUp':
      event.preventDefault()
      for (let i = 0; i < 6; i += 1) move(state, event.key === 'PageDown' ? 1 : -1)
      return
    case 'Enter': {
      event.preventDefault()
      const item = state.visible[state.active]
      if (item) choose(state, item)
      return
    }
    case ' ':
      if (fromSearch) return
      event.preventDefault()
      if (state.visible[state.active]) choose(state, state.visible[state.active])
      return
    default:
      if (!fromSearch && event.key.length === 1 && !event.ctrlKey && !event.metaKey && !event.altKey) {
        event.preventDefault()
        if (state.search) {
          state.search.focus({ preventScroll: true })
          state.search.value += event.key
          filter(state)
        } else {
          typeaheadTo(state, event.key)
        }
      }
  }
}

function onViewportChange(event: Event) {
  const state = menu
  if (!state) return
  if (event.type === 'scroll' && state.panel.contains(event.target as Node)) return
  const rect = state.select.getBoundingClientRect()
  const zoom = zoomFactor()
  if (rect.bottom < 0 || rect.top > window.innerHeight / zoom) {
    close(false)
    return
  }
  place(state)
}

function onFocusIn(event: FocusEvent) {
  const state = menu
  if (!state) return
  const target = event.target as Node
  if (target === state.select || state.panel.contains(target)) return
  close(false)
}

export function installSelectMenu() {
  if (typeof document === 'undefined') return
  document.addEventListener('mousedown', onMouseDown, true)
  document.addEventListener('touchstart', onTouchStart, { capture: true, passive: true })
  document.addEventListener('touchend', onTouchEnd, { capture: true, passive: false })
  document.addEventListener('keydown', onKeyDown, true)
  document.addEventListener('focusin', onFocusIn, true)
  window.addEventListener('scroll', onViewportChange, true)
  window.addEventListener('resize', onViewportChange)
}
