import { requirePermission } from '@/lib/auth'
import { can } from '@/lib/roles'
import { supabaseAdmin } from '@/lib/supabase/server'
import { PageHeader } from '@/components/page-header'
import { Card, CardBody, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { KV } from '@/components/ui/kv'
import { ConfigEditor } from './editor'
import { FIF_ENV, IS_PRODUCTION } from '@/lib/env'
import { fmtAgo } from '@/lib/format'

export const metadata = { title: 'App config · Fix It Felix Admin' }
export const dynamic = 'force-dynamic'

type ConfigRow = {
  key: string
  value: Record<string, unknown>
  description: string | null
  updated_at: string | null
}

/**
 * What both apps read at launch.
 *
 * This table replaced Firebase Remote Config, and it is read before sign-in —
 * `app_config` is the one table with a "anyone reads" policy. Nothing here is
 * per-user; everything here is per-install, which is what makes it the most
 * dangerous screen in the panel and why editing is superAdmin only.
 *
 * Note the prod_/dev_ prefixes: several keys exist twice, once per
 * environment, inside BOTH projects. The app picks by its compile-time
 * APP_TYPE, not by which project it is talking to — so on production the key
 * that matters is `prod_variable`, and `dev_variable` in the same table is
 * read by nobody.
 */
export default async function ConfigPage() {
  const admin = await requirePermission('viewConfig')
  const writable = can(admin.role, 'writeConfig')

  const { data, error } = await supabaseAdmin()
    .from('app_config')
    .select('key, value, description, updated_at')
    .order('key')

  if (error) throw new Error(`Loading app config failed: ${error.message}`)
  const rows = (data ?? []) as ConfigRow[]

  const live = IS_PRODUCTION ? 'prod_' : 'dev_'
  const relevant = rows.filter((r) => !r.key.startsWith('prod_') && !r.key.startsWith('dev_'))
  const perEnv = rows.filter((r) => r.key.startsWith('prod_') || r.key.startsWith('dev_'))

  const maintenance = rows.find((r) => r.key === `${live}maintenance`)
  const forceUpdate = rows.find((r) =>
    IS_PRODUCTION ? r.key === 'force_app_update' : r.key === 'dev_force_app_update',
  )
  const maintenanceOn = maintenance?.value?.isEnabled === true
  const forceOn = String(forceUpdate?.value?.value ?? 'false') === 'true'

  return (
    <>
      <PageHeader
        title="App config"
        subtitle="Read by both apps at launch, before anyone signs in. Changing a value here changes every install."
      />

      <div className="mb-2 grid gap-2 lg:grid-cols-3">
        <Card className={maintenanceOn ? 'border-destructive/40' : undefined}>
          <CardHeader>
            <CardTitle>Maintenance</CardTitle>
            {maintenanceOn ? <Badge tone="danger">On</Badge> : <Badge tone="muted">Off</Badge>}
          </CardHeader>
          <CardBody>
            {maintenanceOn ? (
              <p className="text-[11px] leading-relaxed text-destructive">
                Every {FIF_ENV} install is showing the maintenance screen right now:{' '}
                {String(maintenance?.value?.title ?? '')} — {String(maintenance?.value?.message ?? '')}
              </p>
            ) : (
              <p className="text-[11px] text-muted-foreground">
                Nobody is being held out. The {live}maintenance key below turns this on.
              </p>
            )}
          </CardBody>
        </Card>

        <Card className={forceOn ? 'border-warning/40' : undefined}>
          <CardHeader>
            <CardTitle>Forced update</CardTitle>
            {forceOn ? <Badge tone="warning">On</Badge> : <Badge tone="muted">Off</Badge>}
          </CardHeader>
          <CardBody>
            <p className="text-[11px] leading-relaxed text-muted-foreground">
              {forceOn
                ? 'Anyone below the configured version is being sent to the store before they can use the app.'
                : 'Old versions keep working.'}
            </p>
          </CardBody>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Which keys this build reads</CardTitle>
          </CardHeader>
          <CardBody>
            <KV
              columns={1}
              items={[
                { label: 'This deployment', value: FIF_ENV },
                { label: 'Live prefix', value: `${live}*` },
                { label: 'Keys in the table', value: rows.length },
                {
                  label: 'Last change',
                  value: fmtAgo(
                    rows
                      .map((r) => r.updated_at)
                      .filter(Boolean)
                      .sort()
                      .at(-1) ?? null,
                  ),
                },
              ]}
            />
            <p className="mt-2 text-[10px] leading-relaxed text-muted-foreground">
              An app picks its prefix from the APP_TYPE baked into its binary, not from the project
              it is talking to. Editing the other prefix here changes nothing for anybody.
            </p>
          </CardBody>
        </Card>
      </div>

      {perEnv.length ? (
        <>
          <h2 className="mb-2 mt-3 text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
            Per-environment keys
          </h2>
          <div className="grid gap-2 lg:grid-cols-2">
            {perEnv.map((row) => (
              <ConfigEditor
                key={row.key}
                configKey={row.key}
                value={row.value}
                description={
                  row.key.startsWith(live)
                    ? (row.description ?? 'Read by this environment.')
                    : `Not read by ${FIF_ENV} builds — the ${live}* key is. ${row.description ?? ''}`.trim()
                }
                updatedAt={row.updated_at}
                readOnly={!writable}
              />
            ))}
          </div>
        </>
      ) : null}

      <h2 className="mb-2 mt-3 text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
        Shared keys
      </h2>
      {relevant.length === 0 ? (
        <Card>
          <CardBody className="py-6 text-center">
            <p className="text-xs text-muted-foreground">
              No shared keys. The apps also read `subscriptions`, `commissionRates`, `videoLimits`
              and `accountDeletion` — if they are not here, the apps are running on their built-in
              defaults for all four.
            </p>
          </CardBody>
        </Card>
      ) : (
        <div className="grid gap-2 lg:grid-cols-2">
          {relevant.map((row) => (
            <ConfigEditor
              key={row.key}
              configKey={row.key}
              value={row.value}
              description={row.description}
              updatedAt={row.updated_at}
              readOnly={!writable}
            />
          ))}
        </div>
      )}
    </>
  )
}
