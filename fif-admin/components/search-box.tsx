'use client'

import { useRouter, useSearchParams } from 'next/navigation'
import { useState } from 'react'
import { Input } from '@/components/ui/input'

/**
 * Search that writes to the URL rather than filtering in the browser.
 *
 * The tables here page over thousands of rows, so filtering client-side would
 * only ever filter the page you can already see. Submitting means the server
 * runs the query — and the result is a link someone can send.
 */
export function SearchBox({
  placeholder = 'Search…',
  param = 'q',
  className,
}: {
  placeholder?: string
  param?: string
  className?: string
}) {
  const router = useRouter()
  const params = useSearchParams()
  const [value, setValue] = useState(params.get(param) ?? '')

  function submit(event: React.FormEvent) {
    event.preventDefault()
    const next = new URLSearchParams(params.toString())
    if (value.trim()) next.set(param, value.trim())
    else next.delete(param)
    next.delete('page') // a new search starts at the first page, not page 7
    router.push(`?${next.toString()}`)
  }

  return (
    <form onSubmit={submit} className={className}>
      <Input
        type="search"
        name={param}
        value={value}
        onChange={(e) => setValue(e.target.value)}
        placeholder={placeholder}
        className="w-60"
        aria-label={placeholder}
      />
    </form>
  )
}
