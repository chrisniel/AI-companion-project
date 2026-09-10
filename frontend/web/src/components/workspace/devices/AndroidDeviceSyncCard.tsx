import React, { useState } from 'react';
import {
  Smartphone,
  Bell,
  CheckSquare,
  Activity,
  Radio,
  RotateCw,
  Check,
  Wifi,
  ShieldCheck,
  Zap,
} from 'lucide-react';
import { AndroidSyncItem } from '../../../types';
import { mockAndroidSyncItems } from '../../../mock/deviceAndMemoryData';
import { Card } from '../../ui/Card';
import { Badge } from '../../ui/Badge';
import { NeumorphicButton } from '../../ui/NeumorphicButton';

export const AndroidDeviceSyncCard: React.FC = () => {
  const [syncItems, setSyncItems] = useState<AndroidSyncItem[]>(mockAndroidSyncItems);
  const [isSyncingAll, setIsSyncingAll] = useState(false);
  const [lastGlobalSync, setLastGlobalSync] = useState('Just now');

  const handleSyncNow = () => {
    setIsSyncingAll(true);
    setTimeout(() => {
      setSyncItems((prev) =>
        prev.map((item) => ({
          ...item,
          status: 'synced',
          lastSynced: 'Just now',
        }))
      );
      setLastGlobalSync('Just now');
      setIsSyncingAll(false);
    }, 1200);
  };

  const getSyncIcon = (key: AndroidSyncItem['key']) => {
    switch (key) {
      case 'alarms':
        return <Bell className="w-4 h-4 text-amber-500" />;
      case 'tasks':
        return <CheckSquare className="w-4 h-4 text-emerald-500" />;
      case 'health':
        return <Activity className="w-4 h-4 text-rose-500" />;
      case 'assistantConnection':
        return <Radio className="w-4 h-4 text-[var(--color-accent)]" />;
    }
  };

  return (
    <Card
      id="android-device-sync-card"
      variant="elevated"
      padding="lg"
      className="space-y-4"
    >
      {/* Card Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-[var(--color-border-subtle)]">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-2xl surface-raised border border-[var(--color-border-subtle)] flex items-center justify-center text-emerald-500 flex-shrink-0 shadow-xs">
            <Smartphone className="w-5 h-5" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h3 className="text-base font-bold text-[var(--color-text-primary)]">
                Android Device Telemetry & Sync Bridge
              </h3>
              <Badge variant="success" size="sm">
                Connected
              </Badge>
            </div>
            <p className="text-xs text-[var(--color-text-muted)]">
              Pixel 8 Pro • Android 15 • Background bidirectional synchronization channel.
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <NeumorphicButton
            size="sm"
            variant="secondary"
            onClick={handleSyncNow}
            disabled={isSyncingAll}
            icon={<RotateCw className={`w-3.5 h-3.5 ${isSyncingAll ? 'animate-spin text-[var(--color-accent)]' : ''}`} />}
          >
            {isSyncingAll ? 'Syncing...' : 'Sync Now'}
          </NeumorphicButton>
        </div>
      </div>

      {/* 4 Status Rows for: Alarms, Tasks, Health, Assistant Connection */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
        {syncItems.map((item) => (
          <div
            key={item.key}
            className="p-3.5 rounded-2xl surface-base border border-[var(--color-border-subtle)] flex flex-col justify-between space-y-2 hover:border-[var(--color-border-strong)] transition-all"
          >
            <div className="flex items-start justify-between gap-2">
              <div className="flex items-center gap-2">
                <div className="p-1.5 rounded-xl surface-recessed border border-[var(--color-border-subtle)]">
                  {getSyncIcon(item.key)}
                </div>
                <div>
                  <h4 className="text-xs font-bold text-[var(--color-text-primary)]">
                    {item.name}
                  </h4>
                  <span className="text-[10px] text-[var(--color-text-muted)] font-mono">
                    Updated: {item.lastSynced}
                  </span>
                </div>
              </div>

              <Badge
                variant={
                  item.status === 'synced' || item.status === 'connected'
                    ? 'success'
                    : 'default'
                }
                size="sm"
                className="capitalize"
              >
                {item.status}
              </Badge>
            </div>

            <p className="text-xs text-[var(--color-text-secondary)] leading-relaxed pl-1">
              {item.details}
            </p>
          </div>
        ))}
      </div>

      {/* Footer info banner */}
      <div className="pt-2 flex items-center justify-between text-xs text-[var(--color-text-muted)] font-mono">
        <div className="flex items-center gap-1.5">
          <ShieldCheck className="w-3.5 h-3.5 text-emerald-500" />
          <span>Local mTLS encryption • Encrypted SQLite cache mirror</span>
        </div>
        <span>Last global sync: {lastGlobalSync}</span>
      </div>
    </Card>
  );
};
