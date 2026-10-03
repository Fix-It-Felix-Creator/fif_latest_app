import { ownerRows } from '@/lib/queries'
import { Card, CardBody, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { RowTable } from '@/components/row-table'
import { fmtAgo, fmtDate, fmtDateTime, humanise } from '@/lib/format'

/**
 * The two tabs both people pages share.
 *
 * Devices and notifications are the same question for a tradesperson and for
 * a customer — what is this account signed in on, and what have we sent it —
 * so they are one implementation rather than two that drift. Everything else
 * about the two pages differs, which is why only these two live here.
 */

export async function DevicesTab({ ownerId }: { ownerId: string }) {
  const [devices, sessions, tokens] = await Promise.all([
    ownerRows('user_devices', ownerId, 'last_active_at', 100),
    ownerRows('user_sessions', ownerId, 'last_activity_at', 100),
    ownerRows('fcm_tokens', ownerId, 'last_seen_at', 100),
  ])

  return (
    <div className="space-y-2">
      <Card>
        <CardHeader>
          <CardTitle>Devices</CardTitle>
        </CardHeader>
        <CardBody className="px-0 pb-0">
          <RowTable
            rows={devices}
            empty="No devices recorded."
            hideKeys={['owner_id']}
            columns={[
              { key: 'device_model', label: 'Device' },
              { key: 'manufacturer', label: 'Make' },
              { key: 'platform', label: 'Platform', badge: true },
              { key: 'os_version', label: 'OS' },
              { key: 'app_version', label: 'App' },
              { key: 'build_number', label: 'Build' },
              { key: 'locale', label: 'Locale' },
              { key: 'is_physical_device', label: 'Real device' },
              { key: 'is_active', label: 'Active' },
              {
                key: 'last_active_at',
                label: 'Last seen',
                align: 'right',
                render: (v) => fmtAgo(v as string),
              },
            ]}
          />
        </CardBody>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Sessions</CardTitle>
        </CardHeader>
        <CardBody className="px-0 pb-0">
          <RowTable
            rows={sessions}
            empty="No sessions recorded."
            expandKey="login_location"
            columns={[
              { key: 'status', label: 'Status', badge: true },
              { key: 'login_method', label: 'Signed in with', render: (v) => humanise(v) },
              { key: 'platform', label: 'Platform' },
              { key: 'device_model', label: 'Device' },
              { key: 'app_version', label: 'App' },
              { key: 'ip_address', label: 'IP' },
              { key: 'login_at', label: 'Started', render: (v) => fmtDateTime(v as string) },
              {
                key: 'last_activity_at',
                label: 'Last activity',
                align: 'right',
                render: (v) => fmtAgo(v as string),
              },
              { key: 'logout_at', label: 'Ended', align: 'right', render: (v) => fmtAgo(v as string) },
            ]}
          />
        </CardBody>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Push tokens</CardTitle>
          <span className="text-[10px] text-muted-foreground">
            A push reaches this account once per token
          </span>
        </CardHeader>
        <CardBody className="px-0 pb-0">
          <RowTable
            rows={tokens}
            empty="No push tokens — this account cannot receive a push notification at all."
            hideKeys={['owner_id']}
            columns={[
              { key: 'platform', label: 'Platform', badge: true },
              { key: 'device_id', label: 'Device' },
              {
                key: 'token',
                label: 'Token',
                render: (v) => <span className="tabular">{String(v).slice(0, 24)}…</span>,
              },
              {
                key: 'last_seen_at',
                label: 'Last seen',
                align: 'right',
                render: (v) => fmtAgo(v as string),
              },
              {
                key: 'created_at',
                label: 'Registered',
                align: 'right',
                render: (v) => fmtDate(v as string),
              },
            ]}
          />
        </CardBody>
      </Card>
    </div>
  )
}

export async function NotificationsTab({ ownerId }: { ownerId: string }) {
  const rows = await ownerRows('notifications', ownerId, 'created_at', 200)
  return (
    <RowTable
      rows={rows}
      empty="Nothing has been sent to this account."
      expandKey="payload"
      columns={[
        { key: 'title', label: 'Title' },
        { key: 'body', label: 'Body' },
        { key: 'type', label: 'Type', badge: true },
        {
          key: 'read',
          label: 'Read',
          render: (v, row) =>
            v ? (
              <Badge tone="success">Read {fmtAgo(row.read_at as string)}</Badge>
            ) : (
              <Badge tone="muted">Unread</Badge>
            ),
        },
        { key: 'created_at', label: 'Sent', align: 'right', render: (v) => fmtDateTime(v as string) },
      ]}
    />
  )
}

/**
 * The jobs this customer posted.
 *
 * `Pin` is the column worth having here: a request with no coordinates is
 * never returned by a distance search, so it looks posted and reaches nobody.
 * That is the answer to the commonest support question this page will get.
 */
export async function JobRequestsTab({ customerId }: { customerId: string }) {
  const rows = await ownerRows('job_requests', customerId, 'created_at', 200, 'customer_id')
  return (
    <RowTable
      rows={rows}
      empty="This customer has not posted a job."
      expandKey="selections"
      columns={[
        { key: 'service_name', label: 'Service' },
        { key: 'formatted_address', label: 'Where' },
        {
          key: 'latitude',
          label: 'Pin',
          render: (v, row) => {
            const open = row.status !== 'completed' && row.status !== 'cancelled'
            if (v !== null && v !== undefined) return <Badge tone="muted">On the map</Badge>
            return <Badge tone={open ? 'danger' : 'muted'}>Missing</Badge>
          },
        },
        { key: 'urgency', label: 'Urgency', badge: true },
        { key: 'status', label: 'Status', badge: true },
        {
          key: 'created_at',
          label: 'Posted',
          align: 'right',
          render: (v) => fmtDateTime(v as string),
        },
      ]}
    />
  )
}
