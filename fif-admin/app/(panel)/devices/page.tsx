import { requirePermission } from '@/lib/auth'
import { countRows, distinctValues, listTable, namesFor, PAGE_SIZE } from '@/lib/queries'
import { PageHeader } from '@/components/page-header'
import { Tabs } from '@/components/tabs'
import { Stat } from '@/components/ui/stat'
import { Badge, statusTone } from '@/components/ui/badge'
import { Table, TableWrap, TBody, TD, TH, THead, TR, Empty } from '@/components/ui/table'
import { FilterBar } from '@/components/filter-bar'
import { SearchBox } from '@/components/search-box'
import { Pager } from '@/components/pager'
import { OwnerLink } from '@/components/owner-link'
import { fmtAgo, fmtDateTime, fmtNum, humanise } from '@/lib/format'

export const metadata = { title: 'Devices · Fix It Felix Admin' }
export const dynamic = 'force-dynamic'

/**
 * What the apps are installed on.
 *
 * Two tabs over two tables that answer different questions: a device is a
 * phone someone owns, a session is a time they signed in. A support call about
 * "it logged me out" is a session question; one about "the update never
 * arrived" is a device question, because the app version lives there.
 */
export default async function DevicesPage({
  searchParams,
}: {
  searchParams: Promise<{
    tab?: string
    q?: string
    platform?: string
    version?: string
    page?: string
  }>
}) {
  await requirePermission('viewDevices')
  const params = await searchParams
  const tab = params.tab === 'sessions' ? 'sessions' : 'devices'
  const page = Number(params.page ?? '1') || 1

  const [deviceCount, sessionCount, activeSessions, tokenCount, platforms, versions] =
    await Promise.all([
      countRows('user_devices'),
      countRows('user_sessions'),
      countRows('user_sessions', { status: 'active' }),
      countRows('fcm_tokens'),
      distinctValues('user_devices', 'platform'),
      distinctValues('user_devices', 'app_version'),
    ])

  const { rows, total } = await listTable({
    table: tab === 'devices' ? 'user_devices' : 'user_sessions',
    orderBy: tab === 'devices' ? 'last_active_at' : 'last_activity_at',
    page,
    filters: {
      platform: params.platform,
      app_version: tab === 'devices' ? params.version : undefined,
    },
    searchColumns:
      tab === 'devices'
        ? ['device_model', 'manufacturer', 'device_id', 'os_version']
        : ['device_model', 'ip_address', 'session_id', 'login_method'],
    q: params.q,
  })

  const owners = await namesFor(rows.map((r) => r.owner_id as string))

  return (
    <>
      <PageHeader
        title="Devices"
        subtitle="Phones both apps are installed on, and the sessions signed in from them."
        actions={<SearchBox placeholder={tab === 'devices' ? 'Model, make, OS…' : 'Device, IP…'} />}
      />

      <div className="mb-2 grid grid-cols-2 gap-2 sm:grid-cols-4">
        <Stat label="Devices" value={fmtNum(deviceCount)} />
        <Stat label="Sessions" value={fmtNum(sessionCount)} />
        <Stat label="Signed in now" value={fmtNum(activeSessions)} tone="success" />
        <Stat label="Push tokens" value={fmtNum(tokenCount)} />
      </div>

      <Tabs
        basePath="/devices"
        current={tab}
        param="tab"
        tabs={[
          { key: 'devices', label: 'Devices', count: deviceCount },
          { key: 'sessions', label: 'Sessions', count: sessionCount },
        ]}
      />

      <FilterBar
        filters={[
          { param: 'platform', label: 'Platform', options: platforms, current: params.platform },
          ...(tab === 'devices'
            ? [{ param: 'version', label: 'App version', options: versions, current: params.version }]
            : []),
        ]}
      />

      <TableWrap>
        <Table>
          <THead>
            {tab === 'devices' ? (
              <TR>
                <TH>Account</TH>
                <TH>Device</TH>
                <TH>Platform</TH>
                <TH>OS</TH>
                <TH>App</TH>
                <TH>Build</TH>
                <TH>Locale</TH>
                <TH>Real</TH>
                <TH>Active</TH>
                <TH className="text-right">Last seen</TH>
              </TR>
            ) : (
              <TR>
                <TH>Account</TH>
                <TH>Status</TH>
                <TH>Signed in with</TH>
                <TH>Device</TH>
                <TH>Platform</TH>
                <TH>App</TH>
                <TH>IP</TH>
                <TH className="text-right">Started</TH>
                <TH className="text-right">Last activity</TH>
                <TH className="text-right">Ended</TH>
              </TR>
            )}
          </THead>
          <TBody>
            {rows.length === 0 ? (
              <Empty colSpan={10}>Nothing matches that.</Empty>
            ) : (
              rows.map((r, i) =>
                tab === 'devices' ? (
                  <TR key={`${r.owner_id}-${r.device_id}`}>
                    <TD>
                      <OwnerLink id={r.owner_id as string} owner={owners.get(r.owner_id as string)} />
                    </TD>
                    <TD className="max-w-[12rem] truncate">{(r.device_model as string) || '—'}</TD>
                    <TD>
                      <Badge tone={statusTone(r.platform as string)}>{humanise(r.platform)}</Badge>
                    </TD>
                    <TD className="text-muted-foreground">{(r.os_version as string) || '—'}</TD>
                    <TD className="tabular">{(r.app_version as string) || '—'}</TD>
                    <TD className="tabular text-muted-foreground">
                      {(r.build_number as string) || '—'}
                    </TD>
                    <TD className="text-muted-foreground">{(r.locale as string) || '—'}</TD>
                    <TD className="text-muted-foreground">
                      {r.is_physical_device ? 'Yes' : 'Simulator'}
                    </TD>
                    <TD>
                      {r.is_active ? <Badge tone="success">Yes</Badge> : <Badge tone="muted">No</Badge>}
                    </TD>
                    <TD className="whitespace-nowrap text-right text-muted-foreground">
                      {fmtAgo(r.last_active_at as string)}
                    </TD>
                  </TR>
                ) : (
                  <TR key={(r.id as string) ?? i}>
                    <TD>
                      <OwnerLink id={r.owner_id as string} owner={owners.get(r.owner_id as string)} />
                    </TD>
                    <TD>
                      <Badge tone={statusTone(r.status as string)}>{humanise(r.status)}</Badge>
                    </TD>
                    <TD className="text-muted-foreground">{humanise(r.login_method)}</TD>
                    <TD className="max-w-[11rem] truncate">{(r.device_model as string) || '—'}</TD>
                    <TD className="text-muted-foreground">{humanise(r.platform)}</TD>
                    <TD className="tabular">{(r.app_version as string) || '—'}</TD>
                    <TD className="tabular text-muted-foreground">
                      {(r.ip_address as string) || '—'}
                    </TD>
                    <TD className="whitespace-nowrap text-right text-muted-foreground">
                      {fmtDateTime(r.login_at as string)}
                    </TD>
                    <TD className="whitespace-nowrap text-right text-muted-foreground">
                      {fmtAgo(r.last_activity_at as string)}
                    </TD>
                    <TD className="whitespace-nowrap text-right text-muted-foreground">
                      {fmtAgo(r.logout_at as string)}
                    </TD>
                  </TR>
                ),
              )
            )}
          </TBody>
        </Table>
      </TableWrap>

      <Pager
        page={page}
        pageSize={PAGE_SIZE}
        total={total}
        params={{ tab, q: params.q, platform: params.platform, version: params.version }}
      />
    </>
  )
}
