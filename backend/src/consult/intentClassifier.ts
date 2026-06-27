import { ConsultDecision } from './contract.js';

const greetingOnly = /^(hi|hello|hey|你好|您好|哈喽|在吗|嗨|喂|test|测试)[！!。.\s]*$/i;
const symptomWords = /(吐|呕|拉稀|腹泻|便血|血尿|咳|喘|喷嚏|发烧|发热|没精神|不吃|食欲|疼|痛|瘸|跛|流血|皮肤|掉毛|瘙痒|耳朵|眼睛|分泌物|尿|便|抽搐|误食|中毒|伤口|外伤|肿|舔|叫|哀嚎)/i;
const nutritionWords = /(吃什么|喂什么|营养|粮|罐头|钙|维生素|减肥|增重|热量|蛋白|处方粮|保健品)/i;
const adminWords = /(登录|注册|密码|订单|支付|会员|发票|客服|退款|地址|打不开|崩溃)/i;

const requiredClinicalHints: Array<{ id: string; label: string; test: RegExp; question: string; reason: string }> = [
  {
    id: 'duration',
    label: '持续时间',
    test: /(今天|昨天|刚刚|小时|分钟|天|周|一会|多久|持续|早上|晚上|凌晨|前)/,
    question: '这个情况从什么时候开始，持续了多久？',
    reason: '持续时间会影响是否需要尽快就医。',
  },
  {
    id: 'frequency',
    label: '频次或严重程度',
    test: /(\d+\s*(次|回|遍)|一次|两次|三次|多次|反复|一直|频繁|严重|轻微|少量|大量)/,
    question: '目前一共出现了几次，量大不大，是否越来越严重？',
    reason: '频次和严重程度决定风险分层。',
  },
  {
    id: 'appetite_energy',
    label: '精神和食欲',
    test: /(精神|活力|蔫|萎靡|食欲|吃饭|喝水|不吃|不喝|能吃|能喝)/,
    question: '精神状态、食欲和喝水情况和平时比有什么变化？',
    reason: '精神食欲是宠物分诊里最关键的总体状态指标。',
  },
];

export function classifyIntent(text: string, hasPhoto: boolean): ConsultDecision {
  const trimmed = text.trim();

  if (greetingOnly.test(trimmed)) {
    return {
      intent: 'greeting',
      responseType: 'guide',
      canAssess: false,
      reason: '用户只是寒暄，没有症状信息。',
      missingInfo: ['具体症状', '持续时间', '精神食欲', '排便排尿情况'],
      followUpQuestions: [
        {
          id: 'symptoms',
          text: '请直接描述宠物哪里不舒服、从什么时候开始、精神和食欲有没有变化。',
          reason: '需要基本症状后才能做分诊。',
        },
      ],
      nextActions: [
        { priority: 'monitor', text: '如果是急症，例如呼吸困难、抽搐、误食毒物或大量出血，请立即去宠物医院。' },
      ],
    };
  }

  if (adminWords.test(trimmed) && !symptomWords.test(trimmed)) {
    return {
      intent: 'administrative',
      responseType: 'unsupported',
      canAssess: false,
      reason: '这是账号、订单或 App 使用问题，不属于宠物健康分诊。',
      missingInfo: [],
      followUpQuestions: [],
      nextActions: [{ priority: 'routine', text: '请在“我的”或客服入口处理账号、订单和 App 问题。' }],
    };
  }

  if (nutritionWords.test(trimmed) && !symptomWords.test(trimmed)) {
    return {
      intent: 'nutrition',
      responseType: 'nutrition_advice',
      canAssess: true,
      reason: '用户询问营养或喂养建议。',
      missingInfo: [],
      followUpQuestions: [],
      nextActions: [],
    };
  }

  if (!symptomWords.test(trimmed) && !hasPhoto) {
    return {
      intent: 'unsupported',
      responseType: 'follow_up',
      canAssess: false,
      reason: '未识别到足够的宠物健康信息。',
      missingInfo: ['具体症状'],
      followUpQuestions: [
        {
          id: 'symptoms',
          text: '请补充一个具体表现，例如呕吐、腹泻、咳嗽、不吃饭、皮肤瘙痒或受伤情况。',
          reason: '没有症状无法进行健康分诊。',
        },
      ],
      nextActions: [],
    };
  }

  const missing = requiredClinicalHints.filter((hint) => !hint.test.test(trimmed));
  if (missing.length >= 2 && !hasPhoto) {
    return {
      intent: 'symptom_triage',
      responseType: 'follow_up',
      canAssess: false,
      reason: '症状描述过短，关键分诊信息不足。',
      missingInfo: missing.map((hint) => hint.label),
      followUpQuestions: missing.slice(0, 3).map((hint) => ({
        id: hint.id,
        text: hint.question,
        reason: hint.reason,
      })),
      nextActions: [{ priority: 'monitor', text: '补充信息前，先观察精神、食欲、喝水、排便排尿和是否疼痛。' }],
    };
  }

  return {
    intent: 'symptom_triage',
    responseType: 'triage_report',
    canAssess: true,
    reason: '具备基本分诊信息。',
    missingInfo: missing.map((hint) => hint.label),
    followUpQuestions: missing.slice(0, 1).map((hint) => ({
      id: hint.id,
      text: hint.question,
      reason: hint.reason,
    })),
    nextActions: [],
  };
}
