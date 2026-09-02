import { forceSignOut, loadProfile, useProfile } from '~/composables/useAuth'
import { profileHomePath, roleHomePath } from '~/composables/useRoleMeta'

const PUBLIC_ROUTES = new Set(['/login'])

export default defineNuxtRouteMiddleware(async (to) => {
  const user = useSupabaseUser()
  const profile = useProfile()

  if (!user.value) {
    if (!PUBLIC_ROUTES.has(to.path)) return navigateTo('/login')
    return
  }

  // Don't leave a stranded login screen once authenticated.
  if (PUBLIC_ROUTES.has(to.path)) {
    if (!profile.value || profile.value.id !== user.value.id) await loadProfile()
    return navigateTo(profile.value ? profileHomePath(profile.value) : '/login')
  }

  if (!profile.value || profile.value.id !== user.value.id) {
    await loadProfile()
  }

  // Revoked staff accounts must actually be blocked, not just show a
  // grayed-out row in Admin's Staff table.
  if (profile.value && profile.value.active === false) {
    return forceSignOut('revoked')
  }

  const current = profile.value
  if (!current) return navigateTo('/no-access')

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
