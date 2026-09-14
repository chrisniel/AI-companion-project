import React, { useState } from 'react';
import {
  Activity,
  Heart,
  Moon,
  Footprints,
  Wind,
  Flame,
  ShieldAlert,
  Sparkles,
  Info,
  CheckCircle2,
  RefreshCw,
  Smartphone,
  Watch,
  Database,
  WifiOff,
} from 'lucide-react';
import { Badge } from '../ui/Badge';
import { NeumorphicButton } from '../ui/NeumorphicButton';
import { HealthPipelineCard } from './health/HealthPipelineCard';
import { DataAvailabilityBanner } from './health/DataAvailabilityBanner';
import { useBackend } from '../../context/BackendContext';
import {
  SUPPORTED_HEALTH_PROVIDERS,
  getPipelineStages,
} from './health/healthConfig';
import {
  HealthSourceProvider,
  HealthTimeRange,
} from '../../types';

export const HealthView: React.FC = () => {
  const { isOnline, modelStatus, refreshStatus } = useBackend();
  const [timeRange, setTimeRange] = useState<HealthTimeRange>('today');
  const [selectedProvider, setSelectedProvider] = useState<HealthSourceProvider>(
    SUPPORTED_HEALTH_PROVIDERS[0]
  );
  const [simulateMissingSpO2, setSimulateMissingSpO2] = useState(false);
  const [isSyncing, setIsSyncing] = useState(false);

  const pipelineStages = getPipelineStages(selectedProvider.name);

  const handleRefreshSync = async () => {
    setIsSyncing(true);
    try {
      await refreshStatus();
    } finally {
      setIsSyncing(false);
    }
  };

  return (
    <div id="health-and-wellness-view" className="space-y-6 max-w-7xl mx-auto pb-12">
      {/* View Header */}
      <div className="p-5 sm:p-6 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <div className="w-11 h-11 rounded-2xl bg-accent-gradient flex items-center justify-center text-white glow-accent-sm flex-shrink-0">
              <Activity className="w-6 h-6" />
            </div>
            <div>
              <h1 className="text-xl font-bold text-[var(--color-text-primary)]">
                Health & Wellness
              </h1>
              <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">
                Personal lifestyle telemetry, circadian tracking, and wearable activity data synced to your Local AI Runtime.
              </p>
            </div>
          </div>

          {/* Time Range Soft UI Segmented Controls */}
          <div className="flex items-center self-start md:self-auto">
            <div
              id="health-time-range-segmented-controls"
              className="flex items-center p-1 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] gap-1 select-none"
            >
              {(['today', 'week', 'month'] as const).map((range) => {
                const isSelected = timeRange === range;
                const labels: Record<HealthTimeRange, string> = {
                  today: 'Today',
                  week: 'Week',
                  month: 'Month',
                };

                return (
                  <button
                    key={range}
                    id={`health-timerange-${range}`}
                    type="button"
                    onClick={() => setTimeRange(range)}
                    className={`px-4 py-1.5 rounded-xl text-xs font-semibold capitalize cursor-pointer select-none segmented-control-item ${
                      isSelected
                        ? 'segmented-control-item-active'
                        : 'segmented-control-item-inactive'
                    }`}
                  >
                    {labels[range]}
                  </button>
                );
              })}
            </div>
          </div>
        </div>

        {/* Non-Diagnostic Wellness Disclaimer Notice */}
        <div
          id="health-non-diagnostic-disclaimer"
          className="p-3 rounded-2xl surface-base border border-[var(--color-border-subtle)] flex items-start sm:items-center justify-between gap-3 text-xs"
        >
          <div className="flex items-center gap-2.5">
            <ShieldAlert className="w-4 h-4 text-[var(--color-accent)] flex-shrink-0" />
            <p className="text-[11px] text-[var(--color-text-secondary)] leading-snug">
              <strong className="font-semibold text-[var(--color-text-primary)]">
                Non-Diagnostic Wellness Information:{' '}
              </strong>
              This page represents personal lifestyle and fitness telemetry for informational awareness only. It does not provide medical advice, screening, or clinical diagnosis.
            </p>
          </div>
          <Badge variant="neutral" size="sm" className="hidden sm:inline-flex flex-shrink-0 font-mono text-[10px]">
            Wellness Vitals
          </Badge>
        </div>
      </div>

      {/* Truthful Runtime Connection / Degraded State Banner */}
      {!isOnline ? (
        <div
          id="health-runtime-offline-banner"
          className="p-3.5 rounded-2xl bg-amber-500/10 border border-amber-500/30 flex items-start sm:items-center justify-between gap-3 text-xs text-amber-300"
        >
          <div className="flex items-center gap-2.5">
            <ShieldAlert className="w-4 h-4 text-amber-400 flex-shrink-0" />
            <p className="text-xs leading-relaxed">
              <strong className="font-semibold text-amber-300">Local AI Runtime Offline: </strong>
              Host runtime is disconnected. Wearable synchronization and automated circadian context synthesis are currently offline.
            </p>
          </div>
          <Badge variant="warning" size="sm" className="font-mono text-[10px] flex-shrink-0">
            Runtime Offline
          </Badge>
        </div>
      ) : modelStatus?.runtime_state === 'MODEL_ERROR' || modelStatus?.runtime_state === 'SERVER_ERROR' ? (
        <div
          id="health-runtime-degraded-banner"
          className="p-3.5 rounded-2xl bg-amber-500/10 border border-amber-500/30 flex items-start sm:items-center justify-between gap-3 text-xs text-amber-300"
        >
          <div className="flex items-center gap-2.5">
            <ShieldAlert className="w-4 h-4 text-amber-400 flex-shrink-0" />
            <p className="text-xs leading-relaxed">
              <strong className="font-semibold text-amber-300">Runtime Degraded: </strong>
              Local runtime is online but reports degraded telemetry or model state.
            </p>
          </div>
          <Badge variant="warning" size="sm" className="font-mono text-[10px] flex-shrink-0">
            Degraded
          </Badge>
        </div>
      ) : null}

      {/* HEALTH SOURCE PIPELINE: FitCloudPro → Health Connect → Mobile App → Local AI Runtime */}
      <HealthPipelineCard
        selectedProvider={selectedProvider}
        providers={SUPPORTED_HEALTH_PROVIDERS}
        pipelineStages={pipelineStages}
        onSelectProvider={setSelectedProvider}
        isSyncing={isSyncing}
        onRefreshSync={handleRefreshSync}
      />

      {/* SUMMARY METRICS: Truthful Unconnected Telemetry Metrics */}
      <div className="space-y-2">
        <div className="flex items-center justify-between px-1 text-xs">
          <span className="font-bold text-[var(--color-text-primary)] uppercase tracking-wider text-[11px]">
            {timeRange === 'today' ? 'Today’s Summary' : timeRange === 'week' ? 'Weekly Aggregate' : 'Monthly Aggregate'}
          </span>
          <span className="text-[11px] text-[var(--color-text-muted)] font-mono">
            Provider: {selectedProvider.name} (Awaiting Sync)
          </span>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-3">
          {/* 1. Heart Rate Summary */}
          <div className="p-4 rounded-2xl surface-raised border border-[var(--color-border-subtle)] flex flex-col justify-between hover:border-[var(--color-border-highlight)] transition-colors">
            <div className="flex items-center justify-between text-xs mb-2">
              <span className="text-[11px] font-medium text-[var(--color-text-muted)] uppercase tracking-wider">
                Heart Rate
              </span>
              <div className="w-6 h-6 rounded-lg surface-recessed flex items-center justify-center text-rose-500 border border-[var(--color-border-subtle)]">
                <Heart className="w-3.5 h-3.5" />
              </div>
            </div>
            <div className="flex items-baseline gap-1 my-1">
              <span className="text-2xl font-bold font-mono text-[var(--color-text-muted)]">
                —
              </span>
              <span className="text-xs text-[var(--color-text-muted)] font-medium">bpm</span>
            </div>
            <div className="text-[10px] text-[var(--color-text-muted)] pt-1 border-t border-[var(--color-border-subtle)] flex items-center justify-between">
              <span>Resting: <strong>—</strong></span>
              <span className="font-mono text-amber-500/80">No sensor data</span>
            </div>
          </div>

          {/* 2. Sleep Summary */}
          <div className="p-4 rounded-2xl surface-raised border border-[var(--color-border-subtle)] flex flex-col justify-between hover:border-[var(--color-border-highlight)] transition-colors">
            <div className="flex items-center justify-between text-xs mb-2">
              <span className="text-[11px] font-medium text-[var(--color-text-muted)] uppercase tracking-wider">
                Sleep
              </span>
              <div className="w-6 h-6 rounded-lg surface-recessed flex items-center justify-center text-indigo-400 border border-[var(--color-border-subtle)]">
                <Moon className="w-3.5 h-3.5" />
              </div>
            </div>
            <div className="flex items-baseline gap-1 my-1">
              <span className="text-2xl font-bold font-mono text-[var(--color-text-muted)]">
                —
              </span>
            </div>
            <div className="text-[10px] text-[var(--color-text-muted)] pt-1 border-t border-[var(--color-border-subtle)] flex items-center justify-between">
              <span>Avg: <strong>—</strong></span>
              <span className="font-mono text-amber-500/80">No sleep records</span>
            </div>
          </div>

          {/* 3. Steps Summary */}
          <div className="p-4 rounded-2xl surface-raised border border-[var(--color-border-subtle)] flex flex-col justify-between hover:border-[var(--color-border-highlight)] transition-colors">
            <div className="flex items-center justify-between text-xs mb-2">
              <span className="text-[11px] font-medium text-[var(--color-text-muted)] uppercase tracking-wider">
                Steps
              </span>
              <div className="w-6 h-6 rounded-lg surface-recessed flex items-center justify-center text-emerald-500 border border-[var(--color-border-subtle)]">
                <Footprints className="w-3.5 h-3.5" />
              </div>
            </div>
            <div className="flex items-baseline gap-1 my-1">
              <span className="text-2xl font-bold font-mono text-[var(--color-text-muted)]">
                —
              </span>
            </div>
            <div className="text-[10px] text-[var(--color-text-muted)] pt-1 border-t border-[var(--color-border-subtle)] flex items-center justify-between">
              <span>Goal: 10,000</span>
              <span className="font-mono text-amber-500/80">0%</span>
            </div>
          </div>

          {/* 4. Activity Summary */}
          <div className="p-4 rounded-2xl surface-raised border border-[var(--color-border-subtle)] flex flex-col justify-between hover:border-[var(--color-border-highlight)] transition-colors">
            <div className="flex items-center justify-between text-xs mb-2">
              <span className="text-[11px] font-medium text-[var(--color-text-muted)] uppercase tracking-wider">
                Activity
              </span>
              <div className="w-6 h-6 rounded-lg surface-recessed flex items-center justify-center text-amber-500 border border-[var(--color-border-subtle)]">
                <Flame className="w-3.5 h-3.5" />
              </div>
            </div>
            <div className="flex items-baseline gap-1 my-1">
              <span className="text-2xl font-bold font-mono text-[var(--color-text-muted)]">
                —
              </span>
              <span className="text-xs text-[var(--color-text-muted)] font-medium">mins</span>
            </div>
            <div className="text-[10px] text-[var(--color-text-muted)] pt-1 border-t border-[var(--color-border-subtle)] flex items-center justify-between">
              <span>Burn: <strong>—</strong></span>
              <span className="font-mono text-amber-500/80">0.0 km</span>
            </div>
          </div>

          {/* 5. Blood Oxygen Summary */}
          <div className="p-4 rounded-2xl surface-raised border border-[var(--color-border-subtle)] flex flex-col justify-between hover:border-[var(--color-border-highlight)] transition-colors">
            <div className="flex items-center justify-between text-xs mb-2">
              <span className="text-[11px] font-medium text-[var(--color-text-muted)] uppercase tracking-wider">
                Blood Oxygen
              </span>
              <div className="w-6 h-6 rounded-lg surface-recessed flex items-center justify-center text-cyan-400 border border-[var(--color-border-subtle)]">
                <Wind className="w-3.5 h-3.5" />
              </div>
            </div>
            <div className="flex items-baseline gap-1 my-1">
              <span className="text-xs font-semibold text-[var(--color-text-muted)]">
                Unavailable
              </span>
            </div>
            <div className="text-[10px] text-[var(--color-text-muted)] pt-1 border-t border-[var(--color-border-subtle)] flex items-center justify-between">
              <span className="text-amber-500/80 font-mono">Awaiting SpO2 sync</span>
            </div>
          </div>
        </div>
      </div>

      {/* PRIMARY UNAVAILABLE / COMING-LATER STATE */}
      <div className="p-8 sm:p-10 rounded-3xl surface-raised border border-[var(--color-border-subtle)] text-center space-y-4">
        <div className="w-14 h-14 rounded-3xl bg-accent-gradient flex items-center justify-center text-white glow-accent-sm mx-auto">
          <Activity className="w-7 h-7" />
        </div>
        <div className="max-w-md mx-auto space-y-2">
          <h2 className="text-lg sm:text-xl font-bold text-[var(--color-text-primary)]">
            No Wearable Telemetry Synchronized
          </h2>
          <p className="text-xs sm:text-sm text-[var(--color-text-secondary)] leading-relaxed">
            Real-time biometrics, sleep architecture, and activity tracking require an active synchronization bridge from the Android Companion app or Bluetooth LE daemon.
          </p>
        </div>
        <div className="flex flex-wrap items-center justify-center gap-2 pt-2">
          <Badge variant="neutral" size="sm" className="font-mono text-[11px]">
            Android Health Connect: Ready
          </Badge>
          <Badge variant="neutral" size="sm" className="font-mono text-[11px]">
            BLE GATT Bridge: Standby
          </Badge>
          <Badge variant="neutral" size="sm" className="font-mono text-[11px]">
            SQLite Telemetry: 0 Records
          </Badge>
        </div>
        <div className="pt-2">
          <NeumorphicButton
            size="sm"
            variant="secondary"
            onClick={handleRefreshSync}
            disabled={isSyncing}
            icon={<RefreshCw className={`w-3.5 h-3.5 ${isSyncing ? 'animate-spin' : ''}`} />}
          >
            {isSyncing ? 'Checking Sync Bridge...' : 'Check Sync Status'}
          </NeumorphicButton>
        </div>
      </div>

      {/* CIRCADIAN & WELLNESS INSIGHTS: Explicit Unavailable State */}
      <div className="p-6 rounded-3xl surface-base border border-[var(--color-border-subtle)] space-y-3">
        <div className="flex items-center justify-between gap-3">
          <div className="flex items-center gap-2.5">
            <Sparkles className="w-5 h-5 text-[var(--color-accent)]" />
            <div>
              <h3 className="text-sm font-bold text-[var(--color-text-primary)]">
                Automated Circadian & Wellness Insights
              </h3>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Circadian phase detection, recovery readiness scoring, and sleep regularity models.
              </p>
            </div>
          </div>
          <Badge variant="neutral" size="sm" className="font-mono text-[10px]">
            Awaiting Telemetry
          </Badge>
        </div>
        <div className="p-4 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-muted)] flex items-start gap-2.5">
          <Info className="w-4 h-4 text-[var(--color-accent)] flex-shrink-0 mt-0.5" />
          <p className="leading-relaxed">
            Personalized circadian rhythm analysis and prompt contextualization will be generated by the Local AI Runtime once 7+ days of continuous telemetry are synchronized.
          </p>
        </div>
      </div>

      {/* DATA AVAILABILITY & CAPABILITIES */}
      <DataAvailabilityBanner
        provider={selectedProvider}
        simulateMissingSpO2={simulateMissingSpO2}
        onToggleSimulateMissingSpO2={() => setSimulateMissingSpO2(!simulateMissingSpO2)}
      />
    </div>
  );
};
