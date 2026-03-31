<template>
  <div class="main-page">
    <TopNav />
    <div class="topBox">
      <LeftNav @navigate="onNavigate" @toggleCollapse="handleToggleCollapse" />
      <div class="right-page" :style="{ width: 'calc(100% - ' + (collapsed ? '71px' : '205px') + ')' }">
        <transition name="router-slide">
          <div class="content">
            <!-- 页面主内容区域 -->
            <router-view :key="collapsed" />
          </div>
        </transition>
      </div>
	  
	  <!-- 浮动窗口 -->
	  <view class="fd" v-if="showFd">
<!-- 		  <view class="li">
			  <van-icon class="icon" name="/static/assets/fd1.png" />
			  <view class="text">画笔</view>
		  </view> -->
		  <view class="li" @click="LyShow">
		  		<van-icon class="icon" name="/static/assets/fd2.png" />
		  		<view class="text">录音</view>
		  </view>
		  <view class="li" @click.stop="pianoShow = !pianoShow">
		  		<van-icon class="icon" name="/static/assets/fd3.png" />
		  		<view class="text">钢琴</view>
		  </view>
		  <view class="bb">
			  <van-icon class="icon" @click="showFd = false" name="/static/assets/wechat1.png" />
		  </view>
	  </view>
	  
	  <!-- 浮动按钮 -->
	  <van-slider class="slide" v-model="y" vertical v-if="!showFd" >
		   <template #button>
		      <van-icon class="icon" @click="showFd = true" name="/static/assets/wechat.png" />
		    </template>
	  </van-slider>
    </div>

	
	<!-- 虚拟钢琴组件 -->
	<view class="piano_box" v-if="pianoShow">
	  <virtual-piano />
	</view>
	
	<!-- 消息弹窗 -->
	<view class="msgList">
		<view class="close" @click="msg.length = 0">
			<van-icon class="close_b" name="/static/assets/bg_close.jpg" />
		</view>
		    <view class="li" v-for="(item,index) in msg" :key="index" @click="goChat(item)">
		    	<view class="class">
		    		<van-icon class="icon" name="/static/assets/notice.png" />
		    		{{item.className}}
		    	</view>
		    	<view class="user">
		    		<van-icon class="icon" :name="item.userHead" />
		    		<view class="name">{{item.userName}}</view>
		    	</view>
		    	<view class="text" v-if="item.type == 1" v-html="item.content">
		    		
		    	</view>
				<view class="text" v-if="item.type == 3">
					内容分享
				</view>
				<view class="text" v-if="item.type == 2">
					图片
				</view>
		    </view>
	</view>
	
	<!-- 录音弹窗 -->
	<van-popup
	  class="lyOver"
	  v-model:show="showLY"
	  :overlay="false"
	  position="top"
	  :style="{ width: '100%', height: '71px' }"
	>
		<view class="lyBox">
			<!-- 计时器显示 -->
			<view class="timer-display">{{ formatTime(timer) }}</view>
			
			<!-- 录音按钮 -->
			<view class="btn_box">
				<view class="btn play" v-if="timer && recordedAudioUrl" @click="playRecordedAudio">
				  <van-image
				    class="img_bg"
				    :src="!isLoad?'/static/assets/jpq_play.jpg':'/static/assets/jpg_stop1.jpg'"
				  />
				  试听
				</view>
<!-- 			    <view class="btn again" v-if="timer" @click="reset">
			      <van-image
			        class="img_bg"
			        src="/static/assets/ly_reload.jpg"
			      />
			      重录
			    </view> -->
			    <view class="btn begin" @click="begin">
					<van-image
			      class="img_bg"
			      width="17"
			      height="26"
			      src="/static/assets/ly_b2.png"
			    />{{ isplayText }}</view>
			    <view class="btn add" v-if="timer && recordedAudioUrl" @click="add"><van-image
			      class="img_bg" 
			      src="/static/assets/ly_reload.jpg"
			    />保存</view>
				<van-image
				  class="close"
				  @click="showLY = false"
				  src="/static/assets/close1.png"
				/>
			  </view>
		</view>
	</van-popup>
	
	<!-- 保存录音 -->
	<van-dialog class="add_log" width="700" :before-close='onBeforeClose' v-model:show="addShow" show-cancel-button @confirm="save">
	  <view class="contain">
	    <view class="title">您可选择喜欢的音效</view>
	    <view class="yx">
	      <van-grid :gutter="10" :border="false">
	        <van-grid-item
	          v-for="(effect, index) in soundEffects"
	          :key="index"
	          @click="selectSoundEffect(index)">
	          <view class="img" :class="{ 'active': index === activeIndex }" :style="{'backgroundImage': effect.icon}"></view>
	          <view class="text">{{effect.text}}</view>
	        </van-grid-item>
	      </van-grid>
	    </view>
	    <view class="title" style="margin: 16px 0 15px 0;">请选择文件夹</view>
	    <view class="wj">
	      <select v-model="checked" class="select" name="" >
	        <option :value="item.id" v-for="item in navItems" :name="item.id">{{item.name}}</option>
	      </select>
	    </view>
	    <view class="title" style="margin: 26px 0 15px 0;">作品名称</view>
	    <view class="name">
	      <van-field v-model="lyTitle" placeholder="请输入文件名称" style="height: 34px;border-radius: 9px;box-shadow: 0 0 8px 0 #f3f3f3;"/>
	    </view>
	  </view>
	</van-dialog>
  </div>
</template>

<script setup>
	
	
import { ref, watch ,watchEffect,onMounted,computed} from 'vue';
import TopNav from '../../components/TopNav.vue';
import LeftNav from '../../components/LeftNav.vue';
import { useRouter } from 'vue-router';
import VirtualPiano from '../common/piano.vue';
import { useStore } from 'vuex';
import { openDB } from 'idb';
import {getrecordingGateList,fileUpload,addrecordingList} from '/api/home.js';
import { showToast, showConfirmDialog, showLoadingToast, Toast } from 'vant';

const store = useStore();
const collapsed = ref(false);
const router = useRouter();


const pianoShow = ref(false);

const onNavigate = (path) => {
  router.push(path);
};
const handleToggleCollapse = (isCollapsed) => {
  collapsed.value = isCollapsed;
};

//正在播放的音频
const audioStream = computed(() => store.state.audioStream);

const offset = ref(null);
const isOver = ref(false);
const y = ref(97);
const showB = ref(false);
const showFd = ref(false);

const btnBoxHeight = ref(50);
const showLY = ref(false);

const clickBtn = () => {
  showB.value = !showB.value;
};


watch(offset, (newValue) => {
  const windowWidth = window.innerWidth;
  isOver.value = windowWidth - newValue?.x > 40;
});

watch(pianoShow, (newValue) => {
  if (newValue) {
    y.value = 60; // 设置 y 的值为小于 50 的数值
  }
});
if(uni.getStorageSync("token")){
	router.push({ name: 'home'});
}else{
	router.push({ name: 'login'});
}

const msg = ref([]);


const dbPromise = openDB('chatAppDB', 1, {
    upgrade(db) {
        const store = db.createObjectStore('messages', { keyPath: 'id' });
        store.createIndex('classId', 'classId', { unique: false });
    },
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
    const user = await store.get(userId);
    return user;
};

function onChange(){
	console.log(y.value)
}

watchEffect(async () => {
    const list = store.getters.getMsg;

    // 消息结构更新
    let arr = [];
    if (list.length > 0) {
        for (const e of list) {
            const className = await getClassName(e.classId);
            const user = await getUserData(e.fromUserId);
            let param = {
                className: className,
                userHead: user.headUrl,
                userName: user.realname || user.nickname,
                content: e.content,
				type:e.type
            };
            arr.push(param);
        }
    }
	msg.value.push(...arr);
	
	// if (wechatIcon.style.top) {
	//   let iconTop = parseInt(wechatIcon.style.top);
	//   let windowHeight = window.innerHeight;
	//   let iconHeight = wechatIcon.offsetHeight;
	//   if (iconTop < 0) wechatIcon.style.top = '0px';
	//   if (iconTop + iconHeight > windowHeight) wechatIcon.style.top = `${windowHeight - iconHeight}px`;
	// }
});

//每3秒删除一个元素
setInterval(() => {
  if (msg.value.length > 0) {
    const firstItem = document.querySelector('.msgList .li');
    if (firstItem) {
      // 添加离开过渡效果类
      firstItem.classList.add('fade-transition-leave-active');
      // 等待过渡效果完成后删除元素
      setTimeout(() => {
			firstItem.remove()
			msg.value.shift();
      }, 300); // 这里的时间应与过渡效果时间一致
    }
  }
}, 3000);

//跳转聊天
function goChat(item){
	router.push({name:"chat",state:{id:item.classId}})
}

//录音功能
let mediaRecorder;
let audioChunks = [];
let interval;
const timer = ref(0);
const isPlaying = ref(false);
const isplayText = ref('开始');
const recordedAudioUrl = ref('');
const recordedAudioBlob = ref(null);
const recordedDuration = ref('00:00.00');
const addShow = ref(false);
const activeIndex = ref(0);
const activeSidebar = ref(0);
const checked = ref('');
const lyTitle = ref("");
const isLoad = ref(false);
const soundEffects = [
  { text: '原声', icon: "url(/static/assets/ly1.png)" },
  { text: '考场', icon: "url(/static/assets/ly2.png)" },
  { text: '录音棚', icon: "url(/static/assets/ly3.png)" },
  { text: '音乐厅', icon: "url(/static/assets/ly4.png)" },
];
const navItems = ref([]);

function getMl(){
	getrecordingGateList().then(res =>{
		navItems.value = res.data;
	})
}

function startTimer() {
  interval = setInterval(() => {
    timer.value += 10;
  }, 10);
}

// 录音试听
function playRecordedAudio() {
	//录音播放
	uni.postMessage({data:{message:"lyPlay"}})
}

function onBeforeClose(action, done){
	if(action == 'cancel'){
		addShow.value = false;
	}
}

function selectSoundEffect(index) {
  activeIndex.value = index;
}

function formatTime(milliseconds) {
  const mins = Math.floor(milliseconds / 60000);
  const secs = Math.floor((milliseconds % 60000) / 1000);
  const millis = Math.floor((milliseconds % 1000) / 10);
  return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}.${millis.toString().padStart(2, '0')}`;
}

function setupRecorder() {
  navigator.mediaDevices.getUserMedia({ audio: true })
    .then(stream => {
      const options = {
        mimeType: 'video/mp4',
        videoBitsPerSecond : 100000
      };

      mediaRecorder = new MediaRecorder(stream, options);
      mediaRecorder.ondataavailable = e => {
        audioChunks.push(e.data);
      };
      mediaRecorder.onstop = e => {
        const audioBlob = new Blob(audioChunks, { type: 'audio/webm' });
        const audioUrl = URL.createObjectURL(audioBlob);
        audioChunks = [];
        // 这里我们将音频 URL 存储到一个响应式的变量中，便于后续操作
        recordedAudioUrl.value = audioUrl;
        recordedAudioBlob.value = audioBlob;
        // 计算录音时长
        recordedDuration.value = formatTime(timer.value);
      };
    })
    .catch(e => console.error(e));
}

function checkAndSetupRecorder() {
  if (!mediaRecorder) {
    setupRecorder();
  }
}

function stopTimer() {
  clearInterval(interval);
}

function reset() {
  if (isPlaying.value) {
    mediaRecorder.stop();
  }
  stopTimer();
  timer.value = 0;
  isPlaying.value = false;
  isplayText.value = '开始';
  audioChunks = [];
}

function begin() {
  if (isPlaying.value) {
	//录音暂停
	uni.postMessage({data:{message:"lyStop"}})
	
    stopTimer();
    isPlaying.value = false;
    isplayText.value = '开始';
  } else {
		//录音开始
		uni.postMessage({data:{message:"beginLY"}})
		
		isPlaying.value = true;
		isplayText.value = '暂停';
		timer.value = 0;
	}
}

//显示录音
function LyShow() {
    showLY.value = !showLY.value;
}
function releaseMediaResources() {
    if (mediaRecorder && mediaRecorder.stream) {
        mediaRecorder.stream.getTracks().forEach(track => {
            track.stop();
        });
    }
    stopTimer();
    isPlaying.value = false;
    isplayText.value = '开始';
    console.log("Tracks and resources released.");
}


// 保存录音
function add(){
	if(recordedAudioUrl.value){
		getMl()
		addShow.value = true;
	}
}
// 保存录音
function save(){
	if(!checked.value){
		showToast("请选择录音所属文件夹！")
		return false;
	}
	if(!lyTitle.value){
		showToast("请输入录音标题！")
		return false;
	}
	
	// 将Blob转为File
	function blobToFile(theBlob, fileName){
	    // 用来保存转换后的文件对象
	    var file = new File([theBlob], fileName, {
	        lastModified: new Date().getTime(),
	        type: theBlob.type
	    });
	    return file;
	}
	
	const mp3File = blobToFile(recordedAudioBlob.value, 'recorded.mp3');
	
	const formData = new FormData();
	formData.append('file', mp3File);
	let load = showLoadingToast({
	  message: '上传录音中...',
	  forbidClick: true,
	  loadingType: 'spinner',
	  duration:0,
	});
	fileUpload(formData).then(res => {
	  load.close();
	  if(res.code == 0){
		 let params = {
		 	  "categoryId": checked.value,
		 	  "duration": recordedDuration.value,
		 	  "id": 0,
		 	  "name": lyTitle.value,
		 	  "param1": "string",
		 	  "param2": "string",
		 	  "param3": "string",
		 	  "url": res.data
		 }
		 addrecordingList(params).then(res =>{
		 	if(res.code == 0){
				showToast('上传成功,已保存到录音系统！');
				activeSidebar.value = checked.value;
				addShow.value =false;
				reset();
			}else{
				showToast(res.msg);
			}
		 })
	  }else{
		  showToast(res.msg)
	  }
	}).catch(error => {
	  console.error(error);
	});
}
</script>

<style lang="scss" scoped>
	.img.active{
		border: 2px solid #00c9a4;
		border-radius: 9px;
	}
	.yx ::v-deep .van-grid-item__content--center{
		padding: 0;
	}
	::v-deep .add_log{
		.contain{
			padding:36px 36px 15px 36px;
			padding-bottom: 30px;
		}
		.title{
			position: relative;
			padding-left: 10px;
			margin-bottom: 26px;
			color: #8F8F8F;
			font-size: 16px;
		}
	
		.title::before{
			content: "";
			position: absolute;
			width: 3px;
			height: 12px;
			background: #00c9a4;
			border-radius: 4px;
			left: 0;
			top: 5px;
		}
		.mp3{
			display: flex;
			font-size: 14px;
			margin-bottom: 15px;
			.st{
				margin-left: 20px;
				.icon_r{
					position: relative;
					top: 2px;
					margin-right: 6px;
				}
			}
		}
		.yx{
			margin-bottom: 15px;
	
			.img{
				width: 100%;
				height: 90px;
				background-repeat: no-repeat;
				background-size: 100%;
			}
			.text{
				font-size: 14px;
				color: #7F7F7F;
				margin-top: 12px;
			}
		}
		.wj{
			font-size: 14px;
			margin-bottom: 15px;
			.select{
				width: 100%;
				height: 34px;
				padding-left: 10px;
				border: none;
				box-shadow: 0 0 8px 0 #f3f3f3;
				padding-right: 10px;
				appearance: none;
				-moz-appearance: none;
				-webkit-appearance: none;
				background: url('/static/assets/select_arrow.png') no-repeat;
				background-size: 12px;
				background-position: right 10px center;
			}
		}
		.name{
			margin-bottom: 48px;
			.van-field{
				padding: 0;
				padding-left: 10px;
				height: 34px;
				.van-field__control{
					height: 34px;
				}
			}
			.name_input{
				border-bottom: 1px solid rgba(0, 0, 0, 0.2);
				padding-left: 10px;
			}
		}
	}
	.slide{
		position: fixed;
		right: 5px;
		top: 0;
		background: none;
		z-index: 99;
		::v-deep .van-slider__bar{
			background: none;
		}
		.icon{
			font-size: 50px;
		}
	}
	.lyOver{
		  background: rgba(255, 255, 255, 0.1); /* 半透明的白色背景 */
		  border-radius: 10px; /* 圆角 */
		  backdrop-filter: blur(10px); /* 毛玻璃效果 */
		  -webkit-backdrop-filter: blur(10px); /* 兼容 Safari */
		  border: 1px solid rgba(255, 255, 255, 0.18); /* 边框 */
		  padding: 5px 20px; /* 内边距 */
		  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1); /* 阴影效果 */
		  
		  .lyBox{
			  display: flex;
			  justify-content: center;
			  align-items: center;
			  height: 59px;
			  .timer-display{
				  font-size: 20px;
				  margin-right: 40px;
				  margin-left: 40px;
			  }
			  .btn_box{
				  display: flex;
				  align-items: center;
				  
				  .btn{
					  width: 100px;
					  height: 40px;
					  display: flex;
					  align-items: center;
					  justify-content: center;
					  background: #00c9a4;
					  color: #fff;
					  border-radius: 40px;
					  .img_bg{
						  margin-right: 7px;
						  width: 20px;
						  height: 20px;
					  }
				  }
				  .again , .add{
					  background: #595858;
				  }
				  .begin{
					  margin: 0 20px;
				  }
				  .play{
					  // margin: 0 20px;
				  }
				  .close{
					  width: 44px;
					  position: absolute;
					  right: 16px;
				  }
			  }
		  }
	}
	.fd{
		width: 55px;
		height: 212px;
		border-radius: 35px;
		box-shadow: 0 0 4px 0 #eeeeee;
		position: fixed;
		background: #fff;
		right: 18px;
		top: 50%;
		z-index: 999;
		transform: translateY(-106px);
		padding: 10px 2px;
		.li{
			text-align: center;
			border-bottom: 1px solid #eeeeee;
			height: 72px;
			display: flex;
			flex-direction: column;
			align-items: center;
			justify-content: center;
			.icon{
				font-size: 25px;
			}
			.text{
				margin-top: 6px;
				font-size: 14px;
				color: #7F7F7F;
			}
		}
		.bb{
			display: flex;
			justify-content: center;
			align-items: center;
			margin-top: 9px;
			.icon{
				font-size: 45px;
			}
		}
	}
.piano_box{
			position: absolute;
			bottom: 0;
			left: 0;
			width: 100%;
			height: 314px;
			z-index: 99;
			::v-deep .piano-key-wrap{
				height: 241px !important;
			}
			::v-deep .tdt{
				bottom: 241px !important;
			}
		}	
	
::v-deep .van-floating-bubble__icon {
  font-size: 50px;
}

.router-slide-enter-active,
.router-slide-leave-active {
  transition: transform 3s;
}

.router-slide-enter,
.router-slide-leave-to {
  transform: translateX(100%);
}
::v-deep .movable-view {
  background: none;
  box-shadow: none;
}

body {
  background: url('/static/assets/bg.jpg');
  .main-page {
    .topBox {
      height: calc(100% - 89px);
      display: flex;
    }

    .right-page {
      width: 100%;
      height: 100%;
      overflow: hidden;
      .content {
        padding-right: 18px;
        height: 100%;
      }
    }
  }
}

// 消息通知
.fade-transition-leave-active {
	overflow: hidden;
	padding: 0px 11px !important;
  height: 0 !important;
}



.msgList{
	position: absolute;
	z-index: 9999;
	right: 18px;
	top: 0;
	padding-top: 65px;
	height: calc(100% - 15px);
	overflow-y: hidden;
	box-sizing: border-box;
	.close{
		position: absolute;
		width: 100%;
		display: flex;
		justify-content: flex-start;
		top: 30px;
	}
	.close_b{
		font-size: 30px;
	}
	.li{
		transition: height 0.3s linear;
		width: 371px;
		height: 110px;
		padding: 8px 11px;
		border-radius: 9px;
		margin-bottom: 5px;
		background: rgba(255,255,255);
		box-shadow: 0 0 8px #f3f3f3;
		.class{
			font-size: 16px;
			color: #7F7F7F;
			display: flex;
			align-items: center;
			border-bottom: 1px solid #f6f7fb;
			padding-bottom: 7px;
			height: 38px;
			.icon{
				font-size: 24px;
				margin-right: 5px;
			}
		}
		.user{
			font-size: 14px;
			margin-top: 10px;
			display: flex;
			align-items: center;
			.icon{
				font-size: 16px;
				border-radius: 50%;
				overflow: hidden;
				margin-right: 9px;
				margin-left: 4px;
			}
			.name{
				color: #7F7F7F;
			}
		}
		.text{
			margin-top: 6px;
			font-size: 12px;
			padding-left: 30px;
			color: #7F7F7F;
		}
	}
}
</style>
