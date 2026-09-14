import React, { useMemo } from 'react';
import {
  Sparkles,
  Bot,
  Activity,
  CheckSquare,
  Cpu,
  Zap,
  ArrowRight,
  ShieldCheck,
  Clock,
  AlarmClock,
  Bell,
  ChevronRight,
  Heart,
  Footprints,
  MoonStar,
  Terminal,
  Layers,
  Calendar,
} from 'lucide-react';
import { useBackend } from '../../context/BackendContext';
import { Badge } from '../ui/Badge';
import { StatusIndicator } from '../ui/StatusIndicator';
import { NeumorphicButton } from '../ui/NeumorphicButton';

export interface HomeViewProps {
  onNavigate: (sectionId: string) => void;
  activeCharacterName?: string;
  userName?: string;
}

export const HomeView: React.FC<HomeViewProps> = ({
  onNavigate,
  activeCharacterName = 'Assistant',
  userName = 'Local User',
}) => {
  const { isOnline, modelStatus, registry } = useBackend();

  // 1. Time-Derived Greeting
  const greeting = useMemo(() => {
    const h = new Date().getHours();
    return h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening';
  }, []);

  const currentDateString = useMemo(() => {
    return new Date().toLocaleDateString('en-US', {
      weekday: 'long',
      month: 'short',
      day: 'numeric',
    });
  }, []);

  // Authoritative runtime model identity
  const backendActiveModelId = (isOnline && modelStatus?.model_loaded && modelStatus?.active_model)
    ? modelStatus.active_model
    : null;
  const activeModelEntry = backendActiveModelId
    ? registry.find((m) => m.id === backendActiveModelId)
    : null;
  const activeDisplayName = activeModelEntry?.display_name || backendActiveModelId;

  const runtimeState = isOnline ? (modelStatus?.runtime_state || 'Unknown') : 'Offline';
  const appliedLayers = isOnline && modelStatus?.applied_gpu_layers != null
    ? `${modelStatus.applied_gpu_layers} GPU layers [Applied]`
    : 'GPU layers: Unavailable';

  const appliedProfile = (isOnline && modelStatus?.router_running) ? (modelStatus?.applied_profile ?? null) : null;
  const requestedProfile = isOnline ? (modelStatus?.requested_profile ?? null) : null;
  const profileDisplay = appliedProfile
    ? `${appliedProfile} [Applied]`
    : requestedProfile
    ? `${requestedProfile} [Requested]`
    : 'Unavailable';

  return (
    <div className="space-y-6">
      {/* ========================================================= */}
      {/* 1. HEADER: Contextual Backend-Truthful Greeting            */}
      {/* ========================================================= */}
      <div className="p-6 sm:p-7 rounded-3xl glass-panel-elevated border border-[var(--color-surface-glass-border)] relative overflow-hidden">
        <div className="relative z-10 flex flex-col md:flex-row md:items-center justify-between gap-5">
          <div className="space-y-2 max-w-xl">
            <div className="flex flex-wrap items-center gap-2">
              <Badge variant={isOnline ? 'accent' : 'glass'} size="sm">
                {isOnline ? 'Local AI Core Online' : 'Local AI Core Offline'}
              </Badge>
              <span className="text-xs text-[var(--color-text-secondary)] font-mono">
                {currentDateString}
              </span>
            </div>

            <h1 className="text-2xl sm:text-3xl font-bold tracking-tight text-[var(--color-text-primary)] flex items-center gap-2">
              <span>{greeting}, {userName}</span>
            </h1>
            <p className="text-sm text-[var(--color-text-secondary)] leading-relaxed">
              {!isOnline ? (
                <span>
                  <strong className="text-[var(--color-text-primary)]">{activeCharacterName}</strong> is standing by. Local AI Core runtime is currently offline.
                </span>
              ) : !backendActiveModelId ? (
                <span>
                  <strong className="text-[var(--color-text-primary)]">{activeCharacterName}</strong> is connected. No model is currently loaded in Local AI Core.
                </span>
              ) : (
                <span>
                  <strong className="text-[var(--color-text-primary)]">{activeCharacterName}</strong> is active with model <strong className="text-[var(--color-text-primary)]">{activeDisplayName}</strong>.
                </span>
              )}
            </p>
          </div>

          <div className="flex items-center gap-2.5 flex-shrink-0">
            <div className="p-3 rounded-2xl surface-raised border border-[var(--color-border-subtle)] flex items-center gap-3">
              <div className="w-9 h-9 rounded-xl bg-accent-gradient flex items-center justify-center text-white glow-accent-sm flex-shrink-0">
                <Bot className="w-5 h-5" />
              </div>
              <div>
                <div className="flex items-center gap-1.5">
                  <span className="text-xs font-bold text-[var(--color-text-primary)]">
                    {activeCharacterName}
                  </span>
                  <StatusIndicator
                    status={isOnline ? (backendActiveModelId ? 'assistant' : 'online') : 'offline'}
                    size="sm"
                    showLabel={false}
                  />
                </div>
                <span className="text-[11px] text-[var(--color-text-secondary)] font-mono">
                  Runtime: {runtimeState}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* ========================================================= */}
      {/* 2. PRIMARY DASHBOARD: Four Main Summary Areas             */}
      {/* (NEXT, AI STATUS, TODAY, WELLNESS)                         */}
      {/* ========================================================= */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* AREA 1: NEXT UP */}
        <div className="p-6 rounded-3xl surface-raised border border-[var(--color-border-subtle)] flex flex-col justify-between space-y-4 hover:border-[var(--color-accent)]/30 transition-all">
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <h2 className="text-xl sm:text-2xl font-extrabold uppercase tracking-wider font-mono text-[var(--color-accent)] select-none">
                Next Up
              </h2>
              <Badge variant="glass" size="sm">
                Planned
              </Badge>
            </div>

            <div className="p-4 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] space-y-2">
              <div className="flex items-start justify-between gap-2">
                <div>
                  <span className="text-xs font-semibold text-[var(--color-accent)] uppercase tracking-wider font-mono">
                    Task Pipeline
                  </span>
                  <h3 className="text-base font-bold text-[var(--color-text-primary)] mt-0.5">
                    No live task data available
                  </h3>
                </div>
              </div>
              <p className="text-xs text-[var(--color-text-secondary)] leading-relaxed">
                Task and schedule synchronization will be integrated with the backend Tasks API in Phase 8A.3b.2.
              </p>
            </div>
          </div>

          <div className="flex items-center justify-between pt-1">
            <span className="text-xs text-[var(--color-text-muted)] font-mono">
              Schedule integration: Planned
            </span>
            <div className="flex items-center gap-2">
              <NeumorphicButton
                size="sm"
                variant="primary"
                icon={<CheckSquare className="w-3.5 h-3.5 text-white" />}
                onClick={() => onNavigate('tasks')}
              >
                Open Tasks
              </NeumorphicButton>
            </div>
          </div>
        </div>

        {/* AREA 2: AI STATUS */}
        <div className="p-6 rounded-3xl surface-raised border border-[var(--color-border-subtle)] flex flex-col justify-between space-y-4 hover:border-[var(--color-accent)]/30 transition-all">
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <h2 className="text-xl sm:text-2xl font-extrabold uppercase tracking-wider font-mono text-[var(--color-accent)] select-none">
                AI Status
              </h2>
              <div className="flex items-center gap-1.5">
                <StatusIndicator status={isOnline ? 'online' : 'offline'} size="sm" showLabel={false} />
                <span className={`text-xs font-semibold font-mono ${isOnline ? 'text-emerald-500' : 'text-rose-400'}`}>
                  {isOnline ? 'Online (:8000)' : 'Offline'}
                </span>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-2.5 text-xs font-mono">
              <div className="p-3 rounded-2xl surface-recessed border border-[var(--color-border-subtle)]">
                <span className="text-[10px] text-[var(--color-text-muted)] uppercase block">
                  Core Status
                </span>
                <span className="font-bold text-[var(--color-text-primary)] mt-0.5 block">
                  {isOnline ? 'Online (Port 8000)' : 'Offline'}
                </span>
                <span className={`text-[10px] ${isOnline ? 'text-emerald-500' : 'text-[var(--color-text-muted)]'}`}>
                  {isOnline ? 'Connected to local runtime' : 'Unavailable'}
                </span>
              </div>

              <div className="p-3 rounded-2xl surface-recessed border border-[var(--color-border-subtle)]">
                <span className="text-[10px] text-[var(--color-text-muted)] uppercase block">
                  Active Local Model
                </span>
                <span className="font-bold text-[var(--color-text-primary)] mt-0.5 block truncate">
                  {activeDisplayName || (isOnline ? 'No Model Loaded' : 'Unavailable')}
                </span>
                <span className="text-[10px] text-[var(--color-accent)]">
                  {modelStatus?.model_resident
                    ? 'Resident in VRAM'
                    : isOnline
                    ? 'Not resident'
                    : 'Unavailable'}
                </span>
              </div>

              <div className="p-3 rounded-2xl surface-recessed border border-[var(--color-border-subtle)]">
                <span className="text-[10px] text-[var(--color-text-muted)] uppercase block">
                  Runtime / Provider
                </span>
                <span className="font-bold text-[var(--color-text-primary)] mt-0.5 block truncate">
                  {isOnline && modelStatus?.provider?.trim() ? modelStatus.provider : 'Unavailable'}
                </span>
                <span className="text-[10px] text-[var(--color-text-secondary)] truncate block">
                  {appliedLayers}
                </span>
              </div>

              <div className="p-3 rounded-2xl surface-recessed border border-[var(--color-border-subtle)]">
                <span className="text-[10px] text-[var(--color-text-muted)] uppercase block">
                  Execution Mode
                </span>
                <span className="font-bold text-[var(--color-text-primary)] mt-0.5 block flex items-center gap-1 text-emerald-500">
                  {isOnline ? (
                    <>
                      <ShieldCheck className="w-3.5 h-3.5" />
                      <span>Core Runtime (:8000)</span>
                    </>
                  ) : (
                    <span className="text-[var(--color-text-muted)]">Offline</span>
                  )}
                </span>
                <span className="text-[10px] text-[var(--color-text-secondary)]">
                  {isOnline ? 'Operating on port 8000' : 'Core offline'}
                </span>
              </div>
            </div>
          </div>

          <div className="flex items-center justify-between pt-1 border-t border-[var(--color-border-subtle)] text-xs">
            <span className="text-[var(--color-text-secondary)] font-mono">
              Profile: <strong className="text-[var(--color-text-primary)]">{profileDisplay}</strong> (Temperature: Unavailable • Token speed: Unavailable)
            </span>
            <button
              type="button"
              onClick={() => onNavigate('models')}
              className="text-xs font-semibold text-[var(--color-accent)] hover:underline flex items-center gap-1 font-mono cursor-pointer"
            >
              Model Hub <ChevronRight className="w-3 h-3" />
            </button>
          </div>
        </div>

        {/* AREA 3: TODAY */}
        <div className="p-6 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4 hover:border-[var(--color-accent)]/30 transition-all">
          <div className="flex items-center justify-between">
            <h2 className="text-xl sm:text-2xl font-extrabold uppercase tracking-wider font-mono text-[var(--color-accent)] select-none">
              Today
            </h2>
            <Badge variant="glass" size="sm">
              Planned
            </Badge>
          </div>

          <div className="p-4 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] space-y-3">
            <div className="flex items-center gap-2 text-xs text-[var(--color-accent)] font-semibold font-mono">
              <Calendar className="w-4 h-4" />
              <span>Daily Agenda</span>
            </div>
            <p className="text-xs text-[var(--color-text-secondary)] leading-relaxed">
              No live task data available. Workstation tasks and scheduling will connect to the backend Tasks API in Phase 8A.3b.2.
            </p>
          </div>

          <div className="flex items-center justify-between pt-1">
            <span className="text-xs text-[var(--color-text-muted)] font-mono">
              Tasks & Reminders: Planned
            </span>
            <div className="flex items-center gap-2">
              <NeumorphicButton
                size="sm"
                icon={<Clock className="w-3.5 h-3.5 text-[var(--color-accent)]" />}
                onClick={() => onNavigate('schedule')}
              >
                Schedule
              </NeumorphicButton>
              <NeumorphicButton
                size="sm"
                variant="primary"
                icon={<CheckSquare className="w-3.5 h-3.5 text-white" />}
                onClick={() => onNavigate('tasks')}
              >
                Tasks
              </NeumorphicButton>
            </div>
          </div>
        </div>

        {/* AREA 4: WELLNESS */}
        <div className="p-6 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4 hover:border-[var(--color-accent)]/30 transition-all">
          <div className="flex items-center justify-between">
            <h2 className="text-xl sm:text-2xl font-extrabold uppercase tracking-wider font-mono text-[var(--color-accent)] select-none">
              Wellness
            </h2>
            <Badge variant="glass" size="sm">
              Planned
            </Badge>
          </div>

          <div className="p-4 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] space-y-3">
            <div className="flex items-center gap-2 text-xs text-rose-400 font-semibold font-mono">
              <Heart className="w-4 h-4" />
              <span>Biometric Telemetry</span>
            </div>
            <p className="text-xs text-[var(--color-text-secondary)] leading-relaxed">
              Wearable synchronization not configured. Native health and wearable telemetry integrations (Health Connect, BLE) are planned.
            </p>
          </div>

          <div className="p-3 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] flex items-center justify-between text-xs text-[var(--color-text-secondary)]">
            <span className="font-mono text-[11px] text-[var(--color-text-muted)]">
              Wearable status: Not configured
            </span>
            <button
              type="button"
              onClick={() => onNavigate('health')}
              className="text-xs font-semibold text-[var(--color-accent)] hover:underline flex items-center gap-1 font-mono flex-shrink-0 cursor-pointer"
            >
              Health Workspace <ChevronRight className="w-3 h-3" />
            </button>
          </div>
        </div>
      </div>

      {/* ========================================================= */}
      {/* 3. QUICK ACTIONS: Tactile Navigation Actions              */}
      {/* ========================================================= */}
      <div className="p-5 sm:p-6 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-3">
        <div className="flex items-center justify-between">
          <span className="text-xs font-bold text-[var(--color-text-primary)] uppercase tracking-wider font-mono">
            Workstation Quick Navigation
          </span>
          <span className="text-[11px] text-[var(--color-text-muted)] font-mono">
            Direct workspace access
          </span>
        </div>

        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
          <NeumorphicButton
            variant="primary"
            size="md"
            icon={<Bot className="w-4 h-4 text-white" />}
            onClick={() => onNavigate('assistant')}
            className="w-full justify-center"
          >
            Ask Assistant
          </NeumorphicButton>

          <NeumorphicButton
            size="md"
            icon={<CheckSquare className="w-4 h-4 text-[var(--color-accent)]" />}
            onClick={() => onNavigate('tasks')}
            className="w-full justify-center"
          >
            Tasks Workspace
          </NeumorphicButton>

          <NeumorphicButton
            size="md"
            icon={<Clock className="w-4 h-4 text-amber-500" />}
            onClick={() => onNavigate('schedule')}
            className="w-full justify-center"
          >
            Schedule
          </NeumorphicButton>

          <NeumorphicButton
            size="md"
            icon={<Cpu className="w-4 h-4 text-purple-400" />}
            onClick={() => onNavigate('models')}
            className="w-full justify-center"
          >
            Model Hub
          </NeumorphicButton>
        </div>
      </div>

      {/* ========================================================= */}
      {/* 4. RECENT ACTIVITY: Truthful Audit Trail State            */}
      {/* ========================================================= */}
      <div className="p-6 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <h2 className="text-sm font-bold text-[var(--color-text-primary)] uppercase tracking-wider font-mono">
              Recent Activity Feed
            </h2>
          </div>
          <button
            type="button"
            onClick={() => onNavigate('logs')}
            className="text-xs font-mono text-[var(--color-accent)] hover:underline flex items-center gap-1 cursor-pointer"
          >
            View System Logs <ChevronRight className="w-3 h-3" />
          </button>
        </div>

        <div className="p-4 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] flex items-center justify-between text-xs text-[var(--color-text-secondary)]">
          <span>No recent activity logged. Local runtime audit events and session traces will appear here.</span>
          <Badge variant="glass" size="sm">
            Audit
          </Badge>
        </div>
      </div>
    </div>
  );
};
