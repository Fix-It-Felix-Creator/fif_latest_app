import { requirePermission } from '@/lib/auth'
import { can } from '@/lib/roles'
import { countRows, countSince, distinctValues, listTable, namesFor, PAGE_SIZE } from '@/lib/queries'
import { PageHeader } from '@/components/page-header'
import { Stat } from '@/components/ui/stat'
import { Badge, statusTone } from '@/components/ui/badge'
import { Table, TableWrap, TBody, TD, TH, THead, TR, Empty } from '@/components/ui/table'
import { SearchBox } from '@/components/search-box'
import { FilterBar } from '@/components/filter-bar'
import { Pager } from '@/components/pager'
import { OwnerLink } from '@/components/owner-link'
import { fmtAgo, fmtDateTime, fmtNum, humanise, pct } from '@/lib/format'
import { Composer } from './composer'
import { broadcastReach } from './actions'

export const metadata = { title: 'Notifications · Fix It Felix Admin' }
export const dynamic = 'force-dynamic'

export default async function NotificationsPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; type?: string; read?: string; page?: string }>
}) {
  const admin = await requirePermission('sendNotification')
  const params = await searchParams
  const page = Number(params.page ?? '1') || 1

  const week = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)

  const [{ rows, total }, types, all, unread, lastWeek, reach] = await Promise.all([
    listTable({
      table: 'notifications',
      orderBy: 'created_at',
      page,
      filters: {
        type: params.type,
        ...(params.read === 'yes' ? { read: 'true' } : params.read === 'no' ? { read: 'false' } : {}),
      },
      searchColumns: ['title', 'body'],
      q: params.q,
    }),
    distinctValues('notifications', 'type'),
    countRows('notifications'),
    countRows('notifications', { read: 'false' }),
    countSince('notifications', 'created_at', week),
    broadcastReach(),
  ])

  const owners = await namesFor(rows.map((r) => r.owner_id as string))

  return (
    <>
      <PageHeader
        title="Notifications"
        subtitle="Everything ever delivered to an inbox, and the box that sends more."
        actions={<SearchBox placeholder="Title or body…" />}
      />

      <div className="mb-2 grid grid-cols-2 gap-2 sm:grid-cols-4">
        <Stat label="Delivered" value={fmtNum(all)} hint="All time, both apps" />
        <Stat label="Last 7 days" value={fmtNum(lastWeek)} />
        <Stat
          label="Unread"
          value={fmtNum(unread)}
          hint={`${pct(unread, all)}% of everything sent`}
        />
        <Stat
          label="Reachable by push"
          value={fmtNum(reach.tokens)}
          hint={`${fmtNum(reach.profiles)} accounts`}
        />
      </div>

      <div className="mb-2">
        <Composer
          canBroadcast={can(admin.role, 'broadcastNotification')}
          reach={reach}
          types={types}
        />
      </div>

      <FilterBar
        filters={[
          { param: 'type', label: 'Type', options: types, current: params.type },
          {
            param: 'read',
            label: 'Read',
            current: params.read,
            options: [
              { value: 'yes', label: 'Read' },
              { value: 'no', label: 'Unread' },
            ],
          },
        ]}
      />

      <TableWrap>
        <Table>
          <THead>
            <TR>
              <TH>Recipient</TH>
              <TH>Title</TH>
              <TH>Body</TH>
              <TH>Type</TH>
              <TH>Read</TH>
              <TH className="text-right">Sent</TH>
            </TR>
          </THead>
          <TBody>
            {rows.length === 0 ? (
              <Empty colSpan={6}>Nothing matches that.</Empty>
            ) : (
              rows.map((n) => (
                <TR key={n.id as string}>
                  <TD>
                    <OwnerLink id={n.owner_id as string} owner={owners.get(n.owner_id as string)} />
                  </TD>
                  <TD className="max-w-[16rem] truncate font-medium">{(n.title as string) || '—'}</TD>
                  <TD className="max-w-[24rem] truncate text-muted-foreground" title={n.body as string}>
                    {(n.body as string) || '—'}
                  </TD>
                  <TD>
                    <Badge tone={statusTone(n.type as string)}>{humanise(n.type)}</Badge>
                  </TD>
                  <TD>
                    {n.read ? (
                      <Badge tone="success">{fmtAgo(n.read_at as string)}</Badge>
                    ) : (
                      <Badge tone="muted">Unread</Badge>
                    )}
                  </TD>
                  <TD className="whitespace-nowrap text-right text-muted-foreground">
                    {fmtDateTime(n.created_at as string)}
                  </TD>
                </TR>
              ))
            )}
          </TBody>
        </Table>
      </TableWrap>

      <Pager
        page={page}
        pageSize={PAGE_SIZE}
        total={total}
        params={{ q: params.q, type: params.type, read: params.read }}
      />
    </>
  )
}
