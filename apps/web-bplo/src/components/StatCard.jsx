import { TrendingUp, TrendingDown, Minus } from 'lucide-react'

export default function StatCard({ label, value, icon: Icon, color = 'blue', trend, loading }) {
  const colors = {
    blue:   'bg-gov-50 text-gov-700',
    yellow: 'bg-accent-50 text-accent-700',
    green:  'bg-success-50 text-success-700',
    red:    'bg-danger-50 text-danger-700',
    gray:   'bg-gray-100 text-gray-600',
  }

  if (loading) {
    return (
      <div className="card">
        <div className="skeleton h-4 w-24 mb-4" />
        <div className="skeleton h-8 w-16 mb-2" />
        <div className="skeleton h-3 w-20" />
      </div>
    )
  }

  return (
    <div className="card hover:shadow-card-hover transition-shadow duration-200">
      <div className="flex items-start justify-between">
        <div>
          <p className="text-xs font-medium text-gray-500 uppercase tracking-wider">{label}</p>
          <p className="font-heading font-bold text-3xl text-gray-900 mt-1">{value ?? '—'}</p>
          {trend != null && (
            <div className={`flex items-center gap-1 mt-1.5 text-xs font-medium ${
              trend > 0 ? 'text-success-700' : trend < 0 ? 'text-danger-600' : 'text-gray-500'
            }`}>
              {trend > 0 ? <TrendingUp className="w-3 h-3" /> :
               trend < 0 ? <TrendingDown className="w-3 h-3" /> :
               <Minus className="w-3 h-3" />}
              {Math.abs(trend)}% vs last week
            </div>
          )}
        </div>
        {Icon && (
          <div className={`w-10 h-10 rounded-xl flex items-center justify-center ${colors[color]}`}>
            <Icon className="w-5 h-5" />
          </div>
        )}
      </div>
    </div>
  )
}
