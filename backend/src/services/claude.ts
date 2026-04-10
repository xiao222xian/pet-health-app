import Anthropic from '@anthropic-ai/sdk';
import { ConsultResponse, NutritionResponse } from '../types/index.js';

const client = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY,
});

const MODEL = 'claude-sonnet-4-6';
const DISCLAIMER = '本结果仅供参考，不构成兽医诊断意见。如有紧急情况请立即就医。';

function extractJson(text: string): unknown {
  const codeBlock = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  const raw = codeBlock ? codeBlock[1] : text;
  return JSON.parse(raw.trim());
}

export async function consultSymptoms(
  petInfo: { name: string; species: string; breed?: string; age_years?: number; weight_kg?: number },
  symptoms: string,
  _photoUrls: string[] = [],
  photoData: string[] = [],
): Promise<ConsultResponse> {
  const userText = `宠物：${petInfo.name}，${petInfo.species}${petInfo.breed ? `（${petInfo.breed}）` : ''}${petInfo.age_years ? `，${petInfo.age_years}岁` : ''}${petInfo.weight_kg ? `，${petInfo.weight_kg}kg` : ''}\n\n症状：${symptoms}`;

  // Build user message content — include images if provided
  const userContent: Anthropic.MessageParam['content'] = [];
  for (const b64 of photoData) {
    userContent.push({
      type: 'image',
      source: { type: 'base64', media_type: 'image/jpeg', data: b64 },
    });
  }
  userContent.push({ type: 'text', text: userText });

  const response = await client.messages.create({
    model: MODEL,
    max_tokens: 1024,
    system: `你是一个宠物健康助理，帮助宠物主人了解症状严重程度。
严格按照以下JSON格式返回，不要有其他内容：
{
  "risk_level": "low|medium|high|emergency",
  "summary": "1-2句摘要",
  "advice": ["建议1", "建议2", "建议3"],
  "seek_vet": true或false
}
规则：用中文，给出3-5条建议，绝不做确定性诊断。`,
    messages: [{ role: 'user', content: userContent }],
  });

  const text = response.content[0].type === 'text' ? response.content[0].text : '';
  const parsed = extractJson(text) as any;
  return {
    risk_level: parsed.risk_level,
    summary: parsed.summary,
    advice: parsed.advice,
    seek_vet: parsed.seek_vet,
    disclaimer: DISCLAIMER,
  };
}

export async function getNutritionAdvice(petInfo: {
  name: string; species: string; breed?: string; age_years?: number; weight_kg?: number; neutered: boolean;
}): Promise<NutritionResponse> {
  const response = await client.messages.create({
    model: MODEL,
    max_tokens: 1024,
    messages: [{
      role: 'user',
      content: `为宠物${petInfo.name}（${petInfo.species}，${petInfo.age_years ?? '未知'}岁，${petInfo.weight_kg ?? '未知'}kg，${petInfo.neutered ? '已绝育' : '未绝育'}）提供营养建议，严格JSON格式返回：{"daily_calories":number,"protein_ratio":number,"recommendations":["string"],"foods_to_avoid":["string"]}`,
    }],
  });

  const text = response.content[0].type === 'text' ? response.content[0].text : '';
  return extractJson(text) as NutritionResponse;
}
