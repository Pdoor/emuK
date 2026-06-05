const statusEl = document.querySelector("#status");
const reconnectButton = document.querySelector("#reconnect");
const textInput = document.querySelector("#textInput");

let socket;
let reconnectTimer;

function setStatus(text, state) {
  statusEl.textContent = text;
  document.body.dataset.state = state;
}

function wsUrl() {
  const protocol = location.protocol === "https:" ? "wss:" : "ws:";
  return `${protocol}//${location.host}/ws`;
}

function connect() {
  clearTimeout(reconnectTimer);
  setStatus("Connessione...", "connecting");

  socket = new WebSocket(wsUrl());
  socket.addEventListener("open", () => setStatus("Connesso a Windows", "online"));
  socket.addEventListener("close", () => {
    setStatus("Disconnesso, ritento...", "offline");
    reconnectTimer = setTimeout(connect, 1200);
  });
  socket.addEventListener("error", () => setStatus("Errore di connessione", "offline"));
}

function send(payload) {
  if (!socket || socket.readyState !== WebSocket.OPEN) {
    setStatus("Non connesso", "offline");
    return;
  }
  socket.send(JSON.stringify(payload));
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
