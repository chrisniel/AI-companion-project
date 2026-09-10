import React from 'react';
import { Search, X } from 'lucide-react';

export interface SearchInputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  value: string;
  onChangeValue: (value: string) => void;
  shortcutHint?: string;
  sizeVariant?: 'sm' | 'md';
}

export const SearchInput: React.FC<SearchInputProps> = ({
  value,
  onChangeValue,
  placeholder = 'Search components, tokens, or models...',
  shortcutHint = '⌘K',
  sizeVariant = 'md',
  className = '',
  disabled,
  ...props
}) => {
  const sizeClasses = sizeVariant === 'sm' ? 'py-1.5 text-xs' : 'py-2 text-sm';

  return (
    <div className={`relative flex items-center w-full select-none ${className}`}>
      <div className="absolute left-3.5 flex items-center justify-center text-[var(--color-text-muted)] pointer-events-none">
        <Search className="w-4 h-4" />
      </div>

      <input
        type="text"
        value={value}
        onChange={(e) => onChangeValue(e.target.value)}
        placeholder={placeholder}
        disabled={disabled}
        className={`w-full rounded-xl pl-9 pr-16 surface-recessed border border-[var(--color-border-subtle)] text-[var(--color-text-primary)] placeholder-[var(--color-text-muted)] outline-none focus:border-[var(--color-accent)] focus:ring-2 focus:ring-[var(--color-accent)]/20 transition-all duration-150 ${sizeClasses}`}
        {...props}
      />

      <div className="absolute right-3 flex items-center gap-1.5">
        {value ? (
          <button
            type="button"
            onClick={() => onChangeValue('')}
            className="p-1 rounded-md text-[var(--color-text-muted)] hover:text-[var(--color-text-primary)] hover:bg-[var(--color-surface-secondary)] transition-colors"
            aria-label="Clear search"
          >
            <X className="w-3.5 h-3.5" />
          </button>
        ) : (
          shortcutHint && (
            <kbd className="hidden sm:inline-flex items-center px-1.5 py-0.5 text-[10px] font-mono font-medium rounded-md surface-raised text-[var(--color-text-muted)] border border-[var(--color-border-subtle)]">
              {shortcutHint}
            </kbd>
          )
        )}
      </div>
    </div>
  );
};
