import { format, formatDistanceToNow, parseISO, isValid, differenceInYears } from 'date-fns'

export const fmtDate     = d => { try { const dt = typeof d === 'string' ? parseISO(d) : d; return isValid(dt) ? format(dt, 'MMM d, yyyy') : '—' } catch { return '—' } }
export const fmtDateTime = d => { try { const dt = typeof d === 'string' ? parseISO(d) : d; return isValid(dt) ? format(dt, 'MMM d, yyyy h:mm a') : '—' } catch { return '—' } }
export const fmtRelative = d => { try { const dt = typeof d === 'string' ? parseISO(d) : d; return isValid(dt) ? formatDistanceToNow(dt, { addSuffix: true }) : '—' } catch { return '—' } }
export const calcAge     = d => { try { const dt = typeof d === 'string' ? parseISO(d) : d; return isValid(dt) ? differenceInYears(new Date(), dt) : null } catch { return null } }
