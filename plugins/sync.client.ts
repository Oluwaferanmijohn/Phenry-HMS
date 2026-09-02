export default defineNuxtPlugin(() => {
  const user = useSupabaseUser()
  const { setOnline, hydrate, clearUserState } = useSyncQueue()
  const handleOnline = () => setOnline(true)
  const handleOffline = () => setOnline(false)

  setOnline(navigator.onLine)
  window.addEventListener('online', handleOnline)
  window.addEventListener('offline', handleOffline)

  const stop = watch(
    () => user.value?.id,
    async (userId, previousUserId) => {
      // A temporary null user during an offline token refresh is not a real
      // sign-out. Explicit and confirmed forced sign-outs already clear their
      // own data in useAuth; only auto-clear an identity change while online.
      if (navigator.onLine && previousUserId && previousUserId !== userId) await clearUserState(previousUserId)
      if (!navigator.onLine && !userId) return
      await hydrate(userId)
    },
    { immediate: true },
  )

  const cleanup = () => {
    stop()
    window.removeEventListener('online', handleOnline)
    window.removeEventListener('offline', handleOffline)
  }
  if (import.meta.hot) import.meta.hot.dispose(cleanup)
})
