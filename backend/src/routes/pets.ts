import { Router } from 'express';
import { createClient } from '@supabase/supabase-js';
import { z } from 'zod';
import { verifyAuth, AuthRequest } from '../middleware/auth.js';
import { ApiError } from '../types/index.js';

export const petsRouter = Router();

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
);

const PetCreateSchema = z.object({
  name: z.string().trim().min(1).max(80),
  species: z.enum(['dog', 'cat', 'other']),
  breed: z.string().trim().max(80).optional(),
  birth_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  weight_kg: z.number().positive().max(999.99).optional().nullable(),
  gender: z.enum(['male', 'female', 'unknown']).optional(),
  neutered: z.boolean().optional(),
  avatar_url: z.string().max(2_000_000).optional(),
});

petsRouter.post('/', verifyAuth, async (req: AuthRequest, res) => {
  const parsed = PetCreateSchema.safeParse(req.body);
  if (!parsed.success) {
    const body: ApiError = {
      error: { code: 'INVALID_INPUT', message: parsed.error.message },
    };
    return res.status(400).json(body);
  }

  const payload = {
    ...parsed.data,
    user_id: req.userId!,
    neutered: parsed.data.neutered ?? false,
  };

  const { data, error } = await supabase
    .from('pets')
    .insert(payload)
    .select()
    .single();

  if (error || !data) {
    const body: ApiError = {
      error: {
        code: 'INTERNAL_ERROR',
        message: error?.message ?? 'Failed to create pet',
      },
    };
    return res.status(500).json(body);
  }

  return res.status(201).json(data);
});
