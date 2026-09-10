import React, { useState } from 'react';
import {
  Cpu,
  Zap,
  HardDrive,
  Thermometer,
  Activity,
  Server,
  Sparkles,
} from 'lucide-react';
import { SectionHeader } from '../ui/SectionHeader';
import { MetricCard } from '../ui/MetricCard';
import { CircularMetric } from '../ui/CircularMetric';
import { ProgressBar } from '../ui/ProgressBar';
import { Slider } from '../ui/Slider';
import { Badge } from '../ui/Badge';
import { Card } from '../ui/Card';

export const MetricsShowcase: React.FC = () => {
  const [interactiveGauge, setInteractiveGauge] = useState(68);

  return (
    <div className="space-y-10 animate-in fade-in duration-200">
      {/* Metric Cards Grid */}
      <div className="space-y-4">
        <SectionHeader
          title="Metric Cards"
          description="High-contrast telemetry cards displaying system performance, resource allocations, and trends."
          badge={<Badge variant="accent">Telemetry</Badge>}
        />

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          <MetricCard
            label="Inference Velocity"
            value="42.8"
            unit="t/s"
            icon={<Zap className="w-5 h-5" />}
            trend={{ value: 12.4, direction: 'up', label: 'vs last run' }}
            progress={{ current: 42.8, max: 60 }}
          />

          <MetricCard
            label="VRAM Allocation"
            value="8.6"
            unit="/ 16 GB"
            icon={<HardDrive className="w-5 h-5" />}
            trend={{ value: 4.2, direction: 'up', label: 'KV cache loaded' }}
            progress={{ current: 8.6, max: 16 }}
          />

          <MetricCard
            label="Host CPU Load"
            value="28"
            unit="%"
            icon={<Cpu className="w-5 h-5" />}
            trend={{ value: -3.5, direction: 'down', label: 'cooled' }}
            progress={{ current: 28, max: 100 }}
          />

          <MetricCard
            label="Core Temperature"
            value="54"
            unit="°C"
            icon={<Thermometer className="w-5 h-5" />}
            trend={{ value: 0, direction: 'neutral', label: 'stable' }}
            progress={{ current: 54, max: 95 }}
          />
        </div>
      </div>

      {/* Circular Meters */}
      <div className="space-y-4">
        <SectionHeader
          title="Circular Meters & Radial Gauges"
          description="Tactile neumorphic bezel ring combined with an SVG accent gradient arc and central metric typography."
          badge={<Badge variant="glass">Neumorphic Bezel</Badge>}
        />

        <div className="p-8 rounded-2xl surface-raised border border-[var(--color-border-subtle)] space-y-8">
          <div className="flex flex-wrap items-center justify-around gap-6">
            <CircularMetric
              value={interactiveGauge}
              label="Interactive Test Gauge"
              sublabel="Dynamic"
              size={140}
            />

            <CircularMetric
              value={54}
              label="GPU VRAM"
              sublabel="Allocated"
              size={140}
              variant="accent"
            />

            <CircularMetric
              value={92}
              label="Audio Buffer Quality"
              sublabel="Optimal"
              size={140}
              variant="success"
            />

            <CircularMetric
              value={82}
              label="Context Ceiling"
              sublabel="High"
              size={140}
              variant="warning"
            />
          </div>

          <div className="pt-6 border-t border-[var(--color-border-subtle)] max-w-md mx-auto">
            <Slider
              value={interactiveGauge}
              onChange={setInteractiveGauge}
              min={0}
              max={100}
              label="Live Test Value"
              unit="%"
            />
          </div>
        </div>
      </div>

      {/* Progress Bars */}
      <div className="space-y-4">
        <SectionHeader
          title="Progress Bars"
          description="Recessed track channels with smooth accent gradients and status color indicators."
        />

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6 p-6 rounded-2xl surface-recessed border border-[var(--color-border-subtle)]">
          <div className="space-y-4">
            <ProgressBar value={72} label="Accent Gradient Progress" size="md" />
            <ProgressBar value={94} label="Low Memory Pressure (Success)" variant="success" size="md" />
          </div>

          <div className="space-y-4">
            <ProgressBar value={84} label="High Context Usage (Warning)" variant="warning" size="md" />
            <ProgressBar value={96} label="Thermal Throttle Threshold (Danger)" variant="danger" size="md" />
          </div>
        </div>
      </div>
    </div>
  );
};
