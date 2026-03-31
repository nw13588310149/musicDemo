<template>
  <div class="chat-container">
    <!-- 左侧导航栏 -->
    <div class="nav-sidebar" :class="{ 'collapsed': isSidebarCollapsed }">
      <div class="nav-header">
        <div class="brand-row">
          <span v-if="!isSidebarCollapsed" class="brand-title" @click="toggleSidebar" :style="{fontSize:'14px'}">
            艺考AI小助手
          </span>
          <button type="button" class="nav-menu-btn" aria-label="菜单" @click="toggleSidebar">
            <img class="nav-collapse-ico" src="/static/assets/aichat5.png" width="24" height="24" alt="" />
          </button>
        </div>
      </div>

      <!-- 新对话按钮 -->
      <div class="new-chat-btn" @click="onNewChat">
        <span class="new-chat-plus">+</span>
        <span v-if="!isSidebarCollapsed">开启新对话</span>
      </div>

      <!-- 对话列表（按今天 / 7天 / 30天 分组） -->
      <div class="chat-list hide-scrollbar">
        <div v-if="sessionsLoading && !sessions.length" class="session-hint">加载中…</div>
        <div v-else-if="!sessions.length" class="session-hint">暂无会话，点击开启新对话</div>
        <template v-else-if="isSidebarCollapsed">
          <div class="time-section">
            <div class="time-label collapsed-label">会话</div>
            <div
              v-for="s in sessions"
              :key="s.id"
              class="chat-item collapsed-item"
              :class="{ active: activeSessionId === s.id }"
              :title="sessionDisplayTitle(s)"
              @click="selectSession(s)"
            >
              <span class="item-title">{{ sessionCollapsedLabel(s) }}</span>
            </div>
          </div>
        </template>
        <template v-else>
          <div
            v-for="group in sessionGroups"
            :key="group.key"
            class="time-section"
          >
            <div class="time-label">{{ group.label }}</div>
            <div
              v-for="s in group.items"
              :key="s.id"
              class="chat-item"
              :class="{ active: activeSessionId === s.id }"
              :title="sessionDisplayTitle(s)"
              @click="selectSession(s)"
            >
              <span class="item-title">{{ sessionDisplayTitle(s) }}</span>
              <i class="el-icon-more" @click.stop="confirmDeleteSession(s)"></i>
            </div>
          </div>
        </template>
      </div>
    </div>

    <!-- 主聊天区域 -->
    <div class="chat-main" :class="{ 'is-new-conversation': isNewConversation }">
      <div class="chat-content hide-scrollbar" :class="{ 'new-conversation': isNewConversation }">
        <!-- AI 欢迎消息 -->
        <div class="welcome-message" v-if="isNewConversation">
          <div class="ai-avatar">
            <img class="welcome-logo" src="/static/assets/qiu.gif" width="148" height="148" alt="艺同学" />
          </div>
          <div class="message-content">
            <h2>我是艺同学，很高兴见到你！</h2>
            <p>我可以帮你解答音乐理论问题、分析乐谱、提供练习建议、制定考试计划，让你的艺考之路更加顺畅~</p>
          </div>
        </div>

        <!-- 聊天消息列表 -->
        <div class="messages-list" v-if="!isNewConversation">
          <!-- 动态消息列表 -->
          <div
            v-for="message in messages"
            :key="'msg-' + message.id + '-' + (message.streamRev ?? 0)"
            class="message"
            :class="{ 'ai-message': message.type === 'ai', 'user-message': message.type === 'user' }"
          >
            <!-- 消息内容（对话中 AI 消息不展示头像） -->
            <div class="message-content">
              <!-- 可折叠「深度思考」过程 -->
              <div
                v-if="message.type === 'ai' && (message.reasoning || (message.useReasonerUi && message.streaming))"
                class="ai-reasoning"
              >
                <button
                  type="button"
                  class="ai-reasoning-head"
                  @click.stop="toggleReasoningExpand(message)"
                >
                  <i class="el-icon-cpu ai-reasoning-icon"></i>
                  <span class="ai-reasoning-title">深度思考</span>
                  <i
                    class="ai-reasoning-chevron"
                    :class="message.reasoningExpanded === false ? 'el-icon-arrow-down' : 'el-icon-arrow-up'"
                  ></i>
                </button>
                <div
                  v-show="message.reasoningExpanded !== false"
                  class="ai-reasoning-body"
                >
                  <span
                    v-if="message.streaming && !(message.reasoning && String(message.reasoning).length)"
                    class="thinking"
                  >思考中…</span>
                  <div v-else class="ai-reasoning-text ai-formatted-root">
                    <template v-for="(blk, rbi) in aiMessageBlocks(message.reasoning)">
                      <p v-if="blk.kind === 'p'" :key="'rb-'+message.id+'-'+rbi" class="ai-text-para">{{ blk.text }}</p>
                      <ul v-else-if="blk.kind === 'ul'" :key="'rb-'+message.id+'-'+rbi" class="ai-text-list">
                        <li v-for="(li, lix) in blk.items" :key="lix">{{ li }}</li>
                      </ul>
                    </template>
                  </div>
                </div>
              </div>

              <template v-for="(item, itemIndex) in message.content">
                <h2 v-if="item.type === 'heading'" :key="'h-'+itemIndex" class="ai-heading">{{ item.text }}</h2>
                <div
                  v-else-if="item.type === 'text' && message.type === 'ai'"
                  :key="'p-'+itemIndex"
                  class="stream-text ai-formatted-root"
                >
                  <template v-if="message.streaming && !(item.text && String(item.text).length)">
                    <span class="thinking">回复中…</span>
                  </template>
                  <template v-else>
                    <template v-for="(blk, bi) in aiMessageBlocks(item.text)">
                      <p v-if="blk.kind === 'p'" :key="'b-'+message.id+'-'+itemIndex+'-'+bi" class="ai-text-para">{{ blk.text }}</p>
                      <ul v-else-if="blk.kind === 'ul'" :key="'b-'+message.id+'-'+itemIndex+'-'+bi" class="ai-text-list">
                        <li v-for="(li, lix) in blk.items" :key="lix">{{ li }}</li>
                      </ul>
                    </template>
                  </template>
                </div>
                <p
                  v-else-if="item.type === 'text'"
                  :key="'p-'+itemIndex"
                  class="stream-text user-text-plain"
                >
                  {{ item.text }}
                </p>
              </template>
              
              <!-- 发送中 / 失败 提示（已发送成功不显示右下角勾） -->
              <div
                v-if="message.type === 'user' && message.status !== 'sent'"
                class="message-status"
              >
                <i v-if="message.status === 'sending'" class="el-icon-loading"></i>
                <i v-else-if="message.status === 'failed'" class="el-icon-warning-outline"></i>
              </div>
            </div>
            
            <!-- 重发按钮 (仅在发送失败时显示) -->
            <div v-if="message.type === 'user' && message.status === 'failed'" 
                 class="resend-button" 
                 @click="resendMessage(message)">
              <i class="el-icon-refresh-right"></i>
            </div>
          </div>
          
          <!-- AI正在输入提示（流式等待时由气泡内「思考中」展示） -->
          <div class="message ai-message typing-indicator" v-if="isTyping && !waitingStream">
            <div class="message-content typing-indicator-inner">
              <p>艺同学正在输入<span class="typing-dots"><span>.</span><span>.</span><span>.</span></span></p>
            </div>
          </div>
        </div>

        <!-- 底部输入区域 -->
        <div class="input-area" :class="{ 'centered': isNewConversation, 'closer-to-footer': !isNewConversation }">
          <div class="input-wrapper">
            <textarea
              ref="aiChatTextarea"
              class="input-field hide-scrollbar"
              placeholder="给艺同学发送消息"
              v-model="userInput"
              rows="1"
              @input="autoResize"
              @keydown.enter.prevent="handleEnterKey"
            ></textarea>
            <div class="action-buttons">
              <div class="left-buttons">
                <button type="button" class="action-btn feature-btn" :class="{ active: isDeepThinking }" @click="toggleDeepThinking">
                  <img
                    class="feature-ico"
                    :src="isDeepThinking ? '/static/assets/aichat1A.png' : '/static/assets/aichat1.png'"
                    width="14"
                    height="14"
                    alt=""
                  />
                  深度思考
                </button>
                <button type="button" class="action-btn feature-btn" :class="{ active: isWebSearching }" @click="toggleWebSearching">
                  <img
                    class="feature-ico"
                    :src="isWebSearching ? '/static/assets/aichat2A.png' : '/static/assets/aichat2.png'"
                    width="14"
                    height="14"
                    alt=""
                  />
                  联网搜索
                </button>
              </div>
              <div class="right-buttons">
                <button type="button" class="action-btn attachment-btn" aria-label="上传文件">
                  <img src="/static/assets/aichat3.png" width="16" height="16" alt="" />
                </button>
                <button
                  type="button"
                  class="send-btn"
                  :class="{ 'send-enabled': canSendMessage }"
                  :disabled="!canSendMessage"
                  aria-label="发送"
                  @click="sendMessage"
                >
                  <img src="/static/assets/aichat4.png" width="16" height="16" alt="" />
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
      
      <!-- 底部免责声明 -->
      <div class="footer-disclaimer">内容由 AI 生成，请仔细甄别</div>
    </div>
  </div>
</template>

<script>
import {
  chatGptSessionList,
  chatGptSessionCreate,
  chatGptSessionDelete,
  chatGptMsgList,
  chatGptSend
} from '../../api/home.js';
import bus from '../../utils/eventBus.js';

export default {
  name: 'AiChat',
  data() {
    return {
      isSidebarCollapsed: false,
      isNewConversation: true,
      userInput: '',
      isDeepThinking: false,
      isWebSearching: false,
      messages: [],
      isTyping: false,
      sending: false,
      sessions: [],
      sessionsLoading: false,
      activeSessionId: null,
      chatRobot: 'deepseek',
      waitingStream: false,
      streamTargetSessionId: null,
      streamingMsgId: null,
      streamFallbackTimer: null,
      streamChunkCount: 0,
      typewriterRafId: null,
      streamCorrelationReplyId: null,
      streamScrollRaf: null,
      /** 当前这一轮是否使用推理模型 UI（与发送瞬间的开关一致） */
      pendingStreamDeep: false,
      /** type=1 流式片段可能无结束包，空闲后自动收尾 */
      streamIdleTimer: null
    };
  },
  computed: {
    /** 深度思考时使用后端配置的推理模型名（与 robot 绑定） */
    effectiveChatModel() {
      return this.isDeepThinking ? 'deepseek-reasoner' : 'deepseek-chat';
    },
    /** 有非空输入且未在发送中时可发送（设计稿发送按钮高亮） */
    canSendMessage() {
      return Boolean(this.userInput && String(this.userInput).trim()) && !this.sending;
    },
    /** 侧栏会话按时间分组：今天 / 7天内 / 30天内 / 更早 */
    sessionGroups() {
      const list = this.sessions || [];
      if (!list.length) return [];
      const startOfToday = new Date();
      startOfToday.setHours(0, 0, 0, 0);
      const t0 = startOfToday.getTime();
      const d7 = t0 - 7 * 86400000;
      const d30 = t0 - 30 * 86400000;
      const sorted = [...list].sort((a, b) => this.sessionSortTime(b) - this.sessionSortTime(a));
      const today = [];
      const week = [];
      const month = [];
      const older = [];
      for (const s of sorted) {
        const ts = this.sessionSortTime(s);
        if (!ts) {
          older.push(s);
          continue;
        }
        if (ts >= t0) today.push(s);
        else if (ts >= d7) week.push(s);
        else if (ts >= d30) month.push(s);
        else older.push(s);
      }
      const out = [];
      if (today.length) out.push({ key: 'today', label: '今天', items: today });
      if (week.length) out.push({ key: 'week', label: '7天内', items: week });
      if (month.length) out.push({ key: 'month', label: '30天内', items: month });
      if (older.length) out.push({ key: 'older', label: '更早', items: older });
      return out;
    }
  },
  created() {
    this._onWsStream = (json) => this.onWsChatGptStream(json);
    this._onWsFull = (json) => this.onWsChatGptFull(json);
    this._onWsAnyLog = (json) => this.logWsForDebug(json);
    bus.on('ws:chatgpt-stream', this._onWsStream);
    bus.on('ws:chatgpt-full', this._onWsFull);
    bus.on('ws:message', this._onWsAnyLog);
  },
  beforeUnmount() {
    bus.off('ws:chatgpt-stream', this._onWsStream);
    bus.off('ws:chatgpt-full', this._onWsFull);
    bus.off('ws:message', this._onWsAnyLog);
    this.clearStreamFallbackTimer();
    this.clearStreamIdleTimer();
    this.stopTypewriter();
  },
  methods: {
    /** 发给后端的角色约束（若接口忽略则仍依赖展示层 personaDisplayText） */
    assistantSystemRule() {
      return `你必须全程扮演「艺同学」，定位是面向音乐艺考生（音乐类艺考）的备考与学习辅助助手，由本应用提供。

【领域范围】只围绕音乐艺考相关内容，例如：乐理与和声基础、视唱练耳、音乐听辨与中西音乐史常识、主项与副项（声乐或器乐）的练习方法、曲目选择与难点拆解、乐谱分析、艺考政策与院校/专业方向、省统考与校考备考节奏、笔试与面试准备等。

【明确不要】不要主动介绍或展开编程、软件开发、计算机技术、通用翻译、办公软件等与音乐艺考无关的主题；若用户问起，用一句话说明你是音乐艺考辅导助手，再引导回音乐学习。禁止自称 DeepSeek、禁止提及「深度求索」或任何第三方模型/公司名称。

【表达习惯】用语专业、清晰，适合高中生与艺考生；用户仅打招呼时，用一两句亲切、贴合音乐艺考场景的回应即可，不要罗列与音乐艺考无关的「能力清单」或通用客服式长自我介绍。`;
    },
    logWsForDebug(json) {
      try {
        if (typeof localStorage !== 'undefined' && localStorage.getItem('WS_DEBUG') === '0') return;
      } catch (e) {}
      if (typeof console !== 'undefined' && console.log) {
        console.log('[AiChat ws:message]', json);
      }
    },
    toggleSidebar() {
      this.isSidebarCollapsed = !this.isSidebarCollapsed;
    },
    toggleReasoningExpand(message) {
      if (!message || typeof message !== 'object') return;
      message.reasoningExpanded = message.reasoningExpanded === false;
    },
    sessionDisplayTitle(s) {
      const t = (s && (s.title || s.name || s.sessionTitle)) || '';
      const x = String(t).trim();
      return x || '未命名会话';
    },
    sessionCollapsedLabel(s) {
      const t = this.sessionDisplayTitle(s);
      return t ? t.charAt(0) : '会';
    },
    /** 会话排序/分组用时间戳（毫秒） */
    sessionSortTime(s) {
      if (!s || typeof s !== 'object') return 0;
      const raw =
        s.updateTime ??
        s.updateDate ??
        s.createTime ??
        s.createDate ??
        s.lastMessageTime ??
        s.modifyTime ??
        s.timestamp;
      if (raw == null) return 0;
      if (typeof raw === 'number') return raw;
      const n = new Date(raw).getTime();
      return Number.isNaN(n) ? 0 : n;
    },
    /**
     * 将纯文本拆成段落 / 列表块，便于排版（空行分段、- 开头为列表）
     */
    aiMessageBlocks(text) {
      const raw = String(text ?? '');
      if (!raw.trim()) return [];
      const chunks = raw.split(/\n{2,}/);
      const out = [];
      const isListLine = (line) => /^\s*([-*•]|\d+[.)])\s+/.test(line.trim());
      for (const chunk of chunks) {
        if (!chunk.trim()) continue;
        const lines = chunk.split('\n').map((l) => l.replace(/\r$/, ''));
        const nonEmpty = lines.filter((l) => l.trim().length);
        if (nonEmpty.length >= 1 && nonEmpty.every((l) => isListLine(l))) {
          out.push({
            kind: 'ul',
            items: nonEmpty.map((l) =>
              l.replace(/^\s*([-*•]|\d+[.)])\s+/, '').trim()
            )
          });
        } else {
          out.push({ kind: 'p', text: chunk });
        }
      }
      return out;
    },
    normalizeSessionListPayload(data) {
      if (!data) return [];
      if (Array.isArray(data)) return data;
      if (Array.isArray(data.records)) return data.records;
      if (Array.isArray(data.list)) return data.list;
      if (Array.isArray(data.rows)) return data.rows;
      return [];
    },
    normalizeMsgListPayload(data) {
      let list = [];
      if (!data) list = [];
      else if (Array.isArray(data)) list = data;
      else if (Array.isArray(data.records)) list = data.records;
      else if (Array.isArray(data.list)) list = data.list;
      else if (Array.isArray(data.rows)) list = data.rows;
      else if (Array.isArray(data.messages)) list = data.messages;
      const mapped = list.map((raw) => this.mapApiMessage(raw)).filter(Boolean);
      mapped.sort((a, b) => {
        const ta = a.sortTime || 0;
        const tb = b.sortTime || 0;
        if (ta !== tb) return ta - tb;
        const ia = typeof a.id === 'number' ? a.id : 0;
        const ib = typeof b.id === 'number' ? b.id : 0;
        return ia - ib;
      });
      return mapped.map(({ sortTime, ...rest }) => rest);
    },
    normalizeMsgContent(raw) {
      let text =
        raw.content ??
        raw.message ??
        raw.text ??
        raw.answer ??
        (raw.body != null ? String(raw.body) : '');
      if (text != null && typeof text === 'object') {
        const inner = text.content ?? text.text ?? text.message;
        return inner != null ? String(inner).trim() : '';
      }
      if (typeof text === 'string') {
        const u = this.unwrapJsonStringContent(text).trim();
        return this.normalizeAssistantDisplayText(u).trim();
      }
      return this.normalizeAssistantDisplayText(String(text || '')).trim();
    },
    mapApiMessage(raw) {
      if (!raw || typeof raw !== 'object') return null;
      const str = this.normalizeMsgContent(raw);
      const role = raw.role;
      const type = raw.type;
      const mt = raw.messageType;
      let isUser = false;
      let isAi = false;
      if (role === 'user' || role === 'USER') {
        isUser = true;
      } else if (role === 'assistant' || role === 'ai' || role === 'ASSISTANT') {
        isAi = true;
      } else {
        isUser =
          type === 'user' ||
          type === 1 ||
          mt === 0 ||
          mt === 'USER' ||
          raw.senderType === 1 ||
          raw.fromUser === true ||
          raw.isSelf === true;
        isAi =
          type === 'assistant' ||
          type === 'ai' ||
          type === 2 ||
          mt === 1 ||
          mt === 'ASSISTANT' ||
          raw.senderType === 2;
      }
      if (!isUser && !isAi) {
        if (raw.side === 'right' || raw.position === 'right') isUser = true;
        else isAi = true;
      }
      const msgType = isUser ? 'user' : 'ai';
      const id = raw.id ?? raw.msgId ?? `local-${Date.now()}-${Math.random().toString(36).slice(2, 9)}`;
      let sortTime = 0;
      if (raw.createTime != null) {
        const t = new Date(raw.createTime).getTime();
        sortTime = Number.isNaN(t) ? 0 : t;
      } else if (raw.timestamp != null) {
        sortTime = Number(raw.timestamp) || 0;
      }
      const reasoningRaw =
        raw.reasoning_content ??
        raw.reasoningContent ??
        raw.reasoning ??
        raw.thinking ??
        raw.thinkContent ??
        '';
      const reasoning =
        typeof reasoningRaw === 'string'
          ? this.personaDisplayText(reasoningRaw.trim())
          : reasoningRaw != null
            ? this.personaDisplayText(String(reasoningRaw).trim())
            : '';
      const row = {
        id,
        type: msgType,
        content: str ? [{ type: 'text', text: str }] : [{ type: 'text', text: '' }],
        status: 'sent',
        sortTime
      };
      if (msgType === 'ai') {
        row.reasoning = reasoning;
        row.useReasonerUi = !!reasoning;
        row.reasoningExpanded = true;
      }
      return row;
    },
    extractSessionId(res) {
      const d = res && res.data;
      if (d == null) return null;
      if (typeof d === 'number' || typeof d === 'string') return d;
      if (typeof d === 'object') return d.id ?? d.sessionId ?? null;
      return null;
    },
    clearStreamFallbackTimer() {
      if (this.streamFallbackTimer != null) {
        clearTimeout(this.streamFallbackTimer);
        this.streamFallbackTimer = null;
      }
    },
    /** 长时间无片段才触发 HTTP 兜底；每次收到流式片段都会重置，避免长回答超过固定秒数被整段移除 */
    resetStreamFallbackTimer() {
      this.clearStreamFallbackTimer();
      if (!this.waitingStream) return;
      this.streamFallbackTimer = setTimeout(() => {
        this.onStreamFallback();
      }, 90000);
    },
    clearStreamIdleTimer() {
      if (this.streamIdleTimer != null) {
        clearTimeout(this.streamIdleTimer);
        this.streamIdleTimer = null;
      }
    },
    /** 无「结束帧」时，片段停发一段时间后结束 streaming 状态 */
    scheduleStreamIdleFinish() {
      this.clearStreamIdleTimer();
      if (!this.waitingStream || !this.streamingMsgId) return;
      /* 分段打字展示期间不应触发空闲收尾，否则会提前 finishAiStream，打字动画被截断 */
      if (this.typewriterRafId != null) return;
      const i0 = this.messages.findIndex((m) => m.id === this.streamingMsgId);
      const r0 = i0 !== -1 ? this.messages[i0] : null;
      // 深度思考依赖 10005 收尾；空闲收尾会关掉 waitingStream，导致 10005 被丢弃
      if (r0 && r0.useReasonerUi) return;
      this.streamIdleTimer = setTimeout(() => {
        this.streamIdleTimer = null;
        if (!this.waitingStream || !this.streamingMsgId) return;
        const idx = this.messages.findIndex((m) => m.id === this.streamingMsgId);
        if (idx !== -1) {
          const row = this.messages[idx];
          this.messages.splice(idx, 1, { ...row, streaming: false });
        }
        this.finishAiStream();
      }, 2200);
    },
    stopTypewriter() {
      if (this.typewriterRafId != null) {
        cancelAnimationFrame(this.typewriterRafId);
        this.typewriterRafId = null;
      }
    },
    cancelAiStream() {
      this.stopTypewriter();
      if (this.streamScrollRaf != null) {
        cancelAnimationFrame(this.streamScrollRaf);
        this.streamScrollRaf = null;
      }
      this.clearStreamFallbackTimer();
      this.clearStreamIdleTimer();
      this.waitingStream = false;
      this.streamTargetSessionId = null;
      this.streamChunkCount = 0;
      this.streamCorrelationReplyId = null;
      if (this.streamingMsgId) {
        const sid = this.streamingMsgId;
        this.messages = this.messages.filter((m) => m.id !== sid);
        this.streamingMsgId = null;
      }
    },
    beginAiStream() {
      this.cancelAiStream();
      this.waitingStream = true;
      this.streamTargetSessionId = this.activeSessionId;
      this.streamingMsgId = `ai-stream-${Date.now()}`;
      this.streamChunkCount = 0;
      this.isTyping = false;
      this.messages.push({
        id: this.streamingMsgId,
        type: 'ai',
        content: [{ type: 'text', text: '' }],
        reasoning: '',
        useReasonerUi: !!this.pendingStreamDeep,
        reasoningExpanded: true,
        streaming: true,
        streamRev: 0
      });
      this.resetStreamFallbackTimer();
      this.scrollToBottom();
    },
    /** 流式结束：仅结束 WS 状态并保留当前气泡内容，不再请求 msgList（由 WS 10005/10014 已给全文） */
    finishAiStream() {
      this.clearStreamFallbackTimer();
      this.clearStreamIdleTimer();
      if (this.streamScrollRaf != null) {
        cancelAnimationFrame(this.streamScrollRaf);
        this.streamScrollRaf = null;
      }
      const streamId = this.streamingMsgId;
      this.waitingStream = false;
      this.streamTargetSessionId = null;
      this.streamingMsgId = null;
      this.streamCorrelationReplyId = null;
      this.isTyping = false;
      if (streamId) {
        const idx = this.messages.findIndex((m) => m.id === streamId);
        if (idx !== -1) {
          this.messages[idx].streaming = false;
        }
      }
      this.scrollToBottom();
    },
    onStreamFallback() {
      if (!this.waitingStream) return;
      this.cancelAiStream();
      this.isTyping = false;
      if (this.activeSessionId != null) {
        this.fetchSessionMessages(this.activeSessionId);
      }
    },
    extractWsSessionId(json) {
      if (!json || typeof json !== 'object') return null;
      const v =
        json.sessionId ??
        json.chatSessionId ??
        (json.data && json.data.sessionId) ??
        (json.data && json.data.chatSessionId);
      return v != null ? v : null;
    },
    /** 会话 / replyId 可能与后端为 string 或 number，禁止用 Number() 比较（UUID、大整数会变成 NaN，导致流式全部丢弃） */
    streamIdsEqual(a, b) {
      if (a == null && b == null) return true;
      if (a == null || b == null) return false;
      return String(a) === String(b);
    },
    matchesStreamSession(json) {
      if (!this.waitingStream) return false;
      const sid = this.extractWsSessionId(json);
      if (sid != null && !this.streamIdsEqual(sid, this.activeSessionId)) {
        return false;
      }
      if (sid != null && this.streamIdsEqual(sid, this.activeSessionId)) {
        if (json.replyId != null && this.streamCorrelationReplyId != null) {
          return this.streamIdsEqual(json.replyId, this.streamCorrelationReplyId);
        }
        return true;
      }
      if (json.replyId != null) {
        if (this.streamCorrelationReplyId != null) {
          return this.streamIdsEqual(json.replyId, this.streamCorrelationReplyId);
        }
        return this.streamIdsEqual(this.streamTargetSessionId, this.activeSessionId);
      }
      return this.streamIdsEqual(this.streamTargetSessionId, this.activeSessionId);
    },
    wsNumericType(json) {
      if (!json || json.type == null) return NaN;
      const n = Number(json.type);
      return Number.isFinite(n) ? n : NaN;
    },
    /**
     * OpenAI 兼容流式结构：choices[0].delta 上的 content 与 reasoning_content。
     * 深度思考模式下网关常把整段放在对象或 JSON 字符串里，而不是纯文本 content。
     */
    openAiStyleDeltasFromObject(o) {
      const out = { content: '', reasoning: '' };
      if (!o || typeof o !== 'object') return out;
      const ps = (v) => (typeof v === 'string' && v.length ? v : '');
      if (Array.isArray(o.choices) && o.choices.length) {
        const first = o.choices[0];
        const d = first && (first.delta || first.message);
        if (d && typeof d === 'object') {
          const c = ps(d.content);
          const rt =
            ps(d.reasoning_content) ||
            ps(d.reasoningContent) ||
            ps(d.reasoning) ||
            ps(d.thinking);
          if (c) out.content += c;
          if (rt) out.reasoning += rt;
        }
      }
      if (o.delta && typeof o.delta === 'object') {
        const d = o.delta;
        const c = ps(d.content);
        const rt =
          ps(d.reasoning_content) ||
          ps(d.reasoningContent) ||
          ps(d.reasoning) ||
          ps(d.thinking);
        if (c) out.content += c;
        if (rt) out.reasoning += rt;
      }
      const dirR =
        ps(o.reasoning_content) ||
        ps(o.reasoningContent) ||
        ps(o.reasoning) ||
        ps(o.thinking);
      if (dirR) out.reasoning += dirR;
      if (typeof o.content === 'string' && o.content.length && !Array.isArray(o.choices)) {
        out.content += o.content;
      }
      return out;
    },
    extractStreamDelta(json) {
      if (!json || typeof json !== 'object') return '';
      const t = this.wsNumericType(json);
      // 顶层 delta 对象（无 content 字符串时）
      if (json.delta != null && typeof json.delta === 'object') {
        const top = this.openAiStyleDeltasFromObject(json);
        if (top.content) return top.content;
      }
      // 后端流式：type=0；深度思考等场景下 type=1/10014 也可能是字符串片段（由 wsClient 筛入 stream）
      if ((t === 0 || t === 1 || t === 10014) && typeof json.content === 'string') {
        const tr = String(json.content).trim();
        if (tr.startsWith('{')) {
          try {
            const parts = this.openAiStyleDeltasFromObject(JSON.parse(tr));
            if (parts.content || parts.reasoning) {
              return parts.content;
            }
          } catch (e) {
            /* 非完整 JSON 时按普通文本处理 */
          }
        }
        return this.unwrapJsonStringContent(json.content);
      }
      if ((t === 0 || t === 1 || t === 10014) && json.content != null && typeof json.content === 'object') {
        const parts = this.openAiStyleDeltasFromObject(json.content);
        if (parts.content) return parts.content;
      }
      if (json.content != null && typeof json.content === 'object' && (t === 10004 || t === 10013)) {
        const o = json.content;
        const x = o.delta ?? o.text ?? o.message ?? o.content ?? o.chunk;
        if (x != null) return String(x);
      }
      if ((t === 10004 || t === 10013) && typeof json.content === 'string') {
        return json.content;
      }
      let d = json.data;
      if (typeof d === 'string') {
        const s = d.trim();
        if (s.startsWith('{') || s.startsWith('[')) {
          try {
            d = JSON.parse(s);
          } catch (e) {
            return d;
          }
        } else {
          return d;
        }
      }
      if (d && typeof d === 'object') {
        const fromData = this.openAiStyleDeltasFromObject(d);
        if (fromData.content) return fromData.content;
        const nested =
          d.delta ??
          d.chunk ??
          d.text ??
          d.content ??
          d.message ??
          d.answer ??
          (Array.isArray(d.choices) &&
            d.choices[0] &&
            d.choices[0].delta &&
            d.choices[0].delta.content);
        if (nested != null && typeof nested === 'string') return nested;
        if (nested != null && typeof nested === 'object') {
          const po = this.openAiStyleDeltasFromObject(nested);
          if (po.content) return po.content;
        }
      }
      const pick =
        json.delta ??
        json.chunk ??
        json.text ??
        json.message ??
        json.result ??
        json.output;
      if (typeof pick === 'string') return pick;
      if (pick != null && typeof pick === 'object') {
        const pr = this.openAiStyleDeltasFromObject(pick);
        if (pr.content) return pr.content;
      }
      return '';
    },
    /** 流式推理链：对齐 OpenAI 兼容字段 reasoning_content */
    extractReasoningStreamDelta(json) {
      if (!json || typeof json !== 'object') return '';
      const t = this.wsNumericType(json);
      const pickStr = (v) => (v != null && typeof v === 'string' ? v : '');
      let r =
        pickStr(json.reasoning_content) ||
        pickStr(json.reasoningContent) ||
        pickStr(json.reasoning) ||
        pickStr(json.thinking);
      if (r) return r;
      if (json.delta != null && typeof json.delta === 'object') {
        const dr = this.openAiStyleDeltasFromObject(json);
        if (dr.reasoning) return dr.reasoning;
      }
      if (json.content != null && typeof json.content === 'object') {
        const o = json.content;
        const fromO = this.openAiStyleDeltasFromObject(o);
        if (fromO.reasoning) return fromO.reasoning;
        const inner =
          pickStr(o.reasoning_content) ||
          pickStr(o.reasoningContent) ||
          pickStr(o.reasoning) ||
          pickStr(o.thinking);
        if (inner) return inner;
        const delta = o.delta && typeof o.delta === 'object' ? o.delta : o;
        if (delta && typeof delta === 'object') {
          const d2 =
            pickStr(delta.reasoning_content) ||
            pickStr(delta.reasoningContent) ||
            pickStr(delta.reasoning);
          if (d2) return d2;
        }
      }
      let d = json.data;
      if (typeof d === 'string') {
        const s = d.trim();
        if (s.startsWith('{') || s.startsWith('[')) {
          try {
            d = JSON.parse(s);
          } catch (e) {
            d = null;
          }
        } else {
          d = null;
        }
      }
      if (d && typeof d === 'object') {
        const fromDataR = this.openAiStyleDeltasFromObject(d);
        if (fromDataR.reasoning) return fromDataR.reasoning;
        const top =
          pickStr(d.reasoning_content) ||
          pickStr(d.reasoningContent) ||
          pickStr(d.reasoning);
        if (top) return top;
        const choices = d.choices;
        if (Array.isArray(choices) && choices[0]) {
          const delta = choices[0].delta || choices[0].message || {};
          if (delta && typeof delta === 'object') {
            const c =
              pickStr(delta.reasoning_content) ||
              pickStr(delta.reasoningContent) ||
              pickStr(delta.reasoning);
            if (c) return c;
          }
        }
      }
      if ((t === 0 || t === 1 || t === 10014) && typeof json.content === 'string') {
        const tr = String(json.content).trim();
        if (tr.startsWith('{')) {
          try {
            const parts = this.openAiStyleDeltasFromObject(JSON.parse(tr));
            if (parts.reasoning) return parts.reasoning;
          } catch (e) {
            /* 继续走下方 unwrap */
          }
        }
        const u = this.unwrapJsonStringContent(json.content);
        try {
          const o = JSON.parse(String(json.content || '').trim());
          if (o && typeof o === 'object') {
            const x =
              pickStr(o.reasoning_content) ||
              pickStr(o.reasoningContent) ||
              pickStr(o.reasoning);
            if (x) return x;
          }
        } catch (e) {}
        if (u !== json.content) {
          try {
            const o = JSON.parse(u);
            if (o && typeof o === 'object') {
              const x =
                pickStr(o.reasoning_content) ||
                pickStr(o.reasoningContent) ||
                pickStr(o.reasoning);
              if (x) return x;
            }
          } catch (e2) {}
        }
      }
      return '';
    },
    /** 若 content 误传为整条消息的 JSON 字符串，只取出正文展示 */
    unwrapJsonStringContent(s) {
      const str = String(s || '').trim();
      if (!str.startsWith('{')) return str;
      try {
        const o = JSON.parse(str);
        if (o && o.role === 'assistant' && typeof o.content === 'string') {
          return o.content;
        }
        const inner = o.content ?? o.text ?? o.message;
        if (typeof inner === 'string') return inner;
      } catch (e) {}
      return str;
    },
    /** 是否像整条 assistant 消息被序列化成的 JSON（避免用来覆盖已流式拼好的正文） */
    looksLikeAssistantPayloadJson(s) {
      const t = String(s || '').trim();
      if (!t.startsWith('{')) return false;
      return (
        t.includes('"role"') &&
        t.includes('assistant') &&
        (t.includes('"sessionId"') || t.includes('"msgId"') || t.includes('"replyId"'))
      );
    },
    /** 展示层统一口吻：自称艺同学，避免第三方模型名出现在界面上 */
    personaDisplayText(s) {
      if (s == null) return s;
      let t = typeof s === 'string' ? s : String(s);
      if (!t) return t;
      /* 常见开场白整段替换（模型默认话术） */
      t = t.replace(
        /我是\s*DeepSeek\s*[,，]?\s*由深度求索公司创造的AI助手/gi,
        '我是艺同学'
      );
      t = t.replace(/由深度求索公司创造的/g, '由艺同学为你提供帮助的');
      t = t.replace(/深度求索公司/g, '艺同学');
      t = t.replace(/\bDeepSeek\b/gi, '艺同学');
      t = t.replace(/Deep\s*Seek/gi, '艺同学');
      t = t.replace(/deepseek/gi, '艺同学');
      t = t.replace(/深度求索/g, '艺同学');
      return t;
    },
    /** 展示前再剥一层：防止仍套着 assistant JSON 字符串 */
    normalizeAssistantDisplayText(s) {
      let v = String(s || '');
      for (let i = 0; i < 2; i++) {
        const t = v.trim();
        if (!t.startsWith('{')) break;
        try {
          const o = JSON.parse(t);
          if (o && o.role === 'assistant' && typeof o.content === 'string') {
            v = o.content;
            continue;
          }
          if (o && typeof o.content === 'string' && o.content.length > 0) {
            v = o.content;
            continue;
          }
        } catch (e) {
          break;
        }
        break;
      }
      return this.personaDisplayText(v);
    },
    /**
     * 10005/10014 等结束帧：content 常为整条 assistant JSON（含 content + reasoningContent）。
     * 必须与思考过程拆开；正文字段优先取 o.content，绝不能把 message/text 排在 content 前（易把思考误当正文）。
     */
    parseAssistantEnvelopeFromWs(json) {
      if (!json || typeof json !== 'object') return null;
      const t = this.wsNumericType(json);
      if (t !== 10005 && t !== 10014) return null;
      const pickStr = (v) => {
        if (typeof v !== 'string') return '';
        const x = v.trim();
        return x.length ? x : '';
      };
      let o = null;
      const raw = json.content;
      if (typeof raw === 'string' && raw.trim().startsWith('{')) {
        try {
          o = JSON.parse(raw.trim());
        } catch (e) {
          return null;
        }
      } else if (raw != null && typeof raw === 'object') {
        o = raw;
      }
      if (!o || typeof o !== 'object') return null;
      const reasoning =
        pickStr(o.reasoningContent) ||
        pickStr(o.reasoning_content) ||
        pickStr(o.reasoning) ||
        pickStr(o.thinking) ||
        '';
      const reply =
        pickStr(o.content) ||
        pickStr(o.answer) ||
        pickStr(o.text) ||
        pickStr(o.message) ||
        '';
      if (!reply && !reasoning) return null;
      return { reply, reasoning };
    },
    extractFullReply(json) {
      if (!json || typeof json !== 'object') return '';
      const t = this.wsNumericType(json);
      if (
        (json.role === 'assistant' || json.role === 'ai') &&
        json.content != null &&
        typeof json.content === 'object'
      ) {
        const inner =
          json.content.content ?? json.content.answer ?? json.content.text ?? json.content.message;
        if (typeof inner === 'string') return inner;
      }
      if (
        (json.role === 'assistant' || json.role === 'ai') &&
        typeof json.content === 'string'
      ) {
        return this.unwrapJsonStringContent(json.content);
      }
      if (json.content != null && typeof json.content === 'object' && (t === 10005 || t === 10014)) {
        const o = json.content;
        const x = o.content ?? o.answer ?? o.text ?? o.message;
        if (x != null) return String(x);
      }
      if (typeof json.content === 'string' && (t === 10005 || t === 10014)) {
        const tr = String(json.content).trim();
        if (tr.startsWith('{')) {
          try {
            const o = JSON.parse(tr);
            if (o && typeof o === 'object') {
              const main = o.content ?? o.answer ?? o.text ?? o.message;
              if (main != null && String(main).length) return String(main);
            }
          } catch (e) {}
        }
        return tr;
      }
      let d = json.data;
      if (typeof d === 'string') {
        const s = d.trim();
        if (s.startsWith('{') || s.startsWith('[')) {
          try {
            d = JSON.parse(s);
          } catch (e) {
            return d;
          }
        } else {
          return d;
        }
      }
      const pick =
        json.answer ??
        json.full ??
        json.text ??
        json.message ??
        (d && (d.content ?? d.answer ?? d.message ?? d.full ?? d.text));
      return pick != null ? String(pick) : '';
    },
    extractFullReasoning(json) {
      if (!json || typeof json !== 'object') return '';
      const pickStr = (v) => (v != null && typeof v === 'string' ? v : '');
      let r =
        pickStr(json.reasoning_content) ||
        pickStr(json.reasoningContent) ||
        pickStr(json.reasoning) ||
        pickStr(json.thinking);
      if (r) return r;
      if (
        (json.role === 'assistant' || json.role === 'ai') &&
        json.content != null &&
        typeof json.content === 'object'
      ) {
        const o = json.content;
        r =
          pickStr(o.reasoning_content) ||
          pickStr(o.reasoningContent) ||
          pickStr(o.reasoning);
        if (r) return r;
      }
      const t = this.wsNumericType(json);
      if (typeof json.content === 'string' && (t === 10005 || t === 10014)) {
        const tr = String(json.content).trim();
        if (tr.startsWith('{')) {
          try {
            const o = JSON.parse(tr);
            if (o && typeof o === 'object') {
              r =
                pickStr(o.reasoning_content) ||
                pickStr(o.reasoningContent) ||
                pickStr(o.reasoning);
              if (r) return r;
            }
          } catch (e) {}
        }
      }
      if (json.content != null && typeof json.content === 'object' && (t === 10005 || t === 10014)) {
        const o = json.content;
        r =
          pickStr(o.reasoning_content) ||
          pickStr(o.reasoningContent) ||
          pickStr(o.reasoning);
        if (r) return r;
      }
      let d = json.data;
      if (typeof d === 'string') {
        const s = d.trim();
        if (s.startsWith('{') || s.startsWith('[')) {
          try {
            d = JSON.parse(s);
          } catch (e) {
            d = null;
          }
        } else {
          d = null;
        }
      }
      if (d && typeof d === 'object') {
        r =
          pickStr(d.reasoning_content) ||
          pickStr(d.reasoningContent) ||
          pickStr(d.reasoning);
        if (r) return r;
        const choices = d.choices;
        if (Array.isArray(choices) && choices[0]) {
          const msg = choices[0].message || choices[0].delta || {};
          if (msg && typeof msg === 'object') {
            r =
              pickStr(msg.reasoning_content) ||
              pickStr(msg.reasoningContent) ||
              pickStr(msg.reasoning);
            if (r) return r;
          }
        }
      }
      return '';
    },
    /** 合并流式片段：支持增量拼接；若新文本以当前文本为前缀则视为服务端推送的「全文快照」并整段替换 */
    applyStreamChunk(idx, piece, reasoningPiece) {
      let raw = String(piece || '');
      raw = this.unwrapJsonStringContent(raw);
      const rs = String(reasoningPiece || '');
      if (!raw && !rs) return;
      const row = this.messages[idx];
      if (!row || !row.content || !row.content[0]) return;
      const cur = String(row.content[0].text || '');
      let next = cur;
      if (raw) {
        next = cur && raw.startsWith(cur) ? raw : cur + raw;
        if (this.looksLikeAssistantPayloadJson(next)) {
          next = this.normalizeAssistantDisplayText(next);
        }
      }
      let nextReason = String(row.reasoning || '');
      if (rs) {
        nextReason += rs;
      }
      const streamRev = (row.streamRev || 0) + 1;
      this.messages.splice(idx, 1, {
        ...row,
        reasoning: this.personaDisplayText(nextReason),
        content: [{ type: 'text', text: this.personaDisplayText(next) }],
        streamRev,
        streaming: true
      });
    },
    onWsChatGptStream(json) {
      if (!this.matchesStreamSession(json)) return;
      if (json.replyId != null && this.streamCorrelationReplyId == null) {
        this.streamCorrelationReplyId = json.replyId;
      }
      const t = this.wsNumericType(json);
      let delta = this.extractStreamDelta(json);
      let rDelta = this.extractReasoningStreamDelta(json);
      const idx = this.messages.findIndex((m) => m.id === this.streamingMsgId);
      if (idx === -1) return;
      const row = this.messages[idx];
      /**
       * 深度思考：服务端常用 type=1/10014 的 content 推「思考过程」，最终正文在 10005 信封的 content。
       * 若仍当正文拼接，思考会占满主气泡；此处把无独立 reasoning 字段的 type1 片段并入 reasoning。
       */
      if (
        row &&
        row.useReasonerUi &&
        (t === 1 || t === 10014) &&
        delta &&
        !rDelta
      ) {
        rDelta = delta;
        delta = '';
      }
      if (!delta && !rDelta) return;
      this.streamChunkCount += 1;
      this.applyStreamChunk(idx, delta, rDelta);
      this.resetStreamFallbackTimer();
      this.scheduleStreamIdleFinish();
      if (this.streamScrollRaf == null) {
        this.streamScrollRaf = requestAnimationFrame(() => {
          this.streamScrollRaf = null;
          this.scrollToBottom();
        });
      }
    },
    /** 仅收到 10005 全文、未收到 10004 片段时，用 rAF 分段刷字，避免整段一次性出现 */
    runTypewriterReveal(fullText) {
      const targetId = this.streamingMsgId;
      const text = String(fullText || '');
      if (!targetId || !text) {
        this.finishAiStream();
        return;
      }
      this.clearStreamIdleTimer();
      this.clearStreamFallbackTimer();
      this.stopTypewriter();
      let pos = 0;
      const step = Math.max(2, Math.ceil(text.length / 180));
      const tick = () => {
        this.typewriterRafId = null;
        if (!this.waitingStream || this.streamingMsgId !== targetId) return;
        const idx = this.messages.findIndex((m) => m.id === targetId);
        if (idx === -1) {
          this.finishAiStream();
          return;
        }
        const row = this.messages[idx];
        pos = Math.min(text.length, pos + step);
        const slice = text.slice(0, pos);
        const streamRev = (row.streamRev || 0) + 1;
        this.messages.splice(idx, 1, {
          ...row,
          content: [{ type: 'text', text: slice }],
          streamRev,
          streaming: pos < text.length
        });
        this.$nextTick(() => this.scrollToBottom());
        if (pos < text.length) {
          this.typewriterRafId = requestAnimationFrame(tick);
        } else {
          const i2 = this.messages.findIndex((m) => m.id === targetId);
          if (i2 !== -1) {
            const r2 = this.messages[i2];
            this.messages.splice(i2, 1, { ...r2, streaming: false });
          }
          this.finishAiStream();
        }
      };
      this.typewriterRafId = requestAnimationFrame(tick);
    },
    onWsChatGptFull(json) {
      if (!this.matchesStreamSession(json)) return;
      const env = this.parseAssistantEnvelopeFromWs(json);
      const extractedReply = this.extractFullReply(json);
      const extractedReasoning = this.extractFullReasoning(json);
      const full =
        env != null && typeof env.reply === 'string' && env.reply.trim().length > 0
          ? env.reply.trim()
          : extractedReply;
      const fullReasoning =
        env != null && typeof env.reasoning === 'string' && env.reasoning.trim().length > 0
          ? env.reasoning.trim()
          : extractedReasoning;
      const idx = this.messages.findIndex((m) => m.id === this.streamingMsgId);
      if (idx === -1) {
        this.finishAiStream();
        return;
      }
      if (full && this.streamChunkCount === 0) {
        const t0 = this.normalizeAssistantDisplayText(full);
        const row0 = this.messages[idx];
        const r0 = fullReasoning || row0.reasoning || '';
        if (r0) {
          this.messages.splice(idx, 1, {
            ...row0,
            reasoning: this.personaDisplayText(String(r0)),
            useReasonerUi: row0.useReasonerUi || !!r0
          });
        }
        this.runTypewriterReveal(t0);
        return;
      }
      const row = this.messages[idx];
      const streamRev = (row.streamRev || 0) + 1;
      const streamed = (row.content[0] && row.content[0].text) || '';
      let text = full || streamed || '';
      const fullStr = String(full || '');
      // 已从 10005 信封解析出正文时，full 即为最终回答，禁止再用流式前缀覆盖
      if (env != null && typeof env.reply === 'string' && env.reply.trim().length > 0) {
        text = env.reply.trim();
      } else if (full && this.looksLikeAssistantPayloadJson(fullStr)) {
        text = this.normalizeAssistantDisplayText(fullStr);
      } else if (
        streamed &&
        text &&
        this.looksLikeAssistantPayloadJson(text) &&
        !this.looksLikeAssistantPayloadJson(streamed)
      ) {
        text = streamed;
      } else {
        text = this.normalizeAssistantDisplayText(text);
      }
      /* 无论走哪条分支（含 env.reply 直出），最终正文都需统一剥 JSON + 口吻替换；此前 env.reply 会跳过 normalize 导致仍显示 DeepSeek */
      text = this.normalizeAssistantDisplayText(String(text || ''));
      const mergedReasoning = this.personaDisplayText(String(fullReasoning || row.reasoning || ''));
      this.messages.splice(idx, 1, {
        ...row,
        reasoning: mergedReasoning,
        useReasonerUi: row.useReasonerUi || !!mergedReasoning,
        content: [{ type: 'text', text }],
        streamRev,
        streaming: false
      });
      this.finishAiStream();
    },
    scrollToBottom() {
      this.$nextTick(() => {
        const chatContent = document.querySelector('.chat-content');
        if (chatContent) {
          chatContent.scrollTop = chatContent.scrollHeight;
        }
      });
    },
    async loadSessions() {
      this.sessionsLoading = true;
      try {
        const res = await chatGptSessionList({
          current: 1,
          robot: this.chatRobot,
          size: 50
        });
        if (res && res.code === 0) {
          this.sessions = this.normalizeSessionListPayload(res.data);
        } else if (res) {
          uni.showToast({ title: res.msg || '获取会话列表失败', icon: 'none' });
        }
      } catch (e) {
        uni.showToast({ title: '获取会话列表失败', icon: 'none' });
      } finally {
        this.sessionsLoading = false;
      }
    },
    async fetchSessionMessages(sessionId) {
      if (sessionId == null) return;
      this.cancelAiStream();
      try {
        const res = await chatGptMsgList({
          isDesc: false,
          offsetId: 0,
          sessionId,
          size: 100
        });
        if (res && res.code === 0) {
          this.messages = this.normalizeMsgListPayload(res.data);
          this.isNewConversation = this.messages.length === 0;
        } else if (res) {
          uni.showToast({ title: res.msg || '加载消息失败', icon: 'none' });
        }
      } catch (e) {
        uni.showToast({ title: '加载消息失败', icon: 'none' });
      }
      this.scrollToBottom();
    },
    async selectSession(s) {
      if (!s || s.id == null) return;
      this.activeSessionId = s.id;
      await this.fetchSessionMessages(s.id);
    },
    /** 用首句内容生成会话标题：取第一行，最长约 50 字 */
    titleFromFirstUserMessage(text) {
      const raw = String(text || '').trim();
      if (!raw) return '新对话';
      const firstLine = raw.split(/\n/)[0].trim() || raw;
      const max = 50;
      if (firstLine.length <= max) return firstLine;
      return firstLine.slice(0, max) + '…';
    },
    onNewChat() {
      this.cancelAiStream();
      this.activeSessionId = null;
      this.messages = [];
      this.isNewConversation = true;
      this.userInput = '';
    },
    confirmDeleteSession(s) {
      if (!s || s.id == null) return;
      uni.showModal({
        title: '删除会话',
        content: '确定删除该会话？',
        success: async (r) => {
          if (!r.confirm) return;
          try {
            const res = await chatGptSessionDelete({ id: s.id });
            if (!res || res.code !== 0) {
              uni.showToast({ title: (res && res.msg) || '删除失败', icon: 'none' });
              return;
            }
            this.sessions = this.sessions.filter((x) => x.id !== s.id);
            if (this.activeSessionId === s.id) {
              this.activeSessionId = null;
              this.messages = [];
              this.isNewConversation = true;
              if (this.sessions.length) {
                await this.selectSession(this.sessions[0]);
              }
            }
          } catch (e) {
            uni.showToast({ title: '删除失败', icon: 'none' });
          }
        }
      });
    },
    toggleDeepThinking() {
      this.isDeepThinking = !this.isDeepThinking;
    },
    toggleWebSearching() {
      this.isWebSearching = !this.isWebSearching;
    },
    async sendMessage() {
      const userMessage = this.userInput.trim();
      if (!userMessage || this.sending) return;
      this.isNewConversation = false;
      const messageId = `pending-${Date.now()}`;
      this.messages.push({
        id: messageId,
        type: 'user',
        content: [{ type: 'text', text: userMessage }],
        status: 'sending'
      });
      this.userInput = '';
      this.scrollToBottom();
      this.isTyping = true;
      this.sending = true;
      const pendingMsgId = messageId;
      const findPendingIdx = () =>
        this.messages.findIndex((msg) => msg.id === pendingMsgId);
      try {
        let sessionId = this.activeSessionId;
        if (sessionId == null) {
          const title = this.titleFromFirstUserMessage(userMessage);
          const createRes = await chatGptSessionCreate({
            robot: this.chatRobot,
            title
          });
          if (!createRes || createRes.code !== 0) {
            const idx = findPendingIdx();
            if (idx !== -1) this.messages[idx].status = 'failed';
            this.cancelAiStream();
            uni.showToast({ title: (createRes && createRes.msg) || '创建会话失败', icon: 'none' });
            return;
          }
          const newId = this.extractSessionId(createRes);
          if (newId == null) {
            await this.loadSessions();
            uni.showToast({ title: '创建成功但未返回会话 id', icon: 'none' });
            const idx = findPendingIdx();
            if (idx !== -1) this.messages[idx].status = 'failed';
            this.cancelAiStream();
            return;
          }
          sessionId = newId;
          this.activeSessionId = sessionId;
          const row =
            typeof createRes.data === 'object' &&
            createRes.data !== null &&
            !Array.isArray(createRes.data)
              ? { ...createRes.data, id: sessionId, title: createRes.data.title || title }
              : { id: sessionId, title };
          if (!this.sessions.some((x) => x.id === sessionId)) {
            this.sessions.unshift(row);
          }
        }

        // 先出现流式气泡，再请求发送；否则 HTTP 若阻塞到整段生成完毕，界面会一直空白
        this.pendingStreamDeep = this.isDeepThinking;
        this.beginAiStream();
        const rule = this.assistantSystemRule();
        const res = await chatGptSend({
          content: userMessage,
          isDeep: this.isDeepThinking,
          model: this.effectiveChatModel,
          sessionId,
          systemPrompt: rule,
          system: rule
        });
        const idx = findPendingIdx();
        if (res && res.code === 0) {
          if (idx !== -1) this.messages[idx].status = 'sent';
        } else {
          if (idx !== -1) this.messages[idx].status = 'failed';
          this.cancelAiStream();
          uni.showToast({ title: (res && res.msg) || '发送失败', icon: 'none' });
        }
      } catch (e) {
        const idx = findPendingIdx();
        if (idx !== -1) this.messages[idx].status = 'failed';
        this.cancelAiStream();
        uni.showToast({ title: '发送失败，请检查网络', icon: 'none' });
      } finally {
        this.isTyping = false;
        this.sending = false;
        this.scrollToBottom();
      }
    },
    getAiChatTextareaEl() {
      const r = this.$refs.aiChatTextarea;
      if (!r) return null;
      if (r.tagName === 'TEXTAREA') return r;
      if (r.$el && r.$el.tagName === 'TEXTAREA') return r.$el;
      if (typeof document !== 'undefined') {
        const root = this.$el && this.$el.querySelector ? this.$el : document;
        const q = root.querySelector && root.querySelector('.input-field');
        if (q && q.tagName === 'TEXTAREA') return q;
      }
      return null;
    },
    autoResize() {
      this.$nextTick(() => {
        const textarea = this.getAiChatTextareaEl();
        if (!textarea || !textarea.style) return;
        textarea.style.height = 'auto';
        const h = Math.min(textarea.scrollHeight, 72);
        textarea.style.height = `${h}px`;
      });
    },
    handleEnterKey(event) {
      if (!event.shiftKey) {
        if (this.canSendMessage) this.sendMessage();
        return;
      }
      const ta = (event && event.target) || this.getAiChatTextareaEl();
      if (!ta || typeof ta.selectionStart !== 'number') {
        this.userInput += '\n';
        this.autoResize();
        return;
      }
      const start = ta.selectionStart;
      const end = ta.selectionEnd;
      this.userInput =
        this.userInput.substring(0, start) + '\n' + this.userInput.substring(end);
      this.$nextTick(() => {
        ta.selectionStart = ta.selectionEnd = start + 1;
        this.autoResize();
      });
    },
    async resendMessage(message) {
      const text = message.content && message.content[0] && message.content[0].text;
      if (!text || this.sending || this.activeSessionId == null) return;
      const msgIndex = this.messages.findIndex((msg) => msg.id === message.id);
      if (msgIndex !== -1) this.messages[msgIndex].status = 'sending';
      this.isTyping = true;
      this.sending = true;
      try {
        this.pendingStreamDeep = this.isDeepThinking;
        this.beginAiStream();
        const rule = this.assistantSystemRule();
        const res = await chatGptSend({
          content: text,
          isDeep: this.isDeepThinking,
          model: this.effectiveChatModel,
          sessionId: this.activeSessionId,
          systemPrompt: rule,
          system: rule
        });
        if (res && res.code === 0) {
          if (msgIndex !== -1) this.messages[msgIndex].status = 'sent';
        } else {
          if (msgIndex !== -1) this.messages[msgIndex].status = 'failed';
          this.cancelAiStream();
          uni.showToast({ title: (res && res.msg) || '重发失败', icon: 'none' });
        }
      } catch (e) {
        if (msgIndex !== -1) this.messages[msgIndex].status = 'failed';
        this.cancelAiStream();
        uni.showToast({ title: '重发失败', icon: 'none' });
      } finally {
        this.isTyping = false;
        this.sending = false;
        this.scrollToBottom();
      }
    }
  },
  async mounted() {
    await this.loadSessions();
    if (this.sessions.length && this.activeSessionId == null) {
      await this.selectSession(this.sessions[0]);
    }
  }
};
</script>

<style>
/* 引入 Element UI 图标样式 */
@import url("https://unpkg.com/element-ui/lib/theme-chalk/icon.css");
</style>

<style lang="scss" scoped>
/* 设计主色 */
$ai-primary: #856fe2;

.chat-container {
  display: flex;
  border-radius: 9px;
  background: #f0f1f5;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  overflow: hidden;
  height: 100%;
}

.hide-scrollbar {
  scrollbar-width: none;
  -ms-overflow-style: none;

  &::-webkit-scrollbar {
    display: none;
    width: 0;
    height: 0;
    background: transparent;
  }
}

.nav-sidebar {
  width: 230px;
  background: #f7f8fa;
  border-right: 1px solid #e8e9ed;
  display: flex;
  flex-direction: column;
  padding: 14px 10px;
  overflow: hidden;
  flex-shrink: 0;
  transition: width 0.3s ease;

  &.collapsed {
    width: 56px;
    padding: 14px 8px;

    .new-chat-btn {
      width: 36px;
      height: 36px;
      min-width: 36px;
      padding: 0;
      margin: 8px auto 14px;
    }

    .collapsed-label,
    .collapsed-item {
      display: flex;
      justify-content: center;
      align-items: center;
      font-weight: 500;
    }

    .time-label.collapsed-label {
      padding-left: 0;
      text-align: center;
    }

    .brand-avatar-mini {
      width: 32px;
      height: 32px;
      border-radius: 50%;
      overflow: hidden;
      cursor: pointer;

      img {
        width: 100%;
        height: 100%;
        object-fit: cover;
      }
    }
  }


  .nav-header {
    padding: 4px 0 8px;

    .brand-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 8px;
    }

    .brand-title {
      font-size: 18px;
      color: #111827;
      letter-spacing: 0.02em;
      cursor: pointer;
      user-select: none;
    }

    .nav-menu-btn {
      width: 28px;
      height: 28px;
      padding: 0;
      border: none;
      background: transparent;
      border-radius: 6px;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
      margin:0;

      &:hover {
        background: rgba(0, 0, 0, 0.04);
      }
    }

    .nav-collapse-ico {
      width: 24px;
      height: 24px;
      display: block;
      object-fit: contain;
    }
  }


  .new-chat-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
    width: 200px;
    height: 36px;
    box-sizing: border-box;
    margin: 8px auto 14px;
    padding: 0 12px;
    background: #e9ecfc;
    color: #6244de;
    border-radius: 18px;
    cursor: pointer;
    font-size: 14px;
    font-weight: 500;
    transition: background 0.2s ease, opacity 0.2s ease;
    border: 1px solid rgba(98, 68, 222, 0.22);

    .new-chat-plus {
      font-size: 17px;
      font-weight: 500;
      line-height: 1;
    }

    &:hover {
      opacity: 0.92;
      background: #e0e4f8;
    }
  }

  .chat-list {
    flex: 1;
    overflow-y: auto;
    margin-right: -8px;
    padding-right: 8px;
    padding-bottom: 16px; /* 添加底部内边距，确保最后一项有足够空间 */

    .session-hint {
      color: #6b7280;
      font-size: 12px;
      padding: 12px 8px;
      text-align: center;
      line-height: 1.4;
    }

    .time-section {
      margin-bottom: 16px;

      .time-label {
        color: #9ca3af;
        font-size: 12px;
        margin-bottom: 8px;
        font-weight: 500;
      }

      .chat-item {
        padding: 8px;
        cursor: pointer;
        border-radius: 6px;
        display: flex;
        justify-content: space-between;
        align-items: center;
        color: #374151;
        font-size: 14px;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
        touch-action: manipulation;
        -webkit-tap-highlight-color: transparent;

        .item-title {
          flex: 1;
          min-width: 0;
          overflow: hidden;
          text-overflow: ellipsis;
          white-space: nowrap;
        }

        &.collapsed-item .el-icon-more {
          display: none;
        }

        i {
          color: #9ca3af;
          opacity: 0.55;
          transition: opacity 0.2s;
          flex-shrink: 0;
        }

        @media (hover: hover) and (pointer: fine) {
          i {
            opacity: 0;
          }

          &:hover:not(.active) {
            background: #f3f4f6;

            i {
              opacity: 1;
            }
          }

          &.active:hover {
            background: #b7a9fc;

            i {
              opacity: 1;
            }
          }
        }

        &.active {
          background: rgba(183, 169, 252, 0.1);
          color: #111827;
          font-weight: 500;
          border-radius: 10px;
        }
        
        &.collapsed-item {
          height: 32px;
          font-size: 16px;
          padding-left:12px;
        }
      }
    }
  }
}

.chat-main {
  flex: 1;
  display: flex;
  flex-direction: column;
  position: relative;
  background: #fafafa;
  padding: 0;
  justify-content: center;
  align-items: center;
  overflow: hidden;


  .chat-content {
    width: 100%;
    height: calc(100% - 110px); /* 为底部输入框和免责声明留出空间 */
    display: flex;
    flex-direction: column;
    padding: 20px 40px 0 40px; /* 移除底部内边距，由消息列表的padding-bottom提供 */
    box-sizing: border-box; /* 确保内边距不会增加元素总宽度 */
    overflow-y: auto; /* 允许垂直滚动 */
    overflow-x: hidden; /* 防止水平溢出 */
    
    &.new-conversation {
      justify-content: center;
      padding: 20px 40px;
      background: transparent;
    }
  }

  &.is-new-conversation .footer-disclaimer {
    background: transparent;
  }
  
  .footer-disclaimer {
    width: 100%;
    height: 30px;
    display: flex;
    justify-content: center;
    align-items: center;
    color: #9ca3af;
    font-size: 12px;
    background: #fafafa;
    border-top: none;
    position: absolute;
    bottom: 0;
    left: 0;
  }

  .welcome-message {
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
    gap: 16px;
    padding: 24px 16px 0;
    background: transparent;
    width: 100%;
    margin-bottom: 32px;

    .ai-avatar {
      width: 48px;
      height: 48px;
      flex-shrink: 0;
      display: flex;
      justify-content: center;
      align-items: center;
      background: transparent;

      .welcome-logo {
        width: 120px;
        height: 120spx;
        display: block;
        object-fit: contain;
        margin-bottom:60px;
      }
    }

    .message-content {
      max-width: 520px;

      h2 {
        font-size: 20px;
        font-weight: 400;
        margin-bottom: 10px;
        color: #111827;
      }

      p {
        color: #6b7280;
        font-size: 14px;
        line-height: 1.65;
      }
    }
  }

  .messages-list {
    display: flex;
    flex-direction: column;
    width: 100%;
    gap: 24px;
    margin-bottom: 20px;
    padding-bottom: 120px; /* 增加底部内边距，确保消息不被输入框遮挡 */
    
    .message {
      display: flex;
      gap: 16px;
      width: 100%;
      
      &.ai-message {
        align-items: stretch;
        flex-direction: column;

        .message-content {
          background: #f9fafb;
          border-radius: 12px;
          padding: 12px 16px;
          max-width: 100%;
          box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04);

          .ai-reasoning {
            margin: 0 0 12px;
            border-radius: 8px;
            background: #f4f4f5;
            border: 1px solid #e8e8ea;
            overflow: hidden;
            text-align: left;
          }

          .ai-reasoning-head {
            display: flex;
            align-items: center;
            gap: 8px;
            width: 100%;
            padding: 10px 12px;
            margin: 0;
            border: none;
            background: transparent;
            cursor: pointer;
            font-size: 13px;
            font-weight: 600;
            color: #374151;
            transition: background 0.15s ease;

            &:hover {
              background: rgba(77, 107, 254, 0.06);
            }
          }

          .ai-reasoning-icon {
            font-size: 15px;
            color: #856fe2;
          }

          .ai-reasoning-title {
            flex: 1;
            text-align: left;
          }

          .ai-reasoning-chevron {
            font-size: 12px;
            color: #9ca3af;
          }

          .ai-reasoning-body {
            padding: 0 12px 12px;
            font-size: 13px;
            line-height: 1.65;
            color: #6b7280;
          }

          .ai-reasoning-text {
            display: block;
            word-break: break-word;
          }

          .ai-formatted-root {
            width: 100%;
            text-align: left;
          }

          .ai-heading {
            font-size: 18px;
            font-weight: 600;
            margin: 0 0 10px;
            color: #111827;
            line-height: 1.4;
          }

          .ai-text-para {
            margin: 0 0 12px;
            color: #374151;
            font-size: 14px;
            line-height: 1.75;
            letter-spacing: 0.01em;
            white-space: pre-line;
            word-break: break-word;

            &:last-child {
              margin-bottom: 0;
            }
          }

          .ai-text-list {
            margin: 0 0 12px;
            padding-left: 1.25em;
            color: #374151;
            font-size: 14px;
            line-height: 1.75;
            list-style: disc;

            li {
              margin-bottom: 6px;

              &:last-child {
                margin-bottom: 0;
              }
            }
          }

          p {
            color: #374151;
            font-size: 14px;
            line-height: 1.6;
            margin-bottom: 8px;

            &:last-child {
              margin-bottom: 0;
            }
          }

          .stream-text .thinking,
          p.stream-text .thinking {
            color: #9ca3af;
            font-style: italic;
          }

          &.typing-indicator-inner {
            padding: 10px 16px;
          }
        }
      }
      
      &.user-message {
        justify-content: flex-end;
        
        .message-content {
          background: #eef3ff;
          border-radius: 12px;
          padding: 12px 16px;
          max-width: 80%;
          position: relative;
          
          p {
            color: #374151;
            font-size: 14px;
            line-height: 1.6;
            margin: 0;
          }

          .user-text-plain {
            white-space: pre-wrap;
            word-break: break-word;
            line-height: 1.65;
            letter-spacing: 0.01em;
            margin: 0;
          }
          
          .message-status {
            position: absolute;
            bottom: 4px;
            right: 8px;
            font-size: 12px;
            color: #9ca3af;

            .el-icon-warning-outline {
              color: #f59e0b; /* 黄色警告 */
            }
          }
        }
        
        .resend-button {
          display: flex;
          align-items: center;
          justify-content: center;
          width: 28px;
          height: 28px;
          border-radius: 50%;
          background: #f3f4f6;
          color: #f59e0b;
          cursor: pointer;
          margin-left: 8px;
          
          &:hover {
            background: #e5e7eb;
          }
        }
      }
      
      &.typing-indicator {
        .message-content {
          p {
            display: flex;
            align-items: center;
          }
          
          .typing-dots {
            display: inline-flex;
            margin-left: 4px;
            
            span {
              animation: typingDot 1.4s infinite;
              font-size: 16px;
              line-height: 0;
              
              &:nth-child(1) {
                animation-delay: 0s;
              }
              
              &:nth-child(2) {
                animation-delay: 0.2s;
              }
              
              &:nth-child(3) {
                animation-delay: 0.4s;
              }
            }
          }
        }
      }
    }
  }

  .input-area {
    width: calc(100% - 80px); /* 考虑左右各40px的padding */
    position: absolute;
    bottom: 30px; /* 位于免责声明上方 */
    padding: 0;
    box-sizing: border-box;
    display: flex;
    flex-direction: column;
    left: 50%; /* 水平居中定位 */
    transform: translateX(-50%); /* 水平居中定位 */
    z-index: 10; /* 确保输入框在最上层 */
    
    &.centered {
      position: relative;
      bottom: auto;
      margin-top: 20px;
      left: auto;
      transform: none;
      width: 100%;
      padding: 0 40px;
    }
    
    &.closer-to-footer {
      bottom: 30px; /* 固定在底部免责声明上方 */
    }
    
    .input-wrapper {
      background: #fff;
      border-radius: 14px;
      padding: 14px 16px 12px;
      transition: border-color 0.2s ease, box-shadow 0.2s ease;

      &:focus-within {
        border-color: #f1effe;
        box-shadow: 0 0 0 1px #f1effe, 0 2px 12px rgba(15, 23, 42, 0.06);
      }
    }

    .input-field {
      width: 100%;
      border: none;
      background: transparent;
      color: #374151;
      font-size: 14px;
      line-height: 1.5;
      resize: none;
      padding: 4px;
      margin-bottom: 12px;
      min-height: 24px;
      max-height: 72px; /* 从150px调整为72px，大约3行文本的高度 */
      overflow-y: auto;
      
      &:focus {
        outline: none;
      }
      
      &::placeholder {
        color: #9ca3af;
      }
    }

    .action-buttons {
      display: flex;
      justify-content: space-between;
      align-items: center;
      width: 100%;
      
      .left-buttons, .right-buttons {
        display: flex;
        align-items: center;
        gap: 8px;
      }

      .action-btn {
        display: flex;
        align-items: center;
        gap: 6px;
        padding: 8px 12px;
        border: 1px solid #e5e7eb;
        border-radius: 999px;
        background: #fff;
        cursor: pointer;
        font-size: 13px;
        color: #4b5563;
        height: 34px;
        transition: all 0.2s ease;

        img {
          display: block;
          flex-shrink: 0;
        }

        &:hover {
          background: #f9fafb;
        }

        &.attachment-btn {
          padding: 8px;
          width: 36px;
          min-height: 36px;
          justify-content: center;
          border-radius: 10px;
        }

        &.feature-btn {
          padding: 6px 12px;
          font-weight: 500;

          .feature-ico {
            width: 14px;
            height: 14px;
            object-fit: contain;
          }

          &.active {
            background: rgba(133, 111, 226, 0.12);
            color: #856fe2;
            border-color: rgba(133, 111, 226, 0.35);
          }
        }
      }

      .send-btn {
        background: #d1d5db;
        color: #fff;
        border: none;
        padding: 0;
        width: 36px;
        height: 36px;
        min-width: 36px;
        border-radius: 10px;
        cursor: not-allowed;
        display: flex;
        align-items: center;
        justify-content: center;
        margin-left: 4px;
        transition: background-color 0.2s ease, opacity 0.2s ease;
        opacity: 0.85;

        img {
          display: block;
          width: 16px;
          height: 16px;
          object-fit: contain;
        }

        &.send-enabled {
          background: #856fe2;
          cursor: pointer;
          opacity: 1;

          &:hover {
            background: #7558d4;
          }
        }

        &:disabled {
          pointer-events: none;
        }
      }
    }
  }
}

@keyframes typingDot {
  0%, 60%, 100% {
    transform: translateY(0);
    opacity: 0.6;
  }
  30% {
    transform: translateY(-4px);
    opacity: 1;
  }
}
    .collapsed .nav-header .brand-row{
      justify-content: center !important;
    }
    uni-button:after{
      border:none;
    }
</style>

