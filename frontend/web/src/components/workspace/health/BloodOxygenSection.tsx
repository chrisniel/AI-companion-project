import React from 'react';
import { Wind, ShieldAlert, CheckCircle2, AlertCircle, Info } from 'lucide-react';
import { Card } from '../../ui/Card';
import { BloodOxygenMetric, HealthSourceProvider } from '../../../types';

interface BloodOxygenSectionProps {
  data: BloodOxygenMetric;
  provider?: HealthSourceProvider;
}

export const BloodOxygenSection: React.FC<BloodOxygenSectionProps> = ({
  data,
  provider,
}) => {
  return (
    <Card
      id="health-blood-oxygen-card"
      variant="elevated"
      padding="md"
      className="space-y-4"
    >
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 pb-3 border-b border-[var(--color-border-subtle)]">
        <div className="flex items-center gap-2.5">
          <div className="w-8 h-8 rounded-xl surface-raised flex items-center justify-center text-cyan-400 border border-[var(--color-border-subtle)] shadow-xs flex-shrink-0">
            <Wind className="w-4 h-4" />
          </div>
          <div>
            <h3 className="text-sm font-bold text-[var(--color-text-primary)]">
              Blood Oxygen (SpO2 Estimates)
            </h3>
            <p className="text-[11px] text-[var(--color-text-muted)]">
              Peripheral capillary oxygen saturation spot-checks via red & infrared optical LEDs
            </p>
          </div>
        </div>

        {data.isAvailable && data.latestPercentage && (
          <div className="flex items-center gap-2">
            <span className="text-xs text-[var(--color-text-muted)]">Latest Spot:</span>
            <span className="text-sm font-mono font-bold text-cyan-400">
              {data.latestPercentage}%
            </span>
          </div>
        )}
      </div>

      {/* Non-Diagnostic Boundary Disclaimer Banner */}
      <div className="p-3 rounded-2xl surface-base border border-[var(--color-border-subtle)] flex items-start gap-2.5 text-xs">
        <Info className="w-4 h-4 text-cyan-500/80 flex-shrink-0 mt-0.5" />
        <p className="text-[11px] text-[var(--color-text-muted)] leading-relaxed">
          <strong className="font-medium text-[var(--color-text-secondary)]">General Wellness Tracking: </strong>
          Consumer wrist sensor pulse oximetry provides periodic fitness approximations. Measurements are not calibrated for clinical diagnosis, hypoxia evaluation, or medical screening.
        </p>
      </div>

      {/* Content: Available Measurements or Graceful Missing State */}
      {!data.isAvailable || data.measurements.length === 0 ? (
        <div
          id="health-spo2-unavailable-state"
          className="p-5 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] text-center space-y-2"
        >
          <div className="w-9 h-9 rounded-2xl surface-raised flex items-center justify-center text-[var(--color-text-muted)] border border-[var(--color-border-subtle)] mx-auto">
            <AlertCircle className="w-4.5 h-4.5" />
          </div>
          <div className="text-xs font-bold text-[var(--color-text-secondary)]">
            No SpO2 data available.
          </div>
          <p className="text-[11px] text-[var(--color-text-muted)] max-w-md mx-auto">
            No valid blood oxygen spot measurements were recorded by {provider?.name || 'the current wearable provider'} for this timeframe. To preserve sensor battery, continuous oximetry may be paused or withheld.
          </p>
        </div>
      ) : (
        <div className="space-y-3">
          <div className="flex items-center justify-between text-xs px-1">
            <span className="text-[11px] font-semibold text-[var(--color-text-secondary)]">
              Recent Discrete Spot Measurements
            </span>
            <span className="text-[10px] text-[var(--color-text-muted)]">
              Integer resolution (no artificial precision)
            </span>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-2.5">
            {data.measurements.map((measurement) => (
              <div
                key={measurement.id}
                className="p-3 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] flex flex-col justify-between hover:border-[var(--color-border-highlight)] transition-colors"
              >
                <div className="flex items-center justify-between text-[11px] text-[var(--color-text-muted)]">
                  <span className="font-mono">{measurement.timestamp}</span>
                  <span className="px-1.5 py-0.2 rounded text-[9px] font-mono capitalize bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)]">
                    {measurement.condition}
                  </span>
                </div>

                <div className="flex items-baseline gap-1 my-2">
                  <span className="text-2xl font-bold font-mono text-[var(--color-text-primary)]">
                    {measurement.percentage}
                  </span>
                  <span className="text-xs font-semibold text-cyan-400">%</span>
                </div>

                <div className="flex items-center gap-1 text-[10px] text-emerald-500 font-medium">
                  <CheckCircle2 className="w-3 h-3" />
                  <span>Expected typical range (95-100%)</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </Card>
  );
};
