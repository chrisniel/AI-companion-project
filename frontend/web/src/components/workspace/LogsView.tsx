import React, { useState, useEffect, useMemo, useRef } from 'react';
import {
  Terminal,
  Search,
  Play,
  Pause,
  Trash2,
  RotateCcw,
  Download,
  Copy,
  Check,
  ChevronDown,
  ChevronRight,
  Filter,
  Activity,
  AlertTriangle,
  Clock,
  Code,
  Zap,
} from 'lucide-react';
import { Badge } from '../ui/Badge';
import { NeumorphicButton } from '../ui/NeumorphicButton';
import { SearchInput } from '../ui/SearchInput';
import { useTheme } from '../../context/ThemeContext';
import {
  LogSubsystem,
  LogSeverity,
  StructuredLogEntry,
} from '../../types';
import { initialMockLogs, streamingEventTemplates } from '../../mock/logsData';

const SUBSYSTEM_FILTERS: { id: LogSubsystem; label: string }[] = [
  { id: 'all', label: 'All' },
  { id: 'assistant', label: 'Assistant' },
  { id: 'models', label: 'Models' },
  { id: 'tools', label: 'Tools' },
  { id: 'audio', label: 'Audio' },
  { id: 'health', label: 'Health' },
  { id: 'devices', label: 'Devices' },
  { id: 'scheduler', label: 'Scheduler' },
  { id: 'network', label: 'Network' },
  { id: 'errors', label: 'Errors' },
];

const SEVERITY_FILTERS: LogSeverity[] = ['ALL', 'INFO', 'DEBUG', 'WARN', 'ERROR', 'TRACE'];

export const LogsView: React.FC = () => {
  const { mode } = useTheme();

  // Master logs store (persists all events)
  const [allLogs, setAllLogs] = useState<StructuredLogEntry[]>(initialMockLogs);
  
  // Clear-view flag (UI only, does not delete raw data)
  const [isViewCleared, setIsViewCleared] = useState(false);

  // Streaming state
  const [isStreaming, setIsStreaming] = useState(true);

  // Filters
  const [activeSubsystem, setActiveSubsystem] = useState<LogSubsystem>('all');
  const [activeSeverity, setActiveSeverity] = useState<LogSeverity>('ALL');
  const [searchQuery, setSearchQuery] = useState('');

  // Expanded row ID for inspection
  const [expandedLogId, setExpandedLogId] = useState<string | null>(null);

  // Copied state for feedback
  const [copiedId, setCopiedId] = useState<string | null>(null);

  // Stream simulation timer
  useEffect(() => {
    if (!isStreaming) return;

    const interval = setInterval(() => {
      // Pick random template
      const randomTemplate =
        streamingEventTemplates[Math.floor(Math.random() * streamingEventTemplates.length)];

      const now = new Date();
      const timeStr = `${now.getHours().toString().padStart(2, '0')}:${now
        .getMinutes()
        .toString()
        .padStart(2, '0')}:${now.getSeconds().toString().padStart(2, '0')}.${now
        .getMilliseconds()
        .toString()
        .padStart(3, '0')}`;

      const newEntry: StructuredLogEntry = {
        ...randomTemplate,
        id: `log-stream-${Date.now()}-${Math.random().toString(36).substring(2, 6)}`,
        timestamp: timeStr,
      };

      setAllLogs((prev) => [newEntry, ...prev.slice(0, 199)]); // Keep last 200 entries
    }, 4500);

    return () => clearInterval(interval);
  }, [isStreaming]);

  // Compute filtered logs
  const filteredLogs = useMemo(() => {
    if (isViewCleared) return [];

    return allLogs.filter((log) => {
      // Subsystem filter
      if (activeSubsystem === 'errors') {
        if (log.severity !== 'ERROR' && log.subsystem !== 'errors') return false;
      } else if (activeSubsystem !== 'all') {
        if (log.subsystem !== activeSubsystem) return false;
      }

      // Severity filter
      if (activeSeverity !== 'ALL') {
        if (log.severity !== activeSeverity) return false;
      }

      // Search query
      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase();
        const matchesEvent = log.event.toLowerCase().includes(q);
        const matchesSubsystem = log.subsystem.toLowerCase().includes(q);
        const matchesComponent = log.component?.toLowerCase().includes(q);
        const matchesDetails = log.details
          ? JSON.stringify(log.details).toLowerCase().includes(q)
          : false;
        if (!matchesEvent && !matchesSubsystem && !matchesComponent && !matchesDetails) {
          return false;
        }
      }

      return true;
    });
  }, [allLogs, isViewCleared, activeSubsystem, activeSeverity, searchQuery]);

  // Subsystem counts for badges
  const subsystemCounts = useMemo(() => {
    const counts: Record<string, number> = { all: allLogs.length, errors: 0 };
    for (const l of allLogs) {
      counts[l.subsystem] = (counts[l.subsystem] || 0) + 1;
      if (l.severity === 'ERROR' || l.subsystem === 'errors') {
        counts.errors += 1;
      }
    }
    return counts;
  }, [allLogs]);

  // Average latency
  const avgLatency = useMemo(() => {
    const latencies = allLogs.filter((l) => typeof l.latencyMs === 'number').map((l) => l.latencyMs!);
    if (!latencies.length) return 0;
    const sum = latencies.reduce((a, b) => a + b, 0);
    return Math.round(sum / latencies.length);
  }, [allLogs]);

  // Copy JSON helper
  const handleCopyPayload = (log: StructuredLogEntry) => {
    const jsonStr = JSON.stringify(log, null, 2);
    navigator.clipboard.writeText(jsonStr);
    setCopiedId(log.id);
    setTimeout(() => setCopiedId(null), 2000);
  };

  // Export JSON helper
  const handleExportLogs = () => {
    const dataStr = 'data:text/json;charset=utf-8,' + encodeURIComponent(JSON.stringify(allLogs, null, 2));
    const downloadAnchor = document.createElement('a');
    downloadAnchor.setAttribute('href', dataStr);
    downloadAnchor.setAttribute('download', `localai-telemetry-logs-${Date.now()}.json`);
    document.body.appendChild(downloadAnchor);
    downloadAnchor.click();
    downloadAnchor.remove();
  };

  // Subsystem badge style helper
  const getSubsystemBadgeClass = (sub: string) => {
    switch (sub) {
      case 'assistant':
        return 'text-sky-600 dark:text-sky-400 bg-sky-500/10 border-sky-500/20';
      case 'models':
        return 'text-indigo-600 dark:text-indigo-400 bg-indigo-500/10 border-indigo-500/20';
      case 'tools':
        return 'text-amber-600 dark:text-amber-400 bg-amber-500/10 border-amber-500/20';
      case 'audio':
        return 'text-teal-600 dark:text-teal-400 bg-teal-500/10 border-teal-500/20';
      case 'health':
        return 'text-rose-600 dark:text-rose-400 bg-rose-500/10 border-rose-500/20';
      case 'devices':
        return 'text-emerald-600 dark:text-emerald-400 bg-emerald-500/10 border-emerald-500/20';
      case 'scheduler':
        return 'text-blue-600 dark:text-blue-400 bg-blue-500/10 border-blue-500/20';
      case 'network':
        return 'text-purple-600 dark:text-purple-400 bg-purple-500/10 border-purple-500/20';
      case 'errors':
        return 'text-red-600 dark:text-red-400 bg-red-500/10 border-red-500/20';
      default:
        return 'text-slate-600 dark:text-slate-400 bg-slate-500/10 border-slate-500/20';
    }
  };

  // Severity badge style helper
  const getSeverityBadgeClass = (sev: LogSeverity) => {
    switch (sev) {
      case 'ERROR':
        return 'text-red-600 dark:text-red-400 bg-red-500/15 border-red-500/30 font-bold';
      case 'WARN':
        return 'text-amber-600 dark:text-amber-400 bg-amber-500/15 border-amber-500/30 font-semibold';
      case 'INFO':
        return 'text-sky-600 dark:text-sky-400 bg-sky-500/10 border-sky-500/20';
      case 'DEBUG':
        return 'text-purple-600 dark:text-purple-400 bg-purple-500/10 border-purple-500/20';
      case 'TRACE':
        return 'text-slate-500 dark:text-slate-400 bg-slate-500/10 border-slate-500/20';
      default:
        return 'text-slate-600 dark:text-slate-400 bg-slate-500/10';
    }
  };

  return (
    <div className="space-y-5">
      {/* 1. Header with Status & Controls */}
      <div className="p-5 sm:p-6 rounded-3xl surface-raised border border-[var(--color-border-subtle)] flex flex-col lg:flex-row lg:items-center justify-between gap-4">
        <div className="flex items-center gap-3.5">
          <div className="w-11 h-11 rounded-2xl bg-accent-gradient flex items-center justify-center text-white glow-accent-sm flex-shrink-0 shadow-sm">
            <Terminal className="w-5 h-5" />
          </div>
          <div>
            <div className="flex items-center gap-2.5">
              <h1 className="text-lg font-bold text-[var(--color-text-primary)]">
                Structured Event Viewer & Telemetry Stream
              </h1>
              {isStreaming ? (
                <div className="flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-emerald-500/10 border border-emerald-500/20 text-emerald-600 dark:text-emerald-400 text-xs font-semibold">
                  <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
                  Live Stream
                </div>
              ) : (
                <div className="flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-amber-500/10 border border-amber-500/20 text-amber-600 dark:text-amber-400 text-xs font-semibold">
                  <span className="w-2 h-2 rounded-full bg-amber-500" />
                  Paused
                </div>
              )}
            </div>
            <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">
              High-resolution event bus: assistant orchestrator, llama.cpp, tools, audio pipeline, and local airgap firewall.
            </p>
          </div>
        </div>

        {/* Quick Stats & Primary Action Buttons */}
        <div className="flex items-center flex-wrap gap-2.5">
          <div className="flex items-center gap-2 px-3 py-1.5 rounded-2xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-xs font-medium text-[var(--color-text-secondary)]">
            <span>Buffer: <strong className="text-[var(--color-text-primary)] font-mono">{allLogs.length}</strong></span>
            <span className="text-[var(--color-border-subtle)]">|</span>
            <span>Errors: <strong className="text-red-500 font-mono">{subsystemCounts.errors || 0}</strong></span>
            <span className="text-[var(--color-border-subtle)]">|</span>
            <span>Avg Latency: <strong className="text-[var(--color-accent)] font-mono">{avgLatency}ms</strong></span>
          </div>

          {/* Pause / Resume Button */}
          <NeumorphicButton
            variant="ghost"
            size="sm"
            onClick={() => setIsStreaming(!isStreaming)}
            icon={isStreaming ? <Pause className="w-3.5 h-3.5 text-amber-500" /> : <Play className="w-3.5 h-3.5 text-emerald-500" />}
          >
            {isStreaming ? 'Pause Stream' : 'Resume Stream'}
          </NeumorphicButton>

          {/* Clear View / Restore View Button */}
          {isViewCleared ? (
            <NeumorphicButton
              variant="primary"
              size="sm"
              onClick={() => setIsViewCleared(false)}
              icon={<RotateCcw className="w-3.5 h-3.5 text-white" />}
            >
              Restore View
            </NeumorphicButton>
          ) : (
            <NeumorphicButton
              variant="ghost"
              size="sm"
              onClick={() => setIsViewCleared(true)}
              icon={<Trash2 className="w-3.5 h-3.5 text-rose-500" />}
            >
              Clear View
            </NeumorphicButton>
          )}

          {/* Export JSON */}
          <NeumorphicButton
            variant="ghost"
            size="sm"
            onClick={handleExportLogs}
            icon={<Download className="w-3.5 h-3.5 text-[var(--color-text-secondary)]" />}
          >
            Export JSON
          </NeumorphicButton>
        </div>
      </div>

      {/* View Cleared Notice Banner */}
      {isViewCleared && (
        <div className="p-3.5 rounded-2xl bg-amber-500/10 border border-amber-500/20 text-amber-800 dark:text-amber-200 flex items-center justify-between gap-3 text-xs">
          <div className="flex items-center gap-2">
            <AlertTriangle className="w-4 h-4 text-amber-500 flex-shrink-0" />
            <span>
              The viewer screen is currently cleared for focused debugging. No log entries have been deleted from the buffer.
            </span>
          </div>
          <button
            type="button"
            onClick={() => setIsViewCleared(false)}
            className="px-2.5 py-1 rounded-xl bg-amber-500 text-white font-semibold text-xs hover:bg-amber-600 transition-colors flex-shrink-0"
          >
            Restore All ({allLogs.length})
          </button>
        </div>
      )}

      {/* 2. Filter Bar: Subsystems & Severities & Search */}
      <div className="p-4 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-3.5">
        {/* Subsystem Pills */}
        <div className="flex items-center gap-1.5 overflow-x-auto pb-1 scrollbar-none">
          <span className="text-[11px] font-bold uppercase tracking-wider text-[var(--color-text-muted)] mr-1 flex-shrink-0 font-mono">
            Subsystem:
          </span>
          {SUBSYSTEM_FILTERS.map((item) => {
            const count = subsystemCounts[item.id] || 0;
            const isSelected = activeSubsystem === item.id;
            return (
              <button
                key={item.id}
                type="button"
                onClick={() => {
                  setActiveSubsystem(item.id);
                  if (isViewCleared) setIsViewCleared(false);
                }}
                className={`px-3 py-1.5 rounded-xl text-xs font-medium transition-all flex items-center gap-1.5 flex-shrink-0 whitespace-nowrap ${
                  isSelected
                    ? 'bg-accent-gradient text-white shadow-sm font-semibold'
                    : 'bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)] hover:border-[var(--color-accent)]/30'
                }`}
              >
                <span>{item.label}</span>
                <span
                  className={`text-[10px] px-1.5 py-0.2 rounded-full font-mono ${
                    isSelected
                      ? 'bg-white/20 text-white'
                      : 'bg-[var(--color-surface-secondary)] text-[var(--color-text-muted)]'
                  }`}
                >
                  {count}
                </span>
              </button>
            );
          })}
        </div>

        {/* Search & Severity Filter Bar */}
        <div className="flex flex-col sm:flex-row gap-3 items-stretch sm:items-center justify-between pt-2 border-t border-[var(--color-border-subtle)]">
          {/* Search Box */}
          <div className="w-full sm:w-80">
            <SearchInput
              value={searchQuery}
              onChangeValue={(val) => {
                setSearchQuery(val);
                if (isViewCleared) setIsViewCleared(false);
              }}
              placeholder="Search event message, component, or JSON..."
              sizeVariant="sm"
            />
          </div>

          {/* Severity Segmented Filter */}
          <div className="flex items-center gap-2 self-end sm:self-auto">
            <span className="text-[11px] font-bold uppercase tracking-wider text-[var(--color-text-muted)] font-mono">
              Severity:
            </span>
            <div className="flex items-center gap-1 bg-[var(--color-surface-elevated)] p-1 rounded-2xl border border-[var(--color-border-subtle)]">
              {SEVERITY_FILTERS.map((sev) => {
                const isSelected = activeSeverity === sev;
                return (
                  <button
                    key={sev}
                    type="button"
                    onClick={() => {
                      setActiveSeverity(sev);
                      if (isViewCleared) setIsViewCleared(false);
                    }}
                    className={`px-2.5 py-1 rounded-xl text-xs font-mono font-medium transition-all ${
                      isSelected
                        ? 'bg-accent-gradient text-white shadow-xs font-bold'
                        : 'text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)]'
                    }`}
                  >
                    {sev}
                  </button>
                );
              })}
            </div>
          </div>
        </div>
      </div>

      {/* 3. Structured Event Viewer (Compact Rows, Not Giant Cards) */}
      <div className="rounded-3xl surface-raised border border-[var(--color-border-subtle)] overflow-hidden shadow-xs">
        {/* Table Column Headers */}
        <div className="grid grid-cols-12 items-center px-4 py-3 bg-[var(--color-surface-secondary)]/50 border-b border-[var(--color-border-subtle)] text-[11px] font-mono uppercase tracking-wider text-[var(--color-text-muted)] font-semibold select-none">
          <div className="col-span-2 sm:col-span-2">Timestamp</div>
          <div className="col-span-2 sm:col-span-1 text-center sm:text-left">Severity</div>
          <div className="col-span-3 sm:col-span-2">Subsystem</div>
          <div className="col-span-5 sm:col-span-5">Event & Component</div>
          <div className="hidden sm:block sm:col-span-1 text-right">Latency</div>
          <div className="hidden sm:block sm:col-span-1 text-right">Action</div>
        </div>

        {/* Rows List */}
        <div className="divide-y divide-[var(--color-border-subtle)] max-h-[620px] overflow-y-auto font-mono text-xs">
          {filteredLogs.length === 0 ? (
            <div className="py-16 px-6 text-center space-y-3">
              <div className="w-12 h-12 rounded-2xl bg-[var(--color-surface-secondary)] mx-auto flex items-center justify-center text-[var(--color-text-muted)]">
                <Filter className="w-6 h-6" />
              </div>
              <h3 className="text-sm font-semibold text-[var(--color-text-primary)]">
                {isViewCleared ? 'View is currently cleared' : 'No matching log entries found'}
              </h3>
              <p className="text-xs text-[var(--color-text-secondary)] max-w-sm mx-auto">
                {isViewCleared
                  ? 'Click "Restore View" to bring back all retained events.'
                  : 'Try adjusting your search criteria, subsystem filter, or severity selector.'}
              </p>
              {isViewCleared && (
                <div className="pt-2">
                  <NeumorphicButton
                    variant="primary"
                    size="sm"
                    onClick={() => setIsViewCleared(false)}
                  >
                    Restore View ({allLogs.length})
                  </NeumorphicButton>
                </div>
              )}
            </div>
          ) : (
            filteredLogs.map((log) => {
              const isExpanded = expandedLogId === log.id;
              const hasLatency = typeof log.latencyMs === 'number';

              return (
                <div
                  key={log.id}
                  className={`transition-colors ${
                    isExpanded
                      ? 'bg-[var(--color-surface-secondary)]/60'
                      : 'hover:bg-[var(--color-surface-secondary)]/30'
                  }`}
                >
                  {/* Compact Row */}
                  <div
                    onClick={() => setExpandedLogId(isExpanded ? null : log.id)}
                    className="grid grid-cols-12 items-center px-4 py-2.5 cursor-pointer select-none gap-2 leading-tight"
                  >
                    {/* Timestamp */}
                    <div className="col-span-2 sm:col-span-2 text-[var(--color-text-muted)] text-[11px] truncate flex items-center gap-1.5">
                      <span className="text-[var(--color-text-primary)] font-mono font-medium">
                        {log.timestamp}
                      </span>
                    </div>

                    {/* Severity Badge */}
                    <div className="col-span-2 sm:col-span-1">
                      <span
                        className={`inline-block px-1.5 py-0.5 rounded text-[10px] font-bold border tracking-wider uppercase ${getSeverityBadgeClass(
                          log.severity
                        )}`}
                      >
                        {log.severity}
                      </span>
                    </div>

                    {/* Subsystem Badge */}
                    <div className="col-span-3 sm:col-span-2">
                      <span
                        className={`inline-block px-2 py-0.5 rounded-lg text-[11px] font-medium border truncate max-w-full ${getSubsystemBadgeClass(
                          log.subsystem
                        )}`}
                      >
                        {log.subsystem}
                      </span>
                    </div>

                    {/* Event & Component */}
                    <div className="col-span-5 sm:col-span-5 flex items-center gap-2 overflow-hidden">
                      {log.component && (
                        <span className="text-[10px] px-1.5 py-0.2 rounded bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-[var(--color-text-muted)] flex-shrink-0">
                          {log.component}
                        </span>
                      )}
                      <span className="text-[var(--color-text-primary)] truncate font-sans text-xs">
                        {log.event}
                      </span>
                    </div>

                    {/* Latency if applicable */}
                    <div className="hidden sm:block sm:col-span-1 text-right">
                      {hasLatency ? (
                        <span
                          className={`text-[11px] px-1.5 py-0.5 rounded font-mono ${
                            log.latencyMs! > 200
                              ? 'text-amber-500 bg-amber-500/10'
                              : 'text-[var(--color-text-muted)]'
                          }`}
                        >
                          {log.latencyMs}ms
                        </span>
                      ) : (
                        <span className="text-[var(--color-text-muted)]/50 text-[10px]">—</span>
                      )}
                    </div>

                    {/* Expand / Inspect Action */}
                    <div className="hidden sm:flex sm:col-span-1 justify-end items-center text-[var(--color-text-muted)]">
                      <div className="p-1 rounded-lg hover:bg-[var(--color-surface-elevated)] transition-colors">
                        {isExpanded ? (
                          <ChevronDown className="w-3.5 h-3.5 text-[var(--color-accent)]" />
                        ) : (
                          <ChevronRight className="w-3.5 h-3.5" />
                        )}
                      </div>
                    </div>
                  </div>

                  {/* Expandable Inspection Drawer */}
                  {isExpanded && (
                    <div className="px-5 pb-4 pt-1 bg-[var(--color-surface-elevated)]/70 border-t border-[var(--color-border-subtle)] space-y-3 font-mono text-xs">
                      <div className="flex flex-wrap items-center justify-between gap-3 pt-2">
                        <div className="flex items-center gap-3">
                          <span className="text-[11px] text-[var(--color-text-muted)]">
                            Event ID: <strong className="text-[var(--color-text-primary)]">{log.id}</strong>
                          </span>
                          {log.component && (
                            <span className="text-[11px] text-[var(--color-text-muted)]">
                              Module: <strong className="text-[var(--color-accent)]">{log.component}</strong>
                            </span>
                          )}
                          {hasLatency && (
                            <span className="text-[11px] text-[var(--color-text-muted)]">
                              Duration: <strong className="text-[var(--color-text-primary)]">{log.latencyMs}ms</strong>
                            </span>
                          )}
                        </div>

                        {/* Copy JSON payload */}
                        <button
                          type="button"
                          onClick={() => handleCopyPayload(log)}
                          className="px-2.5 py-1 rounded-xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] hover:border-[var(--color-accent)]/40 text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)] text-[11px] flex items-center gap-1.5 transition-all shadow-xs"
                        >
                          {copiedId === log.id ? (
                            <>
                              <Check className="w-3 h-3 text-emerald-500" />
                              <span className="text-emerald-500 font-semibold">Copied JSON</span>
                            </>
                          ) : (
                            <>
                              <Copy className="w-3 h-3" />
                              <span>Copy JSON</span>
                            </>
                          )}
                        </button>
                      </div>

                      {/* Full event description */}
                      <div className="p-3 rounded-2xl bg-[var(--color-surface-recessed)]/80 border border-[var(--color-border-subtle)] font-sans text-xs text-[var(--color-text-primary)] leading-relaxed">
                        <span className="font-semibold font-mono text-[var(--color-accent)] mr-2">
                          [{log.severity}]
                        </span>
                        {log.event}
                      </div>

                      {/* Stack Trace if available */}
                      {log.stackTrace && (
                        <div className="p-3 rounded-2xl bg-red-500/10 border border-red-500/20 text-red-700 dark:text-red-300 space-y-1">
                          <div className="font-bold text-[11px] flex items-center gap-1.5">
                            <AlertTriangle className="w-3.5 h-3.5" />
                            Stack Trace / Policy Rejection:
                          </div>
                          <pre className="text-[11px] whitespace-pre-wrap break-all leading-tight font-mono">
                            {log.stackTrace}
                          </pre>
                        </div>
                      )}

                      {/* Structured Details JSON */}
                      {log.details && (
                        <div className="space-y-1">
                          <span className="text-[11px] text-[var(--color-text-muted)] font-semibold flex items-center gap-1">
                            <Code className="w-3 h-3" />
                            Structured Metadata Payload:
                          </span>
                          <pre className="p-3 rounded-2xl bg-[var(--color-surface-recessed)] border border-[var(--color-border-subtle)] text-[11px] text-[var(--color-text-primary)] overflow-x-auto leading-relaxed">
                            {JSON.stringify(log.details, null, 2)}
                          </pre>
                        </div>
                      )}
                    </div>
                  )}
                </div>
              );
            })
          )}
        </div>

        {/* Footer Summary */}
        <div className="px-4 py-2.5 bg-[var(--color-surface-secondary)]/40 border-t border-[var(--color-border-subtle)] flex items-center justify-between text-[11px] font-mono text-[var(--color-text-muted)]">
          <span>
            Showing <strong className="text-[var(--color-text-primary)]">{filteredLogs.length}</strong> of{' '}
            <strong className="text-[var(--color-text-primary)]">{allLogs.length}</strong> events
          </span>
          <span className="text-[10px]">
            {isStreaming ? '• Stream Polling Active (4.5s)' : 'Stream Paused'}
          </span>
        </div>
      </div>
    </div>
  );
};
