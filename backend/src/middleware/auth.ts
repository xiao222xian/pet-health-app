import { createClient } from '@supabase/supabase-js';
import { Request, Response, NextFunction } from 'express';
import { ApiError } from '../types/index.js';

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

export interface AuthRequest extends Request {
  userId?: string;
}

export async function verifyAuth(
  req: AuthRequest,
  res: Response,
  next: NextFunction
): Promise<void> {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    const body: ApiError = { error: { code: 'UNAUTHORIZED', message: 'Missing token' } };
    res.status(401).json(body);
    return;
  }

  const token = authHeader.slice(7);
  const { data, error } = await supabase.auth.getUser(token);

  if (error || !data.user) {
    const body: ApiError = { error: { code: 'UNAUTHORIZED', message: 'Invalid token' } };
    res.status(401).json(body);
    return;
  }

  req.userId = data.user.id;
  next();
}
