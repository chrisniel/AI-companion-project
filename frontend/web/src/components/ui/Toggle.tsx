import React from 'react';

export interface ToggleProps {
  checked: boolean;
  onChange: (checked: boolean) => void;
  label?: string;
  description?: string;
  disabled?: boolean;
  size?: 'sm' | 'md' | 'lg';
  id?: string;
}

export const Toggle: React.FC<ToggleProps> = ({
  checked,
  onChange,
  label,
  description,
  disabled = false,
  size = 'md',
  id,
}) => {
  const toggleId = id || (label ? `toggle-${label.toLowerCase().replace(/\s+/g, '-')}` : undefined);

  const trackDimensions = {
    sm: 'w-9 h-5',
    md: 'w-12 h-7',
    lg: 'w-14 h-8',
  }[size];

  const thumbDimensions = {
    sm: 'w-3.5 h-3.5',
    md: 'w-5 h-5',
    lg: 'w-6 h-6',
  }[size];

  const translateChecked = {
    sm: 'translate-x-4',
    md: 'translate-x-5',
    lg: 'translate-x-6',
  }[size];

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (disabled) return;
    if (e.key === ' ' || e.key === 'Enter') {
      e.preventDefault();
      onChange(!checked);
    }
  };

  return (
    <div
      className={`inline-flex items-center gap-3 select-none ${
        disabled ? 'opacity-40 cursor-not-allowed pointer-events-none' : 'cursor-pointer'
      }`}
      onClick={() => !disabled && onChange(!checked)}
    >
      <button
        type="button"
        role="switch"
        aria-checked={checked}
        aria-labelledby={toggleId ? `${toggleId}-label` : undefined}
        id={toggleId}
        disabled={disabled}
        onKeyDown={handleKeyDown}
        className={`relative inline-flex items-center flex-shrink-0 p-1 rounded-full transition-colors duration-200 focus-ring surface-recessed ${trackDimensions} ${
          checked
            ? 'bg-gradient-to-r from-[var(--color-accent)]/30 to-[var(--color-accent-secondary)]/30 border border-[var(--color-accent)]/50'
            : 'border border-[var(--color-border-subtle)]'
        }`}
      >
        <span
          className={`pointer-events-none inline-block rounded-full surface-raised transform transition-transform duration-200 shadow-sm ${thumbDimensions} ${
            checked
              ? `${translateChecked} bg-accent-gradient text-white glow-accent-sm`
              : 'translate-x-0.5 bg-[var(--color-surface-elevated)]'
          }`}
        />
      </button>

      {(label || description) && (
        <div className="flex flex-col">
          {label && (
            <span
              id={toggleId ? `${toggleId}-label` : undefined}
              className="text-sm font-medium text-[var(--color-text-primary)]"
            >
              {label}
            </span>
          )}
          {description && (
            <span className="text-xs text-[var(--color-text-secondary)]">{description}</span>
          )}
        </div>
      )}
    </div>
  );
};
