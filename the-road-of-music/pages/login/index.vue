<template>
	<view class="login">
		<view class="logo">
			<van-image
			  width="185"
			  height="186"
			  style="margin-bottom: 12px;"
			  src="/static/assets/logo_b.png"
			/>
			<text class="text">音乐之路，让梦想不再遥远</text>
		</view>
		<view class="box">
			<view class="title">欢迎登录</view>
			<van-form class="form" @submit="onSubmit">
			  <van-cell-group inset>
			    <van-field
			      v-model="username"
			      name="手机号"
			      left-icon="/static/assets/login_phone.png"
			      placeholder="请输入手机号"
			    />
			    <van-field
			      v-model="password"
			      type="password"
			      name="密码"
			      left-icon="/static/assets/login_password.png"
			      placeholder="请输入密码"
			    />
			  </van-cell-group>
			  <view class="yk" @click="ykLogin()">游客登录</view>
			  <view class="forget" @click="forget()">忘记密码？</view>
			  <div style="margin-top: 16px;">
			    <van-button round block type="primary" native-type="submit">
			      立即登录
			    </van-button>
			  </div>
			  <div class="tip">没有账号，<text @click='reg()'>注册新账号</text></div>
			</van-form>
		</view>
	</view>
</template>

<script setup>
import { ref } from 'vue';
import {login,updateToken,reportCid,getCheck} from '../../api/home.js'
import {showToast} from 'vant';
import { useRouter } from 'vue-router';
import bus from '../../utils/eventBus';
const username = ref('');
const password = ref('');
const router = useRouter();

const onSubmit = (values) => {
	//上架屏蔽
	getCheck().then(res =>{
		uni.setStorageSync('checkStatus',res.data)
	})
	//获取系统信息
	uni.getSystemInfo({
		success(res){
			let param = {
				  // "deviceId": res.deviceId,
				  'deviceId':"17186897471475123686",
				  "deviceName": res.deviceModel,
				  "deviceType": res.deviceType,
				  "mobile": username.value,
				  "password": password.value
			}
			login(param)
			.then(res =>{
				  if(res.code == 0){
					  uni.setStorageSync('token',res.data.token);
					  updateToken(res.data.token);
					  showToast('登录成功！');
					  bus.emit('login-success');
					  router.push({ name: 'home'});
					//上报cid
					
					//获取push客户端标记
					let cid = uni.getStorageSync('pushId')
					console.log('loginCid',cid)
					if(cid){
							reportCid({cid:cid}).then(data =>{
								if(data.code == 0){
									console.log(11111111,cid)
								}else{
									showToast(data.msg)
								}
							})
					}

					  

				  }else{
					showToast(res.msg);  
				  }
			})
		}
	})
	

};

const reg = ()=>{
	router.push({ name: 'register'});
}
const forget = ()=>{
	router.push({ name: 'forget'});
}

const ykLogin = ()=>{
	uni.setStorageSync('token','youke');
	router.push({ name: 'home'});
}
</script>

<style lang="scss" scoped>
	.van-cell:after{
		display: none;
	}
	.login{
		z-index: 2001;
		position: fixed;
		width: 100%;
		height: 100%;
		background: #fff;
		top: 0;
		left: 0;
		background-image: url('/static/assets/logo_bg.jpg');
		background-size: 100% 100%;
		background-repeat: no-repeat;
		background-position: bottom;
		display: flex;
		.logo{
			display: flex;
			justify-content: center;
			align-items: center;
			width: 45%;
			height: 100%;
			flex-direction:column;
			padding-left: 60px;
			.text{
				margin-top: 20px;
				font-size: 20px;
			}
		}
		.box{
			width: 55%;
			display: flex;
			justify-content: center;
			align-items: center;
			height: 100%;
			flex-direction:column;
			.title{
				    margin-bottom: 30px;
				    font-size: 25px;
					font-family: "douyu";
				    font-weight: 500;
				    letter-spacing: 3px;
				    color: #171a20;
			}
			.form{
				width: 365px;
				.van-cell-group{
					background: none;
					margin: 0;
				}
				.van-cell{
					margin-bottom: 24px;
					height: 45px;
					border-radius:9px;
					overflow: hidden;
					display: flex;
					align-items: center;
					::v-deep .van-field__left-icon{
						margin-right: 13px;
					}
					::v-deep .van-field__control{
						font-size: 14px;
						color: #C2C2C2;
					}
				}
				.van-cell:last-child{
					margin-bottom: 10px;
				}
				.van-button {
					background: #00c9a4;
					border: none;
					border-radius: 12px;
					::v-deep .van-button__text{
						color: #fff;
						letter-spacing: 2px;
						font-size: 16px;
					}
				}
			}
			.forget{
				text-align: right;
				margin-bottom: 50px;
				color: #00c9a4;
				font-size: 13px;
			}
			.yk{
				position: absolute;
				color: #999;
				font-size: 13px;
			}
			.tip{
				text-align: center;
				font-size: 13px;
				margin-top: 10px;
				::v-deep span{
					color:  #00c9a4;
				}
			}
		}
		
	}
</style>