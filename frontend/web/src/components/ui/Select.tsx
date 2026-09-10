import React, { useState, useRef, useEffect } from 'react';
import { ChevronDown, Check } from 'lucide-react';
import { SelectOption } from '../../types';

export interface SelectProps {
  options: SelectOption[];
  value: string;
  onChange: (value: string) => void;
  label?: string;
  placeholder?: string;
  disabled?: boolean;
  className?: string;
}

export const Select: React.FC<SelectProps> = ({
  options,
  value,
  onChange,
  label,
  placeholder = 'Select an option',
  disabled = false,
  className = '',
}) => {
  const [isOpen, setIsOpen] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);

  const selectedOption = options.find((opt) => opt.value === value);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (containerRef.current && !containerRef.current.contains(event.target as Node)) {
        setIsOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (disabled) return;
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      setIsOpen(!isOpen);
    } else if (e.key === 'Escape') {
      setIsOpen(false);
    }
  };

  return (
    <div
      ref={containerRef}
      className={`relative flex flex-col gap-1.5 w-full ${
        disabled ? 'opacity-40 pointer-events-none' : ''
      } ${className}`}
    >
      {label && (
        <label className="text-xs font-semibold text-[var(--color-text-secondary)] tracking-wide select-none">
          {label}
        </label>
      )}

      {/* Trigger Button */}
      <button
        type="button"
        aria-haspopup="listbox"
        aria-expanded={isOpen}
        disabled={disabled}
        onClick={() => setIsOpen(!isOpen)}
        onKeyDown={handleKeyDown}
        className={`w-full flex items-center justify-between px-3.5 py-2.5 rounded-xl surface-recessed border transition-all duration-150 focus-ring ${
          isOpen
            ? 'border-[var(--color-accent)] ring-2 ring-[var(--color-accent)]/20'
            : 'border-[var(--color-border-subtle)] hover:border-[var(--color-accent)]/40'
        }`}
      >
        <div className="flex items-center gap-2 truncate">
          {selectedOption?.icon && <span className="flex-shrink-0">{selectedOption.icon}</span>}
          <span
            className={`text-sm truncate ${
              selectedOption ? 'text-[var(--color-text-primary)] font-medium' : 'text-[var(--color-text-muted)]'
            }`}
          >
            {selectedOption ? selectedOption.label : placeholder}
          </span>
        </div>

        <ChevronDown
          className={`w-4 h-4 text-[var(--color-text-muted)] transition-transform duration-200 ${
            isOpen ? 'rotate-180 text-[var(--color-accent)]' : ''
          }`}
        />
      </button>

      {/* Dropdown Menu */}
      {isOpen && (
        <div
          role="listbox"
          className="absolute top-full left-0 right-0 mt-2 z-50 rounded-2xl glass-panel-elevated py-1.5 shadow-2xl max-h-60 overflow-y-auto border border-[var(--color-surface-glass-border)] animate-in fade-in zoom-in-95 duration-150"
        >
          {options.map((option) => {
            const isSelected = option.value === value;
            return (
              <div
                key={option.value}
                role="option"
                aria-selected={isSelected}
                onClick={() => {
                  onChange(option.value);
                  setIsOpen(false);
                }}
                className={`flex items-center justify-between px-3.5 py-2 cursor-pointer transition-colors duration-150 ${
                  isSelected
                    ? 'bg-[var(--color-accent)]/15 text-[var(--color-accent)] font-semibold'
                    : 'text-[var(--color-text-primary)] hover:bg-[var(--color-surface-secondary)]/50'
                }`}
              >
                <div className="flex items-center gap-2 truncate">
                  {option.icon && <span className="flex-shrink-0 text-sm">{option.icon}</span>}
                  <div className="flex flex-col">
                    <span className="text-sm">{option.label}</span>
                    {option.description && (
                      <span className="text-xs text-[var(--color-text-muted)]">
                        {option.description}
                      </span>
                    )}
                  </div>
                </div>

                <div className="flex items-center gap-2 ml-2">
                  {option.badge && (
                    <span className="text-[10px] px-1.5 py-0.5 rounded bg-[var(--color-surface-secondary)] text-[var(--color-text-muted)]">
                      {option.badge}
                    </span>
                  )}
                  {isSelected && <Check className="w-4 h-4 text-[var(--color-accent)]" />}
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};
