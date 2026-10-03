import Link from 'next/link'

export default function NotFound() {
  return (
    <div className="mx-auto max-w-lg py-16 text-center">
      <h2 className="text-sm font-semibold">There is nothing at that address.</h2>
      <p className="mt-2 text-xs text-muted-foreground">
        The record may have been deleted, or the link may be from another environment.
      </p>
      <Link href="/" className="mt-4 inline-block text-xs text-primary hover:underline">
        Back to the dashboard
      </Link>
    </div>
  )
}
