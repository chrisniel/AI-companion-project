import React from 'react';
import { ComponentState } from '../../types';

export interface IconButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  icon: React.ReactNode;
  'aria-label': string;
  variant?: 'neumorphic' | 'glass' | 'ghost' | 'accent';
  size?: 'sm' | 'md' | 'lg';
  state?: ComponentState;
  active?: boolean;
}

export const IconButton: React.FC<IconButtonProps> = ({
  icon,
  'aria-label': ariaLabel,
  variant = 'neumorphic',
  size = 'md',
  state = 'default',
  active = false,
  className = '',
  disabled,
  ...props
}) => {
  const isActuallyDisabled = disabled || state === 'disabled';

  const sizeClasses = {
    sm: 'w-8 h-8 rounded-lg p-1.5',
    md: 'w-10 h-10 rounded-xl p-2',
    lg: 'w-12 h-12 rounded-2xl p-3',
  }[size];

  let variantClasses = '';
  switch (variant) {
    case 'neumorphic':
      variantClasses =
        'surface-raised text-[var(--color-text-primary)] hover:border-[var(--color-accent)]/40 active:surface-pressed active:translate-y-0.5';
      break;
    case 'glass':
      variantClasses =
        'glass-panel text-[var(--color-text-primary)] hover:bg-[var(--color-surface-glass-border)]/20 active:scale-95';
      break;
    case 'ghost':
      variantClasses =
        'bg-transparent text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)] hover:bg-[var(--color-surface-secondary)]/50 active:bg-[var(--color-surface-secondary)]';
      break;
    case 'accent':
      variantClasses =
        'bg-accent-gradient text-white glow-accent-sm shadow-soft-outer hover:opacity-90 active:scale-95';
      break;
  }

  const activeClasses =
    active || state === 'selected'
      ? 'ring-2 ring-[var(--color-accent)] text-[var(--color-accent)] bg-[var(--color-accent)]/10 font-bold'
      : '';

  const disabledClasses = isActuallyDisabled
    ? 'opacity-40 cursor-not-allowed pointer-events-none'
    : 'cursor-pointer';

  return (
    <button
      aria-label={ariaLabel}
      title={ariaLabel}
      disabled={isActuallyDisabled}
      className={`inline-flex items-center justify-center transition-all duration-150 select-none focus-ring ${sizeClasses} ${variantClasses} ${activeClasses} ${disabledClasses} ${className}`}
      {...props}
    >
      <span className="flex items-center justify-center pointer-events-none">
        {icon}
      </span>
    </button>
  );
};
