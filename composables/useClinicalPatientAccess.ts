import type { SupabaseClient } from '@supabase/supabase-js'

type AppSupabaseClient = SupabaseClient<any, 'public', 'public', any, any>

interface ClinicalPatientDirectoryPayload {
  patients: any[]
  activeCycles: any[]
}

export interface ClinicalPatientContextPayload {
  patient: any | null
  cycle: any | null
  cycleManagerName: string
  prescriptions: any[]
  pastConsultations: any[]
  pastLabResults: any[]
  pendingOrders: any[]
  investigations: any[]
  ultrasound: any | null
}

const emptyDirectory = (): ClinicalPatientDirectoryPayload => ({
  patients: [],
  activeCycles: [],
})

const emptyContext = (): ClinicalPatientContextPayload => ({
  patient: null,
  cycle: null,
  cycleManagerName: '',
  prescriptions: [],
  pastConsultations: [],
  pastLabResults: [],
  pendingOrders: [],
  investigations: [],
  ultrasound: null,
})

// These reads intentionally go through the role-scoped database API added in
// migration 21. Table RLS remains active for every other operation, while the
// multi-table page bootstrap has one authorization decision and one failure
// boundary instead of several independent PostgREST requests.
export async function fetchClinicalPatientDirectory(
  supabase: AppSupabaseClient,
): Promise<ClinicalPatientDirectoryPayload> {
  const { data, error } = await supabase.rpc('clinical_patient_directory')
  if (error) {
    // Keep the shared patient page usable while an older database is still
    // missing the directory RPC or PostgREST is refreshing its schema cache.
    // RLS still applies to both reads; this is not a permission bypass.
    const [patientsResult, cyclesResult] = await Promise.all([
      supabase.from('patient_names').select('patient_id, first_name, surname, full_name, bio_details(dob, sex, status)').order('full_name'),
      supabase.from('cycles').select('*').neq('status', 'Closed').order('start_date', { ascending: false }),
    ])
    if (patientsResult.error && cyclesResult.error) throw error
    const patients = (patientsResult.data || []).map((row: any) => ({ ...row, ...(Array.isArray(row.bio_details) ? row.bio_details[0] : row.bio_details || {}) }))
    return { patients, activeCycles: cyclesResult.data || [] }
  }
  if (!data || typeof data !== 'object' || Array.isArray(data)) return emptyDirectory()

  const payload = data as Record<string, unknown>
  return {
    patients: Array.isArray(payload.patients) ? payload.patients : [],
    activeCycles: Array.isArray(payload.activeCycles) ? payload.activeCycles : [],
  }
}

export async function fetchClinicalPatientContext(
  supabase: AppSupabaseClient,
  patientId: string,
): Promise<ClinicalPatientContextPayload> {
  const { data, error } = await supabase.rpc('clinical_patient_context', {
    p_patient_id: patientId,
  })
  if (error) throw error
  if (!data || typeof data !== 'object' || Array.isArray(data)) return emptyContext()

  const payload = data as Record<string, unknown>
  return {
    patient: payload.patient && typeof payload.patient === 'object' ? payload.patient : null,
    cycle: payload.cycle && typeof payload.cycle === 'object' ? payload.cycle : null,
    cycleManagerName: typeof payload.cycleManagerName === 'string' ? payload.cycleManagerName : '',
    prescriptions: Array.isArray(payload.prescriptions) ? payload.prescriptions : [],
    pastConsultations: Array.isArray(payload.pastConsultations) ? payload.pastConsultations : [],
    pastLabResults: Array.isArray(payload.pastLabResults) ? payload.pastLabResults : [],
    pendingOrders: Array.isArray(payload.pendingOrders) ? payload.pendingOrders : [],
    investigations: Array.isArray(payload.investigations) ? payload.investigations : [],
    ultrasound: payload.ultrasound && typeof payload.ultrasound === 'object' ? payload.ultrasound : null,
  }
}
