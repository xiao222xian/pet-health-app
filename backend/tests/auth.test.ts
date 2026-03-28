import { describe, it, expect, vi } from 'vitest';
import { Request, Response, NextFunction } from 'express';

vi.mock('@supabase/supabase-js', () => ({
  createClient: vi.fn(() => ({
    auth: {
      getUser: vi.fn(async (token: string) => {
        if (token === 'valid-token') {
          return { data: { user: { id: 'user-123' } }, error: null };
        }
        return { data: { user: null }, error: { message: 'Invalid token' } };
      }),
    },
  })),
}));

const { verifyAuth } = await import('../src/middleware/auth.js');

describe('verifyAuth middleware', () => {
  it('rejects requests without Authorization header', async () => {
    const req = { headers: {} } as Request;
    const res = {
      status: vi.fn().mockReturnThis(),
      json: vi.fn(),
    } as unknown as Response;
    const next = vi.fn() as NextFunction;

    await verifyAuth(req, res, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(next).not.toHaveBeenCalled();
  });

  it('rejects invalid tokens', async () => {
    const req = { headers: { authorization: 'Bearer invalid-token' } } as Request;
    const res = {
      status: vi.fn().mockReturnThis(),
      json: vi.fn(),
    } as unknown as Response;
    const next = vi.fn() as NextFunction;

    await verifyAuth(req, res, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(next).not.toHaveBeenCalled();
  });

  it('calls next() and sets req.userId for valid tokens', async () => {
    const req = {
      headers: { authorization: 'Bearer valid-token' },
    } as Request;
    const res = {} as Response;
    const next = vi.fn() as NextFunction;

    await verifyAuth(req, res, next);

    expect(next).toHaveBeenCalled();
    expect((req as any).userId).toBe('user-123');
  });
});
