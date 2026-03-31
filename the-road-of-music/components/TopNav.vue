<template>
    <div class="top">
		<div class="logo">
						<!-- logo -->
						<van-image
						  class="logo-img"
						  :src="logoImg || '/static/assets/logo.jpg'"
						/>
		</div>
      <div class="s">
		  <van-popover v-model:show="showPopover4"   class="inpuS">
			  <view class="txBox2">
				  <van-tabbar class="xz" v-model="activeSearch">
				    <van-tabbar-item name="text">课程（{{searchAll[0].list.length || 0}}）</van-tabbar-item>
					<van-tabbar-item name="video">视频（{{searchAll[1].list.length || 0}}）</van-tabbar-item>
				    <van-tabbar-item name="ly">录音（{{searchAll[2].list.length || 0}}）</van-tabbar-item>
				    <van-tabbar-item name="note">笔记（{{searchAll[3].list.length || 0}}）</van-tabbar-item>
				  </van-tabbar>
				  <view v-for="item in searchAll" >
					  <view class="searchList" v-if="item.name == activeSearch">
					  	<van-empty description="暂无结果" v-if="item.list.length == 0"  image="/static/assets/empty_search.png"/>
					  	<view class="over_y" v-if="item.list.length > 0">
					  		<view class="li" v-for="(a,key) in item.list" @click="goDetail(a)">
								<view class="num">{{key+1}}</view>
								<view class="text">{{a.title || a.name}}</view>
							</view>
					  	</view>
					  </view>
				  </view>
				
			  </view>
		  	<template #reference>
				<van-search class="search_box" v-model="search" placeholder="搜索" custom-class="search-box"></van-search>
		  	</template>
		  </van-popover>
		<div class="right">
			<!-- 提醒 -->
			<van-popover v-model:show="showPopover1">
			  <view class="txBox">
				<view class="boxTitle">通知({{msgL.length}}) <view class="yd" @click="plD">批量已读</view></view>
				<view class="list over_y">
					<van-empty description="暂无通知" v-if="msgL.length == 0" image="/static/assets/empty_notice.png"/>
					<view class="li " v-if="msgL.length>0" v-for="item in msgL" @click="goKb(item)">
						<van-icon v-if="item.targetType == 0" class="remind-img" name="/static/assets/msg1.png" />
						<van-icon v-if="item.targetType == 1" class="remind-img" name="/static/assets/msg2.png" />
						<van-icon v-if="item.targetType == 2" class="remind-img" name="/static/assets/msg3.png" />
						<van-icon v-if="item.targetType == 3" class="remind-img" name="/static/assets/msg4.png" />
						<view class="right">
							<view class="tit" style="overflow: hidden;white-space: nowrap;text-overflow: ellipsis;width: 255px;">{{item.content}}</view>
							<view class="text">{{item.createTime}}</view>
						</view>
					</view>
				</view>
			  </view>
			  <template #reference>
				  <van-image style="margin-left:15px;margin-top: 5px;padding-bottom: 6px;" class="remind-img notice_img" src="/static/assets/remind.png">
					<view class="dian" v-if="unReadNum > 0"></view>
				  </van-image>
			  </template>
			</van-popover>
			<!-- 设置 -->
			<van-image class="remind-img set-img" @click="setGo" src="/static/assets/set.png"/>
			<!-- 扫一扫 -->
			<van-image class="remind-img qrcord-img" @click="showQr" src="/static/assets/qrcode.png"/>
			<!-- 头像 -->
			<van-image class="remind-img avtor-img" :src="info?.headUrl || user?.headUrl || '/static/assets/head.jpg'"/>
			<!-- 昵称 -->
			<van-popover v-model:show="showPopover" :actions="actions"  placement="bottom-end" @select="onSelect">
				<template #reference>
					<view class="name">
						{{info?.nickname || user.nickname}}
						<van-icon class="remind-img" :name="showPopover?'arrow-up':'arrow-down'" />
					</view>
				</template>
			</van-popover>
		</div>
		
      </div>
	    <!-- 扫码弹出层 -->
	    <van-popup v-model:show="showQrCodePopup" position="bottom" :duration="0" :lazy-render="false" :style="{ height: '100%',background:'none' } ">
			<view class="scanContent">
				<van-icon class="return" name="/static/assets/left1.png" style="font-size: 30px;" @click="showQrCodePopup = false" />
				<view id="reader" style="width: 100%;height: 100%;position: relative;">
				</view>
				<div v-if="true" class="scan-line"></div>
			</view>
	    </van-popup>
		<!-- 修改所在地区（与资料页一致） -->
		<van-popup v-model:show="showRegionPopup" round position="bottom">
		  <van-picker
		    :columns="columnsRegion"
		    title="选择地区"
		    @cancel="showRegionPopup = false"
		    @confirm="onConfirmRegion"
		  />
		</van-popup>
    </div>
</template>

<script setup>
import {ref , watchEffect ,onMounted,watch} from 'vue';
import { showToast , showSuccessToast} from 'vant';
import {getTextbooklist,getCourseware,getVideolist,recordingList,getnoteList, logout , getMyInfo , classQrcodeEnter,getUnReadMsgCount,msgList,updateRead,updateSchool, getCity, editMyInfo} from '/api/home.js';
import { stopGlobalWebSocket } from '../utils/wsClient.js';
import { useRouter} from 'vue-router';
import { useStore } from 'vuex';
import {Html5Qrcode} from "html5-qrcode";
import bus from '../utils/eventBus';

const store = useStore();

const router = useRouter();

const showPopover = ref(false);

const search = ref('')
const showQrCodePopup = ref(false);
const showPopover1 = ref(false);
const showPopover4 = ref(false);
const showRegionPopup = ref(false);
const columnsRegion = ref([]);

getCity().then((res) => {
	if (res?.data?.length) {
		columnsRegion.value = res.data.map((item) => ({ text: item.name, value: item.name }));
	}
});

const unReadNum = ref(0);
const searchAll = ref([{name:'text',list:[]},{name:'video',list:[]},{name:"ly",list:[]},{name:'note',list:[]}]);
const activeSearch = ref('text')
const logoImg = ref();
const showLine = ref(false);

// 搜索
watch(search, (newValue, oldValue) => {
  if (newValue) {
    sear(newValue)
  }
});

function goKb(item){
	if(item.targetType == 3){
		router.push({ name: 'smart-campus',state:{name:'我的课表'}})
	}else if(item.targetType == 1){
		showToast(item.extData.content);
	}
}

//跳转
function goDetail(item){

	let currentPage = history.state.current;

	if(item.type == 1 || item.type == 3 || item.type == 4 || item.type == 5){
		if(currentPage == "/musicPlay"){
			store.dispatch('updateId',item.id)
		}else{
			if(item.type == 4 || item.type == 5){
				router.push({ name: 'music', state: { id: item.id,type:2}});
			}else{
				router.push({ name: 'music', state: { id: item.id}});
			}
		}
	}else if(item.type == 2){
		if(currentPage == "/theory"){
			store.dispatch('updateId',item.id)
		}else{
			router.push({ name: 'theory', state: { id: item.id}});
		}
	}else if(item.type == 6){
		if(currentPage == "/video-tutorial"){
			store.dispatch('updateId',item.id)
			store.dispatch('updateTime',new Date())
		}else{
			router.push({ name: 'video', state: { id: item.id}});
		}
	}else if(item.type == "ly"){
		router.push({ name: 'recording', state: { id: item.categoryId}});
	}else if(item.type == "note"){
		router.push({ name: 'noteDetail' ,state:{id:item.categoryId,title:item.title,type:item.paperType,param1:item.param1,sId:item.id}});
	}else if(item.type == 9){
		if(currentPage == "/consultationDetail"){
			store.dispatch('updateId',item.id)
		}else{
			router.push({ name: 'consultationDetail', state: { id: item.id}});
		}
	}
}

function sear(value){
	let param1 = {
  "current": 1,
  "firstMenu": "",
  "keyword": value,
  "province": "甘肃",
  "secondMenu": "",
  "size": 100,
  "type": ""
}
	searchAll.value = [{name:'text',list:[]},{name:'video',list:[]},{name:"ly",list:[]},{name:'note',list:[]}];
	
	// 课程
	getTextbooklist(param1).then(res =>{
		if(res.code == 0){
			searchAll.value[0].list = res.data;
		}
	})
	
	//视频
	getVideolist(param1).then(res =>{
		if(res.code == 0){
			res.data.forEach(e =>{
				e.type = 6;
			})
			searchAll.value[1].list = res.data;
		}
	})
	
	//录音
	recordingList(param1).then(res =>{
		if(res.code == 0){
			res.data.forEach(e =>{
				e.type = 'ly'
			})
			searchAll.value[2].list = res.data;
		}
	})
	
	//笔记
	getnoteList(param1).then(res =>{
		if(res.code == 0){
			res.data.forEach(e =>{
				e.type = 'note'
			})
			searchAll.value[3].list = res.data;
		}
	})
}

function showQr(){
	showQrCodePopup.value = true;
	
	// 获取支持的相机列表
	Html5Qrcode.getCameras().then(devices => {
	  /**
	   * devices 类型为对象数组
	   * { id: "id", label: "label" }
	   */
	  if (devices && devices.length) {
	    let cameraId = devices[1].id;
	    // 开始扫码
	    const html5QrCode = new Html5Qrcode(/* element id */ "reader");
		showLine.value = true;
	    html5QrCode.start(
	      cameraId,
	      {
	        fps: 10,    // 帧率，控制扫描速度
	        qrbox: { width: 380, height: 380}  // 限制要用于扫描的取景器区域
	      },
	      (decodedText, decodedResult) => {
	        // 获取扫描结果
			if(decodedText){
				const parts = decodedText.split('#');
				if(parts[0] == 1){
					html5QrCode.stop()
					classQrcodeEnter({id:parts[1]}).then(res =>{
						if(res.code == 0){
							showQrCodePopup.value = false;
							router.push({name:"smart-campus",state:{id:1}})
							showSuccessToast("恭喜加入班级")
						}else{
							showQrCodePopup.value = false;
							showToast(res.msg)
						}
					})
				}
				
			}
	      },
	      (errorMessage) => {
	        // 结果错误处理
	      })
	    .catch((err) => {
	      // 无法扫描时的错误处理
		  
	    });
	  }
	}).catch(err => {
	  // 处理错误
	  showToast("摄像头无访问权限")
	});
}

const onSelect = (action) => {
	if(action.text == '退出登录'){
		logout().then(res =>{
			if(res.code == 0){
				showToast('退出成功')
				stopGlobalWebSocket()
				localStorage.clear()
				sessionStorage.clear()
				uni.removeStorageSync('token')
				router.push({name:'login'})
			}else{
				
				showToast(res.msg)
			}
		})
	}else if(action.text == '资料修改'){
		router.push({name:"info"})
	}else if(action.icon == '/static/assets/topI1.png'){
		showPopover.value = false;
		showRegionPopup.value = true;
	}
};

function onConfirmRegion({ selectedOptions }) {
	editMyInfo({ province: selectedOptions[0].text }).then((res) => {
		if (res.code == 0) {
			showToast('修改成功！');
			showRegionPopup.value = false;
			getMyInfo().then((r) => {
				if (r.code == 0) {
					store.dispatch('updateInfo', r.data.user);
				}
			});
		} else {
			showToast(res.msg);
		}
	});
}

const setGo = ()=>{
	router.push({name:"set"})
}

const info = ref("");
const user = ref("");
const actions = ref([]);

watchEffect(() => {
  info.value = store.getters.getInfo;
  user.value =  info.value ;
  	actions.value = [
  	  { text: user.value.province || '未设置' , icon: '/static/assets/topI1.png' },
        { text: '资料修改', icon: '/static/assets/topI2.png' },
        { text: '退出登录', icon: '/static/assets/topI3.png' },
  ]
});


getMyInfo().then(res =>{
	if(res.code == 401){
		router.push({name:"login"})
		return
	}
	user.value = res.data.user;
	actions.value = [
	  { text: res.data.user.province || '未设置' , icon: '/static/assets/topI1.png' },
      { text: '资料修改', icon: '/static/assets/topI2.png' },
      { text: '退出登录', icon: '/static/assets/topI3.png' },
]
})

const msgL = ref([]);
//获取未读消息数量
setInterval(function(){
	getUnReadMsgCount().then(res =>{
		unReadNum.value = res.data.unReadMsgCount;
		if(unReadNum.value>0){
			msgList({"current": 1,"size": 10}).then(res =>{
				if(res.code == 0){
					msgL.value = res.data;
				}
			})
		}
	})
},1000*60)

//批量读取
function plD(){
	let arr = [];
	msgL.value.forEach(e=>{
		arr.push(e.id)
	})
	updateRead({ids:arr}).then(res =>{
		if(res.code == 0){
			showToast('消息已处理');
			msgList({"current": 1,"size": 10}).then(res =>{
				if(res.code == 0){
					msgL.value = res.data;
					unReadNum.value = 0;
				}
			})
		}else{
			showToast(res.msg)
		}
		
	})
}

//获取学校
updateS()
function updateS(){
	setInterval(function(){
		updateSchool().then(res =>{
			if(res.code == 0){
				logoImg.value = res.data.logo;
			}
		})
	},30000)
}

onMounted(() => {
  updateS();
  bus.on('login-success', () => {
    updateSchool().then(res =>{
      if(res.code == 0){
        logoImg.value = res.data.logo;
      }
    });
  });
});


</script>

<style lang="scss" scoped>
	::v-deep .van-popover__action-icon{
		font-size: 24px;
	}
::v-deep .van-popover{
	box-shadow: 0 2px 12px 0 rgba(0, 0, 0, 0.1);
}
::v-deep .scanContent{
	height: 100%;
	background: #000;
}
::v-deep .van-popover__content{
	border-radius: 9px;
	overflow:hidden;
}
.scan-line {
    position: absolute;
    top: 0;
	width: 320px;
    left: 50%; /* Center the scan line within the qrbox */
    transform: translateX(-50%); /* Center the scan line exactly */
    height: 2px;
    animation: scan-animation 2s linear infinite;
	z-index: 99999999999;
	background: linear-gradient(to right, rgba(0, 201, 164, 0) 0%, rgba(0, 201, 164, 1) 50%, rgba(0, 201, 164, 0) 100%);
}
.scan-line::before {
    content: '';
    position: absolute;
    top: -6px; /* Adjust this value to position the shadow correctly */
    left: 50%;
    transform: translateX(-50%);
    width: 320px;
    height: 12px; /* Adjust this value to control the height of the shadow */
    background: radial-gradient(ellipse at center, rgba(0, 201, 164, 0.5) 0%, rgba(0, 201, 164, 0) 80%);
    z-index: -1;
}

@keyframes scan-animation {
    0% {
        top: calc(50% - 130px);
    }
    100% {
        top: calc(50% + 130px) /* Height of the qrbox */
    }
}


.scanContent{
	position: relative;
	.return{
		position: absolute;
		left: 24px;
		top: 20px;
		z-index: 999;
	}
	.scan-video{
		width: 100vw;
		height: 100vh;
		z-index: 1;
	}
}

.inpuS{
	.txBox2{
		width: 311px;
		height: 460px;
		.xz{
			position: absolute;
			top: 0;
			border-radius: 9px;
			overflow: hidden;
			::v-deep .van-tabbar-item--active{
				position: relative;
			}
			::v-deep .van-tabbar-item__text{
				font-size: 13px;
			}
			::v-deep .van-tabbar-item--active::after{
				content: "";
				position: absolute;
				width: 40%;
				height: 3px;
				border-radius: 3px;
				left: 30%;
				bottom: 0;
				background: #00c9a4;
			}
		}
		.searchList{
			margin-top: 50px;
			height: 460px;
			padding: 10px;
			.over_y{
				border: 1px solid #f3f3f3;
				border-radius: 4px;
				height: 440px;
				padding: 10px;
				.li{
					height: 44px;
					display: flex;
					align-items: center;
					border-bottom: 1px solid #f3f3f3;
					color: #333;

					.text{
					overflow: hidden;
					text-overflow: ellipsis;
					white-space: nowrap;	
					width: 225px;
					font-size: 12px;
					}
					.num{
						width: 20px;
						height: 20px;
						border-radius: 50%;
						background: #00c9a4;
						display: flex;
						align-items: center;
						justify-content: center;
						color: #fff;
						font-size: 12px;
						margin-right: 10px;
					}
				}
			}
		}
		
	}
}

.txBox{
	width: 330px;
	height: 456px;
	padding: 12px;
	.boxTitle{
		padding: 12px 0;
		border-bottom: 1px solid rgba(5, 5, 5, 0.04);
		margin-bottom: 16px;
		position: relative;
		.yd{
			position: absolute;
			right: 10px;
			top: 12px;
			font-size: 12px;
			padding: 3px 8px;
			border-radius: 4px;
			background: #00c9a4;
			color: #fff;
			box-shadow: 0 0 8px 0 #f3f3f3;
		}
	}
	.list{
		border: 1px solid rgba(5, 5, 5, 0.04);
		border-radius: 8px;
		height: 370px;
		.li{
			height: 67px;
			border-bottom: 1px solid rgba(5, 5, 5, 0.06);
			padding: 6px;
			display: flex;
			align-items: center;
			.right{
				padding-left: 5px;
			}
			.remind-img{
				font-size: 30px;
				margin-top: 4px;
				margin-right: 16px;
			}
			.tit{
				font-size: 14px;
				margin-bottom: 6px;
			}
			.text{
				margin-top: 0px;
				font-size: 12px;
				color: rgba(5, 5, 5, 0.45);
			}
		}
	}
}
	
.top {
  display: flex;
  justify-content: space-between;
  align-items: center;
  height: 71px; 
  padding: 16px 1.25rem;
  padding-left: 0;
}
.logo {
	width: 205px;
	height: 54px;
	display: flex;
	justify-content: center;
	align-items: center;
	margin-top: 4px;
}
.logo-img{
	width: 120px;
}



.remind-img{
	width: 30px;
	height: 30px;
	height: fit-content;
	margin-right: 15px;
}
.notice_img{
	position: relative;
	top: 2.5px;
	width: 27px;
	.dian{
		position: absolute;
		width: 8px;
		height: 8px;
		background: red;
		border-radius: 50%;
		top: 2px;
		right: 3px;
	}
}
.set-img{
	width:28px;
	height: 28px;
}
.qrcord-img{
	width: 28px;
	height: 28px;
	position: relative;
	top: 0px;

}
.avtor-img{
	width:33px;
	height: 33px;
	margin-left: 3px;
	border-radius: 12px;
	overflow: hidden;
	border: 1.5px solid #fff;
	margin-right: 7px;
	
}
.s {
  display: flex;
  align-items: center;
  flex-grow: 1; /* Take remaining space */
}
.s .right{
	width: 100%;
	display: flex;
	justify-content: flex-end;
	align-items: center;
}

.search_box {
    width: 311px;
    height: 36px;
	line-height: 36px;
    background: #fff;
    display: flex;
    border-radius: 40px;
	caret-color: #00c9a4;
	padding: 0;
	flex-shrink:0
}
.search_box::v-deep  .van-search__content{
	background: none;
	padding-left: 0;
}
.search_box::v-deep .van-field__left-icon{
	display: none;
}
.search_box::v-deep .van-field__control{
	padding-left: 0rem;
	position: relative;
	top: 1px;
}
.search_box::v-deep  .van-search__content::before{
	content: "";
	display: inline-block;
	background: url(@/static/assets/search.png);
	background-repeat: no-repeat;
	width: 18px;
	height: 18px;
	margin: 8px;
	margin-left:12px;
	background-size: 100% 100%;
}

.icon-bell, .icon-setting, .icon-manager {
  margin-left: 1.25rem;
}

.name {
  font-weight: 400;
  font-size: 18px; 
  letter-spacing: 0.125rem; 
  display: flex;
  align-items: center;
  position: relative;
  color: #000;
  margin-top: 6px;
  padding-bottom: 6px;
}
.name .remind-img{
	padding-right: 0.3rem;
	width: 1rem;
	margin-right: 0.5rem;
	margin-left: 0.1rem;
}

.icon-bot {
  margin-left: 0.625rem; 
  width: 0.75rem; 
}

/* 添加scanner-wrapper样式以确保扫描器充满弹出层 */
.scanner-wrapper {
  width: 100%;
  height: 100%;
  display: flex;
  justify-content: center;
  align-items: center;
  background-color: #f6f7fb;
}

.qrcode-stream {
  width: 100%;
  height: 100%;
}


</style>