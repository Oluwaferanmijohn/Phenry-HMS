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
