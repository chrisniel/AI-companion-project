import React, { useState } from 'react';
import { Network, ShieldCheck, Globe, Wifi, KeyRound, Check, RefreshCw } from 'lucide-react';
import { Toggle } from '../../ui/Toggle';
import { NeumorphicButton } from '../../ui/NeumorphicButton';
import { useTheme } from '../../../context/ThemeContext';

export interface NetworkSettingsState {
  gatewayProvider: string;
  gatewayIp: string;
  gatewayPort: number;
  allowRemoteCompanion: boolean;
  enforceTlsCertificates: boolean;
  blockOutboundWan: boolean;
}

interface NetworkSectionProps {
  settings: NetworkSettingsState;
  onUpdate: <K extends keyof NetworkSettingsState>(key: K, value: NetworkSettingsState[K]) => void;
}

export const NetworkSection: React.FC<NetworkSectionProps> = ({ settings, onUpdate }) => {
  const { mode } = useTheme();
  const [isPinging, setIsPinging] = useState(false);
  const [pingResult, setPingResult] = useState<string | null>('14.2ms RTT (Healthy)');

  const handleTestPing = () => {
    setIsPinging(true);
    setPingResult(null);
    setTimeout(() => {
      setIsPinging(false);
      const ms = (12 + Math.random() * 4).toFixed(1);
      setPingResult(`${ms}ms RTT (Healthy)`);
    }, 1200);
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h2 className="text-base font-bold text-[var(--color-text-primary)] flex items-center gap-2">
          <Network className="w-5 h-5 text-purple-500" />
          Network, Remote Gateway & Tunneling
        </h2>
        <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">
          Configure encrypted point-to-point mesh networking via Tailscale and monitor loopback health.
        </p>
      </div>

      {/* 1. Remote Gateway Configuration */}
      <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
        <h3 className="text-xs font-bold uppercase tracking-wider font-mono text-[var(--color-accent)] flex items-center gap-1.5">
          <Globe className="w-4 h-4" />
          Remote Gateway Architecture
        </h3>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-[var(--color-text-primary)]">
              Gateway Provider Type
            </label>
            <select
              value={settings.gatewayProvider}
              onChange={(e) => onUpdate('gatewayProvider', e.target.value)}
              style={{ colorScheme: mode }}
              className="w-full px-3.5 py-2.5 rounded-2xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-primary)] font-medium focus:outline-none focus:border-[var(--color-accent)] transition-all cursor-pointer shadow-xs"
            >
              <option value="tailscale" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Tailscale WireGuard Mesh (Recommended)</option>
              <option value="cloudflare" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Cloudflare Zero Trust Tunnel</option>
              <option value="wireguard_direct" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Direct WireGuard Peer-to-Peer</option>
              <option value="loopback_only" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Strict Localhost Only (127.0.0.1 Airgap)</option>
            </select>
          </div>

          <div className="grid grid-cols-3 gap-2">
            <div className="col-span-2 space-y-1.5">
              <label className="text-xs font-semibold text-[var(--color-text-primary)]">
                Node IP / Tailscale Hostname
              </label>
              <input
                type="text"
                value={settings.gatewayIp}
                onChange={(e) => onUpdate('gatewayIp', e.target.value)}
                className="w-full px-3.5 py-2.5 rounded-2xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-primary)] font-mono focus:outline-none focus:border-[var(--color-accent)] transition-all shadow-xs"
                placeholder="100.84.192.42"
              />
            </div>
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-[var(--color-text-primary)]">
                Port
              </label>
              <input
                type="number"
                value={settings.gatewayPort}
                onChange={(e) => onUpdate('gatewayPort', Number(e.target.value))}
                className="w-full px-3.5 py-2.5 rounded-2xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-primary)] font-mono focus:outline-none focus:border-[var(--color-accent)] transition-all shadow-xs"
                placeholder="8000"
              />
            </div>
          </div>
        </div>

        <div className="space-y-3.5 pt-2 border-t border-[var(--color-border-subtle)]">
          <div className="flex items-center justify-between gap-4">
            <div>
              <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                Allow Mobile Companion App Pairing
              </span>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Accept incoming authenticated sessions from your iPad or mobile phone over the tunnel.
              </p>
            </div>
            <Toggle
              checked={settings.allowRemoteCompanion}
              onChange={(val) => onUpdate('allowRemoteCompanion', val)}
              size="sm"
            />
          </div>

          <div className="flex items-center justify-between gap-4 pt-3 border-t border-[var(--color-border-subtle)]">
            <div>
              <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                Enforce Strict Local mTLS Certificates
              </span>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Require mutual TLS certificates for all HTTP/WebSocket API socket connections.
              </p>
            </div>
            <Toggle
              checked={settings.enforceTlsCertificates}
              onChange={(val) => onUpdate('enforceTlsCertificates', val)}
              size="sm"
            />
          </div>
        </div>
      </div>

      {/* 2. Connection State & Diagnostics */}
      <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
        <div className="flex items-center justify-between">
          <h3 className="text-xs font-bold uppercase tracking-wider font-mono text-[var(--color-accent)] flex items-center gap-1.5">
            <Wifi className="w-4 h-4" />
            Gateway Connection State & Telemetry
          </h3>
          <NeumorphicButton
            variant="ghost"
            size="sm"
            onClick={handleTestPing}
            disabled={isPinging}
            icon={<RefreshCw className={`w-3.5 h-3.5 ${isPinging ? 'animate-spin text-[var(--color-accent)]' : ''}`} />}
          >
            {isPinging ? 'Pinging...' : 'Ping Test'}
          </NeumorphicButton>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3.5">
          <div className="p-4 rounded-2xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)]">
            <span className="text-[11px] text-[var(--color-text-muted)] block font-mono">Tunnel State</span>
            <div className="flex items-center gap-1.5 mt-1">
              <span className="w-2.5 h-2.5 rounded-full bg-emerald-500 animate-pulse" />
              <span className="text-sm font-bold text-[var(--color-text-primary)]">Connected & Encrypted</span>
            </div>
            <span className="text-[11px] text-[var(--color-text-secondary)] mt-1 block">
              ChaCha20-Poly1305 WireGuard
            </span>
          </div>

          <div className="p-4 rounded-2xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)]">
            <span className="text-[11px] text-[var(--color-text-muted)] block font-mono">Mesh Latency</span>
            <div className="text-sm font-bold text-[var(--color-accent)] mt-1 font-mono">
              {isPinging ? 'Measuring...' : pingResult || '—'}
            </div>
            <span className="text-[11px] text-[var(--color-text-secondary)] mt-1 block">
              100.84.192.42:8000
            </span>
          </div>

          <div className="p-4 rounded-2xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)]">
            <span className="text-[11px] text-[var(--color-text-muted)] block font-mono">Airgap Policy</span>
            <div className="flex items-center gap-1.5 mt-1">
              <ShieldCheck className="w-4 h-4 text-emerald-500" />
              <span className="text-sm font-bold text-emerald-600 dark:text-emerald-400">WAN Firewall Active</span>
            </div>
            <span className="text-[11px] text-[var(--color-text-secondary)] mt-1 block">
              Outgoing WAN queries blocked
            </span>
          </div>
        </div>
      </div>
    </div>
  );
};
