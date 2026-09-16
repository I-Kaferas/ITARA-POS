import { onBeforeUnmount, watch, type WatchSource } from 'vue'

export function debounceFn(fn: () => unknown, ms = 280) {
  let timer: ReturnType<typeof setTimeout> | undefined
  const wrapped = () => {
    if (timer) clearTimeout(timer)
    if (ms <= 0) {
      fn()
      return
    }
    timer = setTimeout(() => {
      timer = undefined
      fn()
    }, ms)
  }
  wrapped.cancel = () => {
    if (timer) clearTimeout(timer)
    timer = undefined
  }
  return wrapped
}

export function watchLiveSearch(source: WatchSource, run: () => unknown, delay = 280) {
  const debounced = debounceFn(run, delay)
  const stop = watch(source, () => { void debounced() })
  onBeforeUnmount(() => {
    debounced.cancel()
    stop()
  })
  return debounced
}
