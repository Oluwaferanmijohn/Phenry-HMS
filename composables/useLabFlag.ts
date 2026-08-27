// Reference ranges are entered as free text (LabTemplateManager's "Reference
// Range" field, or the ref_range field on cycle_investigations) — e.g.
// "3.5-12.5", "< 5", "≥ 40", "Negative". This parses the common clinical
// notations into numeric bounds so a result can be compared against them.
// Anything that doesn't match a recognized pattern (plain text like
// "Negative"/"Normal", or a bare number with no operator) returns null
// rather than guessing — an unflagged result stays unflagged rather than
// risk a false abnormal flag from a misparsed range.
export function parseRefBounds(ref: string | null | undefined): { low: number | null; high: number | null } | null {
  if (!ref) return null
  const trimmed = ref.trim()
  if (!trimmed) return null

  const upperOnly = trimmed.match(/^[<≤]\s*(-?\d+(?:\.\d+)?)/)
  if (upperOnly) return { low: null, high: Number(upperOnly[1]) }

  const lowerOnly = trimmed.match(/^[>≥]\s*(-?\d+(?:\.\d+)?)/)
  if (lowerOnly) return { low: Number(lowerOnly[1]), high: null }

  // Two numbers anywhere in the string, in either order, joined by a
  // dash/en-dash/"to"/"~" etc. — covers "3.5-12.5", "3.5 – 12.5", "3.5 to 12.5".
  const nums = trimmed.match(/-?\d+(?:\.\d+)?/g)
  if (nums && nums.length === 2) {
    const a = Number(nums[0])
    const b = Number(nums[1])
    return { low: Math.min(a, b), high: Math.max(a, b) }
  }

  return null
}

// Returns whether `value` falls outside `ref`. Non-numeric values (text
// results, blanks, "—") and reference ranges that don't parse both return
// false — same as the old hardcoded behavior, just no longer hardcoded for
// the cases that DO parse.
export function computeFlag(value: string | number | null | undefined, ref: string | null | undefined): boolean {
  if (value === null || value === undefined) return false
  const num = typeof value === 'number' ? value : parseFloat(String(value).replace(/,/g, ''))
  if (Number.isNaN(num)) return false

  const bounds = parseRefBounds(ref)
  if (!bounds) return false
  if (bounds.low !== null && num < bounds.low) return true
  if (bounds.high !== null && num > bounds.high) return true
  return false
}
