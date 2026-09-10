import React from 'react';
import { AlertCircle, CheckCircle2, Database, EyeOff, ShieldCheck, SlidersHorizontal } from 'lucide-react';
import { Card } from '../../ui/Card';
import { HealthSourceProvider } from '../../../types';

interface DataAvailabilityBannerProps {
  provider: HealthSourceProvider;
  simulateMissingSpO2: boolean;
  onToggleSimulateMissingSpO2: () => void;
}

export const DataAvailabilityBanner: React.FC<DataAvailabilityBannerProps> = ({
  provider,
  simulateMissingSpO2,
  onToggleSimulateMissingSpO2,
}) => {
  return (
    <Card
      id="health-data-availability-card"
      variant="elevated"
      padding="md"
      className="space-y-3 border-l-4 border-l-[var(--color-accent)]"
    >
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-3">
        <div className="flex items-start gap-2.5">
          <div className="w-7 h-7 rounded-lg surface-raised flex items-center justify-center text-[var(--color-accent)] border border-[var(--color-border-subtle)] flex-shrink-0 mt-0.5">
            <Database className="w-3.5 h-3.5" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h4 className="text-xs font-bold text-[var(--color-text-primary)]">
                Data Availability & Telemetry Authenticity
              </h4>
              <span className="text-[10px] font-mono text-[var(--color-text-muted)] bg-[var(--color-surface-recessed)] px-1.5 py-0.2 rounded border border-[var(--color-border-subtle)]">
                Health Connect Schema
              </span>
            </div>
            <p className="text-[11px] text-[var(--color-text-secondary)] mt-0.5">
              Strict non-fabrication guarantee: Unavailable sensor metrics display explicit provider notices.
            </p>
          </div>
        </div>

        {/* Missing Data Demonstration Toggle */}
        <div className="flex items-center gap-2 self-start md:self-auto">
          <button
            id="health-toggle-missing-spo2-btn"
            type="button"
            onClick={onToggleSimulateMissingSpO2}
            className={`px-3 py-1 rounded-xl text-xs font-semibold flex items-center gap-1.5 transition-colors cursor-pointer select-none segmented-control-item ${
              simulateMissingSpO2
                ? 'bg-amber-500/15 text-amber-500 border-amber-500/30'
                : 'segmented-control-item-inactive text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)]'
            }`}
            title="Toggle simulating missing SpO2 sensor data"
          >
            <EyeOff className="w-3.5 h-3.5" />
            <span>{simulateMissingSpO2 ? 'Missing SpO2 (Simulated)' : 'Normal SpO2'}</span>
          </button>
        </div>
      </div>

      {/* Provider Capabilities Table / Notice */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 text-xs pt-1">
        <div className="p-2.5 rounded-xl surface-recessed border border-[var(--color-border-subtle)] flex items-start gap-2">
          <CheckCircle2 className="w-3.5 h-3.5 text-emerald-500 flex-shrink-0 mt-0.5" />
          <div className="text-[11px] leading-snug">
            <strong className="text-[var(--color-text-primary)]">Available from {provider.name}: </strong>
            <span className="text-[var(--color-text-muted)]">
              Continuous optical heart rate, step accumulation, calibrated distance, and consolidated sleep duration.
            </span>
          </div>
        </div>

        <div className="p-2.5 rounded-xl surface-recessed border border-[var(--color-border-subtle)] flex items-start gap-2">
          <AlertCircle className="w-3.5 h-3.5 text-amber-500 flex-shrink-0 mt-0.5" />
          <div className="text-[11px] leading-snug">
            <strong className="text-[var(--color-text-primary)]">Hardware Limitations: </strong>
            <span className="text-[var(--color-text-muted)]">
              Polysomnography REM sleep stages and clinical ECG are not supported by this hardware protocol.
            </span>
          </div>
        </div>
      </div>
    </Card>
  );
};
