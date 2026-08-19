export default defineNuxtPlugin(() => {
  const { setOnline } = useSyncQueue()

  setOnline(navigator.onLine)
  window.addEventListener('online', () => setOnline(true))
  window.addEventListener('offline', () => setOnline(false))
})
