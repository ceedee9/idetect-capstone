import { Circle } from 'lucide-react'

const STATUS_MAP = {
  pending:   { className: 'badge-pending',   label: 'Pending'   },
  approved:  { className: 'badge-approved',  label: 'Approved'  },
  suspended: { className: 'badge-suspended', label: 'Suspended' },
  revoked:   { className: 'badge-revoked',   label: 'Revoked'   },
}

export default function StatusBadge({ status }) {
  const config = STATUS_MAP[status] ?? { className: 'badge-revoked', label: status }
  return (
    <span className={config.className}>
      <Circle className="w-1.5 h-1.5 fill-current" />
      {config.label}
    </span>
  )
}
