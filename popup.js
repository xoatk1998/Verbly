let allWords = [];
let settings = {
  intervalMinutes: 10,
  intervalSeconds: null,
  enabled: true,
  wordsPerDay: 5,
  wordsPerPopup: 2,
  answerType: "choice",
  questionDirection: "mixed",
  selectedDifficulties: [],
  selectedCategories: [],
  sessionTimeoutSeconds: 90,
};
let stats = { correct: 0, incorrect: 0, streak: 0, bestStreak: 0 };
let searchQuery = "";
let countdownInterval = null;

function debounce(fn, ms) {
  let t;
  return (...args) => {
    clearTimeout(t);
    t = setTimeout(() => fn(...args), ms);
  };
}

async function loadData() {
  const [wordsRes, local] = await Promise.all([
    chrome.runtime.sendMessage({ type: "GET_ALL_WORDS" }).catch(() => null),
    chrome.storage.local.get(["settings", "stats"]),
  ]);
  allWords = wordsRes?.words || [];
  settings = { ...settings, ...(local.settings || {}) };
  stats = local.stats || stats;
}

// ─── CSV Parsing ──────────────────────────────────────────────────────────────

function parseCSVRow(line) {
  const result = [];
  let current = "",
    inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (ch === '"') {
      if (inQuotes && line[i + 1] === '"') {
        current += '"';
        i++;
      } else inQuotes = !inQuotes;
    } else if (ch === "," && !inQuotes) {
      result.push(current);
      current = "";
    } else {
      current += ch;
    }
  }
  result.push(current);
  return result;
}

function parseCSV(text) {
  const lines = text
    .replace(/\r\n/g, "\n")
    .replace(/\r/g, "\n")
    .trim()
    .split("\n");
  if (lines.length < 2) return null;

  const headers = parseCSVRow(lines[0]).map((h) =>
    h.trim().toLowerCase().replace(/\s+/g, ""),
  );
  const required = [
    "english",
    "vietnamese",
    "examplesentence",
    "englishmeaning",
    "difficulty",
    "category",
  ];

  if (!required.every((h) => headers.includes(h))) return null;

  const words = [];
  let errorRows = 0;

  for (let i = 1; i < lines.length; i++) {
    const line = lines[i].trim();
    if (!line) continue;
    try {
      const values = parseCSVRow(line);
      const obj = {};
      headers.forEach((h, idx) => {
        obj[h] = (values[idx] || "").trim();
      });

      if (!obj.english || !obj.vietnamese) {
        errorRows++;
        continue;
      }

      words.push({
        english: obj.english.toLowerCase().trim(),
        vietnamese: obj.vietnamese,
        exampleSentence: obj.examplesentence || "",
        englishMeaning: obj.englishmeaning || "",
        difficulty: ["B1", "B2", "C1", "C2"].includes(obj.difficulty)
          ? obj.difficulty
          : "B1",
        category: obj.category || "general",
      });
    } catch (_) {
      errorRows++;
    }
  }

  return { words, errorRows };
}

async function importCSV(text) {
  const parsed = parseCSV(text);
  const resultEl = document.getElementById("import-result");

  if (!parsed) {
    showImportResult(
      "Định dạng CSV không hợp lệ. Vui lòng kiểm tra lại file.",
      "error",
    );
    return;
  }

  if (parsed.words.length === 0) {
    showImportResult("Không tìm thấy từ hợp lệ trong file.", "error");
    return;
  }

  try {
    const res = await chrome.runtime.sendMessage({
      type: "IMPORT_WORDS",
      words: parsed.words,
    });
    if (!res?.ok) {
      showImportResult(`Lỗi lưu dữ liệu: ${res?.error || "unknown"}`, "error");
      return;
    }
    await loadData();
    renderWordList();
    renderAllWords();
    await loadLearningStatus();

    let msg = `Đã thêm ${res.added} từ, cập nhật ${res.updated} từ — tổng trong bộ nhớ: ${res.total}`;
    if (parsed.errorRows > 0) msg += `, bỏ qua ${parsed.errorRows} dòng lỗi`;
    showImportResult(msg, "success");
  } catch (_) {
    showImportResult("Có lỗi xảy ra khi nhập từ.", "error");
  }
}

function showImportResult(msg, type) {
  const el = document.getElementById("import-result");
  el.textContent = msg;
  el.className = "import-result " + type;
  el.hidden = false;
  setTimeout(() => {
    el.hidden = true;
  }, 5000);
}

// ─── Words Tab ────────────────────────────────────────────────────────────────

function escHtml(str) {
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function difficultyClass(d) {
  return (
    { B1: "badge-b1", B2: "badge-b2", C1: "badge-c1", C2: "badge-c2" }[d] ||
    "badge-b1"
  );
}

function renderWordList() {
  const container = document.getElementById("word-list");
  const countEl = document.getElementById("word-count");

  const filtered = allWords.filter(
    (w) =>
      (w.english || "").toLowerCase().includes(searchQuery.toLowerCase()) ||
      (w.vietnamese || "").toLowerCase().includes(searchQuery.toLowerCase()),
  );

  container.innerHTML =
    filtered.length === 0
      ? '<div class="empty-msg">Không có từ nào</div>'
      : filtered
          .map(
            (w) => `
        <div class="word-item" data-id="${escHtml(w.id || "")}">
          <div class="word-main">
            <span class="word-en">${escHtml(w.english)}</span>
            <span class="word-arrow">→</span>
            <span class="word-vn">${escHtml(w.vietnamese)}</span>
          </div>
          <div class="word-meta">
            ${w.difficulty ? `<span class="w-badge ${difficultyClass(w.difficulty)}">${w.difficulty}</span>` : ""}
            ${w.category ? `<span class="w-badge badge-cat">${escHtml(w.category)}</span>` : ""}
          </div>
          <button class="delete-btn" data-id="${escHtml(w.id || "")}" title="Xóa">✕</button>
        </div>
      `,
          )
          .join("");

  countEl.textContent = `${filtered.length} / ${allWords.length} từ`;
}

let lastCategoryKey = null;

function renderCategoryFilter(categories) {
  const key =
    JSON.stringify(categories) + JSON.stringify(settings.selectedCategories);
  if (key === lastCategoryKey) return;
  lastCategoryKey = key;

  const container = document.getElementById("category-filter");
  if (!categories || categories.length === 0) {
    container.innerHTML = '<span class="filter-note">Chưa có chủ đề nào</span>';
    return;
  }
  const sel = settings.selectedCategories || [];
  container.innerHTML = categories
    .map(
      (cat) =>
        `<button class="filter-pill${sel.includes(cat) ? " active" : ""}" data-value="${cat}">${cat}</button>`,
    )
    .join("");
}

async function loadLearningStatus() {
  try {
    const status = await chrome.runtime.sendMessage({
      type: "GET_LEARNING_STATUS",
    });
    document.getElementById("ls-new").textContent = status.new;
    document.getElementById("ls-learning").textContent = status.learning;
    document.getElementById("ls-mastered").textContent = status.mastered;

    const todayEl = document.getElementById("today-value");
    const todayBar = document.getElementById("today-bar");
    if (todayEl) {
      todayEl.textContent = `${status.todayStudied} / ${status.todayTotal} từ hôm nay`;
      const pct =
        status.todayTotal > 0
          ? (status.todayStudied / status.todayTotal) * 100
          : 0;
      if (todayBar) todayBar.style.width = `${pct}%`;
    }

    if (status.categories) renderCategoryFilter(status.categories);
  } catch (_) {}
}

// ─── Stats Tab ────────────────────────────────────────────────────────────────

function renderStats() {
  document.getElementById("stat-correct").textContent = stats.correct;
  document.getElementById("stat-incorrect").textContent = stats.incorrect;
  document.getElementById("stat-streak").textContent = stats.streak;
  document.getElementById("stat-best-streak").textContent = stats.bestStreak;

  const total = stats.correct + stats.incorrect;
  const accuracy = total === 0 ? 0 : Math.round((stats.correct / total) * 100);
  document.getElementById("stat-accuracy").textContent =
    total === 0 ? "--%" : `${accuracy}%`;
  document.getElementById("progress-bar").style.width = `${accuracy}%`;
}

document
  .getElementById("reset-stats-btn")
  .addEventListener("click", async () => {
    if (
      !confirm(
        "Đặt lại tất cả thống kê và tiến độ học?\nThao tác này không thể hoàn tác.",
      )
    )
      return;
    await chrome.runtime.sendMessage({ type: "RESET_STATS" });
    stats = { correct: 0, incorrect: 0, streak: 0, bestStreak: 0 };
    renderStats();
    await loadLearningStatus();
  });

// ─── Settings Tab ─────────────────────────────────────────────────────────────

function renderSettings() {
  document.getElementById("enabled-toggle").checked = settings.enabled;
  document.getElementById("enabled-toggle-settings").checked = settings.enabled;
  document.getElementById("words-per-day").value = settings.wordsPerDay || 5;

  document.querySelectorAll(".interval-btn").forEach((b) => {
    const val = b.dataset.value;
    const isSeconds = val.endsWith("s");
    let active;
    if (settings.intervalSeconds) {
      active = isSeconds && parseInt(val) === settings.intervalSeconds;
    } else {
      active = !isSeconds && parseInt(val) === (settings.intervalMinutes || 10);
    }
    b.classList.toggle("active", active);
  });

  document
    .querySelectorAll(".popup-size-btn")
    .forEach((b) =>
      b.classList.toggle(
        "active",
        parseInt(b.dataset.value) === (settings.wordsPerPopup || 2),
      ),
    );

  document
    .querySelectorAll("#direction-control .seg-btn")
    .forEach((b) =>
      b.classList.toggle(
        "active",
        b.dataset.value === (settings.questionDirection || "mixed"),
      ),
    );

  document
    .querySelectorAll("#answer-type-control .seg-btn")
    .forEach((b) =>
      b.classList.toggle(
        "active",
        b.dataset.value === (settings.answerType || "choice"),
      ),
    );

  const selDiff = settings.selectedDifficulties || [];
  document
    .querySelectorAll("#difficulty-filter .filter-pill")
    .forEach((b) =>
      b.classList.toggle("active", selDiff.includes(b.dataset.value)),
    );

  document
    .querySelectorAll(".timeout-btn")
    .forEach((b) =>
      b.classList.toggle(
        "active",
        parseInt(b.dataset.value) === (settings.sessionTimeoutSeconds ?? 90),
      ),
    );
}

async function saveSettings() {
  await chrome.runtime.sendMessage({ type: "UPDATE_SETTINGS", settings });
  startCountdown();
}

// Enabled toggles (header + settings tab kept in sync)
document
  .getElementById("enabled-toggle")
  .addEventListener("change", async (e) => {
    settings.enabled = e.target.checked;
    document.getElementById("enabled-toggle-settings").checked =
      e.target.checked;
    await saveSettings();
  });
document
  .getElementById("enabled-toggle-settings")
  .addEventListener("change", async (e) => {
    settings.enabled = e.target.checked;
    document.getElementById("enabled-toggle").checked = e.target.checked;
    await saveSettings();
  });

// Interval buttons
document.querySelectorAll(".interval-btn").forEach((btn) => {
  btn.addEventListener("click", async () => {
    const val = btn.dataset.value;
    if (val.endsWith("s")) {
      settings.intervalSeconds = parseInt(val);
    } else {
      settings.intervalSeconds = null;
      settings.intervalMinutes = parseInt(val);
    }
    document
      .querySelectorAll(".interval-btn")
      .forEach((b) => b.classList.remove("active"));
    btn.classList.add("active");
    await saveSettings();
  });
});

// Popup size buttons
document.querySelectorAll(".popup-size-btn").forEach((btn) => {
  btn.addEventListener("click", async () => {
    settings.wordsPerPopup = parseInt(btn.dataset.value);
    document
      .querySelectorAll(".popup-size-btn")
      .forEach((b) => b.classList.remove("active"));
    btn.classList.add("active");
    await saveSettings();
  });
});

// Words per day stepper
document.getElementById("wpd-dec").addEventListener("click", async () => {
  const input = document.getElementById("words-per-day");
  const v = Math.max(1, (parseInt(input.value) || 5) - 1);
  input.value = v;
  settings.wordsPerDay = v;
  await saveSettings();
});
document.getElementById("wpd-inc").addEventListener("click", async () => {
  const input = document.getElementById("words-per-day");
  const v = Math.min(20, (parseInt(input.value) || 5) + 1);
  input.value = v;
  settings.wordsPerDay = v;
  await saveSettings();
});
document
  .getElementById("words-per-day")
  .addEventListener("change", async (e) => {
    const v = Math.max(1, Math.min(20, parseInt(e.target.value) || 5));
    e.target.value = v;
    settings.wordsPerDay = v;
    await saveSettings();
  });

// Direction control
document.querySelectorAll("#direction-control .seg-btn").forEach((btn) => {
  btn.addEventListener("click", async () => {
    settings.questionDirection = btn.dataset.value;
    document
      .querySelectorAll("#direction-control .seg-btn")
      .forEach((b) => b.classList.remove("active"));
    btn.classList.add("active");
    await saveSettings();
  });
});

// Answer type control
document.querySelectorAll("#answer-type-control .seg-btn").forEach((btn) => {
  btn.addEventListener("click", async () => {
    settings.answerType = btn.dataset.value;
    document
      .querySelectorAll("#answer-type-control .seg-btn")
      .forEach((b) => b.classList.remove("active"));
    btn.classList.add("active");
    await saveSettings();
  });
});

// Difficulty filter pills (multi-select toggle)
document.querySelectorAll("#difficulty-filter .filter-pill").forEach((btn) => {
  btn.addEventListener("click", async () => {
    const val = btn.dataset.value;
    const sel = settings.selectedDifficulties || [];
    if (sel.includes(val)) {
      settings.selectedDifficulties = sel.filter((v) => v !== val);
    } else {
      settings.selectedDifficulties = [...sel, val];
    }
    btn.classList.toggle("active", settings.selectedDifficulties.includes(val));
    await saveSettings();
  });
});

// Category filter pills (rendered dynamically, use event delegation)
document
  .getElementById("category-filter")
  .addEventListener("click", async (e) => {
    const btn = e.target.closest(".filter-pill");
    if (!btn) return;
    const val = btn.dataset.value;
    const sel = settings.selectedCategories || [];
    if (sel.includes(val)) {
      settings.selectedCategories = sel.filter((v) => v !== val);
    } else {
      settings.selectedCategories = [...sel, val];
    }
    btn.classList.toggle("active", settings.selectedCategories.includes(val));
    await saveSettings();
  });

// Timeout buttons
document.querySelectorAll(".timeout-btn").forEach((btn) => {
  btn.addEventListener("click", async () => {
    settings.sessionTimeoutSeconds = parseInt(btn.dataset.value);
    document
      .querySelectorAll(".timeout-btn")
      .forEach((b) => b.classList.remove("active"));
    btn.classList.add("active");
    await saveSettings();
  });
});

// Clear all words
document
  .getElementById("clear-words-btn")
  .addEventListener("click", async () => {
    if (!confirm("Xóa toàn bộ từ vựng?\nThao tác này không thể hoàn tác."))
      return;
    await chrome.runtime.sendMessage({ type: "CLEAR_ALL_WORDS" });
    await loadData();
    renderWordList();
    renderAllWords();
    await loadLearningStatus();
    renderCategoryFilter([]);
  });

// Reset to default seed words
document
  .getElementById("reset-default-btn")
  .addEventListener("click", async () => {
    if (
      !confirm(
        "Khôi phục danh sách từ mặc định?\nToàn bộ từ hiện tại và tiến độ sẽ bị xóa.",
      )
    )
      return;
    await chrome.runtime.sendMessage({ type: "RESET_TO_DEFAULT" });
    await loadData();
    stats = { correct: 0, incorrect: 0, streak: 0, bestStreak: 0 };
    renderWordList();
    renderAllWords();
    renderStats();
    await loadLearningStatus();
  });

// ─── Add word ─────────────────────────────────────────────────────────────────

document.getElementById("add-word-btn").addEventListener("click", async () => {
  const engInput = document.getElementById("new-english");
  const vnInput = document.getElementById("new-vietnamese");
  const english = engInput.value.trim().toLowerCase();
  const vietnamese = vnInput.value.trim();
  if (!english || !vietnamese) return;

  const exists = allWords.some((w) => w.english === english);
  if (exists) {
    engInput.style.borderColor = "#ef4444";
    setTimeout(() => {
      engInput.style.borderColor = "";
    }, 1500);
    return;
  }

  const res = await chrome.runtime.sendMessage({
    type: "IMPORT_WORDS",
    words: [
      {
        english,
        vietnamese,
        exampleSentence: "",
        englishMeaning: "",
        difficulty: "B1",
        category: "general",
      },
    ],
  });
  await loadData();
  engInput.value = "";
  vnInput.value = "";
  searchQuery = "";
  document.getElementById("search-input").value = "";
  renderWordList();
  await loadLearningStatus();
});

document.getElementById("new-vietnamese").addEventListener("keydown", (e) => {
  if (e.key === "Enter") document.getElementById("add-word-btn").click();
});

// ─── Delete delegation (set up once, avoids per-render listener attachment) ───

document.getElementById("word-list").addEventListener("click", async (e) => {
  const btn = e.target.closest(".delete-btn");
  if (!btn?.dataset.id) return;
  const id = btn.dataset.id;
  await chrome.runtime.sendMessage({ type: "DELETE_WORD", wordId: id });
  allWords = allWords.filter((w) => w.id !== id);
  renderWordList();
  await loadLearningStatus();
});

document.getElementById("aw-word-list").addEventListener("click", async (e) => {
  const btn = e.target.closest(".delete-btn");
  if (!btn?.dataset.id) return;
  const id = btn.dataset.id;
  await chrome.runtime.sendMessage({ type: "DELETE_WORD", wordId: id });
  allWords = allWords.filter((w) => w.id !== id);
  renderAllWords();
  renderWordList();
  await loadLearningStatus();
});

// ─── Search ───────────────────────────────────────────────────────────────────

document.getElementById("search-input").addEventListener(
  "input",
  debounce((e) => {
    searchQuery = e.target.value;
    renderWordList();
  }, 150),
);

// ─── CSV Import ───────────────────────────────────────────────────────────────

document.getElementById("import-btn").addEventListener("click", () => {
  document.getElementById("csv-file-input").click();
});

document
  .getElementById("csv-file-input")
  .addEventListener("change", async (e) => {
    const file = e.target.files[0];
    if (!file) return;
    e.target.value = ""; // reset so same file can be selected again
    const text = await file.text();
    await importCSV(text);
  });

// ─── All Words Tab ────────────────────────────────────────────────────────────

const AW_PAGE_SIZE = 50;
let awPage = 0;
let awQuery = "";

function renderAllWords() {
  const filtered = allWords.filter(
    (w) =>
      (w.english || "").toLowerCase().includes(awQuery.toLowerCase()) ||
      (w.vietnamese || "").toLowerCase().includes(awQuery.toLowerCase()),
  );
  const totalPages = Math.max(1, Math.ceil(filtered.length / AW_PAGE_SIZE));
  if (awPage >= totalPages) awPage = totalPages - 1;

  const pageWords = filtered.slice(
    awPage * AW_PAGE_SIZE,
    (awPage + 1) * AW_PAGE_SIZE,
  );
  const list = document.getElementById("aw-word-list");
  const pagination = document.getElementById("aw-pagination");
  const count = document.getElementById("aw-count");

  count.textContent = `${filtered.length} / ${allWords.length} từ`;

  list.innerHTML =
    pageWords.length === 0
      ? '<div class="empty-msg">Không có từ nào</div>'
      : pageWords
          .map(
            (w) => `
        <div class="word-item">
          <div class="word-main">
            <span class="word-en">${escHtml(w.english)}</span>
            <span class="word-arrow">→</span>
            <span class="word-vn">${escHtml(w.vietnamese)}</span>
          </div>
          <div class="word-meta">
            ${w.difficulty ? `<span class="w-badge ${difficultyClass(w.difficulty)}">${w.difficulty}</span>` : ""}
            ${w.category ? `<span class="w-badge badge-cat">${escHtml(w.category)}</span>` : ""}
          </div>
          <button class="delete-btn" data-id="${escHtml(w.id || "")}" title="Xóa">✕</button>
        </div>
      `,
          )
          .join("");

  pagination.innerHTML =
    totalPages <= 1
      ? ""
      : `
    <button class="aw-page-btn" id="aw-prev" ${awPage === 0 ? "disabled" : ""}>&#8249; Trước</button>
    <span class="aw-page-info">${awPage + 1} / ${totalPages}</span>
    <button class="aw-page-btn" id="aw-next" ${awPage >= totalPages - 1 ? "disabled" : ""}>Sau &#8250;</button>
  `;

  const prevBtn = document.getElementById("aw-prev");
  const nextBtn = document.getElementById("aw-next");
  if (prevBtn)
    prevBtn.addEventListener("click", () => {
      awPage--;
      renderAllWords();
    });
  if (nextBtn)
    nextBtn.addEventListener("click", () => {
      awPage++;
      renderAllWords();
    });
}

document.getElementById("aw-search").addEventListener(
  "input",
  debounce((e) => {
    awQuery = e.target.value;
    awPage = 0;
    renderAllWords();
  }, 150),
);

// ─── Tabs ─────────────────────────────────────────────────────────────────────

document.querySelectorAll(".tab").forEach((tab) => {
  tab.addEventListener("click", () => {
    document
      .querySelectorAll(".tab")
      .forEach((t) => t.classList.remove("active"));
    document
      .querySelectorAll(".tab-content")
      .forEach((c) => c.classList.remove("active"));
    tab.classList.add("active");
    document.getElementById(`tab-${tab.dataset.tab}`).classList.add("active");
    if (tab.dataset.tab === "all-words") renderAllWords();
  });
});

// ─── Trigger Now ──────────────────────────────────────────────────────────────

document
  .getElementById("trigger-now-btn")
  .addEventListener("click", async () => {
    const btn = document.getElementById("trigger-now-btn");
    btn.textContent = "...";
    btn.disabled = true;
    try {
      const res = await chrome.runtime.sendMessage({ type: "TRIGGER_NOW" });
      if (!res?.ok) {
        const msgs = {
          no_words: "No words found. Import a CSV first.",
          no_questions: "No words due right now.",
          no_tab: "Open a web page first.",
          error: "Something went wrong.",
        };
        btn.textContent = msgs[res?.reason] || "Failed";
        btn.disabled = false;
        setTimeout(() => {
          btn.textContent = "Show now";
        }, 2500);
        return;
      }
    } catch (_) {}
    setTimeout(() => {
      btn.textContent = "Show now";
      btn.disabled = false;
    }, 1200);
  });

// ─── Countdown ────────────────────────────────────────────────────────────────

let cachedAlarmTime = null; // invalidated when settings change

function startCountdown() {
  if (countdownInterval) clearInterval(countdownInterval);
  cachedAlarmTime = null; // reset on every settings save

  const tick = async () => {
    try {
      if (cachedAlarmTime === null) {
        const res = await chrome.runtime.sendMessage({
          type: "GET_NEXT_ALARM",
        });
        cachedAlarmTime = res?.scheduledTime ?? undefined;
      }
      const el = document.getElementById("countdown");
      if (!el) return;
      if (!cachedAlarmTime) {
        el.textContent = "--:--";
        return;
      }
      const r = cachedAlarmTime - Date.now();
      if (r <= 0) {
        el.textContent = "00:00";
        cachedAlarmTime = null;
        return;
      }
      const m = Math.floor(r / 60000),
        s = Math.floor((r % 60000) / 1000);
      el.textContent = `${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}`;
    } catch (_) {}
  };
  tick();
  countdownInterval = setInterval(tick, 1000);
}

// ─── Init ─────────────────────────────────────────────────────────────────────

(async () => {
  await loadData();
  renderWordList();
  renderStats();
  renderSettings();
  await loadLearningStatus();
  startCountdown();
})();
