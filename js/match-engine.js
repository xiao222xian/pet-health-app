/**
 * Pet Soul · 双层匹配引擎
 * 合频 = 55% 主人 Soul + 35% 狗玩伴 + 10% 意图加成
 * 测验答案 → 人宠相处向量（非纯狗 MBTI）
 */
window.PetSoulMatch = {
  WEIGHTS: { owner: 0.55, dog: 0.35, intent: 0.1 },

  /** 每题 4 选项 → [social, bond, play, energy] 增量 0~1 */
  OPTION_DELTAS: [
    [[0.2, 0.5, 0.4, 0.3], [0.9, 0.6, 0.7, 0.85], [0.5, 0.4, 0.3, 0.7], [0.6, 0.5, 0.5, 0.6]],
    [[0.5, 0.5, 0.6, 0.55], [0.95, 0.7, 0.8, 0.9], [0.35, 0.6, 0.4, 0.4], [0.85, 0.5, 0.75, 0.95]],
    [[0.3, 0.5, 0.35, 0.35], [0.8, 0.55, 0.7, 0.8], [0.15, 0.65, 0.25, 0.3], [0.4, 0.45, 0.3, 0.35]],
    [[0.25, 0.4, 0.35, 0.3], [0.7, 0.75, 0.65, 0.7], [0.45, 0.55, 0.4, 0.5], [0.6, 0.4, 0.7, 0.75]],
    [[0.35, 0.85, 0.45, 0.35], [0.55, 0.95, 0.5, 0.45], [0.65, 0.6, 0.75, 0.7], [0.5, 0.4, 0.55, 0.6]],
    [[0.3, 0.35, 0.4, 0.35], [0.85, 0.9, 0.7, 0.8], [0.45, 0.5, 0.45, 0.4], [0.25, 0.3, 0.35, 0.45]],
    [[0.25, 0.9, 0.35, 0.25], [0.6, 0.95, 0.45, 0.4], [0.4, 0.55, 0.4, 0.45], [0.55, 0.5, 0.65, 0.6]],
    [[0.5, 0.45, 0.4, 0.55], [0.45, 0.8, 0.35, 0.35], [0.7, 0.4, 0.5, 0.65], [0.55, 0.45, 0.55, 0.6]],
    [[0.55, 0.5, 0.85, 0.6], [0.75, 0.85, 0.6, 0.7], [0.45, 0.45, 0.35, 0.55], [0.65, 0.55, 0.9, 0.75]],
    [[0.4, 0.5, 0.45, 0.45], [0.85, 0.6, 0.75, 0.85], [0.35, 0.4, 0.3, 0.35], [0.7, 0.55, 0.8, 0.7]],
    [[0.45, 0.45, 0.35, 0.35], [0.5, 0.5, 0.85, 0.9], [0.9, 0.55, 0.7, 0.75], [0.55, 0.45, 0.65, 0.6]],
    [[0.5, 0.75, 0.5, 0.45], [0.8, 0.65, 0.55, 0.7], [0.4, 0.5, 0.35, 0.4], [0.65, 0.85, 0.6, 0.55]],
    [[0.7, 0.45, 0.55, 0.75], [0.45, 0.5, 0.4, 0.45], [0.35, 0.55, 0.35, 0.35], [0.5, 0.4, 0.45, 0.4]],
    [[0.75, 0.4, 0.5, 0.7], [0.35, 0.55, 0.35, 0.3], [0.6, 0.5, 0.55, 0.5], [0.55, 0.45, 0.65, 0.55]],
    [[0.35, 0.55, 0.3, 0.35], [0.85, 0.7, 0.65, 0.65], [0.2, 0.45, 0.25, 0.4], [0.45, 0.4, 0.4, 0.45]],
    [[0.95, 0.75, 0.7, 0.9], [0.4, 0.7, 0.45, 0.4], [0.85, 0.5, 0.8, 0.85], [0.3, 0.55, 0.35, 0.35]],
  ],

  PERSONA_TITLES: {
    ENFP: '社交小太陽', ESFP: '現場 MVP', ENFJ: '暖心隊長', ESFJ: '治癒系',
    ENTP: '鬼馬探險家', ESTP: '衝鋒玩瘋型', ENTJ: '帶隊大哥', ESTJ: '規律管家',
    INFP: '慢熱詩人', ISFP: '安靜美學', INFJ: '深度觀察者', ISFJ: '忠犬系',
    INTP: '傲嬌貴族', ISTP: '獨立游侠', INTJ: '戰略家', ISTJ: '穩重组',
  },

  BREED_SIZE: {
    '柯基': 'small', '柴犬': 'small', '黃金獵犬': 'large', '混種': 'medium',
  },

  DEFAULT_USER: {
    ownerSoul: { social: 0.82, bond: 0.78, play: 0.75, energy: 0.8 },
    dogPlay: { social: 0.85, play: 0.8, energy: 0.82 },
    personaCode: 'ENFP',
    personaTitle: '社交小太陽',
    breed: '柯基',
    intent: '遛狗搭子',
    ownerGender: '',
    lookingFor: '不限',
  },

  scoreQuizAnswers(answers) {
    const sums = { social: 0, bond: 0, play: 0, energy: 0 };
    const n = answers.length;
    answers.forEach((optIdx, qi) => {
      const row = this.OPTION_DELTAS[qi]?.[optIdx];
      if (!row) return;
      sums.social += row[0];
      sums.bond += row[1];
      sums.play += row[2];
      sums.energy += row[3];
    });
    const ownerSoul = {
      social: sums.social / n,
      bond: sums.bond / n,
      play: sums.play / n,
      energy: sums.energy / n,
    };
    const dogPlay = {
      social: (ownerSoul.social * 1.2 + ownerSoul.play * 0.3) / 1.5,
      play: ownerSoul.play,
      energy: (ownerSoul.energy * 1.1 + ownerSoul.social * 0.2) / 1.3,
    };
    const personaCode = this.personaFromSoul(ownerSoul);
    return {
      quizAnswers: answers,
      ownerSoul,
      dogPlay,
      personaCode,
      personaTitle: this.PERSONA_TITLES[personaCode] || '社交小太陽',
    };
  },

  personaFromSoul(s) {
    const e = s.social >= 0.52 ? 'E' : 'I';
    const n = s.energy >= 0.52 ? 'N' : 'S';
    const f = s.bond >= 0.52 ? 'F' : 'T';
    const p = s.play >= 0.48 ? 'P' : 'J';
    return `${e}${n}${f}${p}`;
  },

  userProfile() {
    const p = window.PetSoulProfile?.load() || {};
    return {
      ...this.DEFAULT_USER,
      ownerSoul: p.ownerSoul || this.DEFAULT_USER.ownerSoul,
      dogPlay: p.dogPlay || this.DEFAULT_USER.dogPlay,
      personaCode: p.personaCode || this.DEFAULT_USER.personaCode,
      personaTitle: p.personaTitle || this.DEFAULT_USER.personaTitle,
      breed: p.breed || '柯基',
      intent: window.PetSoulProfile?.getIntent() || p.intent || '遛狗搭子',
      ownerGender: p.ownerGender || '',
      lookingFor: p.lookingFor || '不限',
    };
  },

  vecSimilarity(a, b) {
    const keys = Object.keys(a);
    let diff = 0;
    keys.forEach((k) => { diff += Math.abs((a[k] || 0) - (b[k] || 0)); });
    const avgDiff = diff / keys.length;
    return Math.round((1 - avgDiff) * 100);
  },

  sizeCompatibility(a, b) {
    const order = { small: 0, medium: 1, large: 2 };
    const sa = order[a] ?? 1;
    const sb = order[b] ?? 1;
    const gap = Math.abs(sa - sb);
    if (gap === 0) return 1;
    if (gap === 1) return 0.85;
    return 0.65;
  },

  intentBonus(userIntent, theirIntent) {
    if (userIntent === theirIntent) return 10;
    if (userIntent === '都可' || theirIntent === '都可') return 5;
    if (userIntent === '遛狗搭子' && theirIntent === '交友向') return -5;
    if (userIntent === '交友向' && theirIntent === '遛狗搭子') return -5;
    return 0;
  },

  passesGenderFilter(user, target) {
    const needFilter = user.intent === '交友向' || target.intent === '交友向';
    if (!needFilter) return true;
    if (user.lookingFor === '不限' && target.lookingFor === '不限') return true;
    if (!user.ownerGender || !target.ownerGender) return true;
    const same = user.ownerGender === target.ownerGender;
    if (user.lookingFor === '同性家長' && !same) return false;
    if (user.lookingFor === '異性家長' && same) return false;
    if (target.lookingFor === '同性家長' && !same) return false;
    if (target.lookingFor === '異性家長' && same) return false;
    return true;
  },

  compute(user, target) {
    const tSoul = target.ownerSoul || { social: 0.5, bond: 0.5, play: 0.5, energy: 0.5 };
    const tDog = target.dogPlay || { social: 0.5, play: 0.5, energy: 0.5 };
    const ownerScore = this.vecSimilarity(user.ownerSoul, tSoul);
    let dogScore = this.vecSimilarity(user.dogPlay, tDog);
    const userSize = this.BREED_SIZE[user.breed] || 'medium';
    const theirSize = this.BREED_SIZE[target.breed] || 'medium';
    dogScore = Math.round(dogScore * 0.85 + this.sizeCompatibility(userSize, theirSize) * 100 * 0.15);

    const iBonus = this.intentBonus(user.intent, target.intent || '都可');
    let total = Math.round(
      ownerScore * this.WEIGHTS.owner +
      dogScore * this.WEIGHTS.dog +
      Math.max(0, 50 + iBonus * 5) * this.WEIGHTS.intent
    );
    total = Math.max(52, Math.min(98, total));

    const genderOk = this.passesGenderFilter(user, target);

    return {
      total,
      ownerScore,
      dogScore,
      intentBonus: iBonus,
      genderOk,
      whyLabel: `主人 Soul ${ownerScore}% · 狗玩伴 ${dogScore}%`,
      copy: this.matchCopy(ownerScore, dogScore, user, target),
    };
  },

  matchCopy(ownerScore, dogScore, user, target) {
    if (ownerScore >= 85 && dogScore >= 80) return '雙向合頻 · 你們相处风格与玩风都很接近。';
    if (ownerScore >= 80) return '主人 Soul 高度同頻 · 遛狗节奏应该很合拍。';
    if (dogScore >= 80) return '狗玩伴契合 · 能量与体型适合一起疯。';
    if (ownerScore >= 70) return '互补型 · 你外向牠慢热，可能需要主人多引导。';
    return '可試試 · 同場先见见再决定。';
  },
};
