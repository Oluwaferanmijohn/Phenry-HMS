const PHOTO_BUCKET = 'patient-photos'
const MAX_PHOTO_SIZE = 5 * 1024 * 1024
const PHOTO_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp'])

export function validatePatientPhoto(file: File) {
  if (!PHOTO_TYPES.has(file.type)) return 'Use a JPEG, PNG, or WebP image.'
  if (file.size > MAX_PHOTO_SIZE) return 'The patient picture must be 5 MB or smaller.'
  return ''
}

export async function fetchPatientPhotoUrl(supabase: any, patientId: string) {
  if (!patientId) return ''
  const { data: path, error: pathError } = await supabase.rpc('patient_photo_path', { p_patient_id: patientId })
  if (pathError || !path) return ''
  const { data, error } = await supabase.storage.from(PHOTO_BUCKET).createSignedUrl(path, 60 * 60)
  return error ? '' : data?.signedUrl || ''
}

export async function uploadPatientPhoto(supabase: any, patientId: string, file: File) {
  const validationError = validatePatientPhoto(file)
  if (validationError) throw new Error(validationError)

  const extension = file.type === 'image/png' ? 'png' : file.type === 'image/webp' ? 'webp' : 'jpg'
  const path = `${patientId}/${crypto.randomUUID()}.${extension}`
  const { error: uploadError } = await supabase.storage.from(PHOTO_BUCKET).upload(path, file, {
    contentType: file.type,
    upsert: false,
  })
  if (uploadError) throw uploadError

  const { data: oldPath, error: attachError } = await supabase.rpc('set_patient_photo', {
    p_patient_id: patientId,
    p_photo_path: path,
  })
  if (attachError) {
    await supabase.storage.from(PHOTO_BUCKET).remove([path])
    throw attachError
  }
  if (oldPath && oldPath !== path) await supabase.storage.from(PHOTO_BUCKET).remove([oldPath])
  return fetchPatientPhotoUrl(supabase, patientId)
}
