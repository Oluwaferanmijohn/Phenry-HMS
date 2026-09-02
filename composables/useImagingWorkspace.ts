import type { SupabaseClient } from '@supabase/supabase-js'

type AppSupabaseClient = SupabaseClient<any, 'public', 'public', any, any>

export type ImagingFieldType = 'text' | 'textarea' | 'number' | 'select' | 'checkbox' | 'date'

export interface ImagingTemplateField {
  key: string
  label: string
  section: string
  type: ImagingFieldType
  unit?: string
  options?: string[]
  required?: boolean
}

export interface ImagingTemplate {
  id: string
  name: string
  category: string
  study_type: string
  description?: string | null
  fields: ImagingTemplateField[]
  created_by_profile_id?: string | null
  creator_name?: string
  system_template: boolean
  active: boolean
}

export interface ImagingStudy {
  id: string
  patient_id: string
  cycle_id?: string | null
  template_id: string
  template_name?: string
  template_fields?: ImagingTemplateField[]
  category: string
  study_type: string
  indication?: string | null
  approach?: string | null
  performed_at: string
  lmp?: string | null
  cycle_day?: number | null
  status: 'Draft' | 'Final' | 'Amended'
  technique?: string | null
  findings: Record<string, string | number | boolean | null>
  impression?: string | null
  recommendations?: string | null
  image_reference?: string | null
  amendment_reason?: string | null
  performed_by_profile_id?: string | null
  interpreted_by_profile_id?: string | null
  performed_by_name?: string
  interpreted_by_name?: string
}

export interface ImagingWorkspacePayload {
  templates: ImagingTemplate[]
  studies: ImagingStudy[]
}

export interface ImagingTemplateInput {
  id?: string | null
  name: string
  category: string
  studyType: string
  description: string
  fields: ImagingTemplateField[]
}

export interface ImagingStudyInput {
  id?: string | null
  patientId: string
  cycleId?: string | null
  templateId: string
  category: string
  studyType: string
  indication: string
  approach?: string | null
  performedAt: string
  lmp?: string | null
  cycleDay?: number | null
  technique: string
  findings: Record<string, string | number | boolean | null>
  impression: string
  recommendations: string
  imageReference: string
  amendmentReason?: string
  status: 'Draft' | 'Final' | 'Amended'
}

const emptyWorkspace = (): ImagingWorkspacePayload => ({ templates: [], studies: [] })

export async function fetchImagingWorkspace(
  supabase: AppSupabaseClient,
  patientId: string,
): Promise<ImagingWorkspacePayload> {
  const { data, error } = await supabase.rpc('imaging_workspace', { p_patient_id: patientId })
  if (error) throw error
  if (!data || typeof data !== 'object' || Array.isArray(data)) return emptyWorkspace()

  const payload = data as Record<string, unknown>
  return {
    templates: Array.isArray(payload.templates) ? payload.templates as ImagingTemplate[] : [],
    studies: Array.isArray(payload.studies) ? payload.studies as ImagingStudy[] : [],
  }
}

export async function fetchImagingHistory(
  supabase: AppSupabaseClient,
  patientId: string,
): Promise<ImagingStudy[]> {
  const { data, error } = await supabase.rpc('imaging_patient_history', { p_patient_id: patientId })
  if (error) throw error
  return Array.isArray(data) ? data as ImagingStudy[] : []
}

export async function saveImagingTemplate(
  supabase: AppSupabaseClient,
  input: ImagingTemplateInput,
): Promise<ImagingTemplate> {
  const { data, error } = await supabase.rpc('save_imaging_template', {
    p_id: input.id || null,
    p_name: input.name,
    p_category: input.category,
    p_study_type: input.studyType,
    p_description: input.description,
    p_fields: input.fields,
  })
  if (error) throw error
  return data as ImagingTemplate
}

export async function saveImagingStudy(
  supabase: AppSupabaseClient,
  input: ImagingStudyInput,
): Promise<ImagingStudy> {
  const { data, error } = await supabase.rpc('save_imaging_study', {
    p_id: input.id || null,
    p_patient_id: input.patientId,
    p_cycle_id: input.cycleId || null,
    p_template_id: input.templateId,
    p_category: input.category,
    p_study_type: input.studyType,
    p_indication: input.indication,
    p_approach: input.approach || null,
    p_performed_at: input.performedAt,
    p_lmp: input.lmp || null,
    p_cycle_day: input.cycleDay || null,
    p_technique: input.technique,
    p_findings: input.findings,
    p_impression: input.impression,
    p_recommendations: input.recommendations,
    p_image_reference: input.imageReference,
    p_status: input.status,
    p_amendment_reason: input.amendmentReason || null,
  })
  if (error) throw error
  return data as ImagingStudy
}
