import { forceSignOut, refreshProfileAccess, useProfile, type ProfileRefreshStatus } from '~/composables/useAuth'
import { profileHomePath, roleHomePath } from '~/composables/useRoleMeta'

const PUBLIC_ROUTES = new Set(['/login'])

export default defineNuxtRouteMiddleware(async (to) => {
  const user = useSupabaseUser()
  const profile = useProfile()
  const offline = import.meta.client && !navigator.onLine
  let refreshStatus: ProfileRefreshStatus | null = null

  if (!user.value) {
    // Supabase's reactive user can temporarily be unavailable while a token
    // refresh has no network. A last-confirmed active profile is sufficient
    // for this device's encrypted offline workspace until reconnect.
    if (!(offline && profile.value?.active)) {
      if (!PUBLIC_ROUTES.has(to.path)) return navigateTo('/login')
      return
    }
  }

  if (user.value && (!profile.value || profile.value.id !== user.value.id)) {
    const refreshed = await refreshProfileAccess()
    refreshStatus = refreshed.status
  }

  if (refreshStatus === 'revoked' || refreshStatus === 'missing') {
    return forceSignOut('revoked')
  }

  // Revoked staff accounts must actually be blocked, not just show a
  // grayed-out row in Admin's Staff table. This branch only runs on a profile
  // whose inactive state was positively confirmed, never on a fetch error.
  if (profile.value && profile.value.active === false) {
    return forceSignOut('revoked')
  }

  const current = profile.value
  if (!current) {
    if (refreshStatus === 'unavailable') {
      if (to.path !== '/no-access') return navigateTo('/no-access?offline=1')
      return
    }
    if (to.path !== '/no-access') return navigateTo('/no-access')
    return
  }

  // Don't leave a stranded login screen once authenticated or operating from
  // a last-confirmed profile during an outage.
  if (PUBLIC_ROUTES.has(to.path)) return navigateTo(profileHomePath(current))

  // Forced password reset gate (Bible §6.2 / spec §3.1) — applies to every
  // role, not just Patient. Staff created via create-staff.post.ts get the
  // exact same force_password_reset: true temp-password flag Patient does
  // (see the comment there: "same gate already built for patients"), so the
  // check here has to be role-agnostic or staff keep their temp password
  // forever. reset-password.vue is already written role-agnostically and
  // redirects back to roleHomePath() when done, so no other change needed.
  if (current.force_password_reset) {
    if (to.path !== '/reset-password') return navigateTo('/reset-password')
    return
  }
  if (to.path === '/reset-password' && !current.force_password_reset) {
    return navigateTo(profileHomePath(current))
  }

  if (!current.role && !current.custom_role_key) {
    if (to.path !== '/no-access') return navigateTo('/no-access')
    return
  }

  if (current.custom_role_key) {
    if (!to.path.startsWith('/custom')) return navigateTo('/custom')
    return
  }

  if (to.path === '/') {
    return navigateTo(roleHomePath(current.role!))
  }

  // Keep a logged-in user inside their own role's routes — RLS would block
  // the data anyway, but redirecting avoids a confusing all-empty screen.
  const routeRole = to.path.split('/')[1]
  if (routeRole && routeRole !== current.role && !['reset-password', 'no-access'].includes(routeRole)) {
    return navigateTo(roleHomePath(current.role!))
  }
})
