import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import fs from 'fs';
import path from 'path';
import { CharactersView } from '../components/workspace/CharactersView';
import { DevicesView } from '../components/workspace/DevicesView';
import { LogsView } from '../components/workspace/LogsView';
import { SettingsView } from '../components/workspace/SettingsView';
import * as healthApiModule from '../services/api/healthApi';
import { SystemStatusResponse } from '../services/api/healthApi';
import { ThemeProvider } from '../context/ThemeContext';

describe('Phase 8A.3b.3 Truthfulness Suite', () => {
  describe('CharactersView Truthfulness', () => {
    it('does not import mockCharacters in production CharactersView', () => {
      const filePath = path.resolve(__dirname, '../components/workspace/CharactersView.tsx');
      const content = fs.readFileSync(filePath, 'utf-8');
      expect(content).not.toContain("from '../../mock/characterData'");
      expect(content).not.toContain('mockCharacters');
    });

    it('does not introduce unapproved voice synthesis engine contracts in CharactersView', () => {
      const filePath = path.resolve(__dirname, '../components/workspace/CharactersView.tsx');
      const content = fs.readFileSync(filePath, 'utf-8');
      expect(content).not.toContain('Piper');
      expect(content).not.toContain('Kokoro');
    });

    it('renders Character Studio as an interactive Preview with Neutral Assistant fallback', () => {
      render(<CharactersView />);

      // Must display Character Studio header and Preview badge
      expect(screen.getByText('Character Studio')).toBeDefined();
      expect(screen.getAllByText(/Preview/i).length).toBeGreaterThan(0);

      // Must communicate Neutral Assistant fallback
      expect(screen.getAllByText(/Neutral Assistant/i).length).toBeGreaterThan(0);
      expect(screen.getAllByText(/fallback/i).length).toBeGreaterThan(0);

      // Must communicate planned persistence / activation
      expect(screen.getAllByText(/Planned/i).length).toBeGreaterThan(0);

      // Must NOT render fake active character badge like "Active: Lisa" or claims of persistence
      expect(screen.queryByText(/Saved to local database/i)).toBeNull();
      expect(screen.queryByText(/Active Character:/i)).toBeNull();
    });

    it('displays future personality trait vector preview as read-only / preview only without Save/Apply', () => {
      render(<CharactersView />);

      // Trait vector preview
      expect(screen.getByText('Personality Architecture Preview')).toBeDefined();
      expect(screen.getByText('Warmth')).toBeDefined();

      // There must be NO functional Save / Apply / Activate button
      expect(screen.queryByRole('button', { name: /^Save$/i })).toBeNull();
      expect(screen.queryByRole('button', { name: /^Apply$/i })).toBeNull();
      expect(screen.queryByRole('button', { name: /^Activate$/i })).toBeNull();
    });
  });

  describe('App.tsx Character State Truthfulness', () => {
    it('does not maintain fake activeCharacterId state in App.tsx', () => {
      const filePath = path.resolve(__dirname, '../App.tsx');
      const content = fs.readFileSync(filePath, 'utf-8');
      expect(content).not.toContain("useState('p-1')");
      expect(content).not.toContain('activeCharacterId');
    });
  });

  describe('DevicesView Truthfulness', () => {
    const mockSystemStatus: SystemStatusResponse = {
      status: 'ok',
      platform: 'Windows-11-23H2',
      python_version: '3.11.9',
      hostname: 'WORKSTATION-PC',
      cpu_count: 16,
      version: '0.8.0',
      database_connected: true,
      timestamp: '2026-09-15T00:00:00.000Z',
    };

    beforeEach(() => {
      vi.restoreAllMocks();
    });

    it('does not import mockDevicesList or simulated hardware components in DevicesView', () => {
      const filePath = path.resolve(__dirname, '../components/workspace/DevicesView.tsx');
      const content = fs.readFileSync(filePath, 'utf-8');
      expect(content).not.toContain('mockDevicesList');
      expect(content).not.toContain('AndroidDeviceSyncCard');
      expect(content).not.toContain('AudioDeviceManager');
      expect(content).not.toContain('HealthSourceCard');
      expect(content).not.toContain('RemoteConnectionCard');
      expect(content).not.toContain('Local Mesh Healthy');
      expect(content).not.toContain('Ping: 14ms');
    });

    it('does not describe unapproved peer-to-peer or bi-directional memory sync mechanisms in DevicesView', () => {
      const filePath = path.resolve(__dirname, '../components/workspace/DevicesView.tsx');
      const content = fs.readFileSync(filePath, 'utf-8');
      expect(content).not.toContain('Peer-to-peer');
      expect(content).not.toContain('peer-to-peer');
      expect(content).not.toContain('Bi-directional');
      expect(content).not.toContain('bi-directional');
      expect(content).not.toContain('push notification relay');
      expect(content).not.toContain('Direct BLE');
    });

    it('does not contain overstated host status wording in DevicesView source', () => {
      const filePath = path.resolve(__dirname, '../components/workspace/DevicesView.tsx');
      const content = fs.readFileSync(filePath, 'utf-8');
      expect(content).not.toContain('Host Monitored');
      expect(content).not.toContain('Runtime Offline');
    });

    it('does not expose unapproved host claims such as Host Monitored or Runtime Offline', async () => {
      vi.spyOn(healthApiModule, 'getSystemStatus').mockRejectedValueOnce(new Error('Network error'));

      render(<DevicesView />);

      await waitFor(() => {
        expect(screen.getByText(/Runtime Host Unavailable/i)).toBeDefined();
      });

      expect(screen.queryByText('Host Monitored')).toBeNull();
      expect(screen.queryByText('Runtime Offline')).toBeNull();
    });

    it('shows loading state and renders real host telemetry on success', async () => {
      const getSystemStatusSpy = vi
        .spyOn(healthApiModule, 'getSystemStatus')
        .mockResolvedValue(mockSystemStatus);

      render(<DevicesView />);

      // Should call getSystemStatus
      expect(getSystemStatusSpy).toHaveBeenCalled();

      // Wait for real host data to render
      await waitFor(() => {
        expect(screen.getByText('WORKSTATION-PC')).toBeDefined();
        expect(screen.getByText('Windows-11-23H2')).toBeDefined();
        expect(screen.getByText('3.11.9')).toBeDefined();
        expect(screen.getByText('16 Cores')).toBeDefined();
        expect(screen.getByText('0.8.0')).toBeDefined();
        expect(screen.getByText('Host Status')).toBeDefined();
        expect(screen.getByText('Status Available')).toBeDefined();
      });

      // Planned capability cards rendered truthfully
      expect(screen.getByText('Android Companion')).toBeDefined();
      expect(screen.getByText('Audio Device Management')).toBeDefined();
      expect(screen.getByText('Health & Wearables')).toBeDefined();
      expect(screen.getByText('Remote Runtime Access')).toBeDefined();
    });

    it('renders truthful Unavailable error state on API failure and retries on action', async () => {
      const getSystemStatusSpy = vi
        .spyOn(healthApiModule, 'getSystemStatus')
        .mockRejectedValueOnce(new Error('Network error'))
        .mockResolvedValueOnce(mockSystemStatus);

      render(<DevicesView />);

      await waitFor(() => {
        expect(screen.getByText(/Runtime Host Unavailable/i)).toBeDefined();
        expect(screen.getByText('Host Unavailable')).toBeDefined();
      });

      const retryButton = screen.getByRole('button', { name: /Retry/i });
      fireEvent.click(retryButton);

      await waitFor(() => {
        expect(screen.getByText('WORKSTATION-PC')).toBeDefined();
        expect(screen.getByText('Status Available')).toBeDefined();
      });

      expect(getSystemStatusSpy).toHaveBeenCalledTimes(2);
    });
  });

  describe('LogsView Truthfulness', () => {
    it('does not import initialMockLogs or streamingEventTemplates in LogsView', () => {
      const filePath = path.resolve(__dirname, '../components/workspace/LogsView.tsx');
      const content = fs.readFileSync(filePath, 'utf-8');
      expect(content).not.toContain('initialMockLogs');
      expect(content).not.toContain('streamingEventTemplates');
      expect(content).not.toContain("from '../../mock/logsData'");
    });

    it('does not contain unapproved logging architecture decisions in LogsView', () => {
      const filePath = path.resolve(__dirname, '../components/workspace/LogsView.tsx');
      const content = fs.readFileSync(filePath, 'utf-8');
      expect(content).not.toContain('/api/v1/logs/stream');
      expect(content).not.toContain('WebSocket');
      expect(content).not.toContain('SSE');
      expect(content).not.toContain('rotating JSON');
    });

    it('does not contain fake connection state or fictional log filename in LogsView source', () => {
      const filePath = path.resolve(__dirname, '../components/workspace/LogsView.tsx');
      const content = fs.readFileSync(filePath, 'utf-8');
      expect(content).not.toContain('Stream Disconnected');
      expect(content).not.toContain('Status: Disconnected');
      expect(content).not.toContain('runtime-telemetry.log');
    });

    it('does not expose fake connection state or fictional log filename in LogsView UI', () => {
      render(<LogsView />);

      expect(screen.queryByText('Stream Disconnected')).toBeNull();
      expect(screen.queryByText(/Status: Disconnected/i)).toBeNull();
      expect(screen.queryByText('runtime-telemetry.log')).toBeNull();
    });

    it('renders truthful messaging and does not simulate operational streaming', () => {
      render(<LogsView />);

      expect(screen.getByText('Runtime log streaming is not implemented yet.')).toBeDefined();
      expect(screen.getAllByText(/Planned/i).length).toBeGreaterThan(0);
      expect(screen.getByText('Telemetry Viewer — Preview')).toBeDefined();
      expect(screen.getByText('Status: Not Implemented')).toBeDefined();
      expect(screen.getByText('Planned diagnostic log and telemetry viewer surface.')).toBeDefined();

      // No fake operational indicators
      expect(screen.queryByText(/Live Stream/i)).toBeNull();
      expect(screen.queryByText(/Avg Latency/i)).toBeNull();
      expect(screen.queryByText(/Buffer/i)).toBeNull();
    });
  });

  describe('SettingsView Truthfulness', () => {
    it('does not import unsupported interactive section components in SettingsView', () => {
      const filePath = path.resolve(__dirname, '../components/workspace/SettingsView.tsx');
      const content = fs.readFileSync(filePath, 'utf-8');
      expect(content).not.toContain('GeneralSection');
      expect(content).not.toContain('AssistantSection');
      expect(content).not.toContain('VoiceSection');
      expect(content).not.toContain('AiSection');
      expect(content).not.toContain('HealthSection');
      expect(content).not.toContain('DevicesSection');
      expect(content).not.toContain('NetworkSection');
      expect(content).not.toContain('PrivacySection');
      expect(content).not.toContain('AdvancedSection');
      expect(content).not.toContain('Persisted Locally (SQLite & Keyring)');
    });

    it('does not expose unapproved milestone names in SettingsView planned sections', () => {
      const filePath = path.resolve(__dirname, '../components/workspace/SettingsView.tsx');
      const content = fs.readFileSync(filePath, 'utf-8');
      expect(content).not.toContain('Desktop Wrapper Milestone');
      expect(content).not.toContain('Audio Subsystem Milestone');
      expect(content).not.toContain('Health Connect Milestone');
      expect(content).not.toContain('Audio Routing Subsystem');
      expect(content).not.toContain('Mesh Ingress Milestone');
      expect(content).not.toContain('Security & Enterprise Milestone');
      expect(content).not.toContain('Phase 8P Advanced Subsystem');
    });

    it('opens on Appearance by default and keeps ThemeContext functional', () => {
      render(
        <ThemeProvider>
          <SettingsView />
        </ThemeProvider>
      );

      // Appearance heading / options visible
      expect(screen.getByText(/Theme Mode/i)).toBeDefined();
      expect(screen.getByText(/Appearance preferences are stored in this browser/i)).toBeDefined();
    });

    it('supports typing in SearchInput and clearing the search query', () => {
      render(
        <ThemeProvider>
          <SettingsView />
        </ThemeProvider>
      );

      const searchInput = screen.getByPlaceholderText('Search preferences...') as HTMLInputElement;
      expect(searchInput.value).toBe('');

      // Type "Voice"
      fireEvent.change(searchInput, { target: { value: 'Voice' } });
      expect(searchInput.value).toBe('Voice');

      // Voice should be visible, Appearance should be filtered out
      expect(screen.getByText('Voice')).toBeDefined();
      expect(screen.queryByRole('button', { name: /^Appearance/i })).toBeNull();

      // Click clear search button
      const clearButton = screen.getByRole('button', { name: 'Clear search' });
      fireEvent.click(clearButton);

      // Value should be empty and Appearance button should be restored
      expect(searchInput.value).toBe('');
      expect(screen.getByRole('button', { name: /^Appearance/i })).toBeDefined();
    });

    it('renders Planned section without interactive fake toggles when selecting unsupported tabs', () => {
      render(
        <ThemeProvider>
          <SettingsView />
        </ThemeProvider>
      );

      // Click Voice tab
      const voiceButton = screen.getByRole('button', { name: /Voice/i });
      fireEvent.click(voiceButton);

      // Should show Planned state
      expect(screen.getAllByText(/Planned/i).length).toBeGreaterThan(0);
      expect(screen.queryByText(/kokoro-82m/i)).toBeNull();
      expect(screen.queryByText(/Hey Iris/i)).toBeNull();

      // Click Network tab
      const networkButton = screen.getByRole('button', { name: /Network/i });
      fireEvent.click(networkButton);

      // Should show Planned state
      expect(screen.queryByText(/100.84.192.42/i)).toBeNull();
    });
  });
});
