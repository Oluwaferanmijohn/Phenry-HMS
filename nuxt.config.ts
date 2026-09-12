// https://nuxt.com/docs/api/configuration/nuxt-config
const configuredSupabaseOrigin = (() => {
  try {
    return process.env.SUPABASE_URL ? new URL(process.env.SUPABASE_URL).origin : ''
  } catch {
    return ''
  }
})()
const configuredSupabaseSocket = configuredSupabaseOrigin.replace(/^http/, 'ws')
const supabaseConnections = ["'self'", 'https://*.supabase.co', 'wss://*.supabase.co', configuredSupabaseOrigin, configuredSupabaseSocket].filter(Boolean).join(' ')
const imageSources = ["'self'", 'data:', 'blob:', 'https://*.supabase.co', configuredSupabaseOrigin].filter(Boolean).join(' ')

export default defineNuxtConfig({
  compatibilityDate: '2026-01-01',
  devtools: { enabled: process.env.NODE_ENV === 'development' },

  modules: ['@nuxtjs/supabase', '@nuxtjs/tailwindcss'],

  // Every component template in this codebase uses short names regardless of
  // which subfolder the component lives in — <Sidebar>, <Icon>, <StaffModal>,
  // <PatientsSearchPage>, etc. Nuxt's default auto-import prefixes nested
  // components with their folder path (e.g. components/layout/Sidebar.vue ->
  // <LayoutSidebar>), which breaks every one of those references. Disabling
  // pathPrefix makes registration filename-only, matching how the app is
  // actually written. Checked: no duplicate filenames across components/
  // subfolders, so this introduces no naming collisions.
  components: [{ path: '~/components', pathPrefix: false }],

  css: ['~/assets/css/main.css'],

  // Auth gating is handled by our own middleware/auth.global.ts (role-aware,
  // multi-portal), not the module's built-in redirect — we disable that here.
  supabase: {
    url: process.env.SUPABASE_URL,
    key: process.env.SUPABASE_ANON_KEY,
    redirect: false,
  },

  runtimeConfig: {
    // Server-only. Never exposed to the client. Used by server/api routes that
    // need elevated access (creating staff/patient auth users, etc — added
    // starting with the Receptionist role's registration flow).
    supabaseServiceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY,
    whatsappWorkerSecret: process.env.WHATSAPP_WORKER_SECRET,
    public: {
      supabaseUrl: process.env.SUPABASE_URL,
      clinicName: 'Phenry Health',
    },
  },

  typescript: { strict: true },

  app: {
    head: {
      title: 'Phenry Health EMR',
      meta: [{ name: 'viewport', content: 'width=device-width, initial-scale=1, viewport-fit=cover' }],
    },
  },

  routeRules: {
    '/**': {
      headers: {
        'Content-Security-Policy': `default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src ${imageSources}; font-src 'self' data:; connect-src ${supabaseConnections}; frame-ancestors 'none'; base-uri 'self'; form-action 'self'`,
        'Referrer-Policy': 'strict-origin-when-cross-origin',
        'Permissions-Policy': 'camera=(self), microphone=(), geolocation=()',
        'X-Content-Type-Options': 'nosniff',
        'X-Frame-Options': 'DENY',
      },
    },
  },
})
