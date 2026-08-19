// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: '2026-01-01',
  devtools: { enabled: true },

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
})
