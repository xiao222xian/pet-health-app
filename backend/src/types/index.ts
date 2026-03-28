export interface ConsultRequest {
  pet_id: string;
  symptoms: string;
  photo_urls?: string[];
}

export interface ConsultResponse {
  risk_level: 'low' | 'medium' | 'high' | 'emergency';
  summary: string;
  advice: string[];
  seek_vet: boolean;
  disclaimer: string;
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
    code: 'UNAUTHORIZED' | 'INVALID_INPUT' | 'AI_ERROR' | 'NOT_FOUND' | 'INTERNAL_ERROR';
    message: string;
  };
}
