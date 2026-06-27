import { ConsultEmergency, ConsultNextAction } from '../types/index.js';

export interface EmergencyMatch {
  riskLevel: 'emergency' | 'high';
  title: string;
  shortAnswer: string;
  emergency: ConsultEmergency;
  nextActions: ConsultNextAction[];
}

const emergencyRules: Array<{
  keywords: RegExp;
  title: string;
  reason: string;
  actions: string[];
  avoid: string[];
}> = [
  {
    keywords: /(老鼠药|鼠药|灭鼠|百草枯|农药|杀虫剂|蟑螂药|防冻液|乙二醇|误食.*药|吃了.*药|巧克力|葡萄|葡萄干|洋葱|大蒜)/i,
    title: '疑似中毒或误食风险',
    reason: '描述中包含宠物常见高风险毒物或药物，不能等待 AI 观察判断。',
    actions: ['立即联系附近宠物医院或急诊兽医', '带上包装、剩余物或照片给医生判断成分', '记录误食时间、数量、宠物体重和当前表现'],
    avoid: ['不要自行催吐，除非兽医明确要求', '不要喂牛奶、油或偏方', '不要等待明显症状出现后再处理'],
  },
  {
    keywords: /(呼吸困难|喘不上气|张口呼吸|舌头发紫|牙龈发白|牙龈发紫|抽搐|癫痫|昏迷|站不起来|休克|大出血|血流不止)/i,
    title: '出现危急生命体征',
    reason: '描述中包含呼吸、循环、神经或大量出血相关危险信号。',
    actions: ['立即前往有急诊能力的宠物医院', '途中保持宠物安静和呼吸道通畅', '如有出血，用干净纱布持续按压止血'],
    avoid: ['不要强行喂水喂食', '不要反复搬动或剧烈摇晃宠物', '不要在家继续观察到明天'],
  },
  {
    keywords: /(尿不出来|排尿困难|频繁蹲猫砂.*没尿|公猫.*尿|难产|生不出来|车撞|高处摔|骨折|严重外伤)/i,
    title: '需要尽快线下处理的高风险情况',
    reason: '泌尿梗阻、难产或创伤类问题可能快速恶化。',
    actions: ['尽快联系宠物医院并说明症状', '准备宠物近期病史、用药和照片', '运输时减少活动，避免加重疼痛或损伤'],
    avoid: ['不要自行按压腹部或膀胱', '不要喂人用止痛药', '不要拖延到症状更明显'],
  },
];

export function detectEmergency(text: string): EmergencyMatch | null {
  for (const rule of emergencyRules) {
    if (!rule.keywords.test(text)) continue;
    return {
      riskLevel: rule.title.includes('高风险') ? 'high' : 'emergency',
      title: rule.title,
      shortAnswer: `${rule.reason} 建议把线上问诊作为记录信息的辅助，优先线下就医。`,
      emergency: {
        reason: rule.reason,
        immediate_actions: rule.actions,
        avoid: rule.avoid,
      },
      nextActions: rule.actions.map((item, index) => ({
        priority: index === 0 ? 'now' : 'today',
        text: item,
      })),
    };
  }
  return null;
}
