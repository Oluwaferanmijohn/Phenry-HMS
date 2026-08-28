export default defineNuxtPlugin(async () => {
  const { setOnline, hydrate } = useSyncQueue()

  // Restore any writes queued in a previous session (app was closed or
  // refreshed while offline with pending changes) before we start
  // reflecting online/offline state.
  await hydrate()

  setOnline(navigator.onLine)
  window.addEventListener('online', () => setOnline(true))
  window.addEventListener('offline', () => setOnline(false))
})
