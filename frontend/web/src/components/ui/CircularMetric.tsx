import React from 'react';

export interface CircularMetricProps {
  value: number;
  max?: number;
  label?: string;
  sublabel?: string;
  unit?: string;
  size?: number; // pixel diameter, default 120
  strokeWidth?: number;
  variant?: 'accent' | 'success' | 'warning' | 'danger';
  className?: string;
}

export const CircularMetric: React.FC<CircularMetricProps> = ({
  value,
  max = 100,
  label,
  sublabel,
  unit = '%',
  size = 130,
  strokeWidth = 9,
  variant = 'accent',
  className = '',
}) => {
  const percentage = Math.min(Math.max((value / max) * 100, 0), 100);
  const radius = (size - strokeWidth * 2) / 2;
  const circumference = 2 * Math.PI * radius;
  const strokeDashoffset = circumference - (percentage / 100) * circumference;

  const gradientId = `circ-grad-${Math.random().toString(36).substring(2, 9)}`;

  let strokeColor = `url(#${gradientId})`;
  if (variant === 'success') strokeColor = '#10b981';
  else if (variant === 'warning') strokeColor = '#f59e0b';
  else if (variant === 'danger') strokeColor = '#f43f5e';

  return (
    <div
      className={`flex flex-col items-center justify-center relative select-none ${className}`}
      style={{ width: size }}
    >
      <div
        className="relative flex items-center justify-center rounded-full surface-raised p-2 border border-[var(--color-border-subtle)]"
        style={{ width: size, height: size }}
      >
        {/* Inner recessed plate */}
        <div
          className="absolute rounded-full surface-recessed pointer-events-none"
          style={{
            width: size - strokeWidth * 2.5,
            height: size - strokeWidth * 2.5,
          }}
        />

        <svg width={size} height={size} className="transform -rotate-90 relative z-10">
          <defs>
            <linearGradient id={gradientId} x1="0%" y1="0%" x2="100%" y2="100%">
              <stop offset="0%" stopColor="var(--color-accent, #06b6d4)" />
              <stop offset="100%" stopColor="var(--color-accent-secondary, #8b5cf6)" />
            </linearGradient>
          </defs>

          {/* Background Ring */}
          <circle
            cx={size / 2}
            cy={size / 2}
            r={radius}
            stroke="currentColor"
            strokeWidth={strokeWidth}
            className="text-[var(--color-surface-secondary)]/50"
            fill="transparent"
          />

          {/* Progress Arc */}
          <circle
            cx={size / 2}
            cy={size / 2}
            r={radius}
            stroke={strokeColor}
            strokeWidth={strokeWidth}
            strokeDasharray={circumference}
            strokeDashoffset={strokeDashoffset}
            strokeLinecap="round"
            fill="transparent"
            className="transition-all duration-500 ease-out"
          />
        </svg>

        {/* Tactile raised center disc */}
        <div
          className="absolute rounded-full surface-raised flex flex-col items-center justify-center text-center z-20 pointer-events-none shadow-sm border border-[var(--color-border-subtle)]"
          style={{
            width: size - strokeWidth * 3.6,
            height: size - strokeWidth * 3.6,
          }}
        >
          <span className="typo-metric-value text-xl sm:text-2xl font-bold">
            {Math.round(value)}
            <span className="text-xs font-normal text-[var(--color-text-secondary)] ml-0.5">
              {unit}
            </span>
          </span>
          {sublabel && <span className="typo-caption text-[10px] uppercase tracking-wider">{sublabel}</span>}
        </div>
      </div>

      {label && (
        <span className="mt-2.5 text-xs font-medium text-[var(--color-text-secondary)] text-center">
          {label}
        </span>
      )}
    </div>
  );
};
