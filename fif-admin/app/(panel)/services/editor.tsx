'use client'

import { useRouter } from 'next/navigation'
import { useState, useTransition } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardBody, CardHeader, CardTitle } from '@/components/ui/card'
import { Input, Select, Textarea } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { SidePanel } from '@/components/side-panel'
import { ActionResult, type Feedback } from '@/app/(panel)/_components/action-result'
import { saveService, type ServiceInput } from './actions'
import { ThumbnailEditor } from './thumbnail-editor'
import { fmtNum } from '@/lib/format'
import { countTree, type FlowNode } from './flow'

export type ServiceRow = {
  id: string
  name: string
  subtitle: string | null
  description: string
  icon: string | null
  color: string | null
  group_id: string | null
  is_popular: boolean
  has_emergency: boolean
  is_active: boolean
  sort_order: number
  thumbnail_url: string | null
  thumbnail_path: string | null
  flow_title: string
  flow_subtitle: string | null
  categories: FlowNode[]
  updated_at: string | null
}

function initial(s: ServiceRow): ServiceInput {
  return {
    id: s.id,
    name: s.name,
    subtitle: s.subtitle ?? '',
    description: s.description,
    icon: s.icon ?? '',
    color: s.color ?? '',
    groupId: s.group_id ?? '',
    isPopular: s.is_popular,
    hasEmergency: s.has_emergency,
    isActive: s.is_active,
    sortOrder: String(s.sort_order),
    flowTitle: s.flow_title,
    flowSubtitle: s.flow_subtitle ?? '',
    categoriesText: JSON.stringify(s.categories ?? [], null, 2),
  }
}

export function ServiceEditor({
  service,
  groups,
  readOnly,
}: {
  service: ServiceRow
  groups: Array<{ id: string; name: string }>
  readOnly: boolean
}) {
  const router = useRouter()
  const base = initial(service)
  const [form, setForm] = useState<ServiceInput>(base)
  const [open, setOpen] = useState(false)
  const [confirmingDiscard, setConfirmingDiscard] = useState(false)
  const [thumb, setThumb] = useState(service.thumbnail_url)
  const [feedback, setFeedback] = useState<Feedback>(null)
  const [pending, start] = useTransition()

  const dirty = JSON.stringify(form) !== JSON.stringify(base)
  const set = <K extends keyof ServiceInput>(k: K, v: ServiceInput[K]) =>
    setForm((f) => ({ ...f, [k]: v }))

  const incomplete = !service.icon || !service.color || !service.group_id
  const counts = countTree(service.categories ?? [])

  function save() {
    start(async () => {
      const result = await saveService(form)
      if (result.ok) {
        setFeedback({ tone: 'ok', text: result.message, note: result.auditError })
        router.refresh()
        setOpen(false)
      } else {
        setFeedback({ tone: 'bad', text: result.error })
      }
    })
  }

  function close() {
    setForm(base)
    setConfirmingDiscard(false)
    setOpen(false)
  }

  function requestClose(): boolean {
    if (pending) return false
    if (dirty) {
      setConfirmingDiscard(true)
      return false
    }
    close()
    return true
  }

  return (
    <Card className={service.is_active ? undefined : 'opacity-60'}>
      <CardHeader>
        <div className="flex min-w-0 items-center gap-1.5">
          <CardTitle>{service.name}</CardTitle>
          <span className="tabular text-[10px] text-muted-foreground">{service.id}</span>
        </div>
        <div className="flex shrink-0 items-center gap-1">
          {service.has_emergency ? <Badge tone="danger">Emergency</Badge> : null}
          {service.is_popular ? <Badge tone="primary">Popular</Badge> : null}
          {!service.is_active ? <Badge tone="muted">Off</Badge> : null}
        </div>
      </CardHeader>

      <CardBody className="space-y-2">
        {thumb ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={thumb} alt="" className="h-24 w-full rounded-md border border-border object-cover" />
        ) : (
          <div className="flex h-24 w-full items-center justify-center rounded-md border border-dashed border-border text-[11px] text-muted-foreground">
            No thumbnail
          </div>
        )}

        <p className="text-[11px] leading-relaxed text-muted-foreground">
          {service.subtitle || service.description || 'No description.'}
        </p>

        <div className="flex flex-wrap items-center gap-1.5 text-[10px] text-muted-foreground">
          <span className="tabular">
            {fmtNum(counts.categories)} categories · {fmtNum(counts.options)} options
          </span>
          {incomplete ? (
            <Badge tone="warning">
              {[!service.group_id && 'no group', !service.icon && 'no icon', !service.color && 'no colour']
                .filter(Boolean)
                .join(', ')}
            </Badge>
          ) : null}
        </div>

        {readOnly ? (
          <p className="text-[11px] text-muted-foreground">
            Read-only for your role. Only a super admin can change a service.
          </p>
        ) : (
          <Button size="sm" variant="outline" onClick={() => setOpen(true)}>
            Edit service
          </Button>
        )}

        <SidePanel
          open={open}
          onRequestClose={requestClose}
          width="lg"
          title={service.name}
          subtitle={
            <>
              <span className="tabular">{service.id}</span> · {fmtNum(counts.categories)} categories,{' '}
              {fmtNum(counts.options)} options
            </>
          }
          footer={
            <div className="flex flex-wrap items-center gap-1.5">
              {confirmingDiscard ? (
                <>
                  <span className="text-[11px] text-warning">Discard your changes?</span>
                  <Button size="sm" variant="destructive" onClick={close}>
                    Discard
                  </Button>
                  <Button size="sm" variant="ghost" onClick={() => setConfirmingDiscard(false)}>
                    Keep editing
                  </Button>
                </>
              ) : (
                <>
                  <Button size="sm" onClick={save} disabled={pending || !dirty}>
                    {pending ? 'Saving…' : 'Save'}
                  </Button>
                  <Button size="sm" variant="ghost" onClick={requestClose} disabled={pending}>
                    {dirty ? 'Discard' : 'Close'}
                  </Button>
                  {dirty ? (
                    <span className="text-[10px] text-warning">Unsaved</span>
                  ) : (
                    <span className="text-[10px] text-muted-foreground">No changes</span>
                  )}
                </>
              )}
            </div>
          }
        >
          <div className="space-y-3">
            <Section title="Thumbnail">
              <ThumbnailEditor
                serviceId={service.id}
                currentUrl={thumb}
                onSaved={(url) => {
                  setThumb(url)
                  router.refresh()
                }}
              />
            </Section>

            <Section title="Catalogue">
              <Field label="Name" hint="The tile a customer taps">
                <Input value={form.name} onChange={(e) => set('name', e.target.value)} />
              </Field>
              <Field label="Subtitle" hint="One line under the name">
                <Input value={form.subtitle} onChange={(e) => set('subtitle', e.target.value)} />
              </Field>
              <Field label="Description" hint="Longer copy, for search and detail views">
                <Textarea
                  rows={2}
                  value={form.description}
                  onChange={(e) => set('description', e.target.value)}
                />
              </Field>
              <div className="grid gap-2 sm:grid-cols-3">
                <Field label="Group" hint="Heading it sits under">
                  <Select
                    className="w-full"
                    value={form.groupId}
                    onChange={(e) => set('groupId', e.target.value)}
                  >
                    <option value="">Ungrouped</option>
                    {groups.map((g) => (
                      <option key={g.id} value={g.id}>
                        {g.name}
                      </option>
                    ))}
                  </Select>
                </Field>
                <Field label="Icon" hint="lucide name">
                  <Input
                    value={form.icon}
                    onChange={(e) => set('icon', e.target.value)}
                    className="font-mono"
                  />
                </Field>
                <Field label="Colour" hint="#RRGGBB">
                  <div className="flex items-center gap-1.5">
                    <Input
                      value={form.color}
                      onChange={(e) => set('color', e.target.value)}
                      className="font-mono"
                    />
                    {/^#[0-9a-f]{6}$/i.test(form.color) ? (
                      <span
                        className="h-6 w-6 shrink-0 rounded border border-border"
                        style={{ background: form.color }}
                      />
                    ) : null}
                  </div>
                </Field>
              </div>
              <div className="flex flex-wrap items-center gap-4">
                <Check label="Popular" checked={form.isPopular} onChange={(v) => set('isPopular', v)} />
                <Check
                  label="Has emergency"
                  checked={form.hasEmergency}
                  onChange={(v) => set('hasEmergency', v)}
                />
                <Check label="Active" checked={form.isActive} onChange={(v) => set('isActive', v)} />
                <label className="flex items-center gap-1.5 text-[11px] text-muted-foreground">
                  Order
                  <Input
                    value={form.sortOrder}
                    onChange={(e) => set('sortOrder', e.target.value)}
                    className="w-16"
                  />
                </label>
              </div>
            </Section>

            <Section
              title="What the customer is asked"
              note="This flow is the data-input process. Both apps walk it to turn a tap on this service into a described job."
            >
              <Field label="Question" hint="The heading at the top of the flow">
                <Input value={form.flowTitle} onChange={(e) => set('flowTitle', e.target.value)} />
              </Field>
              <Field label="Helper text" hint="Smaller line beneath it">
                <Input
                  value={form.flowSubtitle}
                  onChange={(e) => set('flowSubtitle', e.target.value)}
                />
              </Field>
              <FlowPreview text={form.categoriesText} />
              <Field label="Flow" hint="Categories and their nested options, as JSON">
                <Textarea
                  rows={20}
                  value={form.categoriesText}
                  onChange={(e) => set('categoriesText', e.target.value)}
                  spellCheck={false}
                  className="font-mono text-[11px]"
                />
              </Field>
            </Section>

            <ActionResult feedback={feedback} />
          </div>
        </SidePanel>
      </CardBody>
    </Card>
  )
}

/**
 * The flow as a tree, drawn from whatever is currently in the box.
 *
 * A 14KB JSON document is unreadable as text, and the question being edited is
 * "does this read right to a customer" — which needs the shape, not the
 * syntax. Invalid JSON says so here rather than only on save.
 */
function FlowPreview({ text }: { text: string }) {
  let parsed: FlowNode[] | null = null
  let error: string | null = null
  try {
    const value = JSON.parse(text)
    if (Array.isArray(value)) parsed = value as FlowNode[]
    else error = 'The flow has to be an array of categories.'
  } catch (e) {
    error = e instanceof Error ? e.message : String(e)
  }

  if (error) {
    return (
      <p className="rounded border border-destructive/40 bg-destructive/10 px-2 py-1.5 text-[11px] text-destructive">
        {error}
      </p>
    )
  }

  const counts = countTree(parsed ?? [])
  return (
    <details open className="rounded-md border border-border bg-background">
      <summary className="cursor-pointer px-2.5 py-1.5 text-[11px] text-muted-foreground hover:text-foreground">
        Preview · {fmtNum(counts.categories)} categories, {fmtNum(counts.options)} options
      </summary>
      <div className="scroll-thin max-h-72 overflow-auto px-2.5 pb-2.5">
        <ul className="space-y-1">
          {(parsed ?? []).map((c, i) => (
            <Node key={c.id ?? i} node={c} depth={0} />
          ))}
        </ul>
      </div>
    </details>
  )
}

function Node({ node, depth }: { node: FlowNode; depth: number }) {
  return (
    <li style={{ paddingLeft: depth * 12 }}>
      <span className="flex items-baseline gap-1.5 text-[11px]">
        <span className={depth === 0 ? 'font-medium' : 'text-muted-foreground'}>
          {node.name ?? <span className="text-destructive">(no name)</span>}
        </span>
        {node.urgent ? <Badge tone="danger">Urgent</Badge> : null}
        {node.requiresDescription ? <Badge tone="info">Asks for detail</Badge> : null}
      </span>
      {node.options?.length ? (
        <ul className="mt-0.5 space-y-0.5">
          {node.options.map((o, i) => (
            <Node key={o.id ?? i} node={o} depth={depth + 1} />
          ))}
        </ul>
      ) : null}
    </li>
  )
}

function Section({
  title,
  note,
  children,
}: {
  title: string
  note?: string
  children: React.ReactNode
}) {
  return (
    <div className="space-y-2 border-t border-border/60 pt-2 first:border-0 first:pt-0">
      <h3 className="text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
        {title}
      </h3>
      {note ? <p className="text-[11px] leading-relaxed text-muted-foreground">{note}</p> : null}
      {children}
    </div>
  )
}

function Field({
  label,
  hint,
  children,
}: {
  label: string
  hint?: string
  children: React.ReactNode
}) {
  return (
    <label className="block space-y-1">
      <span className="flex items-baseline gap-1.5">
        <span className="text-[11px] font-medium text-muted-foreground">{label}</span>
        {hint ? <span className="text-[10px] text-muted-foreground/70">{hint}</span> : null}
      </span>
      {children}
    </label>
  )
}

function Check({
  label,
  checked,
  onChange,
}: {
  label: string
  checked: boolean
  onChange: (v: boolean) => void
}) {
  return (
    <label className="flex items-center gap-1.5 text-[11px]">
      <input
        type="checkbox"
        checked={checked}
        onChange={(e) => onChange(e.target.checked)}
        className="accent-primary"
      />
      <span className="font-medium">{label}</span>
    </label>
  )
}
