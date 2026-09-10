import React from 'react';

export interface SliderProps {
  value: number;
  onChange: (value: number) => void;
  min?: number;
  max?: number;
  step?: number;
  label?: string;
  unit?: string;
  disabled?: boolean;
  className?: string;
}

export const Slider: React.FC<SliderProps> = ({
  value,
  onChange,
  min = 0,
  max = 100,
  step = 1,
  label,
  unit = '',
  disabled = false,
  className = '',
}) => {
  const percentage = Math.min(Math.max(((value - min) / (max - min)) * 100, 0), 100);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    onChange(Number(e.target.value));
  };

  return (
    <div className={`w-full flex flex-col gap-2 ${disabled ? 'opacity-40 pointer-events-none' : ''} ${className}`}>
      {(label || unit !== undefined) && (
        <div className="flex items-center justify-between text-xs">
          {label && <span className="font-medium text-[var(--color-text-secondary)]">{label}</span>}
          <span className="font-mono font-semibold text-[var(--color-text-primary)]">
            {value}
            {unit}
          </span>
        </div>
      )}

      <div className="relative flex items-center w-full h-6 select-none touch-none">
        {/* Recessed Track */}
        <div className="w-full h-2.5 rounded-full surface-recessed border border-[var(--color-border-subtle)] relative overflow-hidden">
          {/* Active Accent Gradient Fill */}
          <div
            className="absolute left-0 top-0 bottom-0 bg-accent-gradient transition-all duration-75 rounded-full"
            style={{ width: `${percentage}%` }}
          />
        </div>

        {/* Tactile Raised Thumb via Native Input Overlay */}
        <input
          type="range"
          min={min}
          max={max}
          step={step}
          value={value}
          onChange={handleChange}
          disabled={disabled}
          className="absolute inset-0 w-full h-full opacity-0 cursor-pointer z-10"
        />

        {/* Visible Styled Thumb */}
        <div
          className="pointer-events-none absolute w-5 h-5 rounded-full surface-raised border border-[var(--color-accent)]/50 bg-[var(--color-surface-elevated)] -ml-2.5 flex items-center justify-center transition-all duration-75 shadow-md"
          style={{ left: `${percentage}%` }}
        >
          <div className="w-2 h-2 rounded-full bg-accent-gradient" />
        </div>
      </div>
    </div>
  );
};
