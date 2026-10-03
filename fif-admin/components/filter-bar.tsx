'use client'

import { useRouter, useSearchParams } from 'next/navigation'
import { Select } from '@/components/ui/input'
import { humanise } from '@/lib/format'

/**
 * Dropdown filters that write to the URL.
 *
 * Options come from the data rather than a hardcoded list, so a plan or a
 * provider added upstream appears here without anyone editing this panel — and
 * a filter can never offer a value that matches nothing.
 */
export function FilterBar({
  filters,
}: {
  filters: Array<{
    param: string
    label: string
    options: Array<string | { value: string; label: string }>
    current?: string
    allLabel?: string
  }>
}) {
  const router = useRouter()
  const params = useSearchParams()

  function set(param: string, value: string) {
    const next = new URLSearchParams(params.toString())
    if (value) next.set(param, value)
    else next.delete(param)
    next.delete('page')
    router.push(`?${next.toString()}`)
  }

  const active = filters.some((f) => f.current)

  return (
    <div className="mb-2 flex flex-wrap items-center gap-1.5">
      {filters.map((filter) => (
        <label
          key={filter.param}
          className="flex items-center gap-1.5 text-[11px] text-muted-foreground"
        >
          {filter.label}
          <Select value={filter.current ?? ''} onChange={(e) => set(filter.param, e.target.value)}>
            <option value="">{filter.allLabel ?? 'All'}</option>
            {filter.options.map((option) => {
              const value = typeof option === 'string' ? option : option.value
              const label = typeof option === 'string' ? humanise(option) : option.label
              return (
                <option key={value} value={value}>
                  {label}
                </option>
              )
            })}
          </Select>
        </label>
      ))}
      {active ? (
        <button
          type="button"
          onClick={() => router.push('?')}
          className="rounded border border-border px-2 py-1 text-[11px] text-muted-foreground transition-colors hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
        >
          Clear
        </button>
      ) : null}
    </div>
  )
}
