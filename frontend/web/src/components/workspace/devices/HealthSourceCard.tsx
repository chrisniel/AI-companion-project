import React, { useState } from 'react';
import {
  Activity,
  Heart,
  Moon,
  Footprints,
  RotateCw,
  CheckCircle2,
  Watch,
  Shield,
  Layers,
  ArrowRightLeft,
  ChevronDown,
} from 'lucide-react';
import {
  HealthSourceOption,
  mockHealthSourceOptions,
} from '../../../mock/deviceAndMemoryData';
import { Card } from '../../ui/Card';
import { Badge } from '../../ui/Badge';
import { NeumorphicButton } from '../../ui/NeumorphicButton';
import { useTheme } from '../../../context/ThemeContext';

export const HealthSourceCard: React.FC = () => {
  const { mode } = useTheme();
  const [selectedProviderId, setSelectedProviderId] = useState<string>('fitcloudpro');
  const [isSyncing, setIsSyncing] = useState(false);
  const [syncFeedback, setSyncFeedback] = useState<string | null>(null);

  const currentProvider =
    mockHealthSourceOptions.find((p) => p.id === selectedProviderId) ||
    mockHealthSourceOptions[0];

  const handleProviderSwitch = (id: string) => {
    setSelectedProviderId(id);
    setSyncFeedback(`Switched health source to ${mockHealthSourceOptions.find((p) => p.id === id)?.name}`);
    setTimeout(() => setSyncFeedback(null), 3000);
  };

  const handleSyncHealth = () => {
    setIsSyncing(true);
    setTimeout(() => {
      setIsSyncing(false);
      setSyncFeedback(`Synchronized biometric metrics from ${currentProvider.name}`);
      setTimeout(() => setSyncFeedback(null), 3500);
    }, 1100);
  };

  return (
    <Card
      id="health-source-card"
      variant="elevated"
      padding="lg"
      className="space-y-4"
    >
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-[var(--color-border-subtle)]">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-2xl surface-raised border border-[var(--color-border-subtle)] flex items-center justify-center text-rose-500 flex-shrink-0 shadow-xs">
            <Activity className="w-5 h-5" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h3 className="text-base font-bold text-[var(--color-text-primary)]">
                Health Connect & Biometric Source
              </h3>
              <Badge variant="success" size="sm">
                Connected
              </Badge>
            </div>
            <p className="text-xs text-[var(--color-text-muted)]">
              Unified Android Health Connect aggregation layer with hot-swappable hardware sources.
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <NeumorphicButton
            size="sm"
            variant="secondary"
            onClick={handleSyncHealth}
            disabled={isSyncing}
            icon={<RotateCw className={`w-3.5 h-3.5 ${isSyncing ? 'animate-spin text-[var(--color-accent)]' : ''}`} />}
          >
            {isSyncing ? 'Syncing...' : 'Sync Health'}
          </NeumorphicButton>
        </div>
      </div>

      {/* Main Display: Health Connect Status & Replaceable Source Selector */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {/* Left: Health Connect Gateway Box */}
        <div className="p-4 rounded-2xl surface-base border border-[var(--color-border-subtle)] space-y-2.5">
          <span className="text-[10px] font-mono uppercase tracking-wider text-[var(--color-text-muted)]">
            Aggregation Layer
          </span>
          <div className="flex items-center justify-between">
            <h4 className="text-sm font-bold text-[var(--color-text-primary)]">
              Health Connect
            </h4>
            <Badge variant="success" size="sm">
              Connected
            </Badge>
          </div>
          <p className="text-xs text-[var(--color-text-secondary)]">
            Encrypted Android on-device health datastore. Granted permissions for heart rate, sleep, steps, and SpO2.
          </p>
          <div className="pt-1 text-[11px] font-mono text-[var(--color-text-muted)] flex items-center gap-1.5">
            <Shield className="w-3.5 h-3.5 text-emerald-500" />
            <span>Encrypted SQLite Store</span>
          </div>
        </div>

        {/* Center & Right: Current Active Source & Replaceable Provider Switcher */}
        <div className="md:col-span-2 p-4 rounded-2xl surface-base border border-[var(--color-border-subtle)] space-y-3">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
            <div>
              <span className="text-[10px] font-mono uppercase tracking-wider text-[var(--color-text-muted)]">
                Active Source Provider (Replaceable)
              </span>
              <div className="flex items-center gap-2 mt-0.5">
                <span className="text-sm font-bold text-[var(--color-accent)]">
                  Source: {currentProvider.name}
                </span>
                <span className="text-xs text-[var(--color-text-muted)]">
                  ({currentProvider.deviceModel})
                </span>
              </div>
            </div>

            {/* Provider Selector Dropdown */}
            <div className="flex items-center gap-1.5">
              <ArrowRightLeft className="w-3.5 h-3.5 text-[var(--color-text-muted)]" />
              <div className="relative">
                <select
                  value={selectedProviderId}
                  onChange={(e) => handleProviderSwitch(e.target.value)}
                  style={{ colorScheme: mode }}
                  className="px-2.5 py-1.5 pr-7 rounded-xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-xs font-semibold text-[var(--color-text-primary)] focus:outline-none focus:border-[var(--color-accent)] transition-all appearance-none cursor-pointer shadow-xs"
                >
                  {mockHealthSourceOptions.map((opt) => (
                    <option
                      key={opt.id}
                      value={opt.id}
                      className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}
                    >
                      Switch to: {opt.name}
                    </option>
                  ))}
                </select>
                <ChevronDown className="w-3.5 h-3.5 text-[var(--color-text-muted)] absolute right-2 top-1/2 -translate-y-1/2 pointer-events-none" />
              </div>
            </div>
          </div>

          {/* Details & Metrics supported by this source */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 text-xs font-mono text-[var(--color-text-secondary)] pt-1">
            <div>Protocol: <span className="text-[var(--color-text-primary)] font-medium">{currentProvider.protocol}</span></div>
            <div>Last Ingestion: <span className="text-[var(--color-text-primary)] font-medium">{currentProvider.lastSynced}</span></div>
          </div>

          {/* Supported Metrics Tags */}
          <div className="flex items-center gap-1.5 flex-wrap pt-1">
            <span className="text-[10px] text-[var(--color-text-muted)] font-mono">Metrics:</span>
            {currentProvider.supportedMetrics.map((metric) => (
              <span
                key={metric}
                className="text-[10px] px-2 py-0.5 rounded-md surface-recessed border border-[var(--color-border-subtle)] text-[var(--color-text-secondary)]"
              >
                {metric}
              </span>
            ))}
          </div>
        </div>
      </div>

      {/* Sync Feedback Message */}
      {syncFeedback && (
        <div className="px-3 py-2 rounded-xl surface-recessed border border-emerald-500/30 text-xs text-emerald-400 flex items-center gap-2 animate-fadeIn">
          <CheckCircle2 className="w-3.5 h-3.5" />
          <span>{syncFeedback}</span>
        </div>
      )}
    </Card>
  );
};
