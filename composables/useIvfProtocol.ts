export interface BlankCycleDay {
  id: string
  cycle_id: string
  day: number
  date: string
  phase: string | null
  medication: string | null
  milestone: string | null
  medication_administered: boolean
  vitals_logged: boolean
  note: string | null
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
    phase: null,
    medication: null,
    milestone: null,
    medication_administered: false,
    vitals_logged: false,
    note: null,
  }))
}

export function nextBlankCycleDay(cycleId: string, startDate: string, currentDays: number[]) {
  const next = Math.max(0, ...currentDays) + 1
  return createBlankCycleDays(cycleId, addDays(startDate, next - 1), 1).map((row) => ({ ...row, day: next }))[0]!
}
