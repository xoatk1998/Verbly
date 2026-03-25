(() => {
  let overlayHost = null;

  function escapeRegex(str) {
    return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  function normalize(str) {
    return str.toLowerCase().trim()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .replace(/đ/g, 'd')
      .replace(/\s+/g, ' ');
  }

  function checkAnswer(input, correct) {
    return normalize(input) === normalize(correct);
  }

  function buildSentenceHTML(sentence, englishWord, direction) {
    if (!sentence) return '';
    const regex = new RegExp(escapeRegex(englishWord), 'gi');
    if (direction === 'en-to-vn') {
      return sentence.replace(regex, m => `<span class="word-highlight">${m}</span>`);
    } else {
      return sentence.replace(regex, '<span class="word-blank">___</span>');
    }
  }

  function difficultyClass(d) {
    return { B1: 'diff-b1', B2: 'diff-b2', C1: 'diff-c1', C2: 'diff-c2' }[d] || 'diff-b1';
  }

  chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
    if (message.type === 'SHOW_WORD_SESSION') {
      showSession(message.questions, message.streak || 0, message.sessionTimeoutSeconds ?? 90);
      sendResponse({ ok: true });
    }
    if (message.type === 'SHOW_WORD_QUIZ') {
      showSession([{ word: message.word, direction: 'en-to-vn', answerType: 'choice', options: message.options }], 0, 90);
      sendResponse({ ok: true });
    }
    return true;
  });

  function showSession(questions, initialStreak, timeoutSeconds) {
    if (overlayHost) { overlayHost.remove(); overlayHost = null; }
    if (!questions || questions.length === 0) return;

    overlayHost = document.createElement('div');
    overlayHost.id = 'lnw-host';
    Object.assign(overlayHost.style, { position: 'fixed', inset: '0', zIndex: '2147483647', pointerEvents: 'auto' });
    document.body.appendChild(overlayHost);

    const shadow = overlayHost.attachShadow({ mode: 'open' });
    shadow.innerHTML = `<style>${getStyles()}</style><div id="backdrop"><div id="card"></div></div>`;

    const card = shadow.getElementById('card');

    const state = {
      questions,
      index: 0,
      streak: initialStreak,
      results: [],
      firstAttempt: true,
      timeoutSeconds,
      timeoutTimer: null
    };

    renderQuestion(card, shadow, state);
  }

  function startTimeout(card, shadow, state) {
    if (state.timeoutTimer) clearTimeout(state.timeoutTimer);
    const secs = state.timeoutSeconds;
    if (!secs || secs <= 0) return;

    // Animate bar
    const bar = shadow.getElementById('timeout-bar-fill');
    if (bar) {
      bar.style.transition = 'none';
      bar.style.width = '100%';
      requestAnimationFrame(() => requestAnimationFrame(() => {
        bar.style.transition = `width ${secs}s linear`;
        bar.style.width = '0%';
      }));
    }

    state.timeoutTimer = setTimeout(() => closeOverlay(), secs * 1000);
  }

  function clearSessionTimeout(state) {
    if (state.timeoutTimer) { clearTimeout(state.timeoutTimer); state.timeoutTimer = null; }
  }

  function renderQuestion(card, shadow, state) {
    if (card._keyHandler) { document.removeEventListener('keydown', card._keyHandler); card._keyHandler = null; }

    const { questions, index, streak, timeoutSeconds } = state;
    const { word, direction, answerType, options } = questions[index];
    const total = questions.length;

    const promptLabel = direction === 'en-to-vn' ? 'Từ tiếng Anh:' : 'Từ tiếng Việt:';
    const displayWord = direction === 'en-to-vn' ? word.english : word.vietnamese;
    const correctAnswer = direction === 'en-to-vn' ? word.vietnamese : word.english;
    const sentenceHTML = buildSentenceHTML(word.exampleSentence, word.english, direction);
    const answerLabel = direction === 'en-to-vn' ? 'Nghĩa tiếng Việt là:' : 'Từ tiếng Anh là:';

    state.firstAttempt = true;

    card.innerHTML = `
      ${timeoutSeconds > 0 ? '<div id="timeout-bar"><div id="timeout-bar-fill"></div></div>' : ''}
      <div id="top-bar">
        <div id="progress">${index + 1} / ${total}</div>
        <div id="badges">
          ${word.difficulty ? `<span class="badge ${difficultyClass(word.difficulty)}">${word.difficulty}</span>` : ''}
          ${word.category ? `<span class="badge cat-badge">${word.category}</span>` : ''}
        </div>
      </div>

      <div id="prompt-label">${promptLabel}</div>
      <div id="word-display">
        ${displayWord}
        ${direction === 'en-to-vn' ? `<button id="speak-btn" title="Phát âm">🔊</button>` : ''}
      </div>

      ${word.exampleSentence ? `
        <div id="sentence-area">
          <div id="sentence">"${sentenceHTML}"</div>
          ${word.englishMeaning ? `<button id="hint-btn">💡 Gợi ý</button><div id="hint-text" hidden>${word.englishMeaning}</div>` : ''}
        </div>
      ` : (word.englishMeaning ? `
        <div id="sentence-area">
          <button id="hint-btn">💡 Gợi ý</button>
          <div id="hint-text" hidden>${word.englishMeaning}</div>
        </div>
      ` : '')}

      <div id="answer-label">${answerLabel}</div>

      ${answerType === 'choice' ? `
        <div id="options-grid">
          ${(options || []).map(opt => `<button class="option" data-value="${escAttr(opt)}">${opt}</button>`).join('')}
        </div>
      ` : `
        <div id="typing-area">
          <input type="text" id="answer-input" placeholder="${direction === 'en-to-vn' ? 'Gõ nghĩa tiếng Việt...' : 'Type the English word...'}" autocomplete="off" spellcheck="false" />
          <button id="check-btn">Kiểm tra</button>
        </div>
      `}

      <div id="error-msg" hidden></div>
      <button id="known-btn">✓ Tôi đã biết từ này rồi</button>

      <div id="footer">
        <div id="streak-display">🔥 Streak: <strong>${streak}</strong></div>
        <div id="countdown-display"></div>
      </div>
    `;

    // Next-popup countdown
    chrome.runtime.sendMessage({ type: 'GET_NEXT_ALARM' }).then(({ scheduledTime }) => {
      const el = shadow.getElementById('countdown-display');
      if (!el || !scheduledTime) return;
      const tick = () => {
        const r = scheduledTime - Date.now();
        if (r <= 0) { el.textContent = ''; return; }
        const m = Math.floor(r / 60000), s = Math.floor((r % 60000) / 1000);
        el.textContent = `${m}:${s.toString().padStart(2, '0')}`;
      };
      tick();
      const iv = setInterval(() => { if (!overlayHost?.isConnected) { clearInterval(iv); return; } tick(); }, 1000);
    }).catch(() => {});

    // Auto-close timeout
    startTimeout(card, shadow, state);

    // Hint
    const hintBtn = shadow.getElementById('hint-btn');
    const hintText = shadow.getElementById('hint-text');
    // Speak button
    const speakBtn = shadow.getElementById('speak-btn');
    if (speakBtn) {
      const speak = () => {
        speechSynthesis.cancel();
        const utt = new SpeechSynthesisUtterance(word.english);
        utt.lang = 'en-US';
        speechSynthesis.speak(utt);
      };
      speakBtn.addEventListener('click', speak);
      speak(); // auto-play on first render
    }

    if (hintBtn && hintText) {
      hintBtn.addEventListener('click', () => { hintText.hidden = false; hintBtn.textContent = '💡 Đã dùng gợi ý'; hintBtn.disabled = true; });
    }

    // Mark as known
    shadow.getElementById('known-btn')?.addEventListener('click', () => {
      clearSessionTimeout(state);
      chrome.runtime.sendMessage({ type: 'MARK_KNOWN', wordId: word.id }).catch(() => {});
      state.index++;
      if (state.index < questions.length) renderQuestion(card, shadow, state);
      else renderSummary(card, shadow, state);
    });

    // Answer handlers
    if (answerType === 'choice') {
      shadow.querySelectorAll('.option').forEach(btn => {
        btn.addEventListener('click', () => handleChoiceAnswer(btn.dataset.value, correctAnswer, card, shadow, state));
      });
      const keyHandler = e => {
        const idx = ['1','2','3','4'].indexOf(e.key);
        if (idx !== -1) { const btns = shadow.querySelectorAll('.option'); if (btns[idx]) btns[idx].click(); }
      };
      document.addEventListener('keydown', keyHandler);
      card._keyHandler = keyHandler;
    } else {
      const input = shadow.getElementById('answer-input');
      const checkBtn = shadow.getElementById('check-btn');
      const submit = () => handleTypingAnswer(input.value, correctAnswer, card, shadow, state);
      checkBtn?.addEventListener('click', submit);
      input?.addEventListener('keydown', e => { if (e.key === 'Enter') submit(); });
      setTimeout(() => input?.focus(), 50);
    }
  }

  function escAttr(str) {
    return str.replace(/"/g, '&quot;').replace(/'/g, '&#39;');
  }

  function handleChoiceAnswer(selected, correct, card, shadow, state) {
    const isCorrect = selected === correct;
    shadow.querySelectorAll('.option').forEach(btn => {
      btn.disabled = true;
      if (btn.dataset.value === correct) btn.classList.add('correct');
      else if (btn.dataset.value === selected && !isCorrect) btn.classList.add('wrong');
    });
    if (isCorrect) onCorrect(card, shadow, state);
    else onWrong(card, shadow, state, () => {
      shadow.querySelectorAll('.option').forEach(btn => { btn.disabled = false; btn.classList.remove('correct', 'wrong'); });
    });
  }

  function handleTypingAnswer(input, correct, card, shadow, state) {
    const isCorrect = checkAnswer(input, correct);
    const inputEl = shadow.getElementById('answer-input');
    if (isCorrect) {
      if (inputEl) { inputEl.disabled = true; inputEl.classList.add('input-correct'); }
      const checkBtn = shadow.getElementById('check-btn');
      if (checkBtn) checkBtn.disabled = true;
      onCorrect(card, shadow, state);
    } else {
      if (inputEl) {
        inputEl.classList.add('input-wrong', 'shake');
        setTimeout(() => { inputEl.classList.remove('shake', 'input-wrong'); inputEl.value = ''; inputEl.focus(); }, 600);
      }
      onWrong(card, shadow, state, null);
    }
  }

  function onCorrect(card, shadow, state) {
    clearSessionTimeout(state);
    const { questions, index, streak } = state;
    const { word } = questions[index];

    state.results.push(true);
    state.streak = streak + 1;

    chrome.runtime.sendMessage({ type: 'RECORD_ANSWER', wordId: word.id, correct: true, isFirstAttempt: true }).catch(() => {});

    const errorEl = shadow.getElementById('error-msg');
    if (errorEl) { errorEl.hidden = false; errorEl.className = 'success-msg'; errorEl.textContent = '✓ Chính xác!'; }

    const streakEl = shadow.getElementById('streak-display');
    if (streakEl) streakEl.innerHTML = `🔥 Streak: <strong>${state.streak}</strong>`;

    // Disable "known" button during advance
    const knownBtn = shadow.getElementById('known-btn');
    if (knownBtn) knownBtn.disabled = true;

    if (card._keyHandler) { document.removeEventListener('keydown', card._keyHandler); card._keyHandler = null; }

    setTimeout(() => {
      state.index++;
      if (state.index < questions.length) renderQuestion(card, shadow, state);
      else renderSummary(card, shadow, state);
    }, 1000);
  }

  function onWrong(card, shadow, state, retryCallback) {
    const { questions, index } = state;
    const { word } = questions[index];

    const errorEl = shadow.getElementById('error-msg');
    if (errorEl) { errorEl.hidden = false; errorEl.className = ''; errorEl.textContent = 'Sai rồi! Thử lại nhé 💪'; }

    if (state.firstAttempt) {
      state.firstAttempt = false;
      state.results.push(false);
      chrome.runtime.sendMessage({ type: 'RECORD_ANSWER', wordId: word.id, correct: false, isFirstAttempt: true }).catch(() => {});
      state.streak = 0;
      const streakEl = shadow.getElementById('streak-display');
      if (streakEl) streakEl.innerHTML = `🔥 Streak: <strong>0</strong>`;
    }

    if (retryCallback) setTimeout(retryCallback, 500);
  }

  function renderSummary(card, shadow, state) {
    if (card._keyHandler) { document.removeEventListener('keydown', card._keyHandler); card._keyHandler = null; }

    const total = state.results.length;
    const correct = state.results.filter(Boolean).length;
    const icons = state.results.map(r => r ? '<span class="res-correct">✓</span>' : '<span class="res-wrong">✗</span>').join('');

    card.innerHTML = `
      <div id="summary">
        <div id="summary-emoji">${correct === total ? '🎉' : correct >= total / 2 ? '👍' : '💪'}</div>
        <div id="summary-title">Hoàn thành buổi học!</div>
        <div id="summary-icons">${icons}</div>
        <div id="summary-score">Đúng: <strong>${correct}</strong> / ${total}</div>
        <div id="summary-streak">Streak: <strong>${state.streak}</strong> 🔥</div>
        <button id="continue-btn">Tiếp tục →</button>
      </div>
    `;

    shadow.getElementById('continue-btn')?.addEventListener('click', closeOverlay);

    const keyHandler = e => { if (e.key === 'Enter' || e.key === 'Escape') closeOverlay(); };
    document.addEventListener('keydown', keyHandler);
    card._keyHandler = keyHandler;

    shadow.getElementById('backdrop')?.addEventListener('click', e => {
      if (e.target === shadow.getElementById('backdrop')) closeOverlay();
    });
  }

  function closeOverlay() {
    if (overlayHost) {
      const card = overlayHost.shadowRoot?.getElementById('card');
      if (card?._keyHandler) document.removeEventListener('keydown', card._keyHandler);
      overlayHost.style.opacity = '0';
      overlayHost.style.transition = 'opacity 0.2s ease';
      setTimeout(() => { overlayHost?.remove(); overlayHost = null; }, 220);
    }
  }

  function getStyles() {
    return `
      * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }
      :host { position: fixed !important; inset: 0 !important; z-index: 2147483647 !important; }

      #backdrop {
        position: fixed; inset: 0;
        background: linear-gradient(150deg, rgba(12, 52, 30, 0.94), rgba(6, 36, 18, 0.94));
        backdrop-filter: blur(8px); -webkit-backdrop-filter: blur(8px);
        display: flex; align-items: center; justify-content: center;
        animation: fadeIn 0.2s ease;
      }

      @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
      @keyframes slideUp {
        from { opacity: 0; transform: translateY(20px) scale(0.97); }
        to   { opacity: 1; transform: translateY(0) scale(1); }
      }
      @keyframes shake {
        0%, 100% { transform: translateX(0); }
        20% { transform: translateX(-8px); } 40% { transform: translateX(8px); }
        60% { transform: translateX(-6px); } 80% { transform: translateX(6px); }
      }

      #card {
        background: #fff; border-radius: 24px; overflow: hidden;
        padding: 0 32px 24px;
        width: 100%; max-width: 520px; margin: 20px;
        box-shadow: 0 32px 80px rgba(0,0,0,0.45);
        animation: slideUp 0.28s cubic-bezier(0.34, 1.4, 0.64, 1);
      }

      /* Timeout bar */
      #timeout-bar { height: 4px; background: rgba(0,0,0,0.08); margin: 0 -32px 20px; }
      #timeout-bar-fill { height: 100%; background: linear-gradient(90deg, #10b981, #6366f1); width: 100%; }

      /* Top bar */
      #top-bar { display: flex; align-items: center; gap: 8px; margin-bottom: 20px; padding-top: 24px; }
      #progress { font-size: 12px; font-weight: 700; color: #6366f1; background: #eef2ff; padding: 3px 10px; border-radius: 100px; }
      #badges { display: flex; gap: 6px; flex: 1; }
      .badge { font-size: 11px; font-weight: 700; padding: 3px 8px; border-radius: 6px; }
      .diff-b1 { background: #d1fae5; color: #065f46; }
      .diff-b2 { background: #dbeafe; color: #1e40af; }
      .diff-c1 { background: #fed7aa; color: #92400e; }
      .diff-c2 { background: #fee2e2; color: #991b1b; }
      .cat-badge { background: #f3f4f6; color: #6b7280; }

      #prompt-label { font-size: 11px; font-weight: 700; color: #9ca3af; text-transform: uppercase; letter-spacing: 0.08em; margin-bottom: 6px; }
      #word-display { font-size: 46px; font-weight: 800; color: #111827; letter-spacing: -0.02em; line-height: 1.1; margin-bottom: 16px; display: flex; align-items: center; gap: 12px; flex-wrap: wrap; }
      #speak-btn { font-size: 22px; background: none; border: none; cursor: pointer; padding: 4px; opacity: 0.6; transition: opacity 0.15s, transform 0.15s; flex-shrink: 0; line-height: 1; }
      #speak-btn:hover { opacity: 1; transform: scale(1.15); }

      #sentence-area { margin-bottom: 18px; }
      #sentence { font-size: 14px; color: #6b7280; line-height: 1.6; font-style: italic; padding: 10px 14px; background: #f9fafb; border-radius: 10px; border-left: 3px solid #6366f1; margin-bottom: 8px; }
      .word-highlight { color: #ef4444; font-weight: 700; font-style: normal; }
      .word-blank { color: #6366f1; font-weight: 700; font-style: normal; }
      #hint-btn { background: none; border: 1.5px solid #e5e7eb; border-radius: 8px; padding: 5px 12px; font-size: 12px; font-weight: 600; color: #6b7280; cursor: pointer; transition: all 0.15s; }
      #hint-btn:hover:not(:disabled) { border-color: #f59e0b; color: #d97706; background: #fffbeb; }
      #hint-btn:disabled { opacity: 0.6; cursor: default; }
      #hint-text { margin-top: 8px; font-size: 13px; color: #374151; line-height: 1.5; padding: 8px 12px; background: #fffbeb; border-radius: 8px; border: 1.5px solid #fde68a; }

      #answer-label { font-size: 12px; font-weight: 600; color: #6b7280; margin-bottom: 12px; }

      #options-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-bottom: 12px; }
      .option { padding: 13px 10px; border: 2px solid #e5e7eb; border-radius: 14px; background: #fafafa; font-size: 14px; color: #374151; cursor: pointer; text-align: center; transition: all 0.15s; font-weight: 500; line-height: 1.35; }
      .option:hover:not(:disabled) { border-color: #6366f1; background: #eef2ff; color: #4338ca; transform: translateY(-1px); }
      .option.correct { border-color: #10b981; background: #d1fae5; color: #065f46; }
      .option.wrong { border-color: #ef4444; background: #fee2e2; color: #991b1b; animation: shake 0.5s ease; }
      .option:disabled { cursor: default; transform: none; }

      #typing-area { display: flex; gap: 8px; margin-bottom: 12px; }
      #answer-input { flex: 1; padding: 12px 14px; border: 2px solid #e5e7eb; border-radius: 12px; font-size: 15px; outline: none; transition: border-color 0.15s; background: #fafafa; color: #111827; }
      #answer-input:focus { border-color: #6366f1; background: #fff; }
      #answer-input.input-correct { border-color: #10b981; background: #d1fae5; }
      #answer-input.input-wrong { border-color: #ef4444; background: #fee2e2; }
      #answer-input.shake { animation: shake 0.5s ease; }
      #check-btn { padding: 12px 18px; background: #6366f1; color: #fff; border: none; border-radius: 12px; font-size: 14px; font-weight: 700; cursor: pointer; transition: background 0.15s; white-space: nowrap; }
      #check-btn:hover { background: #4f46e5; }
      #check-btn:disabled { background: #a5b4fc; cursor: default; }

      #error-msg { font-size: 13px; font-weight: 600; color: #ef4444; padding: 8px 12px; background: #fee2e2; border-radius: 8px; margin-bottom: 10px; text-align: center; }
      #error-msg.success-msg { color: #065f46; background: #d1fae5; }

      #known-btn { display: block; width: 100%; padding: 0; margin-bottom: 14px; background: none; border: none; font-size: 12px; color: #9ca3af; cursor: pointer; text-align: center; transition: color 0.15s; font-weight: 500; }
      #known-btn:hover:not(:disabled) { color: #10b981; }
      #known-btn:disabled { opacity: 0.4; cursor: default; }

      #footer { display: flex; justify-content: space-between; align-items: center; padding-top: 12px; border-top: 1.5px solid #f3f4f6; font-size: 12px; color: #9ca3af; font-weight: 600; }
      #streak-display strong { color: #f59e0b; }

      #summary { text-align: center; padding: 24px 0 10px; }
      #summary-emoji { font-size: 48px; margin-bottom: 10px; }
      #summary-title { font-size: 22px; font-weight: 800; color: #111827; margin-bottom: 16px; }
      #summary-icons { font-size: 22px; letter-spacing: 4px; margin-bottom: 12px; }
      .res-correct { color: #10b981; }
      .res-wrong { color: #ef4444; }
      #summary-score { font-size: 16px; color: #374151; margin-bottom: 6px; }
      #summary-score strong { color: #111827; font-size: 20px; }
      #summary-streak { font-size: 14px; color: #6b7280; margin-bottom: 24px; }
      #summary-streak strong { color: #f59e0b; }
      #continue-btn { padding: 14px 40px; background: #6366f1; color: #fff; border: none; border-radius: 14px; font-size: 16px; font-weight: 700; cursor: pointer; transition: all 0.15s; }
      #continue-btn:hover { background: #4f46e5; transform: translateY(-1px); box-shadow: 0 4px 14px rgba(99,102,241,0.4); }
    `;
  }
})();
