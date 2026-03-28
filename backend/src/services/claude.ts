import Anthropic from '@anthropic-ai/sdk';
import { ConsultResponse, NutritionResponse } from '../types/index.js';

const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

const DISCLAIMER = '本结果仅供参考，不构成兽医诊断意见。如有紧急情况请立即就医。';

export async function consultSymptoms(
  petInfo: { name: string; species: string; breed?: string; age_years?: number; weight_kg?: number },
  symptoms: string,
  photoUrls: string[] = []
): Promise<ConsultResponse> {
  const systemPrompt = `你是一个宠物健康助理，帮助宠物主人了解症状严重程度。
你必须：
1. 给出风险等级：low（轻微）/medium（中等）/high（严重）/emergency（紧急）
2. 给出简短摘要（1-2句）
3. 给出3-5条具体建议
4. 指出是否需要立即就医
5. 始终用中文回答
6. 绝不做出确定性诊断

严格按照以下JSON格式返回，不要有其他内容：
{
  "risk_level": "low|medium|high|emergency",
  "summary": "string",
  "advice": ["string", "string", "string"],
  "seek_vet": boolean
}`;

  const userContent = `宠物信息：${petInfo.name}，${petInfo.species}${petInfo.breed ? `（${petInfo.breed}）` : ''}${petInfo.age_years ? `，${petInfo.age_years}岁` : ''}${petInfo.weight_kg ? `，${petInfo.weight_kg}kg` : ''}

症状描述：${symptoms}`;

  const message = await client.messages.create({
    model: 'claude-haiku-4-5-20251001',
    max_tokens: 1024,
    system: systemPrompt,
    messages: [{ role: 'user', content: userContent }],
  });

  const text = message.content[0].type === 'text' ? message.content[0].text : '';
  const parsed = JSON.parse(text);

  return {
    risk_level: parsed.risk_level,
    summary: parsed.summary,
    advice: parsed.advice,
    seek_vet: parsed.seek_vet,
    disclaimer: DISCLAIMER,
  };
}

export async function getNutritionAdvice(petInfo: {
  name: string;
  species: string;
  breed?: string;
  age_years?: number;
  weight_kg?: number;
  neutered: boolean;
}): Promise<NutritionResponse> {
  const message = await client.messages.create({
    model: 'claude-sonnet-4-6',
    max_tokens: 1024,
    messages: [{
      role: 'user',
      content: `请为以下宠物提供营养建议，用JSON格式返回：
宠物：${petInfo.name}，${petInfo.species}${petInfo.breed ? `（${petInfo.breed}）` : ''}，${petInfo.age_years ?? '未知'}岁，${petInfo.weight_kg ?? '未知'}kg，${petInfo.neutered ? '已绝育' : '未绝育'}

返回格式：
{
  "daily_calories": number,
  "protein_ratio": number (0-1),
  "recommendations": ["string"],
  "foods_to_avoid": ["string"]
}`,
    }],
  });

  const text = message.content[0].type === 'text' ? message.content[0].text : '';
  return JSON.parse(text);
}
