import React, { useState } from 'react';
import {
  Network,
  Radio,
  Lock,
  Globe,
  RefreshCw,
  CheckCircle2,
  Cpu,
  Layers,
  ShieldCheck,
  Zap,
  ChevronDown,
} from 'lucide-react';
import {
  RemoteGatewayProviderOption,
  mockGatewayProviders,
  initialRemoteGatewayDetails,
} from '../../../mock/deviceAndMemoryData';
import { Card } from '../../ui/Card';
import { Badge } from '../../ui/Badge';
import { NeumorphicButton } from '../../ui/NeumorphicButton';
import { useTheme } from '../../../context/ThemeContext';

export const RemoteConnectionCard: React.FC = () => {
  const { mode } = useTheme();
  const [selectedProviderId, setSelectedProviderId] = useState<string>('tailscale');
  const [latencyMs, setLatencyMs] = useState<number>(14);
  const [isPinging, setIsPinging] = useState(false);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);

  const currentProvider =
    mockGatewayProviders.find((p) => p.id === selectedProviderId) ||
    mockGatewayProviders[0];

  const handleProviderChange = (id: string) => {
    setSelectedProviderId(id);
    const prov = mockGatewayProviders.find((p) => p.id === id);
    setStatusMessage(`Gateway tunnel reconfigured to: ${prov?.name}`);
    setTimeout(() => setStatusMessage(null), 3000);
  };

  const handleTestLatency = () => {
    setIsPinging(true);
    setTimeout(() => {
      // Simulate realistic jitter
      const nextLatency = Math.floor(Math.random() * 8) + 11;
      setLatencyMs(nextLatency);
      setIsPinging(false);
      setStatusMessage(`Gateway round-trip verified: ${nextLatency}ms (0% packet loss)`);
      setTimeout(() => setStatusMessage(null), 3000);
    }, 800);
  };

  return (
    <Card
      id="remote-connection-card"
      variant="elevated"
      padding="lg"
      className="space-y-4"
    >
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-[var(--color-border-subtle)]">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-2xl surface-raised border border-[var(--color-border-subtle)] flex items-center justify-center text-cyan-500 flex-shrink-0 shadow-xs">
            <Network className="w-5 h-5" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h3 className="text-base font-bold text-[var(--color-text-primary)]">
                Remote Gateway & Secure Ingress
              </h3>
              <Badge variant="success" size="sm">
                Active Mesh
              </Badge>
            </div>
            <p className="text-xs text-[var(--color-text-muted)]">
              Modular remote gateway architecture. Protocol-agnostic mesh routing and peer discovery.
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <NeumorphicButton
            size="sm"
            variant="secondary"
            onClick={handleTestLatency}
            disabled={isPinging}
            icon={<RefreshCw className={`w-3.5 h-3.5 ${isPinging ? 'animate-spin text-[var(--color-accent)]' : ''}`} />}
          >
            {isPinging ? 'Testing Ping...' : 'Test Latency'}
          </NeumorphicButton>
        </div>
      </div>

      {/* Grid Display: Generic Gateway Details + Modular Provider Switcher */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {/* Gateway Generic Info */}
        <div className="p-4 rounded-2xl surface-base border border-[var(--color-border-subtle)] space-y-2">
          <span className="text-[10px] font-mono uppercase tracking-wider text-[var(--color-text-muted)]">
            Remote Gateway
          </span>
          <div className="flex items-center justify-between">
            <h4 className="text-sm font-bold text-[var(--color-text-primary)]">
              remote-gw-home
            </h4>
            <span className="text-xs font-mono text-emerald-400 font-semibold flex items-center gap-1">
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
              {latencyMs}ms
            </span>
          </div>
          <div className="space-y-1 text-xs font-mono text-[var(--color-text-secondary)]">
            <div>Virtual IP: <span className="text-[var(--color-text-primary)] font-medium">100.84.12.9</span></div>
            <div>Assigned Role: <span className="text-[var(--color-accent)] font-medium">Secure Ingress Proxy</span></div>
            <div>Encryption: <span className="text-[var(--color-text-primary)] font-medium">ChaCha20-Poly1305</span></div>
          </div>
        </div>

        {/* Modular Gateway Provider Switcher (Not tied to Tailscale permanently) */}
        <div className="md:col-span-2 p-4 rounded-2xl surface-base border border-[var(--color-border-subtle)] space-y-3">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
            <div>
              <span className="text-[10px] font-mono uppercase tracking-wider text-[var(--color-text-muted)]">
                Network Gateway Provider (Replaceable)
              </span>
              <div className="flex items-center gap-2 mt-0.5">
                <span className="text-sm font-bold text-[var(--color-text-primary)]">
                  Provider: <span className="text-[var(--color-accent)]">{currentProvider.name}</span>
                </span>
                <Badge variant="accent" size="sm">
                  {currentProvider.protocol}
                </Badge>
              </div>
            </div>

            {/* Selector */}
            <div className="flex items-center gap-1.5">
              <div className="relative">
                <select
                  value={selectedProviderId}
                  onChange={(e) => handleProviderChange(e.target.value)}
                  style={{ colorScheme: mode }}
                  className="px-2.5 py-1.5 pr-7 rounded-xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-xs font-semibold text-[var(--color-text-primary)] focus:outline-none focus:border-[var(--color-accent)] transition-all appearance-none cursor-pointer shadow-xs"
                >
                  {mockGatewayProviders.map((opt) => (
                    <option
                      key={opt.id}
                      value={opt.id}
                      className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}
                    >
                      Switch Provider: {opt.name}
                    </option>
                  ))}
                </select>
                <ChevronDown className="w-3.5 h-3.5 text-[var(--color-text-muted)] absolute right-2 top-1/2 -translate-y-1/2 pointer-events-none" />
              </div>
            </div>
          </div>

          <p className="text-xs text-[var(--color-text-secondary)] leading-relaxed">
            {currentProvider.description}
          </p>

          <div className="pt-1 flex items-center justify-between text-[11px] font-mono text-[var(--color-text-muted)]">
            <div className="flex items-center gap-1.5">
              <ShieldCheck className="w-3.5 h-3.5 text-cyan-500" />
              <span>Zero-trust network architecture • Independent of coordinator vendor</span>
            </div>
            <span>NAT: Direct P2P</span>
          </div>
        </div>
      </div>

      {/* Status Message */}
      {statusMessage && (
        <div className="px-3 py-2 rounded-xl surface-recessed border border-cyan-500/30 text-xs text-cyan-400 flex items-center gap-2 animate-fadeIn">
          <CheckCircle2 className="w-3.5 h-3.5" />
          <span>{statusMessage}</span>
        </div>
      )}
    </Card>
  );
};
