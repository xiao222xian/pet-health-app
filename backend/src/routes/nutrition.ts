import { Router } from 'express';
import { createClient } from '@supabase/supabase-js';
import { z } from 'zod';
import { verifyAuth, AuthRequest } from '../middleware/auth.js';
import { getNutritionAdvice } from '../services/claude.js';
import { ApiError } from '../types/index.js';

export const nutritionRouter = Router();

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

const NutritionSchema = z.object({
  pet_id: z.string().uuid(),
});

nutritionRouter.post('/', verifyAuth, async (req: AuthRequest, res) => {
  const parsed = NutritionSchema.safeParse(req.body);
  if (!parsed.success) {
    const body: ApiError = { error: { code: 'INVALID_INPUT', message: parsed.error.message } };
    return res.status(400).json(body);
  }

  const { pet_id } = parsed.data;

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
    const result = await getNutritionAdvice({
      name: pet.name,
      species: pet.species,
      breed: pet.breed,
      age_years: ageYears,
      weight_kg: pet.weight_kg,
      neutered: pet.neutered,
    });
    return res.json(result);
  } catch {
    const body: ApiError = { error: { code: 'AI_ERROR', message: 'AI service unavailable' } };
    return res.status(503).json(body);
  }
});
