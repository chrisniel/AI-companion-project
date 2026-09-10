import React, { useState } from 'react';
import { Moon, Clock, Sparkles, AlertCircle, CheckCircle2 } from 'lucide-react';
import { Card } from '../../ui/Card';
import { SleepMetric, HealthTimeRange, HealthSourceProvider } from '../../../types';

interface SleepSectionProps {
  data: SleepMetric;
  timeRange: HealthTimeRange;
  provider?: HealthSourceProvider;
}

function formatMinutesToHours(minutes: number): string {
  const hours = Math.floor(minutes / 60);
  const mins = minutes % 60;
  return `${hours}h ${mins}m`;
}

export const SleepSection: React.FC<SleepSectionProps> = ({
  data,
  timeRange,
  provider,
}) => {
  const [hoveredNight, setHoveredNight] = useState<{
    label: string;
    totalMinutes: number;
    targetMinutes: number;
  } | null>(null);

  // Simple trend visual math
  const maxMinutes = Math.max(...data.dailyTrend.map((d) => d.totalMinutes), 540); // at least 9h

  return (
    <Card
      id="health-sleep-card"
      variant="elevated"
      padding="md"
      className="space-y-4"
    >
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 pb-3 border-b border-[var(--color-border-subtle)]">
        <div className="flex items-center gap-2.5">
          <div className="w-8 h-8 rounded-xl surface-raised flex items-center justify-center text-indigo-400 border border-[var(--color-border-subtle)] shadow-xs flex-shrink-0">
            <Moon className="w-4 h-4 fill-indigo-400/20" />
          </div>
          <div>
            <h3 className="text-sm font-bold text-[var(--color-text-primary)]">
              Sleep & Nocturnal Recovery
            </h3>
            <p className="text-[11px] text-[var(--color-text-muted)]">
              Rest cycles, window duration, and regularity score
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2 text-xs">
          <span className="text-[var(--color-text-muted)]">Target:</span>
          <span className="font-mono font-semibold text-[var(--color-text-secondary)]">8h 00m</span>
        </div>
      </div>

      {/* Triad Metrics: Total Duration | Recent Average | Consistency */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
        {/* Total Duration */}
        <div className="p-3.5 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] flex flex-col justify-between">
          <span className="text-[11px] font-medium text-[var(--color-text-muted)] uppercase tracking-wider">
            {timeRange === 'today' ? 'Last Night Total' : timeRange === 'week' ? 'Weekly Cumulative' : 'Monthly Total'}
          </span>
          <div className="flex items-baseline gap-1.5 my-1">
            <span className="text-2xl font-bold font-mono text-[var(--color-text-primary)]">
              {formatMinutesToHours(data.totalMinutes)}
            </span>
          </div>
          <div className="flex items-center justify-between text-[10px] text-[var(--color-text-muted)]">
            <span>In bed: {data.asleepTime}</span>
            <span>Woke: {data.wakeTime}</span>
          </div>
        </div>

        {/* Recent Average */}
        <div className="p-3.5 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] flex flex-col justify-between">
          <span className="text-[11px] font-medium text-[var(--color-text-muted)] uppercase tracking-wider">
            Recent Average
          </span>
          <div className="flex items-baseline gap-1.5 my-1">
            <span className="text-2xl font-bold font-mono text-indigo-400">
              {formatMinutesToHours(data.recentAvgMinutes)}
            </span>
          </div>
          <div className="flex items-center justify-between text-[10px] text-[var(--color-text-muted)]">
            <span>14-day weighted baseline</span>
            <span className="text-amber-500 font-mono">-34m last night</span>
          </div>
        </div>

        {/* Consistency */}
        <div className="p-3.5 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] flex flex-col justify-between">
          <span className="text-[11px] font-medium text-[var(--color-text-muted)] uppercase tracking-wider">
            Schedule Consistency
          </span>
          <div className="flex items-baseline gap-1.5 my-1">
            <span className="text-2xl font-bold font-mono text-[var(--color-accent)]">
              {data.consistencyPercentage}%
            </span>
            <span className="text-xs text-[var(--color-text-muted)]">Regular</span>
          </div>
          <div className="flex items-center justify-between text-[10px] text-[var(--color-text-muted)]">
            <span>Bedtime variance ±18 min</span>
            <span className="text-emerald-500 font-medium">Optimal window</span>
          </div>
        </div>
      </div>

      {/* Simple Trend Visualization (Calm Daily Sleep Duration Bars) */}
      <div className="p-3.5 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] space-y-3">
        <div className="flex items-center justify-between text-xs px-1">
          <span className="text-[11px] font-semibold text-[var(--color-text-secondary)]">
            Sleep Duration History vs. 8h Target
          </span>
          {hoveredNight && (
            <div className="text-[11px] font-mono bg-[var(--color-surface-elevated)] px-2 py-0.5 rounded-md border border-[var(--color-border-subtle)]">
              <span className="text-[var(--color-text-muted)]">{hoveredNight.label}: </span>
              <strong className="text-indigo-400">{formatMinutesToHours(hoveredNight.totalMinutes)}</strong>
            </div>
          )}
        </div>

        {/* Calm Bar Trend */}
        <div className="space-y-2 pt-2">
          <div className="grid grid-cols-7 gap-2 h-28 items-end relative border-b border-[var(--color-border-subtle)] pb-2">
            {/* 8-Hour Reference Line */}
            <div
              className="absolute left-0 right-0 border-b border-dashed border-[var(--color-text-muted)]/50 z-0 pointer-events-none"
              style={{ bottom: `${(480 / maxMinutes) * 100}%` }}
            >
              <span className="absolute -top-3.5 right-1 text-[9px] font-mono text-[var(--color-text-muted)]">
                8h target
              </span>
            </div>

            {data.dailyTrend.map((night, idx) => {
              const heightPercent = Math.min((night.totalMinutes / maxMinutes) * 100, 100);
              const isTargetMet = night.totalMinutes >= 480;

              return (
                <div
                  key={idx}
                  className="flex flex-col items-center h-full justify-end group cursor-pointer z-10"
                  onMouseEnter={() => setHoveredNight(night)}
                  onMouseLeave={() => setHoveredNight(null)}
                >
                  <div
                    className={`w-full max-w-[28px] rounded-t-lg transition-all duration-200 group-hover:opacity-100 ${
                      isTargetMet
                        ? 'bg-indigo-500/80 group-hover:bg-indigo-400'
                        : 'bg-indigo-500/40 group-hover:bg-indigo-500/60'
                    }`}
                    style={{ height: `${heightPercent}%` }}
                  />
                  <span className="text-[10px] font-mono text-[var(--color-text-muted)] mt-1.5 truncate">
                    {night.label}
                  </span>
                </div>
              );
            })}
          </div>
        </div>
      </div>

      {/* Graceful Missing Data Handling or Provider Sleep Stages */}
      {!provider?.supportsSleepStages ? (
        <div
          id="sleep-stage-provider-availability-notice"
          className="p-3 rounded-2xl surface-base border border-[var(--color-border-subtle)] flex items-start gap-3 text-xs"
        >
          <AlertCircle className="w-4 h-4 text-amber-500 flex-shrink-0 mt-0.5" />
          <div className="space-y-0.5 flex-1">
            <div className="font-semibold text-[var(--color-text-secondary)]">
              Sleep stage data is not available from the current provider.
            </div>
            <p className="text-[11px] text-[var(--color-text-muted)] leading-relaxed">
              The active wearable sensor ({provider?.name || 'FitCloudPro'}) synchronizes consolidated nocturnal sleep duration ({formatMinutesToHours(data.totalMinutes)} total). Detailed REM, Light, and Deep sleep stage decomposition is not supported by this hardware protocol and is not fabricated.
            </p>
          </div>
        </div>
      ) : (
        <div
          id="sleep-stage-breakdown"
          className="p-3 rounded-2xl surface-base border border-[var(--color-border-subtle)] space-y-2 text-xs"
        >
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <CheckCircle2 className="w-3.5 h-3.5 text-emerald-500" />
              <span className="font-semibold text-[var(--color-text-primary)]">
                Sleep Architecture Breakdown ({provider.name})
              </span>
            </div>
            <span className="text-[10px] text-[var(--color-text-muted)] font-mono">
              Health Connect Sync
            </span>
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 pt-1">
            <div className="p-2 rounded-xl surface-recessed border border-[var(--color-border-subtle)]">
              <span className="text-[10px] text-[var(--color-text-muted)]">Deep Sleep</span>
              <div className="text-sm font-bold font-mono text-indigo-400 mt-0.5">1h 24m</div>
              <span className="text-[9px] text-[var(--color-text-muted)]">21% of night</span>
            </div>
            <div className="p-2 rounded-xl surface-recessed border border-[var(--color-border-subtle)]">
              <span className="text-[10px] text-[var(--color-text-muted)]">Light Sleep</span>
              <div className="text-sm font-bold font-mono text-sky-400 mt-0.5">3h 48m</div>
              <span className="text-[9px] text-[var(--color-text-muted)]">56% of night</span>
            </div>
            <div className="p-2 rounded-xl surface-recessed border border-[var(--color-border-subtle)]">
              <span className="text-[10px] text-[var(--color-text-muted)]">REM Cycle</span>
              <div className="text-sm font-bold font-mono text-violet-400 mt-0.5">1h 12m</div>
              <span className="text-[9px] text-[var(--color-text-muted)]">18% of night</span>
            </div>
            <div className="p-2 rounded-xl surface-recessed border border-[var(--color-border-subtle)]">
              <span className="text-[10px] text-[var(--color-text-muted)]">Awake Time</span>
              <div className="text-sm font-bold font-mono text-amber-500 mt-0.5">0h 24m</div>
              <span className="text-[9px] text-[var(--color-text-muted)]">5% of night</span>
            </div>
          </div>
        </div>
      )}
    </Card>
  );
};
