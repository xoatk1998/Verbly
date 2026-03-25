const FIBONACCI = [1, 2, 3, 5, 8, 13, 21, 34, 55, 89];
function getFibInterval(correctCount) {
  return FIBONACCI[Math.min(correctCount, FIBONACCI.length - 1)];
}
const MASTERED_THRESHOLD = 7;
const WORDS_CHUNK_SIZE = 500;

function generateId() {
  return Date.now().toString(36) + Math.random().toString(36).slice(2, 9);
}

// ─── Chunked word storage helpers ────────────────────────────────────────────

async function getStoredWords() {
  const { words_count } = await chrome.storage.local.get('words_count');
  if (words_count !== undefined) {
    const n = Math.ceil(words_count / WORDS_CHUNK_SIZE);
    const keys = Array.from({ length: n }, (_, i) => `words_chunk_${i}`);
    const data = await chrome.storage.local.get(keys);
    return keys.flatMap(k => data[k] || []);
  }
  // Legacy single-key fallback
  const { words } = await chrome.storage.local.get('words');
  return words || [];
}

async function setStoredWords(words) {
  const n = Math.max(1, Math.ceil(words.length / WORDS_CHUNK_SIZE));
  const { words_count: oldCount } = await chrome.storage.local.get('words_count');

  // Remove stale chunks if word count shrank
  if (oldCount !== undefined) {
    const oldN = Math.ceil(oldCount / WORDS_CHUNK_SIZE);
    const stale = [];
    for (let i = n; i < oldN; i++) stale.push(`words_chunk_${i}`);
    if (stale.length) await chrome.storage.local.remove(stale);
  }

  const toSet = { words_count: words.length };
  for (let i = 0; i < n; i++) {
    toSet[`words_chunk_${i}`] = words.slice(i * WORDS_CHUNK_SIZE, (i + 1) * WORDS_CHUNK_SIZE);
  }
  // Remove legacy single key if present
  await chrome.storage.local.remove('words');
  await chrome.storage.local.set(toSet);
}

// ─── CSV / Seed helpers ───────────────────────────────────────────────────────

async function loadSeedWords() {
  try {
    const url = chrome.runtime.getURL('sample.csv');
    const text = await (await fetch(url)).text();
    const lines = text.replace(/\r\n/g, '\n').replace(/\r/g, '\n').trim().split('\n');
    if (lines.length < 2) return [];

    const headers = lines[0].split(',').map(h => h.trim().toLowerCase().replace(/\s+/g, ''));
    const words = [];
    for (let i = 1; i < lines.length; i++) {
      const line = lines[i].trim();
      if (!line) continue;
      const values = parseCSVRow(line);
      const obj = {};
      headers.forEach((h, idx) => { obj[h] = (values[idx] || '').trim(); });
      if (!obj.english || !obj.vietnamese) continue;
      words.push({
        english: obj.english.toLowerCase(),
        vietnamese: obj.vietnamese,
        exampleSentence: obj.examplesentence || '',
        englishMeaning: obj.englishmeaning || '',
        difficulty: ['B1', 'B2', 'C1', 'C2'].includes(obj.difficulty) ? obj.difficulty : 'B1',
        category: obj.category || 'general'
      });
    }
    return words;
  } catch (_) {
    return [];
  }
}

function parseCSVRow(line) {
  const result = [];
  let current = '', inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (ch === '"') {
      if (inQuotes && line[i + 1] === '"') { current += '"'; i++; }
      else inQuotes = !inQuotes;
    } else if (ch === ',' && !inQuotes) {
      result.push(current); current = '';
    } else {
      current += ch;
    }
  }
  result.push(current);
  return result;
}

const DEFAULT_SETTINGS = {
  intervalMinutes: 10,
  enabled: true,
  wordsPerDay: 5,
  wordsPerPopup: 2,
  answerType: 'choice',
  questionDirection: 'mixed',
  selectedDifficulties: [],
  selectedCategories: [],
  sessionTimeoutSeconds: 90
};

const DEFAULT_STATS = {
  correct: 0,
  incorrect: 0,
  streak: 0,
  bestStreak: 0
};

// ─── Install / Startup ───────────────────────────────────────────────────────

chrome.runtime.onInstalled.addListener(async () => {
  const stored = await chrome.storage.local.get(['settings', 'stats', 'userWords', 'popupCount']);
  let words = await getStoredWords();

  if (words.some(w => !w.id)) {
    words = words.map(w => ({
      id: w.id || generateId(),
      english: w.english,
      vietnamese: w.vietnamese,
      exampleSentence: w.exampleSentence || '',
      englishMeaning: w.englishMeaning || '',
      difficulty: w.difficulty || 'B1',
      category: w.category || 'general',
      addedAt: w.addedAt || Date.now()
    }));
  }

  if (words.length === 0) {
    const seedWords = await loadSeedWords();
    words = seedWords.map(w => ({ ...w, id: generateId(), addedAt: Date.now() }));
  }

  const settings = { ...DEFAULT_SETTINGS, ...(stored.settings || {}) };
  await setStoredWords(words);
  await chrome.storage.local.set({
    settings,
    stats: stored.stats || DEFAULT_STATS,
    userWords: stored.userWords || {},
    popupCount: stored.popupCount || 0,
    dailyState: null
  });

  await setupAlarm(settings);
});

chrome.runtime.onStartup.addListener(async () => {
  const { settings } = await chrome.storage.local.get('settings');
  await setupAlarm(settings || DEFAULT_SETTINGS);
});

async function setupAlarm(settings) {
  const interval = settings?.intervalMinutes || 10;
  await chrome.alarms.clear('learnWord');
  chrome.alarms.create('learnWord', { periodInMinutes: interval });
}

// ─── Eligible word pool ───────────────────────────────────────────────────────

function getEligibleWords(words, settings) {
  let pool = words;
  const diffs = settings.selectedDifficulties;
  if (diffs && diffs.length > 0) pool = pool.filter(w => diffs.includes(w.difficulty));
  const cats = settings.selectedCategories;
  if (cats && cats.length > 0) pool = pool.filter(w => cats.includes(w.category));
  return pool.length > 0 ? pool : words;
}

// ─── Alarm ───────────────────────────────────────────────────────────────────

chrome.alarms.onAlarm.addListener(async (alarm) => {
  if (alarm.name !== 'learnWord') return;
  await buildAndShowSession();
});

async function buildAndShowSession() {
  const [words, stored] = await Promise.all([
    getStoredWords(),
    chrome.storage.local.get(['settings', 'userWords', 'popupCount', 'stats'])
  ]);
  const settings = stored.settings || DEFAULT_SETTINGS;
  if (!settings.enabled) return;
  if (words.length === 0) return;

  const userWords = stored.userWords || {};
  const popupCount = (stored.popupCount || 0) + 1;
  await chrome.storage.local.set({ popupCount });

  let dailyState = await refreshDailyState(settings, words, userWords);
  let updatedUserWords = (await chrome.storage.local.get('userWords')).userWords || {};
  let questions = buildQuestions(settings, words, updatedUserWords, popupCount, dailyState);

  if (questions.length === 0) {
    // Today's words are all mastered — reset daily state and pick fresh words
    await chrome.storage.local.set({ dailyState: null });
    dailyState = await refreshDailyState(settings, words, updatedUserWords);
    updatedUserWords = (await chrome.storage.local.get('userWords')).userWords || {};
    questions = buildQuestions(settings, words, updatedUserWords, popupCount, dailyState);
    if (questions.length === 0) return;
  }

  const payload = {
    type: 'SHOW_WORD_SESSION',
    questions,
    streak: stored.stats?.streak || 0,
    sessionTimeoutSeconds: settings.sessionTimeoutSeconds ?? 90
  };

  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab?.id) return;

  try {
    await chrome.tabs.sendMessage(tab.id, payload);
  } catch (_) {
    try {
      await chrome.scripting.executeScript({ target: { tabId: tab.id }, files: ['content.js'] });
      setTimeout(async () => {
        try { await chrome.tabs.sendMessage(tab.id, payload); } catch (_) {}
      }, 200);
    } catch (_) {}
  }
}

async function refreshDailyState(settings, words, userWords) {
  const today = new Date().toLocaleDateString('en-CA');
  const { dailyState } = await chrome.storage.local.get('dailyState');

  if (dailyState?.date === today) return dailyState;

  const eligible = getEligibleWords(words, settings);
  const learnedIds = new Set(Object.keys(userWords));
  const unlearnedWords = eligible.filter(w => !learnedIds.has(w.id));
  const newWords = unlearnedWords.slice(0, settings.wordsPerDay);

  const newState = { date: today, newWordIds: newWords.map(w => w.id) };
  await chrome.storage.local.set({ dailyState: newState });

  if (newWords.length > 0) {
    const updates = { ...userWords };
    for (const w of newWords) {
      if (!updates[w.id]) {
        updates[w.id] = { wordId: w.id, correctCount: 0, incorrectCount: 0, showAfterPopup: 0, lastSeenAt: 0, status: 'new' };
      }
    }
    await chrome.storage.local.set({ userWords: updates });
  }

  return newState;
}

function buildQuestions(settings, words, userWords, popupCount, dailyState) {
  const { wordsPerPopup, answerType, questionDirection } = settings;
  const wordMap = Object.fromEntries(words.map(w => [w.id, w]));
  const todayIds = new Set(dailyState?.newWordIds || []);

  const dueUserWords = Object.values(userWords)
    .filter(uw => wordMap[uw.wordId] && uw.status !== 'mastered' && uw.showAfterPopup <= popupCount)
    .sort((a, b) => a.showAfterPopup - b.showAfterPopup);

  const dueIds = new Set(dueUserWords.map(uw => uw.wordId));
  const newToday = [...todayIds]
    .filter(id => !dueIds.has(id) && userWords[id] && wordMap[id] && userWords[id].status !== 'mastered')
    .map(id => userWords[id]);

  const candidates = [...dueUserWords, ...newToday].slice(0, wordsPerPopup);
  if (candidates.length === 0) return [];

  return candidates.map(uw => {
    const word = wordMap[uw.wordId];
    if (!word) return null;

    const isFirstTime = uw.correctCount === 0 && uw.incorrectCount === 0;
    let direction;
    if (isFirstTime) {
      direction = 'en-to-vn';
    } else if (questionDirection === 'en-to-vn') {
      direction = 'en-to-vn';
    } else if (questionDirection === 'vn-to-en') {
      direction = 'vn-to-en';
    } else {
      direction = Math.random() < 0.5 ? 'en-to-vn' : 'vn-to-en';
    }

    let type;
    if (answerType === 'choice') type = 'choice';
    else if (answerType === 'typing') type = 'typing';
    else type = Math.random() < 0.6 ? 'choice' : 'typing';

    let options = null;
    if (type === 'choice') {
      const correct = direction === 'en-to-vn' ? word.vietnamese : word.english;
      let pool = words.filter(w => w.id !== word.id && w.difficulty === word.difficulty);
      if (pool.length < 3) pool = words.filter(w => w.id !== word.id && w.category === word.category);
      if (pool.length < 3) pool = words.filter(w => w.id !== word.id);

      const distractors = pool
        .sort(() => Math.random() - 0.5)
        .map(w => direction === 'en-to-vn' ? w.vietnamese : w.english)
        .filter((v, i, arr) => arr.indexOf(v) === i && v !== correct)
        .slice(0, 3);

      options = [...distractors, correct].sort(() => Math.random() - 0.5);
    }

    return { word, direction, answerType: type, options };
  }).filter(Boolean);
}

// ─── Message handlers ────────────────────────────────────────────────────────

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {

  if (message.type === 'GET_ALL_WORDS') {
    getStoredWords().then(words => sendResponse({ words }));
    return true;
  }

  if (message.type === 'RECORD_ANSWER') {
    const { wordId, correct, isFirstAttempt } = message;
    chrome.storage.local.get(['userWords', 'popupCount', 'stats']).then(({ userWords = {}, popupCount = 0, stats }) => {
      const s = stats || DEFAULT_STATS;
      const uw = userWords[wordId] || { wordId, correctCount: 0, incorrectCount: 0, showAfterPopup: 0, lastSeenAt: 0, status: 'new' };
      uw.lastSeenAt = Date.now();
      if (correct) {
        uw.correctCount++;
        uw.showAfterPopup = popupCount + getFibInterval(uw.correctCount);
        uw.status = uw.correctCount >= MASTERED_THRESHOLD ? 'mastered' : 'learning';
        s.correct++; s.streak++;
        if (s.streak > s.bestStreak) s.bestStreak = s.streak;
      } else if (isFirstAttempt) {
        uw.incorrectCount++;
        uw.showAfterPopup = popupCount + 1;
        s.incorrect++; s.streak = 0;
      }
      userWords[wordId] = uw;
      chrome.storage.local.set({ userWords, stats: s });
      sendResponse({ stats: s });
    });
    return true;
  }

  if (message.type === 'MARK_KNOWN') {
    chrome.storage.local.get(['userWords', 'popupCount']).then(({ userWords = {}, popupCount = 0 }) => {
      const uw = userWords[message.wordId] || { wordId: message.wordId, correctCount: 0, incorrectCount: 0, showAfterPopup: 0, lastSeenAt: 0, status: 'new' };
      uw.status = 'mastered';
      uw.correctCount = MASTERED_THRESHOLD;
      uw.showAfterPopup = popupCount + 999;
      uw.lastSeenAt = Date.now();
      userWords[message.wordId] = uw;
      chrome.storage.local.set({ userWords });
      sendResponse({ ok: true });
    });
    return true;
  }

  if (message.type === 'IMPORT_WORDS') {
    const { words: incoming } = message;
    getStoredWords().then(async words => {
      const existingMap = Object.fromEntries(words.map(w => [w.english.toLowerCase(), w]));
      let added = 0, updated = 0;
      for (const w of incoming) {
        const key = w.english.toLowerCase();
        if (existingMap[key]) {
          Object.assign(existingMap[key], { vietnamese: w.vietnamese, exampleSentence: w.exampleSentence, englishMeaning: w.englishMeaning, difficulty: w.difficulty, category: w.category });
          updated++;
        } else {
          existingMap[key] = { ...w, id: generateId(), addedAt: Date.now() };
          added++;
        }
      }
      const finalWords = Object.values(existingMap);
      try {
        await setStoredWords(finalWords);
        const saved = await getStoredWords();
        sendResponse({ ok: true, added, updated, total: saved.length });
      } catch (err) {
        sendResponse({ ok: false, error: err?.message || 'Storage write failed', added: 0, updated: 0, total: 0 });
      }
    });
    return true;
  }

  if (message.type === 'GET_LEARNING_STATUS') {
    Promise.all([
      getStoredWords(),
      chrome.storage.local.get(['userWords', 'dailyState', 'settings'])
    ]).then(([words, { userWords = {}, dailyState, settings }]) => {
      const total = words.length;
      let learning = 0, mastered = 0;
      for (const uw of Object.values(userWords)) {
        if (uw.status === 'mastered') mastered++;
        else if (uw.status === 'learning') learning++;
      }
      const today = new Date().toLocaleDateString('en-CA');
      const todayIds = dailyState?.date === today ? (dailyState.newWordIds || []) : [];
      const todayStudied = todayIds.filter(id => userWords[id]?.lastSeenAt > 0).length;
      const categories = [...new Set(words.map(w => w.category).filter(Boolean))].sort();
      sendResponse({ total, new: total - Object.keys(userWords).length, learning, mastered, todayStudied, todayGoal: settings?.wordsPerDay || 5, todayTotal: todayIds.length, categories });
    });
    return true;
  }

  if (message.type === 'UPDATE_SETTINGS') {
    const settings = { ...DEFAULT_SETTINGS, ...message.settings };
    chrome.storage.local.set({ settings }).then(() => {
      setupAlarm(settings);
      sendResponse({ ok: true });
    });
    return true;
  }

  if (message.type === 'RESET_STATS') {
    chrome.storage.local.set({ stats: DEFAULT_STATS, userWords: {}, popupCount: 0, dailyState: null }).then(() => sendResponse({ ok: true }));
    return true;
  }

  if (message.type === 'CLEAR_ALL_WORDS') {
    setStoredWords([]).then(() =>
      chrome.storage.local.set({ userWords: {}, popupCount: 0, dailyState: null })
    ).then(() => sendResponse({ ok: true }));
    return true;
  }

  if (message.type === 'RESET_TO_DEFAULT') {
    loadSeedWords().then(async seedWords => {
      const words = seedWords.map(w => ({ ...w, id: generateId(), addedAt: Date.now() }));
      await setStoredWords(words);
      await chrome.storage.local.set({ userWords: {}, popupCount: 0, dailyState: null });
      sendResponse({ ok: true });
    });
    return true;
  }

  if (message.type === 'GET_NEXT_ALARM') {
    chrome.alarms.get('learnWord').then(alarm => sendResponse({ scheduledTime: alarm?.scheduledTime || null }));
    return true;
  }

  if (message.type === 'TRIGGER_NOW') {
    buildAndShowSession().then(() => sendResponse({ ok: true })).catch(() => sendResponse({ ok: false }));
    return true;
  }

  if (message.type === 'DELETE_WORD') {
    getStoredWords().then(async words => {
      const filtered = words.filter(w => w.id !== message.wordId);
      await setStoredWords(filtered);
      const { userWords = {} } = await chrome.storage.local.get('userWords');
      delete userWords[message.wordId];
      await chrome.storage.local.set({ userWords });
      sendResponse({ ok: true });
    });
    return true;
  }
});
