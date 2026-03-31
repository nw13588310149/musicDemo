import bus from './eventBus.js';

/** 与 api/home.js 中 baseURL 域名一致 */
const API_HOST = 'https://api.yyzl0931.com';
const WS_PATH = '/websocket';

const RECONNECT_MS = 5000;
const HEARTBEAT_MS = 60 * 1000;

function wsDebugOn() {
  try {
    if (typeof localStorage === 'undefined') return true;
    return localStorage.getItem('WS_DEBUG') !== '0';
  } catch (e) {
    return true;
  }
}

function wsLog(...args) {
  if (!wsDebugOn() || typeof console === 'undefined' || !console.log) return;
  console.log('[WS]', ...args);
}

let socket = null;
let reconnectTimer = null;
let heartbeatTimer = null;
let intentionallyClosed = false;
let listenersRegistered = false;

function getWsUrl() {
  const base = (API_HOST || '').trim();
  // 不能写 replace(/^http/, 'wss')：会把 https 变成 wsss
  if (base.startsWith('https://')) {
    return 'wss://' + base.slice('https://'.length) + WS_PATH;
  }
  if (base.startsWith('http://')) {
    return 'ws://' + base.slice('http://'.length) + WS_PATH;
  }
  return base + WS_PATH;
}

function stopHeartbeat() {
  if (heartbeatTimer != null) {
    clearInterval(heartbeatTimer);
    heartbeatTimer = null;
  }
}

function startHeartbeat() {
  stopHeartbeat();
  heartbeatTimer = setInterval(() => {
    if (socket != null && socket.readyState === WebSocket.OPEN) {
      socket.send(JSON.stringify({ type: 100 }));
    }
  }, HEARTBEAT_MS);
}

function normalizeWsType(json) {
  if (!json || typeof json !== 'object') return undefined;
  const t = json.type ?? json.msgType ?? json.messageType;
  if (t === undefined || t === null) return undefined;
  const n = Number(t);
  return Number.isFinite(n) ? n : t;
}

/**
 * 部分场景（如深度思考）下服务端用 type=1 / 10014 推字符串片段，与 type=0 一样需拼接；
 * 带 role、sessionId 等整包特征时仍走 chatgpt-full。
 */
function isLikelyChatGptStreamChunk(json, t) {
  const n = Number(t);
  if (n !== 1 && n !== 10014) return false;
  if (!json || typeof json !== 'object') return false;
  if (typeof json.content !== 'string') return false;
  if (json.replyId == null) return false;
  if (json.role != null) return false;
  if (json.sessionId != null || json.chatSessionId != null) return false;
  return true;
}

function emitParsed(json) {
  const t = normalizeWsType(json);
  wsLog('message parsed type=', t, json);
  bus.emit('ws:message', json);
  // 业务侧：ChatGPT 流式 type=0 片段；结束多为 type=1 或带 role=assistant 的整包
  if (t === 0) {
    bus.emit('ws:chatgpt-stream', json);
  } else if (t === 10004 || t === 10013) {
    bus.emit('ws:chatgpt-stream', json);
  } else if (isLikelyChatGptStreamChunk(json, t)) {
    bus.emit('ws:chatgpt-stream', json);
  } else if (t === 1 || t === 10005 || t === 10014) {
    bus.emit('ws:chatgpt-full', json);
  } else if (
    (t === undefined || !Number.isFinite(Number(t))) &&
    json.role === 'assistant' &&
    json.content != null &&
    json.sessionId != null
  ) {
    bus.emit('ws:chatgpt-full', json);
  } else if (t === 10003) {
    bus.emit('ws:kick', json);
  } else if (t === 10000) {
    bus.emit('ws:token-error', json);
  } else if (t === 10002) {
    bus.emit('ws:login-timeout', json);
  }
}

function handleMessage(event) {
  const raw = event && event.data;
  wsLog('frame raw length=', raw != null ? String(raw).length : 0, raw);
  let json;
  try {
    json = JSON.parse(raw);
  } catch (e) {
    wsLog('JSON.parse failed', e && e.message, raw);
    return;
  }
  emitParsed(json);
}

function scheduleReconnect() {
  if (reconnectTimer != null) return;
  reconnectTimer = setTimeout(() => {
    reconnectTimer = null;
    if (uni.getStorageSync('token') && !intentionallyClosed) {
      connect();
    }
  }, RECONNECT_MS);
}

function connect() {
  const token = uni.getStorageSync('token');
  if (!token) {
    wsLog('connect skipped: no app token (请先登录)');
    return;
  }

  if (typeof WebSocket === 'undefined') {
    wsLog('WebSocket API 不可用（当前运行环境可能不支持原生 WS）');
    return;
  }

  if (socket != null) {
    try {
      socket.close();
    } catch (e) {}
    socket = null;
  }

  if (reconnectTimer != null) {
    clearTimeout(reconnectTimer);
    reconnectTimer = null;
  }

  const url = getWsUrl();
  wsLog('connecting', url);
  try {
    socket = new WebSocket(url);
  } catch (e) {
    wsLog('new WebSocket threw', e);
    scheduleReconnect();
    return;
  }

  socket.onopen = function () {
    wsLog('open, sending login type 1000');
    const loginPayload = JSON.stringify({ type: 1000, token });
    socket.send(loginPayload);
    startHeartbeat();
    bus.emit('ws:open', { url });
  };

  socket.onmessage = handleMessage;

  socket.onclose = function (event) {
    wsLog('close code=', event.code, 'reason=', event.reason);
    stopHeartbeat();
    socket = null;
    bus.emit('ws:close', { code: event.code });
    if (!intentionallyClosed && event.code !== 1000) {
      wsLog('will reconnect in', RECONNECT_MS, 'ms');
      scheduleReconnect();
    }
  };

  socket.onerror = function (err) {
    wsLog('socket error', err);
    bus.emit('ws:error', {});
  };
}

function registerBusOnce() {
  if (listenersRegistered) return;
  listenersRegistered = true;
  bus.on('login-success', () => {
    intentionallyClosed = false;
    connect();
  });
}

/**
 * 应用启动时调用：有 token 则连接，登录成功后会重连。
 */
export function initGlobalWebSocket() {
  wsLog('initGlobalWebSocket');
  registerBusOnce();
  intentionallyClosed = false;
  connect();
}

/**
 * 退出登录等场景主动断开，不再自动重连。
 */
export function stopGlobalWebSocket() {
  intentionallyClosed = true;
  if (reconnectTimer != null) {
    clearTimeout(reconnectTimer);
    reconnectTimer = null;
  }
  stopHeartbeat();
  if (socket != null) {
    try {
      socket.close(1000);
    } catch (e) {}
    socket = null;
  }
}

export function getWebSocketReadyState() {
  if (!socket) return 3;
  return socket.readyState;
}
