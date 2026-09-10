import React from 'react';
import {
  Monitor,
  Smartphone,
  Mic,
  Headphones,
  Speaker,
  Activity,
  Watch,
  Network,
  Cpu,
  Radio,
  Clock,
  Battery,
  Wifi,
  ShieldCheck,
} from 'lucide-react';
import { DeviceItem } from '../../../types';
import { Badge } from '../../ui/Badge';

export interface DeviceCardProps {
  device: DeviceItem;
  highlight?: boolean;
}

export const DeviceCard: React.FC<DeviceCardProps> = ({
  device,
  highlight = false,
}) => {
  const getDeviceIcon = () => {
    switch (device.iconType) {
      case 'desktop':
        return <Monitor className="w-5 h-5" />;
      case 'phone':
        return <Smartphone className="w-5 h-5" />;
      case 'mic':
        return <Mic className="w-5 h-5" />;
      case 'headphones':
        return <Headphones className="w-5 h-5" />;
      case 'speaker':
        return <Speaker className="w-5 h-5" />;
      case 'activity':
        return <Activity className="w-5 h-5" />;
      case 'watch':
        return <Watch className="w-5 h-5" />;
      case 'network':
        return <Network className="w-5 h-5" />;
      default:
        return <Cpu className="w-5 h-5" />;
    }
  };

  const getStatusBadge = () => {
    switch (device.status) {
      case 'online':
        return (
          <Badge variant="success" size="sm" className="flex items-center gap-1.5">
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
            <span>Online</span>
          </Badge>
        );
      case 'connected':
        return (
          <Badge variant="accent" size="sm" className="flex items-center gap-1.5">
            <span className="w-1.5 h-1.5 rounded-full bg-[var(--color-accent)] animate-pulse" />
            <span>Connected</span>
          </Badge>
        );
      case 'idle':
      case 'standby':
        return (
          <Badge variant="neutral" size="sm">
            Standby
          </Badge>
        );
      case 'offline':
        return (
          <Badge variant="default" size="sm">
            Offline
          </Badge>
        );
      default:
        return (
          <Badge variant="neutral" size="sm">
            {device.status}
          </Badge>
        );
    }
  };

  return (
    <div
      id={`device-card-${device.id}`}
      className={`p-4 sm:p-5 rounded-3xl border flex flex-col justify-between transition-all duration-200 relative overflow-hidden ${
        highlight
          ? 'surface-raised border-[var(--color-accent)] ring-1 ring-[var(--color-accent)]/30 shadow-md'
          : 'surface-base border-[var(--color-border-subtle)] hover:border-[var(--color-border-strong)]'
      }`}
    >
      <div>
        {/* Header: Icon, Name & Status */}
        <div className="flex items-start justify-between gap-3 mb-3">
          <div className="flex items-start gap-3 min-w-0">
            <div className="w-10 h-10 rounded-2xl surface-raised border border-[var(--color-border-subtle)] flex items-center justify-center text-[var(--color-accent)] flex-shrink-0 shadow-xs">
              {getDeviceIcon()}
            </div>
            <div className="min-w-0">
              <h4 className="text-sm font-bold text-[var(--color-text-primary)] truncate" title={device.name}>
                {device.name}
              </h4>
              <p className="text-xs text-[var(--color-accent)] font-medium mt-0.5">
                {device.assignedRole}
              </p>
            </div>
          </div>

          <div className="flex-shrink-0">
            {getStatusBadge()}
          </div>
        </div>

        {/* Capability description */}
        <div className="mb-3.5">
          <span className="text-[10px] font-semibold tracking-wider uppercase text-[var(--color-text-muted)] block mb-1">
            Capability
          </span>
          <p className="text-xs text-[var(--color-text-secondary)] leading-relaxed line-clamp-2">
            {device.capability}
          </p>
        </div>

        {/* Extended hardware details if present */}
        {device.details && Object.keys(device.details).length > 0 && (
          <div className="p-2.5 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] mb-3 grid grid-cols-2 gap-2 text-[11px] font-mono text-[var(--color-text-secondary)]">
            {Object.entries(device.details).slice(0, 4).map(([key, val]) => (
              <div key={key} className="truncate">
                <span className="text-[var(--color-text-muted)]">{key}: </span>
                <span className="text-[var(--color-text-primary)] font-medium">{String(val)}</span>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Footer: Last seen and telemetry */}
      <div className="pt-2.5 border-t border-[var(--color-border-subtle)] flex items-center justify-between text-xs text-[var(--color-text-muted)] font-mono">
        <div className="flex items-center gap-1.5">
          <Clock className="w-3.5 h-3.5 text-[var(--color-text-muted)]" />
          <span>Last seen: {device.lastSeen}</span>
        </div>

        {device.batteryLevel !== undefined && (
          <div className="flex items-center gap-1 text-[var(--color-text-secondary)]">
            <Battery className="w-3.5 h-3.5 text-emerald-500" />
            <span>{device.batteryLevel}%</span>
          </div>
        )}
      </div>
    </div>
  );
};
