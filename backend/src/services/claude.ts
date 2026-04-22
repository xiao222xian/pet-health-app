import OpenAI from 'openai';
import { ConsultResponse, NutritionResponse } from '../types/index.js';

const openRouterClient = new OpenAI({
  apiKey: process.env.OPENROUTER_API_KEY,
  baseURL: 'https://openrouter.ai/api/v1',
});

const groqClient = new OpenAI({
  apiKey: process.env.GROQ_API_KEY,
  baseURL: 'https://api.groq.com/openai/v1',
});

const OPENROUTER_MODEL = process.env.OPENROUTER_MODEL ?? 'openrouter/auto';
const GROQ_MODEL = process.env.GROQ_MODEL ?? 'llama-3.1-8b-instant';
const GEMINI_MODEL = process.env.GEMINI_MODEL ?? 'gemini-flash-latest';
const DISCLAIMER = '本结果仅供参考，不构成兽医诊断意见。如有紧急情况请立即就医。';

function extractJson(text: string): unknown {
  const codeBlock = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  const raw = codeBlock ? codeBlock[1] : text;
  return JSON.parse(raw.trim());
}

function buildPetSummary(petInfo: {
  name: string;
  species: string;
  breed?: string;
  age_years?: number;
  weight_kg?: number;
}) {
  return `宠物：${petInfo.name}，${petInfo.species}${petInfo.breed ? `（${petInfo.breed}）` : ''}${petInfo.age_years ? `，${petInfo.age_years}岁` : ''}${petInfo.weight_kg ? `，${petInfo.weight_kg}kg` : ''}`;
}

async function callGemini(textPrompt: string, systemPrompt: string, photoData: string[] = []) {
  if (!process.env.GEMINI_API_KEY) {
    throw new Error('Missing GEMINI_API_KEY');
  }

  const parts: Array<Record<string, unknown>> = [
    { text: `${systemPrompt}\n\n${textPrompt}` },
  ];

  for (const b64 of photoData) {
    parts.push({
      inline_data: {
        mime_type: 'image/jpeg',
        data: b64,
      },
    });
  }

  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-goog-api-key': process.env.GEMINI_API_KEY,
      },
      body: JSON.stringify({
        contents: [{ parts }],
        generationConfig: {
          temperature: 0.3,
          maxOutputTokens: 900,
        },
      }),
    },
  );

  if (!response.ok) {
    throw new Error(`Gemini API error ${response.status}: ${await response.text()}`);
  }

  const data = await response.json() as {
    candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>
  };
  const text = data.candidates?.[0]?.content?.parts
    ?.map((part) => part.text ?? '')
    .join('')
    .trim();

  if (!text) {
    throw new Error('Gemini returned empty content');
  }

  return text;
}

export async function consultSymptoms(
  petInfo: { name: string; species: string; breed?: string; age_years?: number; weight_kg?: number },
  symptoms: string,
  _photoUrls: string[] = [],
  photoData: string[] = [],
): Promise<ConsultResponse> {
  const multimodalContent: OpenAI.Chat.Completions.ChatCompletionContentPart[] = [
    {
      type: 'text',
      text: `${buildPetSummary(petInfo)}\n\n症状：${symptoms}`,
    },
  ];

  for (const b64 of photoData) {
    multimodalContent.push({
      type: 'image_url',
      image_url: {
        url: `data:image/jpeg;base64,${b64}`,
      },
    });
  }

  const systemPrompt = `你是一个宠物健康助理，帮助宠物主人了解症状严重程度。
严格按照以下JSON格式返回，不要有其他内容：
{
  "risk_level": "low|medium|high|emergency",
  "summary": "1-2句摘要",
  "advice": ["建议1", "建议2", "建议3"],
  "seek_vet": true
}
规则：
1. 用中文。
2. 给出3-5条具体建议。
3. 绝不做确定性诊断。
4. 只有在确有紧急风险时才把 risk_level 设为 emergency 或 high。`;

  let text = '';
  try {
    const response = await openRouterClient.chat.completions.create({
      model: OPENROUTER_MODEL,
      temperature: 0.3,
      max_tokens: 900,
      messages: [
        {
          role: 'system',
          content: systemPrompt,
        },
        {
          role: 'user',
          content: multimodalContent,
        },
      ],
    });
    text = response.choices[0]?.message?.content ?? '';
  } catch (error) {
    try {
      if (!process.env.GROQ_API_KEY) {
        throw error;
      }
      const textOnlyPrompt = `${buildPetSummary(petInfo)}\n\n症状：${symptoms}${photoData.length > 0 ? '\n\n补充：用户还上传了宠物照片，但当前后备模型只按文字信息分析。' : ''}`;
      const fallbackResponse = await groqClient.chat.completions.create({
        model: GROQ_MODEL,
        temperature: 0.3,
        max_tokens: 900,
        messages: [
          {
            role: 'system',
            content: systemPrompt,
          },
          {
            role: 'user',
            content: textOnlyPrompt,
          },
        ],
      });
      text = fallbackResponse.choices[0]?.message?.content ?? '';
    } catch {
      const geminiPrompt = `${buildPetSummary(petInfo)}\n\n症状：${symptoms}\n\n请按要求严格输出 JSON。`;
      text = await callGemini(geminiPrompt, systemPrompt, photoData);
    }
  }

  const parsed = extractJson(text) as any;
  return {
    risk_level: parsed.risk_level,
    summary: parsed.summary,
    advice: Array.isArray(parsed.advice) ? parsed.advice : [],
    seek_vet: Boolean(parsed.seek_vet),
    disclaimer: DISCLAIMER,
  };
}

export async function getNutritionAdvice(petInfo: {
  name: string; species: string; breed?: string; age_years?: number; weight_kg?: number; neutered: boolean;
}): Promise<NutritionResponse> {
  const messages: OpenAI.Chat.Completions.ChatCompletionMessageParam[] = [{
    role: 'system',
    content: '你是宠物营养顾问。严格返回 JSON，不要有任何额外说明。',
  }, {
    role: 'user',
    content: `为宠物${petInfo.name}（${petInfo.species}，${petInfo.age_years ?? '未知'}岁，${petInfo.weight_kg ?? '未知'}kg，${petInfo.neutered ? '已绝育' : '未绝育'}）提供营养建议，严格JSON格式返回：{"daily_calories":number,"protein_ratio":number,"recommendations":["string"],"foods_to_avoid":["string"]}`,
  }];

  let text = '';
  try {
    const response = await openRouterClient.chat.completions.create({
      model: OPENROUTER_MODEL,
      temperature: 0.2,
      max_tokens: 700,
      messages,
    });
    text = response.choices[0]?.message?.content ?? '';
  } catch (error) {
    try {
      if (!process.env.GROQ_API_KEY) {
        throw error;
      }
      const fallbackResponse = await groqClient.chat.completions.create({
        model: GROQ_MODEL,
        temperature: 0.2,
        max_tokens: 700,
        messages,
      });
      text = fallbackResponse.choices[0]?.message?.content ?? '';
    } catch {
      text = await callGemini(
        `为宠物${petInfo.name}（${petInfo.species}，${petInfo.age_years ?? '未知'}岁，${petInfo.weight_kg ?? '未知'}kg，${petInfo.neutered ? '已绝育' : '未绝育'}）提供营养建议，严格JSON格式返回：{"daily_calories":number,"protein_ratio":number,"recommendations":["string"],"foods_to_avoid":["string"]}`,
        '你是宠物营养顾问。严格返回 JSON，不要有任何额外说明。',
      );
    }
  }
  return extractJson(text) as NutritionResponse;
}
