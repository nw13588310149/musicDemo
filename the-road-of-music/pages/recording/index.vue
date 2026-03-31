<template>
  <view class="app-container23">
    <!-- 左侧导航 -->
    <view class="sidebar">
      <view class="sidebar-title"><van-icon class="title_icon" name="/static/assets/bottom_go.png" />分类</view>
      <view class="over_y" style="height: calc(100% - 125px);">
		  <view
		    class="sidebar-item"
		    v-for="(item, index) in navItems"
		    :key="index"
		    @click="onSelectNavItem(item)"
		  >
		    <van-swipe-cell>
		      <view class="btn" :class="{'active': activeSidebar == item.id}">{{item.name}}</view>
		      <template #right>
		        <van-icon class="del" @click="del(item)" name="/static/assets/delIcon2.png" />
		      </template>
		    </van-swipe-cell>
		  </view>
	  </view>
      <!-- 新增分类 -->
      <view class="add_box">
        <view class="van_button" @click="addShow2 = true"><van-icon class="add_class" name="/static/assets/add_class.png" />录音分类</view> 
      </view>
    </view>

    <!-- 主体内容 -->
    <view class="content">
      <!-- 录音系统 -->
      <view class="ly" v-if="activeSidebar == 0">
        <view class="img">
          <view class="box1">
            <van-icon class="lyPlay" @click="playRecordedAudio" name="/static/assets/ly_play.png" v-if="!isPlaying && timer && !isLoad"/>
            <van-icon class="lyPlay" style="z-index: 10;background-color: black;border-radius: 50%;font-size: 100px;display: flex;justify-content: center;align-items: center;" name="/static/assets/music.gif" v-if="isLoad"/>
          </view>
          <view class="box2" :class="{ 'playing': isPlaying }"></view>
          <view class="box3" :class="{ 'playing': isPlaying }"></view>
          <view class="box4" :class="{ 'playing': isPlaying }"></view>
        </view>
        <!-- 计时器显示 -->
        <view class="timer-display">{{ formatTime(timer) }}</view>
        <view class="btn_box">
          <view class="btn again" v-if="timer" @click="reset">
            <van-image
              class="img_bg"
              src="/static/assets/ly_reload.jpg"
            />
            重录
          </view>
          <view class="btn begin" @click="begin"><van-image
            class="img_bg"
            width="17"
            height="26"
            src="/static/assets/ly_b2.png"
          />{{ isplayText }}</view>
          <view class="btn add" v-if="recordedAudioUrl" @click="add"><van-image
            class="img_bg"
            src="/static/assets/ly_reload.jpg"
          />保存</view>
        </view>
      </view>
      
      <!-- 内容列表 -->
      <view class="top" v-if="activeSidebar != 0">
        <view class="add_kj" @click="activeSidebar = 0"><van-icon name="/static/assets/kejianAdd.png" style="margin-right: 6px; font-size: 24px;"/>新建录音</view>
      </view>
	  <van-empty description="暂无录音,请上传!" v-if="list.length == 0" style="height: calc(100% - 50px);" image="/static/assets/empty_list.png" :image-size="[260, 260]"/>
      <van-grid :gutter="12" :column-num="3" :border='false' v-if="activeSidebar != 0">
        <van-grid-item v-for="(item, value) in list" :key="value">
          <view class="item-top">
            <view class="text">{{item.name}}</view>
            <view class="top-right">
              <van-icon @click="playMusic(item)" :name="isPlaying2!=item.id ? '/static/assets/jpq_play.jpg' : '/static/assets/jpg_stop1.jpg'" style="font-size: 30px;position: relative;top: -4px;"/>
            </view>
          </view>
          <view class="item-bottom">
			  <van-swipe-cell class="cell">
			  <van-icon class="icon_l" name="/static/assets/play_time.jpg" /><view class="thin" style="font-size: 14px;display: inline-block;">{{item.duration}}</view>
			  <van-icon class="icon_r" name="/static/assets/kejian_nav2.png" @click="fenxiang(item)"/>
			    <template #right>
			      <van-icon class="del" @click="delD(item)" style="font-size: 20px;margin-left: 15px;margin-right: 15px;margin-top:1px;" name="/static/assets/delIcon.png" />
			    </template>
			  </van-swipe-cell>

          </view>
        </van-grid-item>
      </van-grid>
    </view>
    
    <!-- 新建目录 -->
    <van-dialog class="add_log" v-model:show="addShow2" title="新建分类" show-cancel-button @confirm="addMl">
      <view class="kjBox2" style="padding: 10px 0;">
        <van-field v-model="mlTitle" placeholder="请输入分类名称" style="border-radius: 30px;box-shadow: 0 0 8px 0 #f3f3f3;"/>
      </view>
    </van-dialog>
    
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
          <van-field v-model="lyTitle" placeholder="请输入文件名称" style="height: 34px;border-radius: 34px;box-shadow: 0 0 8px 0 #f3f3f3;"/>
        </view>
      </view>
    </van-dialog>
    
    <!-- 分享课件 -->
    <van-popup class="fxLeftBox" v-model:show="showL" position="left" style="width: 50%;height: 100%;" overlay-class="fxLeftOver">
      <view class="fxLeft">
        <view class="fxLeft_title">
          <view class="flex_return" @click="showL = false">
            <van-icon
              class="returnIcon"
              :name="'/static/assets/qunL.png'"
            /> 
            <view class="text">返回</view>
          </view>
        </view>
        <view class="fxContent">
          <view class="fxTitle">
            您即将分享的录音: 
            <view class="fxTitleName">{{fxItem.name}}</view>
          </view>
          <view class="fxList">
            您的班级群: 
            <view class="fxLi" v-for="item in classItem" @click="item.isCheck = !item.isCheck">
              <van-icon
                class="fxLiIcon"
                :name="'/static/assets/class.png'"
              /> 
              <view class="fxLiname">{{item.name}}</view>
              <van-icon
                class="fxLiCheck"
                :name="item.isCheck ? '/static/assets/checked.png' : '/static/assets/check.png'"
              /> 
            </view>
          </view>
          <view class="fxBtn">
            <view class="fxBBtn" @click="fasong">发送</view>
          </view>
        </view>
      </view>
    </van-popup>
  </view>
</template>

<script setup>
import { ref, onMounted ,onBeforeUnmount } from 'vue';
import { classList, sendMsg, getrecordingGateList, delrecordingGateList, addrecordingGateList, addrecordingList, fileUpload, recordingList,recordingDelete } from '/api/home.js';
import { showToast, showConfirmDialog, showLoadingToast, Toast } from 'vant';

const navItems = ref([
  { name: '声乐' },
  { name: '器乐' },
]);

const soundEffects = [
  { text: '原声', icon: "url(/static/assets/ly1.png)" },
  { text: '考场', icon: "url(/static/assets/ly2.png)" },
  { text: '录音棚', icon: "url(/static/assets/ly3.png)" },
  { text: '音乐厅', icon: "url(/static/assets/ly4.png)" },
];
const activeIndex = ref(0);
const activeSidebar = ref(0);
const isPlaying = ref(false);
const isplayText = ref('开始');
const timer = ref(0);
const addShow = ref(false);
const addShow2 = ref(false);
const mlTitle = ref('');
let mediaRecorder;
let audioChunks = [];
let interval;
const lyTitle = ref("");

const checked = ref('');
const recordedAudioUrl = ref('');
const recordedAudioBlob = ref(null);
const recordedDuration = ref('00:00.00');
const list = ref([]);

const fxItem = ref({});
const classItem = ref([]);
const showL = ref(false);

if(history.state.id){
	activeSidebar.value = history.state.id;
	getList()
}

function fenxiang(item){
	classList().then(res =>{
		if(res.code == 0){
			showL.value = true;
			fxItem.value = item;
			classItem.value = res.data;
		}else{
			showToast(res.msg)
		}
	})
}

function fasong(){
	let arr = [];
	classItem.value.forEach(e =>{
		if(e.isCheck){
			arr.push(e)
		}
	})
	if(arr.length == 0){
		showToast('请先选择要分享的班级群');
		return false;
	}
	
	let num = 0;
	arr.forEach(e =>{
		//发送消息
		let param = {
		  "classId": e.id,
		  "content": JSON.stringify(fxItem.value),
		  "param1": "voice",
		  "param2": "",
		  "param3": "",
		  "param4": "",
		  "param5": "",
		  "type": 3
		}
		sendMsg(param).then(res =>{
		  if(res.code == 0){
			num += 1;
			showL.value = false;
			if(num == arr.length){
				showToast('消息已成功发送')
			}
		  }else{
			  showToast(res.msg)
		  }
		})
	})
}

function delD(item){
	showConfirmDialog({
	  confirmButtonText:"删除",
	  confirmButtonColor:"#ff004a",
	  message:
	    '删除后不可恢复，请谨慎操作！',
	})
	  .then(() => {
	    // on confirm
		recordingDelete({id:item.id}).then(res =>{
			if(res.code == 0){
				getList()
			}else{
				showToast(res.msg)
			}
		})
	  })
	  .catch(() => {
	    // on cancel
	  });
}

onBeforeUnmount(() => {
    if (mediaRecorder) {
        console.log('MediaRecorder state before stopping:', mediaRecorder.state); // 打印状态

        if (mediaRecorder.state === 'recording') {
            mediaRecorder.stop();
        }

        if (mediaRecorder.stream && mediaRecorder.stream.getTracks().length > 0) {
            console.log('Tracks before stopping:', mediaRecorder.stream.getTracks()); // 打印轨道信息
            mediaRecorder.stream.getTracks().forEach(track => {
                track.stop();
                console.log('Track stopped:', track); // 打印每个轨道的停止状态
            });
        } else {
            console.log('No tracks to stop.'); // 如果没有轨道，则打印提示信息
        }
    } else {
        console.log('MediaRecorder not initialized.'); // 如果MediaRecorder未初始化，则打印提示信息
    }

    stopTimer();
});

// 获取目录
getMl();

function getMl(){
	getrecordingGateList().then(res =>{
		navItems.value = res.data;
	})
}

// 新增目录
function addMl(){
	if(!mlTitle.value){
		showToast('请填写目录名称！')
		return false;
	}
	addrecordingGateList({id:"",name:mlTitle.value}).then(res =>{
		getMl();
	})
}

// 获取列表
function getList(){
	let params = { "categoryId": activeSidebar.value, "current": 1, "size": 1000 };
	recordingList(params).then(res =>{
		list.value = res.data;
	})
}

// 音频播放
const audioElement = document.createElement('audio');
const isPlaying2 = ref(0);

function playMusic(item) {
  if (isPlaying2.value == item.id) {
    isPlaying2.value = 0;
    audioElement.pause();
  } else {
    isPlaying2.value = item.id;
    audioElement.src = item.url;
    audioElement.play();
  }
  // 监听音频播放结束事件
  end(item)
}

function end(item){
	audioElement.addEventListener('ended', function() {
	    isPlaying2.value = 0;
	});
}

const onSelectNavItem = (item) => {
  activeSidebar.value = item.id;
  getList()
};

// 保存录音
function add(){
	if(recordedAudioUrl.value){
		addShow.value = true;
	}
}

const isLoad = ref(false);

// 录音试听
function playRecordedAudio() {
  if (recordedAudioUrl.value) {
    const audio = new Audio(recordedAudioUrl.value);
	isLoad.value = true;
    audio.play();
	audio.onended = function (){
		isLoad.value = false;
	}
  }
}

function selectSoundEffect(index) {
  activeIndex.value = index;
}

function onBeforeClose(action, done){
	if(action == 'cancel'){
		addShow.value = false;
	}
}

function setupRecorder() {
  navigator.mediaDevices.getUserMedia({ audio: true })
    .then(stream => {
      mediaRecorder = new MediaRecorder(stream);
      mediaRecorder.ondataavailable = e => {
        audioChunks.push(e.data);
      };
      mediaRecorder.onstop = e => {
		const audioBlob = new Blob(audioChunks, { type: 'audio/mp3' });
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
				showToast('上传成功！');
				activeSidebar.value = checked.value;
				addShow.value =false;
				getList()
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

function begin() {
  if (isPlaying.value) {
    // 如果已经在录音，停止录音
    mediaRecorder.stop();
    mediaRecorder.stream.getTracks().forEach(track => track.stop()); // 停止所有轨道，释放录音权限
    stopTimer();
    isPlaying.value = false;
    isplayText.value = '开始';
  } else {
    navigator.mediaDevices.getUserMedia({ audio: true })
      .then(stream => {
        if (mediaRecorder) {
          // 如果已存在录音对象，则先释放之前的资源
          mediaRecorder.stream.getTracks().forEach(track => track.stop());
        }
        // 创建新的录音对象
    	const options = {
    	  mimeType: 'video/mp4',
    	  videoBitsPerSecond : 100000
    	};
    	
    	mediaRecorder = new MediaRecorder(stream, options);
        mediaRecorder.ondataavailable = e => {
          audioChunks.push(e.data);
        };
        mediaRecorder.onstop = e => {
          const audioBlob = new Blob(audioChunks, { type: 'audio/mp3' });
          const audioUrl = URL.createObjectURL(audioBlob);
          audioChunks = [];
          recordedAudioUrl.value = audioUrl;
          recordedAudioBlob.value = audioBlob;
          recordedDuration.value = formatTime(timer.value);
        };
        mediaRecorder.start();
        startTimer();
        isPlaying.value = true;
        isplayText.value = '暂停';
    	timer.value = 0;
      })
      .catch(e => console.error(e));
  }
}

function startTimer() {
  interval = setInterval(() => {
    timer.value += 10;
  }, 10);
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

function formatTime(milliseconds) {
  const mins = Math.floor(milliseconds / 60000);
  const secs = Math.floor((milliseconds % 60000) / 1000);
  const millis = Math.floor((milliseconds % 1000) / 10);
  return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}.${millis.toString().padStart(2, '0')}`;
}

onMounted(() => {
  getMl();
});

// 删除目录
function del(item){
	showConfirmDialog({
	  confirmButtonText:"删除",
	  confirmButtonColor:"#ff004a",
	  message:
	    '删除分类后将删除该分类下所有录音，请谨慎操作！',
	})
	  .then(() => {
	    // on confirm
		delrecordingGateList({id:item.id}).then(res =>{
			if(res.code == 0){
				getMl();
			}else{
				showToast(res.msg)
			}
		})
	  })
	  .catch(() => {
	    // on cancel
	  });
}
</script>


<style lang="scss" scoped>
.app-container23 {
  display: flex;
  height: 100%;
  ::v-deep .van-dialog__header{
  	background: #fff;
	font-weight: 400;
  }
  ::v-deep .add-box{
  	width: 70%;
  	height: 70%;
  }
  ::v-deep .van-dialog__footer{
  	position: absolute;
  	width: 100%;
  	bottom: 0;
  }
  .img.active{
  	border: 2px solid #00c9a4;
	border-radius: 9px;
  }
  .top{
	  position: absolute;
	  bottom: 15px;
  	height: 40px;
  	margin-bottom: 16px;
	right: 14px;
  	.add_kj{
  	    float: right;
  	    margin-right: 10px;
  	    width: 135px;
  	    height: 43px;
  	    line-height: 43px;
  	    background: #00c9a4;
  	    text-align: center;
  	    border-radius: 9px;
		font-size: 16px;
  		color: #fff;
		display: flex;
		justify-content: center;
		align-items: center;
  	}
  }
  .sidebar-item{
  	    text-align: center;
  	    height: 44px;
  	    border-bottom: 1px solid #dddddd38;
  		.btn{
  			width: calc(100% - 6px);
  			margin: 0 auto;
  			margin-top: 5px;
  			height: 34px;
  			line-height: 34px;
  			position: relative;
			overflow: hidden;
			text-overflow: ellipsis;
			white-space: nowrap;
  		}
  		.btn.active{
  			    background: #F6F7FB;
  			    color: #000;
  			    border-radius: 8px;
  				
  		}
  		.del{
  			    font-size: 16px;
  			    width: 50px;
  			    height: 32px;
  			    text-align: center;
				display: flex;
				justify-content: center;
				align-items: center;
  		}
  }
	.ly{
		height: 100%;
		display:flex;
		flex-direction: column;
		.img{
			width: 100%;
		    height: 70%;
		    display: flex;
		    justify-content: center;
		    flex-direction: column;
		    align-items: center;
			.box1{
				background-color: #000;
				background-image: url(/static/assets/ly_b.png);
				background-repeat: no-repeat;
				width: 200px;
				height: 200px;
				background-size: 83px 115px;
				background-position: center;
				position: relative;
				z-index: 9;
				border-radius: 50%;
				.lyPlay{
					position: absolute;
					width: 100%;
					height: 100%;
					font-size: 200px;
				}
			}
			.box2,.box3,.box4{
				position: absolute;
				border-radius: 50%;
				animation-duration: 3s;
				animation-iteration-count: infinite;
				animation-timing-function: linear;
			}
			.playing{
				width: 200px !important;
				height: 200px !important;
				background: #00c9a4 !important;
				animation-name:circleChange;
			}
			.box2{
				width: 230px;
				height: 230px;
				background: #00c9a4;
				z-index: 8;
				animation-delay: 1s;
			}
			.box3{
				width: 270px;
				height: 270px;
				background: #86e2c9;
				z-index: 7;
				animation-delay: 2s;
			}
			.box4{
				background: #e2f8f2;
				width: 310px;
				height: 310px;
				z-index: 6;
				animation-delay: 3s;
			}
		}
		.btn_box{
			display: flex;
			justify-content: center;
			align-items: center;
			.btn{
				margin: 0 20px;
				width: 120px;
				height: 36px;
				background: #f6f7fb;
				text-align: center;
				line-height: 36px;
				border-radius: 30px;
				font-size: 20px;
				.img_bg{
					width: 18px;
				    height: 18px;
				    margin-right: 10px;
				    position: relative;
				    top: 2px;
				}
			}
			.begin{
				background: #00c9a4;
				background-size: cover;
				color: #fff;
				width: 160px;
				height: 52px;
				line-height: 52px;
				font-size: 26px;
				display: flex;
				justify-content: center;
				align-items: center;
				.img_bg{
					width: 36px;
				    height: 36px;
				    margin-right: 10px;
					position: relative;
					top: -1px;
				}
			}
			.add{
			}
		}
	}
	@keyframes circleChange {
		0%{transform: scale(1);opacity: 0.95;}
		25%{transform: scale(1.2);opacity: 0.75;}
		50%{transform: scale(1.4);opacity: 0.5;}
		75%{transform: scale(1.6);opacity: 0.25;}
		100%{transform: scale(1.8);opacity: 0.05;}
	}
	.timer-display {
	  font-size: 26px;
	  color: #333;
	  text-align: center;
	  margin-bottom:40px;
	  position: relative;
	  top: -30px;
	}
  .sidebar {
	width: 112px;
	padding: 3px;
    height: 100%;
    background: #fff;
    border-radius: 9px;
    overflow: hidden;
	position: relative;
	.sidebar-title::after{
		content: "";
		width: 15px;
		height: 15px;
		background: url(/static/assets/bottom_1.png) no-repeat;
		background-size: cover;
		position: absolute;
		bottom: -14px;
		right: 19px;
	}
    .sidebar-title {
      // 添加标题样式
		height: 34px;
		margin-bottom: 5px;
		line-height: 34px;
		background: #000;
		color: #fff;
		text-align: center;
		font-size: 18px;
		letter-spacing: 2px;
		border-radius: 9px;
		position: relative;
		.title_icon{
			    border-radius: 50%;
			    width: 20px;
			    height: 20px;
			    font-size: 20px;
			    text-align: center;
			    line-height: 21px;
			    padding-left: 1px;
			    font-weight: 400;
			    margin-right: 10px;
				color:#171a20;
				position: relative;
				left: -11px;
				top: 3px;
		}
    }
	.van-sidebar{
		width: 100%;
		height: calc(100% - 100px);

		overflow-y: auto;
		.van-sidebar-item{
			border-bottom: 1px solid #f8f8f8;
			background: none;
			height: 40px;
			padding: 8px 28px;
			::v-deep .van-badge__wrapper{
				color: #fff;
				width: 84px;
				height: 24px;
				text-align: center;
				line-height: 24px;
				border-radius: 24px;
				letter-spacing: 2px;
				color: #333;
			}
		}
		.van-sidebar-item--select{
			::v-deep .van-badge__wrapper{
				background: #111;
				color: #fff;
			}
		}
		.van-sidebar-item::before{
			display: none;
		}

	}
	.add_box{
		position: absolute;
		bottom: 0;
		width: 100%;
		height: 100px;
		padding: 0px 3px 28px;
		.van_button{
			border: none;
			position: relative;
			width: 100%;
			margin-top: 40px;
			font-size: 16px;
			padding: 12px;
			text-align: center;
			.add_class{
				position: absolute;
				    top: -18px;
				    width: 24px;
				    height: 24px;
				    line-height: 24px;
				    border-radius: 50%;
				    font-weight: 400;
					font-size: 24px;
				    left: 41px;
			}
		}
	}
  }

  .content {
    width: calc(100% - 123px);
    margin-left: 12px;
    background: #fff;
    border-radius: 9px;
	padding: 12px 0px;

	.van-grid{
		::v-deep .van-grid-item{
				 min-width: 187px; 
		}
		::v-deep .van-grid-item__content--center {
	    align-items: center;
	    justify-content: center;
	    background: #f2f3f7;
	    border-radius: 9px;
	    border: none;
		height: 123px;

		.item-top{
			height: 44px;
			width: 100%;
			border-bottom: 2px dashed #fff;
			position: relative;
			font-size: 18px;
			padding: 0 10px;
			.text{
				width: calc(100% - 31px);
				overflow: hidden;
				text-overflow: ellipsis;
				white-space: nowrap;
			}
			.top-right{
				position: absolute;
				right: 10px;
				top: 2px;
				font-size: 16px;
			}
		}
		.item-top::before{
			    content: "";
			    width: 13px;
			    height: 13px;
			    left: -7px;
			    bottom: -7px;
			    background: #fff;
			    border-radius: 50%;
			    position: absolute;
		}
		.item-top::after{
			    content: "";
			    width: 13px;
			    height: 13px;
			    right: -7px;
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
			.icon_l{
				margin-right: 10px;
				position: relative;
				top: 2px;
			}
			.icon_r{
				position: absolute;
				right: 10px;
				bottom: 21px;
				font-size: 18px;
			}
		}

		}
	}
	
  }
}
		::v-deep .van-swipe-cell__right{
			display: flex;
			align-items: center;
			justify-content: center;
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
			background-size: 100% 100%;
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
			padding-left: 15px !important;
			border: none;
			box-shadow: 0 0 8px 0 #f3f3f3;
			padding-right: 10px;
			appearance: none;
			border-radius: 30px;
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
			padding-left: 15px !important;
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

		::v-deep .van-grid-item__content--center{
			padding: 0;
		}

</style>
