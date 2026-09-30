import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import fs from 'fs';
import path from 'path';

import { ThemeProvider, ACCENT_PRESETS } from '../context/ThemeContext';
import { BackendProvider } from '../context/BackendContext';
import { Header } from '../components/layout/Header';
import { Sidebar } from '../components/layout/Sidebar';
import { DevicesView } from '../components/workspace/DevicesView';
import { AssistantView } from '../components/workspace/AssistantView';
import { AppearanceSection } from '../components/workspace/settings/AppearanceSection';
import { SettingsView } from '../components/workspace/SettingsView';
import * as api from '../services/api';

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
});
