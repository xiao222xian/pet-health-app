import OpenAI from 'openai';
import { CONSULT_DISCLAIMER, PetContext } from './contract.js';
import { ConsultAgentResponse, ConsultTriage } from '../types/index.js';

const fluClient = new OpenAI({
  apiKey: process.env.FLU_API_KEY || 'missing-key',
  baseURL: process.env.FLU_BASE_URL ?? 'https://new.fluapi.com/v1',
});

const openRouterClient = new OpenAI({
  apiKey: process.env.OPENROUTER_API_KEY || 'missing-key',
  baseURL: 'https://openrouter.ai/api/v1',
});

const groqClient = new OpenAI({
  apiKey: process.env.GROQ_API_KEY || 'missing-key',
  baseURL: 'https://api.groq.com/openai/v1',
});

const FLU_MODEL = process.env.FLU_MODEL ?? 'gpt-5.5';
const OPENROUTER_MODEL = process.env.OPENROUTER_MODEL ?? 'google/gemini-2.0-flash-001';
const GROQ_MODEL = process.env.GROQ_MODEL ?? 'llama-3.1-8b-instant';
const GEMINI_MODEL = process.env.GEMINI_MODEL ?? 'gemini-flash-latest';

export interface TriageGeneration {
  provider: string;
  model: string;
  title: string;
  short_answer: string;
  risk_level: ConsultAgentResponse['risk_level'];
  summary: string;
  triage: ConsultTriage;
  follow_up_question: string;
  seek_vet: boolean;
}

function petLine(pet: PetContext) {
  return [
    `名字：${pet.name}`,
    `物种：${pet.species}`,
    pet.breed ? `品种：${pet.breed}` : null,
    pet.age_years ? `年龄：${pet.age_years}岁` : null,
    pet.weight_kg ? `体重：${pet.weight_kg}kg` : null,
  ].filter(Boolean).join('，');
}

function systemPrompt() {
  return `你是生产级宠物健康分诊助手，只做初步风险分层和护理建议，不做确诊。

必须严格输出 JSON，不要 Markdown，不要代码块，不要额外解释：
{
  "title": "不超过18字的标题",
  "short_answer": "1-2句直接回答",
  "risk_level": "low|medium|high|emergency",
  "summary": "2-3句，结合宠物信息和主人描述",
  "possible_causes": ["2-4条，只写可能方向，不能确诊"],
  "home_care": ["3-5条，具体可执行"],
  "watch_points": ["2-4条，接下来重点观察"],
  "when_to_seek_vet": ["2-5条，明确触发条件"],
  "follow_up_question": "最多1个最关键追问；没有就空字符串",
  "seek_vet": true
}

规则：
1. 全部中文，专业、克制、自然。
2. 不能编造图片细节；如果只知道有照片但看不到或不确定，只说需要线下检查或补充清晰照片。
3. low 表示可短期观察；medium 表示需要严密观察或预约；high 表示建议当天/尽快就医；emergency 只用于明显急症。
4. 不给人用药剂量，不建议自行使用抗生素、止痛药、激素。
5. 必须给出具体观察窗口，例如 6-12 小时、24 小时，或出现哪些变化立刻就医。`;
}

export async function generateTriage(params: {
  pet: PetContext;
  symptoms: string;
  photoData: string[];
}): Promise<TriageGeneration> {
  const text = `宠物信息：${petLine(params.pet)}\n主人描述：${params.symptoms}\n图片数量：${params.photoData.length}`;
  const content: OpenAI.Chat.Completions.ChatCompletionContentPart[] = [{ type: 'text', text }];
  for (const image of params.photoData) {
    content.push({ type: 'image_url', image_url: { url: `data:image/jpeg;base64,${image}` } });
  }

  const attempts: Array<() => Promise<{ provider: string; model: string; text: string }>> = [
    async () => {
      if (!process.env.FLU_API_KEY) throw new Error('Missing FLU_API_KEY');
      const response = await fluClient.chat.completions.create({
        model: FLU_MODEL,
        temperature: 0.2,
        max_tokens: 1200,
        messages: [
          { role: 'system', content: systemPrompt() },
          { role: 'user', content },
        ],
      });
      return { provider: 'flu', model: FLU_MODEL, text: response.choices[0]?.message?.content ?? '' };
    },
    async () => {
      const textOnly = await callGemini(text, systemPrompt());
      return { provider: 'gemini', model: GEMINI_MODEL, text: textOnly };
    },
    async () => {
      if (!process.env.OPENROUTER_API_KEY) throw new Error('Missing OPENROUTER_API_KEY');
      const response = await openRouterClient.chat.completions.create({
        model: OPENROUTER_MODEL,
        temperature: 0.2,
        max_tokens: 1200,
        messages: [
          { role: 'system', content: systemPrompt() },
          { role: 'user', content: text },
        ],
      });
      return { provider: 'openrouter', model: OPENROUTER_MODEL, text: response.choices[0]?.message?.content ?? '' };
    },
    async () => {
      if (!process.env.GROQ_API_KEY) throw new Error('Missing GROQ_API_KEY');
      const response = await groqClient.chat.completions.create({
        model: GROQ_MODEL,
        temperature: 0.2,
        max_tokens: 1200,
        messages: [
          { role: 'system', content: systemPrompt() },
          { role: 'user', content: text },
        ],
      });
      return { provider: 'groq', model: GROQ_MODEL, text: response.choices[0]?.message?.content ?? '' };
    },
  ];

  let lastError: unknown;
  for (const attempt of attempts) {
    try {
      const result = await attempt();
      return normalizeGeneration(result.provider, result.model, parseJson(result.text));
    } catch (error) {
      lastError = error;
    }
  }
  throw lastError instanceof Error ? lastError : new Error('LLM generation failed');
}

export function buildFallbackTriage(params: {
  symptoms: string;
  reason: string;
}): TriageGeneration {
  const hasVomiting = /(吐|呕)/.test(params.symptoms);
  const hasDiarrhea = /(拉稀|腹泻|便血)/.test(params.symptoms);
  const hasCough = /(咳|喘|喷嚏)/.test(params.symptoms);
  const focus = hasVomiting
    ? '呕吐'
    : hasDiarrhea
      ? '腹泻'
      : hasCough
        ? '呼吸道症状'
        : '当前症状';

  return {
    provider: 'rules',
    model: 'fallback-triage-v1',
    title: '先稳妥观察处理',
    short_answer: `模型服务暂时不稳定，我先基于规则给出${focus}的保守分诊建议。`,
    risk_level: 'medium',
    summary: `目前描述具备初步分诊信息，但 AI 模型未能稳定返回结构化结果。建议先按中等风险处理，重点观察精神、食欲、喝水、排便排尿和症状频次。`,
    triage: {
      possible_causes: [
        `${focus}可能与饮食变化、轻度胃肠刺激、感染、疼痛或应激有关`,
        '需要结合持续时间、频次、精神食欲和是否伴随其他症状继续判断',
      ],
      home_care: [
        '先让宠物安静休息，避免剧烈活动和继续接触可疑食物',
        '少量多次提供清水；如果喝水也立即呕吐，不要强行喂',
        '暂时不要自行使用人用药、抗生素、止痛药或止吐药',
        '记录接下来 6-12 小时内症状次数、精神、食欲、饮水和排便排尿',
      ],
      watch_points: [
        '是否反复加重或出现精神明显变差',
        '是否无法进食进水、持续呕吐或腹泻',
        '是否出现血便、血尿、呼吸异常、疼痛或站立困难',
      ],
      when_to_seek_vet: [
        '症状在 6-12 小时内明显加重或反复出现',
        '精神很差、无法喝水、无法进食或明显疼痛',
        '出现血便、血尿、呼吸困难、抽搐、昏迷等危险信号',
        '幼宠、老年宠、孕期宠或有慢性病时建议更早就医',
      ],
    },
    follow_up_question: '请补充宠物年龄、体重、症状开始时间，以及今天精神和食欲变化。',
    seek_vet: true,
  };
}

async function callGemini(textPrompt: string, system: string) {
  if (!process.env.GEMINI_API_KEY) throw new Error('Missing GEMINI_API_KEY');
  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-goog-api-key': process.env.GEMINI_API_KEY,
      },
      body: JSON.stringify({
        contents: [{ parts: [{ text: `${system}\n\n${textPrompt}` }] }],
        generationConfig: { temperature: 0.2, maxOutputTokens: 1200 },
      }),
    },
  );
  if (!response.ok) throw new Error(`Gemini API error ${response.status}`);
  const data = await response.json() as { candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }> };
  const text = data.candidates?.[0]?.content?.parts?.map((part) => part.text ?? '').join('').trim();
  if (!text) throw new Error('Gemini returned empty content');
  return text;
}

function parseJson(text: string) {
  const codeBlock = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  const raw = codeBlock ? codeBlock[1] : text;
  return JSON.parse(raw.trim());
}

function normalizeGeneration(provider: string, model: string, parsed: any): TriageGeneration {
  const possibleCauses = stringList(parsed.possible_causes, 4);
  const homeCare = stringList(parsed.home_care, 5);
  const watchPoints = stringList(parsed.watch_points, 4);
  const whenToSeekVet = stringList(parsed.when_to_seek_vet, 5);
  const risk = normalizeRisk(parsed.risk_level);
  return {
    provider,
    model,
    title: stringValue(parsed.title) || riskTitle(risk),
    short_answer: stringValue(parsed.short_answer) || stringValue(parsed.summary),
    risk_level: risk,
    summary: stringValue(parsed.summary) || stringValue(parsed.short_answer),
    triage: {
      possible_causes: possibleCauses,
      home_care: homeCare,
      watch_points: watchPoints,
      when_to_seek_vet: whenToSeekVet,
    },
    follow_up_question: stringValue(parsed.follow_up_question),
    seek_vet: Boolean(parsed.seek_vet) || risk === 'high' || risk === 'emergency',
  };
}

function stringValue(value: unknown) {
  return String(value ?? '').trim();
}

function stringList(value: unknown, max: number) {
  if (!Array.isArray(value)) return [];
  return value.map((item) => stringValue(item)).filter(Boolean).slice(0, max);
}

function normalizeRisk(value: unknown): ConsultAgentResponse['risk_level'] {
  if (value === 'low' || value === 'medium' || value === 'high' || value === 'emergency') return value;
  return 'medium';
}

function riskTitle(risk: ConsultAgentResponse['risk_level']) {
  switch (risk) {
    case 'emergency':
      return '建议立即就医';
    case 'high':
      return '建议尽快就医';
    case 'medium':
      return '需要重点观察';
    default:
      return '可先谨慎观察';
  }
}

export function attachLegacyFields(response: ConsultAgentResponse): ConsultAgentResponse {
  const triage = response.triage;
  if (!triage) return response;
  return {
    ...response,
    possible_causes: triage.possible_causes,
    home_care: triage.home_care,
    watch_points: triage.watch_points,
    when_to_seek_vet: triage.when_to_seek_vet,
    follow_up_question: response.follow_up_questions[0]?.text ?? response.follow_up_question ?? '',
    advice: triage.home_care.length > 0 ? triage.home_care : response.next_actions.map((item) => item.text),
    disclaimer: CONSULT_DISCLAIMER,
  };
}
