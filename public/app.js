"use strict";

const statuses = { todo: "未着手", doing: "進行中", done: "完了" };
const form = document.querySelector("#task-form");
const titleInput = document.querySelector("#task-title");
const titleCount = document.querySelector("#title-count");
const createButton = document.querySelector("#create-button");
const filter = document.querySelector("#status-filter");
const reloadButton = document.querySelector("#reload-button");
const listArea = document.querySelector("#task-list-area");
const list = document.querySelector("#task-list");
const taskCount = document.querySelector("#task-count");
const emptyMessage = document.querySelector("#empty-message");
const errorMessage = document.querySelector("#error-message");
const noticeMessage = document.querySelector("#notice-message");
const requestOutput = document.querySelector("#api-request");
const responseOutput = document.querySelector("#api-response");
const apiStatus = document.querySelector("#api-status");
let busy = false;

function updateTitleCount() {
  const length = Array.from(titleInput.value).length;
  titleCount.textContent = `${length} / 100`;
  titleInput.setCustomValidity(length > 100 ? "タイトルは100文字以内で入力してください。" : "");
}

function setBusy(value) {
  busy = value;
  listArea.setAttribute("aria-busy", String(value));
  document.querySelectorAll("button, input, select").forEach((control) => {
    control.disabled = value;
  });
}

function showError(error) {
  errorMessage.textContent = error.message;
  errorMessage.hidden = false;
}

async function perform(action) {
  if (busy) return;
  errorMessage.hidden = true;
  noticeMessage.textContent = "";
  setBusy(true);
  try {
    await action();
  } catch (error) {
    showError(error);
  } finally {
    setBusy(false);
  }
}

async function apiRequest(path, { method = "GET", body, capture = true } = {}) {
  const headers = { Accept: "application/json" };
  if (body !== undefined) headers["Content-Type"] = "application/json";
  if (capture) {
    requestOutput.textContent = `${method} ${path}${body === undefined ? "" : `\n\n${JSON.stringify(body, null, 2)}`}`;
    responseOutput.textContent = "受信待ち…";
    apiStatus.textContent = "送信中";
  }

  let response;
  let rawBody;
  try {
    response = await fetch(path, {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    rawBody = await response.text();
  } catch {
    if (capture) {
      apiStatus.textContent = "通信失敗";
      responseOutput.textContent = "サーバーに接続できませんでした。";
    }
    throw new Error("サーバーに接続できませんでした。Railsの起動を確認して、再読み込みしてください。");
  }

  let data;
  try {
    data = rawBody ? JSON.parse(rawBody) : null;
  } catch {
    data = rawBody;
  }
  if (capture) {
    apiStatus.textContent = `${response.status} ${response.statusText}`.trim();
    responseOutput.textContent = typeof data === "string" ? data : JSON.stringify(data, null, 2);
  }
  if (!response.ok) {
    const detail = data && typeof data === "object" ? data.detail || data.error || data.title : null;
    const description = typeof detail === "string"
      ? `：${detail}`
      : capture ? "。下のレスポンスを確認してください。" : "。一覧を再読み込みしてください。";
    throw new Error(`APIがエラーを返しました（HTTP ${response.status}）${description}`);
  }
  return data;
}

function renderTasks(tasks) {
  const fragment = document.createDocumentFragment();
  tasks.forEach((task) => {
    const row = document.createElement("li");
    row.className = "task-row";
    row.dataset.status = task.status;

    const mark = document.createElement("span");
    mark.className = "task-mark";
    mark.setAttribute("aria-hidden", "true");

    const text = document.createElement("div");
    text.className = "task-text";
    const title = document.createElement("p");
    title.className = "task-title";
    title.textContent = task.title;
    const meta = document.createElement("span");
    meta.className = "task-meta";
    meta.textContent = `#${task.id}`;
    text.append(title, meta);

    const statusWrapper = document.createElement("div");
    statusWrapper.className = "task-status";
    const label = document.createElement("label");
    label.className = "visually-hidden";
    label.htmlFor = `task-status-${task.id}`;
    label.textContent = `「${task.title}」の状態`;
    const select = document.createElement("select");
    select.id = label.htmlFor;
    Object.entries(statuses).forEach(([value, caption]) => {
      const option = document.createElement("option");
      option.value = value;
      option.textContent = caption;
      select.append(option);
    });
    select.value = task.status;
    select.disabled = busy;
    select.addEventListener("change", async () => {
      const newStatus = select.value;
      await perform(async () => {
        try {
          await apiRequest(`/api/tasks/${task.id}`, { method: "PATCH", body: { status: newStatus } });
        } catch (error) {
          select.value = task.status;
          throw error;
        }
        noticeMessage.textContent = `「${task.title}」を${statuses[newStatus]}に変更しました。`;
        await loadTasks(false);
      });
      (document.getElementById(select.id) || filter).focus();
    });
    statusWrapper.append(label, select);
    row.append(mark, text, statusWrapper);
    fragment.append(row);
  });
  list.replaceChildren(fragment);
  taskCount.textContent = `${tasks.length}件`;
  emptyMessage.hidden = tasks.length > 0;
  emptyMessage.textContent = filter.value
    ? "この状態のタスクはありません。ほかの状態でも確認してみましょう。"
    : "タスクはまだありません。上の入力欄から追加してください。";
}

async function loadTasks(capture = true) {
  const query = filter.value ? `?status=${encodeURIComponent(filter.value)}` : "";
  const tasks = await apiRequest(`/api/tasks${query}`, { capture });
  if (!Array.isArray(tasks)) throw new Error(`一覧の形式が想定と異なります。${capture ? "下のAPIレスポンスを確認" : "再読み込み"}してください。`);
  renderTasks(tasks);
}

titleInput.addEventListener("input", updateTitleCount);
form.addEventListener("submit", async (event) => {
  event.preventDefault();
  if (busy) return;
  createButton.textContent = "追加中…";
  await perform(async () => {
    await apiRequest("/api/tasks", { method: "POST", body: { title: titleInput.value } });
    form.reset();
    updateTitleCount();
    filter.value = "";
    noticeMessage.textContent = "タスクを追加しました（未着手）。";
    await loadTasks(false);
  });
  createButton.textContent = "タスクを追加";
  titleInput.focus();
});

filter.addEventListener("change", async () => {
  await perform(async () => {
    await loadTasks();
    noticeMessage.textContent = `${filter.value ? statuses[filter.value] : "すべて"}のタスクを表示しました。`;
  });
  filter.focus();
});
reloadButton.addEventListener("click", async () => {
  await perform(async () => {
    await loadTasks();
    noticeMessage.textContent = "一覧を再読み込みしました。";
  });
  reloadButton.focus();
});

perform(async () => {
  try {
    await loadTasks();
  } catch (error) {
    emptyMessage.textContent = "一覧を読み込めませんでした。再読み込みしてください。";
    throw error;
  }
});
