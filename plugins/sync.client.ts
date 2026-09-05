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
      // sign-out. `navigator.onLine` may also be a false positive, so a null
      // value must never clear or de-hydrate the confirmed user's encrypted
      // queue. Explicit sign-out and confirmed revocation clear their own data.
      if (!userId) return
      if (previousUserId && previousUserId !== userId) await clearUserState(previousUserId)
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
