/** Pet Soul · 合频 / 聊天 / 活动卡 mock 数据 */
window.PETSOUL_MATCHES = {
  bella: {
    id: 'bella',
    name: 'Bella',
    breed: '柯基',
    persona: 'ENFP · 社交小太陽',
    score: 87,
    ownerScore: 88,
    dogScore: 86,
    distance: '同場 · 現場',
    intent: '遛狗搭子',
    ownerSoul: { social: 0.88, bond: 0.75, play: 0.8, energy: 0.85 },
    dogPlay: { social: 0.9, play: 0.82, energy: 0.88 },
    ownerGender: '女',
    lookingFor: '不限',
    img: 'https://images.unsplash.com/photo-1619983081563-430f63602796?w=200&q=80',
    owner: 'B媽',
    ownerImg: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=200&q=80',
    copy: '雙向合频 · 你們都是外向玩瘋型。',
    ice: '灰色連帽衫 · 測驗區剛見過。',
    preview: '好呀！明天海濱見～',
    unread: 1,
    soulLine: '靈魂共鳴 87% · 可立刻開聊',
  },
  lucky: {
    id: 'lucky',
    name: 'Lucky',
    breed: '黃金獵犬',
    persona: 'ESFJ · 治癒系',
    score: 91,
    ownerScore: 84,
    dogScore: 79,
    distance: '同場 · 80m',
    intent: '都可',
    ownerSoul: { social: 0.72, bond: 0.85, play: 0.65, energy: 0.68 },
    dogPlay: { social: 0.78, play: 0.7, energy: 0.72 },
    ownerGender: '女',
    lookingFor: '不限',
    img: 'https://images.unsplash.com/photo-1558787533-047468894a7f?w=200&q=80',
    owner: 'Cici',
    ownerImg: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&q=80',
    copy: '91% · 現場最高合頻。',
    ice: '手機殼有 Lucky 贴纸。',
    preview: '週末咖啡？可以帶狗～',
    unread: 0,
    soulLine: '靈魂共鳴 91% · 可立刻開聊',
  },
};

window.PETSOUL_FAVS = {
  mochi: {
    id: 'mochi',
    name: 'Mochi',
    breed: '柴犬',
    score: 72,
    ownerScore: 58,
    dogScore: 62,
    distance: '同場 · 120m',
    intent: '都可',
    ownerSoul: { social: 0.35, bond: 0.55, play: 0.4, energy: 0.38 },
    dogPlay: { social: 0.3, play: 0.45, energy: 0.35 },
    ownerGender: '男',
    lookingFor: '不限',
    img: 'https://images.unsplash.com/photo-1587300003388-59208cc962cb?w=200&q=80',
    preview: '等你回覆 ♥ 才解鎖聊天',
    pending: true,
  },
};

window.PETSOUL_TEMPLATES = {
  playdate: {
    type: 'playdate',
    brand: 'Petch · Playdate',
    title: '氹仔海濱遛狗',
    when: '明天 · 17:00',
    where: '同場 · 步行 8 分鐘',
    note: 'Bella 會帶飛盤，豆包一起跑嗎？',
  },
  date: {
    type: 'date',
    brand: 'FetchaDate · 見面',
    title: '週末咖啡 · 可帶狗',
    when: '週六 · 15:00',
    where: '氹仔某 pet-friendly 咖啡',
    note: '先認識主人，WingPet 已互相 Like～',
  },
};

window.PETSOUL_CHAT_SEED = {
  bella: [
    { from: 'system', kind: 'soul-banner', score: 87 },
    { from: 'them', text: '嗨！Bella 妈 here～同場看到你们 ENFP 小太阳 🐾', time: '14:02' },
    { from: 'me', text: '哈哈豆包也是社交疯，想找个固定遛狗搭子', time: '14:03' },
  ],
  lucky: [
    { from: 'system', kind: 'soul-banner', score: 91 },
    { from: 'them', text: 'Lucky 说你也喜欢慢跑？', time: '13:40' },
  ],
};

window.PETSOUL_PLAYDATE_CONFIRMED = {
  title: 'Playdate 已確認',
  when: '明天 · 17:00',
  where: '氹仔海濱',
  with: 'Bella & 豆包',
};

/** 依当前用户档案重算合频分（matches / chat 页可用） */
window.PETSOUL_rescoreMatch = function (target) {
  if (!window.PetSoulMatch) return target;
  const m = window.PetSoulMatch.compute(window.PetSoulMatch.userProfile(), target);
  return { ...target, score: m.total, ownerScore: m.ownerScore, dogScore: m.dogScore, copy: m.copy };
};
