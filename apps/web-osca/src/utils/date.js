import { format, formatDistanceToNow, parseISO, isValid, differenceInYears } from 'date-fns'

export function fmtDate(d) {
  if (!d) return '—'
  try {
    const dt = typeof d === 'string' ? parseISO(d) : d
    return isValid(dt) ? format(dt, 'MMM d, yyyy') : '—'
  } catch { return '—' }
}

export function fmtDateTime(d) {
  if (!d) return '—'
  try {
    const dt = typeof d === 'string' ? parseISO(d) : d
    return isValid(dt) ? format(dt, 'MMM d, yyyy h:mm a') : '—'
  } catch { return '—' }
}

export function fmtRelative(d) {
  if (!d) return '—'
  try {
    const dt = typeof d === 'string' ? parseISO(d) : d
    return isValid(dt) ? formatDistanceToNow(dt, { addSuffix: true }) : '—'
  } catch { return '—' }
}

export function calcAge(dob) {
  if (!dob) return null
  try {
    const dt = typeof dob === 'string' ? parseISO(dob) : dob
    return isValid(dt) ? differenceInYears(new Date(), dt) : null
  } catch { return null }
}
