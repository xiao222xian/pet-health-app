import { describe, it, expect, vi } from 'vitest';
import request from 'supertest';

const mocks = vi.hoisted(() => ({
  insertedPayload: null as Record<string, unknown> | null,
}));

vi.mock('../src/middleware/auth.js', () => ({
  verifyAuth: (req: any, _res: any, next: any) => {
    req.userId = 'user-123';
    next();
  },
}));

vi.mock('@supabase/supabase-js', () => ({
  createClient: vi.fn(() => ({
    from: vi.fn(() => ({
      insert: vi.fn((payload: Record<string, unknown>) => {
        mocks.insertedPayload = payload;
        return {
          select: vi.fn(() => ({
            single: vi.fn(async () => ({
              data: {
                id: 'pet-123',
                user_id: payload.user_id,
                name: payload.name,
                species: payload.species,
                gender: payload.gender,
                neutered: payload.neutered,
                created_at: '2026-06-26T10:00:00Z',
              },
              error: null,
            })),
          })),
        };
      }),
    })),
  })),
}));

const app = (await import('../src/index.js')).default;

describe('POST /api/v1/pets', () => {
  it('rejects invalid pet payloads', async () => {
    const res = await request(app)
      .post('/api/v1/pets')
      .send({ species: 'dog' });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('INVALID_INPUT');
  });

  it('creates a pet for the authenticated user', async () => {
    const res = await request(app)
      .post('/api/v1/pets')
      .send({
        user_id: 'attacker',
        name: 'Buddy',
        species: 'dog',
        gender: 'unknown',
        neutered: false,
      });

    expect(res.status).toBe(201);
    expect(res.body).toHaveProperty('id', 'pet-123');
    expect(mocks.insertedPayload).toMatchObject({
      user_id: 'user-123',
      name: 'Buddy',
      species: 'dog',
    });
  });
});
