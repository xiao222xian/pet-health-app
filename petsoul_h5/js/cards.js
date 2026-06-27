export const DEMO_CARDS = {
  'demo-bella': {
    slug: 'demo-bella',
    petName: 'Bella',
    breed: '柯基 · 3岁',
    emoji: '🐕',
    personaCode: 'ENFP',
    personaTitle: '社交小太阳',
    personaSummary: '见狗就嗨，天蝎座女孩（娱乐向），放电型选手。',
    tags: ['社牛', '爱玩球', '放电王'],
    ownerMotto: '周末晨光队 · 话痨铲屎官',
    ownerNickname: 'Bella 的妈咪',
  },
  'demo-doubao': {
    slug: 'demo-doubao',
    petName: '豆包',
    breed: '金毛 · 2岁',
    emoji: '🦮',
    personaCode: 'ESFJ',
    personaTitle: '贴心陪伴型',
    personaSummary: '双鱼座宝宝（娱乐向），对熟狗超级温柔。',
    tags: ['暖狗', '粘人', '游泳健将'],
    ownerMotto: '装备党 · 零食管够',
    ownerNickname: '豆包爸',
  },
  'demo-mochi': {
    slug: 'demo-mochi',
    petName: 'Mochi',
    breed: '柴犬 · 4岁',
    emoji: '🐕‍🦺',
    personaCode: 'INTJ',
    personaTitle: '高冷战略家',
    personaSummary: '看起来不好惹，熟悉后是忠犬。',
    tags: ['高冷', '护短', '表情帝'],
    ownerMotto: '点头微笑型 · 夜遛党',
    ownerNickname: 'Mochi 家长',
  },
};

const STORAGE_KEY = 'petsoul_cards';

export function loadAllCards() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    return raw ? JSON.parse(raw) : {};
  } catch {
    return {};
  }
}

export function saveCard(card) {
  const all = loadAllCards();
  all[card.slug] = { ...card, updatedAt: Date.now() };
  localStorage.setItem(STORAGE_KEY, JSON.stringify(all));
  return card;
}

export function getCard(slug) {
  if (DEMO_CARDS[slug]) return DEMO_CARDS[slug];
  const all = loadAllCards();
  return all[slug] || null;
}

export function getMyCard() {
  const slug = localStorage.getItem('petsoul_my_slug');
  if (!slug) return null;
  return getCard(slug);
}

export function setMyCardSlug(slug) {
  localStorage.setItem('petsoul_my_slug', slug);
}

export function compatibility(a, b) {
  if (!a || !b) return { score: 72, copy: '两只小可爱，值得试试。' };
  let score = 58;
  if (a.personaCode && b.personaCode) {
    if (a.personaCode[0] === b.personaCode[0]) score += 12;
    if (a.personaCode.slice(-1) === b.personaCode.slice(-1)) score += 10;
    if (a.tags && b.tags) {
      const overlap = a.tags.filter((t) => b.tags.includes(t)).length;
      score += overlap * 8;
    }
  }
  score = Math.min(98, score + (a.slug.length + b.slug.length) % 7);
  let copy = '合频不错，狗先玩，人慢慢熟。';
  if (score >= 88) copy = `${a.petName} × ${b.petName}：天生玩伴型，今天适合多跑两圈。`;
  else if (score >= 75) copy = `性格互补也可能很合拍，${a.petName} 和 ${b.petName} 值得约下次。`;
  else copy = `慢热组合，需要主人多引导一下～`;
  return { score, copy };
}
