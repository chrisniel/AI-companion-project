import React from 'react';
import {
  Terminal,
  Info,
  Clock,
  Code,
  Shield,
  Layers,
  Cpu,
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
              Centralized diagnostic log streaming and telemetry viewer for runtime engines, tools, and background tasks.
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2 self-start md:self-auto">
          <div className="px-3 py-1.5 rounded-xl surface-recessed border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-muted)] flex items-center gap-2">
            <Info className="w-3.5 h-3.5 text-[var(--color-accent)] flex-shrink-0" />
            <span>Backend telemetry WebSocket / SSE endpoint not implemented yet</span>
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
              Channel: /api/v1/logs/stream (Planned)
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
              No authoritative log stream is connected. Live system events, model inference token velocities, and tool execution traces will stream here once backend telemetry is established.
            </p>
          </div>

          <div className="p-4 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] max-w-lg w-full text-left space-y-2 text-[11px] text-[var(--color-text-muted)]">
            <div className="text-[var(--color-text-primary)] font-semibold font-sans">
              Planned Stream Channels:
            </div>
            <ul className="list-disc pl-4 space-y-1">
              <li>
                <span className="text-[var(--color-accent)]">engine</span>: llama.cpp token velocity, GPU offload layers, KV cache usage
              </li>
              <li>
                <span className="text-[var(--color-accent)]">assistant</span>: Conversation turn generation, tool dispatch, grounding checks
              </li>
              <li>
                <span className="text-[var(--color-accent)]">system</span>: Database transactions, background routines, memory indexing
              </li>
            </ul>
          </div>
        </div>
      </div>

      {/* 3. Observability Architecture Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-5">
        <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-2">
          <div className="flex items-center gap-2 text-xs font-semibold text-[var(--color-text-primary)]">
            <Cpu className="w-4 h-4 text-[var(--color-accent)]" />
            <span>Airgapped Local Logs</span>
          </div>
          <p className="text-xs text-[var(--color-text-secondary)] leading-relaxed">
            All future log records remain strictly on-device in SQLite or flat rotating JSON logs. Zero cloud telemetry.
          </p>
        </div>

        <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-2">
          <div className="flex items-center gap-2 text-xs font-semibold text-[var(--color-text-primary)]">
            <Code className="w-4 h-4 text-[var(--color-accent)]" />
            <span>Structured JSON Schema</span>
          </div>
          <p className="text-xs text-[var(--color-text-secondary)] leading-relaxed">
            Standardized payload format: timestamp, subsystem, severity, message, execution latency, and context metadata.
          </p>
        </div>

        <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-2">
          <div className="flex items-center gap-2 text-xs font-semibold text-[var(--color-text-primary)]">
            <Shield className="w-4 h-4 text-emerald-500" />
            <span>Privacy redaction</span>
          </div>
          <p className="text-xs text-[var(--color-text-secondary)] leading-relaxed">
            Automated PII scrubbing for conversation content and memory keys prior to stream serialization.
          </p>
        </div>
      </div>
    </div>
  );
};
