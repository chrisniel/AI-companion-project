import React, { useState } from 'react';
import {
  Sun,
  Moon,
  Cpu,
  PanelLeftClose,
  Zap,
  Gauge,
  Leaf,
  ChevronDown,
  PowerOff,
} from 'lucide-react';
import { useTheme } from '../../context/ThemeContext';
import { useBackend } from '../../context/BackendContext';
import {
  AssistantPanelMode,
  PerformanceProfile,
} from '../../types';
import { Dropdown, DropdownItem } from '../ui/Dropdown';
import {
  getRegistryEntryId,
  getRegistryEntryDisplayName,
  registryEntryMatchesIdentifier,
} from '../../services/api';

export interface HeaderProps {
  searchQuery?: string;
  onSearchChange?: (query: string) => void;
  sidebarCollapsed: boolean;
  onToggleSidebarCollapse: () => void;
  assistantPanelMode?: AssistantPanelMode;
  onCycleAssistantPanelMode?: () => void;
  currentModelId?: string;
  onSelectModel?: (modelId: string) => void;
  performanceProfile?: PerformanceProfile;
  onChangePerformanceProfile?: (profile: PerformanceProfile) => void;
  userName?: string;
}

export const Header: React.FC<HeaderProps> = ({
  searchQuery,
  onSearchChange,
  sidebarCollapsed,
  onToggleSidebarCollapse,
  assistantPanelMode,
  onCycleAssistantPanelMode,
  currentModelId,
  onSelectModel,
  performanceProfile = 'balanced',
  onChangePerformanceProfile,
  userName = 'Local User',
}) => {
  const { mode, toggleTheme, accent, setAccent, currentAccentPreset } = useTheme();
  const { isOnline, modelStatus, isModelLoading, loadModel, unloadModel, changeProfile, registry } = useBackend();
  const [switchingModelId, setSwitchingModelId] = useState<string | null>(null);

  const isLoaded = Boolean(isOnline && modelStatus?.model_loaded && modelStatus?.active_model);
  const isSleeping = isLoaded && modelStatus?.runtime_state === 'MODEL_SLEEPING';
  const backendActiveModelId = isLoaded ? (modelStatus?.active_model ?? null) : null;

  const activeRegistryEntry = backendActiveModelId
    ? registry.find((e) => registryEntryMatchesIdentifier(e, backendActiveModelId))
    : null;
  const activeDisplayName = activeRegistryEntry
    ? getRegistryEntryDisplayName(activeRegistryEntry)
    : backendActiveModelId;

  let activeModelLabel = 'Router Offline';
  if (!isOnline) {
    activeModelLabel = 'Runtime Offline';
  } else if (modelStatus?.runtime_state === 'SERVER_STOPPED') {
    activeModelLabel = 'Router Offline';
  } else if (modelStatus?.runtime_state === 'MODEL_LOADING' || isModelLoading) {
    activeModelLabel = switchingModelId ? `Loading ${switchingModelId}...` : 'Loading...';
  } else if (modelStatus?.runtime_state === 'MODEL_UNLOADED' || !backendActiveModelId) {
    activeModelLabel = 'No Model Loaded';
  } else if (isLoaded) {
    activeModelLabel = isSleeping
      ? `${activeDisplayName} (Sleeping)`
      : `${activeDisplayName}`;
  }

  // Model options for dropdown — strictly populated from verified installed registry
  const modelOptions = registry.map((entry) => {
    const entryId = getRegistryEntryId(entry);
    const entryDisplayName = getRegistryEntryDisplayName(entry);
    const isThisActive = Boolean(backendActiveModelId && registryEntryMatchesIdentifier(entry, backendActiveModelId));

    let badge = 'Disk';
    if (!isOnline) {
      badge = 'Disk';
    } else if (isModelLoading && switchingModelId === entryId) {
      badge = 'Loading';
    } else if (isThisActive) {
      if (isSleeping) {
        badge = 'Sleeping';
      } else if (modelStatus?.runtime_state === 'MODEL_ERROR') {
        badge = 'Error';
      } else {
        badge = 'Loaded';
      }
    }

    return {
      id: entryId,
      label: entryDisplayName,
      badge,
      icon: <Cpu className="w-3.5 h-3.5 text-[var(--color-accent)]" />,
      onClick: async () => {
        onSelectModel?.(entryId);
        if (!isOnline) return;
        if (isThisActive && modelStatus?.runtime_state === 'MODEL_READY') {
          return;
        }
        try {
          setSwitchingModelId(entryId);
          await loadModel(entryId);
        } catch {
          // Handled in backend context
        } finally {
          setSwitchingModelId(null);
        }
      },
    };
  });

  // Construct dropdown items including Unload action when model is loaded/sleeping
  const modelDropdownItems: (DropdownItem | { divider: true })[] = [];
  if (isLoaded) {
    modelDropdownItems.push({
      id: 'action-unload-model',
      label: 'Unload current model',
      badge: 'Unload',
      danger: true,
      icon: <PowerOff className="w-3.5 h-3.5 text-rose-500" />,
      onClick: async () => {
        if (!isOnline) return;
        try {
          await unloadModel();
        } catch {
          // Handled in backend context
        }
      },
    });
    modelDropdownItems.push({ divider: true });
  }
  modelDropdownItems.push(...modelOptions);

  // Performance Profile options & truthfulness
  const requestedProfile = isOnline ? (modelStatus?.requested_profile as PerformanceProfile | undefined) : undefined;
  const appliedProfile = (isOnline && modelStatus?.router_running) ? (modelStatus?.applied_profile as PerformanceProfile | null) : null;
  const profileDisplay = !isOnline || !modelStatus ? 'Unavailable' : (requestedProfile || 'Not Set');

  const profileOptions = [
    {
      id: 'maximum',
      label: 'Maximum (Max AI)',
      badge: !isOnline || !modelStatus ? undefined : appliedProfile === 'maximum' ? 'Applied' : requestedProfile === 'maximum' ? 'Requested' : undefined,
      icon: <Zap className="w-3.5 h-3.5 text-amber-500" />,
      onClick: async () => {
        if (!isOnline) return;
        onChangePerformanceProfile?.('maximum');
        try {
          await changeProfile('maximum');
        } catch {
          // Handled in backend context
        }
      },
    },
    {
      id: 'balanced',
      label: 'Balanced Profile',
      badge: !isOnline || !modelStatus ? undefined : appliedProfile === 'balanced' ? 'Applied' : requestedProfile === 'balanced' ? 'Requested' : undefined,
      icon: <Gauge className="w-3.5 h-3.5 text-[var(--color-accent)]" />,
      onClick: async () => {
        if (!isOnline) return;
        onChangePerformanceProfile?.('balanced');
        try {
          await changeProfile('balanced');
        } catch {
          // Handled in backend context
        }
      },
    },
    {
      id: 'eco',
      label: 'Eco Profile',
      badge: !isOnline || !modelStatus ? undefined : appliedProfile === 'eco' ? 'Applied' : requestedProfile === 'eco' ? 'Requested' : undefined,
      icon: <Leaf className="w-3.5 h-3.5 text-emerald-500" />,
      onClick: async () => {
        if (!isOnline) return;
        onChangePerformanceProfile?.('eco');
        try {
          await changeProfile('eco');
        } catch {
          // Handled in backend context
        }
      },
    },
  ];

  return (
    <header className="sticky top-0 z-50 h-14 w-full glass-bar border-b border-[var(--color-surface-glass-border)] flex items-stretch justify-between flex-shrink-0 select-none transition-colors duration-200">
      {/* 1. Left: Brand & Collapsible Logo Div */}
      <div
        role="button"
        tabIndex={0}
        onClick={onToggleSidebarCollapse}
        onKeyDown={(e) => {
          if (e.key === 'Enter' || e.key === ' ') {
            e.preventDefault();
            onToggleSidebarCollapse();
          }
        }}
        aria-label={sidebarCollapsed ? 'Expand sidebar' : 'Collapse sidebar'}
        title={sidebarCollapsed ? 'Click to expand sidebar' : 'Click to collapse sidebar'}
        className={`h-full flex items-center border-r border-[var(--color-surface-glass-border)] transition-[width,padding] duration-300 ease-in-out cursor-pointer group hover:bg-[var(--color-surface-secondary)]/30 active:scale-[0.99] flex-shrink-0 ${
          sidebarCollapsed ? 'w-14 justify-center px-0' : 'w-64 sm:w-72 px-4 justify-between'
        }`}
      >
        <div
          className={`flex items-center overflow-hidden min-w-0 ${
            sidebarCollapsed ? 'justify-center w-full' : 'gap-3'
          }`}
        >
          <div className="w-9 h-9 rounded-xl bg-accent-gradient flex items-center justify-center text-white font-bold text-sm shadow-md flex-shrink-0 glow-accent-sm group-hover:scale-105 transition-transform duration-200">
            <Cpu className="w-4 h-4 text-white" />
          </div>

          {!sidebarCollapsed && (
            <div className="flex flex-col truncate">
              <span className="font-bold text-xs tracking-tight text-[var(--color-text-primary)] truncate">
                Local AI Runtime
              </span>
              <span className="text-[10px] font-medium text-[var(--color-text-secondary)] truncate">
                Desktop Control Center
              </span>
            </div>
          )}
        </div>

        {!sidebarCollapsed && (
          <div className="opacity-0 group-hover:opacity-75 transition-opacity duration-200 flex items-center gap-1 text-[9px] uppercase font-mono tracking-wider text-[var(--color-text-muted)] group-hover:text-[var(--color-accent)] px-1 py-0.5 rounded surface-recessed border border-[var(--color-border-subtle)] flex-shrink-0 mr-0.5">
            <PanelLeftClose className="w-3 h-3" />
          </div>
        )}
      </div>

      {/* 2. Middle: Status & Active Config Controls */}
      <div className="flex-1 flex items-center justify-between px-3 sm:px-4 gap-2 sm:gap-3 min-w-0">
        {/* Center Indicators / Switchers */}
        <div className="flex items-center gap-2 flex-shrink-0">
          {/* Current Model Selector Dropdown */}
          <Dropdown
            trigger={
              <button
                type="button"
                className="flex items-center gap-1.5 px-2.5 py-1 rounded-xl surface-raised border border-[var(--color-border-subtle)] hover:border-[var(--color-accent)]/40 transition-all text-xs text-[var(--color-text-primary)]"
                title="Current Local Model"
              >
                <Cpu className="w-3.5 h-3.5 text-[var(--color-accent)]" />
                <span className="font-mono font-medium max-w-[110px] sm:max-w-[160px] truncate">
                  {activeModelLabel}
                </span>
                <ChevronDown className="w-3 h-3 text-[var(--color-text-muted)]" />
              </button>
            }
            items={modelDropdownItems}
            align="left"
          />

          {/* Performance Profile Dropdown */}
          <Dropdown
            trigger={
              <button
                type="button"
                className="hidden lg:flex items-center gap-1.5 px-2.5 py-1 rounded-xl surface-raised border border-[var(--color-border-subtle)] hover:border-[var(--color-accent)]/40 transition-all text-xs text-[var(--color-text-primary)]"
                title={
                  !isOnline || !modelStatus
                    ? 'Profile: Unavailable (Runtime Offline)'
                    : appliedProfile
                    ? `Profile: ${appliedProfile} [Applied]`
                    : requestedProfile
                    ? `Profile: ${requestedProfile} (Requested)`
                    : 'Profile: Unavailable'
                }
              >
                {requestedProfile === 'turbo' && <Zap className="w-3.5 h-3.5 text-amber-500" />}
                {requestedProfile === 'maximum' && <Zap className="w-3.5 h-3.5 text-amber-500" />}
                {requestedProfile === 'balanced' && (
                  <Gauge className="w-3.5 h-3.5 text-[var(--color-accent)]" />
                )}
                {requestedProfile === 'eco' && <Leaf className="w-3.5 h-3.5 text-emerald-500" />}
                <span className="font-medium capitalize">{profileDisplay}</span>
                <span className={`text-[10px] font-mono px-1 py-0.5 rounded ${
                  !isOnline || !modelStatus
                    ? 'text-[var(--color-text-muted)] bg-[var(--color-surface-secondary)]'
                    : appliedProfile
                    ? 'text-emerald-400 bg-emerald-500/10'
                    : requestedProfile
                    ? 'text-amber-400 bg-amber-500/10'
                    : 'text-[var(--color-text-muted)] bg-[var(--color-surface-secondary)]'
                }`}>
                  {!isOnline || !modelStatus ? 'Unavailable' : appliedProfile ? 'Applied' : requestedProfile ? 'Requested' : 'Unavailable'}
                </span>
                <ChevronDown className="w-3 h-3 text-[var(--color-text-muted)]" />
              </button>
            }
            items={profileOptions}
            align="right"
          />
        </div>

        {/* Right Tools & User */}
        <div className="flex items-center gap-2 sm:gap-2.5 flex-shrink-0">
          {/* Single Global Lightweight Runtime Status Pill */}
          <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-xl surface-recessed border border-[var(--color-border-subtle)] text-[11px] font-mono">
            <span className={`w-2 h-2 rounded-full ${isOnline ? 'bg-emerald-500 animate-pulse' : 'bg-rose-500'}`} />
            <span className="text-[var(--color-text-secondary)] font-medium">Runtime</span>
            <span className={isOnline ? 'text-emerald-500 font-semibold' : 'text-rose-400 font-semibold'}>
              {isOnline ? 'Online' : 'Offline'}
            </span>
          </div>

          {/* Theme Mode Toggle */}
          <button
            type="button"
            onClick={toggleTheme}
            aria-label={`Switch to ${mode === 'light' ? 'dark' : 'light'} theme`}
            className="w-8 h-8 rounded-xl surface-raised border border-[var(--color-border-subtle)] hover:border-[var(--color-accent)]/40 flex items-center justify-center text-[var(--color-text-primary)] transition-all cursor-pointer"
            title={`Switch to ${mode === 'light' ? 'dark' : 'light'} mode`}
          >
            {mode === 'light' ? (
              <Sun className="w-3.5 h-3.5 text-amber-500" />
            ) : (
              <Moon className="w-3.5 h-3.5 text-sky-400" />
            )}
          </button>

          {/* Current User Avatar & Name */}
          <div className="flex items-center gap-2 pl-1 sm:pl-2 border-l border-[var(--color-border-subtle)]">
            <div className="relative">
              <div className="w-7 h-7 rounded-xl bg-accent-gradient flex items-center justify-center text-white text-xs font-bold shadow-sm glow-accent-sm">
                {userName ? userName[0].toUpperCase() : 'U'}
              </div>
            </div>
            <span className="hidden xl:inline text-xs font-semibold text-[var(--color-text-primary)]">
              {userName}
            </span>
          </div>
        </div>
      </div>
    </header>
  );
};
