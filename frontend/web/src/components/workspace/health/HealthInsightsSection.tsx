import React from 'react';
import { Sparkles, Moon, Heart, Footprints, ShieldCheck, ArrowRight } from 'lucide-react';
import { GlassPanel } from '../../ui/GlassPanel';
import { Badge } from '../../ui/Badge';
import { HealthInsight } from '../../../types';

interface HealthInsightsSectionProps {
  insights: HealthInsight[];
}

export const HealthInsightsSection: React.FC<HealthInsightsSectionProps> = ({
  insights,
}) => {
  const getCategoryIcon = (category: string) => {
    switch (category) {
      case 'sleep':
        return <Moon className="w-4 h-4 text-indigo-400" />;
      case 'heart':
        return <Heart className="w-4 h-4 text-rose-500" />;
      case 'activity':
        return <Footprints className="w-4 h-4 text-emerald-500" />;
      default:
        return <ShieldCheck className="w-4 h-4 text-[var(--color-accent)]" />;
    }
  };

  return (
    <GlassPanel
      id="health-wellness-insights-section"
      elevated
      padding="lg"
      className="space-y-4 border border-[var(--color-border-highlight)]"
    >
      {/* Soft Glass Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-[var(--color-border-subtle)]">
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-2xl bg-accent-gradient flex items-center justify-center text-white glow-accent-sm flex-shrink-0">
            <Sparkles className="w-4.5 h-4.5" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h3 className="text-sm font-bold text-[var(--color-text-primary)]">
                Wellness Observations & Local AI Patterns
              </h3>
              <Badge variant="accent" size="sm" className="font-mono text-[10px]">
                Private Inference
              </Badge>
            </div>
            <p className="text-xs text-[var(--color-text-secondary)]">
              Descriptive lifestyle observations analyzed purely on-device without cloud telemetry transmission.
            </p>
          </div>
        </div>

        <span className="text-[11px] text-[var(--color-text-muted)] self-start sm:self-auto">
          Non-diagnostic lifestyle review
        </span>
      </div>

      {/* Observation Cards Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
        {insights.map((item) => {
          const borderStyle =
            item.type === 'attention'
              ? 'border-amber-500/25 bg-amber-500/[0.03]'
              : item.type === 'positive'
              ? 'border-emerald-500/25 bg-emerald-500/[0.03]'
              : 'border-[var(--color-border-subtle)] surface-recessed';

          return (
            <div
              key={item.id}
              className={`p-4 rounded-2xl border ${borderStyle} flex flex-col justify-between space-y-2.5 transition-all hover:border-[var(--color-border-highlight)]`}
            >
              <div className="flex items-center justify-between gap-2">
                <div className="flex items-center gap-2">
                  <div className="w-6 h-6 rounded-lg surface-raised flex items-center justify-center border border-[var(--color-border-subtle)]">
                    {getCategoryIcon(item.category)}
                  </div>
                  <span className="text-xs font-bold text-[var(--color-text-primary)]">
                    {item.title}
                  </span>
                </div>
                <span className="text-[10px] font-mono text-[var(--color-text-muted)] px-2 py-0.5 rounded-full surface-base border border-[var(--color-border-subtle)]">
                  {item.tag}
                </span>
              </div>

              <p className="text-xs text-[var(--color-text-secondary)] leading-relaxed">
                {item.observation}
              </p>

              <div className="flex items-center justify-between text-[10px] text-[var(--color-text-muted)] pt-2 border-t border-[var(--color-border-subtle)]/60">
                <span>{item.timeframe}</span>
                <span className="text-[var(--color-text-muted)] italic">Descriptive telemetry</span>
              </div>
            </div>
          );
        })}
      </div>
    </GlassPanel>
  );
};
