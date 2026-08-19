import { loadProfile, useProfile } from '~/composables/useAuth'
import { roleHomePath } from '~/composables/useRoleMeta'

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
    return navigateTo(profile.value ? roleHomePath(profile.value.role ?? '') : '/login')
  }

  if (!profile.value || profile.value.id !== user.value.id) {
    await loadProfile()
  }

  // Revoked staff accounts must actually be blocked, not just show a
  // grayed-out row in Admin's Staff table.
  if (profile.value && profile.value.active === false) {
    const supabase = useSupabaseClient()
    await supabase.auth.signOut()
    profile.value = null
    return navigateTo('/login?revoked=1')
  }

  // No role assigned at all (account provisioned but not configured yet),
  // OR a custom role with no built UI: the permissions DATA MODEL
  // (custom_roles/role_permissions) is fully built and enforced by RLS, but
  // neither the prototype nor the spec describes what an arbitrary custom
  // role's actual SCREENS should look like — that's a real product
  // decision, not a gap to paper over with an invented generic UI. Both
  // cases land on /no-access, which shows the right message for each.
  if (!profile.value?.role) {
    if (to.path !== '/no-access') return navigateTo('/no-access')
    return
  }

  // Patient forced password reset gate (Bible §6.2 / spec §3.1).
  if (profile.value.role === 'patient' && profile.value.force_password_reset) {
    if (to.path !== '/reset-password') return navigateTo('/reset-password')
    return
  }
  if (to.path === '/reset-password' && !profile.value.force_password_reset) {
    return navigateTo(roleHomePath(profile.value.role))
  }

  if (to.path === '/') {
    return navigateTo(roleHomePath(profile.value.role))
  }

  // Keep a logged-in user inside their own role's routes — RLS would block
  // the data anyway, but redirecting avoids a confusing all-empty screen.
  const routeRole = to.path.split('/')[1]
  if (routeRole && routeRole !== profile.value.role && !['reset-password', 'no-access'].includes(routeRole)) {
    return navigateTo(roleHomePath(profile.value.role))
  }
})
