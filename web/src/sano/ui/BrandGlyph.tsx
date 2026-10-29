import React from 'react';
import { Icon } from './Icon';

/** Crisp rounded vector icons with diffuse brand light, never rasterized at small sizes. */
export const BrandGlyph: React.FC<{ name: string; className?: string }> = ({ name, className = '' }) => (
  <span aria-hidden="true" className={`brand-glyph shrink-0 ${className}`}><Icon name={name} size={24} strokeWidth={1.8} /></span>
);
