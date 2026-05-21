import { describe, expect, it } from 'vitest';

import { intentRouter } from './intent';

describe('intentRouter', () => {
  it('deve expor o endpoint /api/intent', () => {
    const paths = intentRouter.stack.map((layer: any) => layer.route?.path).filter(Boolean);
    expect(paths).toContain('/api/intent');
  });
});
