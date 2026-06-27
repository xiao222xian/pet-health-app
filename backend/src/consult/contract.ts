import { z } from 'zod';
import { randomUUID } from 'crypto';
import {
  ConsultAgentResponse,
  ConsultIntent,
  ConsultNextAction,
  ConsultQuestion,
  ConsultResponseType,
} from '../types/index.js';

export const CONSULT_DISCLAIMER = '本结果仅供参考，不构成兽医诊断意见。如有紧急情况请立即就医。';

export const consultRequestSchema = z.object({
  pet_id: z.string().uuid(),
  symptoms: z.string().min(1).max(5000),
  photo_urls: z.array(z.string().url()).max(3).optional(),
  photo_data: z.array(z.string()).max(3).optional(),
  session_id: z.string().uuid().optional(),
  client_message_id: z.string().max(120).optional(),
});

export interface PetContext {
  id: string;
  name: string;
  species: string;
  breed?: string;
  age_years?: number;
  weight_kg?: number;
}

export interface ConsultInput {
  pet: PetContext;
  symptoms: string;
  photoUrls: string[];
  photoData: string[];
  sessionId?: string;
  clientMessageId?: string;
}

export interface ConsultEvent {
  event: 'trace' | 'state' | 'token' | 'result' | 'error' | 'done';
  data: Record<string, unknown>;
}

export interface ConsultDecision {
  intent: ConsultIntent;
  responseType: ConsultResponseType;
  canAssess: boolean;
  reason: string;
  missingInfo: string[];
  followUpQuestions: ConsultQuestion[];
  nextActions: ConsultNextAction[];
}

export function createTraceId() {
  return `tr_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 10)}`;
}

export function createSessionId() {
  return randomUUID();
}

export function buildBaseResponse(params: {
  responseType: ConsultResponseType;
  intent: ConsultIntent;
  canAssess: boolean;
  title: string;
  shortAnswer: string;
  riskLevel?: ConsultAgentResponse['risk_level'];
  summary?: string;
  missingInfo?: string[];
  followUpQuestions?: ConsultQuestion[];
  nextActions?: ConsultNextAction[];
  sessionId: string;
  traceId: string;
  state: string;
}): ConsultAgentResponse {
  return {
    response_type: params.responseType,
    intent: params.intent,
    can_assess: params.canAssess,
    risk_level: params.riskLevel ?? 'unknown',
    title: params.title,
    short_answer: params.shortAnswer,
    summary: params.summary ?? params.shortAnswer,
    possible_causes: [],
    home_care: [],
    watch_points: [],
    when_to_seek_vet: [],
    follow_up_question: params.followUpQuestions?.[0]?.text ?? '',
    missing_info: params.missingInfo ?? [],
    follow_up_questions: params.followUpQuestions ?? [],
    next_actions: params.nextActions ?? [],
    advice: params.nextActions?.map((item) => item.text) ?? [],
    seek_vet: false,
    disclaimer: CONSULT_DISCLAIMER,
    session_id: params.sessionId,
    trace_id: params.traceId,
    state: params.state,
  };
}
