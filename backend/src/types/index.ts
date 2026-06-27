export interface ConsultRequest {
  pet_id: string;
  symptoms: string;
  photo_urls?: string[];
}

export interface ConsultResponse {
  risk_level: 'unknown' | 'low' | 'medium' | 'high' | 'emergency';
  summary: string;
  possible_causes: string[];
  home_care: string[];
  watch_points: string[];
  when_to_seek_vet: string[];
  follow_up_question: string;
  advice: string[];
  seek_vet: boolean;
  disclaimer: string;
}

export type ConsultIntent =
  | 'greeting'
  | 'symptom_triage'
  | 'nutrition'
  | 'care_guidance'
  | 'administrative'
  | 'unsupported';

export type ConsultResponseType =
  | 'guide'
  | 'follow_up'
  | 'triage_report'
  | 'emergency_alert'
  | 'nutrition_advice'
  | 'unsupported';

export interface ConsultQuestion {
  id: string;
  text: string;
  reason: string;
}

export interface ConsultNextAction {
  priority: 'now' | 'today' | 'monitor' | 'routine';
  text: string;
}

export interface ConsultTriage {
  possible_causes: string[];
  home_care: string[];
  watch_points: string[];
  when_to_seek_vet: string[];
}

export interface ConsultEmergency {
  reason: string;
  immediate_actions: string[];
  avoid: string[];
}

export interface ConsultAgentResponse extends ConsultResponse {
  response_type: ConsultResponseType;
  intent: ConsultIntent;
  can_assess: boolean;
  title: string;
  short_answer: string;
  missing_info: string[];
  follow_up_questions: ConsultQuestion[];
  next_actions: ConsultNextAction[];
  triage?: ConsultTriage;
  emergency?: ConsultEmergency;
  session_id: string;
  trace_id: string;
  model?: string;
  provider?: string;
  state: string;
}

export interface NutritionRequest {
  pet_id: string;
}

export interface NutritionResponse {
  daily_calories: number;
  protein_ratio: number;
  recommendations: string[];
  foods_to_avoid: string[];
}

export interface ApiError {
  error: {
    code:
      | 'UNAUTHORIZED'
      | 'INVALID_INPUT'
      | 'AI_ERROR'
      | 'NOT_FOUND'
      | 'USER_EXISTS'
      | 'REGISTER_FAILED'
      | 'PET_CREATE_FAILED'
      | 'INTERNAL_ERROR';
    message: string;
  };
}
