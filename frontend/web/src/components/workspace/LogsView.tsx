import React from 'react';
import {
  Terminal,
  Info,
} from 'lucide-react';
import { Badge } from '../ui/Badge';

export const LogsView: React.FC = () => {
  return (
    <div id="logs-view" className="space-y-8 pb-12">
      {/* 1. Header Banner */}
      <div className="p-5 sm:p-6 rounded-3xl surface-raised border border-[var(--color-border-subtle)] flex flex-col md:flex-row md:items-center justify-between gap-4 shadow-sm">
        <div className="flex items-center gap-3.5">
          <div className="w-11 h-11 rounded-2xl bg-accent-gradient flex items-center justify-center text-white glow-accent-sm flex-shrink-0">
            <Terminal className="w-5 h-5" />
          </div>
          <div>
            <div className="flex items-center gap-2 flex-wrap">
              <h1 className="text-xl font-bold text-[var(--color-text-primary)]">
                System & Diagnostic Logs
              </h1>
              <Badge variant="neutral" size="sm">
                Preview / Planned
              </Badge>
              <Badge variant="warning" size="sm">
                Stream Disconnected
              </Badge>
            </div>
            <p className="text-xs text-[var(--color-text-secondary)] mt-0.5 max-w-2xl">
              Centralized diagnostic log streaming and telemetry viewer for the companion runtime.
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2 self-start md:self-auto">
          <div className="px-3 py-1.5 rounded-xl surface-recessed border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-muted)] flex items-center gap-2">
            <Info className="w-3.5 h-3.5 text-[var(--color-accent)] flex-shrink-0" />
            <span>This screen is a Preview / Planned viewer surface</span>
          </div>
        </div>
      </div>

      {/* 2. Primary Log Terminal Shell (Truthful Preview) */}
      <div className="rounded-3xl surface-raised border border-[var(--color-border-subtle)] overflow-hidden shadow-sm flex flex-col">
        {/* Terminal Title Bar */}
        <div className="px-5 py-3.5 bg-[var(--color-surface-sunken)] border-b border-[var(--color-border-subtle)] flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="flex items-center gap-1.5 mr-2">
              <div className="w-3 h-3 rounded-full bg-rose-500/80" />
              <div className="w-3 h-3 rounded-full bg-amber-500/80" />
              <div className="w-3 h-3 rounded-full bg-emerald-500/80" />
            </div>
            <span className="text-xs font-mono font-semibold text-[var(--color-text-primary)]">
              runtime-telemetry.log
            </span>
          </div>

          <div className="flex items-center gap-2">
            <span className="text-[11px] font-mono text-[var(--color-text-muted)]">
              Status: Disconnected
            </span>
          </div>
        </div>

        {/* Terminal Body with Truthful Notice */}
        <div className="p-8 sm:p-12 font-mono text-xs flex flex-col items-center justify-center text-center space-y-4 min-h-[360px] bg-black/40 dark:bg-black/60">
          <div className="w-12 h-12 rounded-2xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] flex items-center justify-center text-[var(--color-text-muted)]">
            <Terminal className="w-6 h-6 text-[var(--color-accent)]" />
          </div>

          <div className="space-y-1.5 max-w-md">
            <h2 className="text-sm font-bold text-[var(--color-text-primary)]">
              Runtime log streaming is not implemented yet.
            </h2>
            <p className="text-xs text-[var(--color-text-secondary)] leading-relaxed font-sans">
              No authoritative log stream is connected. Runtime telemetry/logging may appear here in a future implementation.
            </p>
          </div>

          <div className="p-4 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] max-w-lg w-full text-center text-[11px] text-[var(--color-text-muted)]">
            <p className="font-sans">
              This screen is a Preview / Planned viewer surface. The companion runtime currently provides no live telemetry streaming endpoints.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};
