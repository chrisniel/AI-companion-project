import React from 'react';
import { BadgeVariant } from '../../types';

export interface BadgeProps extends React.HTMLAttributes<HTMLSpanElement> {
  variant?: BadgeVariant;
  size?: 'sm' | 'md';
  dot?: boolean;
  pulse?: boolean;
  icon?: React.ReactNode;
}

export const Badge: React.FC<BadgeProps> = ({
  children,
  variant = 'default',
  size = 'md',
  dot = false,
  pulse = false,
  icon,
  className = '',
  ...props
}) => {
  const sizeClasses = {
    sm: 'text-[10px] px-2 py-0.5 gap-1 font-semibold rounded-full tracking-wide',
    md: 'text-xs px-2.5 py-1 gap-1.5 font-medium rounded-full',
  }[size];

  let variantClasses = '';
  let dotColor = 'bg-current';

  switch (variant) {
    case 'default':
      variantClasses =
        'bg-[var(--color-surface-secondary)] text-[var(--color-text-secondary)] border border-[var(--color-border-subtle)]';
      dotColor = 'bg-[var(--color-text-secondary)]';
      break;
    case 'accent':
      variantClasses =
        'bg-[var(--color-accent)]/15 text-[var(--color-accent)] border border-[var(--color-accent)]/30 font-semibold';
      dotColor = 'bg-[var(--color-accent)]';
      break;
    case 'success':
      variantClasses =
        'bg-emerald-500/15 text-emerald-600 dark:text-emerald-400 border border-emerald-500/30 font-semibold';
      dotColor = 'bg-emerald-500';
      break;
    case 'warning':
      variantClasses =
        'bg-amber-500/15 text-amber-600 dark:text-amber-400 border border-amber-500/30 font-semibold';
      dotColor = 'bg-amber-500';
      break;
    case 'danger':
      variantClasses =
        'bg-rose-500/15 text-rose-600 dark:text-rose-400 border border-rose-500/30 font-semibold';
      dotColor = 'bg-rose-500';
      break;
    case 'glass':
      variantClasses =
        'glass-panel text-[var(--color-text-primary)] border border-[var(--color-surface-glass-border)]';
      dotColor = 'bg-[var(--color-accent)]';
      break;
    case 'neutral':
      variantClasses =
        'surface-raised text-[var(--color-text-secondary)] border border-[var(--color-border-subtle)]';
      dotColor = 'bg-[var(--color-text-muted)]';
      break;
  }

  return (
    <span
      className={`inline-flex items-center select-none whitespace-nowrap ${sizeClasses} ${variantClasses} ${className}`}
      {...props}
    >
      {dot && (
        <span className="relative flex h-2 w-2">
          {pulse && (
            <span
              className={`animate-ping absolute inline-flex h-full w-full rounded-full opacity-75 ${dotColor}`}
            />
          )}
          <span className={`relative inline-flex rounded-full h-2 w-2 ${dotColor}`} />
        </span>
      )}
      {icon && <span className="flex-shrink-0">{icon}</span>}
      <span>{children}</span>
    </span>
  );
};
