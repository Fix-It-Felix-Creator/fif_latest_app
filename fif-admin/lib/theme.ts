export const THEME_KEY = 'fif-admin-theme'

export type Theme = 'light' | 'dark' | 'system'

/**
 * Applies the stored theme before the first paint.
 *
 * This has to be a blocking inline script in <head>. React hydrates after the
 * browser has already painted, so setting the attribute in an effect means
 * anyone who chose light on a dark machine watches the panel flash black
 * first — on every single navigation.
 *
 * "system" stores nothing and stamps nothing, so the CSS media query is left
 * to answer. Wrapped in try/catch because localStorage throws outright in a
 * few real configurations (Safari private mode, site data blocked), and a
 * theme preference is not worth a blank page.
 */
export const THEME_SCRIPT = `(function(){try{var t=localStorage.getItem(${JSON.stringify(
  THEME_KEY,
)});if(t==='dark'||t==='light'){document.documentElement.setAttribute('data-theme',t)}}catch(e){}})()`
