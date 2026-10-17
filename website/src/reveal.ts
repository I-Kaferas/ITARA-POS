/** Lightweight scroll-reveal for marketing sections. */
export function initReveal(root: ParentNode = document) {
  const nodes = root.querySelectorAll<HTMLElement>('[data-reveal]')
  if (!nodes.length) return () => undefined

  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches
  if (reduce) {
    nodes.forEach((el) => el.classList.add('is-revealed'))
    return () => undefined
  }

  const observer = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (!entry.isIntersecting) continue
        entry.target.classList.add('is-revealed')
        observer.unobserve(entry.target)
      }
    },
    { threshold: 0.12, rootMargin: '0px 0px -8% 0px' },
  )

  nodes.forEach((el) => observer.observe(el))
  return () => observer.disconnect()
}
