import React from 'react';
import { AlertCircle, CheckCircle2, Database, ShieldCheck } from 'lucide-react';
import { Card } from '../../ui/Card';
import { HealthSourceProvider } from '../../../types';

interface DataAvailabilityBannerProps {
  provider: HealthSourceProvider;
}

export const DataAvailabilityBanner: React.FC<DataAvailabilityBannerProps> = ({
  provider,
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
                Telemetry Authenticity & Architecture Guarantee
              </h4>
              <span className="text-[10px] font-mono text-[var(--color-text-muted)] bg-[var(--color-surface-recessed)] px-1.5 py-0.2 rounded border border-[var(--color-border-subtle)]">
                Planned Specification
              </span>
            </div>
            <p className="text-[11px] text-[var(--color-text-secondary)] mt-0.5">
              Native wearable synchronization is planned for a future Android Companion phase. No synthetic telemetry is rendered.
            </p>
          </div>
        </div>
      </div>

      {/* Provider Capabilities Table / Notice */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 text-xs pt-1">
        <div className="p-2.5 rounded-xl surface-recessed border border-[var(--color-border-subtle)] flex items-start gap-2">
          <ShieldCheck className="w-3.5 h-3.5 text-emerald-500 flex-shrink-0 mt-0.5" />
          <div className="text-[11px] leading-snug">
            <strong className="text-[var(--color-text-primary)]">Non-Fabrication Policy: </strong>
            <span className="text-[var(--color-text-muted)]">
              All vital statistics, sleep architecture, and activity tracking remain strictly in an unavailable state until live companion synchronization is implemented.
            </span>
          </div>
        </div>

        <div className="p-2.5 rounded-xl surface-recessed border border-[var(--color-border-subtle)] flex items-start gap-2">
          <AlertCircle className="w-3.5 h-3.5 text-amber-500 flex-shrink-0 mt-0.5" />
          <div className="text-[11px] leading-snug">
            <strong className="text-[var(--color-text-primary)]">Planned Integration ({provider.name}): </strong>
            <span className="text-[var(--color-text-muted)]">
              Hardware sensor protocols, Android Health Connect batch exports, and BLE bridges represent design specifications awaiting runtime endpoints.
            </span>
          </div>
        </div>
      </div>
    </Card>
  );
};

