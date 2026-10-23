/**
 * Motion tokens for the ERP.
 * Durations stay short on frequent actions. Charts and KPI count-up
 * are entrance-only, so they may run longer.
 * CSS variables are applied once at startup so stylesheets stay in sync.
 */
export const motion = {
  duration: {
    micro: 150,
    fast: 180,
    panel: 260,
    page: 300,
    chart: 600,
    kpi: 1200,
    /** Later KPI updates must not replay the full entrance. */
    kpiUpdate: 400,
  },
  stagger: 60,
  distance: {
    slide: 12,
    lift: 4,
  },
  easing: {
    standard: [0.22, 1, 0.36, 1] as const,
    spring: [0.34, 1.4, 0.64, 1] as const,
  },
} as const

const [x1, y1, x2, y2] = motion.easing.standard

function bezier(t: number, p1: number, p2: number) {
  const u = 1 - t
  return (3 * u * u * t * p1) + (3 * u * t * t * p2) + (t * t * t)
}

function bezierSlope(t: number, p1: number, p2: number) {
  const u = 1 - t
  return (3 * u * u * p1) + (6 * u * t * (p2 - p1)) + (3 * t * t * (1 - p2))
}

/** Sample of cubic-bezier(0.22, 1, 0.36, 1) for scripted motion. */
export function easeStandard(progress: number) {
  const x = Math.min(1, Math.max(0, progress))
  let t = x
  for (let i = 0; i < 6; i += 1) {
    const estimate = bezier(t, x1, x2)
    const slope = bezierSlope(t, x1, x2)
    if (Math.abs(slope) < 1e-4) break
    t = Math.min(1, Math.max(0, t - ((estimate - x) / slope)))
  }
  return bezier(t, y1, y2)
}

export function applyMotionTokens(root: HTMLElement = document.documentElement) {
  const { duration, stagger, distance, easing } = motion
  const standard = `cubic-bezier(${easing.standard.join(', ')})`
  root.style.setProperty('--motion-micro', `${duration.micro}ms`)
  root.style.setProperty('--motion-fast', `${duration.fast}ms`)
  root.style.setProperty('--motion-normal', `${duration.panel}ms`)
  root.style.setProperty('--motion-panel', `${duration.panel}ms`)
  root.style.setProperty('--motion-page', `${duration.page}ms`)
  root.style.setProperty('--motion-chart', `${duration.chart}ms`)
  root.style.setProperty('--motion-kpi', `${duration.kpi}ms`)
  root.style.setProperty('--motion-stagger', `${stagger}ms`)
  root.style.setProperty('--motion-slide', `${distance.slide}px`)
  root.style.setProperty('--motion-lift', `${distance.lift}px`)
  root.style.setProperty('--ease-out', standard)
}
