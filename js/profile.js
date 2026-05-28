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

  applyToResult(root) {
    const p = this.load();
    if (!p) return;
    const img = root.querySelector('[data-profile="petPhoto"]');
    const name = root.querySelector('[data-profile="petName"]');
    const personaLine = root.querySelector('[data-profile="personaLine"]');
    const area = root.querySelector('[data-profile="playArea"]');
    const code = root.querySelector('[data-profile="personaCode"]');
    if (img && p.petPhoto) img.src = p.petPhoto;
    if (name) name.textContent = p.petName || name.textContent;
    if (personaLine && p.personaCode) {
      personaLine.textContent = `${p.breed || '柯基'} · ${p.personaCode} · ${p.personaTitle || '社交小太陽'}`;
    }
    if (code) code.textContent = p.personaCode || 'ENFP';
    if (area && p.playArea) area.textContent = p.playArea;
  },

  applyToMe(root) {
    const p = this.load();
    if (!p) return;
    const img = root.querySelector('[data-profile="petPhoto"]');
    const name = root.querySelector('[data-profile="petName"]');
    const sub = root.querySelector('[data-profile="petSub"]');
    const owner = root.querySelector('[data-profile="ownerLine"]');
    const area = root.querySelector('[data-profile="playArea"]');
    const slug = root.querySelector('[data-profile="slug"]');
    if (img && p.petPhoto) img.src = p.petPhoto;
    if (name) name.textContent = p.petName || name.textContent;
    if (sub && p.personaCode) {
      sub.textContent = `${p.breed || '柯基'} · ${p.personaCode} ${p.personaTitle || ''}`.trim();
    } else if (sub) sub.textContent = `${p.breed || '柯基'} · ENFP 社交小太陽`;
    if (owner) owner.textContent = this.ownerRevealed(p) || '主人 · 現場揭曉';
    if (area && p.playArea) area.textContent = p.playArea;
    if (slug) slug.textContent = `petsoul.app/c/${this.slugFromName(p.petName)}`;
  },

  applyToCard(root) {
    const p = this.load();
    if (!p) return;
    const hero = root.querySelector('[data-profile="petPhoto"]');
    const name = root.querySelector('[data-profile="petName"]');
    const breed = root.querySelector('[data-profile="breed"]');
    const clue = root.querySelector('[data-profile="ownerClue"]');
    const owner = root.querySelector('[data-profile="ownerRevealed"]');
    if (hero && p.petPhoto) hero.src = p.petPhoto;
    if (name) name.textContent = p.petName || '豆包';
    if (breed && p.personaCode) {
      breed.textContent = `${p.breed || '柯基'} · ${p.personaCode} · ${p.personaTitle || ''}`.trim();
    } else if (breed) breed.textContent = `${p.breed || '柯基'} · 社交小太陽`;
    if (clue) clue.textContent = p.ownerClue || this.formatClue(p.petName, '');
    if (owner) owner.textContent = this.ownerRevealed(p);
  },

  iceHintForMatch(theirIce) {
    const p = this.load();
    const mine = p?.iceHint;
    if (mine && theirIce) return `對方：${theirIce}\n你：${mine}`;
    return theirIce || mine || '同場 · 測驗區附近';
  },
};
