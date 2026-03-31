<script setup>
import {ref} from "vue";	
import {syncMsg} from '/api/home.js';
import {onLaunch} from '@dcloudio/uni-app';
import { useStore } from 'vuex';  // 引入 useStore
import { initGlobalWebSocket } from './utils/wsClient.js';



function getUrlSearch(name) {
  // 未传参，返回空
  if (!name) return null;
  // 查询参数：先通过search取值，如果取不到就通过hash来取
  var after = window.location.search;
  after = after.substr(1) || window.location.hash.split('?')[1];
  // 地址栏URL没有查询参数，返回空
  if (!after) return null;
  // 如果查询参数中没有"name"，返回空
  if (after.indexOf(name) === -1) return null;
 
  var reg = new RegExp('(^|&)' + name + '=([^&]*)(&|$)');
  // 当地址栏参数存在中文时，需要解码，不然会乱码
  var r = decodeURI(after).match(reg);
  // 如果url中"name"没有值，返回空
  if (!r) return null;
 
  return r[2];
}

//获取地址
uni.setStorageSync('pushId',getUrlSearch("cid"))

const store = useStore();  // 使用 useStore

// 消息本地化
let db;
const request = indexedDB.open("chatAppDB",1);

request.onupgradeneeded = function(event) {
    db = event.target.result;

    // 创建对象存储
    const messageStore = db.createObjectStore('messages', { keyPath: 'id' });
    const userStore = db.createObjectStore('users', { keyPath: 'id' });
    const classStore = db.createObjectStore('classes', { keyPath: 'id' });

    // 索引
    messageStore.createIndex('classId', 'classId', { unique: false });
    userStore.createIndex('mobile', 'mobile', { unique: true });
    classStore.createIndex('name', 'name', { unique: false });
};

request.onsuccess = function(event) {
    db = event.target.result;
	initMaxMsgId()
};

request.onerror = function(event) {
    console.error('IndexedDB初始化失败', event);
};

const msgId = ref(0);




//消息存储
function storeData(storeName, data) {
    const transaction = db.transaction([storeName], 'readwrite');
    const store = transaction.objectStore(storeName);

    data.forEach(item => {
		if(storeName == "messages"){
			item.id = item.id/1;
		}else{
			
		}
		store.put(item);

    });

    transaction.oncomplete = function() {
        console.log(`${storeName}存储成功`);
    };

    transaction.onerror = function(event) {
        console.error(`${storeName}存储失败`, event);
    };
}

// 初始化最大消息ID
function initMaxMsgId() {
    const transaction = db.transaction(['messages'], 'readonly');
    const store = transaction.objectStore('messages');
    const request = store.openCursor(null, 'prev');

    request.onsuccess = function(event) {
        const cursor = event.target.result;
        if (cursor) {
            msgId.value = cursor.value.id;
            console.log('最大消息ID:', msgId.value);
        }
    };

    request.onerror = function(event) {
        console.error('获取最大消息ID失败', event);
    };
}

onLaunch(() =>{
	initGlobalWebSocket();
	//获取最新消息ID（AI 问答页不需要班级群聊 syncMsg，避免与 WS 流式无关的频繁请求）
	setInterval(function(){
		getInfo()
	},3000)
	console.log(444)
})

/** 当前是否在 AI 问答页：此页用 WebSocket 做流式回复，不轮询班级群聊 syncMsg */
function isAiChatRoute() {
	try {
		const h = (window.location.hash || '').toLowerCase();
		const p = (window.location.pathname || '').toLowerCase();
		return h.includes('personal-ai') || p.includes('personal-ai');
	} catch (e) {
		return false;
	}
}
	
	
//消息轮询
function getInfo(){
	const token = uni.getStorageSync('token');
	//已经登录
	if(!token){
		return false
	}
	if (isAiChatRoute()) {
		return false;
	}
	
	syncMsg({"offsetMsgId": msgId.value,"size": 20}).then(res =>{
		if(res.code == 0){
			msgId.value = res.data.offsetMsgId;
			// 存储数据到IndexedDB
			if(res.data.msgList && res.data.msgList.length>0){
				storeData('messages', res.data.msgList);
				//获取当前页面
				const pages = history.state.current;
				if(pages == '/smart-campus' || pages == "/chat"){
					store.dispatch('updateMsg2', res.data.msgList);  // 更新 Vuex 中的 info 状态
				}else{
					store.dispatch('updateMsg', res.data.msgList);  // 更新 Vuex 中的 info 状态
				}
			}
			if(res.data.userList){
				storeData('users', res.data.userList);
			}
			if(res.data.classList){
				storeData('classes', res.data.classList);
			}
		}else if(res.code == 401){
			// uni.removeStorageSync('token')
		}
	})
}




// 分类消息
function getMessagesByClassId(classId) {
    return new Promise((resolve, reject) => {
        const transaction = db.transaction(['messages'], 'readonly');
        const store = transaction.objectStore('messages');
        const index = store.index('classId');

        const request = index.getAll(classId);

        request.onsuccess = function(event) {
            resolve(event.target.result);
        };

        request.onerror = function(event) {
            reject('分类消息失败', event);
        };
    });
}

//图片旋转


</script>

<style>
	@font-face {
	    font-style: normal;
	    font-family: 'Harmony_Regular';
	    /*引入HarmonyOS_Sans_SC，目录别搞错*/
	    src: url('/static/font/HarmonyOS_Sans_SC_Regular.ttf') format('truetype');
	}
	@font-face {
	    font-style: normal;
	    font-family: 'Harmony_Medium';
	    /*引入HarmonyOS_Sans_SC，目录别搞错*/
	    src: url('/static/font/HarmonyOS_Sans_SC_Medium.ttf') format('truetype');
	}
	@font-face {
	    font-style: normal;
	    font-family: 'Harmony_Thin';
	    /*引入HarmonyOS_Sans_SC，目录别搞错*/
	    src: url('/static/font/HarmonyOS_Sans_SC_Thin.ttf') format('truetype');
	}
	@font-face {
	    font-style: normal;
	    font-family: 'Harmony_Light';
	    /*引入HarmonyOS_Sans_SC，目录别搞错*/
	    src: url('/static/font/HarmonyOS_Sans_SC_Light.ttf') format('truetype');
	}
	@font-face {
	    font-style: normal;
	    font-family: 'douyu';
	    /*引入HarmonyOS_Sans_SC，目录别搞错*/
	    src: url('/static/font/douyuFont.ttf') format('truetype');
	}
	::v-deep .van-image-preview__close-icon{
		background: url(/static/assets/close1.png) no-repeat;
		background-size: 40px;
		width: 40px;
		height: 40px;
	}
	::v-deep .van-image-preview__close-icon::before{
		display: none !important;
	}
	::v-deep .van-image-preview__index{
		    background-color: #9E9E9E;
		    color: #fff !important;
		    text-shadow: none !important;
		    width: 60px;
		    height: 30px;
		    display: flex;
		    justify-content: center;
		    align-items: center;
		    border-radius: 60px;
			bottom: 40px !important;
			top: auto !important;
			right: -6px !important;
			left:auto !important;
	}
	*{
		box-sizing: border-box;
		padding: 0;
		margin: 0;
		font-weight: 400;
		font-family: 'Harmony_Medium';
	}
	body {
	    -webkit-user-select: none; /* 禁止文本选择 */
	}
	div,view,uni-view{
		color: #3a3a3a;
	}
	/*每个页面公共css */
	uni-page-head{
		display: none;
	}
	img{
		user-select: none;
		-webkit-touch-callout: none;
		-webkit-user-select: none;
		-moz-user-select: none;
		-ms-user-select: none;
		-webkit-user-drag: none; 
	}
	::v-deep img{
		user-select: none;
		-webkit-touch-callout: none;
		-webkit-user-select: none;
		-moz-user-select: none;
		-ms-user-select: none;
		-webkit-user-drag: none; 
	}
	
	.thin{
		font-family: "Harmony_Regular";
		color:#999999;
		::v-deep span{
			font-family: "Harmony_Regular";
			color:#999999;
		}
	}
	
	uni-page-wrapper, uni-page-body,.main-page{
		height: 100% !important;
	}
	.van-empty{
		height: 100%;
	}
	
	::v-deep .add_log {
	  width: 400px;
	  .add_content {
	    margin: 40px 20px;
	    border-radius: 9px;
	    overflow: hidden;
		box-shadow: 0 0 8px 0 #f3f3f3;
	  }
	  .van-dialog__confirm .van-button__content .van-button__text {
	    color: #111;
	    font-weight: 400;
	  }
	}
	::v-deep .van-dialog__header {
	  height: 56px;
	  padding: 0;
	  line-height: 8px !important;
	  font-size: 20px;
	  letter-spacing: 2px;
	  background: #00c9a4;
	  color: #111 !important;
	  font-weight: 400;
	}
	::v-deep .van-picker__confirm{
		color: #00c9a4 !important;
	}
	
	.van-radio__icon--checked .van-icon{
		color: #00c9a4 !important;
		background-color: #171a20 !important;
		border: none !important;
	}
	
	/* 隐藏 Chrome、Safari 和 Opera 的滚动条 */
	::v-deep :host .scroll::-webkit-scrollbar {
	  display: none;
	}
	
	/* 隐藏 IE、Edge 和 Firefox 的滚动条 */
	::v-deep :host .scroll {
	  -ms-overflow-style: none;  /* IE and Edge */
	  scrollbar-width: none;  /* Firefox */
	}
	::v-deep .scroll::-webkit-scrollbar {
	  display: none;
	}
	.over_y{
		overflow-x: hidden;
		overflow-y: auto;
		-ms-overflow-style: none;  /* IE and Edge */
		scrollbar-width: none;  /* Firefox */
		-webkit-overflow-scrolling: touch; /* 兼容iOS滚动 */
		-webkit-mask-composite: source-in;
		mask-composite: intersect;
	}
	.over_y::-webkit-scrollbar {
	  display: none;
	}
	::v-deep .uni-scroll-view::-webkit-scrollbar {
	  display: none;
	}
	
	.van-toast__text{
		color: #fff;
	}
	
	/* 左侧分享 */
	.fxLeftOver{
		background: none !important;
	}
	.fxLeftBox{
		box-shadow: 0 0 16px 0 #D9D9D9;
	}
	.fxLeft{
		height: 100%;
		position: relative;
		padding-bottom: 70px;
		background: url(/static/assets/qunQrbg1.png) no-repeat;
		background-size: cover;
		.fxLeft_title{
			height: 95px;
			text-align: center;
			line-height: 95px;
			border-bottom:2px solid #fff;
			background: #00c9a412;
			color: #00c9a4;
			background: url(/static/assets/qunBG2.png) no-repeat;
			background-size: 266px 63px;
			background-position: right 20px bottom;
			display: flex;
			.flex_return{
				margin-left: 20px;
				display: flex;
				align-items: center;
				.text{
					color: #7F7F7F;
					margin-left: 6px;
					font-size: 16px;
				}
			}
		}
		.fxContent{
			padding: 8px 18px;
			height: calc(100% - 50px);
			overflow-y: auto;
			-ms-overflow-style: none;  /* IE and Edge */
			scrollbar-width: none;  /* Firefox */
			.fxTitle{
				border-bottom: 1px solid rgba(0, 0, 0, .05);
				padding-bottom: 12px;
				background: #fff;
				height: 94px;
				border-radius: 9px;
				padding: 20px 15px;
				color: #404040;
				font-size: 16px;
				.fxTitleName{
					margin-top: 13px;
					font-size: 14px;
					color: #404040;
					background: #E0F8F1;
					display: inline-block;
					font-family: Harmony_Regular;
					font-weight: 400;
					padding: 0 9px;
					border-radius: 20px;
					display: table;
				}
				
			}
			.fxList{
				padding: 12px 0;
				.fxLi{
					padding: 12px 0;
					display: flex;
					align-items: center;
					height: 70px;
					border-bottom: 1px solid rgba(0, 0, 0, .05);
					position: relative;
					.fxLiIcon{
						font-size: 30px;
						margin-right: 10px;
					}
					.fxLiCheck{
						font-size: 20px;
						position: absolute;
						right: 12px;
					}
				}
			}
			.fxBtn{
				position: absolute;
				bottom: 0;
				width: 100%;
				height: 70px;
				left: 0;
				display: flex;
				justify-content: center;
				align-items: center;
				.fxBBtn{
					                width: 100px;
					                height: 40px;
					                background: #00c9a4;
					                color: #fff;
					                border-radius: 9px;
					                text-align: center;
					                line-height: 40px;
					                letter-spacing: 1px;
				}
			}
		}
	}
	
	/* 弹窗 */
	.van-dialog{
		/* min-width: 542px; */
		min-width: 440px;
		border-radius: 9px !important;
		background: none !important;
		::v-deep .van-dialog__header {
			    background: none !important;
			    background-image: url(/static/assets/infoHead.png) !important;
			    background-size: 100% auto !important;
			    height: 87px;
			    line-height: 70px !important;
			    font-weight: 400 !important;
			    font-size: 18px;
		}
		::v-deep .van-dialog__content{
			background: #fff;
			margin-top: -1px;
			padding: 20px;
			padding-bottom: 130px;
		}
		::v-deep .van-hairline--top:after ,.van-hairline--left:after{
			border: none !important;
		}
		::v-deep .van-dialog__footer{
			padding: 50px 0;
			display: flex;
			justify-content: center;
			margin-top: -1px;
			background: #fff;
			        position: absolute;
			        bottom: 0;
			        width: 100%;
		}
		::v-deep .van-dialog__cancel ,.van-dialog__confirm{
			width: 113px;
			height: 36px;
			flex: none;
			border-radius: 26px;
			margin: 0 17px;
			
		}
		::v-deep .van-dialog__cancel{
			background: #E0F8F1;
			.van-button__content{
				color: #00c9a4;
			}
		}
		::v-deep .van-dialog__confirm{
			background: #00c9a4;
			::v-deep .van-button__content .van-button__text{
				color: #fff;
			}
		}

		

	}
		.qrcode_box{
			::v-deep .van-dialog__content{
				background: none;
				margin-top: -1px;
				padding: 20px;
				padding-bottom: 0;
			}
			::v-deep .van-dialog__footer{
				display: none !important;
				padding: 50px 0;
				display: flex;
				justify-content: center;
				margin-top: -1px;
				background: none;
				        position: absolute;
				        bottom: 0;
				        width: 100%;
			}
		}
		
		/* 选择框 */
		::v-deep .van-picker{
			.van-picker__cancel, .van-picker__confirm{
				    background: #ddd;
				    border-radius: 50px;
				    height: 30px;
				    margin: 10px;
			}
			.van-picker__cancel{
				background: #E0F8F1;
				color: #00c9a4;
			}
			.van-picker__confirm{
				background: #00c9a4;
				color: #fff !important;
			}
		}
		
		/* 短消息提示 */
		::v-deep .van-toast{
			background: #000 !important;
			border-radius: 9px !important;
		}
		
		/* 输入框 */
		::v-deep .van-field__control{
			font-size: 15px;
			caret-color:#00c9a4;
		}
		/* 选择框 */
		::v-deep .van-picker__columns{
			padding:0 20px;
			position: relative;
		}
		::v-deep .van-picker__columns::before{
			content: "";
			position: absolute;
			width: calc(100% - 40px);
			height: 44px;
			background: #f3f4f4;
			    top: 50%;
			    transform: translateY(-22px);
			    border-radius: 9px;
		}
		::v-deep .van-picker-column__item--selected .van-ellipsis{
			color: #000;
		}
		
		/* 图片旋转 */
		::v-deep .van-image-preview__image{
			display: flex !important;
			justify-content: center;
			align-items: center;
		}
		::v-deep .rotate-90 {
			-webkit-transform: rotate(90deg);
		  transform: rotate(90deg);
		  width: 70% !important;
		}
		
		::v-deep .rotate-180 {
			-webkit-transform: rotate(180deg);
		  transform: rotate(180deg);
		}
		
		::v-deep .rotate-270 {
		  -webkit-transform: rotate(270deg);
		  transform: rotate(270deg);
		  width: 70% !important;
		}
		
		::v-deep .van-dialog__message{
			    font-size: 16px !important;
			    position: relative;
			    top: 16px;
		}
		::v-deep .van-uploader__preview-delete--shadow{
			width: 18px !important;
			height: 18px !important;
		}
		::v-deep .van-uploader__preview-delete-icon{
			font-size: 16px !important;
		}
		::v-deep .van-uploader__mask-message{
			color: #fff;
		}
		::v-deep .van-empty__description{
			margin-top: -10px !important;
		}
		
		/* 智能听写-钢琴按键 */
		.change_box2{
			height: calc(100% - 70px);
			position: relative;
			margin: 0 -80px;
			.piano-key-wrap{
				height: 100%;
				.piano_f{
					height: 100%;
					.piano-key{
						margin-bottom: 10px;
						float: left;
						height: 50%;
						width: 5.5%;
						background: #fff;
						box-shadow: inset 0 1px 0 #fff, inset 0 -1px 0 #fff, inset 1px 0 0 #fff, inset -1px 0 0 #fff, 0 4px 3px rgba(0,0,0,.2);
						.topBox{
							height: 100%;
							position: relative;
							.notenameBox{
								position: absolute;
								width: 100%;
								height: 100%;
							}
							.notename2{
								position: absolute;
								bottom: 18px;
								left: 50%;
								width: 30px;
								display: flex;
								justify-content: center;
								align-items: center;
								transform: translateX(-15px);
								.c{
									position: relative;
									top: -3px;
									right: -1px;
									font-size: 10px;
									float: left;
								}
							}
						}
					}
				}
				.piano_b{
					position: absolute;
					top: 0;
					height: 25%;
					width: 100%;
					white-space: nowrap;
					.piano-key-black{
						position: relative;
						    height: 100%;
						    background: linear-gradient(-20deg, #333, #171a20, #333);
						    border-color: #666 #222 #111 #555;
						    border-style: solid;
							width:3.85%;
						    border-width: 1px 2px 7px;
						    border-radius: 0 0 2px 2px;
						    box-shadow: inset 0 -1px 2px hsla(0,0%,100%,.4), 0 2px 3px rgba(0,0,0,.4);
						    overflow: hidden;
							display: inline-block;
					}
				}
			}
		.piano-key.active{
			box-shadow: 0 2px 2px rgba(0,0,0,.4) !important;
			height: calc(50% - 2px) !important;
			background: linear-gradient(
					to right,
					rgba(0,0,0,.6) 0%,
					rgba(0,0,0,0.5) 20%,
					rgba(0,0,0,0.4) 40%,
					rgba(0,0,0,0.4) 50%,
					rgba(0,0,0,0.4) 60%,
					rgba(0,0,0,0.5) 80%,
					rgba(0,0,0,0.6) 100%	
				) !important;
		}
		}


</style>
