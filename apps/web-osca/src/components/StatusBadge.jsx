import { Circle } from 'lucide-react'

const MAP = {
  active:    { cls: 'badge-active',    label: 'Active'    },
  inactive:  { cls: 'badge-inactive',  label: 'Inactive'  },
  suspended: { cls: 'badge-suspended', label: 'Suspended' },
  expired:   { cls: 'badge-expired',   label: 'Expired'   },
  revoked:   { cls: 'badge-revoked',   label: 'Revoked'   },
  pending:   { cls: 'badge-pending',   label: 'Pending'   },
}

export default function StatusBadge({ status }) {
  const cfg = MAP[status?.toLowerCase()] ?? { cls: 'badge-inactive', label: status ?? '—' }
  return (
    <span className={cfg.cls}>
      <Circle className="w-1.5 h-1.5 fill-current" />
      {cfg.label}
    </span>
  )
}
