export const QUESTIONS = [
  {
    text: '遇见陌生狗，TA 通常…',
    a: { label: '先闻再玩', dim: 'E' },
    b: { label: '躲在你腿后', dim: 'I' },
  },
  {
    text: '遛完回家，TA 通常…',
    a: { label: '还要再疯一轮', dim: 'P' },
    b: { label: '直接躺平', dim: 'J' },
  },
  {
    text: '在狗群里，TA 更像…',
    a: { label: '社交天花板', dim: 'E' },
    b: { label: '只跟熟狗玩', dim: 'I' },
  },
  {
    text: '到新地方，TA 会…',
    a: { label: '到处探索', dim: 'P' },
    b: { label: '贴着你走', dim: 'J' },
  },
  {
    text: '玩玩具时，TA Prefer…',
    a: { label: '追跑放电', dim: 'P' },
    b: { label: '嗅闻慢玩', dim: 'J' },
  },
  {
    text: '对陌生人，TA…',
    a: { label: '摇尾打招呼', dim: 'E' },
    b: { label: '观察很久才靠近', dim: 'I' },
  },
  {
    text: '吃饭风格…',
    a: { label: '秒光盘', dim: 'P' },
    b: { label: '细嚼慢咽', dim: 'J' },
  },
  {
    text: '独处时，TA 更常…',
    a: { label: '找事做/拆家', dim: 'P' },
    b: { label: '安静睡觉', dim: 'J' },
  },
];

const PERSONAS = {
  ENFP: { title: '社交小太阳', summary: '见狗就嗨、见人就摇尾，今天的快乐必须当场花完。', tags: ['社牛', '放电王', '爱玩球'] },
  ENFJ: { title: '狗群队长', summary: '爱组织局面，是狗公园里的气氛组组长。', tags: ['领队', '暖狗', '爱互动'] },
  ESFP: { title: '派对主角', summary: '哪里有狗哪里就有 TA，天生 C 位。', tags: ['派对型', '戏精', '粘人'] },
  ESFJ: { title: '贴心陪伴型', summary: '对熟狗超温柔，是靠谱玩伴。', tags: ['温柔', ' loyal', '慢热友'] },
  INFP: { title: '敏感诗人', summary: '内心戏很多，熟悉后才放飞自我。', tags: ['慢热', '观察型', '专一'] },
  INFJ: { title: '安静知己', summary: '不吵不闹，但最懂你的节奏。', tags: ['安静', '深度玩', '谨慎'] },
  ISFP: { title: '软萌艺术家', summary: '喜欢慢节奏嗅闻散步，拒绝硬社交。', tags: ['软萌', '嗅闻派', '佛系'] },
  ISFJ: { title: '守护小天使', summary: '对家人忠诚，对陌生狗礼貌保持距离。', tags: ['忠诚', '谨慎', '暖'] },
  ENTP: { title: '捣蛋发明家', summary: '永远有新玩法，别的狗跟不上 TA 脑洞。', tags: ['鬼马', '好奇', '高能'] },
  ENTJ: { title: '霸道总裁', summary: '有自己的秩序，玩具必须按 TA 规矩来。', tags: ['主导', '自信', '护主'] },
  ESTP: { title: '运动健将', summary: '跑酷、追球、冲刺——体力就是正义。', tags: ['运动型', '冲刺', '直球'] },
  ESTJ: { title: '纪律委员', summary: '散步路线固定，节奏稳定最安心。', tags: ['规律', '可靠', '守序'] },
  INTP: { title: '思考者', summary: '先研究再行动，嗅闻是在做数据分析。', tags: ['分析型', '独立', '冷静'] },
  INTJ: { title: '高冷战略家', summary: '看起来不好惹，熟悉后是忠犬。', tags: ['高冷', '智性', '护短'] },
  ISTP: { title: '酷盖独行侠', summary: '能自己玩得很开心，偶发社交。', tags: ['酷', '独立', '灵活'] },
  ISTJ: { title: '老成稳重', summary: '不爱折腾，但每一步都踏实。', tags: ['稳重', '老灵魂', '慢热'] },
};

export function computePersona(answers) {
  let e = 0, i = 0, p = 0, j = 0;
  for (const a of answers) {
    if (a === 'E') e++;
    else if (a === 'I') i++;
    else if (a === 'P') p++;
    else if (a === 'J') j++;
  }
  const code =
    (e >= i ? 'E' : 'I') +
    (e + i >= p + j ? 'N' : 'S').replace('S', 'S') +
    (p >= j ? 'P' : 'J');
  // Simplified: use E/I + N fixed + P/J from our 8Q (only E/I/P/J collected)
  const type =
    (e >= i ? 'E' : 'I') +
    'N' +
    (p >= j ? 'F' : 'T') +
    (p >= j ? 'P' : 'J');
  const adjusted = normalizeType(type, e, i, p, j);
  const persona = PERSONAS[adjusted] || PERSONAS.ENFP;
  return { code: adjusted, ...persona };
}

function normalizeType(type, e, i, p, j) {
  const ei = e >= i ? 'E' : 'I';
  const pj = p >= j ? 'P' : 'J';
  const map = {
    EP: ['ENFP', 'ESFP', 'ENTP', 'ESTP'],
    EJ: ['ENFJ', 'ESFJ', 'ENTJ', 'ESTJ'],
    IP: ['INFP', 'ISFP', 'INTP', 'ISTP'],
    IJ: ['INFJ', 'ISFJ', 'INTJ', 'ISTJ'],
  };
  const bucket = map[ei + pj];
  const idx = (e + p) % 4;
  return bucket[idx];
}

export function randomSlug(name) {
  const base = (name || 'pet')
    .toLowerCase()
    .replace(/[^a-z0-9\u4e00-\u9fff]/g, '')
    .slice(0, 8);
  const rand = Math.random().toString(36).slice(2, 6);
  return `${base || 'soul'}-${rand}`;
}
