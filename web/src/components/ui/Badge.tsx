import { cn } from '@/lib/utils'

interface BadgeProps {
  variant?: 'default' | 'destructive' | 'secondary' | 'success' | 'warning' | 'outline'
  className?: string
  children: React.ReactNode
}

export const Badge = ({ variant = 'default', className, children }: BadgeProps) => {
  const variants = {
    default: 'bg-primary hover:bg-primary/80 text-primary-foreground',
    destructive: 'bg-red-500 hover:bg-red-600 text-white',
    secondary: 'bg-slate-100 hover:bg-slate-200 text-slate-900',
    success: 'bg-green-100 hover:bg-green-200 text-green-800',
    warning: 'bg-yellow-100 hover:bg-yellow-200 text-yellow-800',
    outline: 'border border-slate-200 text-slate-900',
  }

  return (
    <div className={cn('inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold transition-colors focus:outline-none focus:ring-2 focus:ring-slate-400 focus:ring-offset-2', variants[variant], className)}>
      {children}
    </div>
  )
}

