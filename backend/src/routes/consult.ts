import { Router } from 'express';
import { createClient } from '@supabase/supabase-js';
import { z } from 'zod';
import { verifyAuth, AuthRequest } from '../middleware/auth.js';
import { consultSymptoms } from '../services/claude.js';
import { ApiError } from '../types/index.js';

export const consultRouter = Router();

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

const ConsultSchema = z.object({
  pet_id: z.string().uuid(),
  symptoms: z.string().min(3).max(1000),
  photo_urls: z.array(z.string().url()).max(3).optional(),
  photo_data: z.array(z.string()).max(3).optional(), // base64-encoded images
});

consultRouter.post('/', verifyAuth, async (req: AuthRequest, res) => {
  const parsed = ConsultSchema.safeParse(req.body);
  if (!parsed.success) {
    const body: ApiError = { error: { code: 'INVALID_INPUT', message: parsed.error.message } };
    return res.status(400).json(body);
  }

  const { pet_id, symptoms, photo_urls = [], photo_data = [] } = parsed.data;

  const { data: pet, error } = await supabase
    .from('pets')
    .select('*')
    .eq('id', pet_id)
    .eq('user_id', req.userId!)
    .single();

  if (error || !pet) {
    const body: ApiError = { error: { code: 'NOT_FOUND', message: 'Pet not found' } };
    return res.status(404).json(body);
  }

  const ageYears = pet.birth_date
    ? Math.floor((Date.now() - new Date(pet.birth_date).getTime()) / 31557600000)
    : undefined;

  try {
    const result = await consultSymptoms(
      { name: pet.name, species: pet.species, breed: pet.breed, age_years: ageYears, weight_kg: pet.weight_kg },
      symptoms,
      photo_urls,
      photo_data,
    );

    await supabase.from('consult_sessions').insert({
      pet_id,
      symptoms,
      photo_urls,
      ai_response: result,
      risk_level: result.risk_level,
    });

    return res.json(result);
  } catch {
    const body: ApiError = { error: { code: 'AI_ERROR', message: 'AI service unavailable' } };
    return res.status(503).json(body);
  }
});
