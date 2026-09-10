import React, { useState } from 'react';
import {
  Cpu,
  Monitor,
  Smartphone,
  Mic,
  Headphones,
  Speaker,
  Activity,
  Watch,
  Network,
  Radio,
  Sliders,
  CheckCircle2,
  HardDrive,
  Layers,
  Filter,
} from 'lucide-react';
import { Badge } from '../ui/Badge';
import { NeumorphicButton } from '../ui/NeumorphicButton';
import { DeviceItem, DeviceCategory } from '../../types';
import { mockDevicesList } from '../../mock/deviceAndMemoryData';
import { DeviceCard } from './devices/DeviceCard';
import { AudioDeviceManager } from './devices/AudioDeviceManager';
import { AndroidDeviceSyncCard } from './devices/AndroidDeviceSyncCard';
import { HealthSourceCard } from './devices/HealthSourceCard';
import { RemoteConnectionCard } from './devices/RemoteConnectionCard';

export const DevicesView: React.FC = () => {
  const [activeSectionFilter, setActiveSectionFilter] = useState<'all' | DeviceCategory>('all');

  // Filter devices by category
  const computerDevices = mockDevicesList.filter((d) => d.category === 'computer');
  const mobileDevices = mockDevicesList.filter((d) => d.category === 'mobile');
  const audioDevices = mockDevicesList.filter((d) => d.category === 'audio');
  const healthDevices = mockDevicesList.filter((d) => d.category === 'health');
  const networkDevices = mockDevicesList.filter((d) => d.category === 'network');

  const filterTabs: { id: 'all' | DeviceCategory; label: string; count: number; icon: React.ReactNode }[] = [
    { id: 'all', label: 'All Devices', count: mockDevicesList.length, icon: <Layers className="w-3.5 h-3.5" /> },
    { id: 'computer', label: 'Computers', count: computerDevices.length, icon: <Monitor className="w-3.5 h-3.5" /> },
    { id: 'mobile', label: 'Mobile', count: mobileDevices.length, icon: <Smartphone className="w-3.5 h-3.5" /> },
    { id: 'audio', label: 'Audio', count: audioDevices.length, icon: <Mic className="w-3.5 h-3.5" /> },
    { id: 'health', label: 'Health', count: healthDevices.length, icon: <Activity className="w-3.5 h-3.5" /> },
    { id: 'network', label: 'Network', count: networkDevices.length, icon: <Network className="w-3.5 h-3.5" /> },
  ];

  return (
    <div id="devices-view" className="space-y-8 pb-12">
      {/* Top Header */}
      <div className="p-5 sm:p-6 rounded-3xl surface-raised border border-[var(--color-border-subtle)] flex flex-col md:flex-row md:items-center justify-between gap-4 shadow-sm">
        <div className="flex items-center gap-3.5">
          <div className="w-11 h-11 rounded-2xl bg-accent-gradient flex items-center justify-center text-white glow-accent-sm flex-shrink-0">
            <HardDrive className="w-5 h-5" />
          </div>
          <div>
            <div className="flex items-center gap-2 flex-wrap">
              <h1 className="text-xl font-bold text-[var(--color-text-primary)]">
                Devices & Hardware Infrastructure
              </h1>
              <Badge variant="accent" size="sm">
                8 Active Endpoints
              </Badge>
            </div>
            <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">
              Workstation host, mobile companion telemetry, dynamic audio routing, health bridge, and encrypted gateway.
            </p>
          </div>
        </div>

        {/* Status badges */}
        <div className="flex items-center gap-2 flex-wrap">
          <Badge variant="success" size="sm" className="flex items-center gap-1.5">
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
            <span>Local Mesh Healthy</span>
          </Badge>
          <Badge variant="glass" size="sm" className="font-mono text-[11px]">
            Ping: 14ms
          </Badge>
        </div>
      </div>

      {/* Category Navigation Bar */}
      <div className="flex items-center gap-1.5 overflow-x-auto pb-1 no-scrollbar">
        {filterTabs.map((tab) => {
          const isActive = activeSectionFilter === tab.id;
          return (
            <button
              key={tab.id}
              onClick={() => setActiveSectionFilter(tab.id)}
              className={`px-3.5 py-2 rounded-2xl text-xs font-semibold flex items-center gap-2 whitespace-nowrap transition-all duration-150 cursor-pointer ${
                isActive
                  ? 'surface-raised text-[var(--color-text-primary)] border border-[var(--color-accent)]/50 shadow-xs'
                  : 'surface-base text-[var(--color-text-secondary)] border border-[var(--color-border-subtle)] hover:text-[var(--color-text-primary)]'
              }`}
            >
              <span className={isActive ? 'text-[var(--color-accent)]' : 'text-[var(--color-text-muted)]'}>
                {tab.icon}
              </span>
              <span>{tab.label}</span>
              <span
                className={`text-[10px] px-1.5 py-0.2 rounded-full font-mono ${
                  isActive ? 'bg-[var(--color-accent)]/20 text-[var(--color-accent)]' : 'surface-recessed text-[var(--color-text-muted)]'
                }`}
              >
                {tab.count}
              </span>
            </button>
          );
        })}
      </div>

      {/* ========================================================================= */}
      {/* 1. COMPUTERS SECTION */}
      {/* ========================================================================= */}
      {(activeSectionFilter === 'all' || activeSectionFilter === 'computer') && (
        <section id="section-computers" className="space-y-4">
          <div className="flex items-center justify-between pb-1 border-b border-[var(--color-border-subtle)]">
            <div className="flex items-center gap-2">
              <Monitor className="w-4 h-4 text-[var(--color-accent)]" />
              <h2 className="text-sm font-bold uppercase tracking-wider text-[var(--color-text-secondary)]">
                Computers
              </h2>
            </div>
            <span className="text-xs text-[var(--color-text-muted)] font-mono">
              Desktop PC Host
            </span>
          </div>

          <div className="grid grid-cols-1 gap-4">
            {computerDevices.map((dev) => (
              <DeviceCard key={dev.id} device={dev} highlight={true} />
            ))}
          </div>
        </section>
      )}

      {/* ========================================================================= */}
      {/* 2. MOBILE SECTION */}
      {/* ========================================================================= */}
      {(activeSectionFilter === 'all' || activeSectionFilter === 'mobile') && (
        <section id="section-mobile" className="space-y-4">
          <div className="flex items-center justify-between pb-1 border-b border-[var(--color-border-subtle)]">
            <div className="flex items-center gap-2">
              <Smartphone className="w-4 h-4 text-emerald-500" />
              <h2 className="text-sm font-bold uppercase tracking-wider text-[var(--color-text-secondary)]">
                Mobile
              </h2>
            </div>
            <span className="text-xs text-[var(--color-text-muted)] font-mono">
              Android Phone Companion
            </span>
          </div>

          <div className="grid grid-cols-1 gap-4">
            {mobileDevices.map((dev) => (
              <DeviceCard key={dev.id} device={dev} />
            ))}
          </div>

          {/* Android Device Sync Status (alarms, tasks, health, assistant connection) */}
          <AndroidDeviceSyncCard />
        </section>
      )}

      {/* ========================================================================= */}
      {/* 3. AUDIO SECTION */}
      {/* ========================================================================= */}
      {(activeSectionFilter === 'all' || activeSectionFilter === 'audio') && (
        <section id="section-audio" className="space-y-4">
          <div className="flex items-center justify-between pb-1 border-b border-[var(--color-border-subtle)]">
            <div className="flex items-center gap-2">
              <Speaker className="w-4 h-4 text-cyan-400" />
              <h2 className="text-sm font-bold uppercase tracking-wider text-[var(--color-text-secondary)]">
                Audio
              </h2>
            </div>
            <span className="text-xs text-[var(--color-text-muted)] font-mono">
              Microphone • Bluetooth Headset • System/Default Devices
            </span>
          </div>

          {/* Audio Device Cards Grid */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {audioDevices.map((dev) => (
              <DeviceCard key={dev.id} device={dev} />
            ))}
          </div>

          {/* Audio Device Manager (Selectors for Input, Output, Preferred Output, Fallback Output, Test buttons) */}
          <AudioDeviceManager />
        </section>
      )}

      {/* ========================================================================= */}
      {/* 4. HEALTH SECTION */}
      {/* ========================================================================= */}
      {(activeSectionFilter === 'all' || activeSectionFilter === 'health') && (
        <section id="section-health" className="space-y-4">
          <div className="flex items-center justify-between pb-1 border-b border-[var(--color-border-subtle)]">
            <div className="flex items-center gap-2">
              <Activity className="w-4 h-4 text-rose-500" />
              <h2 className="text-sm font-bold uppercase tracking-wider text-[var(--color-text-secondary)]">
                Health
              </h2>
            </div>
            <span className="text-xs text-[var(--color-text-muted)] font-mono">
              Health Connect • Smartwatch Source
            </span>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {healthDevices.map((dev) => (
              <DeviceCard key={dev.id} device={dev} />
            ))}
          </div>

          {/* Health Source Card (Health Connect Connected, Source: FitCloudPro, Replaceable providers) */}
          <HealthSourceCard />
        </section>
      )}

      {/* ========================================================================= */}
      {/* 5. NETWORK SECTION */}
      {/* ========================================================================= */}
      {(activeSectionFilter === 'all' || activeSectionFilter === 'network') && (
        <section id="section-network" className="space-y-4">
          <div className="flex items-center justify-between pb-1 border-b border-[var(--color-border-subtle)]">
            <div className="flex items-center gap-2">
              <Network className="w-4 h-4 text-purple-400" />
              <h2 className="text-sm font-bold uppercase tracking-wider text-[var(--color-text-secondary)]">
                Network
              </h2>
            </div>
            <span className="text-xs text-[var(--color-text-muted)] font-mono">
              Remote Gateway Node
            </span>
          </div>

          <div className="grid grid-cols-1 gap-4">
            {networkDevices.map((dev) => (
              <DeviceCard key={dev.id} device={dev} />
            ))}
          </div>

          {/* Remote Connection Card (Remote Gateway, Tailscale replaceable, IP, Latency, Protocol) */}
          <RemoteConnectionCard />
        </section>
      )}
    </div>
  );
};
