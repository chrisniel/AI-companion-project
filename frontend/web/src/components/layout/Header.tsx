import React, { useState } from 'react';
import {
  Sun,
  Moon,
  Palette,
  Bot,
  Sparkles,
  Cpu,
  X,
  PanelLeftClose,
  PanelLeftOpen,
  Bell,
  User,
  Zap,
  Gauge,
  Leaf,
  ChevronDown,
  Check,
  Search,
} from 'lucide-react';
import { useTheme, ACCENT_PRESETS } from '../../context/ThemeContext';
import {
  AccentPresetId,
  AssistantPanelMode,
  PerformanceProfile,
} from '../../types';
import { SearchInput } from '../ui/SearchInput';
import { StatusIndicator } from '../ui/StatusIndicator';
import { Dropdown } from '../ui/Dropdown';
import { IconButton } from '../ui/IconButton';
import { Badge } from '../ui/Badge';
import {
  DesktopSizeSelector,
  DesktopSimulationPreset,
} from './DesktopSizeSelector';
import {
  mockLocalModels,
  mockAssistantPersonas,
  mockNotifications,
} from '../../mock/localAiData';

export interface HeaderProps {
  searchQuery: string;
  onSearchChange: (query: string) => void;
  sidebarCollapsed: boolean;
  onToggleSidebarCollapse: () => void;
  assistantPanelMode: AssistantPanelMode;
  onCycleAssistantPanelMode: () => void;
  currentModelId?: string;
  onSelectModel?: (modelId: string) => void;
  activeCharacterId?: string;
  onSelectCharacter?: (charId: string) => void;
  performanceProfile?: PerformanceProfile;
  onChangePerformanceProfile?: (profile: PerformanceProfile) => void;
  userName?: string;
  desktopPreset?: DesktopSimulationPreset;
  onSelectDesktopPreset?: (preset: DesktopSimulationPreset) => void;
  actualWidth?: number;
}

export const Header: React.FC<HeaderProps> = ({
  searchQuery,
  onSearchChange,
  sidebarCollapsed,
  onToggleSidebarCollapse,
  assistantPanelMode,
  onCycleAssistantPanelMode,
  currentModelId = 'm-1',
  onSelectModel,
  activeCharacterId = 'p-1',
  onSelectCharacter,
  performanceProfile = 'balanced',
  onChangePerformanceProfile,
  userName = 'Chris',
  desktopPreset = 'auto',
  onSelectDesktopPreset,
  actualWidth = 1440,
}) => {
  const { mode, toggleTheme, accent, setAccent, currentAccentPreset } = useTheme();
  const [notificationsOpen, setNotificationsOpen] = useState(false);
  const [notifications, setNotifications] = useState(mockNotifications);

  const activeModel =
    mockLocalModels.find((m) => m.id === currentModelId) || mockLocalModels[0];
  const activePersona =
    mockAssistantPersonas.find((p) => p.id === activeCharacterId) ||
    mockAssistantPersonas[0];

  const unreadCount = notifications.filter((n) => !n.read).length;

  const markAllRead = () => {
    setNotifications(notifications.map((n) => ({ ...n, read: true })));
  };

  // Model options for dropdown
  const modelOptions = mockLocalModels.map((m) => ({
    id: m.id,
    label: m.name,
    badge: m.status === 'loaded' ? 'VRAM' : 'Disk',
    icon: <Cpu className="w-3.5 h-3.5 text-[var(--color-accent)]" />,
    onClick: () => onSelectModel?.(m.id),
  }));

  // Character options for dropdown
  const characterOptions = mockAssistantPersonas.map((p) => ({
    id: p.id,
    label: p.name,
    badge: p.title.split(' ')[0],
    icon: <Bot className="w-3.5 h-3.5 text-[var(--color-accent)]" />,
    onClick: () => onSelectCharacter?.(p.id),
  }));

  // Performance profile options
  const profileOptions = [
    {
      id: 'maximum',
      label: 'Maximum (Max AI)',
      badge: 'High Power',
      icon: <Zap className="w-3.5 h-3.5 text-amber-500" />,
      onClick: () => onChangePerformanceProfile?.('maximum'),
    },
    {
      id: 'balanced',
      label: 'Balanced Profile',
      badge: 'Optimal',
      icon: <Gauge className="w-3.5 h-3.5 text-[var(--color-accent)]" />,
      onClick: () => onChangePerformanceProfile?.('balanced'),
    },
    {
      id: 'eco',
      label: 'Eco Profile',
      badge: 'Cool & Quiet',
      icon: <Leaf className="w-3.5 h-3.5 text-emerald-500" />,
      onClick: () => onChangePerformanceProfile?.('eco'),
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
                Local AI Core
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

      {/* 2. Middle: Search, Status, & Active Config Controls */}
      <div className="flex-1 flex items-center justify-between px-3 sm:px-4 gap-2 sm:gap-3 min-w-0">
        {/* Quick Search */}
        <div className="flex items-center w-48 sm:w-60 lg:w-72 flex-shrink-0">
          <SearchInput
            value={searchQuery}
            onChangeValue={onSearchChange}
            placeholder="Search commands, models, tasks..."
            sizeVariant="sm"
          />
        </div>

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
                <span className="font-mono font-medium max-w-[110px] sm:max-w-[140px] truncate">
                  {activeModel.name.replace('-Instruct', '')}
                </span>
                <ChevronDown className="w-3 h-3 text-[var(--color-text-muted)]" />
              </button>
            }
            items={modelOptions}
            align="left"
          />

          {/* Performance Profile Dropdown */}
          <Dropdown
            trigger={
              <button
                type="button"
                className="hidden lg:flex items-center gap-1.5 px-2.5 py-1 rounded-xl surface-raised border border-[var(--color-border-subtle)] hover:border-[var(--color-accent)]/40 transition-all text-xs text-[var(--color-text-primary)] capitalize"
                title="Performance Profile"
              >
                {performanceProfile === 'turbo' && <Zap className="w-3.5 h-3.5 text-amber-500" />}
                {performanceProfile === 'balanced' && (
                  <Gauge className="w-3.5 h-3.5 text-[var(--color-accent)]" />
                )}
                {performanceProfile === 'eco' && <Leaf className="w-3.5 h-3.5 text-emerald-500" />}
                <span className="font-medium">{performanceProfile}</span>
                <ChevronDown className="w-3 h-3 text-[var(--color-text-muted)]" />
              </button>
            }
            items={profileOptions}
            align="right"
          />
        </div>

        {/* Right Tools & User */}
        <div className="flex items-center gap-2 sm:gap-2.5 flex-shrink-0">
          {/* Local AI Core Status Badge */}
          <div className="hidden xl:flex items-center gap-1.5 px-2.5 py-1 rounded-xl surface-recessed border border-[var(--color-border-subtle)] text-[11px] font-mono">
            <StatusIndicator status="online" size="sm" showLabel={false} />
            <span className="text-[var(--color-text-secondary)] font-medium">Core Active</span>
            <span className="text-[var(--color-accent)]">22ms</span>
          </div>

          {/* Notification Bell with Popover */}
          <div className="relative">
            <button
              type="button"
              onClick={() => setNotificationsOpen(!notificationsOpen)}
              className="relative w-8 h-8 rounded-xl surface-raised border border-[var(--color-border-subtle)] hover:border-[var(--color-accent)]/40 flex items-center justify-center text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)] transition-all"
              title="System Notifications"
            >
              <Bell className="w-3.5 h-3.5" />
              {unreadCount > 0 && (
                <span className="absolute -top-1 -right-1 w-4 h-4 rounded-full bg-[var(--color-accent)] text-white text-[9px] font-bold flex items-center justify-center shadow-sm">
                  {unreadCount}
                </span>
              )}
            </button>

            {notificationsOpen && (
              <div className="absolute right-0 top-10 w-80 p-3 rounded-2xl bg-[var(--color-surface-elevated)]/95 backdrop-blur-2xl border border-[var(--color-surface-glass-border)] shadow-2xl z-[100] space-y-2 animate-in fade-in zoom-in-95 duration-150">
                <div className="flex items-center justify-between pb-2 border-b border-[var(--color-border-subtle)]">
                  <span className="text-xs font-bold text-[var(--color-text-primary)]">
                    Notifications
                  </span>
                  {unreadCount > 0 && (
                    <button
                      type="button"
                      onClick={markAllRead}
                      className="text-[10px] text-[var(--color-accent)] hover:underline"
                    >
                      Mark all as read
                    </button>
                  )}
                </div>

                <div className="space-y-2 max-h-60 overflow-y-auto">
                  {notifications.map((n) => (
                    <div
                      key={n.id}
                      className={`p-2.5 rounded-xl border text-xs transition-colors ${
                        n.read
                          ? 'surface-recessed border-[var(--color-border-subtle)] opacity-75'
                          : 'surface-raised border-[var(--color-accent)]/30'
                      }`}
                    >
                      <div className="flex items-center justify-between text-[10px] font-mono text-[var(--color-text-muted)] mb-1">
                        <span className="font-semibold text-[var(--color-text-primary)]">
                          {n.title}
                        </span>
                        <span>{n.time}</span>
                      </div>
                      <p className="text-[11px] text-[var(--color-text-secondary)]">{n.message}</p>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>

          {/* Desktop Resolution & Space Priority Selector (1280, 1366, 1440, 1920) */}
          {onSelectDesktopPreset && (
            <DesktopSizeSelector
              currentPreset={desktopPreset}
              onSelectPreset={onSelectDesktopPreset}
              actualWidth={actualWidth}
            />
          )}

          {/* Theme Mode Toggle */}
          <button
            type="button"
            onClick={toggleTheme}
            aria-label={`Switch to ${mode === 'light' ? 'dark' : 'light'} theme`}
            className="w-8 h-8 rounded-xl surface-raised border border-[var(--color-border-subtle)] hover:border-[var(--color-accent)]/40 flex items-center justify-center text-[var(--color-text-primary)] transition-all"
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
                {userName ? userName[0].toUpperCase() : 'C'}
              </div>
              <span className="absolute -bottom-0.5 -right-0.5 w-2 h-2 rounded-full bg-emerald-500 border border-[var(--color-app-bg)]" />
            </div>
            <span className="hidden xl:inline text-xs font-semibold text-[var(--color-text-primary)]">
              {userName}
            </span>
          </div>

          {/* Assistant Panel Toggle Button (Click to open or automatically close) */}
          <button
            type="button"
            onClick={onCycleAssistantPanelMode}
            className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold transition-all cursor-pointer ${
              assistantPanelMode !== 'hidden'
                ? 'bg-accent-gradient text-white shadow-md glow-accent-sm'
                : 'surface-raised border border-[var(--color-border-subtle)] text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)] hover:border-[var(--color-accent)]/40'
            }`}
            title={assistantPanelMode !== 'hidden' ? 'Close Assistant Panel' : 'Open Assistant Panel'}
          >
            <Sparkles className="w-3.5 h-3.5" />
            <span className="hidden sm:inline">Assistant</span>
          </button>
        </div>
      </div>
    </header>
  );
};
