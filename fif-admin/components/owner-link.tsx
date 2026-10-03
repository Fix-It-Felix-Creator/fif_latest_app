import Link from 'next/link'
import { initials, shortId } from '@/lib/format'
import { cn } from '@/lib/utils'

export type OwnerInfo = { name: string | null; email: string | null; account_type: string }

/**
 * The route to a person, given only the uuid a row carries.
 *
 * The two people pages hold different columns because the two products are
 * different, so a link has to know which one it is going to. `account_type` is
 * the only thing that answers that, which is why namesFor() carries it.
 */
export function ownerHref(id: string, accountType: string | undefined): string {
  return accountType === 'customer' ? `/customers/${id}` : `/tradespeople/${id}`
}

/**
 * A uuid, rendered as the person it belongs to.
 *
 * Falls back to the shortened id rather than to nothing: a row whose owner has
 * been deleted still has to be identifiable, and "—" in the owner column of an
 * invoice ledger hides exactly the case worth looking at.
 */
export function OwnerLink({
  id,
  owner,
  className,
  showAvatar = true,
}: {
  id: string | null | undefined
  owner?: OwnerInfo
  className?: string
  showAvatar?: boolean
}) {
  if (!id) return <span className="text-muted-foreground">—</span>

  const label = owner?.name || owner?.email || shortId(id)

  return (
    <Link
      href={ownerHref(id, owner?.account_type)}
      className={cn('group flex items-center gap-2', className)}
    >
      {showAvatar ? (
        <span className="flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-secondary text-[9px] font-semibold">
          {initials(owner?.name, owner?.email ?? id)}
        </span>
      ) : null}
      <span
        className={cn(
          'max-w-[11rem] truncate group-hover:text-primary group-hover:underline',
          owner ? 'font-medium' : 'tabular text-muted-foreground',
        )}
        title={owner?.email ?? id}
      >
        {label}
      </span>
    </Link>
  )
}
