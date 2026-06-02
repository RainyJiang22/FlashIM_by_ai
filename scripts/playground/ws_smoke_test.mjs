#!/usr/bin/env node

const url = process.argv[2] ?? "ws://127.0.0.1:9600/ws";
const message = process.argv[3] ?? "hello websocket";
const expectedWelcome = "welcome to flash_im websocket";
const expectedEcho = `echo: ${message}`;

let receivedWelcome = false;
let receivedEcho = false;
let finished = false;

const socket = new WebSocket(url);
const timeout = setTimeout(() => {
  console.error(`timeout: no complete websocket response from ${url}`);
  socket.close();
  process.exit(1);
}, 5000);

socket.addEventListener("open", () => {
  console.log(`connected: ${url}`);
});

socket.addEventListener("message", (event) => {
  const text = String(event.data);
  console.log(`received: ${text}`);

  if (!receivedWelcome) {
    if (text !== expectedWelcome) {
      console.error(`unexpected welcome message: ${text}`);
      clearTimeout(timeout);
      socket.close();
      process.exit(1);
    }

    receivedWelcome = true;
    socket.send(message);
    console.log(`sent: ${message}`);
    return;
  }

  if (!receivedEcho) {
    if (text !== expectedEcho) {
      console.error(`unexpected echo message: ${text}`);
      clearTimeout(timeout);
      socket.close();
      process.exit(1);
    }

    receivedEcho = true;
    finished = true;
    clearTimeout(timeout);
    console.log("websocket smoke test passed");
    socket.close(1000, "done");
  }
});

socket.addEventListener("close", (event) => {
  console.log(`closed: code=${event.code} reason=${event.reason || "-"}`);
  if (receivedWelcome && receivedEcho) {
    process.exit(0);
  }
});

socket.addEventListener("error", () => {
  if (finished) {
    return;
  }
  console.error(`websocket connection failed: ${url}`);
  clearTimeout(timeout);
  process.exit(1);
});
