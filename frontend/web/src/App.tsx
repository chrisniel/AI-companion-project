import React, { useState, useEffect } from 'react';
import { ThemeProvider } from './context/ThemeContext';
import { BackendProvider, useBackend } from './context/BackendContext';
import { Sidebar } from './components/layout/Sidebar';
import { Header } from './components/layout/Header';
import { GlobalBackground } from './components/layout/GlobalBackground';
import { GlobalComposer } from './components/workspace/GlobalComposer';

// Workspace Views
import { HomeView } from './components/workspace/HomeView';
import { AssistantView } from './components/workspace/AssistantView';
import { TasksView } from './components/workspace/TasksView';
// Lazy Loaded Views
const ScheduleView = React.lazy(() => import('./components/workspace/ScheduleView').then(module => ({ default: module.ScheduleView })));
const HealthView = React.lazy(() => import('./components/workspace/HealthView').then(m => ({ default: m.HealthView })));
const MemoryView = React.lazy(() => import('./components/workspace/MemoryView').then(m => ({ default: m.MemoryView })));
import { ModelsView } from './components/workspace/ModelsView';
const CharactersView = React.lazy(() => import('./components/workspace/CharactersView').then(m => ({ default: m.CharactersView })));
import { DevicesView } from './components/workspace/DevicesView';
import { LogsView } from './components/workspace/LogsView';
const SettingsView = React.lazy(() => import('./components/workspace/SettingsView').then(m => ({ default: m.SettingsView })));
import { ApplicationStatesShowcase } from './components/workspace/states/ApplicationStatesShowcase';
import { DesktopSimulationPreset } from './components/layout/DesktopSizeSelector';
import { WorkspaceErrorBoundary } from './components/workspace/WorkspaceErrorBoundary';

// Types
import { AssistantState, PerformanceProfile } from './types';

function MainApp() {
  const { modelStatus } = useBackend();
  const [activeSection, setActiveSection] = useState('home');
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
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

  const [performanceProfile, setPerformanceProfile] = useState<PerformanceProfile>('balanced');
  const [assistantState, setAssistantState] = useState<AssistantState>('idle');
  const [desktopPreset, setDesktopPreset] = useState<DesktopSimulationPreset>('auto');
  const [windowWidth, setWindowWidth] = useState<number>(window.innerWidth);

  // Desktop Responsive Space Priority: 1280, 1366, 1440, 1920
  // When width is <= 1280, collapse sidebar to icon rail to maximize workspace canvas.
  // Above 1280, sidebar remains comfortably expanded.
  useEffect(() => {
    const applySpacePriority = (effectiveWidth: number) => {
      if (effectiveWidth <= 1280) {
        setSidebarCollapsed(true);
      } else {
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
        return (
          <React.Suspense fallback={<div className="flex h-full items-center justify-center p-8 text-neutral-400">Loading schedule...</div>}>
            <ScheduleView />
          </React.Suspense>
        );
      case 'health':
        return (
          <React.Suspense fallback={<div className="flex h-full items-center justify-center text-neutral-400">Loading health...</div>}>
            <HealthView />
          </React.Suspense>
        );
      case 'memory':
        return (
          <React.Suspense fallback={<div className="flex h-full items-center justify-center text-neutral-400">Loading memory...</div>}>
            <MemoryView />
          </React.Suspense>
        );
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
          <React.Suspense fallback={<div className="flex h-full items-center justify-center text-neutral-400">Loading characters...</div>}>
            <CharactersView />
          </React.Suspense>
        );
      case 'devices':
        return <DevicesView />;
      case 'logs':
        return <LogsView />;
      case 'settings':
        return (
          <React.Suspense fallback={<div className="flex h-full items-center justify-center text-neutral-400">Loading settings...</div>}>
            <SettingsView />
          </React.Suspense>
        );
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
          sidebarCollapsed={sidebarCollapsed}
          onToggleSidebarCollapse={() => setSidebarCollapsed(!sidebarCollapsed)}
          currentModelId={selectedModelId ?? undefined}
          onSelectModel={setSelectedModelId}
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

          {/* Main Workspace Canvas */}
          <main className={`flex-1 min-w-0 flex flex-col justify-between ${
            activeSection === 'assistant'
              ? 'overflow-hidden px-4 sm:px-6 py-4'
              : 'overflow-y-auto px-4 sm:px-8 py-6 sm:py-8 space-y-8'
          }`}>
            <div className={`w-full mx-auto flex-1 ${
              activeSection === 'assistant' ? 'h-full flex flex-col min-h-0' : 'max-w-7xl space-y-8'
            }`}>
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

            {/* Subdued footer (only shown on scrollable pages, omitted in assistant) */}
            {activeSection !== 'assistant' && (
              <footer className="pt-6 pb-2 text-center text-[11px] text-[var(--color-text-muted)]">
                <p>
                  Local AI Control Center • Local Inference & Companion Workspace
                </p>
              </footer>
            )}
          </main>
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
