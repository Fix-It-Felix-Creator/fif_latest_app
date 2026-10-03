/**
 * Which backend this deployment is pointed at.
 *
 * Staging and production are two separate Supabase projects. The panel loads
 * exactly one project's keys, so the environment is a build-time fact rather
 * than something a session can change — and the only honest thing to do with a
 * build-time fact is say it everywhere someone might act on it.
 */
export type FifEnv = 'staging' | 'production'

export const FIF_ENV: FifEnv =
  process.env.NEXT_PUBLIC_FIF_ENV === 'production' ? 'production' : 'staging'

export const IS_PRODUCTION = FIF_ENV === 'production'

/** The Supabase project ref, as it appears in the dashboard URL. */
export function projectRef(): string {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL ?? ''
  return url.replace(/^https:\/\//, '').split('.')[0] || 'unknown'
}

export const ENV_LABEL: Record<FifEnv, string> = {
  staging: 'Staging',
  production: 'Production',
}

/**
 * The sentence in the top bar.
 *
 * Production says what it is reading and that it is being recorded; staging
 * says it is safe. Someone who has both open in two tabs should be able to
 * tell them apart without looking for the banner.
 */
export const ENV_NOTE: Record<FifEnv, string> = {
  staging:
    'Reading the staging project · safe to click · every change is still written to the audit log',
  production:
    'Reading live production data · every change is written to the audit log',
}
