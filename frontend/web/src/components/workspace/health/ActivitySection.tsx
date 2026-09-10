import React, { useState } from 'react';
import { Footprints, Flame, Timer, Compass } from 'lucide-react';
import { Card } from '../../ui/Card';
import { ProgressBar } from '../../ui/ProgressBar';
import { ActivityMetric, HealthTimeRange } from '../../../types';

interface ActivitySectionProps {
  data: ActivityMetric;
  timeRange: HealthTimeRange;
}

export const ActivitySection: React.FC<ActivitySectionProps> = ({
  data,
  timeRange,
}) => {
  const [hoveredBar, setHoveredBar] = useState<{
    label: string;
    steps: number;
    activeMinutes: number;
  } | null>(null);

  const stepPercent = Math.min(Math.round((data.steps / data.stepGoal) * 100), 100);
  const activeMinsPercent = Math.min(
    Math.round((data.activeMinutes / data.activeMinutesGoal) * 100),
    100
  );

  const maxSteps = Math.max(...data.trend.map((t) => t.steps), 2500);

  return (
    <Card
      id="health-activity-card"
      variant="elevated"
      padding="md"
      className="space-y-4"
    >
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 pb-3 border-b border-[var(--color-border-subtle)]">
        <div className="flex items-center gap-2.5">
          <div className="w-8 h-8 rounded-xl surface-raised flex items-center justify-center text-emerald-500 border border-[var(--color-border-subtle)] shadow-xs flex-shrink-0">
            <Footprints className="w-4 h-4" />
          </div>
          <div>
            <h3 className="text-sm font-bold text-[var(--color-text-primary)]">
              Daily Activity & Cadence
            </h3>
            <p className="text-[11px] text-[var(--color-text-muted)]">
              Pedometer accelerometer counts, active cadence, and estimated expenditure
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2 text-xs">
          <span className="text-[var(--color-text-muted)]">Goal:</span>
          <span className="font-mono font-semibold text-[var(--color-text-secondary)]">
            {data.stepGoal.toLocaleString()} steps
          </span>
        </div>
      </div>

      {/* Metrics Row: Steps | Active Minutes | Distance/Expenditure */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
        {/* Steps */}
        <div className="p-3.5 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] flex flex-col justify-between">
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-medium text-[var(--color-text-muted)] uppercase tracking-wider">
              {timeRange === 'today' ? 'Step Count' : 'Total Steps'}
            </span>
            <span className="text-xs font-mono font-bold text-emerald-500">{stepPercent}%</span>
          </div>
          <div className="my-1.5">
            <span className="text-2xl font-bold font-mono text-[var(--color-text-primary)]">
              {data.steps.toLocaleString()}
            </span>
          </div>
          <ProgressBar value={data.steps} max={data.stepGoal} size="sm" showValue={false} />
          <div className="flex items-center justify-between text-[10px] text-[var(--color-text-muted)] mt-1.5">
            <span>Goal: {data.stepGoal.toLocaleString()}</span>
            <span>{(data.stepGoal - data.steps > 0 ? data.stepGoal - data.steps : 0).toLocaleString()} remaining</span>
          </div>
        </div>

        {/* Active Minutes */}
        <div className="p-3.5 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] flex flex-col justify-between">
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-medium text-[var(--color-text-muted)] uppercase tracking-wider">
              Active Minutes
            </span>
            <span className="text-xs font-mono font-bold text-[var(--color-accent)]">
              {activeMinsPercent}%
            </span>
          </div>
          <div className="my-1.5">
            <span className="text-2xl font-bold font-mono text-[var(--color-accent)]">
              {data.activeMinutes}
            </span>
            <span className="text-xs font-semibold text-[var(--color-text-secondary)] ml-1">mins</span>
          </div>
          <ProgressBar value={data.activeMinutes} max={data.activeMinutesGoal} size="sm" showValue={false} />
          <div className="flex items-center justify-between text-[10px] text-[var(--color-text-muted)] mt-1.5">
            <span>Goal: {data.activeMinutesGoal} min</span>
            <span className="text-emerald-500 font-medium">Brisk walking / cardio</span>
          </div>
        </div>

        {/* Distance & Calorie Estimates */}
        <div className="p-3.5 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] flex flex-col justify-between">
          <span className="text-[11px] font-medium text-[var(--color-text-muted)] uppercase tracking-wider">
            Movement Estimates
          </span>
          <div className="space-y-1.5 my-1">
            <div className="flex items-center justify-between text-xs">
              <span className="text-[var(--color-text-secondary)] flex items-center gap-1.5">
                <Compass className="w-3.5 h-3.5 text-sky-400" />
                Distance:
              </span>
              <span className="font-mono font-bold text-[var(--color-text-primary)]">
                {data.distanceKm} km
              </span>
            </div>
            <div className="flex items-center justify-between text-xs">
              <span className="text-[var(--color-text-secondary)] flex items-center gap-1.5">
                <Flame className="w-3.5 h-3.5 text-amber-500" />
                Active Burn:
              </span>
              <span className="font-mono font-bold text-[var(--color-text-primary)]">
                {data.caloriesBurnedKcal} kcal
              </span>
            </div>
          </div>
          <div className="text-[10px] text-[var(--color-text-muted)] pt-1 border-t border-[var(--color-border-subtle)]">
            Stride length calibrated by mobile sensor
          </div>
        </div>
      </div>

      {/* Activity Trend (Hourly or Daily Distribution Bars) */}
      <div className="p-3.5 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] space-y-2">
        <div className="flex items-center justify-between text-xs px-1">
          <span className="text-[11px] font-semibold text-[var(--color-text-secondary)]">
            {timeRange === 'today' ? 'Hourly Activity Distribution' : 'Daily Movement Comparison'}
          </span>
          {hoveredBar && (
            <div className="text-[11px] font-mono bg-[var(--color-surface-elevated)] px-2 py-0.5 rounded-md border border-[var(--color-border-subtle)] flex items-center gap-2">
              <span className="text-[var(--color-text-muted)]">{hoveredBar.label}:</span>
              <strong className="text-emerald-500">{hoveredBar.steps.toLocaleString()} steps</strong>
              <span className="text-[var(--color-text-muted)]">({hoveredBar.activeMinutes}m active)</span>
            </div>
          )}
        </div>

        <div className="space-y-2 pt-2">
          <div className="grid grid-cols-7 sm:grid-cols-8 gap-2 h-24 items-end border-b border-[var(--color-border-subtle)] pb-2">
            {data.trend.map((item, idx) => {
              const heightPercent = Math.max((item.steps / maxSteps) * 100, 4);
              const isPeak = item.steps > 1500;

              return (
                <div
                  key={idx}
                  className="flex flex-col items-center h-full justify-end group cursor-pointer"
                  onMouseEnter={() => setHoveredBar(item)}
                  onMouseLeave={() => setHoveredBar(null)}
                >
                  <div
                    className={`w-full max-w-[24px] rounded-t-md transition-all duration-200 group-hover:opacity-100 ${
                      isPeak
                        ? 'bg-emerald-500/80 group-hover:bg-emerald-400'
                        : 'bg-emerald-500/35 group-hover:bg-emerald-500/60'
                    }`}
                    style={{ height: `${heightPercent}%` }}
                  />
                  <span className="text-[9px] font-mono text-[var(--color-text-muted)] mt-1.5 truncate">
                    {item.label}
                  </span>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </Card>
  );
};
