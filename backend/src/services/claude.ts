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

const OPENROUTER_MODEL = process.env.OPENROUTER_MODEL ?? 'google/gemini-2.0-flash-001';
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

function consultSystemPrompt() {
  return `你是一名谨慎、耐心、表达自然的宠物健康分诊助手。
你的任务不是做确诊，而是根据主人提供的症状，给出贴近实际的初步判断、居家护理建议、观察重点，以及明确的就医时机。

严格输出 JSON，不要输出 Markdown，不要输出代码块，不要输出额外说明：
{
  "risk_level": "low|medium|high|emergency",
  "summary": "2-3句，结合当前描述给出初步判断，不要空泛",
  "possible_causes": ["2-4条，写可能原因或方向，避免确定性诊断"],
  "home_care": ["3-5条，写具体可执行的居家处理步骤"],
  "watch_points": ["2-4条，写接下来要重点观察的表现"],
  "when_to_seek_vet": ["2-4条，写明确触发就医的具体情况"],
  "follow_up_question": "如果信息不足，追问1个最关键的问题；如果信息已经比较充分，返回空字符串",
  "seek_vet": true
}

规则：
1. 全部用中文，语气像专业但克制的问诊助手。
2. 必须结合用户当前描述回答，避免模板化空话。
3. 不要直接给出确定性疾病诊断，只能说“可能”“需要结合进一步表现判断”。
4. 不要动不动建议立刻就医；只有出现明确危险信号时，才把 risk_level 设为 high 或 emergency。
5. home_care 要尽量具体，比如观察多久、补水、饮食、环境、休息，而不是泛泛地说“注意观察”。
6. when_to_seek_vet 必须写具体触发条件，比如“连续呕吐超过几次”“精神持续很差”“无法进食进水”“呼吸明显急促”等。
7. 如果信息明显不足，follow_up_question 必须只问一个最关键的问题，帮助下一轮判断。`;
}

function normalizeStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => String(item ?? '').trim())
    .filter(Boolean)
    .slice(0, 5);
}

function normalizeConsultResponse(parsed: any): ConsultResponse {
  const homeCare = normalizeStringArray(parsed.home_care);
  const watchPoints = normalizeStringArray(parsed.watch_points);
  const whenToSeekVet = normalizeStringArray(parsed.when_to_seek_vet);
  const advice = homeCare.length > 0
    ? homeCare
    : normalizeStringArray(parsed.advice);

  return {
    risk_level: parsed.risk_level,
    summary: String(parsed.summary ?? '').trim(),
    possible_causes: normalizeStringArray(parsed.possible_causes),
    home_care: homeCare,
    watch_points: watchPoints,
    when_to_seek_vet: whenToSeekVet,
    follow_up_question: String(parsed.follow_up_question ?? '').trim(),
    advice,
    seek_vet: Boolean(parsed.seek_vet),
    disclaimer: DISCLAIMER,
  };
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

  const systemPrompt = consultSystemPrompt();

  let text = '';
  try {
    const geminiPrompt = `${buildPetSummary(petInfo)}\n\n主人描述：${symptoms}\n\n请像宠物分诊助手一样回答，并严格输出 JSON。`;
    text = await callGemini(geminiPrompt, systemPrompt, photoData);
  } catch (error) {
    try {
      if (!process.env.OPENROUTER_API_KEY) {
        throw error;
      }
      const fallbackResponse = await openRouterClient.chat.completions.create({
        model: OPENROUTER_MODEL,
        temperature: 0.3,
        max_tokens: 1100,
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
      text = fallbackResponse.choices[0]?.message?.content ?? '';
    } catch {
      const textOnlyPrompt = `${buildPetSummary(petInfo)}\n\n主人描述：${symptoms}${photoData.length > 0 ? '\n\n补充：主人还上传了宠物照片，但当前后备模型只能基于文字分析。' : ''}`;
      const fallbackResponse = await groqClient.chat.completions.create({
        model: GROQ_MODEL,
        temperature: 0.3,
        max_tokens: 1000,
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
    }
  }

  const parsed = extractJson(text) as any;
  return normalizeConsultResponse(parsed);
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
