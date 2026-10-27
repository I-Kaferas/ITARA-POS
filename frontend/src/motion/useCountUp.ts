import { onUnmounted, ref, watch, type Ref } from 'vue'
import { easeStandard, motion } from './tokens'
import { useReducedMotion } from './useReducedMotion'

/**
 * Animates toward `target`. The first run lasts 1.2s from zero.
 * Later changes ease from the current value in at most 400ms.
 */
export function useCountUp(target: Ref<number>, duration: number = motion.duration.kpi) {
  const displayed = ref(0)
  const reduced = useReducedMotion()
  let frame = 0
  let first = true

  function stop() {
    cancelAnimationFrame(frame)
  }

  function run() {
    stop()
    const next = Number(target.value) || 0
    if (reduced.value) {
      displayed.value = next
      first = false
      return
    }
    const from = first ? 0 : displayed.value
    const span = first ? duration : Math.min(motion.duration.kpiUpdate, duration)
    const started = performance.now()
    first = false

    const tick = (now: number) => {
      const progress = Math.min(1, (now - started) / span)
      displayed.value = from + ((next - from) * easeStandard(progress))
      if (progress < 1) frame = requestAnimationFrame(tick)
      else displayed.value = next
    }
    frame = requestAnimationFrame(tick)
  }

  watch(target, run, { immediate: true })
  watch(reduced, run)
  onUnmounted(stop)

  return displayed
}
