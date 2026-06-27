import { Router } from 'express';
import { createClient } from '@supabase/supabase-js';
import { z } from 'zod';
import { ApiError } from '../types/index.js';

export const authRouter = Router();

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
  { auth: { autoRefreshToken: false, persistSession: false } },
);

const RegisterSchema = z.object({
  email: z.string().email(),
  password: z.string().min(6).max(72),
});

authRouter.post('/register', async (req, res) => {
  const parsed = RegisterSchema.safeParse(req.body);
  if (!parsed.success) {
    const body: ApiError = {
      error: { code: 'INVALID_INPUT', message: parsed.error.message },
    };
    return res.status(400).json(body);
  }

  const { email, password } = parsed.data;
  const { data, error } = await supabase.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
  });

  if (error) {
    const message = error.message.toLowerCase();
    const body: ApiError = {
      error: {
        code: message.includes('already') || message.includes('registered')
          ? 'USER_EXISTS'
          : 'REGISTER_FAILED',
        message: error.message,
      },
    };
    return res.status(body.error.code === 'USER_EXISTS' ? 409 : 500).json(body);
  }

  return res.status(201).json({ user_id: data.user?.id });
});
