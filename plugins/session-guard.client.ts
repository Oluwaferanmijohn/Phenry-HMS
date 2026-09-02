import { forceSignOut, loadProfile, useProfile } from '~/composables/useAuth'
import { profileHomePath } from '~/composables/useRoleMeta'

export default defineNuxtPlugin(() => {
  const supabase = useSupabaseClient()
  const user = useSupabaseUser()
  const profile = useProfile()
  const route = useRoute()
  let channel: ReturnType<typeof supabase.channel> | null = null
  let checking = false

  async function validateSession() {
    if (!user.value || checking) return
    checking = true
    try {
      const current = await loadProfile()
      if (!current || !current.active) {
        await forceSignOut('revoked')
        return
      }
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
          const current = await loadProfile()
          if (!current || !current.active) return forceSignOut('revoked')
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

  const cleanup = () => {
    stop()
    window.clearInterval(interval)
    window.removeEventListener('focus', validateSession)
    if (channel) void supabase.removeChannel(channel)
  }
  if (import.meta.hot) import.meta.hot.dispose(cleanup)
})
