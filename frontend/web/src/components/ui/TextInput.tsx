import React, { forwardRef } from 'react';
import { AlertCircle, CheckCircle2 } from 'lucide-react';
import { ComponentState } from '../../types';

export interface TextInputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  helperText?: string;
  error?: string;
  state?: ComponentState;
  variant?: 'recessed' | 'glass';
  leftIcon?: React.ReactNode;
  rightIcon?: React.ReactNode;
}

export const TextInput = forwardRef<HTMLInputElement, TextInputProps>(
  (
    {
      label,
      helperText,
      error,
      state = 'default',
      variant = 'recessed',
      leftIcon,
      rightIcon,
      className = '',
      disabled,
      id,
      ...props
    },
    ref,
  ) => {
    const inputId = id || (label ? `input-${label.toLowerCase().replace(/\s+/g, '-')}` : undefined);
    const isError = error || state === 'error';
    const isSuccess = state === 'success';
    const isWarning = state === 'warning';
    const isDisabled = disabled || state === 'disabled';

    let surfaceClass =
      variant === 'recessed'
        ? 'surface-recessed border-[var(--color-border-subtle)]'
        : 'glass-panel border-[var(--color-surface-glass-border)]';

    if (isError) {
      surfaceClass += ' border-rose-500/80 focus:border-rose-500 ring-1 ring-rose-500/40';
    } else if (isSuccess) {
      surfaceClass += ' border-emerald-500/80 focus:border-emerald-500 ring-1 ring-emerald-500/40';
    } else if (isWarning) {
      surfaceClass += ' border-amber-500/80 focus:border-amber-500 ring-1 ring-amber-500/40';
    } else {
      surfaceClass += ' focus:border-[var(--color-accent)] focus:ring-2 focus:ring-[var(--color-accent)]/25';
    }

    return (
      <div className={`w-full flex flex-col gap-1.5 ${isDisabled ? 'opacity-45 pointer-events-none' : ''}`}>
        {label && (
          <label
            htmlFor={inputId}
            className="text-xs font-semibold text-[var(--color-text-secondary)] tracking-wide select-none"
          >
            {label}
          </label>
        )}

        <div className="relative flex items-center w-full">
          {leftIcon && (
            <div className="absolute left-3.5 flex items-center justify-center text-[var(--color-text-muted)] pointer-events-none">
              {leftIcon}
            </div>
          )}

          <input
            id={inputId}
            ref={ref}
            disabled={isDisabled}
            className={`w-full text-sm font-normal py-2.5 rounded-xl border text-[var(--color-text-primary)] placeholder-[var(--color-text-muted)] transition-all duration-150 outline-none ${surfaceClass} ${
              leftIcon ? 'pl-10' : 'pl-3.5'
            } ${rightIcon || isError || isSuccess ? 'pr-10' : 'pr-3.5'} ${className}`}
            {...props}
          />

          <div className="absolute right-3.5 flex items-center gap-1 text-[var(--color-text-muted)]">
            {isError && <AlertCircle className="w-4 h-4 text-rose-500" />}
            {isSuccess && <CheckCircle2 className="w-4 h-4 text-emerald-500" />}
            {rightIcon && !isError && !isSuccess && rightIcon}
          </div>
        </div>

        {(error || helperText) && (
          <p
            className={`text-xs mt-0.5 ${
              isError
                ? 'text-rose-500 font-medium'
                : isSuccess
                ? 'text-emerald-500'
                : 'text-[var(--color-text-muted)]'
            }`}
          >
            {error || helperText}
          </p>
        )}
      </div>
    );
  },
);

TextInput.displayName = 'TextInput';
