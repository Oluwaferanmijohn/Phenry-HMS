// Supabase Auth's password sign-in is fundamentally email-shaped — there's
// no "arbitrary username" mode. "Log in with Patient ID + surname" is
// implemented as a synthetic, non-deliverable email built from the patient
// ID, used purely as the Auth identifier and never shown to the patient.
// Shared between the login page (builds this to call signInWithPassword)
// and server/api/receptionist/create-patient-account.post.ts (builds the
// exact same thing when creating the account) — kept in one place so the
// two can't drift out of sync.
export function patientLoginEmail(patientId: string): string {
  return `${patientId.trim().toLowerCase()}@patient.phenryhealth.internal`
}
