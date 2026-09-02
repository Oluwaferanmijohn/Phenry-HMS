import { cachePatientSnapshot, getCachedPatientSnapshot } from '~/composables/useOfflineDb'
import { useSyncQueue } from '~/composables/useSyncQueue'
import { useProfile } from '~/composables/useAuth'

// Wraps a data-loading function so its result is cached to IndexedDB on
// success, and served from that cache when offline. This is the mechanism
// behind "I can reopen a patient I've already looked at, even with no
// signal" — deliberately scoped to patients actually opened, not every
// patient in the system (see useOfflineDb.ts for why).
export function useRecentPatientCache() {
  const { online } = useSyncQueue()
  const user = useSupabaseUser()
  const profile = useProfile()

  async function loadWithCache<T>(patientId: string, fetcher: () => Promise<T>): Promise<{ data: T | null; fromCache: boolean }> {
    const userId = user.value?.id || (!online.value ? profile.value?.id : undefined)
    if (!userId) return { data: null, fromCache: false }
    if (online.value) {
      try {
        const data = await fetcher()
        if (data) await cachePatientSnapshot(userId, patientId, data)
        return { data, fromCache: false }
      } catch (err) {
        // A fetch can fail because connectivity just dropped mid-request —
        // fall back to cache rather than surfacing a blank screen.
        const cached = await getCachedPatientSnapshot<T>(userId, patientId)
        if (cached) return { data: cached, fromCache: true }
        throw err
      }
    }
    const cached = await getCachedPatientSnapshot<T>(userId, patientId)
    return { data: cached, fromCache: true }
  }

  return { loadWithCache }
}
