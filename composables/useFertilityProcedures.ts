const FERTILITY_PROCEDURE_PATTERNS = [
  /\bopu\b/i,
  /oocyte (pick[- ]?up|retrieval|collection|freez|cryopreserv)/i,
  /egg (retrieval|collection|freez|cryopreserv)/i,
  /embryo (transfer|freez|cryopreserv|thaw|warm)/i,
  /\bfet\b/i,
  /frozen embryo transfer/i,
  /\biui\b/i,
  /intrauterine insemination/i,
  /sperm (freez|cryopreserv|thaw|preparation|retrieval)/i,
  /semen (freez|cryopreserv|preparation)/i,
  /\b(tese|tesa|pesa|mesa|micro[- ]?tese)\b/i,
]

export function isFertilityLabProcedure(value: string | null | undefined) {
  const label = String(value || '').trim()
  return label !== '' && FERTILITY_PROCEDURE_PATTERNS.some(pattern => pattern.test(label))
}

export function procedureSupportsCryo(value: string | null | undefined) {
  const label = String(value || '')
  return /(opu|retrieval|freez|cryopreserv)/i.test(label)
}

export function procedureCategory(value: string | null | undefined): 'opu' | 'transfer' | 'iui' | 'sperm' | 'freezing' | 'other' {
  const label = String(value || '').toLowerCase()
  if (/\bopu\b|oocyte pick|egg retrieval|oocyte retrieval/.test(label)) return 'opu'
  if (/embryo transfer|\bfet\b/.test(label)) return 'transfer'
  if (/\biui\b|intrauterine insemination/.test(label)) return 'iui'
  if (/sperm|semen|\b(tese|tesa|pesa|mesa|micro-tese)\b/.test(label)) return 'sperm'
  if (/freez|cryopreserv|thaw|warm/.test(label)) return 'freezing'
  return 'other'
}
