'use client'

import { X } from 'lucide-react'
import { useEffect, useRef, useState } from 'react'
import { createPortal } from 'react-dom'
import { cn } from '@/lib/utils'

/**
 * A panel that slides in from the right.
 *
 * Portalled to <body> rather than rendered in place. The things that open one
 * of these live inside a CSS grid of cards, and a fixed element inside a grid
 * cell is still laid out against that cell's stacking context — so an in-place
 * drawer gets clipped by the card it came from.
 *
 * Deliberately not a modal in the "you must finish this" sense: the backdrop
 * and Escape both close it, because an editor that traps you until you press
 * the right button is worse than one you can dismiss. Unsaved work is guarded
 * by `onRequestClose` instead, which is where the caller asks.
 */
export function SidePanel({
  open,
  title,
  subtitle,
  onRequestClose,
  footer,
  children,
  width = 'md',
}: {
  open: boolean
  title: string
  subtitle?: React.ReactNode
  /** Return false to refuse the close — used to guard unsaved changes. */
  onRequestClose: () => boolean | void
  footer?: React.ReactNode
  children: React.ReactNode
  width?: 'md' | 'lg'
}) {
  // Portals need a DOM, and this component renders on the server first.
  const [mounted, setMounted] = useState(false)
  useEffect(() => setMounted(true), [])

  const panelRef = useRef<HTMLDivElement>(null)
  const restoreFocusTo = useRef<HTMLElement | null>(null)

  // The close handler, held in a ref so the effect below does not depend on
  // its identity. Callers build it inline, so it is a new function on every
  // render — and this effect moves focus, so depending on it meant every
  // keystroke in the panel tore the effect down (pulling focus back to the
  // button that opened it) and set it up again. Typing one character worked;
  // typing two did not.
  const closeRef = useRef(onRequestClose)
  closeRef.current = onRequestClose

  useEffect(() => {
    if (!open) return

    restoreFocusTo.current = document.activeElement as HTMLElement | null
    // Focus the panel itself rather than its first field: dropping the caret
    // straight into a text input means a stray keystroke edits a price.
    panelRef.current?.focus()

    function onKeyDown(event: KeyboardEvent) {
      if (event.key === 'Escape') {
        event.stopPropagation()
        closeRef.current()
      }
    }
    document.addEventListener('keydown', onKeyDown)

    // Stop the page behind scrolling while the panel has the reader's
    // attention — otherwise a scroll gesture near the edge moves the table
    // under the panel and loses their place.
    const previousOverflow = document.body.style.overflow
    document.body.style.overflow = 'hidden'

    return () => {
      document.removeEventListener('keydown', onKeyDown)
      document.body.style.overflow = previousOverflow
      restoreFocusTo.current?.focus?.()
    }
    // `open` only. See closeRef above.
  }, [open])

  if (!mounted || !open) return null

  return createPortal(
    <div className="fixed inset-0 z-50 flex justify-end">
      {/* A scrim rather than a drop shadow: the design has no shadows, and
          something has to say the page behind is not the thing being read. */}
      <button
        type="button"
        aria-label="Close panel"
        onClick={() => onRequestClose()}
        className="absolute inset-0 bg-background/70 backdrop-blur-[1px]"
      />

      <div
        ref={panelRef}
        role="dialog"
        aria-modal="true"
        aria-label={title}
        tabIndex={-1}
        className={cn(
          'relative flex h-full flex-col border-l border-border bg-card outline-none',
          'w-full',
          width === 'lg' ? 'sm:w-[40rem]' : 'sm:w-[32rem]',
        )}
      >
        <header className="flex shrink-0 items-start justify-between gap-3 border-b border-border px-3 py-2">
          <div className="min-w-0">
            <h2 className="truncate text-xs font-semibold">{title}</h2>
            {subtitle ? (
              <p className="mt-0.5 text-[11px] text-muted-foreground">{subtitle}</p>
            ) : null}
          </div>
          <button
            type="button"
            onClick={() => onRequestClose()}
            className="shrink-0 rounded-md p-1 text-muted-foreground transition-colors hover:bg-accent hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
          >
            <X className="h-3.5 w-3.5" />
            <span className="sr-only">Close</span>
          </button>
        </header>

        <div className="scroll-thin min-h-0 flex-1 overflow-y-auto px-3 py-3">{children}</div>

        {footer ? (
          // Sticky rather than scrolled away: the form is long enough that Save
          // would otherwise be below the fold on every plan.
          <footer className="shrink-0 border-t border-border px-3 py-2">{footer}</footer>
        ) : null}
      </div>
    </div>,
    document.body,
  )
}
