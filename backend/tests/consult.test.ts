import { describe, it, expect, vi } from 'vitest';
import request from 'supertest';

const mocks = vi.hoisted(() => ({
  insertError: null as null | { message: string },
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
      insert: vi.fn(() => ({ error: mocks.insertError })),
    })),
  })),
}));

const app = (await import('../src/index.js')).default;

describe('POST /api/v1/consult', () => {
  it('returns an SSE error for invalid stream input', async () => {
    const res = await request(app)
      .post('/api/v1/consult/stream')
      .send({ symptoms: 'hi' });
    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toContain('text/event-stream');
    expect(res.text).toContain('event: error');
    expect(res.text).toContain('INVALID_INPUT');
  });

  it('returns 400 for missing symptoms', async () => {
    const res = await request(app)
      .post('/api/v1/consult')
      .send({ pet_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11' });
    expect(res.status).toBe(400);
  });

  it('does not generate a medical card for greeting-only input', async () => {
    const res = await request(app)
      .post('/api/v1/consult')
      .send({ pet_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', symptoms: 'hi' });
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('response_type', 'guide');
    expect(res.body).toHaveProperty('can_assess', false);
    expect(res.body).toHaveProperty('risk_level', 'unknown');
    expect(res.body.follow_up_questions[0].text).toContain('描述');
    expect(res.body.possible_causes).toEqual([]);
  });

  it('asks follow-up questions for vague symptoms', async () => {
    const res = await request(app)
      .post('/api/v1/consult')
      .send({ pet_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', symptoms: '狗狗吐了' });
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('response_type', 'follow_up');
    expect(res.body).toHaveProperty('can_assess', false);
    expect(res.body.missing_info.length).toBeGreaterThan(0);
    expect(res.body.follow_up_questions.length).toBeGreaterThan(0);
  });

  it('still returns the consult response when history persistence fails', async () => {
    mocks.insertError = { message: 'db write failed' };
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => {});
    const res = await request(app)
      .post('/api/v1/consult')
      .send({ pet_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', symptoms: 'hi' });
    mocks.insertError = null;
    warn.mockRestore();

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('response_type', 'guide');
  });

  it('falls back to conservative rule triage when LLM providers are unavailable', async () => {
    const previous = {
      flu: process.env.FLU_API_KEY,
      gemini: process.env.GEMINI_API_KEY,
      openrouter: process.env.OPENROUTER_API_KEY,
      groq: process.env.GROQ_API_KEY,
    };
    delete process.env.FLU_API_KEY;
    delete process.env.GEMINI_API_KEY;
    delete process.env.OPENROUTER_API_KEY;
    delete process.env.GROQ_API_KEY;

    const res = await request(app)
      .post('/api/v1/consult')
      .send({
        pet_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        symptoms: '狗狗今天早上开始呕吐，已经吐了3次，精神比平时差，不太想吃饭，但还能喝一点水。',
      });

    restoreEnv('FLU_API_KEY', previous.flu);
    restoreEnv('GEMINI_API_KEY', previous.gemini);
    restoreEnv('OPENROUTER_API_KEY', previous.openrouter);
    restoreEnv('GROQ_API_KEY', previous.groq);

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('response_type', 'triage_report');
    expect(res.body).toHaveProperty('provider', 'rules');
    expect(res.body.home_care.length).toBeGreaterThan(0);
  });

  it('returns emergency alert before calling an LLM', async () => {
    const res = await request(app)
      .post('/api/v1/consult')
      .send({ pet_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', symptoms: '狗狗刚刚误食老鼠药，怎么办' });
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('response_type', 'emergency_alert');
    expect(res.body).toHaveProperty('risk_level', 'emergency');
    expect(res.body.seek_vet).toBe(true);
    expect(res.body.emergency.immediate_actions[0]).toContain('宠物医院');
  });

  it('streams state and result events', async () => {
    const res = await request(app)
      .post('/api/v1/consult/stream')
      .send({ pet_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', symptoms: '你好' });
    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toContain('text/event-stream');
    expect(res.text).toContain('event: state');
    expect(res.text).toContain('event: result');
    expect(res.text).toContain('"response_type":"guide"');
  });
});

function restoreEnv(key: string, value: string | undefined) {
  if (value === undefined) {
    delete process.env[key];
  } else {
    process.env[key] = value;
  }
}
