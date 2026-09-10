import React from 'react';
import { StatusType } from '../../types';

export interface StatusIndicatorProps extends React.HTMLAttributes<HTMLDivElement> {
  status: StatusType;
  showLabel?: boolean;
  label?: string;
  size?: 'sm' | 'md' | 'lg';
}

export const StatusIndicator: React.FC<StatusIndicatorProps> = ({
  status,
  showLabel = true,
  label,
  size = 'md',
  className = '',
  ...props
}) => {
  const dotSize = {
    sm: 'w-2 h-2',
    md: 'w-2.5 h-2.5',
    lg: 'w-3 h-3',
  }[size];

  let colorClass = '';
  let defaultLabel = '';
  let shouldPulse = false;

  switch (status) {
    case 'online':
      colorClass = 'bg-emerald-500 shadow-[0_0_8px_rgba(16,185,129,0.5)]';
      defaultLabel = 'Online';
      shouldPulse = true;
      break;
    case 'idle':
      colorClass = 'bg-amber-400 shadow-[0_0_8px_rgba(245,158,11,0.4)]';
      defaultLabel = 'Standby';
      break;
    case 'busy':
      colorClass = 'bg-rose-500 shadow-[0_0_8px_rgba(244,63,94,0.5)]';
      defaultLabel = 'Processing';
      shouldPulse = true;
      break;
    case 'assistant':
      colorClass = 'bg-accent-gradient shadow-[0_0_12px_var(--accent-glow)]';
      defaultLabel = 'Assistant Ready';
      shouldPulse = true;
      break;
    case 'model-active':
      colorClass = 'bg-[var(--color-accent)] shadow-[0_0_12px_var(--accent-glow)]';
      defaultLabel = 'Model Inference Active';
      shouldPulse = true;
      break;
    case 'offline':
      colorClass = 'bg-slate-400 dark:bg-slate-600';
      defaultLabel = 'Offline';
      break;
    case 'error':
      colorClass = 'bg-red-600 shadow-[0_0_8px_rgba(220,38,38,0.6)]';
      defaultLabel = 'Core Error';
      shouldPulse = true;
      break;
  }

  const displayLabel = label || defaultLabel;

  return (
    <div className={`inline-flex items-center gap-2 ${className}`} {...props}>
      <span className="relative flex items-center justify-center">
        {shouldPulse && (
          <span
            className={`animate-ping absolute inline-flex h-full w-full rounded-full opacity-60 ${colorClass}`}
          />
        )}
        <span className={`relative inline-flex rounded-full ${dotSize} ${colorClass}`} />
      </span>
      {showLabel && (
        <span className="text-xs font-medium text-[var(--color-text-secondary)] select-none">
          {displayLabel}
        </span>
      )}
    </div>
  );
};
