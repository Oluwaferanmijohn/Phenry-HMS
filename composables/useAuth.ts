// Central place every page/layout/middleware reads "who is logged in and
// what role are they" from. Wraps @nuxtjs/supabase's useSupabaseUser() with
// a fetch of the matching profiles row (role, patient_id, force_password_reset).
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

export async function loadProfile() {
  const supabase = useSupabaseClient()
  const user = useSupabaseUser()
  const profile = useProfile()

  if (!user.value) {
    profile.value = null
    return null
  }

  const { data, error } = await supabase
    .from('profiles')
    .select('id, role, custom_role_key, full_name, avatar_url, patient_id, force_password_reset, active')
    .eq('id', user.value.id)
    .single()

  if (error) {
    profile.value = null
    return null
  }

  profile.value = data as Profile
  return profile.value
}

export async function signOut() {
  const supabase = useSupabaseClient()
  await supabase.auth.signOut()
  useProfile().value = null
  await navigateTo('/login')
}
