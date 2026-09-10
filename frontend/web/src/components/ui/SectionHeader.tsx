import React from 'react';

export interface SectionHeaderProps {
  title: string;
  description?: string;
  badge?: React.ReactNode;
  action?: React.ReactNode;
  className?: string;
}

export const SectionHeader: React.FC<SectionHeaderProps> = ({
  title,
  description,
  badge,
  action,
  className = '',
}) => {
  return (
    <div
      className={`flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-[var(--color-border-subtle)] ${className}`}
    >
      <div className="flex flex-col gap-0.5">
        <div className="flex items-center gap-2.5">
          <h2 className="typo-section-title">{title}</h2>
          {badge}
        </div>
        {description && <p className="typo-secondary text-xs sm:text-sm">{description}</p>}
      </div>

      {action && <div className="flex items-center gap-2 flex-shrink-0">{action}</div>}
    </div>
  );
};
