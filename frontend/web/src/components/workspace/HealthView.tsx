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
} from 'lucide-react';
import { Badge } from '../ui/Badge';
import { HealthPipelineCard } from './health/HealthPipelineCard';
import { HeartRateSection } from './health/HeartRateSection';
import { SleepSection } from './health/SleepSection';
import { ActivitySection } from './health/ActivitySection';
import { BloodOxygenSection } from './health/BloodOxygenSection';
import { HealthInsightsSection } from './health/HealthInsightsSection';
import { DataAvailabilityBanner } from './health/DataAvailabilityBanner';

import {
  HealthSourceProvider,
  HealthTimeRange,
} from '../../types';
import {
  mockHealthProviders,
  getPipelineStages,
  mockHeartRateToday,
  mockHeartRateWeek,
  mockHeartRateMonth,
  mockSleepToday,
  mockSleepWeek,
  mockSleepMonth,
  mockActivityToday,
  mockActivityWeek,
  mockActivityMonth,
  mockBloodOxygenToday,
  mockBloodOxygenWeek,
  mockBloodOxygenMonth,
  mockHealthInsights,
} from '../../mock/healthData';

function formatMinutes(mins: number): string {
  const h = Math.floor(mins / 60);
  const m = mins % 60;
  return `${h}h ${m}m`;
}

export const HealthView: React.FC = () => {
  const [timeRange, setTimeRange] = useState<HealthTimeRange>('today');
  const [selectedProvider, setSelectedProvider] = useState<HealthSourceProvider>(
    mockHealthProviders[0] // FitCloudPro as active default
  );
  const [simulateMissingSpO2, setSimulateMissingSpO2] = useState(false);
  const [isSyncing, setIsSyncing] = useState(false);

  // Dynamic datasets based on selected time range
  const heartRateData =
    timeRange === 'today'
      ? mockHeartRateToday
      : timeRange === 'week'
      ? mockHeartRateWeek
      : mockHeartRateMonth;

  const sleepData =
    timeRange === 'today'
      ? mockSleepToday
      : timeRange === 'week'
      ? mockSleepWeek
      : mockSleepMonth;

  const activityData =
    timeRange === 'today'
      ? mockActivityToday
      : timeRange === 'week'
      ? mockActivityWeek
      : mockActivityMonth;

  // Handle SpO2 data availability based on toggle & provider support
  const rawBloodOxygen =
    timeRange === 'today'
      ? mockBloodOxygenToday
      : timeRange === 'week'
      ? mockBloodOxygenWeek
      : mockBloodOxygenMonth;

  const bloodOxygenData = {
    ...rawBloodOxygen,
    isAvailable: !simulateMissingSpO2 && selectedProvider.supportsSpO2,
    measurements:
      !simulateMissingSpO2 && selectedProvider.supportsSpO2
        ? rawBloodOxygen.measurements
        : [],
  };

  const pipelineStages = getPipelineStages(selectedProvider.name);

  const handleRefreshSync = () => {
    setIsSyncing(true);
    setTimeout(() => {
      setIsSyncing(false);
    }, 1000);
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
                Personal lifestyle telemetry, circadian tracking, and wearable activity data synced to your Local AI Core.
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

      {/* HEALTH SOURCE PIPELINE: FitCloudPro → Health Connect → Mobile App → Local AI Core */}
      <HealthPipelineCard
        selectedProvider={selectedProvider}
        providers={mockHealthProviders}
        pipelineStages={pipelineStages}
        onSelectProvider={setSelectedProvider}
        isSyncing={isSyncing}
        onRefreshSync={handleRefreshSync}
      />

      {/* SUMMARY METRICS: Heart Rate, Sleep, Steps, Activity, Blood Oxygen */}
      <div className="space-y-2">
        <div className="flex items-center justify-between px-1 text-xs">
          <span className="font-bold text-[var(--color-text-primary)] uppercase tracking-wider text-[11px]">
            {timeRange === 'today' ? 'Today’s Summary' : timeRange === 'week' ? 'Weekly Aggregate' : 'Monthly Aggregate'}
          </span>
          <span className="text-[11px] text-[var(--color-text-muted)] font-mono">
            Provider: {selectedProvider.name}
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
              <span className="text-2xl font-bold font-mono text-[var(--color-text-primary)]">
                {heartRateData.currentBpm}
              </span>
              <span className="text-xs text-[var(--color-text-secondary)] font-medium">bpm</span>
            </div>
            <div className="text-[10px] text-[var(--color-text-muted)] pt-1 border-t border-[var(--color-border-subtle)] flex items-center justify-between">
              <span>Resting: <strong>{heartRateData.restingAvgBpm} bpm</strong></span>
              <span>{heartRateData.minBpm}–{heartRateData.maxBpm}</span>
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
              <span className="text-2xl font-bold font-mono text-[var(--color-text-primary)]">
                {formatMinutes(sleepData.totalMinutes)}
              </span>
            </div>
            <div className="text-[10px] text-[var(--color-text-muted)] pt-1 border-t border-[var(--color-border-subtle)] flex items-center justify-between">
              <span>Avg: <strong>{formatMinutes(sleepData.recentAvgMinutes)}</strong></span>
              <span className="text-indigo-400 font-mono">{sleepData.consistencyPercentage}% reg</span>
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
              <span className="text-2xl font-bold font-mono text-[var(--color-text-primary)]">
                {activityData.steps.toLocaleString()}
              </span>
            </div>
            <div className="text-[10px] text-[var(--color-text-muted)] pt-1 border-t border-[var(--color-border-subtle)] flex items-center justify-between">
              <span>Goal: {activityData.stepGoal.toLocaleString()}</span>
              <span className="text-emerald-500 font-bold font-mono">
                {Math.round((activityData.steps / activityData.stepGoal) * 100)}%
              </span>
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
              <span className="text-2xl font-bold font-mono text-[var(--color-accent)]">
                {activityData.activeMinutes}
              </span>
              <span className="text-xs text-[var(--color-text-secondary)] font-medium">mins</span>
            </div>
            <div className="text-[10px] text-[var(--color-text-muted)] pt-1 border-t border-[var(--color-border-subtle)] flex items-center justify-between">
              <span>Burn: <strong>{activityData.caloriesBurnedKcal} kcal</strong></span>
              <span>{activityData.distanceKm} km</span>
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
              {bloodOxygenData.isAvailable && bloodOxygenData.latestPercentage ? (
                <>
                  <span className="text-2xl font-bold font-mono text-cyan-400">
                    {bloodOxygenData.latestPercentage}
                  </span>
                  <span className="text-xs text-[var(--color-text-secondary)] font-medium">%</span>
                </>
              ) : (
                <span className="text-xs font-semibold text-[var(--color-text-muted)]">
                  Unavailable
                </span>
              )}
            </div>
            <div className="text-[10px] text-[var(--color-text-muted)] pt-1 border-t border-[var(--color-border-subtle)] flex items-center justify-between">
              {bloodOxygenData.isAvailable ? (
                <>
                  <span>Spot test: {bloodOxygenData.latestTimestamp}</span>
                  <span className="text-cyan-400 font-mono">Resting</span>
                </>
              ) : (
                <span className="text-amber-500 font-mono">No SpO2 data</span>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* CORE TELEMETRY SECTIONS */}
      <div className="space-y-6">
        {/* Heart Rate Section */}
        <HeartRateSection
          data={heartRateData}
          timeRange={timeRange}
        />

        {/* Sleep Section */}
        <SleepSection
          data={sleepData}
          timeRange={timeRange}
          provider={selectedProvider}
        />

        {/* Activity Section */}
        <ActivitySection
          data={activityData}
          timeRange={timeRange}
        />

        {/* Blood Oxygen Section */}
        <BloodOxygenSection
          data={bloodOxygenData}
          provider={selectedProvider}
        />
      </div>

      {/* SOFT GLASS INSIGHTS: Non-Diagnostic Observations */}
      <HealthInsightsSection insights={mockHealthInsights} />

      {/* DATA AVAILABILITY & CAPABILITIES */}
      <DataAvailabilityBanner
        provider={selectedProvider}
        simulateMissingSpO2={simulateMissingSpO2}
        onToggleSimulateMissingSpO2={() => setSimulateMissingSpO2(!simulateMissingSpO2)}
      />
    </div>
  );
};
