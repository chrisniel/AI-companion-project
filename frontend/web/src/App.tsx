import React, { useState, useEffect } from 'react';
import { ThemeProvider } from './context/ThemeContext';
import { BackendProvider, useBackend } from './context/BackendContext';
import { Sidebar } from './components/layout/Sidebar';
import { Header } from './components/layout/Header';
import { AssistantPanel } from './components/layout/AssistantPanel';
import { GlobalBackground } from './components/layout/GlobalBackground';
import { GlobalComposer } from './components/workspace/GlobalComposer';

// Workspace Views
import { HomeView } from './components/workspace/HomeView';
import { AssistantView } from './components/workspace/AssistantView';
import { TasksView } from './components/workspace/TasksView';
import { ScheduleView } from './components/workspace/ScheduleView';
import { HealthView } from './components/workspace/HealthView';
import { MemoryView } from './components/workspace/MemoryView';
import { ModelsView } from './components/workspace/ModelsView';
import { CharactersView } from './components/workspace/CharactersView';
import { DevicesView } from './components/workspace/DevicesView';
import { LogsView } from './components/workspace/LogsView';
import { SettingsView } from './components/workspace/SettingsView';
import { ApplicationStatesShowcase } from './components/workspace/states/ApplicationStatesShowcase';
import { DesktopSimulationPreset } from './components/layout/DesktopSizeSelector';
import { WorkspaceErrorBoundary } from './components/workspace/WorkspaceErrorBoundary';

// Types
import { AssistantPanelMode, AssistantState, PerformanceProfile } from './types';

function MainApp() {
  const { modelStatus } = useBackend();
  const [activeSection, setActiveSection] = useState('home');
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
  const [assistantPanelMode, setAssistantPanelMode] = useState<AssistantPanelMode>('expanded');
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedModelId, setSelectedModelId] = useState<string | null>(null);
  const [hasHydratedInitialModel, setHasHydratedInitialModel] = useState(false);

  // Authoritative backend active model
  const backendActiveModelId = (modelStatus?.model_loaded && modelStatus?.active_model)
    ? modelStatus.active_model
    : null;

  // On initial startup only: hydrate selectedModelId from backend activeModelId
  useEffect(() => {
    if (!hasHydratedInitialModel && backendActiveModelId) {
      setSelectedModelId(backendActiveModelId);
      setHasHydratedInitialModel(true);
    }
  }, [backendActiveModelId, hasHydratedInitialModel]);

  const [activeCharacterId, setActiveCharacterId] = useState('p-1');
  const [performanceProfile, setPerformanceProfile] = useState<PerformanceProfile>('balanced');
  const [assistantState, setAssistantState] = useState<AssistantState>('idle');
  const [desktopPreset, setDesktopPreset] = useState<DesktopSimulationPreset>('auto');
  const [windowWidth, setWindowWidth] = useState<number>(window.innerWidth);

  // Desktop Responsive Space Priority: 1280, 1366, 1440, 1920
  // When width is limited:
  // 1. collapse Assistant Panel
  // 2. collapse sidebar to icons
  // 3. preserve main workspace
  // Do not convert the desktop UI into the mobile UI.
  useEffect(() => {
    const applySpacePriority = (effectiveWidth: number) => {
      if (effectiveWidth <= 1280) {
        // Priority 1: Collapse/hide assistant panel
        setAssistantPanelMode('hidden');
        // Priority 2: Collapse sidebar to icons
        setSidebarCollapsed(true);
        // Priority 3: Main workspace preserves full desktop multi-column layouts
      } else if (effectiveWidth <= 1366) {
        // Priority 1: Collapse Assistant Panel to narrow icon rail
        setAssistantPanelMode('collapsed');
        // Priority 2: Sidebar remains expanded (or can be user toggled)
        setSidebarCollapsed(false);
        // Priority 3: Main workspace preserved
      } else {
        // 1440, 1920: Full widescreen desktop
        setAssistantPanelMode('expanded');
        setSidebarCollapsed(false);
      }
    };

    const handleResize = () => {
      const width = window.innerWidth;
      setWindowWidth(width);
      if (desktopPreset === 'auto') {
        applySpacePriority(width);
      }
    };

    if (desktopPreset === 'auto') {
      applySpacePriority(window.innerWidth);
    } else {
      applySpacePriority(desktopPreset);
    }

    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, [desktopPreset]);

  // Clicking the Assistant menu above the panel automatically closes it if open, or opens it if closed
  const handleToggleAssistantPanel = () => {
    if (assistantPanelMode !== 'hidden') {
      setAssistantPanelMode('hidden');
    } else {
      setAssistantPanelMode('expanded');
    }
  };

  const activeCharacterName = 'Assistant';

  const renderSection = () => {
    switch (activeSection) {
      case 'home':
        return (
          <HomeView
            onNavigate={(sec) => setActiveSection(sec)}
            activeCharacterName={activeCharacterName}
            userName="Local User"
          />
        );
      case 'assistant':
        return (
          <AssistantView
            activeCharacterName={activeCharacterName}
            userName="Local User"
            assistantState={assistantState}
            onSetAssistantState={setAssistantState}
            currentModelName={
              backendActiveModelId || selectedModelId || undefined
            }
          />
        );
      case 'tasks':
        return <TasksView />;
      case 'schedule':
        return <ScheduleView />;
      case 'health':
        return <HealthView />;
      case 'memory':
        return <MemoryView />;
      case 'models':
        return (
          <ModelsView
            selectedModelId={selectedModelId}
            onSelectModel={setSelectedModelId}
            performanceProfile={performanceProfile}
            onChangePerformanceProfile={setPerformanceProfile}
          />
        );
      case 'characters':
        return (
          <CharactersView
            activeCharacterId={activeCharacterId}
            onSelectCharacter={setActiveCharacterId}
          />
        );
      case 'devices':
        return <DevicesView />;
      case 'logs':
        return <LogsView />;
      case 'settings':
        return <SettingsView />;
      case 'states':
        return <ApplicationStatesShowcase />;
      default:
        return (
          <HomeView
            onNavigate={(sec) => setActiveSection(sec)}
            activeCharacterName={activeCharacterName}
            userName="Local User"
          />
        );
    }
  };

  return (
    <div className="flex flex-col h-screen w-full bg-transparent text-[var(--color-text-primary)] overflow-hidden relative select-none">
      {/* 0. Global Background & Environmental Scrim Layer */}
      <GlobalBackground />

      {/* Optional Desktop Size Simulator Indicator Ribbon */}
      {desktopPreset !== 'auto' && (
        <div className="w-full bg-[var(--color-accent)]/15 border-b border-[var(--color-accent)]/30 text-[var(--color-text-primary)] px-4 py-1 flex items-center justify-between text-[11px] font-mono z-50">
          <div className="flex items-center gap-2">
            <span className="w-2 h-2 rounded-full bg-[var(--color-accent)] animate-pulse" />
            <span className="font-bold">DESKTOP SIMULATION: {desktopPreset}px</span>
            <span className="text-[var(--color-text-muted)] hidden sm:inline">
              {desktopPreset <= 1280
                ? 'Space Priority: 1. Assistant Hidden • 2. Sidebar Icons • 3. Workspace Preserved'
                : desktopPreset <= 1366
                ? 'Space Priority: 1. Assistant Collapsed Rail • 2. Sidebar Preserved • 3. Workspace Preserved'
                : 'Full Multi-Panel Desktop Widescreen Layout'}
            </span>
          </div>
          <button
            type="button"
            onClick={() => setDesktopPreset('auto')}
            className="px-2 py-0.5 rounded-md surface-raised border border-[var(--color-border-subtle)] hover:text-[var(--color-accent)] text-[10px] cursor-pointer"
          >
            Reset to Auto
          </button>
        </div>
      )}

      {/* Main Desktop Container (clamped to simulated desktop preset if not auto) */}
      <div
        className={`flex flex-col flex-1 min-h-0 w-full overflow-hidden ${
          desktopPreset !== 'auto'
            ? 'shadow-2xl border-x border-[var(--color-border-subtle)]'
            : ''
        }`}
        style={
          desktopPreset !== 'auto'
            ? { maxWidth: `${desktopPreset}px`, margin: '0 auto' }
            : undefined
        }
      >
        {/* 1. Compact Top Header */}
        <Header
          searchQuery={searchQuery}
          onSearchChange={setSearchQuery}
          sidebarCollapsed={sidebarCollapsed}
          onToggleSidebarCollapse={() => setSidebarCollapsed(!sidebarCollapsed)}
          assistantPanelMode={assistantPanelMode}
          onCycleAssistantPanelMode={handleToggleAssistantPanel}
          currentModelId={selectedModelId ?? undefined}
          onSelectModel={setSelectedModelId}
          activeCharacterId={activeCharacterId}
          onSelectCharacter={setActiveCharacterId}
          performanceProfile={performanceProfile}
          onChangePerformanceProfile={setPerformanceProfile}
          userName="Local User"
          desktopPreset={desktopPreset}
          onSelectDesktopPreset={setDesktopPreset}
          actualWidth={desktopPreset === 'auto' ? windowWidth : desktopPreset}
        />

        {/* 2. Workspace Body */}
        <div className="flex flex-1 min-h-0 overflow-hidden relative z-0">
          {/* Left Navigation Sidebar */}
          <Sidebar
            activeSection={activeSection}
            onSelectSection={(id) => setActiveSection(id)}
            collapsed={sidebarCollapsed}
          />

          {/* Scrollable Main Workspace Canvas */}
          <main className="flex-1 overflow-y-auto flex flex-col justify-between px-4 sm:px-8 py-6 sm:py-8 space-y-8 min-w-0">
            <div className="max-w-7xl w-full mx-auto space-y-8 flex-1">
              <WorkspaceErrorBoundary onReset={() => setActiveSection('home')}>
                {renderSection()}
              </WorkspaceErrorBoundary>
            </div>

            {/* Persistent Global Assistant Composer (Overlayed only on Main menu views, with auto-hide on hover/focus) */}
            {['home', 'tasks', 'schedule', 'health', 'memory'].includes(activeSection) && (
              <GlobalComposer
                activeCharacterName={activeCharacterName}
                onOpenAssistant={() => setActiveSection('assistant')}
              />
            )}

            {/* Subdued footer */}
            <footer className="pt-6 pb-2 text-center text-[11px] text-[var(--color-text-muted)]">
              <p>
                Local AI Control Center • Local Inference & Companion Workspace
              </p>
            </footer>
          </main>

          {/* Optional Right Assistant Panel (Expanded, Collapsed, or Hidden) */}
          <AssistantPanel
            mode={assistantPanelMode}
            onSetMode={setAssistantPanelMode}
            onOpenAssistant={() => setActiveSection('assistant')}
            selectedPersonaId={activeCharacterId}
            onSelectPersona={setActiveCharacterId}
            assistantState={assistantState}
            onSetAssistantState={setAssistantState}
          />
        </div>
      </div>
    </div>
  );
}

export default function App() {
  return (
    <ThemeProvider>
      <BackendProvider>
        <MainApp />
      </BackendProvider>
    </ThemeProvider>
  );
}
