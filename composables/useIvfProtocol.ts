export interface BlankCycleDay {
  id: string
  cycle_id: string
  day: number
  date: string
  phase: string
  phase_key: 'down_regulation' | 'stimulation' | 'procedure' | 'other'
  phase_day: number
  medication: string | null
  milestone: string | null
  medication_administered: boolean
  vitals_logged: boolean
  note: string | null
  action_status: 'Planned' | 'Administered' | 'Completed' | 'Held' | 'Missed' | 'Changed'
  actual_medication: string | null
  change_reason: string | null
}

function addDays(date: string, offset: number) {
  const parsed = new Date(`${date}T00:00:00Z`)
  if (Number.isNaN(parsed.getTime())) throw new Error('A valid cycle start date is required')
  parsed.setUTCDate(parsed.getUTCDate() + offset)
  return parsed.toISOString().slice(0, 10)
}

// This intentionally creates a blank chart, not a medication protocol.
// Drug, dose, timing, trigger, OPU, transfer, and monitoring decisions must
// be entered/approved by the treating clinical team for the individual.
export function createBlankCycleDays(cycleId: string, startDate: string, count = 14): BlankCycleDay[] {
  const safeCount = Math.min(45, Math.max(1, Math.trunc(count)))
  return Array.from({ length: safeCount }, (_, index) => ({
    id: crypto.randomUUID(),
    cycle_id: cycleId,
    day: index + 1,
    date: addDays(startDate, index),
    // The production schema requires phase to be non-null. An empty string
    // represents an intentionally blank clinician-authored day, while still
    // avoiding any generated treatment recommendation.
    phase: '',
    phase_key: 'other',
    phase_day: index + 1,
    medication: null,
    milestone: null,
    medication_administered: false,
    vitals_logged: false,
    note: null,
    action_status: 'Planned',
    actual_medication: null,
    change_reason: null,
  }))
}

export function nextBlankCycleDay(cycleId: string, startDate: string, currentDays: number[]) {
  const next = Math.max(0, ...currentDays) + 1
  return createBlankCycleDays(cycleId, addDays(startDate, next - 1), 1).map((row) => ({ ...row, day: next }))[0]!
}

export function nextPhaseCycleDay(cycleId: string, startDate: string, rows: Array<{ day: number; phase_day?: number; phase_key?: BlankCycleDay['phase_key'] }>) {
  const sequenceDay = Math.max(0, ...rows.map((row) => row.day)) + 1
  const latest = [...rows].sort((a, b) => b.day - a.day)[0]
  const phaseKey = latest?.phase_key || 'stimulation'
  const phaseDay = Number(latest?.phase_day || 0) + 1
  return {
    ...createBlankCycleDays(cycleId, addDays(startDate, sequenceDay - 1), 1)[0]!,
    day: sequenceDay,
    phase_key: phaseKey,
    phase_day: phaseDay,
    phase: phaseKey === 'down_regulation' ? 'Down-Regulation' : phaseKey === 'stimulation' ? 'Stimulation' : 'Other',
  }
}
