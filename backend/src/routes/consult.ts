import { Router } from 'express';
import { createClient } from '@supabase/supabase-js';
import { verifyAuth, AuthRequest } from '../middleware/auth.js';
import { ApiError } from '../types/index.js';
import { consultRequestSchema, PetContext } from '../consult/contract.js';
import { runConsultAgent } from '../consult/agent.js';
import { setupSse, writeSse, writeSseError } from '../consult/stream.js';

export const consultRouter = Router();

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

consultRouter.post('/', verifyAuth, async (req: AuthRequest, res) => {
  const parsed = consultRequestSchema.safeParse(req.body);
  if (!parsed.success) {
    const body: ApiError = { error: { code: 'INVALID_INPUT', message: parsed.error.message } };
    return res.status(400).json(body);
  }

  try {
    const pet = await loadPet(parsed.data.pet_id, req.userId!);
    if (!pet) {
      const body: ApiError = { error: { code: 'NOT_FOUND', message: 'Pet not found' } };
      return res.status(404).json(body);
    }

    const result = await runConsultAgent({
      pet,
      symptoms: parsed.data.symptoms,
      photoUrls: parsed.data.photo_urls ?? [],
      photoData: parsed.data.photo_data ?? [],
      sessionId: parsed.data.session_id,
      clientMessageId: parsed.data.client_message_id,
    }, req.userId!);

    await saveConsultSession({
      pet_id: parsed.data.pet_id,
      symptoms: parsed.data.symptoms,
      photo_urls: parsed.data.photo_urls ?? [],
      ai_response: result,
      risk_level: result.risk_level === 'unknown' ? null : result.risk_level,
    });

    return res.json(result);
  } catch {
    const body: ApiError = { error: { code: 'AI_ERROR', message: 'AI service unavailable' } };
    return res.status(503).json(body);
  }
});

consultRouter.post('/stream', verifyAuth, async (req: AuthRequest, res) => {
  setupSse(res);

  const parsed = consultRequestSchema.safeParse(req.body);
  if (!parsed.success) {
    return writeSseError(res, 'INVALID_INPUT', parsed.error.message);
  }

  try {
    const pet = await loadPet(parsed.data.pet_id, req.userId!);
    if (!pet) {
      return writeSseError(res, 'NOT_FOUND', 'Pet not found');
    }

    const result = await runConsultAgent({
      pet,
      symptoms: parsed.data.symptoms,
      photoUrls: parsed.data.photo_urls ?? [],
      photoData: parsed.data.photo_data ?? [],
      sessionId: parsed.data.session_id,
      clientMessageId: parsed.data.client_message_id,
    }, req.userId!, (event) => writeSse(res, event));

    await saveConsultSession({
      pet_id: parsed.data.pet_id,
      symptoms: parsed.data.symptoms,
      photo_urls: parsed.data.photo_urls ?? [],
      ai_response: result,
      risk_level: result.risk_level === 'unknown' ? null : result.risk_level,
    });

    writeSse(res, { event: 'done', data: { ok: true, session_id: result.session_id, trace_id: result.trace_id } });
    res.end();
  } catch {
    writeSseError(res, 'AI_ERROR', 'AI service unavailable');
  }
});

async function saveConsultSession(payload: {
  pet_id: string;
  symptoms: string;
  photo_urls: string[];
  ai_response: unknown;
  risk_level: string | null;
}) {
  const { error } = await supabase.from('consult_sessions').insert(payload);
  if (error) {
    console.warn('failed to save consult session', error.message);
  }
}

async function loadPet(petId: string, userId: string): Promise<PetContext | null> {
  const { data: pet, error } = await supabase
    .from('pets')
    .select('*')
    .eq('id', petId)
    .eq('user_id', userId)
    .single();

  if (error || !pet) return null;
  const ageYears = pet.birth_date
    ? Math.floor((Date.now() - new Date(pet.birth_date).getTime()) / 31557600000)
    : undefined;

  return {
    id: pet.id,
    name: pet.name,
    species: pet.species,
    breed: pet.breed,
    age_years: ageYears,
    weight_kg: pet.weight_kg,
  };
}
