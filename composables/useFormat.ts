export function fmtNaira(n: number | string | null | undefined) {
  if (n === null || n === undefined) return '—'
  return '₦' + Number(n).toLocaleString('en-NG')
}

export function fmtDate(d: string | Date | null | undefined) {
  if (!d) return '—'
  const dt = typeof d === 'string' ? new Date(d) : d
  if (isNaN(dt.getTime())) return String(d)
  return dt.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
}

export function initials(name: string | null | undefined) {
  if (!name) return '?'
  return name.split(' ').map((w) => w[0]).slice(0, 2).join('').toUpperCase()
}

// Accepts a Postgres `time` string ("14:30:00" or "14:30") and formats 12h.
export function formatTime12(t: string | null | undefined) {
  if (!t) return '—'
  const [hStr, mStr] = t.split(':')
  const h = Number(hStr)
  const m = Number(mStr)
  const period = h >= 12 ? 'PM' : 'AM'
  const h12 = h % 12 === 0 ? 12 : h % 12
  return `${h12}:${String(m).padStart(2, '0')} ${period}`
}

export function computeAge(dob: string | null | undefined) {
  if (!dob) return '—'
  const b = new Date(dob)
  if (isNaN(b.getTime())) return '—'
  const t = new Date()
  let age = t.getFullYear() - b.getFullYear()
  const m = t.getMonth() - b.getMonth()
  if (m < 0 || (m === 0 && t.getDate() < b.getDate())) age--
  return age
}

const STATUS_TONE: Record<string, string> = {
  Paid: 'green', 'Approved & Dispensed': 'green', Completed: 'green', Active: 'green', Pass: 'green', Positive: 'green', Free: 'green', Dispensed: 'green',
  Pending: 'amber', 'Pending Verification': 'amber', 'Pending Approval': 'amber', Upcoming: 'gray', Scheduled: 'blue', Waiting: 'amber', 'In Progress': 'blue', 'In Room': 'blue',
  Urgent: 'red', Emergency: 'red', Fail: 'red', Critical: 'red', Negative: 'red', Occupied: 'red', Offboarded: 'gray', Closed: 'gray', 'Not Checked': 'gray',
  Routine: 'blue', 'Low Stock': 'amber', Adequate: 'green', 'Denied / Out of Stock': 'red', Reserved: 'amber',
}
export function statusTone(status: string | null | undefined) {
  return (status && STATUS_TONE[status]) || 'gray'
}
