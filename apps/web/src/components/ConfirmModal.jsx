import { X, AlertTriangle, Loader2 } from 'lucide-react'
import { createPortal } from 'react-dom'

export default function ConfirmModal({ open, onClose, onConfirm, title, description, confirmLabel = 'Confirm', variant = 'danger', loading = false, confirmDisabled = false, children }) {
  if (!open) return null
  return createPortal(
    <div className="fixed inset-0 z-[100] flex items-center justify-center p-4">
      <div className="absolute inset-0 bg-black/40 backdrop-blur-sm" onClick={!loading ? onClose : undefined} />
      <div className="relative bg-white rounded-2xl shadow-card-lg w-full max-w-lg max-h-[calc(100vh-2rem)] overflow-y-auto p-6">
        <button onClick={onClose} disabled={loading} className="absolute top-4 right-4 text-slate-400 hover:text-slate-600 disabled:opacity-50">
          <X className="w-5 h-5" />
        </button>
        <div className="flex items-start gap-4 mb-4">
          <div className={`w-10 h-10 rounded-2xl flex items-center justify-center flex-shrink-0 ${variant === 'danger' ? 'bg-danger-50' : variant === 'warn' ? 'bg-warn-50' : 'bg-gov-50'}`}>
            <AlertTriangle className={`w-5 h-5 ${variant === 'danger' ? 'text-danger-600' : variant === 'warn' ? 'text-warn-700' : 'text-gov-600'}`} />
          </div>
          <div className="min-w-0 flex-1">
            <h3 className="font-heading font-bold text-slate-900">{title}</h3>
            <p className="text-sm text-slate-600 mt-2 leading-6">{description}</p>
          </div>
        </div>
        {children && <div className="mb-4">{children}</div>}
        <div className="flex gap-3 justify-end">
          <button onClick={onClose} disabled={loading} className="btn-secondary">Cancel</button>
          <button onClick={onConfirm} disabled={loading || confirmDisabled}
            className={variant === 'danger' ? 'btn-danger' : 'btn-primary'}>
            {loading && <Loader2 className="w-4 h-4 animate-spin" />}
            {confirmLabel}
          </button>
        </div>
      </div>
    </div>,
    document.body,
  )
}
