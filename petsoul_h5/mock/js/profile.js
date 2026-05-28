/** Pet Soul · WingPet 建档 + 流程状态（sessionStorage mock） */
window.PetSoulProfile = {
  KEY: 'petsoul_profile',
  INTENT_KEY: 'petsoul_intent',
  QUIZ_KEY: 'petsoul_quiz_done',

  load() {
    try {
      const raw = sessionStorage.getItem(this.KEY);
      return raw ? JSON.parse(raw) : null;
    } catch {
      return null;
    }
  },

  save(data) {
    const prev = this.load() || {};
    sessionStorage.setItem(this.KEY, JSON.stringify({ ...prev, ...data }));
  },

  hasProfile() {
    const p = this.load();
    return !!(p && p.petName && p.petPhoto);
  },

  requireProfile() {
    if (!this.hasProfile()) {
      location.replace('profile.html');
      return false;
    }
    return true;
  },

  getIntent() {
    return sessionStorage.getItem(this.INTENT_KEY) || this.load()?.intent || '遛狗搭子';
  },

  setIntent(intent) {
    sessionStorage.setItem(this.INTENT_KEY, intent);
    this.save({ intent });
  },

  setLookingFor(value) {
    this.save({ lookingFor: value });
  },

  getLookingFor() {
    return this.load()?.lookingFor || '不限';
  },

  getPetType() {
    const t = this.load()?.petType;
    return ['dog', 'cat', 'other'].includes(t) ? t : 'dog';
  },

  getPetTypeLabel() {
    const p = this.load();
    if (p?.petType === 'other' && p.petTypeOther) return p.petTypeOther;
    const labels = { dog: '狗狗', cat: '貓貓', other: '萌寵' };
    return labels[p?.petType] || labels.dog;
  },

  markQuizDone() {
    sessionStorage.setItem(this.QUIZ_KEY, '1');
    this.save({ quizDone: true });
  },

  slugFromName(name) {
    return (name || 'doubao').toLowerCase().replace(/\s+/g, '');
  },

  formatClue(petName, text) {
    const t = (text || '').trim();
    if (!t) return `${petName || '牠'}說：`;
    if (/说[:：]|說[:：]/.test(t)) return t;
    return `${petName || '牠'}說：${t}`;
  },

  ownerRevealed(p) {
    if (!p) return '';
    if (p.ownerRevealed) return p.ownerRevealed;
    const g = p.ownerGender === '女' ? '女' : p.ownerGender === '男' ? '男' : '';
    const line1 = [
      p.ownerNickname,
      p.ownerAge ? `${p.ownerAge}岁` : '',
      g,
      p.ownerJob || p.ownerTag,
    ].filter(Boolean).join(' · ');
    const line2 = [
      p.ownerEducation,
      p.ownerMarital,
      p.ownerBuddyWant ? `想找${p.ownerBuddyWant}` : '',
    ].filter((x) => x && x !== '');
    return line2.length ? `${line1}\n${line2.join(' · ')}` : line1;
  },

  personaTraitTags(p) {
    const soul = p?.ownerSoul;
    const tags = [];
    if (p?.personaTitle) tags.push({ text: p.personaTitle, accent: true });
    if (!soul) {
      return tags.length ? tags : [{ text: '社交小太陽', accent: true }];
    }
    if (soul.social >= 0.65) tags.push({ text: '外向社交' });
    else if (soul.social < 0.45) tags.push({ text: '慢熱型' });
    if (soul.bond >= 0.65) tags.push({ text: '黏人寶' });
    if (soul.play >= 0.65) tags.push({ text: '愛玩瘋' });
    if (soul.energy >= 0.65) tags.push({ text: '體力充沛' });
    else if (soul.energy < 0.45) tags.push({ text: '佛系慢活' });
    return tags.slice(0, 4);
  },

  personaPrefs(p) {
    const soul = p?.ownerSoul || {};
    const likes = [];
    const dislikes = [];
    const add = (arr, icon, text, ok) => { if (ok) arr.push({ icon, text }); };

    add(likes, '🐕', '散步', soul.energy >= 0.45);
    add(likes, '☀️', '戶外曬太陽', soul.energy >= 0.55);
    add(likes, '🎾', '玩瘋', soul.play >= 0.55);
    add(likes, '👋', '交朋友', soul.social >= 0.55);
    add(likes, '🛋️', '安靜陪伴', soul.bond >= 0.55 && soul.energy < 0.55);
    add(likes, '🦴', '小零食', soul.play >= 0.45);

    add(dislikes, '📢', '大嗓門', soul.social < 0.55);
    add(dislikes, '👀', '陌生突襲', soul.social < 0.5);
    add(dislikes, '⏰', '等太久', soul.energy >= 0.6);

    if (likes.length < 2) {
      likes.push({ icon: '🧸', text: '玩具' }, { icon: '🐾', text: '同場玩耍' });
    }
    if (dislikes.length < 1) {
      dislikes.push({ icon: '📢', text: '嘈雜環境' });
    }
    return { likes: likes.slice(0, 4), dislikes: dislikes.slice(0, 3) };
  },

  renderPrefList(ul, items) {
    if (!ul) return;
    ul.innerHTML = items.map(({ icon, text }) =>
      `<li class="pref-item"><span class="pref-icon">${icon}</span>${text}</li>`
    ).join('');
  },

  personaBioFallback(p) {
    const name = p?.petName || '牠';
    const title = p?.personaTitle || '社交小太陽';
    const soul = p?.ownerSoul;
    if (!soul) {
      return `${name}是「${title}」——同場最會帶氣氛的那隻，適合找固定玩伴一起撒歡。`;
    }
    const bits = [];
    if (soul.social >= 0.6) bits.push('見狗就熱情');
    else if (soul.social < 0.45) bits.push('慢熱但一熟就很黏');
    if (soul.play >= 0.6) bits.push('玩起來停不下來');
    if (soul.energy >= 0.6) bits.push('體力好、愛戶外');
    else if (soul.energy < 0.45) bits.push('佛系慢活、喜歡安靜陪走');
    const tail = bits.length ? bits.join('，') : '性格均衡、好相處';
    return `${name}是「${title}」——${tail}。Discover 時會和對方的相處風格做緣分羅盤比對。`;
  },

  applyToPersonaCard(root) {
    const p = this.load();
    if (!p) return;
    root.querySelectorAll('[data-profile="petPhoto"]').forEach((img) => {
      if (p.petPhoto) img.src = p.petPhoto;
    });
    const name = root.querySelector('[data-profile="petName"]');
    const meta = root.querySelector('[data-profile="personaMeta"]');
    const code = root.querySelector('[data-profile="personaCode"]');
    const bio = root.querySelector('[data-profile="personaBio"]');
    const tagsEl = root.querySelector('#personaTags');
    if (name) name.textContent = p.petName || name.textContent;
    if (meta) {
      meta.textContent = [
        p.breed || '柯基',
        p.personaTitle || '社交小太陽',
        p.playArea || '同場',
      ].filter(Boolean).join(' · ');
    }
    if (code) code.textContent = p.personaCode || 'ENFP';
    root.querySelectorAll('[data-profile="playArea"]').forEach((el) => {
      if (p.playArea) el.textContent = p.playArea;
    });
    if (bio) bio.textContent = p.soulBio || this.personaBioFallback(p);
    if (tagsEl) {
      tagsEl.innerHTML = this.personaTraitTags(p).map(({ text, accent }) =>
        `<span class="persona-tag${accent ? ' is-accent' : ''}">${text}</span>`
      ).join('');
    }
    const prefs = this.personaPrefs(p);
    this.renderPrefList(root.querySelector('#personaLikes'), prefs.likes);
    this.renderPrefList(root.querySelector('#personaDislikes'), prefs.dislikes);
    const clue = root.querySelector('[data-profile="ownerClue"]');
    if (clue) clue.textContent = p.ownerClue || this.formatClue(p.petName, p.iceHint || '');
    const ice = root.querySelector('[data-profile="iceHint"]');
    if (ice) ice.textContent = p.iceHint || '同場 · 測驗區附近';
    const slug = root.querySelector('[data-profile="slug"]');
    if (slug) slug.textContent = `petsoul.app/c/${this.slugFromName(p.petName)}`;
  },

  applyToResult(root) {
    this.applyToPersonaCard(root);
  },

  applyToMe(root) {
    this.applyToPersonaCard(root);
    const intent = this.getIntent();
    ['meIntent', 'meIntentChip', 'shareIntent'].forEach((id) => {
      const el = root.getElementById(id);
      if (!el) return;
      el.textContent = id === 'meIntent' ? `意圖 · ${intent}` : intent;
    });
  },

  applyToCard(root) {
    this.applyToPersonaCard(root);
    const p = this.load();
    const owner = root.querySelector('[data-profile="ownerRevealed"]');
    if (owner) owner.textContent = this.ownerRevealed(p) || '主人 · 合頻後揭曉';
    const intentEl = root.getElementById('cardIntent');
    if (intentEl) intentEl.textContent = this.getIntent();
  },

  iceHintForMatch(theirIce) {
    const p = this.load();
    const mine = p?.iceHint;
    if (mine && theirIce) return `對方：${theirIce}\n你：${mine}`;
    return theirIce || mine || '同場 · 測驗區附近';
  },
};
