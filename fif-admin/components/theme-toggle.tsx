'use client'

import { Monitor, Moon, Sun } from 'lucide-react'
import { useEffect, useState } from 'react'
import { THEME_KEY, type Theme } from '@/lib/theme'
import { cn } from '@/lib/utils'

const OPTIONS: Array<{ value: Theme; label: string; Icon: typeof Sun }> = [
  { value: 'light', label: 'Light', Icon: Sun },
  { value: 'dark', label: 'Dark', Icon: Moon },
  { value: 'system', label: 'Follow system', Icon: Monitor },
]

/**
 * Three states, not two.
 *
 * A plain light/dark switch forces a choice the moment you touch it and gives
 * no way back to "whatever my machine is doing" — which is the setting most
 * people are actually on, and the one that follows them into the evening. So
 * system is a first-class option rather than just the initial value.
 */
export function ThemeToggle() {
  const [theme, setTheme] = useState<Theme>('system')

  // The inline head script already applied the theme; this only syncs the
  // control's own highlight once React is running. Reading in an effect rather
  // than in useState's initialiser keeps the server and the first client
  // render identical, which is what a hydration mismatch is.
  useEffect(() => {
    try {
      const stored = localStorage.getItem(THEME_KEY)
      if (stored === 'light' || stored === 'dark') setTheme(stored)
    } catch {
      // Storage unavailable — the control just starts on "system".
    }
  }, [])

  function choose(next: Theme) {
    setTheme(next)
    const root = document.documentElement
    if (next === 'system') root.removeAttribute('data-theme')
    else root.setAttribute('data-theme', next)
    try {
      if (next === 'system') localStorage.removeItem(THEME_KEY)
      else localStorage.setItem(THEME_KEY, next)
    } catch {
      // The theme still applies for this tab; it just will not be remembered.
    }
  }

  return (
    <div
      role="radiogroup"
      aria-label="Colour theme"
      className="flex items-center gap-px rounded-md border border-border p-px"
    >
      {OPTIONS.map(({ value, label, Icon }) => {
        const active = theme === value
        return (
          <button
            key={value}
            type="button"
            role="radio"
            aria-checked={active}
            title={label}
            onClick={() => choose(value)}
            className={cn(
              'flex h-5 w-6 items-center justify-center rounded-sm transition-colors',
              'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring',
              active ? 'bg-primary/15 text-primary' : 'text-muted-foreground hover:text-foreground',
            )}
          >
            <Icon className="h-3 w-3" />
            <span className="sr-only">{label}</span>
          </button>
        )
      })}
    </div>
  )
}
