import { cn } from '@/lib/utils'

interface CardProps {
  className?: string
  children: React.ReactNode
}

export const Card = ({ className, children }: CardProps) => {
  return (
    <div className={cn('rounded-xl border border-slate-200 bg-white text-slate-950 shadow-sm', className)}>
      {children}
    </div>
  )
}

export const CardHeader = ({ className, children }: CardProps) => {
  return (
    <div className={cn('flex flex-col space-y-1.5 p-6', className)}>
      {children}
    </div>
  )
}

export const CardTitle = ({ className, children }: CardProps) => {
  return (
    <h3 className={cn('text-2xl font-semibold leading-none tracking-tight', className)}>
      {children}
    </h3>
  )
}

export const CardContent = ({ className, children }: CardProps) => {
  return (
    <div className={cn('p-6 pt-0', className)}>
      {children}
    </div>
  )
}

