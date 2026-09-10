import React from 'react';
import { ComponentState } from '../../types';

export interface NeumorphicButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  active?: boolean;
  state?: ComponentState;
  size?: 'sm' | 'md' | 'lg';
  icon?: React.ReactNode;
  accentOnActive?: boolean;
}

export const NeumorphicButton: React.FC<NeumorphicButtonProps> = ({
  children,
  active = false,
  state = 'default',
  size = 'md',
  icon,
  accentOnActive = true,
  className = '',
  disabled,
  ...props
}) => {
  const isActuallyDisabled = disabled || state === 'disabled';
  const isSelected = active || state === 'selected';

  const sizeClasses = {
    sm: 'px-3 py-1.5 text-xs rounded-xl gap-1.5',
    md: 'px-4 py-2.5 text-sm rounded-2xl gap-2 font-medium',
    lg: 'px-6 py-3.5 text-base rounded-2xl gap-3 font-semibold',
  }[size];

  let baseSurfaceClass = 'surface-raised';
  if (isSelected || state === 'pressed') {
    baseSurfaceClass = 'surface-recessed surface-pressed';
  }

  let activeAccentStyle = '';
  if (isSelected && accentOnActive) {
    activeAccentStyle =
      'text-[var(--color-accent)] ring-1 ring-[var(--color-accent)]/50 shadow-[0_0_15px_-3px_var(--accent-glow)]';
  }

  const disabledClass = isActuallyDisabled
    ? 'opacity-40 cursor-not-allowed pointer-events-none'
    : 'cursor-pointer hover:-translate-y-0.5 active:translate-y-0';

  return (
    <button
      disabled={isActuallyDisabled}
      className={`inline-flex items-center justify-center transition-all duration-200 select-none focus-ring text-[var(--color-text-primary)] ${baseSurfaceClass} ${sizeClasses} ${activeAccentStyle} ${disabledClass} ${className}`}
      {...props}
    >
      {icon && <span className="flex-shrink-0">{icon}</span>}
      {children && <span>{children}</span>}
    </button>
  );
};
