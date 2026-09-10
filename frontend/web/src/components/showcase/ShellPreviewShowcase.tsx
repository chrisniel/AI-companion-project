import React, { useState } from 'react';
import {
  Bot,
  Cpu,
  Zap,
  HardDrive,
  Calendar,
  Volume2,
  Mic,
  Clock,
  Sparkles,
  Sliders,
  CheckCircle2,
  Play,
  RotateCcw,
  Plus,
} from 'lucide-react';
import { SectionHeader } from '../ui/SectionHeader';
import { MetricCard } from '../ui/MetricCard';
import { CircularMetric } from '../ui/CircularMetric';
import { Card } from '../ui/Card';
import { GlassPanel } from '../ui/GlassPanel';
import { Button } from '../ui/Button';
import { NeumorphicButton } from '../ui/NeumorphicButton';
import { Badge } from '../ui/Badge';
import { Toggle } from '../ui/Toggle';
import { Slider } from '../ui/Slider';
import { StatusIndicator } from '../ui/StatusIndicator';
import {
  mockLocalModels,
  mockScheduledTasks,
  mockAudioDevices,
  mockSystemMetrics,
} from '../../mock/localAiData';

export const ShellPreviewShowcase: React.FC = () => {
  const [tasks, setTasks] = useState(mockScheduledTasks);
  const [selectedModelId, setSelectedModelId] = useState('m-1');
  const [speakerVol, setSpeakerVol] = useState(68);

  const toggleTask = (id: string) => {
    setTasks((prev) =>
      prev.map((t) => (t.id === id ? { ...t, enabled: !t.enabled } : t)),
    );
  };

  return (
    <div className="space-y-8 animate-in fade-in duration-200">
      <SectionHeader
        title="Desktop Shell Structural Prototype"
        description="Demonstrating how the Soft Glass design system components integrate into the desktop Local AI Control Center."
        badge={<Badge variant="accent">Prototype Layout</Badge>}
        action={
          <Button variant="secondary" size="sm" leftIcon={<RotateCcw className="w-3.5 h-3.5" />}>
            Reset Mock Telemetry
          </Button>
        }
      />

      {/* Primary Telemetry Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <MetricCard
          label="Inference Velocity"
          value={mockSystemMetrics.tokensPerSec}
          unit="tok/s"
          icon={<Zap className="w-5 h-5" />}
          trend={{ value: 8.4, direction: 'up', label: 'vs benchmark' }}
          progress={{ current: mockSystemMetrics.tokensPerSec, max: 60 }}
        />

        <MetricCard
          label="GPU VRAM Usage"
          value={mockSystemMetrics.vramUsedGb}
          unit={`/ ${mockSystemMetrics.vramTotalGb} GB`}
          icon={<HardDrive className="w-5 h-5" />}
          trend={{ value: 2.1, direction: 'up', label: 'KV cache loaded' }}
          progress={{ current: mockSystemMetrics.vramUsedGb, max: mockSystemMetrics.vramTotalGb }}
        />

        <MetricCard
          label="Host RAM Memory"
          value={mockSystemMetrics.ramUsedGb}
          unit={`/ ${mockSystemMetrics.ramTotalGb} GB`}
          icon={<Cpu className="w-5 h-5" />}
          trend={{ value: -1.2, direction: 'down', label: 'steady' }}
          progress={{ current: mockSystemMetrics.ramUsedGb, max: mockSystemMetrics.ramTotalGb }}
        />

        <MetricCard
          label="Core Temperature"
          value={mockSystemMetrics.temperatureC}
          unit="°C"
          icon={<Sliders className="w-5 h-5" />}
          trend={{ value: 0, direction: 'neutral', label: 'optimal cooling' }}
          progress={{ current: mockSystemMetrics.temperatureC, max: 90 }}
        />
      </div>

      {/* Main Two-Column Layout */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left 2 Cols: Models & Tasks */}
        <div className="lg:col-span-2 space-y-6">
          {/* Models Inventory Card */}
          <Card variant="raised" padding="md" className="space-y-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2.5">
                <Bot className="w-5 h-5 text-[var(--color-accent)]" />
                <h3 className="typo-section-title text-base font-bold">
                  Configurable Local Models
                </h3>
              </div>
              <Badge variant="glass">4 Local GGUFs</Badge>
            </div>

            <div className="space-y-2.5">
              {mockLocalModels.map((model) => {
                const isSelected = model.id === selectedModelId;
                return (
                  <div
                    key={model.id}
                    onClick={() => setSelectedModelId(model.id)}
                    className={`p-3.5 rounded-xl transition-all duration-150 cursor-pointer flex flex-col sm:flex-row sm:items-center justify-between gap-3 ${
                      isSelected
                        ? 'surface-raised ring-2 ring-[var(--color-accent)] glow-accent-sm'
                        : 'surface-recessed hover:border-[var(--color-accent)]/30'
                    }`}
                  >
                    <div className="flex items-start sm:items-center gap-3">
                      <div className="w-8 h-8 rounded-lg surface-raised flex items-center justify-center text-[var(--color-accent)] flex-shrink-0">
                        <Cpu className="w-4 h-4" />
                      </div>
                      <div>
                        <div className="flex items-center gap-2">
                          <span className="text-sm font-bold text-[var(--color-text-primary)]">
                            {model.name}
                          </span>
                          <span className="text-[10px] font-mono px-1.5 py-0.5 rounded surface-raised text-[var(--color-text-secondary)]">
                            {model.quantization}
                          </span>
                        </div>
                        <span className="text-xs text-[var(--color-text-secondary)]">
                          {model.family} • {model.sizeGb} GB • {model.contextWindow / 1024}k context
                        </span>
                      </div>
                    </div>

                    <div className="flex items-center gap-2 self-end sm:self-auto">
                      {isSelected ? (
                        <Badge variant="accent" size="sm" dot pulse>
                          Loaded in VRAM
                        </Badge>
                      ) : (
                        <NeumorphicButton size="sm">
                          Load Model
                        </NeumorphicButton>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          </Card>

          {/* Schedules & Alarms */}
          <Card variant="raised" padding="md" className="space-y-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2.5">
                <Calendar className="w-5 h-5 text-[var(--color-accent)]" />
                <h3 className="typo-section-title text-base font-bold">
                  Schedules, Alarms & Automation
                </h3>
              </div>
              <Button variant="ghost" size="sm" leftIcon={<Plus className="w-3.5 h-3.5" />}>
                New Routine
              </Button>
            </div>

            <div className="space-y-3">
              {tasks.map((task) => (
                <div
                  key={task.id}
                  className="p-3.5 rounded-xl surface-recessed border border-[var(--color-border-subtle)] flex items-center justify-between gap-3"
                >
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 rounded-lg surface-raised flex items-center justify-center text-[var(--color-accent-secondary)] flex-shrink-0">
                      <Clock className="w-4 h-4" />
                    </div>
                    <div>
                      <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                        {task.title}
                      </span>
                      <span className="text-xs text-[var(--color-text-secondary)]">
                        {task.time} • {task.frequency}
                      </span>
                    </div>
                  </div>

                  <Toggle
                    checked={task.enabled}
                    onChange={() => toggleTask(task.id)}
                  />
                </div>
              ))}
            </div>
          </Card>
        </div>

        {/* Right 1 Col: Circular Gauges & Audio Management */}
        <div className="space-y-6">
          {/* Radial Hardware Monitor */}
          <Card variant="raised" padding="md" className="flex flex-col items-center text-center space-y-4">
            <h3 className="typo-section-title text-base font-bold">
              Compute Load Balancer
            </h3>

            <CircularMetric
              value={54}
              label="Hardware Ingestion Efficiency"
              sublabel="Optimal"
              size={150}
            />

            <div className="w-full pt-3 border-t border-[var(--color-border-subtle)] flex items-center justify-between text-xs text-[var(--color-text-secondary)]">
              <span>CUDA Cores: Active</span>
              <StatusIndicator status="online" size="sm" label="VRAM Warm" />
            </div>
          </Card>

          {/* Audio & Device Control */}
          <Card variant="raised" padding="md" className="space-y-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Volume2 className="w-4 h-4 text-[var(--color-accent)]" />
                <h3 className="typo-section-title text-sm font-bold">Audio Monitoring</h3>
              </div>
              <Badge variant="glass" size="sm">
                48 kHz
              </Badge>
            </div>

            <Slider
              value={speakerVol}
              onChange={setSpeakerVol}
              min={0}
              max={100}
              label="Spatial Output Level"
              unit="%"
            />

            <div className="flex items-center justify-between text-xs pt-2 border-t border-[var(--color-border-subtle)]">
              <span className="text-[var(--color-text-muted)]">Active Device:</span>
              <span className="font-semibold text-[var(--color-text-primary)]">
                Studio Mic Array (USB-C)
              </span>
            </div>
          </Card>
        </div>
      </div>
    </div>
  );
};
