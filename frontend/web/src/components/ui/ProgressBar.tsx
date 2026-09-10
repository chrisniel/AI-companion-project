import React from 'react';

export interface ProgressBarProps {
  value: number;
  max?: number;
  label?: string;
  showValue?: boolean;
  unit?: string;
  size?: 'sm' | 'md' | 'lg';
  variant?: 'accent' | 'success' | 'warning' | 'danger';
  className?: string;
}

export const ProgressBar: React.FC<ProgressBarProps> = ({
  value,
  max = 100,
  label,
  showValue = true,
  unit = '%',
  size = 'md',
  variant = 'accent',
  className = '',
}) => {
  const percentage = Math.min(Math.max((value / max) * 100, 0), 100);

  const heightClasses = {
    sm: 'h-1.5',
    md: 'h-2.5',
    lg: 'h-4',
  }[size];

  let barGradient = 'bg-accent-gradient';
  if (variant === 'success') {
    barGradient = 'bg-emerald-500';
  } else if (variant === 'warning') {
    barGradient = 'bg-amber-500';
  } else if (variant === 'danger') {
    barGradient = 'bg-rose-500';
  }

  return (
    <div className={`w-full flex flex-col gap-1.5 ${className}`}>
      {(label || showValue) && (
        <div className="flex items-center justify-between text-xs">
          {label && (
            <span className="font-medium text-[var(--color-text-secondary)]">{label}</span>
          )}
          {showValue && (
            <span className="font-mono font-semibold text-[var(--color-text-primary)]">
              {Math.round(percentage)}
              {unit}
            </span>
          )}
        </div>
      )}

      {/* Recessed Track */}
      <div
        role="progressbar"
        aria-valuenow={value}
        aria-valuemin={0}
        aria-valuemax={max}
        className={`w-full rounded-full surface-recessed border border-[var(--color-border-subtle)] overflow-hidden relative p-0.5 ${heightClasses}`}
      >
        <div
          className={`h-full rounded-full transition-all duration-300 ${barGradient}`}
          style={{ width: `${percentage}%` }}
        />
      </div>
    </div>
  );
};
