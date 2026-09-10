import React, { useState } from 'react';
import { HeartPulse, Activity, RefreshCw, Moon, Droplets, Check } from 'lucide-react';
import { Toggle } from '../../ui/Toggle';
import { NeumorphicButton } from '../../ui/NeumorphicButton';
import { useTheme } from '../../../context/ThemeContext';

export interface HealthSettingsState {
  healthProvider: string;
  syncIntervalMinutes: number;
  syncWhileIdle: boolean;
  continuousHeartRateSampling: boolean;
  sleepScoreAnalysis: boolean;
  postureAlerts: boolean;
  hydrationAlerts: boolean;
  stressAlerts: boolean;
}

interface HealthSectionProps {
  settings: HealthSettingsState;
  onUpdate: <K extends keyof HealthSettingsState>(key: K, value: HealthSettingsState[K]) => void;
}

export const HealthSection: React.FC<HealthSectionProps> = ({ settings, onUpdate }) => {
  const { mode } = useTheme();
  const [isSyncing, setIsSyncing] = useState(false);
  const [lastSyncText, setLastSyncText] = useState('Today at 10:42 AM');

  const handleManualSync = () => {
    setIsSyncing(true);
    setTimeout(() => {
      setIsSyncing(false);
      const now = new Date();
      setLastSyncText(`Just now (${now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })})`);
    }, 1800);
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h2 className="text-base font-bold text-[var(--color-text-primary)] flex items-center gap-2">
          <HeartPulse className="w-5 h-5 text-rose-500" />
          Health Synchronization & Biometrics
        </h2>
        <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">
          Connect wearable sensors, control local SQLite vault synchronization, and toggle wellness analytics.
        </p>
      </div>

      {/* 1. Health Provider */}
      <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
        <h3 className="text-xs font-bold uppercase tracking-wider font-mono text-[var(--color-accent)] flex items-center gap-1.5">
          <Activity className="w-4 h-4" />
          Biometric Hardware Provider
        </h3>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
          {[
            {
              id: 'fitcloudpro_ble',
              title: 'FitCloudPro BLE Smart Watch',
              badge: 'Connected',
              desc: 'Direct Bluetooth LE GATT service connection for continuous HR, SpO2, and pedometer steps.',
            },
            {
              id: 'apple_healthkit',
              title: 'Apple HealthKit Local Bridge',
              badge: 'Daemon Ready',
              desc: 'Read-only local SQLite bridge pulling workouts, sleep cycles, and resting vitals.',
            },
            {
              id: 'sqlite_vault_only',
              title: 'Local SQLite Vault (Airgap Only)',
              badge: 'Encrypted',
              desc: 'Stores biometric logs strictly within on-disk local database without external wearable polling.',
            },
            {
              id: 'manual_entry',
              title: 'Manual Entry Mode',
              badge: 'Manual',
              desc: 'Disable all automatic sensor polling; log vitals exclusively via manual assistant chat prompts.',
            },
          ].map((provider) => {
            const isSelected = settings.healthProvider === provider.id;
            return (
              <button
                key={provider.id}
                type="button"
                onClick={() => onUpdate('healthProvider', provider.id)}
                className={`p-4 rounded-2xl border text-left transition-all ${
                  isSelected
                    ? 'border-[var(--color-accent)] bg-[var(--color-surface-elevated)] ring-2 ring-[var(--color-accent)]/20 shadow-sm'
                    : 'border-[var(--color-border-subtle)] bg-[var(--color-surface-elevated)]/40 hover:bg-[var(--color-surface-elevated)]'
                }`}
              >
                <div className="flex items-center justify-between">
                  <h4 className="text-sm font-bold text-[var(--color-text-primary)]">
                    {provider.title}
                  </h4>
                  <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-[var(--color-surface-secondary)] text-[var(--color-text-muted)]">
                    {provider.badge}
                  </span>
                </div>
                <p className="text-xs text-[var(--color-text-secondary)] mt-1 leading-relaxed">
                  {provider.desc}
                </p>
              </button>
            );
          })}
        </div>
      </div>

      {/* 2. Synchronization */}
      <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
        <div className="flex items-center justify-between">
          <h3 className="text-xs font-bold uppercase tracking-wider font-mono text-[var(--color-accent)] flex items-center gap-1.5">
            <RefreshCw className="w-4 h-4" />
            Sensor Synchronization Schedules
          </h3>
          <NeumorphicButton
            variant="ghost"
            size="sm"
            onClick={handleManualSync}
            disabled={isSyncing}
            icon={<RefreshCw className={`w-3.5 h-3.5 ${isSyncing ? 'animate-spin text-[var(--color-accent)]' : ''}`} />}
          >
            {isSyncing ? 'Syncing...' : 'Sync Now'}
          </NeumorphicButton>
        </div>

        <div className="space-y-4">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
            <div>
              <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                Automatic Background Sync Frequency
              </span>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Last synced: <strong className="text-[var(--color-text-primary)] font-mono">{lastSyncText}</strong>
              </p>
            </div>
            <select
              value={settings.syncIntervalMinutes}
              onChange={(e) => onUpdate('syncIntervalMinutes', Number(e.target.value))}
              style={{ colorScheme: mode }}
              className="px-3.5 py-2 rounded-xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-xs font-medium text-[var(--color-text-primary)] focus:outline-none focus:border-[var(--color-accent)] cursor-pointer shadow-xs"
            >
              <option value={5} className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Every 5 minutes (Real-time)</option>
              <option value={15} className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Every 15 minutes (Standard)</option>
              <option value={60} className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Every 1 hour (Power saver)</option>
              <option value={0} className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Manual On-Demand Only</option>
            </select>
          </div>

          <div className="flex items-center justify-between gap-4 pt-3 border-t border-[var(--color-border-subtle)]">
            <div>
              <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                Synchronize While System Idle
              </span>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Trigger BLE telemetry fetch when user is away to prevent Bluetooth interface contention.
              </p>
            </div>
            <Toggle
              checked={settings.syncWhileIdle}
              onChange={(val) => onUpdate('syncWhileIdle', val)}
              size="sm"
            />
          </div>

          <div className="flex items-center justify-between gap-4 pt-3 border-t border-[var(--color-border-subtle)]">
            <div>
              <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                High-Frequency Optical Heart Rate Polling
              </span>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Sample optical PPG sensor continuously at 1Hz during focused task sessions.
              </p>
            </div>
            <Toggle
              checked={settings.continuousHeartRateSampling}
              onChange={(val) => onUpdate('continuousHeartRateSampling', val)}
              size="sm"
            />
          </div>
        </div>
      </div>

      {/* 3. Wellness Insights */}
      <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
        <h3 className="text-xs font-bold uppercase tracking-wider font-mono text-[var(--color-accent)] flex items-center gap-1.5">
          <Moon className="w-4 h-4" />
          Wellness & Autonomous Health Analytics
        </h3>

        <div className="space-y-3.5">
          <div className="flex items-center justify-between gap-4">
            <div>
              <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                Circadian Sleep Architecture & HRV Recovery Score
              </span>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Calculate daily sleep efficiency, deep/REM proportions, and morning autonomic readiness.
              </p>
            </div>
            <Toggle
              checked={settings.sleepScoreAnalysis}
              onChange={(val) => onUpdate('sleepScoreAnalysis', val)}
              size="sm"
            />
          </div>

          <div className="flex items-center justify-between gap-4 pt-3 border-t border-[var(--color-border-subtle)]">
            <div>
              <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                Sedentary Posture & Movement Alerts
              </span>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Gentle desktop nudge when stationary for more than 50 consecutive minutes.
              </p>
            </div>
            <Toggle
              checked={settings.postureAlerts}
              onChange={(val) => onUpdate('postureAlerts', val)}
              size="sm"
            />
          </div>

          <div className="flex items-center justify-between gap-4 pt-3 border-t border-[var(--color-border-subtle)]">
            <div>
              <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                Hydration Reminders
              </span>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Contextual prompts to drink water adjusted for active day temperature and desk time.
              </p>
            </div>
            <Toggle
              checked={settings.hydrationAlerts}
              onChange={(val) => onUpdate('hydrationAlerts', val)}
              size="sm"
            />
          </div>

          <div className="flex items-center justify-between gap-4 pt-3 border-t border-[var(--color-border-subtle)]">
            <div>
              <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                Elevated Stress & HRV Anomaly Detection
              </span>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Suggest 2-minute box breathing when sympathetic heart rate spike is detected.
              </p>
            </div>
            <Toggle
              checked={settings.stressAlerts}
              onChange={(val) => onUpdate('stressAlerts', val)}
              size="sm"
            />
          </div>
        </div>
      </div>
    </div>
  );
};
