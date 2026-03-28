import { describe, it, expect, vi } from 'vitest';
import request from 'supertest';

vi.mock('../src/middleware/auth.js', () => ({
  verifyAuth: (req: any, _res: any, next: any) => {
    req.userId = 'user-123';
    next();
  },
}));

vi.mock('../src/services/claude.js', () => ({
  consultSymptoms: vi.fn(async () => ({
    risk_level: 'low',
    summary: '症状轻微，建议观察',
    advice: ['多喝水', '注意休息', '监测体温'],
    seek_vet: false,
    disclaimer: '仅供参考',
  })),
}));

vi.mock('@supabase/supabase-js', () => ({
  createClient: vi.fn(() => ({
    from: vi.fn(() => ({
      select: vi.fn(() => ({
        eq: vi.fn(() => ({
          eq: vi.fn(() => ({
            single: vi.fn(async () => ({
              data: { id: 'pet-123', name: 'Buddy', species: 'dog', user_id: 'user-123' },
              error: null,
            })),
          })),
        })),
      })),
      insert: vi.fn(() => ({ error: null })),
    })),
  })),
}));

const app = (await import('../src/index.js')).default;

describe('POST /api/v1/consult', () => {
  it('returns 400 for missing symptoms', async () => {
    const res = await request(app)
      .post('/api/v1/consult')
      .send({ pet_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11' });
    expect(res.status).toBe(400);
  });

  it('returns consult response for valid input', async () => {
    const res = await request(app)
      .post('/api/v1/consult')
      .send({ pet_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', symptoms: '食欲不振，精神萎靡' });
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('risk_level', 'low');
    expect(res.body).toHaveProperty('disclaimer');
  });
});
