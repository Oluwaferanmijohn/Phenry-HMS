// Central place every page/layout/middleware reads "who is logged in and
// what role are they" from. Wraps @nuxtjs/supabase's useSupabaseUser() with
// a fetch of the matching profiles row (role, patient_id, force_password_reset).
import { cacheProfileSnapshot, getCachedProfileSnapshot } from '~/composables/useOfflineDb'

const LAST_CONFIRMED_USER_KEY = 'phenry-health:last-confirmed-user-id'

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

export const useLastConfirmedUserId = () =>
  useState<string | null>('last-confirmed-user-id', () => null)

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

function lastConfirmedUserId() {
  const remembered = useLastConfirmedUserId()
  if (!remembered.value && import.meta.client) {
    try {
      remembered.value = window.localStorage.getItem(LAST_CONFIRMED_USER_KEY)
    } catch {
      // Private browsing/storage restrictions must not break normal auth.
    }
  }
  return remembered.value
}

function rememberConfirmedUser(userId: string) {
  useLastConfirmedUserId().value = userId
  if (!import.meta.client) return
  try {
    window.localStorage.setItem(LAST_CONFIRMED_USER_KEY, userId)
  } catch {
    // The in-memory profile still keeps this tab usable.
  }
}

function forgetConfirmedUser() {
  useLastConfirmedUserId().value = null
  if (!import.meta.client) return
  try {
    window.localStorage.removeItem(LAST_CONFIRMED_USER_KEY)
  } catch {
    // Storage may already have been cleared by the browser.
  }
}

// Restore only a profile which was previously confirmed by the server and is
// still inside the encrypted cache's expiry window. The UUID pointer contains
// no clinical data; it only lets us locate the user-scoped encrypted record
// after Supabase temporarily publishes a null user during a failed refresh.
export async function restoreLastConfirmedProfile(): Promise<Profile | null> {
  const profile = useProfile()
  if (profile.value?.active) return profile.value
  if (!import.meta.client) return null
  const userId = lastConfirmedUserId()
  if (!userId) return null
  const cached = await cachedProfileFor(userId, profile.value)
  if (cached) profile.value = cached
  return cached
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
    // `navigator.onLine` is advisory and frequently remains true after Wi-Fi
    // loses upstream access. Never destroy a confirmed identity merely because
    // Supabase's reactive user is temporarily null; explicit/confirmed sign-out
    // paths below are responsible for clearing it.
    const cached = await restoreLastConfirmedProfile()
    if (cached) return { status: 'unavailable', profile: cached }
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
    rememberConfirmedUser(userId)
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
  const userId = user.value?.id || useProfile().value?.id || lastConfirmedUserId()
  const { pendingCount, flushQueue, clearUserState } = useSyncQueue()

  if (pendingCount.value > 0 && navigator.onLine) await flushQueue()
  if (
    pendingCount.value > 0
    && !window.confirm(`${pendingCount.value} offline change${pendingCount.value === 1 ? '' : 's'} will be discarded. Sign out anyway?`)
  ) return false

  await supabase.auth.signOut()
  if (userId) await clearUserState(userId)
  useProfile().value = null
  forgetConfirmedUser()
  await navigateTo('/login')
  return true
}

export async function forceSignOut(reason = 'revoked') {
  const supabase = useSupabaseClient()
  const userId = useSupabaseUser().value?.id || useProfile().value?.id || lastConfirmedUserId()
  if (userId) await useSyncQueue().clearUserState(userId)
  await supabase.auth.signOut()
  useProfile().value = null
  forgetConfirmedUser()
  await navigateTo(`/login?${encodeURIComponent(reason)}=1`)
}
