<template>
  <view class="chatV" >
    <view class="top" @click="showE = false">
      <van-icon class="return" name="/static/assets/left1.png" @click="left" />
      <view class="name">{{classNmae}}</view>
	  <van-icon @click="detail" class="more" name="/static/assets/qunD.png" />
    </view>
    <scroll-view scroll-y scroll-with-animation :scroll-top="scrollTop" class="scrollChat scroll" id="scroll" ref="scroll" :style="{height: `calc(100% - ${addShow ? '180' : '30'}px)`}" @click="addShow = false;showE = false;showEmoji=false; ">
      <van-list
        ref="listRef"
        :style="{transform: `translateY(${addShow ? '-155' : showEmoji?'-350':'0'}px)`}"
      >
        <template v-for="(item, index) in list" :key="messageRowKey(item, index)">
          <view v-if="shouldShowMsgDateBar(item, index)" class="msg-date-bar">
            {{ formatMsgDateDividerText(item) }}
          </view>
          <view v-if="isSystemNotice(item)" class="chat-sys-line">
            <view class="tips" v-if="item.type == 0">{{ item.text }}</view>
            <view class="tips2" v-else>{{ item.text }}</view>
          </view>
          <van-swipe-cell
            v-else
            class="chat-swipe-cell"
            :disabled="!canRecallMessage(item) || isWideTouchLayout"
          >
          <van-cell :border="false" class="chat-list-cell">
          <view
            class="chat-msg-touch-host"
            @touchstart.passive="onRecallTouchStart(item, index, $event)"
            @touchend="onRecallTouchEnd"
            @touchcancel="onRecallTouchEnd"
            @touchmove.passive="onRecallTouchMove"
            @contextmenu.prevent="onRecallContextMenu(item, index)"
          >
          <view class="left" v-if="item.type != 0 && item.fromUserId != myInfo.id">
            <view class="head"><van-icon :name="item.userHead" /></view>
            <view class="text" v-if="item.type == 1" v-html="item.content"></view>
			<view class="textImg imgB" v-if="item.type == 2">
				<van-image
				  class="text_img"
				  @touchstart="onTouchStart(item.content)"
				  :src="item.content"
				/>
			</view>
			<view class="textSc" v-if="item.type == 3">
				<!-- 课件 -->
				<view class="kj" v-if="item.param1 == 'kj'">
					<view class="item-top">
						{{item.content?.title}}
							<view class="top-right" style="top: 0;" v-if="item.content?.param1 == 2">
								<van-icon name="records-o" />
								{{JSON.parse(item.content?.param3).length}}页
							</view>
							<view class="top-right" v-if="item.content?.param1 == 1 || item.content?.param1 == 3">
								<van-icon name="/static/assets/jpq_play.jpg" style="font-size: 30px;position: relative;top: 6px;"/>
							</view>
					</view>
					<view class="item-bottom">
						<view @click="goKj(item)" style="color: #6A6A6A;" class="thin"><van-icon class="icon1"  name="/static/assets/kj_ckxq.png" />查看详情</view>
					</view>
				</view>
				<!-- 视频 -->
				<view class="video" v-if="item.param1 == 'video'">
					<view class="img" @click="openChatVideo(item)">
						<van-image
						class="video_img"
						fit="cover"
						  position="center"
						  :src="item.content?.coverImg"
						/>
						<van-image
						  class="video_play"
						  src="/static/assets/video_play.jpg"
						/> 
					</view>
					<view class="info">
						<view class="title">{{item.content?.name}}</view>
						<view class="tip">
							<view class="time">
								{{item.content?.duration}}
							</view>
							<view class="views">
								{{item.content?.playCount}}
							</view>
						</view>
					</view>
				</view>
				<!-- 资讯 -->
				<view class="video news" v-if="item.param1 == 'news'" @click="goZiXun(item)">
					<view class="img">
						<van-image
						class="video_img"
						fit="cover"
						  position="center"
						  :src="item.content?.img1"
						/>
					</view>
					<view class="info">
						<view class="title">{{item.content?.title}}</view>
						<view class="tip">
							<view class="time">
								{{item.content?.updateTime}}
							</view>
							<view class="views">
								{{item.content?.viewCount}}
							</view>
						</view>
					</view>
				</view>
				<!-- 课程 -->
				<view class="book" v-if="item.param1 == 'book'" @click="goKc(item)">
					<van-icon name="/static/assets/jpq_play.jpg" style="font-size: 26px;"/>
					<view class="info">
						<view class="title">{{item.content?.title}}</view>
						<view class="tip" v-if="item.content?.shortText2">
							{{item.content?.shortText2}}
						</view>
					</view>
					<view class="bq">{{getType(item.content?.type)}}</view>
				</view>
				<!-- 录音 -->
				<view class="book voice" v-if="item.param1 == 'voice'" >
					<van-icon @click="playVoice(item)" :name="isPlaying==item.content.id?'/static/assets/jpg_stop1.jpg':'/static/assets/jpq_play.jpg'" style="font-size: 26px;"/>
					<view class="info">
						<view class="title">{{item.content?.name}}</view>
						<view class="tip time">
							{{item.content?.duration}}
						</view>
					</view>
				</view>
			</view>
            <view class="nick">{{ item.userName }}</view>
          </view>
          <view class="right" v-if="item.type != 0 && item.fromUserId == myInfo.id">
            <view class="text" v-if="item.type == 1" v-html="item.content"></view>
            <view class="textImg imgB" v-if="item.type == 2">
            	<van-image
				class="text_img"
				@touchstart="onTouchStart(item.content)"
            	  :src="item.content"
            	/>
            </view>  
			<view class="textSc" v-if="item.type == 3">
				<!-- 课件 -->
				<view class="kj" v-if="item.param1 == 'kj'">
					<view class="item-top">
						{{item.content?.title}}
							<view class="top-right" style="top: 0;" v-if="item.content?.param1 == 2">
								<van-icon name="records-o" />
								{{JSON.parse(item.content?.param3).length}}页
							</view>
							<view class="top-right" v-if="item.content?.param1 == 1 || item.content?.param1 == 3">
								<van-icon name="/static/assets/jpq_play.jpg" style="font-size: 30px;position: relative;top: 6px;"/>
							</view>
					</view>
					<view class="item-bottom">
						<view @click="goKj(item)" style="color: #6A6A6A;" class="thin"><van-icon class="icon1"  name="/static/assets/kj_ckxq.png" />查看详情</view>
					</view>
				</view>
				<!-- 视频 -->
				<view class="video" v-if="item.param1 == 'video'">
					<view class="img" @click="openChatVideo(item)">
						<van-image
						class="video_img"
						fit="cover"
						  position="center"
						  :src="item.content?.coverImg"
						/>
						<van-image
						  class="video_play"
						  src="/static/assets/video_play.jpg"
						/> 
					</view>
					<view class="info">
						<view class="title">{{item.content?.name}}</view>
						<view class="tip">
							<view class="time">
								{{item.content?.duration}}
							</view>
							<view class="views">
								{{item.content?.playCount}}
							</view>
						</view>
					</view>
				</view>
				<!-- 资讯 -->
				<view class="video news" v-if="item.param1 == 'news'" @click="goZiXun(item)">
					<view class="img">
						<van-image
						class="video_img"
						fit="cover"
						  position="center"
						  :src="item.content?.img1"
						/>
					</view>
					<view class="info">
						<view class="title">{{item.content?.title}}</view>
						<view class="tip">
							<view class="time">
								{{item.content?.updateTime}}
							</view>
							<view class="views">
								{{item.content?.viewCount}}
							</view>
						</view>
					</view>
				</view>
				<!-- 课程 -->
				<view class="book" v-if="item.param1 == 'book'" @click="goKc(item)">
					<van-icon name="/static/assets/jpq_play.jpg" style="font-size: 26px;"/>
					<view class="info">
						<view class="title">{{item.content?.title}}</view>
						<view class="tip" v-if="item.content?.shortText2">
							{{item.content?.shortText2}}
						</view>
					</view>
					<view class="bq">{{getType(item.content?.type)}}</view>
				</view>
				<!-- 录音 -->
				<view class="book voice" v-if="item.param1 == 'voice'">
					<van-icon @click="playVoice(item)" :name="isPlaying==item.content.id?'/static/assets/jpg_stop1.jpg':'/static/assets/jpq_play.jpg'" style="font-size: 26px;"/>
					<view class="info">
						<view class="title">{{item.content?.name}}</view>
						<view class="tip time">
							{{item.content?.duration}}
						</view>
					</view>
				</view>
			</view>  
            <view class="head"><van-icon :name="item.userHead" /></view>  
            <view class="nick">{{ item.userName }}</view>
          </view>
          <view
            v-if="formatMsgTimeLabel(item)"
            class="msg-send-time"
            :class="item.fromUserId == myInfo.id ? 'msg-send-time--self' : 'msg-send-time--other'"
          >{{ formatMsgTimeLabel(item) }}</view>
          </view>
          </van-cell>
            <template #right>
              <view class="recall-swipe-side" @click.stop="confirmRecallMessage(item, index)">
                <van-icon name="delete-o" class="recall-swipe-side__icon" />
                <text class="recall-swipe-side__txt">撤回</text>
              </view>
            </template>
          </van-swipe-cell>
        </template>
      </van-list>
    </scroll-view>

    <van-action-sheet
      v-model:show="showRecallActionSheet"
      :actions="recallSheetActions"
      :description="recallSheetHint"
      cancel-text="取消"
      close-on-click-action
      class="recall-action-sheet"
      @select="onRecallActionSelect"
      @closed="clearRecallPressTimer"
    />

    <!-- 输入框 -->
    <view class="bottom" :style="{'height':emojiS?'400px':''}">
      <view class="btn">
        <view class="icon"><van-icon name="/static/assets/key.png" /></view>
        <view class="input">
		      <div
		        class="textarea"
		        contenteditable="true"
		        ref="editableDiv"
		        @input="handleInput"
		        @blur="sanitizeContent"
		        :maxlength="300"
		      ></div>
        </view>
       <view class="icon">
			<van-icon name="/static/assets/chat_icon.png" class="biaoqing" @click="showEmoji = !showEmoji;addShow=false;"/>
		</view>
        <view class="icon" v-if="!inputText" @click="addShow = !addShow;showEmoji=false;"><van-icon name="/static/assets/chat_add.png" /></view>
        <view class="send" v-if="inputText" @click="send">发送</view>
      </view>
	  <view class="emojiB" v-if="showEmoji">
		<Emoji v-model="inputText" @add="addEmoji($event)" @delete="deleteEmoji()"/>
	  </view>
      <view class="box" v-if="addShow">
        <view class="box_btn">
			<van-uploader class="upload" :after-read="afterRead">
			  <van-icon class="icon" name="/static/assets/chat_1.png" />
			  <view class="text">照片</view>
			</van-uploader>
          
        </view>
        <view class="box_btn">
			<van-uploader :capture="['album']" class="upload" :after-read="afterRead">
			  <van-icon class="icon" name="/static/assets/chat_2.png" />
			  <view class="text">拍照</view>
			</van-uploader>
          
        </view>
        <view class="box_btn">
			<van-uploader
				class="upload"
				accept="video/*"
				:max-size="200 * 1024 * 1024"
				@oversize="onVideoOversize"
				:after-read="afterReadVideo"
			>
			  <van-icon class="icon" name="/static/assets/chat_4.png" />
			  <view class="text">视频</view>
			</van-uploader>
        </view>
      </view>
    </view>
	
	<!-- 聊天内直接上传的视频：全屏播放 -->
	<van-popup
		v-model:show="showVideoPlay"
		position="center"
		class="chat-video-popup"
		round
		:close-on-click-overlay="true"
		@closed="videoPlayUrl = ''"
	>
		<video
			v-if="videoPlayUrl"
			class="chat-video-popup__player"
			:src="videoPlayUrl"
			controls
			playsinline
		/>
	</van-popup>

	<!-- 图片弹窗 -->
	<van-popup v-model:show="showImg">
		<van-image
			@touchstart="onTouchEnd()"
		    :src="showImgUrl"
		/>
	</van-popup>
	
		<!-- 二维码弹窗 -->
		<van-dialog class="qrcode_box" v-model:show="showQrcode" :showConfirmButton='false'>
			<view class="zt" style="border-radius:9px;">
				<view class="top"></view>
				<view class="info">
					<view class="name">{{classD.schoolClass.name}}</view>
					<van-image
						class="img"
						width="230"
						height="230"
						:src="qrImg"
					/>
					<view class="tt">
						扫描二维码进入班级
					</view>
				</view>
				
			</view>
			<view class="close">
				<van-icon @click="showQrcode = false" name="/static/assets/bg_close.jpg" />
			</view>
		</van-dialog>
	
	<!-- 班级信息 -->
	<van-popup v-model:show="showE" position="right" class="qunB" style="width: 50%;height: 100%;box-shadow: 0 0 16px 0 #D9D9D9;" :overlay='false'>
		<view class="boxOne" v-if="showInfoAll == 0">
			<view class="title">
				<van-icon class="setIcon" name="arrow-left" style="font-size: 20px;color: #7F7F7F;margin-right: 8px;position: relative;top: -2px;left:-5px;" @click="showE = false" />
				<view class="text"  @click="showE = false">返回</view>
			</view>
			<view class="content">
				<view class="li">
					<view class="list">

						<view class="p" v-for="item in classD.teacherList" >
							<van-icon class="head" :name="item.headUrl" />
							<view class="text">
								{{item.realname || item.nickname}}
								<view class="tips tips1" v-if="item.id == classD.headTeacher.id">班主任</view>
								<view class="tips tips2" v-if="item.id != classD.headTeacher.id">老师</view>
							</view>
						</view>
					</view>
					<van-icon class="rightIcon" name="arrow" style="margin-top: -2px;"  @click="showInfoAll = 1"/>
				</view>
				<view class="li studentLi">
					<view class="list">
						<view class="p" v-for="item in classD.studentList">
							<van-icon class="head" :name="item.headUrl" />
							<view class="text">{{item.realname || item.nickname}}</view>
						</view>
					</view>
					<view class="more" @click="showInfoAll = 1">
						查看班级成员
						<van-icon class="moreRight" name="arrow"/>
					</view>
				</view>
				<view class="li lli">
					<view class="liO">
						<view class="tit">群聊头像</view>
						<van-icon class="head" :name="myInfo.headUrl"  @click="goSet"/>
						<van-icon class="btnRight" name="arrow" style="position: relative;top: -3px;" @click="goSet"/>
					</view>
					<view class="liO">
						<view class="tit">群聊名称</view>
						<view class="wz">{{classD.schoolClass.name}}</view>
					</view>
					<view class="liO" @click="showQr">
						<view class="tit">群聊二维码</view>
						<van-icon class="btnRight" name="arrow" style="position: relative;top: -3px;"/>
					</view>
					<view class="liO" @click="openAnnouncement">
						<view class="tit">群公告</view>
						<van-icon class="btnRight" name="arrow" style="position: relative;top: -3px;"/>
					</view>
				</view>
				<view class="li lli">
					<view class="liO" v-if="myInfo.id == classD.headTeacher.id">
						<view class="tit">全体学生禁言</view>
						<van-switch class="fy" v-model="jzFy" @change="changeFy" size="22px" active-color="#00c9a4"/>
					</view>
					<view class="liO">
						<view class="tit">群消息免打扰</view>
						<van-switch class="fy" v-model="overLoad" size="22px" active-color="#00c9a4"/>
					</view>
				</view>
				<view class="" v-if="myInfo.id == classD.headTeacher.id">
					<view class="btnBX">
						<view class="name1" @click="delClass">解散班级</view>
					</view>
				</view>
			</view>
		</view>
		<!-- 全部人员 -->
		<view class="boxOne" v-if="showInfoAll == 1">
			<view class="title">
				<van-icon class="setIcon" name="arrow-left" style="font-size: 20px;color: #7F7F7F;margin-right: 8px;position: relative;top: -2px;left:-5px;" @click="showInfoAll = 0" />
			</view>
			<view class="content">
				<view class="li">
					<view class="list">
						<view class="p" v-for="item in classD.teacherList" >
							<van-icon class="head" :name="item.headUrl" />
							<view class="text">
								{{item.realname || item.nickname}}
								<view class="tips tips1" v-if="item.id == classD.headTeacher.id">班主任</view>
								<view class="tips tips2" v-if="item.id != classD.headTeacher.id">老师</view>
							</view>
						</view>
						<view class="p" v-for="item in classD.studentList">
							<van-icon class="head" :name="item.headUrl" />
							<view class="text">
								{{item.realname || item.nickname}}
								<view class="tips tips2">学生</view>
							</view>
						</view>
					</view>
				</view>
			</view>	
		</view>
	</van-popup>

	<!-- 群公告 -->
	<van-popup v-model:show="showAnnouncement" round position="bottom" class="announcement-popup">
		<view class="announcement-panel">
			<view class="announcement-panel__title">群公告</view>
			<van-field
				v-model="announcementDraft"
				type="textarea"
				rows="5"
				autosize
				maxlength="500"
				show-word-limit
				placeholder="暂无公告，班主任可在此编辑"
				:readonly="!isClassHeadTeacher"
			/>
			<view class="announcement-panel__actions">
				<van-button round block plain type="default" @click="showAnnouncement = false">关闭</van-button>
				<van-button
					v-if="isClassHeadTeacher"
					round
					block
					type="primary"
					color="#00c9a4"
					:loading="announcementSaving"
					@click="saveAnnouncement"
				>
					保存
				</van-button>
			</view>
		</view>
	</van-popup>

  </view>
</template>

<script setup>
import { ref, watch, computed, onMounted, nextTick, onBeforeUnmount, watchEffect ,getCurrentInstance} from 'vue';
import { useRouter } from 'vue-router';    
import router from '../../router';
import { openDB } from 'idb';
import { useStore } from 'vuex';
import {
	sendMsg,
	fileUpload,
	classDetail,
	classManageMute,
	classManageDelete,
	getFavoriteDetailList,
	classManageQrcode,
	updateAnnouncement,
	deleteMsg
} from '/api/home.js';
import { showToast , showLoadingToast,showConfirmDialog} from 'vant';
import dayjs from 'dayjs';


const store = useStore();
const loading = ref(true);
const finished = ref(true);
const addShow = ref(false);
const list = ref([]);
const msgId = ref(0);
const interTime = ref(null);    
const listRef = ref(null);    
const scrollTop = ref(0);
const scrollRef = ref(null);  // 新增
const classNmae = history.state.name;
const classId = history.state.id;
const myInfo = JSON.parse(uni.getStorageSync('my'));

function getMsgId(item) {
	if (!item) return null;
	const v = item.id ?? item.msgId;
	if (v === undefined || v === null || v === '') return null;
	return v;
}

function getMsgTimestamp(item) {
	if (!item) return null;
	return item.createTime ?? item.sendTime ?? item.msgTime ?? item.time ?? null;
}

function toDayjs(raw) {
	if (raw == null || raw === '') return null;
	if (typeof raw === 'number') return dayjs(raw);
	return dayjs(raw);
}

function formatMsgTimeLabel(item) {
	const t = toDayjs(getMsgTimestamp(item));
	if (!t || !t.isValid()) return '';
	const today = dayjs();
	if (t.isSame(today, 'day')) return t.format('HH:mm');
	if (t.isSame(today.clone().subtract(1, 'day'), 'day')) return `昨天 ${t.format('HH:mm')}`;
	if (t.isSame(today, 'year')) return t.format('M月D日 HH:mm');
	return t.format('YYYY-MM-DD HH:mm');
}

function formatMsgDateDividerText(item) {
	const t = toDayjs(getMsgTimestamp(item));
	if (!t || !t.isValid()) return '';
	const today = dayjs();
	if (t.isSame(today, 'day')) return '今天';
	if (t.isSame(today.clone().subtract(1, 'day'), 'day')) return '昨天';
	if (t.isSame(today, 'year')) return t.format('M月D日');
	return t.format('YYYY年M月D日');
}

function shouldShowMsgDateBar(item, index) {
	const t = getMsgTimestamp(item);
	if (t == null || t === '') return false;
	if (index === 0) return true;
	const prev = list.value[index - 1];
	const pt = getMsgTimestamp(prev);
	if (pt == null || pt === '') return true;
	return !toDayjs(t).isSame(toDayjs(pt), 'day');
}

function isSystemNotice(item) {
	if (item.type === 0) return true;
	if (item.type === 2 && item.text) return true;
	return false;
}

function canRecallMessage(item) {
	if (isSystemNotice(item)) return false;
	const mid = getMsgId(item);
	if (mid == null) return false;
	if (myInfo.role === 'teacher') return true;
	return item.fromUserId === myInfo.id;
}

function messageRowKey(item, index) {
	const id = getMsgId(item);
	if (id != null) return `m-${id}`;
	return `m-${index}-${item.fromUserId}-${item.type}-${getMsgTimestamp(item) || 'x'}`;
}

function pickNewMsgMeta(res) {
	const d = res?.data;
	const nowStr = dayjs().format('YYYY-MM-DD HH:mm:ss');
	if (d == null) return { id: undefined, createTime: nowStr };
	if (typeof d === 'number') return { id: d, createTime: nowStr };
	if (typeof d === 'object') {
		const id = d.msgId ?? d.id ?? d.messageId;
		return {
			id,
			createTime: d.createTime || d.sendTime || d.msgTime || nowStr
		};
	}
	return { id: undefined, createTime: nowStr };
}

function confirmRecallMessage(item, index) {
	if (!canRecallMessage(item)) {
		showToast('无权限撤回该消息');
		return;
	}
	const mid = getMsgId(item);
	if (mid == null) {
		showToast('消息未同步，请稍后再试');
		return;
	}
	showConfirmDialog({
		title: '撤回消息',
		message: '确定撤回这条消息吗？'
	})
		.then(() => {
			const msgIdNum = Number(mid);
			if (!Number.isFinite(msgIdNum)) {
				showToast('消息 ID 无效');
				return;
			}
			deleteMsg({ msgId: msgIdNum })
				.then((res) => {
					if (res?.code === 0) {
						list.value.splice(index, 1);
						showToast({ type: 'success', message: '已撤回' });
					} else {
						showToast(res?.msg || '撤回失败');
					}
				})
				.catch(() => showToast('网络异常'));
		})
		.catch(() => {});
}

/** 平板/大屏：禁用左滑撤回，改成长按 + 操作面板，避免与列表滚动冲突 */
const WIDE_TOUCH_MIN_WIDTH = 720;
const isWideTouchLayout = ref(false);
function updateTabletViewport() {
	if (typeof window === 'undefined') return;
	isWideTouchLayout.value = window.innerWidth >= WIDE_TOUCH_MIN_WIDTH;
}

const RECALL_SHEET_ACTION = { name: '撤回这条消息', color: '#ee0a24' };
const recallSheetActions = [RECALL_SHEET_ACTION];
const showRecallActionSheet = ref(false);
const recallSheetTarget = ref(null);

const recallSheetHint = computed(() =>
	isWideTouchLayout.value
		? '平板：长按消息打开菜单；连接键鼠时也可使用右键'
		: '长按消息打开菜单，或向左滑动露出撤回'
);

let recallPressTimer = null;
let recallPressStartX = 0;
let recallPressStartY = 0;
const RECALL_LONG_PRESS_MS = 520;

function clearRecallPressTimer() {
	if (recallPressTimer != null) {
		clearTimeout(recallPressTimer);
		recallPressTimer = null;
	}
}

function openRecallSheet(item, index) {
	if (!canRecallMessage(item)) return;
	recallSheetTarget.value = { item, index };
	showRecallActionSheet.value = true;
}

function onRecallTouchStart(item, index, e) {
	if (!canRecallMessage(item)) return;
	const t = e.touches?.[0];
	if (!t) return;
	recallPressStartX = t.clientX;
	recallPressStartY = t.clientY;
	clearRecallPressTimer();
	recallPressTimer = setTimeout(() => {
		recallPressTimer = null;
		openRecallSheet(item, index);
		try {
			if (typeof navigator !== 'undefined' && navigator.vibrate) {
				navigator.vibrate(35);
			}
		} catch (_) {}
	}, RECALL_LONG_PRESS_MS);
}

function onRecallTouchMove(e) {
	if (recallPressTimer == null) return;
	const t = e.touches?.[0];
	if (!t) return;
	if (Math.hypot(t.clientX - recallPressStartX, t.clientY - recallPressStartY) > 14) {
		clearRecallPressTimer();
	}
}

function onRecallTouchEnd() {
	clearRecallPressTimer();
}

function onRecallContextMenu(item, index) {
	openRecallSheet(item, index);
}

function onRecallActionSelect(action) {
	const t = recallSheetTarget.value;
	if (action.name === RECALL_SHEET_ACTION.name && t) {
		confirmRecallMessage(t.item, t.index);
	}
	recallSheetTarget.value = null;
}

const showImg = ref(false);
const showImgUrl = ref("");
const touchTime = ref(0);
const touchTimeout = ref(null);
const showE = ref(false);
const classD = ref({});
const jzFy = ref(false);
const showL = ref(false);
const activeNames = ref('1');
const scList = ref([]);
const overLoad = ref(false);
const showQrcode = ref(false);
const qrImg = ref("");
const showInfoAll = ref(0);
const showAnnouncement = ref(false);
const announcementDraft = ref('');
const announcementSaving = ref(false);
const showVideoPlay = ref(false);
const videoPlayUrl = ref('');
const isClassHeadTeacher = computed(() => {
	const h = classD.value?.headTeacher;
	return h && myInfo.id === h.id;
});
const textarea = ref(null);
const showEmoji = ref(false);
const state = ref({
  value: '',
  msgs: [],
})

onMounted(() => {
	initMsg(classId);
	updateTabletViewport();
	if (typeof window !== 'undefined') {
		window.addEventListener('resize', updateTabletViewport);
		window.addEventListener('orientationchange', updateTabletViewport);
	}
});

const inputText = ref("");
watch(inputText, (newValue, oldValue) => {
  if (newValue) {
    if(newValue){

    }
  }
});

//添加表情
const editableDiv = ref(null);
const internalInstance = getCurrentInstance()
const global = internalInstance?.appContext.config.globalProperties;
function addEmoji(val){
	inputText.value += global.$string2emoji(val);
	editableDiv.value.innerHTML = inputText.value;
}
const deleteEmoji = () => {
  const imgTagRegex = /<img[^>]*class="emoji"[^>]*>/g;
  const lastImgMatch = inputText.value.match(imgTagRegex);
  const lastImgIndex = lastImgMatch ? inputText.value.lastIndexOf(lastImgMatch[lastImgMatch.length - 1]) : -1;

  if (lastImgIndex !== -1 && lastImgIndex + lastImgMatch[lastImgMatch.length - 1].length === inputText.value.length) {
    // 删除最后一个图片标签
    inputText.value = inputText.value.slice(0, lastImgIndex);
  } else {
    // 删除最后一个字符
    inputText.value = inputText.value.slice(0, -1);
  }

  console.log(inputText.value);
  editableDiv.value.innerHTML = inputText.value;
};
function handleInput(){
	inputText.value = editableDiv.value.innerHTML;
}

function getInfo(){
	
}

//获取课程类别
function getType(num){
	if(num == 1){
		return '视唱'
	}else if(num == 2){
		return '乐理'
	}else if(num == 3){
		return "听写"
	}else if(num == 10){
		return '答题'
	}else if(num == 4){
		return '声乐'
	}else if(num == 5){
		return '器乐'
	}
}

onMounted(()=>{
  interTime.value = setInterval(function(){
    getInfo()
  },3000)
})

//播放录音
const isPlaying = ref(0);
const audioElement = document.createElement('audio');

function playVoice(item){
	if(isPlaying.value == item.content.id){
		isPlaying.value = 0
		audioElement.pause();
	}else{
		isPlaying.value = item.content.id;
		audioElement.src = item.content.url;
		audioElement.play();
	}
	// 监听音频播放结束事件
	end()
	
}

function end(){
	audioElement.addEventListener('ended', function() {
	    isPlaying.value = 0;
	});
}


//切换课件
function goKj(item){
	router.push({name:"detail",state:{item:JSON.stringify(item.content)}})
}

//切换视频（教程中心视频，有业务 id）
function goMovie(item){
	router.push({ name: 'video', state: { id: item.content.id } });
}

function formatVideoDuration(seconds) {
	if (seconds == null || !Number.isFinite(Number(seconds))) return '';
	const s = Math.max(0, Math.floor(Number(seconds)));
	const m = Math.floor(s / 60);
	const r = s % 60;
	return `${m}:${String(r).padStart(2, '0')}`;
}

function getVideoDurationFromFile(file) {
	return new Promise((resolve) => {
		if (!file || typeof URL === 'undefined' || typeof document === 'undefined') {
			resolve(null);
			return;
		}
		const url = URL.createObjectURL(file);
		const v = document.createElement('video');
		v.preload = 'metadata';
		v.muted = true;
		const done = (sec) => {
			URL.revokeObjectURL(url);
			resolve(sec);
		};
		v.onloadedmetadata = () => done(v.duration || null);
		v.onerror = () => done(null);
		v.src = url;
	});
}

function buildChatVideoContent(uploadUrl, fileName, durationSec) {
	return {
		id: 0,
		name: fileName || '视频',
		coverImg: '/static/assets/video_play.jpg',
		duration: formatVideoDuration(durationSec) || '',
		playCount: 0,
		url: uploadUrl
	};
}

/** 教程中心分享：用 id 进视频页；本地上传：content 带 url，弹层播放 */
function parseType3Content(item) {
	let c = item.content;
	if (item.type !== 3) return c;
	if (typeof c === 'string') {
		try {
			return JSON.parse(c);
		} catch {
			return null;
		}
	}
	return c;
}

function openChatVideo(item) {
	if (item.param1 !== 'video') return;
	const c = parseType3Content(item);
	if (!c) {
		showToast('视频数据异常');
		return;
	}
	if (c.url) {
		videoPlayUrl.value = c.url;
		showVideoPlay.value = true;
		return;
	}
	if (c.id) {
		goMovie({ content: c });
		return;
	}
	showToast('无法播放该视频');
}

function onVideoOversize() {
	showToast('视频过大，请选小于 200MB 的文件');
}
//切换资讯
function goZiXun(item){
	router.push({name:"consultationDetail",state:{id:item.content.id}})
}
//切换课程
function goKc(item){
	console.log(item)
	if(item.content.type == 2){
		router.push({ name: 'theory', state: { id: item.content.id } });
	}else{
		router.push({ name: 'music', state: { id: item.content.id } });
	}
}

onBeforeUnmount(()=>{
  if (interTime.value) {
    clearInterval(interTime.value);
    interTime.value = null;
  }
  clearRecallPressTimer();
  if (typeof window !== 'undefined') {
    window.removeEventListener('resize', updateTabletViewport);
    window.removeEventListener('orientationchange', updateTabletViewport);
  }
})

function getAnnouncementFromClass(d) {
	if (!d || typeof d !== 'object') return '';
	if (d.announcement != null && String(d.announcement).length) return String(d.announcement);
	const sc = d.schoolClass;
	if (sc && sc.announcement != null && String(sc.announcement).length) return String(sc.announcement);
	return '';
}

function openAnnouncement() {
	announcementDraft.value = getAnnouncementFromClass(classD.value);
	showAnnouncement.value = true;
}

function saveAnnouncement() {
	if (!isClassHeadTeacher.value) return;
	// 与 classDetail({ classId }) 使用同一路由参数，保持与 /app/school/chat/classDetail 一致
	if (classId == null || classId === '') {
		showToast('无法获取班级 ID，请返回后重新进入班级');
		return;
	}
	announcementSaving.value = true;
	const payload = {
		announcement: announcementDraft.value.trim(),
		classId
	};
	updateAnnouncement(payload)
		.then((res) => {
			announcementSaving.value = false;
			if (res && res.code === 0) {
				showToast({ message: '群公告已更新', type: 'success' });
				const text = payload.announcement;
				if (!classD.value.schoolClass) classD.value.schoolClass = {};
				classD.value.schoolClass.announcement = text;
				classD.value.announcement = text;
				showAnnouncement.value = false;
			} else {
				showToast(res?.msg || '保存失败');
			}
		})
		.catch(() => {
			announcementSaving.value = false;
			showToast('网络异常，请重试');
		});
}

//展示二维码
function showQr(){
	classManageQrcode({'id':classId}).then(res =>{
		if(res.code == 0){
			qrImg.value = res.data;
			showQrcode.value = true;
		}else{
			showToast(res.msg);
		}
	})
}

//获取收藏列表
function getFav(value){
	console.log(value)
	if(!value){
		return false;
	}
	const parms = ref({
	    current: 1,
	    type: value,
	    size: 200
	})
	getFavoriteDetailList(parms.value).then((res) => {
		if(res.code == 0){
			scList.value = res.data;
		}
	})
}

//切换设置页面
function goSet(){
	router.push({name:'info'})
}

//图片放大
function onTouchStart(img) {
	const currentTime = new Date().getTime();
	const timeDiff = currentTime - touchTime.value;
	touchTime.value = currentTime;
	if (timeDiff < 300) {
		showImgUrl.value = img;
		showImg.value = true;
	}
}

//班级详情
function detail(){
	classDetail({classId:classId}).then(res =>{
		if(res.code == 0){
			showE.value = true;
			classD.value = res.data;
		}else{
			showToast(res.msg)
		}
	})
}

//班级禁言
function changeFy(){
	
	classManageMute({ "id": classId,"mute": jzFy.value?1:0}).then(res =>{
		if(res.code == 0){
			if(jzFy.value){
				showToast('已禁言学生');
			}else{
				showToast('已取消禁言学生');
			}
		}else{
			showToast(res.msg);
		}
	})
}

//解散班级
function delClass(){
	showConfirmDialog({
	  confirmButtonText:"解散班级",
	  confirmButtonColor:"#ff004a",
	  message:
	    '解散班级后将删除所有班级相关内容，请谨慎操作！',
	})
	  .then(() => {
	    // on confirm
		classManageDelete({classId:classId}).then(res =>{
			if(res.code == 0){
				showToast('班级已成功解散')
				router.push({name:"smart-campus"});
			}else{
				showToast(res.msg)
			}
		})
	  })
	  .catch(() => {
	    // on cancel
	  });
}

function onTouchEnd() {
	const currentTime = new Date().getTime();
	const timeDiff = currentTime - touchTime.value;
	touchTime.value = currentTime;
	if (timeDiff < 300) {
		showImg.value = false;
	}
}

//图片上传
const afterRead = async (file) => {
    const formData = new FormData();
    formData.append('file', file.file);
    let load = showLoadingToast({
        message: '发送中...',
        forbidClick: true,
        loadingType: 'spinner',
        duration: 0,
    });
    try {
        const res = await fileUpload(formData);
        load.close();
        if (res.code == 0) {
            let param = {
                "classId": classId,
                "content": res.data,
                "param1": "",
                "param2": "",
                "param3": "",
                "param4": "",
                "param5": "img",
                "type": 2
            }
            if (res.data) {
                const user = await getUserData(myInfo.id);
                let newP = {
                    userHead: user.headUrl,
                    userName: user.realname || user.nickname,
                    content: res.data,
                    type: 2,
                    fromUserId: myInfo.id,
                };

                sendMsg(param).then(res => {
                    if (res.code == 0) {
						Object.assign(newP, pickNewMsgMeta(res));
						list.value.push(newP);
						scrollToBottom();
                    }else{
						showToast(res.msg)
					}
                });
            }
        } else {
            showToast(res.msg);
        }
    } catch (error) {
        console.error(error);
        showToast('上传失败');
        load.close();
    }
}

// 视频上传并发送（与 VideoTutorial 分享一致：type 3 + param1 video + JSON content，另含 url 供聊天内播放）
const afterReadVideo = async (file) => {
	const f = Array.isArray(file) ? file[0] : file;
	if (!f?.file) return;
	const raw = f.file;
	const mime = raw.type || '';
	if (mime && !mime.startsWith('video/')) {
		showToast('请选择视频文件');
		return;
	}
	addShow.value = false;
	const load = showLoadingToast({
		message: '上传中...',
		forbidClick: true,
		loadingType: 'spinner',
		duration: 0
	});
	try {
		const durationSec = await getVideoDurationFromFile(raw);
		const formData = new FormData();
		formData.append('file', raw);
		const res = await fileUpload(formData);
		load.close();
		if (res.code !== 0) {
			showToast(res.msg || '上传失败');
			return;
		}
		const vo = buildChatVideoContent(res.data, raw.name, durationSec);
		const param = {
			classId,
			content: JSON.stringify(vo),
			param1: 'video',
			param2: '',
			param3: '',
			param4: '',
			param5: '',
			type: 3
		};
		const user = await getUserData(myInfo.id);
		const newP = {
			userHead: user?.headUrl ?? myInfo.headUrl,
			userName: (user?.realname || user?.nickname) ?? (myInfo.realname || myInfo.nickname),
			content: vo,
			type: 3,
			fromUserId: myInfo.id,
			param1: 'video'
		};
		sendMsg(param).then((sm) => {
			if (sm?.code === 0) {
				Object.assign(newP, pickNewMsgMeta(sm));
				list.value.push(newP);
				scrollToBottom();
			} else {
				showToast(sm?.msg || '发送失败');
			}
		});
	} catch (error) {
		console.error(error);
		load.close();
		showToast('上传失败');
	}
};


// 消息发送
const send = async () =>{
  let param = {
    "classId": classId,
    "content": inputText.value,
    "param1": "",
    "param2": "",
    "param3": "",
    "param4": "",
    "param5": "",
    "type": 1
  }
  if(inputText.value){
    const user = await getUserData(myInfo.id)
	let newP = {};
	if(user){
		newP ={
        userHead: user.headUrl,
        userName: user.realname || user.nickname,
        content: inputText.value,
        type:1,
        fromUserId:myInfo.id
		}
	}else{
		newP ={
			userHead: myInfo.headUrl,
			userName: myInfo.realname || myInfo.nickname,
			content: inputText.value,
			type:1,
			fromUserId:myInfo.id
		}
	}
     
    sendMsg(param).then(res =>{
      if(res.code == 0){
		Object.assign(newP, pickNewMsgMeta(res));
		list.value.push(newP);
		scrollToBottom();
	  }else{
		  showToast(res.msg)
	  }
	  inputText.value = ""
	  editableDiv.value.innerHTML = "";
    })
  }
}

function left(){
  router.push({name:"smart-campus"});
}
    
let dbPromise = new Promise((resolve, reject) => {
    let request = indexedDB.open('chatAppDB', 1);

    request.onupgradeneeded = function(event) {
        let db = event.target.result;
        let objectStore;

        if (!db.objectStoreNames.contains('messages')) {
            objectStore = db.createObjectStore('messages', { keyPath: 'id' });
        } else {
            objectStore = event.target.transaction.objectStore('messages');
        }

        if (!objectStore.indexNames.contains('classId')) {
            objectStore.createIndex('classId', 'classId', { unique: false });
        }
    };

    request.onsuccess = function(event) {
        resolve(event.target.result);
    };

    request.onerror = function(event) {
        reject(event.target.errorCode);
    };
});


const getClassName = async (classId) => {
    const db = await dbPromise;
    const tx = db.transaction('classes', 'readonly');
    const store = tx.objectStore('classes');
    const className = await store.get(classId);
    return className.name;
};

const getUserData = async (userId) => {
    const db = await dbPromise;
    const tx = db.transaction('users', 'readonly');
    const store = tx.objectStore('users');
    const request = store.get(userId);

    return new Promise((resolve, reject) => {
        request.onsuccess = () => {
            const user = request.result;
            resolve(user);
        };
        request.onerror = () => {
            console.error('Error getting user data:', request.error);
            reject(request.error);
        };
    });
};


const getMsgData = async (classId) => {
    const db = await dbPromise;
    const tx = db.transaction('messages', 'readonly');
    const store = tx.objectStore('messages');
    let index = store.index('classId');
    let messages = [];

    // 启动光标查询
    let request = index.openCursor(classId);
    request.onsuccess = function(event) {
        let cursor = event.target.result;
        if (cursor) {
            messages.push(cursor.value);
            cursor.continue();
        } else {
            // 在此处理获取到的messages
        }
    };

    request.onerror = function(event) {
        console.error('Cursor request error:', event.target.error);
    };

    return new Promise((resolve, reject) => {
        tx.oncomplete = () => resolve(messages);
        tx.onerror = (event) => reject(event.target.error);
    });
};


//历史消息从本地读取
const initMsg = async (classId) => {
  const msgList = await getMsgData(classId);
  msgList.sort((a, b) => (Number(a.id) || 0) - (Number(b.id) || 0));

  //消息可视化
  let arr = [];
      if (msgList.length > 0) {
          for (const e of msgList) {
              const user = await getUserData(e.fromUserId)
			  try{
				  if(e.type == 3){
					 e.content = JSON.parse(e.content) 
				  }
			  }catch{
				  
			  }
              let param = {
                  userHead: user.headUrl,
                  userName: user.realname || user.nickname,
                  content: e.content,
				  type:e.type,
				  fromUserId:e.fromUserId,
				  param1:e.param1,
				  id: e.id ?? e.msgId,
				  createTime: e.createTime ?? e.sendTime ?? e.msgTime
              };
              arr.push(param);
          }
      }
  list.value.push(...arr)  
  // 设置滚动
  setTimeout(() => {
    var container = document.querySelector('.uni-scroll-view-content');
    if (container) {
      container.scrollTop = container.scrollHeight;
    }
  }, 0);
}


const scrollToBottom = () => {
  setTimeout(() => {
    var container = document.querySelector('.uni-scroll-view-content');
    if (container) {
      container.scrollTop = container.scrollHeight;
    }
  }, 0);
};

watchEffect(async () => {
    const msg = store.getters.getMsg2;

    // 消息结构更新
    let arr = [];
    if (msg.length > 0) {
        for (const e of msg) {
			if(e.classId == classId){
				//如果是自己发的则不同步
				if(e.fromUserId != myInfo.id){
					const className = await getClassName(e.classId);
					const user = await getUserData(e.fromUserId);
					let content = e.content;
					if (e.type === 3 && typeof content === 'string') {
						try {
							content = JSON.parse(content);
						} catch {
							// keep string
						}
					}
					let param = {
					    userHead: user.headUrl,
					    userName: user.realname || user.nickname,
					    content,
						type:e.type,
						fromUserId:e.fromUserId,
						param1:e.param1,
						id: e.id ?? e.msgId,
						createTime: e.createTime ?? e.sendTime ?? e.msgTime
					};
					arr.push(param);
				}
				
			}
        }
		list.value.push(...arr)
		scrollToBottom();
    }

});

</script>

<style lang="scss" scoped>
	.emojiB{
		::v-deep .emoji-box{
			animation: none;
		}
		::v-deep .emoji-container{
			height: 350px !important;
			overflow: hidden;
			padding: 10px;
		}
		::v-deep .emoji-panel{
			background: none;
		}
		::v-deep .emoji-wrapper{
			width: 26px;
			height: 26px;
			img{
				width: 26px;
				height: 26px;
			}
		}
		::v-deep .emoji-tab{
			display: none;
		}
	}
	.textarea{
		  width: 100%;
		  height: auto;
		  min-height: 1.5em; /* 初始高度 */
		  resize: none; /* 禁止用户手动调整大小 */
		  overflow-y: hidden; /* 隐藏滚动条 */
		  box-sizing: border-box; /* 包含 padding 和 border */
		   border: none; /* 移除边框 */
		    outline: none; /* 移除聚焦时的轮廓 */
		 ::v-deep .emoji{
			  width: 20px;
			  height: 20px;
			  vertical-align: sub;
		  }
	}
	.uni-textarea-wrapper {
	  position: relative;
	  display: flex;
	  align-items: flex-end;
	}
	
	.scrollChat{
		::v-deep .uni-scroll-view-content{
			background: #e9e9e914;
			overflow-y: auto;
			scrollbar-width: none; /* Firefox */
			-ms-overflow-style: none; /* IE and Edge */
		}
		::v-deep .uni-scroll-view-content::-webkit-scrollbar {
		  display: none;
		}
	}
	.list ::v-deep .van-icon__image{
		object-fit:cover;
	}
	.chatV{
		background: #fff;
		border-radius: 9px;
		width: 100%;
		height: 100%;
		padding: 44px 0px 30px 0px;
		position: relative;
		.top{
		    position: absolute;
		    top: 0px;
		    z-index: 9;
		    left: 0px;
			height: 44px;
		    font-size: 30px;
			width: 100%;
			display: flex;
			justify-content: center;
			border-bottom: 1px solid #EEEEEE;
			.name{
				font-size: 16px;
				align-items: center;
				line-height: 44px;
			}
			.return{
				position: absolute;
				left: 10px;
				top: 7px;
			}
			.more{
				position: absolute;
				right: 20px;
				top: 12.5px;
				font-size: 18px;
			}
		}
		.scroll{
			height: calc(100% - 30px);
			overflow-y: auto;
			scrollbar-width: none; /* Firefox */
			-ms-overflow-style: none; /* IE and Edge */
		}
		::v-deep .uni-scroll-view{
			overflow-y: auto;
			scrollbar-width: none; /* Firefox */
			-ms-overflow-style: none; /* IE and Edge */
		}
		.van-cell{
			border: none;
			background: none;
		}
		.van-cell::after{
			display: none;
		}
		.msg-date-bar {
			text-align: center;
			padding: 4px 16px;
			font-size: 10px;
			color: #c8c8c8;
		}
		.chat-sys-line {
			padding: 2px 16px;
		}
		.chat-swipe-cell {
			::v-deep .van-swipe-cell__wrapper {
				background: transparent;
			}
		}
		.chat-msg-touch-host {
			width: 100%;
			user-select: none;
			-webkit-user-select: none;
		}
		.chat-list-cell {
			background: transparent;
			padding: 10px 16px;
			align-items: flex-start;
			&::after {
				display: none;
			}
			::v-deep .van-cell__value {
				width: 100%;
				padding: 0;
				overflow: visible;
			}
		}
		.msg-send-time {
			font-size: 10px;
			color: #d9d9d9;
			line-height: 1.2;
			margin-top: 2px;
		}
		.msg-send-time--other {
			text-align: left;
			padding-left: 44px;
		}
		.msg-send-time--self {
			text-align: right;
			padding-right: 44px;
		}
		.recall-swipe-side {
			height: 100%;
			min-height: 88px;
			min-width: 84px;
			display: flex;
			flex-direction: column;
			align-items: center;
			justify-content: center;
			gap: 6px;
			padding: 8px 14px;
			box-sizing: border-box;
			background: linear-gradient(180deg, #ff7875 0%, #e53535 100%);
			color: #fff;
			font-size: 14px;
			font-weight: 500;
			&__icon {
				font-size: 28px;
				line-height: 1;
			}
			&__txt {
				font-size: 13px;
				letter-spacing: 1px;
			}
		}
		::v-deep .recall-action-sheet {
			.van-action-sheet__description {
				font-size: 13px;
				color: #969799;
				line-height: 1.5;
				padding: 12px 20px 8px;
			}
			.van-action-sheet__item {
				font-size: 16px;
				min-height: 52px;
			}
			.van-action-sheet__cancel {
				font-size: 16px;
				min-height: 52px;
			}
		}
		.tips,.tips2{
			text-align: center;
			font-size: 10px;
		}
		.left,.right{
			display: flex;
			position: relative;
			.head{
				font-size: 34px;
				padding-top: 3px;
				margin-right: 8px;
				.van-icon{
					border-radius: 50%;
					overflow: hidden;
					border:1.5px solid #fff;
					::v-deep img{
						    object-fit: cover;
					}
				}
			}
			.text{
				    margin-top: 21px;
				    background: #E0F8F1;
				    border-radius: 6px;
				    font-size: 14px;
				    color: #404040;
				    padding: 4px 10px;
					max-width: 50%;
					position: relative;
			}
			.textImg{
				margin-top: 21px;
				max-width: 50%;
				position: relative;
				padding: 4px 0px;
				border-radius: 6px;
				overflow: hidden;
			}
			.nick{
				position: absolute;
				font-size: 10px;
			}
			.imgB{
				background: none;
				
			}
			.text_img{
				max-width: 100%;
				border-radius: 4px;
				overflow: hidden;
			}
		}
		.left{
			justify-content: flex-start;
			.nick{
				left: 44px;
				font-size: 10px;
				color: #D9D9D9;
			}
			.text{
				background: #F6F7FB;
				position: relative;
			}
			.text::before{
			    position: absolute;
			    left: -6px;
			    top: 8px;
			    content: "";
			    width: 10px;
			    height: 10px;
			    background: url(/static/assets/leftMsg.png) no-repeat;
			    background-size: 10px;
			}
		}
		.right{
			justify-content: flex-end;
			.nick{
				right: 44px;
				font-size: 10px;
				color: #D9D9D9;
			}
			.text{
				background: #00c9a4;
				color: #fff;
			}
			.text::before{
			    position: absolute;
			    right: -6px;
			    top: 8px;
			    content: "";
			    width: 10px;
			    height: 10px;
			    background: url(/static/assets/rightMsg.png) no-repeat;
			    background-size: 10px;
			}
			.head{
				margin-right: 0;
				margin-left: 8px;
			}
		}
		
		// 输入框
		.bottom{
			position: absolute;
			width: 100%;
			bottom: 0;
			left: 0;
			border-top: 1px solid #EEEEEE;
			font-size: 26px;
			padding: 13px 16px;
			background: #fff;
			.send{
				    background: #00c9a4;
				    width: 44px;
				    height: 30px;
				    font-size: 14px;
				    text-align: center;
				    line-height: 30px;
				    border-radius: 4px;
				    color: #fff;
				    letter-spacing: 1px;
			}
			.btn{
				display: flex;
				align-items: center;
				justify-content: center;
			}
			.box{
				display: flex;
				justify-content: center;
				padding: 40px 0 30px 0;
				position: relative;
				.emoji{
					position: absolute;
					width: 100%;
					height: 400px;
					left: 0;
					top: 0;
					background: #fff;
					z-index: 4;
				}
				.box_btn{
					width: 30%;
					text-align: center;
					.icon{
						margin-right: 0;
						font-size: 55px;
						height: 55px;
					}
					.text{
						margin-top: 4px;
						font-size: 14px;
						font-weight: 400;
					}
				}
			}
			.icon{
				margin-right: 10px;
				height: 26px;
				font-size: 24px;
			}
			.icon:last-child{
				margin-right: 0;
			}
			.input{
				width: 88%;
				border-radius:4px;
				margin-right: 16px;
				font-size: 16px;
				padding: 5px 10px;
				background: #F6F7FB;
				
			}
		}
		.qunB{
			background: url(/static/assets/qunBg.jpg) no-repeat;
			background-size: contain;
			background-color: #fff;
		}
		.boxOne{
			.content{
				padding:0 18px 10px 18px;
			}
			.title{
				height: 94px;
				padding-left: 20px;
				display: flex;
				align-items: center;
				position: relative;
				.setIcon{
					width: 8px;
					height: 16px;
					margin-right: 6px;
				}
				.text{
					color: #7F7F7F;
					font-size: 16px;
					position: relative;
					top: 0px;
				}
			}
			.title::after{
				content: "";
				position: absolute;
				width: 266px;
				height: 63px;
				right: 16px;
				bottom: 0;
				background: url('/static/assets/qunBg2.png') no-repeat;
				background-size: 266px 63px;
			}
			.li{
				background: #fff;
				border-radius: 9px;
				margin-bottom: 10px;
				padding: 22px 20px 0 6px;
				position: relative;
				.titleO{
					display: flex;
					padding: 10px;
					.icon{
						font-size: 18px;
						margin-right: 10px;
					}
				}
				.rightIcon{
					width: 6px;
					height: 12px;
					position: absolute;
					right: 20px;
					top: 50%;
					transform: translateY(-6px);
				}
				.liO{
					padding: 0 20px;
					display: flex;
					align-items: center;
					height: 50px;
					justify-content: flex-end;
					border-bottom: 0.5px solid #eeeeee;
					.btnRight{
						width: 6px;
						height: 12px;
						margin-left: 11px;
					}
					.head{
						font-size: 26px;
						border-radius: 50%;
						border: 1.5px solid #fff;
						overflow: hidden;
					}
					.tit{
						margin-right: auto;
						color: #404040;
						font-size: 15px;
					}
					.wz{
						color: #999999;
						font-size: 14px;
					}
				}
				.list{
					.p{
						display: inline-block;
						text-align: center;
						margin-bottom: 22px;
						width: 86px;
						.head{
							font-size: 38px;
							border-radius: 50%;
							border: 1.5px solid #fff;
							overflow: hidden;
						}
						.text{
							color: #404040;
							font-size: 12px;
							display: flex;
							align-items: flex-end;
							justify-content: center;
							.tips{
								font-size: 8px;
								color: #404040;
								height: 12px;
								line-height: 12px;
								padding: 0 4px;
								border-radius: 6px;
								margin-left: 3px;
								position: relative;
								top: -1px;
							}
							.tips1{
								background: #E0F8F1;
							}
							.tips2{
								background: #E0D9FD;
							}
						}
					}
					
				}
				.title1{
					display: flex;
					padding: 15px 10px;
					position: relative;
					height: 56px;
					.name{
						line-height: 26px;
					}
					.fy{
						position: absolute;
						right: 10px;
						
					}

					
				}
			}
			.lli{
				padding: 0;
			}
			.btnBX{
				display: flex;
				justify-content: center;
				margin-top: 40px;
				.name1{
					width: 96px;
					height: 36px;
					color: #00c9a4;
					text-align: center;
					background: #E0F8F1;
					border-radius: 26px;
					line-height: 36px;
				}
			}
			.studentLi{
				padding: 0;
				.list{
					padding: 22px 20px 0 6px;
					overflow: hidden;
					height: 102px;
					border-bottom: 0.5px solid #EEEEEE;
				}
				.more{
					padding: 14px 20px;
					position: relative;
					font-size: 15px;
					color: #404040;
					.moreRight{
						position: absolute;
						right: 20px;
						width: 6px;
						height: 12px;
						top: 18px;
					}
				}
			}
			.lli .liO:last-child{
				border-bottom: none;
			}
		}
		
		// 课件分享
		.textSc{
			background: #fff;
			margin-top: 21px;
			.kj{
				background: #f2f3f7;
				border-radius: 9px;
				border: none;
				width: 252px;
				height: 123px;
				text-align: left;
				.item-top{
					height: 62px;
					width: 100%;
					line-height: 62px;
					border-bottom: 2px dashed #fff;
					position: relative;
					font-size: 16px;
					padding: 0 10px;
					padding-right: 50px;
					overflow: hidden;
					text-overflow: ellipsis;
					white-space: nowrap;
					.top-right{
						position: absolute;
						right: 10px;
						top: 2px;
						font-size: 12px;
					}
				}
				.item-top::before{
					    content: "";
					    width: 13px;
					    height: 13px;
					    left: -8px;
					    bottom: -7px;
					    background: #fff;
					    border-radius: 50%;
					    position: absolute;
				}
				.item-top::after{
					    content: "";
					    width: 13px;
					    height: 13px;
					    right: -8px;
					    bottom: -7px;
					    background: #fff;
					    border-radius: 50%;
					    position: absolute;
				}
				.item-bottom{
					width: 100%;
					height: 44px;
					line-height: 60px;
					padding: 0 10px;
					position: relative;
					color: #757575;
					font-size: 12px;
					.icon_l{
						margin-right: 10px;
					}
					.icon1{
						font-size: 17px;
						margin-right: 4px;
						position: relative;
						top: 4px;
					}
					.icon_r{
						position: absolute;
						right: 0px;
						bottom: 22px;
						font-size: 16px;
					}
					.del{
						width: 30px;
						text-align: right;
						font-size: 23px;
					}
				}
			}
			.video{
				width: 254px;
				height: 75px;
				background: #fff;
				border-radius: 6px;
				box-shadow: 0 0 32px 0 #f3f3f3;
				padding: 4px;
				display: flex;
				.img{
					width: 67px;
					height: 67px;
					position: relative;
					border-radius: 6px;
					overflow: hidden;
					::v-deep .van-image{
						height: 67px;
					}
					.video_play{
						position: absolute;
						    font-size: 26px;
						    width: 26px;
						    height: 26px;
						    left: 20px;
						    top: 20px;
					}
				}
				.info{
					margin-left: 14px;
					color: #000000;
					font-size: 14px;
					padding: 5px 0;
					.title{
						text-align: left;
					}
				}
				.tip{
					margin-top: 25px;
					.time{
						    background: #f2f2f4;
						    border-radius: 20px;
						    padding: 0 5px;
						    float: left;
						    position: relative;
						    height: 9px;
							font-size: 8px;
						    display: flex;
						    align-items: center;
						    color: #6A6A6A;
							padding-left: 14px;
							margin-right: 16px;
					}
					.time::before{
						    content: "";
						    background: url(/static/assets/play_time.jpg) no-repeat;
						    width: 8px;
						    height: 8px;
						    background-size: 8px;
						    position: absolute;
						    left: 2px;
						    top: 0.5px;
					}
					.views{
						    background: #f2f2f4;
						    border-radius: 20px;
						    padding: 0 5px;
						    float: left;
						    padding-left: 20px;
						    position: relative;
						    height: 9px;
							font-size: 8px;
						    display: flex;
						    align-items: center;
						    color: #6A6A6A;
						    padding-left: 14px;
					}
					.views::before{
						    content: "";
						    background: url(/static/assets/play_num.jpg) no-repeat;
						   width: 8px;
						   height: 8px;
						   background-size: 8px;
						   position: absolute;
						   left: 2px;
						   top: 0.5px;
					}
				}
			}
			.news{
				width: 300px;
				.title{
					width: 210px;
					overflow: hidden;
					text-overflow: ellipsis;
					white-space: nowrap;
				}
			}
			.book{
				width: 254px;
				height: 75px;
				border-radius: 6px;
				box-shadow: 0 0 32px 0 #f3f3f3;
				display: flex;
				padding: 13px 14px;
				position: relative;
				align-items: center;
				.bq{
					position: absolute;
					right: 0;
					top: 0;
					width: 24px;
					height: 10px;
					font-size: 8px;
					background: #00c9a4;
					color: #fff;
					text-align: center;
					line-height: 10px;
					border-radius: 0 6px 0 6px;
					font-family: Inter;
				}
				.info{
					margin-left: 8px;
				}
				.title{
					text-align: left;
					font-size: 14px;
					color: #000;
					height: 14px;
					line-height: 14px;
				}
				.tip{
					margin-top: 14px;
					font-size: 8px;
					color: #6A6A6A;
					background: #EFEFEF;
					height: 12px;
					line-height: 12px;
					padding: 0 5px;
					border-radius: 14px;
					display: inline-block;
					float: left;
				}
				.time{
					position: relative;
					padding-left: 14px;
				}
				.time::before{
					    content: "";
					    background: url(/static/assets/play_time.jpg) no-repeat;
					    width: 8px;
					    height: 8px;
					    background-size: 8px;
					    position: absolute;
					    left: 2px;
					    top: 2px;
				}
			}
		}
		
		::v-deep .qrcode_box{
			background: none;
			width: 392px;
			min-width: 392px;
			border-radius: 9px;
			margin-top: 70px;
			.van-dialog__content{
				padding: 0;
				.zt{
					width: 392px;
					height: 564px;
					background: url(/static/assets/qunQrbg1.png) no-repeat;
					background-size: cover;
				}

				.top{
					height: 106px;
					background: url(/static/assets/qunBG2.png) no-repeat;
					background-size: 266px 63px;
					background-position: right 20px bottom;
					position: relative;
				}
				.info{
					background: #fff;
					display: flex;
					flex-direction: column;
					justify-content: center;
					border-radius: 0 0 9px 9px;
					.name{
						text-align: center;
						margin: 30px 0 50px 0;
					}
					.img{
						margin: 0 auto;
					}

				}
				.tt{
					color: #fff;
					background: #21C498;
					width: 272px;
					height: 36px;
					border-radius: 26px;
					line-height: 36px;
					text-align: center;
					margin: 46px auto;
					
				}

				
				.close{
					position: relative;
					text-align: center;
					font-size: 30px;
					padding-top: 10px;
				}
			
			}
			}
			::v-deep .van-overlay{
				background: rgba(217, 217, 217, 0.8);
			}

			::v-deep .chat-video-popup {
				width: 92vw;
				max-width: 720px;
				padding: 12px;
				box-sizing: border-box;
				background: #000;
				.chat-video-popup__player {
					width: 100%;
					max-height: 70vh;
					display: block;
					vertical-align: top;
				}
			}

			::v-deep .announcement-popup {
				padding-bottom: env(safe-area-inset-bottom, 0px);
				.announcement-panel {
					padding: 16px 16px 20px;
					&__title {
						font-size: 16px;
						font-weight: 600;
						margin-bottom: 12px;
						color: #333;
					}
					&__actions {
						display: flex;
						gap: 12px;
						margin-top: 16px;
						.van-button {
							flex: 1;
						}
					}
				}
			}
	}
</style>