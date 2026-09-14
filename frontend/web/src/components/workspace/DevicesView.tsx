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
  CheckCircle2,
  Cpu,
  Clock,
  Database,
  Layers,
  Info,
} from 'lucide-react';
import { Badge } from '../ui/Badge';
import { NeumorphicButton } from '../ui/NeumorphicButton';
import { getSystemStatus, SystemStatusResponse } from '../../services/api';

export const DevicesView: React.FC = () => {
  const [systemStatus, setSystemStatus] = useState<SystemStatusResponse | null>(null);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);

  const fetchHostStatus = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await getSystemStatus();
      setSystemStatus(data);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Unable to reach backend runtime status endpoint';
      setError(msg);
      setSystemStatus(null);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchHostStatus();
  }, [fetchHostStatus]);

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
                Devices & Hardware Infrastructure
              </h1>
              <Badge variant="primary" size="sm" className="font-semibold">
                Host Monitored
              </Badge>
              <Badge variant="neutral" size="sm">
                Hybrid Truthfulness
              </Badge>
            </div>
            <p className="text-xs text-[var(--color-text-secondary)] mt-0.5 max-w-2xl">
              Real host workstation telemetry from the local runtime service. Mobile, audio routing, wearable devices, and remote mesh are planned subsystems.
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2 self-start md:self-auto">
          <NeumorphicButton
            variant="ghost"
            size="sm"
            onClick={fetchHostStatus}
            disabled={loading}
            className="flex items-center gap-1.5 text-xs text-[var(--color-text-secondary)]"
            title="Refresh Host Status"
          >
            <RotateCcw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
            <span>Refresh</span>
          </NeumorphicButton>
        </div>
      </div>

      {/* 2. Primary Host Workstation Card (REAL AUTHORITATIVE DATA) */}
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
                    Runtime Online
                  </Badge>
                )}
                {error && (
                  <Badge variant="danger" size="sm">
                    Runtime Offline
                  </Badge>
                )}
              </div>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Authoritative runtime telemetry via GET /api/v1/system/status
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
              Querying local workstation runtime telemetry...
            </p>
          </div>
        )}

        {/* Error / Unavailable State */}
        {!loading && error && (
          <div
            id="devices-host-error"
            className="p-6 rounded-2xl bg-amber-500/10 border border-amber-500/20 space-y-4"
          >
            <div className="flex items-start gap-3">
              <AlertCircle className="w-5 h-5 text-amber-500 flex-shrink-0 mt-0.5" />
              <div className="space-y-1">
                <h3 className="text-sm font-semibold text-amber-600 dark:text-amber-400">
                  Runtime Host Unavailable
                </h3>
                <p className="text-xs text-[var(--color-text-secondary)]">
                  Could not retrieve authoritative host telemetry from the local companion runtime.
                  The backend service may be offline or initializing.
                </p>
                <p className="text-[11px] font-mono text-[var(--color-text-muted)] mt-1">
                  {error}
                </p>
              </div>
            </div>
            <div className="flex justify-end">
              <NeumorphicButton
                variant="primary"
                size="sm"
                onClick={fetchHostStatus}
                className="flex items-center gap-1.5 text-xs"
              >
                <RotateCcw className="w-3.5 h-3.5" />
                <span>Retry</span>
              </NeumorphicButton>
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

      {/* 3. Unsupported Subsystems (Truthfully Labeled Planned) */}
      <div className="space-y-4">
        <div>
          <h2 className="text-base font-bold text-[var(--color-text-primary)]">
            Subsystem Infrastructure
          </h2>
          <p className="text-xs text-[var(--color-text-secondary)]">
            External hardware endpoints, audio device routing, and synchronization bridges are planned capabilities.
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
          {/* A. Android Companion Sync */}
          <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2.5">
                <Smartphone className="w-4 h-4 text-[var(--color-accent)]" />
                <h3 className="text-sm font-semibold text-[var(--color-text-primary)]">
                  Android Companion Sync
                </h3>
              </div>
              <Badge variant="neutral" size="sm">
                Planned Bridge
              </Badge>
            </div>
            <p className="text-xs text-[var(--color-text-secondary)] leading-relaxed">
              Peer-to-peer synchronization with the Android companion app. Bi-directional memory sync, push notification relay, and on-device alarm coordination.
            </p>
            <div className="p-3 rounded-xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-[11px] text-[var(--color-text-muted)]">
              Status: Sync bridge daemon not implemented in this phase.
            </div>
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
                Planned Subsystem
              </Badge>
            </div>
            <p className="text-xs text-[var(--color-text-secondary)] leading-relaxed">
              Hardware microphone selection, speaker routing, audio frame buffer configuration, and Bluetooth headset handoff.
            </p>
            <div className="p-3 rounded-xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-[11px] text-[var(--color-text-muted)]">
              Status: Audio routing will be managed by native wrapper / future audio subsystem.
            </div>
          </div>

          {/* C. Health & Wearable Sources */}
          <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2.5">
                <Activity className="w-4 h-4 text-[var(--color-accent)]" />
                <h3 className="text-sm font-semibold text-[var(--color-text-primary)]">
                  Health & Wearables
                </h3>
              </div>
              <Badge variant="neutral" size="sm">
                Planned Gateway
              </Badge>
            </div>
            <p className="text-xs text-[var(--color-text-secondary)] leading-relaxed">
              Direct BLE and Health Connect synchronization for biometric data including sleep metrics, heart rate intervals, and step counts.
            </p>
            <div className="p-3 rounded-xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-[11px] text-[var(--color-text-muted)]">
              Status: Wearable integration is deferred to dedicated health integration milestone.
            </div>
          </div>

          {/* D. Remote Runtime Access (Tailscale) */}
          <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2.5">
                <Network className="w-4 h-4 text-[var(--color-accent)]" />
                <h3 className="text-sm font-semibold text-[var(--color-text-primary)]">
                  Remote Runtime Access
                </h3>
              </div>
              <Badge variant="neutral" size="sm">
                Planned Mesh
              </Badge>
            </div>
            <p className="text-xs text-[var(--color-text-secondary)] leading-relaxed">
              Secure remote ingress over Tailscale or encrypted LAN mesh for accessing the companion runtime from secondary devices.
            </p>
            <div className="p-3 rounded-xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-[11px] text-[var(--color-text-muted)]">
              Status: Remote networking is not implemented; runtime currently binds strictly to localhost.
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
