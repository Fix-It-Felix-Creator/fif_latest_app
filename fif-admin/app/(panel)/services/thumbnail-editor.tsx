'use client'

import { useCallback, useEffect, useRef, useState } from 'react'
import { Upload, ZoomIn } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { ActionResult, type Feedback } from '@/app/(panel)/_components/action-result'
import { saveThumbnail, setThumbnailUrl } from './actions'
import { MAX_THUMBNAIL_BYTES } from './limits'

/**
 * Square, because that is the box both apps draw a service in.
 *
 * This was 800×600, and the crop an admin framed was then cropped AGAIN by the
 * app to fit a square tile — the sides they had carefully included were the
 * first thing thrown away.
 */
const OUT = 800

/** The crop frame on screen. The whole image is shown around it. */
const FRAME = 300

/** Room around the frame so an image zoomed out is still visible. */
const PAD = 44

export function ThumbnailEditor({
  serviceId,
  currentUrl,
  onSaved,
}: {
  serviceId: string
  currentUrl: string | null
  onSaved: (url: string | null) => void
}) {
  const [source, setSource] = useState<HTMLImageElement | null>(null)
  const [zoom, setZoom] = useState(1)
  const [offset, setOffset] = useState({ x: 0, y: 0 })
  const [urlValue, setUrlValue] = useState(currentUrl ?? '')
  const [feedback, setFeedback] = useState<Feedback>(null)
  const [busy, setBusy] = useState(false)
  const [outSize, setOutSize] = useState<number | null>(null)

  const dragging = useRef<{ x: number; y: number } | null>(null)

  /**
   * Scale at which the whole image is visible inside the frame.
   *
   * Zoom is expressed as a multiple of this, so 1 always means "I can see all
   * of it" whatever the photograph's shape — which is the point someone starts
   * from when deciding what to keep.
   */
  const fitScale = source ? Math.min(FRAME / source.width, FRAME / source.height) : 1

  /** Smallest zoom that still fills the frame — below this, edges go blank. */
  const coverZoom = source
    ? Math.max(FRAME / source.width, FRAME / source.height) / fitScale
    : 1

  const scale = fitScale * zoom
  const drawnW = source ? source.width * scale : 0
  const drawnH = source ? source.height * scale : 0

  /** True when the current framing leaves part of the square empty. */
  const hasGaps =
    source != null &&
    (drawnW + 0.5 < FRAME ||
      drawnH + 0.5 < FRAME ||
      Math.abs(offset.x) > Math.max(0, (drawnW - FRAME) / 2) + 0.5 ||
      Math.abs(offset.y) > Math.max(0, (drawnH - FRAME) / 2) + 0.5)

  // ---- export -------------------------------------------------------------
  const encode = useCallback(() => {
    if (!source) return null
    const canvas = document.createElement('canvas')
    canvas.width = OUT
    canvas.height = OUT
    const ctx = canvas.getContext('2d')
    if (!ctx) return null

    // White, not transparent: the output is JPEG, which has no alpha, and an
    // unpainted canvas encodes as black.
    ctx.fillStyle = '#fff'
    ctx.fillRect(0, 0, OUT, OUT)

    // The frame maps onto the output, so everything scales by the same ratio.
    const r = OUT / FRAME
    ctx.drawImage(
      source,
      (OUT - drawnW * r) / 2 + offset.x * r,
      (OUT - drawnH * r) / 2 + offset.y * r,
      drawnW * r,
      drawnH * r,
    )

    for (const q of [0.82, 0.72, 0.62, 0.5, 0.4]) {
      const dataUrl = canvas.toDataURL('image/jpeg', q)
      const bytes = Math.ceil(((dataUrl.length - dataUrl.indexOf(',') - 1) * 3) / 4)
      if (bytes <= MAX_THUMBNAIL_BYTES) return { dataUrl, bytes }
    }
    return null
  }, [source, drawnW, drawnH, offset])

  useEffect(() => {
    if (!source) return setOutSize(null)
    setOutSize(encode()?.bytes ?? null)
  }, [source, encode])

  function pick(file: File) {
    if (!/^image\/(jpeg|png|webp)$/.test(file.type)) {
      setFeedback({ tone: 'bad', text: 'Pick a JPEG, PNG or WebP.' })
      return
    }
    const reader = new FileReader()
    reader.onload = () => {
      const img = new Image()
      img.onload = () => {
        setSource(img)
        // Open on "fills the frame" rather than "shows everything": it is the
        // usable starting point, and zooming out from it is one drag.
        setZoom(Math.max(1, Math.max(FRAME / img.width, FRAME / img.height) / Math.min(FRAME / img.width, FRAME / img.height)))
        setOffset({ x: 0, y: 0 })
        setFeedback(null)
      }
      img.onerror = () => setFeedback({ tone: 'bad', text: 'That file could not be read as an image.' })
      img.src = String(reader.result)
    }
    reader.readAsDataURL(file)
  }

  function save() {
    const out = encode()
    if (!out) {
      setFeedback({ tone: 'bad', text: 'Even at low quality this will not fit under 1MB. Crop tighter.' })
      return
    }
    setBusy(true)
    saveThumbnail(serviceId, out.dataUrl)
      .then((result) => {
        if (result.ok) {
          setFeedback({ tone: 'ok', text: result.message, note: result.auditError })
          setSource(null)
          onSaved(result.url ?? null)
        } else {
          setFeedback({ tone: 'bad', text: result.error })
        }
      })
      .finally(() => setBusy(false))
  }

  function link() {
    setBusy(true)
    setThumbnailUrl(serviceId, urlValue)
      .then((result) => {
        if (result.ok) {
          setFeedback({ tone: 'ok', text: result.message, note: result.auditError })
          onSaved(urlValue.trim() || null)
        } else {
          setFeedback({ tone: 'bad', text: result.error })
        }
      })
      .finally(() => setBusy(false))
  }

  return (
    <div className="space-y-2">
      {source ? (
        <>
          {/* The whole image, with the square that will be kept cut out of a
              dimmed overlay. Showing only the crop meant deciding what to
              throw away without being able to see it. */}
          <div
            className="relative mx-auto touch-none select-none overflow-hidden rounded-md border border-border bg-background"
            style={{ width: FRAME + PAD * 2, height: FRAME + PAD * 2 }}
            onPointerDown={(e) => {
              dragging.current = { x: e.clientX - offset.x, y: e.clientY - offset.y }
              e.currentTarget.setPointerCapture(e.pointerId)
            }}
            onPointerMove={(e) => {
              if (!dragging.current) return
              setOffset({ x: e.clientX - dragging.current.x, y: e.clientY - dragging.current.y })
            }}
            onPointerUp={() => (dragging.current = null)}
            onPointerCancel={() => (dragging.current = null)}
          >
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={source.src}
              alt=""
              draggable={false}
              className="pointer-events-none absolute cursor-move"
              style={{
                width: drawnW,
                height: drawnH,
                left: PAD + (FRAME - drawnW) / 2 + offset.x,
                top: PAD + (FRAME - drawnH) / 2 + offset.y,
                maxWidth: 'none',
              }}
            />

            {/* The dim + frame outline, drawn as one element: a huge spread
                shadow fills everything outside the square without needing four
                separate panels that have to stay in step. */}
            <div
              className="pointer-events-none absolute rounded-sm ring-1 ring-white/80"
              style={{
                left: PAD,
                top: PAD,
                width: FRAME,
                height: FRAME,
                boxShadow: '0 0 0 9999px rgba(0,0,0,0.55)',
              }}
            />
          </div>

          <label className="flex items-center gap-2 text-[11px] text-muted-foreground">
            <ZoomIn className="h-3 w-3 shrink-0" />
            <input
              type="range"
              min={1}
              max={4}
              step={0.01}
              value={zoom}
              onChange={(e) => setZoom(Number(e.target.value))}
              className="h-1 flex-1 accent-primary"
              aria-label="Zoom"
            />
            <span className="tabular w-10 text-right">{zoom.toFixed(2)}×</span>
          </label>

          <div className="flex flex-wrap items-center gap-1.5">
            <Button
              size="sm"
              variant="outline"
              onClick={() => {
                setZoom(coverZoom)
                setOffset({ x: 0, y: 0 })
              }}
            >
              Fill the frame
            </Button>
            <Button
              size="sm"
              variant="ghost"
              onClick={() => {
                setZoom(1)
                setOffset({ x: 0, y: 0 })
              }}
            >
              Show all of it
            </Button>
          </div>

          <p className="text-[11px] leading-relaxed text-muted-foreground">
            Drag the image to move it under the frame. Only the square is kept, saved as {OUT}×{OUT}
            {outSize !== null ? (
              <>
                {' '}
                — <span className="tabular font-medium text-foreground">{Math.round(outSize / 1024)}KB</span>
              </>
            ) : (
              ', which will not fit under 1MB at any quality'
            )}
            .
          </p>

          {hasGaps ? (
            <p className="text-[11px] text-warning">
              Part of the square is empty and will save as white. &ldquo;Fill the frame&rdquo; is
              the nearest framing that covers it.
            </p>
          ) : null}

          <div className="flex flex-wrap gap-1.5">
            <Button size="sm" onClick={save} disabled={busy || outSize === null}>
              {busy ? 'Saving…' : 'Save thumbnail'}
            </Button>
            <Button size="sm" variant="ghost" onClick={() => setSource(null)} disabled={busy}>
              Cancel
            </Button>
          </div>
        </>
      ) : (
        <>
          {currentUrl ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={currentUrl}
              alt=""
              className="aspect-square w-32 rounded-md border border-border object-cover"
            />
          ) : (
            <div className="flex aspect-square w-32 items-center justify-center rounded-md border border-dashed border-border text-[11px] text-muted-foreground">
              No image
            </div>
          )}

          <label className="inline-flex h-8 cursor-pointer items-center gap-1.5 rounded-md border border-border px-3 text-xs font-medium transition-colors hover:bg-accent">
            <Upload className="h-3 w-3" />
            Upload and crop
            <input
              type="file"
              accept="image/jpeg,image/png,image/webp"
              className="sr-only"
              onChange={(e) => {
                const file = e.target.files?.[0]
                if (file) pick(file)
                e.target.value = ''
              }}
            />
          </label>

          <div className="space-y-1 border-t border-border/60 pt-2">
            <span className="text-[11px] font-medium text-muted-foreground">
              Or point at an image hosted elsewhere
            </span>
            <div className="flex flex-wrap items-center gap-1.5">
              <Input
                value={urlValue}
                onChange={(e) => setUrlValue(e.target.value)}
                placeholder="https://…"
                className="w-64 font-mono"
              />
              <Button size="sm" variant="outline" onClick={link} disabled={busy}>
                {urlValue.trim() ? 'Link' : 'Remove'}
              </Button>
            </div>
            <p className="text-[10px] text-muted-foreground">
              A linked image is not cropped or stored here, so its shape and size are whoever hosts
              it — the apps draw it in a square box either way.
            </p>
          </div>
        </>
      )}

      <ActionResult feedback={feedback} />
    </div>
  )
}
