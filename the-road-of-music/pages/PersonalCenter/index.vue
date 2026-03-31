<template>
	<view class="my over_y">
		<!-- 头像 -->
		<view class="info">
			<van-image
			  class="head"
			  :src="info.headUrl || '/static/assets/head.jpg'"
			/> 
			<view class="info_right">
				<view class="name">{{info.nickname || '未命名'}} <van-icon class="edit" name="/static/assets/edit_new.png" @click="goInfo" /></view>
				<view class="phone">{{info.mobile}}</view>
				<view class="sf">{{info.role == "teacher"?"老师":info.role == "student"?'学生':'游客'}} 	<view class="vip" v-if="isHide && info.vipExpireDate>=1">年卡会员</view></view>
			</view>
		</view>
		<!-- 会员 -->
		<view class="vip" v-if="isHide">
			<view class="vip_box">
				<view class="tj">音乐之路强烈推荐</view>
				<view class="title">{{vipInfo[0]?.name}}</view>
				<view class="tips">{{vipInfo[0]?.description}}</view>
				<view class="btn" v-if="info.vipExpireDate>3">已开通 </view>
				<view class="money" v-if="info.vipExpireDate<=3"><van-icon class="icon" name="/static/assets/money.jpg" />{{vipInfo[0]?.price}}</view>
			</view>
			<view class="vip_box vip_box2">
				<view class="title">{{vipInfo[1]?.name}}</view>
				<view class="tips">{{vipInfo[1]?.description}}</view>
				<view class="btn" v-if="info.vipExpireDate>=1">已开通 </view>
				<view class="money" v-if="info.vipExpireDate<1"><van-icon class="icon" name="/static/assets/money.jpg" />{{vipInfo[1]?.price}}</view>
			</view>
			<view class="vip_box vip_box3">
				<view class="left">
					<view class="num">0.00</view>
					<view class="title">我的钱包</view>
				</view>
				<view class="right">
					<view class="num">100</view>
					<view class="title">我的积分</view>
				</view>
			</view>
		</view>
		
		<view class="order_box" v-if="isHide">
			<view class="title">我的订单</view>
			<view>
				<van-grid :column-num="8" :border='false' @click="showSx = true">
				  <van-grid-item v-for="value in orderList" :key="value" :icon="value.icon" :text="value.name" />
				</van-grid>
			</view>
		</view>
		
		<!-- 按钮 -->
		<view class="list">
			<view class="li "  @click="showQr"><van-icon class="icon" style="font-size: 20px;position: relative;top: 5px;margin-right: 4px;" name="/static/assets/person1.png" /> 我的二维码 <van-icon class="icon icon_r" name="arrow" /> </view>
			<view class="li "  v-if="isHide" @click="recommendToFriend"><van-icon class="icon" style="font-size: 20px;position: relative;top: 5px;" name="/static/assets/person2.png" /> 推荐音乐之路给好友 <van-icon class="icon icon_r" name="arrow" /> </view>
			<view class="li "  @click="fankui"><van-icon class="icon" style="font-size: 20px;position: relative;top: 5px;" name="/static/assets/person3.png" /> 意见反馈 <van-icon class="icon icon_r" name="arrow" /> </view>
			<view class="li "  @click="email"><van-icon class="icon" style="font-size: 20px;position: relative;top: 5px;" name="/static/assets/person4.png" /> 联系客服 <van-icon class="icon icon_r" name="arrow" /> </view>
			<view class="li " v-if="isHide" @click="vipShow = true" ><van-icon style="font-size: 20px;position: relative;top: 5px;" class="icon" name="/static/assets/person5.png" /> 兑换中心 <van-icon class="icon icon_r" name="arrow" /> </view>
		</view>
		
		<!-- 二维码弹窗 -->
		<van-dialog class="qrcode_box" v-model:show="showQrcode" :showConfirmButton='false'>
			<view style="background: #fff;border-radius:20px;">
				<view class="name">{{info.nickname}}的二维码</view>
				<view class="sf">身份:{{info.role == "teacher"?"老师":info.role == "student"?'学生':'游客'}}</view>
				<view class="phone">手机号: {{info.mobile}}</view>
				<view style="text-align: center;">
					<van-image
						class="img"
						width="260"
						height="260"
						:src="qrImg"
					/>
				</view>
				<view class="btn">保存到相册</view>
				<view class="bottom">
					<view class="thin">使用场景</view>
					<view class="thin">分享:分享给你的好友并邀请他下载音乐之路。</view>
					<view class="thin">添加好友:好友扫码可添加你为好友</view>
				</view>
			</view>
			<view class="close">
				<van-icon @click="showQrcode = false" name="/static/assets/bg_close.jpg" />
			</view>
		</van-dialog>
		
		<!-- vip兑换 -->
		<van-dialog class="add_log" v-model:show="vipShow" title="vip兑换" show-cancel-button @confirm="addVip">
		  <view class="add_content">
		    <van-field v-model="vipCard" placeholder="请输入兑换码" />
		  </view>
		</van-dialog>

		<van-action-sheet
			v-model:show="showRecommendSheet"
			:actions="recommendSheetActions"
			cancel-text="取消"
			close-on-click-action
			@select="onRecommendSelect"
		/>

		<!-- 即将上线 -->
		<van-dialog class="qrcode_box2" v-model:show="showSx" :showConfirmButton='false'>
			<view style="border-radius:20px;overflow: hidden;">
				<van-image
				  src="/static/assets/sx.jpg"
				/>
		
			</view>
			<view class="close">
				<van-icon @click="showSx = false" name="/static/assets/bg_close.jpg" />
			</view>
		</van-dialog>
	</view>
</template>

<script setup>
import { ref ,onMounted} from 'vue';
import { useRouter} from 'vue-router';
import {getMyInfo,getqrcode,vipList,vipCardRedeem,getCheck} from '/api/home.js';
import { showToast} from 'vant';

const router = useRouter();
const info = ref({})
const showQrcode =ref(false);
const showSx = ref(false);
const showRecommendSheet = ref(false);
const recommendSheetActions = ref([]);

/** iOS App Store 推广链接（推荐给好友时复制/系统分享使用） */
const APP_PROMO_URL = 'https://apps.apple.com/cn/app/音乐之路/id6504698046';

function getInviteUrl() {
	if (APP_PROMO_URL) return APP_PROMO_URL;
	// #ifdef H5
	if (typeof window !== 'undefined' && window.location?.href) return window.location.href;
	// #endif
	return APP_PROMO_URL;
}

function recommendToFriend() {
	const list = [];
	// #ifdef H5
	if (typeof navigator !== 'undefined' && typeof navigator.share === 'function') {
		list.push({ name: '系统分享' });
	}
	// #endif
	// #ifdef APP-PLUS
	list.push({ name: '系统分享' });
	// #endif
	list.push({ name: '复制推广链接' });
	recommendSheetActions.value = list;
	showRecommendSheet.value = true;
}

function copyInviteLink() {
	const url = getInviteUrl();
	if (!url) {
		showToast('请在 PersonalCenter 中配置 APP_PROMO_URL 推广链接');
		return;
	}
	uni.setClipboardData({
		data: url,
		showToast: false,
		success: () => showToast('链接已复制，快去发给好友吧'),
	});
}

function shareViaNavigator() {
	const url = getInviteUrl();
	if (!url) {
		showToast('请先配置 APP_PROMO_URL');
		return;
	}
	navigator.share({
		title: '音乐之路',
		text: '推荐你使用「音乐之路」，一起学习音乐！',
		url,
	}).catch((err) => {
		if (!err || err.name !== 'AbortError') showToast('分享失败，可尝试复制链接');
	});
}

function shareViaUniSystem() {
	const url = getInviteUrl();
	if (!url) {
		showToast('请在代码中配置 APP_PROMO_URL');
		return;
	}
	uni.shareWithSystem({
		summary: '推荐你使用「音乐之路」，一起学习音乐！',
		href: url,
		fail() {
			showToast('无法唤起系统分享，可尝试复制链接');
		},
	});
}

function onRecommendSelect(action) {
	if (action.name === '系统分享') {
		// #ifdef H5
		shareViaNavigator();
		// #endif
		// #ifdef APP-PLUS
		shareViaUniSystem();
		// #endif
	} else if (action.name === '复制推广链接') {
		copyInviteLink();
	}
}

const isHide = ref(uni.getStorageSync("checkStatus"));

function calculateDaysRemaining(targetDateStr) {
  // 将传入的日期字符串转换为 Date 对象
  const targetDate = new Date(targetDateStr);
  
  // 获取当前日期
  const currentDate = new Date();
  
  // 计算两者之间的时间差，单位是毫秒
  const timeDifference = targetDate - currentDate;
  
  // 将时间差转换为天数，1天 = 24小时 * 60分钟 * 60秒 * 1000毫秒
  const daysRemaining = Math.ceil(timeDifference / (1000 * 60 * 60 * 24));
  
  return daysRemaining;
}

function fankui(){
		router.push({name:"fankui"})
}

getMyInfo().then(res =>{
	// 已登录
	if(res.code == 0){
		info.value = res.data.user;
		if(info.value.vipExpireDate){
			info.value.vipExpireDate = calculateDaysRemaining(info.value.vipExpireDate)
		}
	}else{
		//未登录
	}
})

const vipShow = ref(false);
const vipCard = ref("");

function addVip(){
	if(vipCard.value){
		vipCardRedeem({cardNumber:vipCard.value}).then(res =>{
			if(res.code == 0){
				showToast('恭喜您成为尊贵的VIP');
				getMyInfo().then(res =>{
					// 已登录
					if(res.code == 0){
						info.value = res.data.user;
						info.value.vipExpireDate = calculateDaysRemaining(info.value.vipExpireDate)
					}else{
						//未登录
					}
				})
			}else{
				showToast(res.msg)
			}
		})
	}
	
}

const vipInfo = ref("");
vipList().then(res =>{
	vipInfo.value = res.data;
})

const orderList = ref([
	{name:"待付款",icon:"/static/assets/order_1.jpg"},
	{name:"待发货",icon:"/static/assets/order_2.jpg"},
	{name:"待收货",icon:"/static/assets/order_3.jpg"},
	{name:"待评价",icon:"/static/assets/order_4.jpg"},
	{name:"退款/售后",icon:"/static/assets/order_5.jpg"},
	{name:"收货地址",icon:"/static/assets/order_6.jpg"},
])

const qrImg = ref('');
function showQr(){
	getqrcode().then(res =>{
		if(res.code == 0){
			qrImg.value = res.data;
			showQrcode.value = true;
		}else{
			showToast(res.msg);
		}
	})
}

function goInfo(){
	router.push({name:"info"})
}
function go(name1){
	router.push({name:name1})
}
function email(){
	router.push({name:"email"})
}
</script>

<style lang="scss" scoped>
	::v-deep .van-grid-item__icon{
		font-size: 26px;
	}
	::v-deep .van-dialog__header{
		background: none;
		font-weight: 200;
	}
	.add_content{
		border: none;
		box-shadow: 0 0 8px 0 #f3f3f3;
	}
	.my{
		background: #fff;
		border-radius: 9px;
		height: 100%;
		padding: 12px;
		.order_box{
			background-color: #f6f7fa;
			border-radius: 9px;
			.title{
				padding: 10px 15px;
				position: relative;
				padding-left: 25px;
				border-bottom: 1px solid #eee;
			}
			.title::before{
				    content: "";
				    position: absolute;
				    left: 16px;
				    width: 3px;
				    height: 12px;
				    background: #00c9a4;
				    border-radius: 4px;
				    top: 14px;
			}
			.van-grid{
				padding: 10px 0;
			}
			.van-grid-item ::v-deep .van-grid-item__content--center{
				background: none;
				.van-grid-item__text{
					font-size: 14px;
					margin-top:10px ;
					color: #3a3a3a;
					font-family: "Harmony_Medium";
				}
			}
		}
		.info{
			padding-bottom: 16px;
			position: relative;
			.head{
				width: 90px;
				height: 90px;
				border-radius:50%;
				overflow: hidden;
				margin: 20px 0 0 20px;
				position: relative;
			}
			.vip{
				position: absolute;
				width: 63px;
				height: 16px;
				background: url(/static/assets/vipBG.png) no-repeat;
				background-size: contain;
				padding: 0;
				font-size: 10px;
				border: none;
				padding: 1px 0;
				padding-left: 17px;
				top: 0;
				left: 44px;
				display: flex;
				align-items: center;
			}
			.info_right{
				position: absolute;
				height: 100%;
				top: 0;
				padding-left: 130px;
				padding-top: 28px;
				.name{
				    color: #000;
				    font-size: 18px;
					position: relative;
					display: flex;
					align-items: center;
					.edit{
					    margin-left: 5px;
					    font-size: 18px;

					}
				}
				.phone{
					    margin: 7px 0 3px 0;
					    font-size: 14px;
				}
				.sf{
					font-size: 10px;
					font-weight: 400;
					background: #00c9a433;
					border-radius: 4px;
					display: inline-block;
					padding: 1.5px 8px;
					position: relative;
					top: -4px;
				}

			}

		}
		.vip{
			padding: 20px 0;
			border-top: 1px solid #6b6b6b1c;
			display: flex;
			.vip_box{
				background: url(/static/assets/card_bg.jpg) no-repeat;
				background-size: 100% 100%;
				width: 32%;
				padding: 10px;
				position: relative;
				border-radius: 9px;
				padding-left: 20px;
				height: 80px;
				.money{
					position: absolute;
					    right: 24px;
					    top: 18px;
					    color: #00c9a4;
					    font-size: 32px;
					    font-weight: 400;
					.icon{
						font-size: 16px;
					}	
				}
				.tj{
					    position: absolute;
					    left: 0;
					    top: -8px;
					    width: 94px;
					    background: #fbe5bd;
					    color: #785c38;
					    font-size: 10px;
					    padding: 1px 5px;
					    border-radius: 9px 10px 10px 0;
				}
				.title{
					color: #fff;
					font-size: 16px;
					font-weight: 400;
					margin-bottom: 5px;
					letter-spacing: 1px;
					margin-top: 10px;
					.icon{
						background: #00c9a4;
						color: #fff;
						width: 20px;
						height: 20px;
						border-radius: 50%;
						text-align: center;
						line-height: 20px;
						margin-right: 6px;
					}
				}
				.tips{
					color: #acacac;
					    font-size: 10px;
					    letter-spacing: 1px;
				}
				.btn{
				    position: absolute;
				    right: 10%;
				    padding: 6px 15px;
				    background: #00c9a4;
				    color: #fff;
				    font-size: 12px;
				    border-radius: 15px;
				    top: 26px;
				}
			}
			.vip_box2{
				margin: 0 2%;
			}
			.vip_box3{
				display: flex;
				.left,.right{
					width: 50%;
					text-align: center;
					position: relative;
					.num{
						font-size: 16px;
					    color: #fff;
					    margin-bottom: 6px;
					    position: relative;
					    top: 10px;
					}
					.title{
						font-size: 10px;
						font-weight: 400;
						position: relative;
						top: 6px;
						color: #ddd;
					}
				}
				.left::after{
					position: absolute;
					right: 0;
					content: "";
					width: 1px;
					height: 100%;
					background: rgb(81 81 81 / 95%);
					top: 0;
				}
			}

		}
		.list{
			margin-top: 15px;
			background: #f6f7fa;
			border-radius: 9px;
			.li{
				height: 50px;
				line-height: 50px;
				padding-left: 15px;
				border-bottom: 1px solid #efefef;
				position: relative;
				font-size: 14px;
				color:#3a3a3a !important;
				.van-icon{
					margin-right: 4px;
					position: relative;
					top: 2px;
				}
				.icon_r{
					position: absolute;
				    right: 8px;
				    top: 16px;
				    color: #c1c1c1;
					padding: 5px 0px 5px 50px;
				}
			}
			.li:last-child{
				border-bottom: none;
			}
		}
		
		::v-deep .qrcode_box2{
			width: 50%;
			background: none;
			.van-dialog__content{
				        background: none;
				        margin-top: -1px;
				        padding: 20px;
				        padding-bottom: 0;
				.close{
					position: relative;
					text-align: center;
					font-size: 30px;
					padding-top: 15px;
				}
			
			}
			.van-dialog__footer{
				display: none !important;
			}
		}
		
		::v-deep .qrcode_box{
			width: 70%;
			background: none;
			.van-dialog__content{
				.name{
					text-align: center;
				    font-size: 20px;
				    padding: 40px 0 16px 0;
				}
				.sf{
					text-align: center;
					    padding: 5px 0;
					    font-size: 12px;
					    color: #888;
					    width: 90px;
					    margin: 0 auto;
					    background: #dcf7f0;
					    border-radius: 50px;
					    margin-bottom: 6px;
				}
				.phone{
					text-align: center;
					padding: 5px 0;
					font-size: 14px;
					color: #888;
				}
				.img{
					margin: 0 auto;
				}
				.btn{
				    margin: 0 auto;
				    background: #00c9a4;
				    color: #fff;
				    font-size: 16px;
				    padding: 5px 16px;
				    border-radius: 16px;
				    width: 140px;
				    text-align: center;
				    margin-top: 10px;
				}
				.bottom{
					border-top: 1px solid #e9e9e9;
					display: flex;
					justify-content: center;
					flex-direction: column;
					align-items: center;
					margin-top: 20px;
					padding-bottom: 20px;
					padding-top: 10px;
					view{
						height: 30px;
						line-height: 30px;
						color: #888;
					}
					
					
				}
				.close{
					position: relative;
					text-align: center;
					font-size: 30px;
					padding-top: 15px;
				}
			
			}
		}
	}
	/* 响应式设计 */
	@media (max-width: 1024px) {
	    /* 在宽度小于等于1024px的平板设备上调整样式 */
		.my .info{
			padding-bottom: 5px;
		}
	
		
	}
</style>