import React from 'react';

export interface GlassPanelProps extends React.HTMLAttributes<HTMLDivElement> {
  elevated?: boolean;
  padding?: 'none' | 'sm' | 'md' | 'lg' | 'xl';
  glow?: boolean;
}

export const GlassPanel: React.FC<GlassPanelProps> = ({
  children,
  elevated = false,
  padding = 'md',
  glow = false,
  className = '',
  ...props
}) => {
  const paddingClasses = {
    none: 'p-0',
    sm: 'p-3',
    md: 'p-5',
    lg: 'p-6 sm:p-8',
    xl: 'p-8 sm:p-10',
  }[padding];

  const glassClass = elevated ? 'glass-panel-elevated' : 'glass-panel';
  const glowClass = glow ? 'glow-accent' : '';

  return (
    <div
      className={`rounded-2xl relative text-[var(--color-text-primary)] transition-all duration-200 ${glassClass} ${glowClass} ${paddingClasses} ${className}`}
      {...props}
    >
      {children}
    </div>
  );
};
