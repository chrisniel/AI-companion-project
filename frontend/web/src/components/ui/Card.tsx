import React from 'react';

export interface CardProps extends React.HTMLAttributes<HTMLDivElement> {
  variant?: 'elevated' | 'raised' | 'recessed' | 'flat';
  hoverable?: boolean;
  padding?: 'none' | 'sm' | 'md' | 'lg' | 'xl';
}

export const Card: React.FC<CardProps> = ({
  children,
  variant = 'elevated',
  hoverable = false,
  padding = 'md',
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

  let variantClass = '';
  switch (variant) {
    case 'elevated':
      variantClass =
        'bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] shadow-soft-outer';
      break;
    case 'raised':
      variantClass = 'surface-raised';
      break;
    case 'recessed':
      variantClass = 'surface-recessed';
      break;
    case 'flat':
      variantClass =
        'bg-[var(--color-surface-primary)] border border-[var(--color-border-subtle)]';
      break;
  }

  const hoverClass = hoverable
    ? 'hover:-translate-y-1 hover:border-[var(--color-accent)]/30 hover:shadow-lg transition-all duration-200'
    : 'transition-all duration-200';

  return (
    <div
      className={`rounded-2xl relative overflow-hidden text-[var(--color-text-primary)] ${variantClass} ${paddingClasses} ${hoverClass} ${className}`}
      {...props}
    >
      {children}
    </div>
  );
};
