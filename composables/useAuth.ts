// Central place every page/layout/middleware reads "who is logged in and
// what role are they" from. Wraps @nuxtjs/supabase's useSupabaseUser() with
// a fetch of the matching profiles row (role, patient_id, force_password_reset).
import { cacheProfileSnapshot, getCachedProfileSnapshot } from '~/composables/useOfflineDb'

export interface Profile {
  id: string
  role: string | null
  custom_role_key: string | null
  full_name: string | null
  avatar_url: string | null
  patient_id: string | null
  force_password_reset: boolean
  active: boolean
}

export const useProfile = () =>
  useState<Profile | null>('profile', () => null)

export type ProfileRefreshStatus = 'active' | 'revoked' | 'missing' | 'unavailable' | 'signed-out'

export interface ProfileRefreshResult {
  status: ProfileRefreshStatus
  profile: Profile | null
}

async function cachedProfileFor(userId: string, current: Profile | null) {
  if (current?.id === userId) return current
  if (!import.meta.client) return null
  try {
    const cached = await getCachedProfileSnapshot<Profile>(userId)
    return cached?.id === userId && cached.active ? cached : null
  } catch {
    return null
  }
}

// A profile refresh has three materially different failure outcomes:
// confirmed inactive/missing, signed out, and temporarily unreachable. Only
// the first is an access revocation. Network/server errors keep the last
// confirmed profile so offline navigation and encrypted caches remain usable.
export async function refreshProfileAccess(): Promise<ProfileRefreshResult> {
  const supabase = useSupabaseClient()
  const user = useSupabaseUser()
  const profile = useProfile()

  if (!user.value) {
    if (import.meta.client && !navigator.onLine && profile.value) {
      return { status: 'unavailable', profile: profile.value }
    }
    profile.value = null
    return { status: 'signed-out', profile: null }
  }

  const userId = user.value.id
  const current = profile.value?.id === userId ? profile.value : null
  if (import.meta.client && !navigator.onLine) {
    const cached = await cachedProfileFor(userId, current)
    if (cached) profile.value = cached
    return { status: 'unavailable', profile: cached }
  }

  const { data, error } = await supabase
    .from('profiles')
    .select('id, role, custom_role_key, full_name, avatar_url, patient_id, force_password_reset, active')
    .eq('id', userId)
    .maybeSingle()

  if (error) {
    const cached = await cachedProfileFor(userId, current)
    if (cached) profile.value = cached
    return { status: 'unavailable', profile: cached }
  }

  if (!data) {
    profile.value = null
    return { status: 'missing', profile: null }
  }

  profile.value = data as Profile
  if (!profile.value.active) return { status: 'revoked', profile: profile.value }

  if (import.meta.client) {
    try {
      await cacheProfileSnapshot(userId, profile.value)
    } catch {
      // The live profile is still valid if secure local storage is unavailable.
    }
  }
  return { status: 'active', profile: profile.value }
}

export async function loadProfile() {
  return (await refreshProfileAccess()).profile
}

export async function signOut() {
  const supabase = useSupabaseClient()
  const user = useSupabaseUser()
  const userId = user.value?.id
  const { pendingCount, flushQueue, clearUserState } = useSyncQueue()

  if (pendingCount.value > 0 && navigator.onLine) await flushQueue()
  if (
    pendingCount.value > 0
    && !window.confirm(`${pendingCount.value} offline change${pendingCount.value === 1 ? '' : 's'} will be discarded. Sign out anyway?`)
  ) return false

  await supabase.auth.signOut()
  if (userId) await clearUserState(userId)
  useProfile().value = null
  await navigateTo('/login')
  return true
}

export async function forceSignOut(reason = 'revoked') {
  const supabase = useSupabaseClient()
  const userId = useSupabaseUser().value?.id
  if (userId) await useSyncQueue().clearUserState(userId)
  await supabase.auth.signOut()
  useProfile().value = null
  await navigateTo(`/login?${encodeURIComponent(reason)}=1`)
}
