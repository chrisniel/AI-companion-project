import React, { useState } from 'react';
import {
  Sparkles,
  AlertCircle,
  CheckCircle2,
  Trash2,
  MoreVertical,
  Download,
  Share2,
  ExternalLink,
  Shield,
  Layers,
  FolderOpen,
} from 'lucide-react';
import { SectionHeader } from '../ui/SectionHeader';
import { Modal } from '../ui/Modal';
import { Dropdown } from '../ui/Dropdown';
import { Tooltip } from '../ui/Tooltip';
import { Badge } from '../ui/Badge';
import { StatusIndicator } from '../ui/StatusIndicator';
import { EmptyState } from '../ui/EmptyState';
import { Skeleton } from '../ui/Skeleton';
import { Button } from '../ui/Button';
import { IconButton } from '../ui/IconButton';
import { StatusType } from '../../types';

export const FeedbackShowcase: React.FC = () => {
  const [isModalOpen, setIsModalOpen] = useState(false);

  const dropdownMenuItems = [
    { id: '1', label: 'Export Model Weights', icon: <Download className="w-4 h-4" /> },
    { id: '2', label: 'Share Telemetry Snapshot', icon: <Share2 className="w-4 h-4" /> },
    { id: '3', label: 'Open Local Terminal', icon: <ExternalLink className="w-4 h-4" /> },
    { divider: true as const },
    { id: '4', label: 'Purge KV Cache', icon: <Trash2 className="w-4 h-4" />, danger: true },
  ];

  const statuses: StatusType[] = [
    'online',
    'idle',
    'busy',
    'assistant',
    'model-active',
    'offline',
    'error',
  ];

  return (
    <div className="space-y-10 animate-in fade-in duration-200">
      {/* Modal Dialog Demo */}
      <div className="space-y-4">
        <SectionHeader
          title="Frosted Glass Modal Dialog"
          description="Elevated glass panel with 20px blur, highlight border, and accessible ESC/click-outside dismissal."
          badge={<Badge variant="accent">Glass Surface</Badge>}
        />

        <div className="p-6 rounded-2xl surface-raised border border-[var(--color-border-subtle)] flex items-center justify-between gap-4">
          <div>
            <h4 className="text-sm font-semibold text-[var(--color-text-primary)]">
              Dialog Trigger Demonstration
            </h4>
            <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">
              Opens a frosted glass overlay with soft shadow and accessible focus capture.
            </p>
          </div>

          <Button
            variant="primary"
            leftIcon={<Sparkles className="w-4 h-4" />}
            onClick={() => setIsModalOpen(true)}
          >
            Launch Sample Modal
          </Button>
        </div>

        <Modal
          isOpen={isModalOpen}
          onClose={() => setIsModalOpen(false)}
          title="Local Model Configuration"
          description="Configure local compute parameters for Llama-3.1-8B-Instruct."
          footer={
            <>
              <Button variant="ghost" size="sm" onClick={() => setIsModalOpen(false)}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" onClick={() => setIsModalOpen(false)}>
                Save Changes
              </Button>
            </>
          }
        >
          <div className="space-y-4 text-xs sm:text-sm">
            <p className="typo-body text-xs sm:text-sm">
              This dialog demonstrates the frosted glass styling using <code className="px-1.5 py-0.5 rounded surface-recessed font-mono">glass-panel-elevated</code>. Notice the deep backdrop blur and crisp highlights.
            </p>

            <div className="p-3.5 rounded-xl surface-recessed border border-[var(--color-border-subtle)] flex items-center justify-between">
              <span className="font-medium text-[var(--color-text-primary)]">
                Quantization Engine
              </span>
              <Badge variant="accent">llama.cpp GGUF</Badge>
            </div>
          </div>
        </Modal>
      </div>

      {/* Badges & Status Indicators */}
      <div className="space-y-4">
        <SectionHeader
          title="Badges & Status Indicators"
          description="Subtle color-coded indicators with pulse beacons for model activity and assistant states."
        />

        <div className="p-6 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] space-y-6">
          {/* Badges */}
          <div className="space-y-2">
            <span className="typo-label">Badge Variants</span>
            <div className="flex flex-wrap items-center gap-2.5">
              <Badge variant="default">Default</Badge>
              <Badge variant="accent" dot>Accent Dot</Badge>
              <Badge variant="success" dot pulse>Success (Pulse)</Badge>
              <Badge variant="warning" dot>Warning</Badge>
              <Badge variant="danger" dot pulse>Danger (Pulse)</Badge>
              <Badge variant="glass">Frosted Glass</Badge>
              <Badge variant="neutral">Neutral Raised</Badge>
            </div>
          </div>

          {/* Status Indicators */}
          <div className="space-y-2 pt-4 border-t border-[var(--color-border-subtle)]">
            <span className="typo-label">Status Indicator Types</span>
            <div className="flex flex-wrap items-center gap-6">
              {statuses.map((s) => (
                <StatusIndicator key={s} status={s} />
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* Dropdown & Tooltip Demos */}
      <div className="space-y-4">
        <SectionHeader
          title="Floating Menus & Tooltips"
          description="Contextual overlays with soft outer shadows and glass aesthetics."
        />

        <div className="grid grid-cols-1 md:grid-cols-2 gap-5 p-6 rounded-2xl surface-raised border border-[var(--color-border-subtle)]">
          <div className="space-y-3">
            <h4 className="text-sm font-semibold text-[var(--color-text-primary)]">
              Glass Action Dropdown Menu
            </h4>
            <p className="text-xs text-[var(--color-text-secondary)]">
              Click the button below to display the floating glass action list.
            </p>
            <div className="pt-2">
              <Dropdown
                trigger={
                  <Button variant="secondary" rightIcon={<MoreVertical className="w-4 h-4" />}>
                    Model Operations
                  </Button>
                }
                items={dropdownMenuItems}
                align="left"
              />
            </div>
          </div>

          <div className="space-y-3">
            <h4 className="text-sm font-semibold text-[var(--color-text-primary)]">
              Accessible Tooltips
            </h4>
            <p className="text-xs text-[var(--color-text-secondary)]">
              Hover over or focus the micro-controls below.
            </p>
            <div className="flex items-center gap-4 pt-2">
              <Tooltip content="Secure Local Sandbox (No Cloud egress)" position="top">
                <Button variant="neumorphic" size="sm">
                  Hover for Info
                </Button>
              </Tooltip>

              <Tooltip content="Low-latency inference mode active" position="bottom">
                <Badge variant="accent">Hover Badge</Badge>
              </Tooltip>
            </div>
          </div>
        </div>
      </div>

      {/* Empty State & Skeletons */}
      <div className="space-y-4">
        <SectionHeader
          title="Empty State & Loading Skeletons"
          description="Graceful handling of unpopulated views and placeholder loading states."
        />

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <EmptyState
            icon={<FolderOpen className="w-7 h-7" />}
            title="No External Models Downloaded"
            description="The local models directory is currently empty. Connect an external GGUF directory or pull a model."
            actionLabel="Add GGUF Model"
            secondaryActionLabel="Refresh Folder"
            onAction={() => alert('Add GGUF Model trigger')}
            onSecondaryAction={() => alert('Folder refreshed')}
          />

          <div className="p-6 rounded-2xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
            <div className="flex items-center justify-between">
              <span className="typo-label">Pulsing Skeletons</span>
              <Badge variant="default" size="sm">
                Placeholder
              </Badge>
            </div>

            <div className="flex items-center gap-3">
              <Skeleton variant="circular" width={40} height={40} />
              <div className="space-y-2 flex-1">
                <Skeleton variant="text" width="60%" />
                <Skeleton variant="text" width="90%" />
              </div>
            </div>

            <Skeleton variant="card" height={90} />
          </div>
        </div>
      </div>
    </div>
  );
};
