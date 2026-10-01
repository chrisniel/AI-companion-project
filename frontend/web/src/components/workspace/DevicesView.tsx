import React, { useState, useEffect, useCallback } from 'react';
import {
  HardDrive,
  Monitor,
  Smartphone,
  Mic,
  Activity,
  Network,
  RotateCcw,
  Loader2,
  AlertCircle,
  AlertTriangle,
  CheckCircle2,
  Lock,
} from 'lucide-react';
import { Badge } from '../ui/Badge';
import { NeumorphicButton } from '../ui/NeumorphicButton';
import { getSystemStatus, SystemStatusResponse, ApiError } from '../../services/api';
import { useBackend } from '../../context/BackendContext';

export const DevicesView: React.FC = () => {
  let isOnline = false;
  try {
    const backend = useBackend();
    isOnline = backend.isOnline;
  } catch {
    isOnline = false;
  }

  const [systemStatus, setSystemStatus] = useState<SystemStatusResponse | null>(null);
  const [loading, setLoading] = useState<boolean>(true);
  const [errorStatus, setErrorStatus] = useState<number | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const fetchHostStatus = useCallback(async () => {
    setLoading(true);
    setErrorStatus(null);
    setErrorMessage(null);
    try {
      const data = await getSystemStatus();
      setSystemStatus(data);
    } catch (err: unknown) {
      setSystemStatus(null);
      if (err instanceof ApiError) {
        setErrorStatus(err.status);
        setErrorMessage(err.message);
      } else if (err instanceof Error) {
        setErrorMessage(err.message);
        if (err.message.includes('401')) {
          setErrorStatus(401);
        }
      } else {
        setErrorMessage('Unable to retrieve workstation telemetry.');
      }
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchHostStatus();
  }, [fetchHostStatus]);

  interface ErrorClassification {
    title: string;
    description: string;
    badgeText: string;
    iconType: 'auth' | 'forbidden' | 'server' | 'offline';
  }

  const classifyHostError = (status: number | null, online: boolean): ErrorClassification => {
    if (status === 401) {
      return {
        title: 'Workstation Telemetry Protected',
        description:
          'The local companion runtime is online and reachable, but detailed workstation telemetry requires pairing or an API authorization key. You can configure your pairing key in Settings.',
        badgeText: 'Pairing Required',
        iconType: 'auth',
      };
    }
    if (status === 403) {
      return {
        title: 'Workstation Telemetry Access Denied',
        description:
          'The configured pairing key does not have permission to access workstation telemetry.',
        badgeText: 'Forbidden',
        iconType: 'forbidden',
      };
    }
    if (status && status >= 500) {
      return {
        title: 'Workstation Telemetry Error',
        description:
          'The companion runtime encountered an internal error while querying system telemetry.',
        badgeText: 'Telemetry Error',
        iconType: 'server',
      };
    }
    return {
      title: 'Runtime Host Unavailable',
      description:
        'Unable to connect to the local companion runtime service. Please check that the backend service is running and accessible.',
      badgeText: 'Host Unavailable',
      iconType: 'offline',
    };
  };

  const classified = classifyHostError(errorStatus, isOnline);

  return (
    <div id="devices-view" className="space-y-8 pb-12">
      {/* 1. Top Header Banner */}
      <div className="p-5 sm:p-6 rounded-3xl surface-raised border border-[var(--color-border-subtle)] flex flex-col md:flex-row md:items-center justify-between gap-4 shadow-sm">
        <div className="flex items-center gap-3.5">
          <div className="w-11 h-11 rounded-2xl bg-accent-gradient flex items-center justify-center text-white glow-accent-sm flex-shrink-0">
            <HardDrive className="w-5 h-5" />
          </div>
          <div>
            <div className="flex items-center gap-2 flex-wrap">
              <h1 className="text-xl font-bold text-[var(--color-text-primary)]">
                Devices & Hardware
              </h1>
              <Badge variant="primary" size="sm" className="font-semibold">
                Host Status
              </Badge>
            </div>
            <p className="text-xs text-[var(--color-text-secondary)] mt-0.5 max-w-2xl">
              Workstation status and hardware telemetry from the companion runtime. Mobile pairing, audio routing, and wearable integrations are planned subsystems.
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2 self-start md:self-auto">
          <button
            type="button"
            onClick={fetchHostStatus}
            disabled={loading}
            aria-label="Refresh Host Status"
            title="Refresh Host Status"
            className="w-9 h-9 rounded-xl surface-raised border border-[var(--color-border-subtle)] hover:border-[var(--color-accent)]/40 hover:text-[var(--color-accent)] flex items-center justify-center text-[var(--color-text-secondary)] transition-all cursor-pointer disabled:opacity-50"
          >
            <RotateCcw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
          </button>
        </div>
      </div>

      {/* 2. Primary Host Workstation Card */}
      <div className="p-5 sm:p-6 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-5">
        <div className="flex items-center justify-between flex-wrap gap-3">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-2xl bg-[var(--color-accent)]/10 text-[var(--color-accent)] flex items-center justify-center flex-shrink-0">
              <Monitor className="w-5 h-5" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h2 className="text-base font-bold text-[var(--color-text-primary)]">
                  Primary Host Workstation
                </h2>
                {systemStatus && (
                  <Badge variant="success" size="sm">
                    Status Available
                  </Badge>
                )}
                {!loading && (errorMessage || (!systemStatus && !loading)) && (
                  <Badge variant={classified.iconType === 'auth' || classified.iconType === 'forbidden' ? 'accent' : 'danger'} size="sm">
                    {classified.badgeText}
                  </Badge>
                )}
              </div>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Local host workstation status and hardware telemetry
              </p>
            </div>
          </div>
        </div>

        {/* Loading State */}
        {loading && (
          <div
            id="devices-host-loading"
            className="py-12 flex flex-col items-center justify-center gap-3 text-center"
          >
            <Loader2 className="w-7 h-7 text-[var(--color-accent)] animate-spin" />
            <p className="text-xs text-[var(--color-text-secondary)]">
              Querying local workstation telemetry...
            </p>
          </div>
        )}

        {/* Error / Unavailable State */}
        {!loading && (errorMessage || (!systemStatus && !loading)) && (
          <div
            id="devices-host-error"
            className="p-6 rounded-2xl bg-surface-subtle border border-[var(--color-border-subtle)] space-y-4"
          >
            <div className="flex items-start gap-3">
              {classified.iconType === 'auth' || classified.iconType === 'forbidden' ? (
                <Lock className="w-5 h-5 text-[var(--color-accent)] flex-shrink-0 mt-0.5" />
              ) : classified.iconType === 'server' ? (
                <AlertTriangle className="w-5 h-5 text-amber-500 flex-shrink-0 mt-0.5" />
              ) : (
                <AlertCircle className="w-5 h-5 text-rose-500 flex-shrink-0 mt-0.5" />
              )}
              <div className="space-y-1">
                <h3 className="text-sm font-semibold text-[var(--color-text-primary)]">
                  {classified.title}
                </h3>
                <p className="text-xs text-[var(--color-text-secondary)] leading-relaxed">
                  {classified.description}
                </p>
              </div>
            </div>
            <div className="flex justify-end">
              <button
                type="button"
                onClick={fetchHostStatus}
                disabled={loading}
                className="px-3.5 py-1.5 rounded-xl surface-raised border border-[var(--color-border-subtle)] hover:border-[var(--color-accent)]/40 hover:text-[var(--color-accent)] text-xs font-medium text-[var(--color-text-primary)] transition-all cursor-pointer disabled:opacity-50"
              >
                Try again
              </button>
            </div>
          </div>
        )}

        {/* Success: Real Telemetry Grid */}
        {!loading && systemStatus && (
          <div id="devices-host-telemetry" className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
            {/* Hostname */}
            <div className="p-4 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] space-y-1">
              <div className="text-[10px] text-[var(--color-text-muted)] font-semibold uppercase tracking-wider">
                Hostname
              </div>
              <div className="text-sm font-bold text-[var(--color-text-primary)] truncate font-mono">
                {systemStatus.hostname}
              </div>
            </div>

            {/* Platform / OS */}
            <div className="p-4 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] space-y-1">
              <div className="text-[10px] text-[var(--color-text-muted)] font-semibold uppercase tracking-wider">
                Platform
              </div>
              <div className="text-sm font-bold text-[var(--color-text-primary)] truncate">
                {systemStatus.platform}
              </div>
            </div>

            {/* Backend Version */}
            <div className="p-4 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] space-y-1">
              <div className="text-[10px] text-[var(--color-text-muted)] font-semibold uppercase tracking-wider">
                Backend Version
              </div>
              <div className="text-sm font-bold text-[var(--color-text-primary)] font-mono">
                {systemStatus.version}
              </div>
            </div>

            {/* Python Version */}
            <div className="p-4 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] space-y-1">
              <div className="text-[10px] text-[var(--color-text-muted)] font-semibold uppercase tracking-wider">
                Python Runtime
              </div>
              <div className="text-sm font-bold text-[var(--color-text-primary)] font-mono truncate">
                {systemStatus.python_version}
              </div>
            </div>

            {/* CPU Cores */}
            <div className="p-4 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] space-y-1">
              <div className="text-[10px] text-[var(--color-text-muted)] font-semibold uppercase tracking-wider">
                CPU Count
              </div>
              <div className="text-sm font-bold text-[var(--color-text-primary)]">
                {systemStatus.cpu_count} Cores
              </div>
            </div>

            {/* Database Connected */}
            <div className="p-4 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] space-y-1">
              <div className="text-[10px] text-[var(--color-text-muted)] font-semibold uppercase tracking-wider">
                SQLite Store
              </div>
              <div className="flex items-center gap-1.5 text-sm font-bold">
                {systemStatus.database_connected ? (
                  <>
                    <CheckCircle2 className="w-4 h-4 text-emerald-500" />
                    <span className="text-emerald-600 dark:text-emerald-400">Connected</span>
                  </>
                ) : (
                  <>
                    <AlertCircle className="w-4 h-4 text-amber-500" />
                    <span className="text-amber-500">Unavailable</span>
                  </>
                )}
              </div>
            </div>

            {/* Runtime Status */}
            <div className="p-4 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] space-y-1">
              <div className="text-[10px] text-[var(--color-text-muted)] font-semibold uppercase tracking-wider">
                Runtime Health
              </div>
              <div className="text-sm font-bold text-[var(--color-text-primary)] uppercase">
                {systemStatus.status}
              </div>
            </div>

            {/* Timestamp */}
            <div className="p-4 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] space-y-1">
              <div className="text-[10px] text-[var(--color-text-muted)] font-semibold uppercase tracking-wider">
                Reported Timestamp
              </div>
              <div className="text-xs text-[var(--color-text-secondary)] font-mono truncate">
                {new Date(systemStatus.timestamp).toLocaleTimeString()}
              </div>
            </div>
          </div>
        )}
      </div>

      {/* 3. Planned Subsystems */}
      <div className="space-y-4">
        <div>
          <h2 className="text-base font-bold text-[var(--color-text-primary)]">
            Connected Subsystems
          </h2>
          <p className="text-xs text-[var(--color-text-secondary)]">
            External device endpoints, audio hardware routing, and companion sync bridges are planned capabilities.
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
          {/* A. Android Companion */}
          <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2.5">
                <Smartphone className="w-4 h-4 text-[var(--color-accent)]" />
                <h3 className="text-sm font-semibold text-[var(--color-text-primary)]">
                  Android Companion
                </h3>
              </div>
              <Badge variant="neutral" size="sm">
                Planned
              </Badge>
            </div>
            <p className="text-xs text-[var(--color-text-secondary)] leading-relaxed">
              Android companion connectivity and synchronization are not implemented yet.
            </p>
          </div>

          {/* B. Audio Device Management */}
          <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2.5">
                <Mic className="w-4 h-4 text-[var(--color-accent)]" />
                <h3 className="text-sm font-semibold text-[var(--color-text-primary)]">
                  Audio Device Management
                </h3>
              </div>
              <Badge variant="neutral" size="sm">
                Planned
              </Badge>
            </div>
            <p className="text-xs text-[var(--color-text-secondary)] leading-relaxed">
              Microphone, speaker and audio-device management are not implemented yet.
            </p>
          </div>

          {/* C. Health & Wearables */}
          <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2.5">
                <Activity className="w-4 h-4 text-[var(--color-accent)]" />
                <h3 className="text-sm font-semibold text-[var(--color-text-primary)]">
                  Health & Wearables
                </h3>
              </div>
              <Badge variant="neutral" size="sm">
                Planned
              </Badge>
            </div>
            <p className="text-xs text-[var(--color-text-secondary)] leading-relaxed">
              Health and wearable integrations are not implemented yet.
            </p>
          </div>

          {/* D. Remote Runtime Access */}
          <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2.5">
                <Network className="w-4 h-4 text-[var(--color-accent)]" />
                <h3 className="text-sm font-semibold text-[var(--color-text-primary)]">
                  Remote Runtime Access
                </h3>
              </div>
              <Badge variant="neutral" size="sm">
                Planned
              </Badge>
            </div>
            <p className="text-xs text-[var(--color-text-secondary)] leading-relaxed">
              Trusted remote access over LAN/Tailscale is future work. The current runtime remains local-only by default.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};
