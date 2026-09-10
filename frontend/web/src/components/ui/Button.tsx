import React from 'react';
import { Loader2, Check, AlertTriangle, XCircle } from 'lucide-react';
import { ButtonSize, ButtonVariant, ComponentState } from '../../types';

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  size?: ButtonSize;
  state?: ComponentState;
  isLoading?: boolean;
  leftIcon?: React.ReactNode;
  rightIcon?: React.ReactNode;
  fullWidth?: boolean;
}

export const Button: React.FC<ButtonProps> = ({
  children,
  variant = 'primary',
  size = 'md',
  state = 'default',
  isLoading = false,
  leftIcon,
  rightIcon,
  fullWidth = false,
  className = '',
  disabled,
  ...props
}) => {
  const isActuallyDisabled = disabled || state === 'disabled' || isLoading;
  const isActuallyLoading = isLoading || state === 'loading';

  // Size sizing
  const sizeClasses = {
    sm: 'px-3 py-1.5 text-xs rounded-lg gap-1.5 font-medium',
    md: 'px-4 py-2 text-sm rounded-xl gap-2 font-medium',
    lg: 'px-6 py-3 text-base rounded-2xl gap-2.5 font-semibold',
  }[size];

  // Variant base
  let variantClasses = '';
  switch (variant) {
    case 'primary':
      variantClasses =
        'bg-accent-gradient text-white shadow-soft-outer hover:opacity-95 active:scale-[0.98] glow-accent-sm border border-white/20';
      break;
    case 'secondary':
      variantClasses =
        'surface-raised text-[var(--color-text-primary)] hover:border-[var(--color-accent)]/40 active:scale-[0.98]';
      break;
    case 'neumorphic':
      variantClasses =
        'surface-raised text-[var(--color-text-primary)] active:surface-pressed active:translate-y-0.5';
      break;
    case 'ghost':
      variantClasses =
        'bg-transparent text-[var(--color-text-primary)] hover:bg-[var(--color-surface-secondary)]/50 active:bg-[var(--color-surface-secondary)]';
      break;
    case 'danger':
      variantClasses =
        'bg-[var(--color-danger)] text-white hover:bg-[var(--color-danger)]/90 active:scale-[0.98] shadow-sm';
      break;
  }

  // State override classes
  let stateClasses = '';
  if (state === 'pressed') {
    stateClasses = 'surface-pressed scale-[0.98]';
  } else if (state === 'selected') {
    stateClasses =
      'ring-2 ring-[var(--color-accent)] border-transparent bg-gradient-to-r from-[var(--color-accent)]/15 to-[var(--color-accent-secondary)]/15 text-[var(--color-accent)] font-semibold';
  } else if (state === 'focused') {
    stateClasses = 'ring-2 ring-[var(--color-accent)] ring-offset-2 ring-offset-[var(--color-app-bg)]';
  } else if (state === 'hover') {
    stateClasses = 'brightness-105 -translate-y-0.5';
  } else if (state === 'success') {
    stateClasses =
      'bg-emerald-500/15 text-emerald-600 dark:text-emerald-400 border border-emerald-500/30';
  } else if (state === 'warning') {
    stateClasses =
      'bg-amber-500/15 text-amber-600 dark:text-amber-400 border border-amber-500/30';
  } else if (state === 'error') {
    stateClasses =
      'bg-rose-500/15 text-rose-600 dark:text-rose-400 border border-rose-500/30';
  }

  // Disabled
  const disabledClasses = isActuallyDisabled
    ? 'opacity-45 cursor-not-allowed pointer-events-none shadow-none transform-none'
    : 'cursor-pointer';

  return (
    <button
      disabled={isActuallyDisabled}
      className={`relative inline-flex items-center justify-center transition-all duration-150 select-none focus-ring ${sizeClasses} ${variantClasses} ${stateClasses} ${disabledClasses} ${
        fullWidth ? 'w-full' : ''
      } ${className}`}
      {...props}
    >
      {isActuallyLoading && <Loader2 className="w-4 h-4 animate-spin text-current" />}
      {!isActuallyLoading && state === 'success' && <Check className="w-4 h-4 text-emerald-500" />}
      {!isActuallyLoading && state === 'warning' && (
        <AlertTriangle className="w-4 h-4 text-amber-500" />
      )}
      {!isActuallyLoading && state === 'error' && <XCircle className="w-4 h-4 text-rose-500" />}

      {!isActuallyLoading && !['success', 'warning', 'error'].includes(state) && leftIcon}
      <span>{children}</span>
      {!isActuallyLoading && rightIcon}
    </button>
  );
};
