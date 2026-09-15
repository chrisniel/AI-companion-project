import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import fs from 'fs';
import path from 'path';
import { HomeView } from '../components/workspace/HomeView';
import { Header } from '../components/layout/Header';
import { AssistantPanel } from '../components/layout/AssistantPanel';
import { GlobalComposer } from '../components/workspace/GlobalComposer';
import { AssistantStatusBar } from '../components/workspace/assistant/AssistantStatusBar';
import { AssistantView } from '../components/workspace/AssistantView';
import { ConversationHistoryDrawer } from '../components/workspace/ConversationHistoryDrawer';
import { AssistantComposer } from '../components/workspace/assistant/AssistantComposer';
import { BackendProvider } from '../context/BackendContext';
import { ThemeProvider } from '../context/ThemeContext';
import * as api from '../services/api';
import { ModelStatusResponse } from '../services/api/modelApi';
import { RegistryEntry } from '../services/api/registryApi';

// Mock API
vi.mock('../services/api', async () => {
  const actual = await vi.importActual<typeof import('../services/api')>('../services/api');
  return {
    ...actual,
    checkHealth: vi.fn(),
    getModelStatus: vi.fn(),
    loadModel: vi.fn(),
    unloadModel: vi.fn(),
    updateModelProfile: vi.fn(),
    fetchModelRegistry: vi.fn(),
    listConversations: vi.fn(),
    getMessages: vi.fn(),
    createConversation: vi.fn(),
  };
});

const mockRegistry: RegistryEntry[] = [
  {
    id: 'qwen3-vl-2b-instruct',
    display_name: 'Qwen3-VL-2B-Instruct',
    family: 'Qwen',
    variant: 'instruct',
    primary_file: 'models/qwen3-vl-2b-instruct.gguf',
    companion_files: [],
    capabilities: ['chat'],
    recommended_profiles: ['eco', 'balanced'],
    estimated_vram_gb: 2.1,
    estimated_ram_gb: 1.1,
    quantization: 'Q4_K_M',
    parameters: '2.4B',
    context_limit: 2048,
    license: 'Apache-2.0',
    source: 'local',
    validation_status: 'verified',
    primary_file_exists: true,
    companion_files_valid: true,
    size_gb: 1.6,
  },
];

function createMockStatus(overrides: Partial<ModelStatusResponse> = {}): ModelStatusResponse {
  return {
    provider: 'llama_cpp',
    engine_version: 'b10936',
    router_running: true,
    managed_by_core: true,
    runtime_state: 'MODEL_READY',
    active_model: 'qwen3-vl-2b-instruct',
    model_resident: true,
    model_loaded: true,
    model_awake: true,
    requested_profile: 'balanced',
    applied_profile: 'balanced',
    applied_context_size: 2048,
    applied_gpu_layers: 33,
    requested_mmproj_offload: true,
    applied_mmproj_offload: true,
    generation_active: false,
    last_runtime_error: null,
    mmproj_offload: true,
    is_loaded: true,
    active_profile: 'balanced',
    context_size: 2048,
    gpu_layers: 33,
    idle_timeout_seconds: 900,
    seconds_until_idle: 850,
    seconds_until_unload: null,
    available_models: ['qwen3-vl-2b-instruct.gguf'],
    ...overrides,
  };
}

const renderWithProviders = (ui: React.ReactElement) => {
  return render(
    <ThemeProvider>
      <BackendProvider>{ui}</BackendProvider>
    </ThemeProvider>
  );
};

describe('Phase 8A.3b.1 Shell + Home Truthfulness Sweep', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(api.fetchModelRegistry).mockResolvedValue(mockRegistry);
  });

  // 1. Backend offline
  it('when backend is offline, Home and Header do NOT report online/loaded and no "Active & Nominal"', async () => {
    vi.mocked(api.checkHealth).mockRejectedValue(new Error('Connection refused'));
    vi.mocked(api.getModelStatus).mockRejectedValue(new Error('Connection refused'));

    renderWithProviders(
      <>
        <Header
          searchQuery=""
          onSearchChange={() => {}}
          sidebarCollapsed={false}
          onToggleSidebarCollapse={() => {}}
          assistantPanelMode="expanded"
          onCycleAssistantPanelMode={() => {}}
        />
        <HomeView onNavigate={() => {}} />
      </>
    );

    // Header model dropdown label must be Runtime Offline
    await waitFor(() => {
      expect(screen.getByText('Runtime Offline')).toBeInTheDocument();
    });

    // Home badge must show offline
    expect(screen.getByText('Local AI Runtime Offline')).toBeInTheDocument();

    // Must NOT contain "Active & Nominal"
    expect(screen.queryByText(/Active & Nominal/i)).not.toBeInTheDocument();

    // VRAM must not show Free (0 MB)
    expect(screen.queryByText(/Free \(0 MB\)/i)).not.toBeInTheDocument();
    // Header/Home VRAM must show Unavailable when offline
    expect(screen.getAllByText('Unavailable').length).toBeGreaterThanOrEqual(1);
  });

  // 2. Backend online with no active model
  it('when backend is online with no active model, Home and Header show No Model Loaded truthfully', async () => {
    vi.mocked(api.checkHealth).mockResolvedValue({ status: 'healthy' });
    vi.mocked(api.getModelStatus).mockResolvedValue(
      createMockStatus({
        model_loaded: false,
        active_model: null,
        runtime_state: 'MODEL_UNLOADED',
        model_resident: false,
        router_running: true,
        applied_gpu_layers: 0,
      })
    );

    renderWithProviders(
      <>
        <Header
          searchQuery=""
          onSearchChange={() => {}}
          sidebarCollapsed={false}
          onToggleSidebarCollapse={() => {}}
          assistantPanelMode="expanded"
          onCycleAssistantPanelMode={() => {}}
        />
        <HomeView onNavigate={() => {}} />
      </>
    );

    await waitFor(() => {
      const noModelTexts = screen.getAllByText('No Model Loaded');
      expect(noModelTexts.length).toBeGreaterThanOrEqual(1);
    });

    expect(screen.getByText('Local AI Runtime Online')).toBeInTheDocument();
    expect(screen.getByText(/No model is currently loaded in Local AI Runtime/i)).toBeInTheDocument();
  });

  // 3. Backend active model
  it('when active model is loaded, Home resolves registry display name and applied GPU layers', async () => {
    vi.mocked(api.checkHealth).mockResolvedValue({ status: 'healthy' });
    vi.mocked(api.getModelStatus).mockResolvedValue(
      createMockStatus({
        model_loaded: true,
        active_model: 'qwen3-vl-2b-instruct',
        runtime_state: 'MODEL_READY',
        model_resident: true,
        router_running: true,
        applied_gpu_layers: 33,
        requested_profile: 'balanced',
        applied_profile: 'balanced',
      })
    );

    renderWithProviders(<HomeView onNavigate={() => {}} />);

    await waitFor(() => {
      // Registry display name resolved in Home
      expect(screen.getAllByText('Qwen3-VL-2B-Instruct').length).toBeGreaterThanOrEqual(1);
    });

    // Applied GPU layers shown truthfully
    expect(screen.getByText('33 GPU layers [Applied]')).toBeInTheDocument();
  });

  // 4. No fabricated metrics
  it('does not render fabricated metrics anywhere in Home or Header', async () => {
    vi.mocked(api.checkHealth).mockResolvedValue({ status: 'healthy' });
    vi.mocked(api.getModelStatus).mockResolvedValue(
      createMockStatus({
        model_loaded: true,
        active_model: 'qwen3-vl-2b-instruct',
        runtime_state: 'MODEL_READY',
        model_resident: true,
        router_running: true,
        applied_gpu_layers: 33,
        requested_profile: 'balanced',
        applied_profile: 'balanced',
      })
    );

    renderWithProviders(
      <>
        <Header
          searchQuery=""
          onSearchChange={() => {}}
          sidebarCollapsed={false}
          onToggleSidebarCollapse={() => {}}
          assistantPanelMode="expanded"
          onCycleAssistantPanelMode={() => {}}
        />
        <HomeView onNavigate={() => {}} />
      </>
    );

    await waitFor(() => {
      expect(screen.getByText('Local AI Runtime Online')).toBeInTheDocument();
    });

    // None of these fabricated metrics must exist:
    expect(screen.queryByText(/22ms/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/42\.8/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/54°C/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/0ms Cloud Latency/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/Free \(0 MB\)/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/38\.4/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/KV Cache/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/Airgapped • Zero Cloud/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/Llama-3\.1-8B-Instruct/i)).not.toBeInTheDocument();
  });

  // 5. App/Header/AssistantPanel source check: no mock data imports
  it('ensures zero production imports of mockAssistantPersonas, mockNotifications, mockActivityLogs in batch files', () => {
    const batchFiles = [
      '../App.tsx',
      '../components/layout/Header.tsx',
      '../components/layout/AssistantPanel.tsx',
      '../components/workspace/GlobalComposer.tsx',
      '../components/workspace/HomeView.tsx',
      '../components/workspace/AssistantView.tsx',
    ];

    for (const relPath of batchFiles) {
      const fullPath = path.resolve(__dirname, relPath);
      const content = fs.readFileSync(fullPath, 'utf-8');

      expect(content).not.toMatch(/mockAssistantPersonas/);
      expect(content).not.toMatch(/mockNotifications/);
      expect(content).not.toMatch(/mockActivityLogs/);
      expect(content).not.toMatch(/from\s+['"].*mock\//);
    }
  });

  // 6. AssistantPanel: no simulation controls
  it('AssistantPanel has no manual assistant-state switcher, simulated inference, or fake VAD waveform', async () => {
    vi.mocked(api.checkHealth).mockResolvedValue({ status: 'healthy' });
    vi.mocked(api.getModelStatus).mockResolvedValue(
      createMockStatus({
        model_loaded: false,
        active_model: null,
        runtime_state: 'MODEL_UNLOADED',
        model_resident: false,
        router_running: true,
      })
    );

    renderWithProviders(
      <AssistantPanel mode="expanded" onSetMode={() => {}} />
    );

    // No Run Inference button
    expect(screen.queryByText(/Run Inference/i)).not.toBeInTheDocument();

    // No manual state changer buttons (Think, Speak, Tool)
    expect(screen.queryByRole('button', { name: /^Think$/i })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /^Speak$/i })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /^Tool$/i })).not.toBeInTheDocument();

    // No fake VAD toggle button
    expect(screen.queryByText(/VAD On/i)).not.toBeInTheDocument();

    // Truthful speech & audio planned label
    expect(screen.getByText(/Voice input not connected/i)).toBeInTheDocument();
  });

  // 7. GlobalComposer: no simulated responses or attachments
  it('GlobalComposer acts as a truthful Assistant launcher with no fake responses or attachments', () => {
    const onOpenAssistant = vi.fn();
    const { container } = render(
      <GlobalComposer
        activeCharacterName="Assistant"
        onOpenAssistant={onOpenAssistant}
      />
    );

    // Collapsed button can be clicked to open assistant
    const launchBtn = screen.getByRole('button', { name: /Ask Assistant/i });
    fireEvent.click(launchBtn);
    expect(onOpenAssistant).toHaveBeenCalledTimes(1);

    // Must not contain 0ms claim
    expect(screen.queryByText(/0ms/i)).not.toBeInTheDocument();

    // Hover over container to expand launcher
    fireEvent.mouseEnter(container.firstChild as Element);

    // In expanded mode, paperclip and mic are disabled
    const buttons = screen.getAllByRole('button');
    const disabledButtons = buttons.filter((b) => b.hasAttribute('disabled'));
    expect(disabledButtons.length).toBeGreaterThanOrEqual(2);
  });

  // 8. Home: no hardcoded sample tasks or wellness data
  it('HomeView displays truthful planned states for tasks, today, and wellness', async () => {
    vi.mocked(api.checkHealth).mockResolvedValue({ status: 'healthy' });
    vi.mocked(api.getModelStatus).mockResolvedValue(
      createMockStatus({
        model_loaded: false,
        active_model: null,
        runtime_state: 'MODEL_UNLOADED',
        model_resident: false,
        router_running: true,
      })
    );

    renderWithProviders(<HomeView onNavigate={() => {}} />);

    // Must NOT contain hardcoded sample tasks
    expect(screen.queryByText(/Deep Work: Core Neural Pipeline Optimization/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/Review llama\.cpp FP16/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/Synchronize daily Oura/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/in 28m/i)).not.toBeInTheDocument();

    // Must NOT contain hardcoded wellness numbers
    expect(screen.queryByText(/7h 48m/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/8,420/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/64 bpm/i)).not.toBeInTheDocument();

    // Shows truthful empty/planned state
    const emptyTaskMsgs = screen.getAllByText(/No live task data available/i);
    expect(emptyTaskMsgs.length).toBeGreaterThanOrEqual(1);

    expect(screen.getByText(/Wearable synchronization not configured/i)).toBeInTheDocument();
  });

  // 9. AssistantStatusBar: no simulated Airgapped/Web mode toggle, no "Runtime Offline (Demo)", no "Low-Latency Loopback"
  it('AssistantStatusBar has no simulated Airgapped/Web mode toggle, no "Runtime Offline (Demo)", and no "Low-Latency Loopback"', () => {
    render(
      <AssistantStatusBar
        conversationTitle="Test Chat"
        drawerConversationsCount={0}
        onOpenHistory={() => {}}
        activeCharacterName="Aura"
        isOnline={false}
        modelStatus={null}
        registry={mockRegistry}
        onNewConversation={() => {}}
        assistantState="offline"
      />
    );

    // No Airgapped Docs / Web Simulated toggle
    expect(screen.queryByText(/Airgapped Docs/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/Web Simulated/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/simulated web search/i)).not.toBeInTheDocument();

    // Truthful Runtime Offline label without (Demo)
    expect(screen.getAllByText('Runtime Offline').length).toBeGreaterThanOrEqual(1);
    expect(screen.queryByText(/Runtime Offline \(Demo\)/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/Core Offline \(Demo\)/i)).not.toBeInTheDocument();

    // No Low-Latency Loopback claim
    expect(screen.queryByText(/Low-Latency Loopback/i)).not.toBeInTheDocument();
  });

  // 10. Missing provider renders Unavailable rather than hardcoded llama.cpp
  it('missing provider renders Unavailable rather than hardcoded llama.cpp in AssistantStatusBar and HomeView', async () => {
    const statusWithoutProvider = createMockStatus({
      provider: '',
      applied_profile: 'balanced',
    });

    // AssistantStatusBar
    const { unmount } = render(
      <AssistantStatusBar
        conversationTitle="Test Chat"
        drawerConversationsCount={0}
        onOpenHistory={() => {}}
        activeCharacterName="Aura"
        isOnline={true}
        modelStatus={statusWithoutProvider}
        registry={mockRegistry}
        onNewConversation={() => {}}
        assistantState="idle"
      />
    );

    expect(screen.getAllByText('Unavailable').length).toBeGreaterThanOrEqual(1);
    expect(screen.queryByText('llama.cpp')).not.toBeInTheDocument();
    expect(screen.queryByText('llama.cpp (BALANCED)')).not.toBeInTheDocument();
    unmount();

    // HomeView
    vi.mocked(api.checkHealth).mockResolvedValue({ status: 'healthy' });
    vi.mocked(api.getModelStatus).mockResolvedValue(statusWithoutProvider);

    renderWithProviders(<HomeView onNavigate={() => {}} />);
    await waitFor(() => {
      expect(screen.getByText('Local AI Runtime Online')).toBeInTheDocument();
    });

    expect(screen.getAllByText('Unavailable').length).toBeGreaterThanOrEqual(1);
    expect(screen.queryByText('llama.cpp')).not.toBeInTheDocument();
  });

  // 11. applied_gpu_layers=null renders Unavailable in Home and AssistantPanel
  it('applied_gpu_layers=null renders Unavailable in Home and AssistantPanel without "null GPU layers"', async () => {
    const statusNullLayers = createMockStatus({
      applied_gpu_layers: null,
      applied_profile: 'balanced',
      provider: 'llama_cpp',
    });

    vi.mocked(api.checkHealth).mockResolvedValue({ status: 'healthy' });
    vi.mocked(api.getModelStatus).mockResolvedValue(statusNullLayers);

    // HomeView
    const { unmount } = renderWithProviders(<HomeView onNavigate={() => {}} />);
    await waitFor(() => {
      expect(screen.getByText('GPU layers: Unavailable')).toBeInTheDocument();
    });
    expect(screen.queryByText(/null GPU layers/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/null \[Applied\]/i)).not.toBeInTheDocument();
    unmount();

    // AssistantPanel
    renderWithProviders(<AssistantPanel mode="expanded" onSetMode={() => {}} />);
    await waitFor(() => {
      expect(screen.getAllByText('Unavailable').length).toBeGreaterThanOrEqual(1);
    });
    expect(screen.queryByText(/null \[Applied\]/i)).not.toBeInTheDocument();
  });

  // 12. Empty backend conversation produces zero synthetic assistant/system messages
  it('empty backend conversation produces zero synthetic assistant/system messages', async () => {
    vi.mocked(api.checkHealth).mockResolvedValue({ status: 'healthy' });
    vi.mocked(api.getModelStatus).mockResolvedValue(createMockStatus());
    vi.mocked(api.listConversations).mockResolvedValue({
      items: [
        {
          id: 'conv-empty-1',
          title: 'Empty Workspace Chat',
          character_id: 'aura',
          owner_id: 'chris',
          created_at: '2026-09-14T00:00:00Z',
          updated_at: '2026-09-14T00:00:00Z',
        },
      ],
      total: 1,
    });
    vi.mocked(api.getMessages).mockResolvedValue({
      items: [],
      total: 0,
    });

    renderWithProviders(<AssistantView />);

    await waitFor(() => {
      expect(screen.getByText('Empty Workspace Chat')).toBeInTheDocument();
    });

    // Zero synthetic messages injected
    expect(screen.queryByText(/Ready for this session/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/New session initialized/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/What would you like to examine or execute/i)).not.toBeInTheDocument();
  });

  // 13. Successful New Chat does not inject synthetic history messages
  it('successful New Chat does not inject synthetic history messages', async () => {
    vi.mocked(api.checkHealth).mockResolvedValue({ status: 'healthy' });
    vi.mocked(api.getModelStatus).mockResolvedValue(createMockStatus());
    vi.mocked(api.listConversations).mockResolvedValue({
      items: [
        {
          id: 'conv-init',
          title: 'Existing Chat',
          character_id: 'aura',
          owner_id: 'chris',
          created_at: '2026-09-14T00:00:00Z',
          updated_at: '2026-09-14T00:00:00Z',
        },
      ],
      total: 1,
    });
    vi.mocked(api.getMessages).mockResolvedValue({
      items: [],
      total: 0,
    });
    vi.mocked(api.createConversation).mockResolvedValue({
      id: 'conv-real-created',
      title: 'New Real Chat',
      character_id: 'aura',
      owner_id: 'chris',
      created_at: '2026-09-14T02:00:00Z',
      updated_at: '2026-09-14T02:00:00Z',
    });

    renderWithProviders(<AssistantView />);

    await waitFor(() => {
      expect(screen.getByText('Existing Chat')).toBeInTheDocument();
    });

    const newChatBtn = screen.getByRole('button', { name: /New Chat/i });
    fireEvent.click(newChatBtn);

    await waitFor(() => {
      expect(screen.getByText('New Real Chat')).toBeInTheDocument();
    });

    // Zero synthetic messages injected
    expect(screen.queryByText(/New session initialized/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/Ready for a new session/i)).not.toBeInTheDocument();
  });

  // 14. Failed/offline New Chat does not create a fake local conversation/session
  it('failed/offline New Chat does not create a fake local conversation or session', async () => {
    vi.mocked(api.checkHealth).mockResolvedValue({ status: 'healthy' });
    vi.mocked(api.getModelStatus).mockResolvedValue(createMockStatus());
    vi.mocked(api.listConversations).mockResolvedValue({
      items: [
        {
          id: 'conv-existing',
          title: 'Preserved Chat Title',
          character_id: 'aura',
          owner_id: 'chris',
          created_at: '2026-09-14T00:00:00Z',
          updated_at: '2026-09-14T00:00:00Z',
        },
      ],
      total: 1,
    });
    vi.mocked(api.getMessages).mockResolvedValue({
      items: [],
      total: 0,
    });
    vi.mocked(api.createConversation).mockRejectedValue(new Error('Network offline'));

    renderWithProviders(<AssistantView />);

    await waitFor(() => {
      expect(screen.getByText('Preserved Chat Title')).toBeInTheDocument();
    });

    const newChatBtn = screen.getByRole('button', { name: /New Chat/i });
    fireEvent.click(newChatBtn);

    // Must preserve existing valid conversation title, NOT switch to "Local Session (Offline)"
    await waitFor(() => {
      expect(screen.getByText('Preserved Chat Title')).toBeInTheDocument();
    });
    expect(screen.queryByText(/Local Session \(Offline\)/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/Local session created offline/i)).not.toBeInTheDocument();
  });

  // 15. GlobalComposer exposes no editable textbox whose contents are discarded
  it('GlobalComposer exposes no editable textbox whose contents are discarded', () => {
    const onOpenAssistant = vi.fn();
    const { container } = render(
      <GlobalComposer
        activeCharacterName="Aura"
        onOpenAssistant={onOpenAssistant}
      />
    );

    // Expand launcher
    fireEvent.mouseEnter(container.firstChild as Element);

    // Must have NO input and NO textarea element
    expect(container.querySelector('input')).toBeNull();
    expect(container.querySelector('textarea')).toBeNull();

    // Launcher button opens assistant
    const launcherBtn = screen.getByRole('button', { name: /Ask Aura \(Opens Assistant Workspace\)/i });
    fireEvent.click(launcherBtn);
    expect(onOpenAssistant).toHaveBeenCalledTimes(1);

    // Global "/" keypress triggers onOpenAssistant
    fireEvent.keyDown(window, { key: '/' });
    expect(onOpenAssistant).toHaveBeenCalledTimes(2);
  });

  // 16. Empty ConversationHistoryDrawer renders no mock conversations and no fake titles
  it('empty ConversationHistoryDrawer renders no mock conversations, truthful empty state, and no 100% private claim', () => {
    render(
      <ConversationHistoryDrawer
        isOpen={true}
        onClose={() => {}}
        activeConversationId=""
        onSelectConversation={() => {}}
        onNewConversation={() => {}}
        conversations={[]}
      />
    );

    // Truthful empty state
    expect(screen.getByText('No conversations yet')).toBeInTheDocument();

    // Fake mock conversation titles must NEVER appear
    expect(screen.queryByText(/CUDA Kernel Tuning for Quantized Weights/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/Biometric Telemetry & Sleep Cycle Correlation/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/Zero-Telemetry Packet Filter Inspection/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/Audio VAD Threshold Calibration/i)).not.toBeInTheDocument();

    // Truthful footer without absolute privacy claim
    expect(screen.getByText('Local conversation storage')).toBeInTheDocument();
    expect(screen.queryByText(/100% Private on-device/i)).not.toBeInTheDocument();
  });

  // 17. AssistantView has no default "conv-1" conversation identity and neutral initial/offline title
  it('AssistantView has no default "conv-1" conversation identity and neutral initial title', async () => {
    vi.mocked(api.checkHealth).mockRejectedValue(new Error('Offline'));
    vi.mocked(api.getModelStatus).mockRejectedValue(new Error('Offline'));

    renderWithProviders(<AssistantView />);

    // Initial / offline title is neutral
    expect(screen.getByText('No Conversation')).toBeInTheDocument();
    expect(screen.queryByText('conv-1')).not.toBeInTheDocument();
    expect(screen.queryByText('Daily Briefing & Local System Orchestration')).not.toBeInTheDocument();
  });

  // 18. Non-active conversation message counts are not fabricated as 1
  it('non-active conversation message counts are not fabricated as 1', async () => {
    vi.mocked(api.checkHealth).mockResolvedValue({ status: 'healthy' });
    vi.mocked(api.getModelStatus).mockResolvedValue(createMockStatus());
    vi.mocked(api.listConversations).mockResolvedValue({
      items: [
        {
          id: 'conv-active',
          title: 'Active Session',
          character_id: 'aura',
          owner_id: 'chris',
          created_at: '2026-09-14T00:00:00Z',
          updated_at: '2026-09-14T00:00:00Z',
        },
        {
          id: 'conv-other',
          title: 'Other Session',
          character_id: 'aura',
          owner_id: 'chris',
          created_at: '2026-09-14T01:00:00Z',
          updated_at: '2026-09-14T01:00:00Z',
        },
      ],
      total: 2,
    });
    vi.mocked(api.getMessages).mockResolvedValue({
      items: [
        {
          id: 'm1',
          conversation_id: 'conv-active',
          sender: 'user',
          content: 'Hello',
          created_at: '2026-09-14T00:01:00Z',
          status: 'completed',
          sequence_no: 1,
        },
        {
          id: 'm2',
          conversation_id: 'conv-active',
          sender: 'assistant',
          content: 'Hi there',
          created_at: '2026-09-14T00:02:00Z',
          status: 'completed',
          sequence_no: 2,
        },
      ],
      total: 2,
    });

    renderWithProviders(<AssistantView />);

    await waitFor(() => {
      expect(screen.getByText('Active Session')).toBeInTheDocument();
    });

    // Open drawer
    const historyBtn = screen.getByTitle('Open Conversation History');
    fireEvent.click(historyBtn);

    // Active session has real count
    expect(screen.getByText('2 msgs')).toBeInTheDocument();

    // Other session MUST NOT have a fabricated "1 msgs" badge
    expect(screen.queryByText('1 msgs')).not.toBeInTheDocument();
  });

  // 19. AssistantPanel client session state has truthful preview stub description
  it('AssistantPanel client session state has truthful preview stub description and no false claim of "no simulated overrides"', async () => {
    vi.mocked(api.checkHealth).mockResolvedValue({ status: 'healthy' });
    vi.mocked(api.getModelStatus).mockResolvedValue(createMockStatus());

    renderWithProviders(<AssistantPanel mode="expanded" onSetMode={() => {}} />);

    await waitFor(() => {
      expect(
        screen.getByText(/Client-side Assistant UI state\. Voice listening state may be a preview stub\./i)
      ).toBeInTheDocument();
    });
    expect(screen.queryByText(/No simulated overrides/i)).not.toBeInTheDocument();
  });

  // 20. Absent appliedContextSize renders "Context buffer: Unavailable" in AssistantComposer
  it('absent appliedContextSize renders "Context buffer: Unavailable" in AssistantComposer', () => {
    render(
      <AssistantComposer
        inputPrompt=""
        onChangePrompt={() => {}}
        onSendMessage={() => {}}
        onStopGeneration={() => {}}
        isBusy={false}
        assistantState="idle"
        onSetAssistantState={() => {}}
        attachments={[]}
        onRemoveAttachment={() => {}}
        appliedContextSize={null}
      />
    );

    expect(screen.getByText('Context buffer: Unavailable')).toBeInTheDocument();
    expect(screen.queryByText(/Local context buffer: active/i)).not.toBeInTheDocument();
  });

  // 21. Top-level search is removed from Header
  it('top-level search is removed from Header', () => {
    renderWithProviders(
      <Header
        sidebarCollapsed={false}
        onToggleSidebarCollapse={() => {}}
        assistantPanelMode="expanded"
        onCycleAssistantPanelMode={() => {}}
      />
    );

    expect(screen.queryByPlaceholderText(/Search commands, models, tasks/i)).not.toBeInTheDocument();
  });

  // 22. Source grep across all batch files: zero prohibited simulation strings or mock fallback
  it('ensures zero occurrences of prohibited simulation strings across batch files', () => {
    const batchFiles = [
      '../App.tsx',
      '../components/layout/Header.tsx',
      '../components/layout/AssistantPanel.tsx',
      '../components/workspace/GlobalComposer.tsx',
      '../components/workspace/HomeView.tsx',
      '../components/workspace/AssistantView.tsx',
      '../components/workspace/assistant/AssistantStatusBar.tsx',
      '../components/workspace/ConversationHistoryDrawer.tsx',
      '../components/workspace/assistant/AssistantComposer.tsx',
    ];

    const prohibitedPatterns = [
      /Airgapped Docs/,
      /Web Simulated/,
      /simulated web search/,
      /Core Offline \(Demo\)/,
      /Low-Latency Loopback/,
      /null GPU layers/,
      /Local Session \(Offline\)/,
      /mockConversations/,
      /100% Private on-device/,
      /No simulated overrides/,
      /Local context buffer: active/,
      /Search commands, models, tasks/,
      /No Conversation \(Offline\)/,
      /Local conversation session stored in SQLite/,
    ];

    for (const relPath of batchFiles) {
      const fullPath = path.resolve(__dirname, relPath);
      const content = fs.readFileSync(fullPath, 'utf-8');

      for (const pattern of prohibitedPatterns) {
        expect(content).not.toMatch(pattern);
      }
    }
  });

  // 23. ConversationHistoryItem.model is optional and drawer omits the model label when absent
  it('ConversationHistoryItem.model is optional and drawer omits the model label when absent', () => {
    render(
      <ConversationHistoryDrawer
        isOpen={true}
        onClose={() => {}}
        activeConversationId="c1"
        onSelectConversation={() => {}}
        onNewConversation={() => {}}
        conversations={[
          {
            id: 'c1',
            title: 'No Model Session',
            date: 'Sep 14',
            snippet: 'Session without model metadata',
            // model is deliberately absent
          },
          {
            id: 'c2',
            title: 'Session With Model',
            date: 'Sep 14',
            snippet: 'Session with explicit model metadata',
            model: 'Mistral-7B-Instruct',
          },
        ]}
      />
    );

    expect(screen.getByText('No Model Session')).toBeInTheDocument();
    expect(screen.getByText('Session With Model')).toBeInTheDocument();
    // c2 renders Mistral-7B (with -Instruct stripped)
    expect(screen.getByText('Mistral-7B')).toBeInTheDocument();
    // c1 has no model badge rendered
    expect(screen.queryByText('Runtime Offline')).not.toBeInTheDocument();
    expect(screen.queryByText('No Model Loaded')).not.toBeInTheDocument();
  });

  // 24. Historical conversation cards do not fabricate the currently active model from runtime state
  it('historical conversation cards do not fabricate the currently active model from runtime state', async () => {
    vi.mocked(api.checkHealth).mockResolvedValue({ status: 'healthy' });
    vi.mocked(api.getModelStatus).mockResolvedValue(
      createMockStatus({ active_model: 'qwen3-vl-2b-instruct' })
    );
    vi.mocked(api.listConversations).mockResolvedValue({
      items: [
        {
          id: 'conv-hist-1',
          title: 'Historical Conversation Alpha',
          character_id: 'aura',
          owner_id: 'chris',
          created_at: '2026-09-14T00:00:00Z',
          updated_at: '2026-09-14T00:00:00Z',
        },
      ],
      total: 1,
    });
    vi.mocked(api.getMessages).mockResolvedValue({ items: [], total: 0 });

    renderWithProviders(<AssistantView />);

    await waitFor(() => {
      expect(screen.getByText('Historical Conversation Alpha')).toBeInTheDocument();
    });

    // Open drawer
    fireEvent.click(screen.getByTitle('Open Conversation History'));

    // The drawer is visible
    expect(screen.getByText('Conversation History')).toBeInTheDocument();

    // The active model appears in the main status bar
    expect(screen.getByTitle('Qwen3-VL-2B-Instruct')).toBeInTheDocument();

    // But inside the drawer card, neither Qwen3-VL nor Qwen3-VL-2B-Instruct is rendered as a badge
    const drawerContainer = screen.getByText('Local conversation storage').closest('.relative');
    expect(drawerContainer).toBeInTheDocument();
    expect(drawerContainer?.textContent).not.toContain('Qwen3-VL');

    // Nor does it display the fabricated SQLite session snippet
    expect(drawerContainer?.textContent).not.toContain('Local conversation session stored in SQLite.');
    expect(screen.queryByText(/Local conversation session stored in SQLite/i)).not.toBeInTheDocument();
  });

  // 25. Failed New Chat without an existing valid conversation sets title to "No Conversation", not "No Conversation (Offline)"
  it('failed New Chat without an existing valid conversation sets title to "No Conversation", not "No Conversation (Offline)"', async () => {
    vi.mocked(api.checkHealth).mockRejectedValue(new Error('Offline'));
    vi.mocked(api.getModelStatus).mockRejectedValue(new Error('Offline'));
    vi.mocked(api.listConversations).mockRejectedValue(new Error('Offline'));
    vi.mocked(api.createConversation).mockRejectedValue(new Error('Backend unreachable'));

    renderWithProviders(<AssistantView />);

    await waitFor(() => {
      expect(screen.getByText('No Conversation')).toBeInTheDocument();
    });

    const newChatBtn = screen.getByRole('button', { name: /New Chat/i });
    fireEvent.click(newChatBtn);

    // Title must remain strictly "No Conversation", NOT "No Conversation (Offline)"
    await waitFor(() => {
      expect(screen.getByText('No Conversation')).toBeInTheDocument();
    });
    expect(screen.queryByText(/No Conversation \(Offline\)/i)).not.toBeInTheDocument();
  });

  // 26. Offline AssistantStatusBar displays "Runtime Offline" even when currentModelName contains a selected model ID
  it('offline AssistantStatusBar displays "Runtime Offline" even when currentModelName contains a selected model ID', () => {
    render(
      <AssistantStatusBar
        conversationTitle="Test Chat"
        drawerConversationsCount={0}
        onOpenHistory={() => {}}
        activeCharacterName="Aura"
        currentModelName="qwen2.5-7b-instruct-q4_k_m"
        isOnline={false}
        modelStatus={null}
        registry={[]}
        onNewConversation={() => {}}
        assistantState="offline"
      />
    );

    // Main model badge must display "Runtime Offline"
    const modelBadge = screen.getByTitle('Runtime Offline');
    expect(modelBadge).toBeInTheDocument();
    expect(modelBadge.textContent).toBe('Runtime Offline');

    // Must NOT display selected model name as though it were active runtime
    expect(screen.queryByText('qwen2.5-7b-instruct-q4_k_m')).not.toBeInTheDocument();
    expect(screen.queryByText(/Selected: qwen2.5-7b-instruct/i)).not.toBeInTheDocument();
  });

  // 27. ConversationHistoryItem.snippet is optional; drawer renders and searches correctly with or without snippet
  it('ConversationHistoryItem.snippet is optional; drawer renders and searches correctly with or without snippet', () => {
    render(
      <ConversationHistoryDrawer
        isOpen={true}
        onClose={() => {}}
        activeConversationId="c1"
        onSelectConversation={() => {}}
        onNewConversation={() => {}}
        conversations={[
          {
            id: 'c1',
            title: 'Session Alpha',
            date: 'Sep 14',
            // snippet is deliberately omitted
          },
          {
            id: 'c2',
            title: 'Session Beta',
            date: 'Sep 14',
            snippet: 'Real explicit preview snippet for beta session',
          },
        ]}
      />
    );

    // c1 renders title and date without fabricated snippet
    expect(screen.getByText('Session Alpha')).toBeInTheDocument();
    // c2 renders its genuine snippet
    expect(screen.getByText('Real explicit preview snippet for beta session')).toBeInTheDocument();
    // Fabricated placeholder must never appear
    expect(screen.queryByText(/Local conversation session stored in SQLite/i)).not.toBeInTheDocument();

    // Search by snippet finds c2 safely even when c1 has no snippet
    const searchInput = screen.getByPlaceholderText(/Search past conversations/i);
    fireEvent.change(searchInput, { target: { value: 'beta session' } });

    expect(screen.getByText('Session Beta')).toBeInTheDocument();
    expect(screen.queryByText('Session Alpha')).not.toBeInTheDocument();

    // Search query matching c1 title finds c1 without error
    fireEvent.change(searchInput, { target: { value: 'Alpha' } });
    expect(screen.getByText('Session Alpha')).toBeInTheDocument();
    expect(screen.queryByText('Session Beta')).not.toBeInTheDocument();
  });
});
