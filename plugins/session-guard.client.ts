import { forceSignOut, refreshProfileAccess, useProfile } from '~/composables/useAuth'
import { profileHomePath } from '~/composables/useRoleMeta'

export default defineNuxtPlugin(() => {
  const supabase = useSupabaseClient()
  const user = useSupabaseUser()
  const profile = useProfile()
  const route = useRoute()
  let channel: ReturnType<typeof supabase.channel> | null = null
  let checking = false

  async function validateSession() {
    if (!navigator.onLine || !user.value || checking) return
    checking = true
    try {
      const result = await refreshProfileAccess()
      if (result.status === 'revoked' || result.status === 'missing') {
        await forceSignOut('revoked')
        return
      }
      // `unavailable` means the request failed; it is not evidence of revoked
      // access. Keep the local session/profile and try again on reconnect.
      if (result.status !== 'active' || !result.profile) return
      const current = result.profile
      if (current.force_password_reset && route.path !== '/reset-password') {
        await navigateTo('/reset-password')
      }
    } finally {
      checking = false
    }
  }

  async function subscribe(userId?: string) {
    if (channel) {
      await supabase.removeChannel(channel)
      channel = null
    }
    if (!userId) return
    if (!navigator.onLine) return
    channel = supabase
      .channel(`profile-session:${userId}`)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'profiles', filter: `id=eq.${userId}` },
        async (event: any) => {
          if (event.eventType === 'DELETE' || event.new?.active === false) {
            await forceSignOut('revoked')
            return
          }
          const previousRole = profile.value?.role
          const previousCustomRole = profile.value?.custom_role_key
          const result = await refreshProfileAccess()
          if (result.status === 'revoked' || result.status === 'missing') return forceSignOut('revoked')
          if (result.status !== 'active' || !result.profile) return
          const current = result.profile
          if (current.force_password_reset) return navigateTo('/reset-password')
          if (current.role !== previousRole || current.custom_role_key !== previousCustomRole) {
            return navigateTo(profileHomePath(current))
          }
        },
      )
      .subscribe()
  }

  const stop = watch(() => user.value?.id, subscribe, { immediate: true })
  const interval = window.setInterval(validateSession, 60_000)
  window.addEventListener('focus', validateSession)
  const handleOnline = () => {
    void subscribe(user.value?.id)
    void validateSession()
  }
  window.addEventListener('online', handleOnline)
  void validateSession()

  const cleanup = () => {
    stop()
    window.clearInterval(interval)
    window.removeEventListener('focus', validateSession)
    window.removeEventListener('online', handleOnline)
    if (channel) void supabase.removeChannel(channel)
  }
  if (import.meta.hot) import.meta.hot.dispose(cleanup)
})
