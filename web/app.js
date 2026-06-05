const statusEl = document.querySelector("#status");
const detailEl = document.querySelector("#detail");
const reconnectButton = document.querySelector("#reconnect");
const textInput = document.querySelector("#textInput");

let socket;
let reconnectTimer;
let lastTransport = "http";
const useWebSocket = new URLSearchParams(location.search).get("ws") === "1";

function setStatus(text, state, detail) {
  statusEl.textContent = text;
  document.body.dataset.state = state;
  if (detail) detailEl.textContent = detail;
}

function wsUrl() {
  const protocol = location.protocol === "https:" ? "wss:" : "ws:";
  return `${protocol}//${location.host}/ws`;
}

function connect() {
  clearTimeout(reconnectTimer);
  if (!useWebSocket) {
    checkHttp();
    return;
  }

  setStatus("Connessione WebSocket...", "connecting", `Apro ${wsUrl()}`);

  socket = new WebSocket(wsUrl());
  socket.addEventListener("open", () => {
    lastTransport = "websocket";
    setStatus("Connesso a Windows", "online", "Canale realtime attivo.");
  });
  socket.addEventListener("close", () => {
    setStatus("WebSocket non disponibile", "offline", "Uso il fallback HTTP sui tocchi.");
    reconnectTimer = setTimeout(connect, 1200);
  });
  socket.addEventListener("error", () => setStatus("Errore WebSocket", "offline", "Se la pagina e aperta, provo comunque via HTTP."));
}

async function send(payload) {
  if (!useWebSocket || !socket || socket.readyState !== WebSocket.OPEN) {
    return sendHttp(payload);
  }
  socket.send(JSON.stringify(payload));
  setStatus("Inviato", "online", `Metodo: ${lastTransport}`);
}

async function checkHttp() {
  try {
    const response = await fetch("/api/send", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ type: "ping" }),
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    lastTransport = "http";
    setStatus("Connesso a Windows", "online", "Metodo: HTTP compatibile.");
  } catch (error) {
    setStatus("HTTP non disponibile", "offline", String(error.message || error));
  }
}

async function sendHttp(payload) {
  try {
    const response = await fetch("/api/send", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    lastTransport = "http";
    setStatus("Inviato", "online", "Metodo: HTTP fallback.");
  } catch (error) {
    setStatus("Invio fallito", "offline", String(error.message || error));
  }
}

function pulse(button) {
  button.classList.remove("pressed");
  void button.offsetWidth;
  button.classList.add("pressed");
}

document.addEventListener("click", (event) => {
  const button = event.target.closest("button");
  if (!button) return;
  pulse(button);

  if (button.dataset.text !== undefined) {
    send({ type: "text", text: button.dataset.text });
  }
  if (button.dataset.key) {
    send({ type: "key", key: button.dataset.key });
  }
  if (button.dataset.combo) {
    send({ type: "combo", keys: button.dataset.combo.split(",") });
  }
  if (button.hasAttribute("data-send-text")) {
    send({ type: "text", text: textInput.value });
    textInput.value = "";
    textInput.focus();
  }
  if (button.hasAttribute("data-test")) {
    send({ type: "text", text: "emuK test" });
  }
});

textInput.addEventListener("keydown", (event) => {
  if ((event.ctrlKey || event.metaKey) && event.key === "Enter") {
    event.preventDefault();
    send({ type: "text", text: textInput.value });
    textInput.value = "";
  }
});

reconnectButton.addEventListener("click", connect);
connect();
