import React from 'react';
import { SlidersHorizontal, Globe, Clock, Laptop, PlayCircle } from 'lucide-react';
import { Toggle } from '../../ui/Toggle';
import { useTheme } from '../../../context/ThemeContext';

export interface GeneralSettingsState {
  launchAtBoot: boolean;
  startMinimized: boolean;
  resumeLastView: boolean;
  defaultStartupView: string;
  language: string;
  assistantVoiceLanguage: string;
  autoDetectTimezone: boolean;
  timezone: string;
  use24HourTime: boolean;
}

interface GeneralSectionProps {
  settings: GeneralSettingsState;
  onUpdate: <K extends keyof GeneralSettingsState>(key: K, value: GeneralSettingsState[K]) => void;
}

export const GeneralSection: React.FC<GeneralSectionProps> = ({ settings, onUpdate }) => {
  const { mode } = useTheme();

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h2 className="text-base font-bold text-[var(--color-text-primary)] flex items-center gap-2">
          <SlidersHorizontal className="w-5 h-5 text-[var(--color-accent)]" />
          General System Preferences
        </h2>
        <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">
          Configure startup orchestration, localization standards, and time format parameters.
        </p>
      </div>

      {/* Startup Behavior */}
      <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
        <h3 className="text-xs font-bold uppercase tracking-wider font-mono text-[var(--color-accent)] flex items-center gap-1.5">
          <Laptop className="w-4 h-4" />
          Startup & Window Behavior
        </h3>

        <div className="space-y-4">
          <div className="flex items-center justify-between gap-4">
            <div>
              <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                Launch Local AI on System Login
              </span>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Automatically boot the background inference server and hardware engine at OS startup.
              </p>
            </div>
            <Toggle
              checked={settings.launchAtBoot}
              onChange={(val) => onUpdate('launchAtBoot', val)}
              size="sm"
            />
          </div>

          <div className="flex items-center justify-between gap-4 pt-3 border-t border-[var(--color-border-subtle)]">
            <div>
              <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                Start Minimized to Menu Bar / System Tray
              </span>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Keep the local engine ready in the background without bringing up the primary window.
              </p>
            </div>
            <Toggle
              checked={settings.startMinimized}
              onChange={(val) => onUpdate('startMinimized', val)}
              size="sm"
            />
          </div>

          <div className="flex items-center justify-between gap-4 pt-3 border-t border-[var(--color-border-subtle)]">
            <div>
              <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                Resume Last Active View on Open
              </span>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Reopen the exact workspace panel (Tasks, Health, Models) you were viewing previously.
              </p>
            </div>
            <Toggle
              checked={settings.resumeLastView}
              onChange={(val) => onUpdate('resumeLastView', val)}
              size="sm"
            />
          </div>

          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pt-3 border-t border-[var(--color-border-subtle)]">
            <div>
              <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                Default Startup View
              </span>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Primary canvas rendered when the application starts fresh.
              </p>
            </div>
            <div className="relative">
              <select
                value={settings.defaultStartupView}
                onChange={(e) => onUpdate('defaultStartupView', e.target.value)}
                style={{ colorScheme: mode }}
                className="px-3.5 py-2 pr-8 rounded-xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-xs font-medium text-[var(--color-text-primary)] focus:outline-none focus:border-[var(--color-accent)] transition-all cursor-pointer shadow-xs"
              >
                <option value="home" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Home Dashboard</option>
                <option value="assistant" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Assistant Voice & Chat</option>
                <option value="schedule" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Schedule & Calendar</option>
                <option value="health" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Wellness & Health</option>
              </select>
            </div>
          </div>
        </div>
      </div>

      {/* Language */}
      <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
        <h3 className="text-xs font-bold uppercase tracking-wider font-mono text-[var(--color-accent)] flex items-center gap-1.5">
          <Globe className="w-4 h-4" />
          Language & Regional Localization
        </h3>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-[var(--color-text-primary)]">
              Application Interface Language
            </label>
            <select
              value={settings.language}
              onChange={(e) => onUpdate('language', e.target.value)}
              style={{ colorScheme: mode }}
              className="w-full px-3.5 py-2.5 rounded-2xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-primary)] font-medium focus:outline-none focus:border-[var(--color-accent)] transition-all cursor-pointer shadow-xs"
            >
              <option value="en-US" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>English (United States)</option>
              <option value="en-GB" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>English (United Kingdom)</option>
              <option value="es-ES" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Español (Castellano)</option>
              <option value="fr-FR" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Français (France)</option>
              <option value="de-DE" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Deutsch (Deutschland)</option>
              <option value="ja-JP" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>日本語 (Japanese)</option>
            </select>
          </div>

          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-[var(--color-text-primary)]">
              Assistant Natural Voice Language
            </label>
            <select
              value={settings.assistantVoiceLanguage}
              onChange={(e) => onUpdate('assistantVoiceLanguage', e.target.value)}
              style={{ colorScheme: mode }}
              className="w-full px-3.5 py-2.5 rounded-2xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-primary)] font-medium focus:outline-none focus:border-[var(--color-accent)] transition-all cursor-pointer shadow-xs"
            >
              <option value="en-US" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>English (American - Standard)</option>
              <option value="en-GB" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>English (British - Natural)</option>
              <option value="es" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Spanish (Neutral Latin America)</option>
              <option value="fr" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>French (Standard Parisian)</option>
              <option value="de" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>German (Hochdeutsch)</option>
            </select>
          </div>
        </div>
      </div>

      {/* Timezone */}
      <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
        <h3 className="text-xs font-bold uppercase tracking-wider font-mono text-[var(--color-accent)] flex items-center gap-1.5">
          <Clock className="w-4 h-4" />
          Timezone & Clock Standards
        </h3>

        <div className="space-y-4">
          <div className="flex items-center justify-between gap-4">
            <div>
              <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                Auto-Detect System Timezone
              </span>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Sync scheduling, alarm triggers, and health timestamps with host system clock.
              </p>
            </div>
            <Toggle
              checked={settings.autoDetectTimezone}
              onChange={(val) => onUpdate('autoDetectTimezone', val)}
              size="sm"
            />
          </div>

          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pt-3 border-t border-[var(--color-border-subtle)]">
            <div>
              <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                Primary Reference Timezone
              </span>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Used for cron schedules, sleep cycle analysis, and calendar events.
              </p>
            </div>
            <select
              value={settings.timezone}
              disabled={settings.autoDetectTimezone}
              onChange={(e) => onUpdate('timezone', e.target.value)}
              style={{ colorScheme: mode }}
              className="px-3.5 py-2 rounded-xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-xs font-medium text-[var(--color-text-primary)] focus:outline-none focus:border-[var(--color-accent)] disabled:opacity-50 cursor-pointer shadow-xs"
            >
              <option value="America/Los_Angeles" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>America/Los_Angeles (UTC-07:00 / PDT)</option>
              <option value="America/Denver" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>America/Denver (UTC-06:00 / MDT)</option>
              <option value="America/Chicago" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>America/Chicago (UTC-05:00 / CDT)</option>
              <option value="America/New_York" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>America/New_York (UTC-04:00 / EDT)</option>
              <option value="UTC" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>UTC (Universal Time Coordinated)</option>
              <option value="Europe/London" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Europe/London (UTC+01:00 / BST)</option>
              <option value="Europe/Berlin" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Europe/Berlin (UTC+02:00 / CEST)</option>
              <option value="Asia/Tokyo" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Asia/Tokyo (UTC+09:00 / JST)</option>
            </select>
          </div>

          <div className="flex items-center justify-between gap-4 pt-3 border-t border-[var(--color-border-subtle)]">
            <div>
              <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                Use 24-Hour Military Time Format
              </span>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Render clock displays as 14:00 instead of 2:00 PM throughout the workspace.
              </p>
            </div>
            <Toggle
              checked={settings.use24HourTime}
              onChange={(val) => onUpdate('use24HourTime', val)}
              size="sm"
            />
          </div>
        </div>
      </div>
    </div>
  );
};
