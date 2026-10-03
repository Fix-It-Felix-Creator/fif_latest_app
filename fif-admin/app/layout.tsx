import type { Metadata } from 'next'
import { THEME_SCRIPT } from '@/lib/theme'
import './globals.css'

export const metadata: Metadata = {
  title: 'Fix It Felix Admin',
  description:
    'Tradespeople, customers, verification, work and billing across both Fix It Felix apps.',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        {/* Blocking, and before anything paints. An effect would run after the
            browser has already drawn the wrong theme once per page. The
            attribute it stamps is why <html> needs suppressHydrationWarning:
            the server cannot know what the browser stored. */}
        <script dangerouslySetInnerHTML={{ __html: THEME_SCRIPT }} />
      </head>
      <body className="min-h-screen antialiased">{children}</body>
    </html>
  )
}
