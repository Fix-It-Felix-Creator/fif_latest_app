import path from 'node:path'
import type { NextConfig } from 'next'

const config: NextConfig = {
  // Pinned because there is a stray package-lock.json above this directory;
  // without it Turbopack infers a workspace root outside the repository and
  // warns on every build.
  turbopack: { root: path.resolve(process.cwd()) },

  experimental: {
    // Every page here reads live rows behind a session, so the client router
    // cache is set to nothing: caching an admin page is caching one admin's
    // view of another user's data. Only `dynamic` is set — Next refuses a
    // `static` below 30s, and every route in this panel is dynamic anyway.
    staleTimes: { dynamic: 0 },
  },
}

export default config
