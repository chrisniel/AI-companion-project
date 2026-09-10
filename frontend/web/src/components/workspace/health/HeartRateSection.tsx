import React, { useState } from 'react';
import { Heart, Activity, TrendingDown, ArrowUp, ArrowDown } from 'lucide-react';
import { Card } from '../../ui/Card';
import { HeartRateMetric, HealthTimeRange } from '../../../types';

interface HeartRateSectionProps {
  data: HeartRateMetric;
  timeRange: HealthTimeRange;
}

export const HeartRateSection: React.FC<HeartRateSectionProps> = ({
  data,
  timeRange,
}) => {
  const [hoveredPoint, setHoveredPoint] = useState<{
    time: string;
    bpm: number;
    restingBaseline?: number;
  } | null>(null);
  const [selectedPoint, setSelectedPoint] = useState<{
    time: string;
    bpm: number;
    restingBaseline?: number;
  } | null>(null);

  const activePoint = hoveredPoint || selectedPoint;

  // SVG Chart Geometry
  const width = 640;
  const height = 180;
  const paddingX = 40;
  const paddingY = 25;

  const chartWidth = width - paddingX * 2;
  const chartHeight = height - paddingY * 2;

  // Scale calculations
  const minVal = Math.min(...data.trend.map((p) => p.bpm), data.minBpm, 50);
  const maxVal = Math.max(...data.trend.map((p) => p.bpm), data.maxBpm, 125);
  const valRange = maxVal - minVal || 1;

  const points = data.trend.map((point, index) => {
    const x = paddingX + (index / (data.trend.length - 1)) * chartWidth;
    const y = paddingY + chartHeight - ((point.bpm - minVal) / valRange) * chartHeight;
    return { ...point, x, y };
  });

  // SVG path generation
  const pathD = points.reduce((acc, curr, idx, arr) => {
    if (idx === 0) return `M ${curr.x} ${curr.y}`;
    const prev = arr[idx - 1];
    // Smooth bezier control points
    const cp1x = prev.x + (curr.x - prev.x) / 2;
    const cp1y = prev.y;
    const cp2x = prev.x + (curr.x - prev.x) / 2;
    const cp2y = curr.y;
    return `${acc} C ${cp1x} ${cp1y}, ${cp2x} ${cp2y}, ${curr.x} ${curr.y}`;
  }, '');

  // Gradient area path
  const areaD = `${pathD} L ${points[points.length - 1].x} ${height - paddingY} L ${points[0].x} ${height - paddingY} Z`;

  // Resting baseline line Y position
  const restingY = paddingY + chartHeight - ((data.restingAvgBpm - minVal) / valRange) * chartHeight;

  return (
    <Card
      id="health-heart-rate-card"
      variant="elevated"
      padding="md"
      className="space-y-4"
    >
      {/* Section Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 pb-3 border-b border-[var(--color-border-subtle)]">
        <div className="flex items-center gap-2.5">
          <div className="w-8 h-8 rounded-xl surface-raised flex items-center justify-center text-rose-500 border border-[var(--color-border-subtle)] shadow-xs flex-shrink-0">
            <Heart className="w-4 h-4 fill-rose-500/20" />
          </div>
          <div>
            <h3 className="text-sm font-bold text-[var(--color-text-primary)]">
              Heart Rate
            </h3>
            <p className="text-[11px] text-[var(--color-text-muted)]">
              Optical PPG wrist telemetry • Continuous sampling
            </p>
          </div>
        </div>

        <div className="flex items-center gap-3 text-xs text-[var(--color-text-secondary)]">
          <div className="flex items-center gap-1.5">
            <span className="w-2.5 h-0.5 bg-[var(--color-accent)] rounded-full" />
            <span className="text-[11px]">Trend Curve</span>
          </div>
          <div className="flex items-center gap-1.5">
            <span className="w-2.5 h-0.5 border-b border-dashed border-[var(--color-text-muted)]" />
            <span className="text-[11px]">Resting Avg ({data.restingAvgBpm} bpm)</span>
          </div>
        </div>
      </div>

      {/* Triad Metric Summary: Latest Value | Resting Average | Daily Range */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
        {/* Latest Value */}
        <div className="p-3.5 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] flex flex-col justify-between">
          <span className="text-[11px] font-medium text-[var(--color-text-muted)] uppercase tracking-wider">
            Latest Value
          </span>
          <div className="flex items-baseline gap-1.5 my-1">
            <span className="text-2xl font-bold font-mono text-[var(--color-text-primary)]">
              {data.currentBpm}
            </span>
            <span className="text-xs font-semibold text-[var(--color-text-secondary)]">bpm</span>
          </div>
          <div className="flex items-center justify-between text-[10px] text-[var(--color-text-muted)]">
            <span>Recorded {data.timestamp}</span>
            <span className="inline-flex items-center gap-1 text-emerald-500 font-medium">
              <Activity className="w-3 h-3" /> Nominal
            </span>
          </div>
        </div>

        {/* Resting Average */}
        <div className="p-3.5 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] flex flex-col justify-between">
          <span className="text-[11px] font-medium text-[var(--color-text-muted)] uppercase tracking-wider">
            Resting Average
          </span>
          <div className="flex items-baseline gap-1.5 my-1">
            <span className="text-2xl font-bold font-mono text-[var(--color-accent)]">
              {data.restingAvgBpm}
            </span>
            <span className="text-xs font-semibold text-[var(--color-text-secondary)]">bpm</span>
          </div>
          <div className="flex items-center justify-between text-[10px] text-[var(--color-text-muted)]">
            <span>Calculated sedentary window</span>
            <span className="inline-flex items-center gap-0.5 text-[var(--color-accent)] font-mono">
              <TrendingDown className="w-3 h-3" /> -1 vs 14d
            </span>
          </div>
        </div>

        {/* Daily Range */}
        <div className="p-3.5 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] flex flex-col justify-between">
          <span className="text-[11px] font-medium text-[var(--color-text-muted)] uppercase tracking-wider">
            {timeRange === 'today' ? 'Daily Range' : 'Observed Range'}
          </span>
          <div className="flex items-baseline gap-2 my-1">
            <div className="flex items-center text-emerald-500 font-mono font-bold text-lg">
              <ArrowDown className="w-3.5 h-3.5 mr-0.5" />
              {data.minBpm}
            </div>
            <span className="text-xs text-[var(--color-text-muted)]">–</span>
            <div className="flex items-center text-amber-500 font-mono font-bold text-lg">
              <ArrowUp className="w-3.5 h-3.5 mr-0.5" />
              {data.maxBpm}
            </div>
            <span className="text-xs font-semibold text-[var(--color-text-secondary)]">bpm</span>
          </div>
          <div className="flex items-center justify-between text-[10px] text-[var(--color-text-muted)]">
            <span>Min (Nocturnal)</span>
            <span>Max (Active Peak)</span>
          </div>
        </div>
      </div>

      {/* Trend Graph (Calm SVG Spline Area) */}
      <div className="p-3 sm:p-3.5 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] space-y-2">
        <div className="flex items-center justify-between text-xs px-1.5 mt-1.5 pt-0.5 min-h-[32px]">
          <span className="text-[11px] font-semibold text-[var(--color-text-secondary)]">
            {timeRange === 'today' ? '24-Hour Heart Rate Profile' : timeRange === 'week' ? '7-Day Rolling Trend' : '30-Day Window Baseline'}
          </span>
          <div className="flex items-baseline gap-1.5 font-mono px-2.5 py-0.5 rounded-lg surface-base border border-[var(--color-border-subtle)] shadow-xs">
            <span className="text-xs text-[var(--color-text-muted)] font-medium">
              {activePoint ? activePoint.time : 'Latest'}:
            </span>
            <span className="text-sm sm:text-base font-bold text-[var(--color-accent)]">
              {activePoint ? activePoint.bpm : data.currentBpm}
            </span>
            <span className="text-xs font-semibold text-[var(--color-text-secondary)]">
              bpm
            </span>
          </div>
        </div>

        <div className="w-full overflow-x-auto">
          <svg
            viewBox={`0 0 ${width} ${height}`}
            className="w-full h-40 select-none overflow-visible"
          >
            <defs>
              <linearGradient id="hrAreaGradient" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="var(--color-accent)" stopOpacity="0.22" />
                <stop offset="100%" stopColor="var(--color-accent)" stopOpacity="0.01" />
              </linearGradient>
            </defs>

            {/* Subtle Grid Lines */}
            <line
              x1={paddingX}
              y1={paddingY}
              x2={width - paddingX}
              y2={paddingY}
              stroke="var(--color-border-subtle)"
              strokeDasharray="3 3"
              strokeOpacity="0.5"
            />
            <line
              x1={paddingX}
              y1={height - paddingY}
              x2={width - paddingX}
              y2={height - paddingY}
              stroke="var(--color-border-subtle)"
              strokeOpacity="0.8"
            />

            {/* Resting Average Reference Line */}
            <line
              x1={paddingX}
              y1={restingY}
              x2={width - paddingX}
              y2={restingY}
              stroke="var(--color-text-muted)"
              strokeDasharray="4 4"
              strokeWidth="1.2"
              strokeOpacity="0.6"
            />
            <text
              x={width - paddingX + 5}
              y={restingY + 3}
              fill="var(--color-text-muted)"
              fontSize="9"
              fontFamily="monospace"
            >
              {data.restingAvgBpm}
            </text>

            {/* Area Fill */}
            <path d={areaD} fill="url(#hrAreaGradient)" />

            {/* Spline Curve */}
            <path
              d={pathD}
              fill="none"
              stroke="var(--color-accent)"
              strokeWidth="2.5"
              strokeLinecap="round"
              strokeLinejoin="round"
            />

            {/* Interactive Data Points */}
            {points.map((p, idx) => {
              const isSelected = activePoint?.time === p.time;
              return (
                <g
                  key={idx}
                  className="cursor-pointer group"
                  onClick={() => setSelectedPoint(selectedPoint?.time === p.time ? null : p)}
                  onMouseEnter={() => setHoveredPoint(p)}
                  onMouseLeave={() => setHoveredPoint(null)}
                >
                  {isSelected && (
                    <circle
                      cx={p.x}
                      cy={p.y}
                      r="7"
                      className="fill-none stroke-[var(--color-accent)] stroke-[1.5] opacity-50"
                    />
                  )}
                  <circle
                    cx={p.x}
                    cy={p.y}
                    r={isSelected ? 4.5 : 3.5}
                    className={`stroke-[var(--color-accent)] stroke-[2] transition-all ${
                      isSelected
                        ? 'fill-[var(--color-accent)]'
                        : 'fill-[var(--color-surface-elevated)] group-hover:scale-125'
                    }`}
                  />
                  {/* Time label on X-axis */}
                  {(idx % 2 === 0 || idx === points.length - 1) && (
                    <text
                      x={p.x}
                      y={height - 8}
                      textAnchor="middle"
                      fill={isSelected ? 'var(--color-accent)' : 'var(--color-text-muted)'}
                      fontSize="9"
                      fontFamily="monospace"
                      fontWeight={isSelected ? 'bold' : 'normal'}
                    >
                      {p.time}
                    </text>
                  )}
                </g>
              );
            })}
          </svg>
        </div>
      </div>
    </Card>
  );
};
