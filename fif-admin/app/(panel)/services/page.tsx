import { requirePermission } from '@/lib/auth'
import { can } from '@/lib/roles'
import { supabaseAdmin } from '@/lib/supabase/server'
import { PageHeader } from '@/components/page-header'
import { Stat } from '@/components/ui/stat'
import { Card, CardBody, CardHeader, CardTitle } from '@/components/ui/card'
import { ServiceEditor, type ServiceRow } from './editor'
import { countTree } from './flow'
import { fmtNum } from '@/lib/format'

export const metadata = { title: 'Services · Fix It Felix Admin' }
export const dynamic = 'force-dynamic'

type Group = { id: string; name: string; sort_order: number }

/**
 * The trade catalogue, and the questions each trade asks.
 *
 * Two things a super admin edits here. The catalogue entry is what a customer
 * sees on a tile — name, blurb, artwork. The flow underneath it is the nested
 * set of questions that turns "I need a plumber" into "install a new combi
 * boiler", which is the difference between a lead a tradesperson can quote and
 * one they have to ring up about.
 *
 * Both apps read these rows directly. The table is publicly readable for the
 * same reason app_config is: the catalogue is shown before anyone signs in.
 */
export default async function ServicesPage() {
  const admin = await requirePermission('viewServices')
  const editable = can(admin.role, 'editServices')

  const db = supabaseAdmin()
  const [{ data: serviceRows, error }, { data: groupRows }] = await Promise.all([
    db.from('services').select('*').order('sort_order'),
    db.from('service_groups').select('id, name, sort_order').order('sort_order'),
  ])

  if (error) {
    throw new Error(
      `Loading services failed: ${error.message}. If it says the relation does not exist, migration 20260915090000_services.sql has not been applied to this project.`,
    )
  }

  const services = (serviceRows ?? []) as ServiceRow[]
  const groups = (groupRows ?? []) as Group[]

  const active = services.filter((s) => s.is_active)
  const withArt = services.filter((s) => s.thumbnail_url)
  const incomplete = services.filter((s) => !s.icon || !s.color || !s.group_id)
  const totals = services.reduce(
    (acc, s) => {
      const c = countTree(s.categories ?? [])
      return { categories: acc.categories + c.categories, options: acc.options + c.options }
    },
    { categories: 0, options: 0 },
  )

  // Ungrouped last, under its own heading rather than hidden — those are the
  // imported flows that never had an index entry, and they need attention.
  const buckets: Array<{ id: string | null; name: string; items: ServiceRow[] }> = [
    ...groups.map((g) => ({
      id: g.id,
      name: g.name,
      items: services.filter((s) => s.group_id === g.id),
    })),
    { id: null, name: 'Ungrouped', items: services.filter((s) => !s.group_id) },
  ].filter((b) => b.items.length > 0)

  return (
    <>
      <PageHeader
        title="Services"
        subtitle="What a customer can ask for, and the questions each one asks them. Both apps read this directly."
      />

      <div className="mb-2 grid grid-cols-2 gap-2 sm:grid-cols-5">
        <Stat label="Services" value={fmtNum(services.length)} hint={`${fmtNum(active.length)} live`} />
        <Stat label="With artwork" value={fmtNum(withArt.length)} tone={withArt.length < services.length ? 'warning' : 'success'} hint={`${fmtNum(services.length - withArt.length)} without`} />
        <Stat label="Categories" value={fmtNum(totals.categories)} hint="Across every flow" />
        <Stat label="Options" value={fmtNum(totals.options)} hint="Nested up to 3 deep" />
        <Stat
          label="Incomplete"
          value={fmtNum(incomplete.length)}
          tone={incomplete.length ? 'warning' : 'default'}
          hint="Missing group, icon or colour"
        />
      </div>

      {incomplete.length ? (
        <Card className="mb-2 border-warning/40">
          <CardHeader>
            <CardTitle>Imported without catalogue metadata</CardTitle>
          </CardHeader>
          <CardBody>
            <p className="text-[11px] leading-relaxed text-muted-foreground">
              {incomplete.length} {incomplete.length === 1 ? 'service has' : 'services have'} a
              question flow but no group, icon or colour — they existed as flow files in the old app
              without an entry in its index. They are live and answerable; they will just look plain
              on a tile until someone fills those in. Nothing was invented for them.
            </p>
            <p className="mt-1.5 text-[11px] text-muted-foreground">
              {incomplete.map((s) => s.name).join(', ')}
            </p>
          </CardBody>
        </Card>
      ) : null}

      {services.length === 0 ? (
        <Card>
          <CardBody className="py-8 text-center">
            <p className="text-xs text-muted-foreground">
              No services yet. They are imported from the old app&apos;s flow files by{' '}
              <span className="font-mono">scripts/import-services.mjs</span>.
            </p>
          </CardBody>
        </Card>
      ) : (
        buckets.map((bucket) => (
          <section key={bucket.id ?? 'ungrouped'} className="mb-4">
            <div className="mb-2 flex flex-wrap items-baseline justify-between gap-2">
              <h2 className="text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
                {bucket.name}
              </h2>
              <span className="tabular text-[11px] text-muted-foreground">
                {fmtNum(bucket.items.length)}{' '}
                {bucket.items.length === 1 ? 'service' : 'services'}
              </span>
            </div>
            <div className="grid gap-2 md:grid-cols-2 xl:grid-cols-3">
              {bucket.items.map((service) => (
                <ServiceEditor
                  key={service.id}
                  service={service}
                  groups={groups}
                  readOnly={!editable}
                />
              ))}
            </div>
          </section>
        ))
      )}
    </>
  )
}
