import React from 'react';
import { ArrowUpRight, ArrowDownRight, Minus } from 'lucide-react';
import { Card } from './Card';
import { ProgressBar } from './ProgressBar';

export interface MetricCardProps {
  label: string;
  value: string | number;
  unit?: string;
  icon?: React.ReactNode;
  trend?: {
    value: number;
    direction: 'up' | 'down' | 'neutral';
    label?: string;
  };
  progress?: {
    current: number;
    max: number;
  };
  secondaryText?: string;
  variant?: 'elevated' | 'glass' | 'raised';
  className?: string;
}

export const MetricCard: React.FC<MetricCardProps> = ({
  label,
  value,
  unit,
  icon,
  trend,
  progress,
  secondaryText,
  variant = 'elevated',
  className = '',
}) => {
  return (
    <Card
      variant={variant === 'glass' ? 'elevated' : variant}
      className={`relative overflow-hidden flex flex-col justify-between ${
        variant === 'glass' ? 'glass-panel' : ''
      } ${className}`}
      padding="md"
    >
      <div className="flex items-start justify-between gap-3 mb-3">
        <div className="flex flex-col">
          <span className="typo-label">{label}</span>
          <div className="flex items-baseline gap-1 mt-1">
            <span className="typo-metric-value">{value}</span>
            {unit && <span className="text-sm font-medium text-[var(--color-text-secondary)]">{unit}</span>}
          </div>
        </div>

        {icon && (
          <div className="w-10 h-10 rounded-xl surface-raised flex items-center justify-center text-[var(--color-accent)] border border-[var(--color-border-subtle)] flex-shrink-0 shadow-sm">
            {icon}
          </div>
        )}
      </div>

      {progress && (
        <div className="mt-2 mb-1">
          <ProgressBar
            value={progress.current}
            max={progress.max}
            size="sm"
            showValue={false}
          />
        </div>
      )}

      {(trend || secondaryText) && (
        <div className="flex items-center justify-between mt-2 pt-2 border-t border-[var(--color-border-subtle)] text-xs">
          {trend ? (
            <div className="flex items-center gap-1">
              <span
                className={`inline-flex items-center px-1.5 py-0.5 rounded font-medium text-[11px] ${
                  trend.direction === 'up'
                    ? 'bg-emerald-500/15 text-emerald-600 dark:text-emerald-400'
                    : trend.direction === 'down'
                    ? 'bg-rose-500/15 text-rose-600 dark:text-rose-400'
                    : 'bg-[var(--color-surface-secondary)] text-[var(--color-text-muted)]'
                }`}
              >
                {trend.direction === 'up' && <ArrowUpRight className="w-3 h-3 mr-0.5" />}
                {trend.direction === 'down' && <ArrowDownRight className="w-3 h-3 mr-0.5" />}
                {trend.direction === 'neutral' && <Minus className="w-3 h-3 mr-0.5" />}
                {trend.value > 0 ? `+${trend.value}%` : `${trend.value}%`}
              </span>
              {trend.label && (
                <span className="text-[var(--color-text-muted)] ml-1">{trend.label}</span>
              )}
            </div>
          ) : (
            <span className="text-[var(--color-text-muted)]">{secondaryText}</span>
          )}
        </div>
      )}
    </Card>
  );
};
