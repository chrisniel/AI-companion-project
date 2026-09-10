import React from 'react';

export interface SkeletonProps extends React.HTMLAttributes<HTMLDivElement> {
  variant?: 'text' | 'circular' | 'rectangular' | 'card';
  width?: string | number;
  height?: string | number;
}

export const Skeleton: React.FC<SkeletonProps> = ({
  variant = 'text',
  width,
  height,
  className = '',
  style,
  ...props
}) => {
  let shapeClass = 'rounded-md';
  let defaultHeight = 'h-4';

  switch (variant) {
    case 'circular':
      shapeClass = 'rounded-full';
      defaultHeight = 'h-10 w-10';
      break;
    case 'rectangular':
      shapeClass = 'rounded-xl';
      defaultHeight = 'h-24';
      break;
    case 'card':
      shapeClass = 'rounded-2xl';
      defaultHeight = 'h-36';
      break;
    case 'text':
      shapeClass = 'rounded-md';
      defaultHeight = 'h-3.5';
      break;
  }

  const customStyle: React.CSSProperties = {
    ...(width ? { width } : {}),
    ...(height ? { height } : {}),
    ...style,
  };

  return (
    <div
      aria-hidden="true"
      style={customStyle}
      className={`animate-pulse surface-recessed border border-[var(--color-border-subtle)] ${shapeClass} ${defaultHeight} ${className}`}
      {...props}
    />
  );
};
