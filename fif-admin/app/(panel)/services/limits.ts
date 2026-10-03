/**
 * Shared between the server action and the browser-side cropper.
 *
 * Its own module because a `'use server'` file may only export async
 * functions — a constant there is a build error, and the cropper genuinely
 * needs the same number the server enforces.
 */

/** Nothing bigger reaches a customer's phone. */
export const MAX_THUMBNAIL_BYTES = 1_000_000
