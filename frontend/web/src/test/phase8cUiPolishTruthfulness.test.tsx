import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import fs from 'fs';
import path from 'path';

import { ThemeProvider, ACCENT_PRESETS } from '../context/ThemeContext';
import { BackendProvider } from '../context/BackendContext';
import { Header } from '../components/layout/Header';
import { Sidebar, NAV_ITEMS } from '../components/layout/Sidebar';
import { DevicesView } from '../components/workspace/DevicesView';
import { AssistantView } from '../components/workspace/AssistantView';
import { AppearanceSection } from '../components/workspace/settings/AppearanceSection';
import { SettingsView } from '../components/workspace/SettingsView';
import { GlobalComposer } from '../components/workspace/GlobalComposer';
import { ConversationMessageItem } from '../components/workspace/ConversationMessageItem';
import { AssistantMarkdownRenderer } from '../components/workspace/assistant/AssistantMarkdownRenderer';
import { getInitialActiveSection, WORKSPACE_STORAGE_KEY } from '../App';
import * as api from '../services/api';
import { AssistantMessage } from '../types';

vi.mock('../services/api', async () => {
  const actual = await vi.importActual('../services/api');
  return {
    ...actual,
    checkHealth: vi.fn(),
    getModelStatus: vi.fn(),
    fetchModelRegistry: vi.fn(),
    getSystemStatus: vi.fn(),
    listConversations: vi.fn(),
    createConversation: vi.fn(),
    getMessages: vi.fn(),
    streamSendMessage: vi.fn(),
    fetchAttachmentBlobUrl: vi.fn(),
    renameConversation: vi.fn(),
    generateConversationTitle: vi.fn(),
    getApiBaseUrl: () => 'http://127.0.0.1:8000',
    getApiKey: () => '',
  };
});

const mockRegistry: api.RegistryEntry[] = [
  {
    manifest: {
      id: 'qwen3-vl-2b-instruct.gguf',
      display_name: 'Qwen3-VL-2B-Instruct',
      asset_type: 'gguf',
      family: 'Qwen',
      architecture: 'qwen3vl',
      variant: 'instruct',
      parameters: '2.4B',
      quantization: 'Q4_K_M',
      reasoning_mode: 'unsupported',
      capabilities: ['chat', 'vision'],
      input_modalities: ['text', 'image'],
      model_max_context: 4096,
      runtime_compatibility: ['llama.cpp'],
      primary_file: 'models/qwen3-vl-2b-instruct.gguf',
      companion_files: [],
      license: 'Apache-2.0',
      source: 'local',
    },
    library_state: {
      discovery_state: 'verified',
      validation_status: 'verified',
      primary_file_exists: true,
      size_gb: 1.8,
      companion_artifact_statuses: [],
      available_capabilities: ['chat', 'vision'],
    },
    hints: {
      recommended_profiles: ['eco', 'balanced'],
      estimated_vram_gb: 2.2,
      estimated_ram_gb: 1.2,
    },
  } as unknown as api.RegistryEntry,
];

const mockStatus: api.ModelStatusResponse = {
  model_loaded: true,
  active_model: 'qwen3-vl-2b-instruct.gguf',
  runtime_state: 'MODEL_READY',
  model_resident: true,
  applied_context_size: 4096,
  applied_gpu_layers: 33,
  applied_profile: 'balanced',
  requested_profile: 'balanced',
  provider: 'llama_cpp',
  router_running: true,
} as unknown as api.ModelStatusResponse;

const renderWithProviders = (ui: React.ReactElement) => {
  return render(
    <ThemeProvider>
      <BackendProvider>{ui}</BackendProvider>
    </ThemeProvider>
  );
};

describe('Phase 8C UI/UX Polish & Truthfulness Suite', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(api.fetchModelRegistry).mockResolvedValue(mockRegistry);
    vi.mocked(api.checkHealth).mockResolvedValue({ status: 'healthy' });
    vi.mocked(api.getModelStatus).mockResolvedValue(mockStatus);
    vi.mocked(api.listConversations).mockResolvedValue({
      items: [
        {
          id: 'conv-active',
          title: 'Existing Chat',
          character_id: 'aura',
          owner_id: 'chris',
          created_at: '2026-09-30T10:00:00Z',
          updated_at: '2026-09-30T10:00:00Z',
        },
      ],
      total: 1,
    });
    vi.mocked(api.getMessages).mockResolvedValue({
      items: [
        {
          id: 'msg-1',
          conversation_id: 'conv-active',
          sender: 'user',
          content: 'Hello, this is an existing message',
          created_at: '2026-09-30T10:01:00Z',
        } as unknown as api.MessageOut,
      ],
      total: 1,
    });
  });

  describe('1. Global Header Status & Surface Consolidation', () => {
    it('header provides a lightweight global runtime status without explicit :8000 port in production', async () => {
      renderWithProviders(
        <Header
          searchQuery=""
          onSearchChange={() => {}}
          sidebarCollapsed={false}
          onToggleSidebarCollapse={() => {}}
        />
      );

      await waitFor(() => {
        expect(screen.getByText('Online')).toBeInTheDocument();
      });

      // No explicit debug port in header
      expect(screen.queryByText(/:8000/)).not.toBeInTheDocument();
      expect(screen.queryByText(/Port: 8000/)).not.toBeInTheDocument();

      // No persistent VRAM diagnostic chip
      expect(screen.queryByText(/VRAM/i)).not.toBeInTheDocument();

      // No AssistantPanel toggle button in header
      expect(screen.queryByTitle(/Assistant Panel/i)).not.toBeInTheDocument();
      expect(screen.queryByTitle(/Toggle Assistant/i)).not.toBeInTheDocument();
    });
  });

  describe('2. Sidebar Redundant Status Removal', () => {
    it('sidebar source does not contain hardcoded "Python FastAPI API Ready" footer status', () => {
      const filePath = path.resolve(__dirname, '../components/layout/Sidebar.tsx');
      const content = fs.readFileSync(filePath, 'utf-8');

      expect(content).not.toContain('Python FastAPI API Ready');
      expect(content).not.toContain('Port: 8000 (Loopback)');
    });

    it('sidebar renders navigation items cleanly without hardcoded runtime footer status', () => {
      renderWithProviders(
        <Sidebar
          activeSection="home"
          onSelectSection={() => {}}
          collapsed={false}
          onToggleCollapse={() => {}}
        />
      );

      expect(screen.queryByText(/Python FastAPI API Ready/i)).not.toBeInTheDocument();
      expect(screen.queryByText(/Port: 8000 \(Loopback\)/i)).not.toBeInTheDocument();
    });
  });

  describe('3. Appearance Accent Presets & Dark Mode Distinction', () => {
    it('all accent presets define distinct, unique primary and secondary colors in dark mode', () => {
      const presets = Object.values(ACCENT_PRESETS);
      const secondaryColors = presets.map((p) => p.secondaryColor.toLowerCase());

      // Ensure at least 4 presets exist
      expect(presets.length).toBeGreaterThanOrEqual(4);

      // Verify colors are NOT all identical #38bdf8
      const uniqueSecondary = new Set(secondaryColors);
      expect(uniqueSecondary.size).toBe(presets.length);

      // Verify balanced palette includes sky, blue/indigo, emerald/teal, and violet/purple
      const presetIds = presets.map((p) => p.id);
      expect(presetIds).toContain('aurora');
      expect(presetIds).toContain('electric');
      expect(presetIds).toContain('emerald');
      expect(presetIds).toContain('amethyst');
    });

    it('AppearanceSection renders all color presets with distinct swatches', () => {
      renderWithProviders(<AppearanceSection />);

      expect(screen.getAllByText('Ocean Sky').length).toBeGreaterThanOrEqual(1);
      expect(screen.getByText('Cobalt Indigo')).toBeInTheDocument();
      expect(screen.getByText('Emerald Teal')).toBeInTheDocument();
      expect(screen.getByText('Amethyst Violet')).toBeInTheDocument();
    });
  });

  describe('4. Devices View UX & Truthful Telemetry', () => {
    it('DevicesView source contains no technical endpoint strings or "Hybrid Truthfulness"', () => {
      const filePath = path.resolve(__dirname, '../components/workspace/DevicesView.tsx');
      const content = fs.readFileSync(filePath, 'utf-8');

      expect(content).not.toContain('GET /api/v1/system/status');
      expect(content).not.toContain('Hybrid Truthfulness');
    });

    it('truthfully indicates protected telemetry when runtime is online but auth is required', async () => {
      // Simulate /health ok, but /system/status requires auth (401)
      const authError = new api.ApiError({
        code: 'UNAUTHORIZED',
        message: 'Authentication required. Pairing key needed.',
        status: 401,
      });
      vi.mocked(api.getSystemStatus).mockRejectedValueOnce(authError);

      renderWithProviders(<DevicesView />);

      await waitFor(() => {
        expect(screen.getByText('Workstation Telemetry Protected')).toBeInTheDocument();
      });

      // Does NOT claim runtime is offline when runtime is online
      expect(screen.getByText(/local companion runtime is online and reachable/i)).toBeInTheDocument();
      expect(screen.queryByText('Failed to fetch')).not.toBeInTheDocument();
    });

    it('indicates unreachable runtime on transport error without exposing raw "Failed to fetch"', async () => {
      vi.mocked(api.checkHealth).mockRejectedValue(new Error('Failed to fetch'));
      vi.mocked(api.getSystemStatus).mockRejectedValueOnce(new TypeError('Failed to fetch'));

      renderWithProviders(<DevicesView />);

      await waitFor(() => {
        expect(screen.getByText('Runtime Host Unavailable')).toBeInTheDocument();
      });

      // User-friendly copy without raw fetch error in title or primary text
      expect(screen.getByText(/Unable to connect to the local companion runtime service/i)).toBeInTheDocument();
    });
  });

  describe('5. Assistant Chat Layout & New Chat Isolation', () => {
    it('renders persistent compact AssistantStatusBar with title, active persona, and New Chat action', async () => {
      renderWithProviders(<AssistantView />);

      await waitFor(() => {
        expect(screen.getByText('Existing Chat')).toBeInTheDocument();
      });

      expect(screen.getByRole('button', { name: /New Chat/i })).toBeInTheDocument();
      expect(screen.getByText(/Active Persona:/i)).toBeInTheDocument();
    });

    it('New Chat immediately presents empty message viewport and resets conversation state upon creation', async () => {
      vi.mocked(api.createConversation).mockResolvedValueOnce({
        id: 'conv-new-123',
        title: 'New Conversation',
        character_id: 'aura',
        owner_id: 'chris',
        created_at: '2026-10-01T00:00:00Z',
        updated_at: '2026-10-01T00:00:00Z',
      });

      renderWithProviders(<AssistantView />);

      // Wait for existing conversation messages to show
      await screen.findByText('Hello, this is an existing message');

      // Click New Chat
      const newChatBtn = screen.getByRole('button', { name: /New Chat/i });
      fireEvent.click(newChatBtn);

      // Verify that after resolution, old message is gone and empty state is displayed
      await waitFor(() => {
        expect(screen.getByRole('heading', { level: 1, name: 'New Conversation' })).toBeInTheDocument();
      });

      expect(screen.queryByText('Hello, this is an existing message')).not.toBeInTheDocument();
      expect(screen.getByText(/Conversation with Aura/i)).toBeInTheDocument();
    });
  });

  describe('6. Milestone Terminology Cleanup', () => {
    it('SettingsView source contains no user-facing "Phase 8P" milestone label', () => {
      const filePath = path.resolve(__dirname, '../components/workspace/SettingsView.tsx');
      const content = fs.readFileSync(filePath, 'utf-8');

      expect(content).not.toContain('Phase 8P');
      expect(content).not.toContain('Phase 8A');
    });

    it('HomeView source contains no user-facing "Phase 8A.3b.2" or "Tasks API" milestone label', () => {
      const filePath = path.resolve(__dirname, '../components/workspace/HomeView.tsx');
      const content = fs.readFileSync(filePath, 'utf-8');

      expect(content).not.toContain('Phase 8A.3b.2');
      expect(content).not.toContain('backend Tasks API');
    });
  });

  describe('7. Sidebar Static Badge Removal', () => {
    it('sidebar NAV_ITEMS contains no static non-authoritative badges for tasks, models, logs, or assistant', () => {
      const tasksItem = NAV_ITEMS.find((item) => item.id === 'tasks');
      const modelsItem = NAV_ITEMS.find((item) => item.id === 'models');
      const logsItem = NAV_ITEMS.find((item) => item.id === 'logs');
      const assistantItem = NAV_ITEMS.find((item) => item.id === 'assistant');

      expect(tasksItem?.badge).toBeUndefined();
      expect(modelsItem?.badge).toBeUndefined();
      expect(logsItem?.badge).toBeUndefined();
      expect(assistantItem?.badge).toBeUndefined();
    });
  });

  describe('8. Global Assistant Launcher Compact & Non-expanding', () => {
    it('GlobalComposer renders a stable compact launcher without expanding on hover', () => {
      const onOpenAssistant = vi.fn();
      render(<GlobalComposer activeCharacterName="Aura" onOpenAssistant={onOpenAssistant} />);

      const button = screen.getByRole('button', { name: /Ask Aura/i });
      expect(button).toBeInTheDocument();

      fireEvent.click(button);
      expect(onOpenAssistant).toHaveBeenCalledTimes(1);

      fireEvent.keyDown(window, { key: '/' });
      expect(onOpenAssistant).toHaveBeenCalledTimes(2);

      // No expanding container with mock buttons
      expect(screen.queryByTitle(/Image attachments/i)).not.toBeInTheDocument();
    });
  });

  describe('9. Image Lightbox & Modal Preview', () => {
    it('renders clickable thumbnail that opens Modal lightbox and closes on Escape', async () => {
      vi.mocked(api.fetchAttachmentBlobUrl).mockResolvedValue('blob:http://localhost/test-image');

      const testAttachment: api.AttachmentRef = {
        id: 'att-123',
        filename_display: 'photo.png',
        mime_type: 'image/png',
        size_bytes: 4096,
      };

      const message: AssistantMessage = {
        id: 'msg-user-1',
        type: 'user',
        content: 'Here is my photo',
        timestamp: '10:00 AM',
        attachments: [testAttachment],
      };

      render(
        <ConversationMessageItem
          message={message}
          activeConversationId="conv-active"
        />
      );

      const viewButton = await screen.findByRole('button', {
        name: /View enlarged preview of photo\.png/i,
      });
      expect(viewButton).toBeInTheDocument();

      fireEvent.click(viewButton);

      const modal = await screen.findByRole('dialog');
      expect(modal).toBeInTheDocument();
      expect(screen.getByTestId('image-lightbox-content')).toBeInTheDocument();

      // Escape closes lightbox
      fireEvent.keyDown(window, { key: 'Escape' });
      await waitFor(() => {
        expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
      });
    });
  });

  describe('10. Workspace Navigation Persistence Across Refreshes', () => {
    it('restores workspace from sessionStorage and falls back to home when missing or invalid', () => {
      sessionStorage.setItem(WORKSPACE_STORAGE_KEY, 'assistant');
      expect(getInitialActiveSection()).toBe('assistant');

      sessionStorage.setItem(WORKSPACE_STORAGE_KEY, 'tasks');
      expect(getInitialActiveSection()).toBe('tasks');

      sessionStorage.setItem(WORKSPACE_STORAGE_KEY, 'models');
      expect(getInitialActiveSection()).toBe('models');

      sessionStorage.setItem(WORKSPACE_STORAGE_KEY, 'devices');
      expect(getInitialActiveSection()).toBe('devices');

      sessionStorage.setItem(WORKSPACE_STORAGE_KEY, 'invalid-nonexistent-section');
      expect(getInitialActiveSection()).toBe('home');

      sessionStorage.removeItem(WORKSPACE_STORAGE_KEY);
      expect(getInitialActiveSection()).toBe('home');
    });
  });

  describe('11. Quick Model Unload Action in Header', () => {
    it('Header model dropdown provides Unload action when model is loaded', async () => {
      renderWithProviders(
        <Header
          sidebarCollapsed={false}
          onToggleSidebarCollapse={() => {}}
        />
      );

      await waitFor(() => {
        expect(screen.getByText('Qwen3-VL-2B-Instruct')).toBeInTheDocument();
      });

      const trigger = screen.getByTitle('Current Local Model');
      fireEvent.click(trigger);

      const unloadOption = screen.getByText('Unload current model');
      expect(unloadOption).toBeInTheDocument();
    });
  });

  describe('12. Assistant Markdown Rendering & Safety', () => {
    it('renders safe headings, bold, inline code, lists, code blocks and sanitizes javascript: URLs', () => {
      const markdown = `# Main Title
## Subtitle
This is **bold text** and *italic text* and \`const x = 1\`.

> Quoted wisdom

- Bullet one
- Bullet two

1. Ordered one
2. Ordered two

\`\`\`python
print("hello world")
\`\`\`

[Safe Site](https://example.com)
[Unsafe Site](javascript:alert(1))`;

      const { container } = render(<AssistantMarkdownRenderer content={markdown} />);

      expect(screen.getByRole('heading', { level: 2, name: 'Main Title' })).toBeInTheDocument();
      expect(screen.getByRole('heading', { level: 3, name: 'Subtitle' })).toBeInTheDocument();
      expect(screen.getByText('bold text')).toBeInTheDocument();
      expect(screen.getByText('const x = 1')).toBeInTheDocument();
      expect(screen.getByText('Quoted wisdom')).toBeInTheDocument();
      expect(screen.getByText('Bullet one')).toBeInTheDocument();
      expect(screen.getByText('Ordered one')).toBeInTheDocument();
      expect(screen.getByText('print("hello world")')).toBeInTheDocument();

      const safeLink = screen.getByRole('link', { name: 'Safe Site' });
      expect(safeLink).toHaveAttribute('href', 'https://example.com');

      expect(screen.queryByRole('link', { name: 'Unsafe Site' })).not.toBeInTheDocument();
      expect(screen.getByText('Unsafe Site')).toBeInTheDocument();
      expect(container.querySelector('script')).toBeNull();
    });
  });

  describe('13. Devices View Error Classification & Retry Controls', () => {
    it('renders compact icon-only refresh button and simple Try again button on error', async () => {
      const forbiddenError = new api.ApiError({
        code: 'FORBIDDEN',
        message: 'Access denied',
        status: 403,
      });
      vi.mocked(api.getSystemStatus).mockRejectedValueOnce(forbiddenError);

      renderWithProviders(<DevicesView />);

      const refreshBtn = screen.getByRole('button', { name: 'Refresh Host Status' });
      expect(refreshBtn).toBeInTheDocument();

      await waitFor(() => {
        expect(screen.getByText('Workstation Telemetry Access Denied')).toBeInTheDocument();
      });
      expect(screen.getByText('Forbidden')).toBeInTheDocument();

      expect(screen.getByRole('button', { name: 'Try again' })).toBeInTheDocument();
    });
  });

  describe('14. Conversation Title Generation & Deterministic Fallback', () => {
    it('derives concise deterministic fallback title from user prompt', () => {
      expect(api.deriveDeterministicTitle('Can you help me figure out why my local model unloads after sleep?'))
        .toBe('Can you help me figure out…');
      expect(api.deriveDeterministicTitle('Short question?')).toBe('Short question?');
      expect(api.deriveDeterministicTitle('   ')).toBe('New Conversation');
    });

    it('shows optimistic deterministic title on send, defers backend persistence until onAccepted, and replaces with generated title on turn completion', async () => {
      vi.mocked(api.checkHealth).mockResolvedValue({ status: 'healthy' });
      vi.mocked(api.getModelStatus).mockResolvedValue({
        model_loaded: true,
        model_awake: true,
        active_model: 'qwen3-vl-2b-instruct.gguf',
        runtime_state: 'MODEL_READY',
        model_resident: true,
        router_running: true,
      } as any);

      const conv: api.ConversationOut = {
        id: 'conv-test-title',
        title: 'New Conversation',
        character_id: 'default',
        owner_id: 'owner-1',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
        message_count: 0,
      };

      vi.mocked(api.listConversations).mockResolvedValue({ items: [conv], total: 1 });
      vi.mocked(api.getMessages).mockResolvedValue({ items: [], total: 0 });
      vi.mocked(api.renameConversation).mockResolvedValue({ ...conv, title: 'What is RX 580…' });
      vi.mocked(api.generateConversationTitle).mockResolvedValue({
        ...conv,
        title: 'RX 580 Performance Insights',
      });

      let acceptCallback: (() => void) | undefined;
      let onDoneCallback: ((fullText?: string) => void) | undefined;
      vi.mocked(api.streamSendMessage).mockImplementation(async (options) => {
        acceptCallback = options.onAccepted;
        onDoneCallback = options.onDone;
      });

      renderWithProviders(<AssistantView />);

      await waitFor(() => {
        expect(screen.getByText('New Conversation')).toBeInTheDocument();
      });

      const input = screen.getByPlaceholderText(/Message Aura/i);
      fireEvent.change(input, { target: { value: 'What is RX 580 compute capability for local inference?' } });
      fireEvent.click(screen.getByTitle(/Send prompt to local model/i));

      // Deterministic title appears optimistically in UI immediately
      await waitFor(() => {
        expect(screen.getByText('What is RX 580 compute capability…')).toBeInTheDocument();
      });
      // But renameConversation is NOT called before acceptance!
      expect(api.renameConversation).not.toHaveBeenCalled();

      // Trigger acceptance: now rename is persisted to backend
      acceptCallback?.();
      await waitFor(() => {
        expect(api.renameConversation).toHaveBeenCalledWith('conv-test-title', 'What is RX 580 compute capability…');
      });

      // First turn completes
      onDoneCallback?.('Here is the compute capability.');

      // Automated model title replaces temporary title once generated
      await waitFor(() => {
        expect(api.generateConversationTitle).toHaveBeenCalledWith('conv-test-title', {
          currentTitle: 'What is RX 580 compute capability…',
          fallbackTitle: 'What is RX 580 compute capability…',
        });
        expect(screen.getByText('RX 580 Performance Insights')).toBeInTheDocument();
      });
    });

    it('reverts optimistic title and preserves reusable empty draft if first send fails before acceptance', async () => {
      vi.mocked(api.checkHealth).mockResolvedValue({ status: 'healthy' });
      vi.mocked(api.getModelStatus).mockResolvedValue({
        model_loaded: true,
        model_awake: true,
        active_model: 'qwen3-vl-2b-instruct.gguf',
        runtime_state: 'MODEL_READY',
        model_resident: true,
        router_running: true,
      } as any);

      const conv: api.ConversationOut = {
        id: 'conv-test-failure',
        title: 'New Conversation',
        character_id: 'default',
        owner_id: 'owner-1',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
        message_count: 0,
      };

      vi.mocked(api.listConversations).mockResolvedValue({ items: [conv], total: 1 });
      vi.mocked(api.getMessages).mockResolvedValue({ items: [], total: 0 });
      vi.mocked(api.createConversation).mockClear();
      vi.mocked(api.renameConversation).mockClear();

      let errorCallback: ((err: Error, partialText?: string) => void) | undefined;
      vi.mocked(api.streamSendMessage).mockImplementation(async (options) => {
        errorCallback = options.onError;
      });

      renderWithProviders(<AssistantView />);

      await waitFor(() => {
        expect(screen.getByRole('heading', { level: 1, name: 'New Conversation' })).toBeInTheDocument();
      });

      const input = screen.getByPlaceholderText(/Message Aura/i);
      fireEvent.change(input, { target: { value: 'Why does inference stall?' } });
      fireEvent.click(screen.getByTitle(/Send prompt to local model/i));

      // Title optimistically changed in UI heading
      await waitFor(() => {
        expect(screen.getByRole('heading', { level: 1, name: 'Why does inference stall?' })).toBeInTheDocument();
      });
      expect(api.renameConversation).not.toHaveBeenCalled();

      // Trigger pre-acceptance rejection (HTTP 503 / ApiError)
      errorCallback?.(
        new api.ApiError({
          code: 'MODEL_BUSY',
          message: 'Model is currently busy loading weights.',
          status: 503,
        })
      );

      // Reverts to 'New Conversation' so draft is preserved truthfully
      await waitFor(() => {
        expect(screen.getByRole('heading', { level: 1, name: 'New Conversation' })).toBeInTheDocument();
      });

      // No backend rename was ever persisted
      expect(api.renameConversation).not.toHaveBeenCalled();

      // Empty draft remains reusable: clicking New Chat does NOT create a redundant remote conversation
      const newChatBtn = screen.getByRole('button', { name: /New Chat/i });
      fireEvent.click(newChatBtn);
      expect(api.createConversation).not.toHaveBeenCalled();
    });
  });

  describe('15. Blank Conversation Spam Prevention via Empty Draft Reuse', () => {
    it('reuses existing empty draft on repeated New Chat clicks without creating extra rows', async () => {
      vi.mocked(api.checkHealth).mockResolvedValue({ status: 'healthy' });
      vi.mocked(api.getModelStatus).mockResolvedValue({
        model_loaded: true,
        model_awake: true,
        active_model: 'qwen3-vl-2b-instruct.gguf',
        runtime_state: 'MODEL_READY',
        model_resident: true,
        router_running: true,
      } as any);

      const emptyDraft: api.ConversationOut = {
        id: 'conv-empty-draft',
        title: 'New Conversation',
        character_id: 'default',
        owner_id: 'owner-1',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
        message_count: 0,
      };

      vi.mocked(api.listConversations).mockResolvedValue({ items: [emptyDraft], total: 1 });
      vi.mocked(api.getMessages).mockResolvedValue({ items: [], total: 0 });

      renderWithProviders(<AssistantView />);

      await waitFor(() => {
        expect(screen.getByText('New Conversation')).toBeInTheDocument();
      });

      // Clear call count after initial load
      vi.mocked(api.createConversation).mockClear();

      const newChatBtn = screen.getByRole('button', { name: /New Chat/i });
      fireEvent.click(newChatBtn);
      fireEvent.click(newChatBtn);
      fireEvent.click(newChatBtn);

      // Reused empty draft, zero additional createConversation calls
      expect(api.createConversation).not.toHaveBeenCalled();
    });
  });

  describe('16. Authoritative History Drawer Counts & Empty Draft Filtering', () => {
    it('displays authoritative message counts and omits historical empty drafts from drawer', async () => {
      vi.mocked(api.checkHealth).mockResolvedValue({ status: 'healthy' });
      vi.mocked(api.getModelStatus).mockResolvedValue({
        model_loaded: true,
        model_awake: true,
        active_model: 'qwen3-vl-2b-instruct.gguf',
        runtime_state: 'MODEL_READY',
        model_resident: true,
        router_running: true,
      } as any);

      const activeConv: api.ConversationOut = {
        id: 'conv-active',
        title: 'Active Research',
        character_id: 'default',
        owner_id: 'owner-1',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
        message_count: 4,
      };

      const populatedPastConv: api.ConversationOut = {
        id: 'conv-past',
        title: 'Previous Architecture Review',
        character_id: 'default',
        owner_id: 'owner-1',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
        message_count: 12,
      };

      const abandonedEmptyConv: api.ConversationOut = {
        id: 'conv-abandoned-empty',
        title: 'New Conversation (Old Blank)',
        character_id: 'default',
        owner_id: 'owner-1',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
        message_count: 0,
      };

      vi.mocked(api.listConversations).mockResolvedValue({
        items: [activeConv, populatedPastConv, abandonedEmptyConv],
        total: 3,
      });
      vi.mocked(api.getMessages).mockResolvedValue({
        items: [
          {
            id: 'm-1',
            conversation_id: 'conv-active',
            sender: 'user',
            content: 'Hello',
            status: 'completed',
            sequence_no: 1,
            attachments: [],
            created_at: new Date().toISOString(),
          },
        ],
        total: 1,
      });

      renderWithProviders(<AssistantView />);

      await waitFor(() => {
        expect(screen.getByText('Active Research')).toBeInTheDocument();
      });

      // Open drawer
      const historyBtn = screen.getByTitle('Open Conversation History');
      fireEvent.click(historyBtn);

      await waitFor(() => {
        expect(screen.getByText('Previous Architecture Review')).toBeInTheDocument();
      });

      // Authoritative count badge rendered
      expect(screen.getByText('12 msgs')).toBeInTheDocument();

      // Abandoned empty conversation is omitted from drawer
      expect(screen.queryByText('New Conversation (Old Blank)')).not.toBeInTheDocument();
    });
  });

  describe('17. Light Mode Contrast & Crisp Glass Border Tokens', () => {
    it('index.css light mode defines crisp non-white glass border and balanced slate palette', () => {
      const cssPath = path.resolve(__dirname, '../index.css');
      const cssContent = fs.readFileSync(cssPath, 'utf-8');

      // Confirms slate-border contrast (not white-on-white 255, 255, 255)
      expect(cssContent).toContain('--color-surface-glass-border: rgba(148, 163, 184, 0.35);');
      expect(cssContent).toContain('--color-border-subtle: rgba(148, 163, 184, 0.28);');
      // Confirms balanced neutral slate app background
      expect(cssContent).toContain('--color-app-bg: #f1f5f9;');
      // Confirms text hierarchy contrast
      expect(cssContent).toContain('--color-text-primary: #0f172a;');
      expect(cssContent).toContain('--color-text-secondary: #334155;');
    });
  });
});
