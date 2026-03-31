<template>
  <view class="login">
    <view class="logo">
      <van-image width="185" height="186"
			  style="margin-bottom: 12px;" src="/static/assets/logo_b.png"/>
      <text class="text">音乐之路，让梦想不再遥远</text>
    </view>
    <view class="box">
      <view class="title">欢迎注册</view>
      <van-form class="form" @submit="onSubmit">
        <van-cell-group inset>
          <van-field
            v-model="username"
            name="手机号"
            left-icon="/static/assets/login_phone.png"
            placeholder="请输入手机号"
          />
		  <view style="position: relative;">
			  <van-field
			  	class="sms_input"
			    v-model="sms"
			    center
			    clearable
			    left-icon="/static/assets/login_sms.png"
			    placeholder="请输入短信验证码"
			  >
			  </van-field>
			  <van-button class="send_btn" size="small" type="primary" :disabled="isSending" @click="sendSms">{{ smsButtonText }}</van-button>
		  </view>

          <van-field
            v-model="password"
            type="password"
            name="密码"
            left-icon="/static/assets/login_password.png"
			placeholder="请输入密码"
            @click-right-icon="showPassword = !showPassword"
          />
        </van-cell-group>
		<div class="gologin" @click="login()">去登录</div>
        <div style="margin-top: 30px;margin-bottom: 10px;">
          <van-button round block type="primary" native-type="submit">立即注册</van-button>
        </div>
        <div class="tip">
          <van-checkbox v-model="checked" checked-color="#171a20" shape="square">同意并愿意遵守<a @click="openTerms" class="a">《音乐之路服务协议》</a></van-checkbox>
        </div>
      </van-form>
    </view>
  </view>
</template>

<script setup>
import { ref } from 'vue';
import {sendSmsApi ,register,updateToken} from '../../api/home.js'
import { showToast ,showSuccessToast, showFailToast} from 'vant';
import { useRouter } from 'vue-router';
const router = useRouter();
const username = ref('');
const sms = ref('');
const password = ref('');
const showPassword = ref(false);
const checked = ref(true);
const isSending = ref(false);
const smsButtonText = ref('发送验证码');
let smsTimer = null;

const onSubmit = () => {
  register({'mobile':username.value,'password':password.value,'smsCode':sms.value})
  .then(res =>{
	  if(res.code == 0){
		 uni.setStorageSync('token',res.data.token);
		 updateToken(res.data.token);
		 showToast('注册成功！');
		 router.push({ name: 'login'});
	  }else{
		showToast(res.msg);  
	  }
  })
};

const sendSms = () => {
  if(!username.value) return;
  if (isSending.value) return;
  
  sendSmsApi(username.value).then((res) =>{
	if(res.code == 200){
			  showToast('短信已发送！');
			   isSending.value = true;
			   smsButtonText.value = '60秒后重发';
			   let countdown = 60;
			   smsTimer = setInterval(() => {
			     countdown--;
			     smsButtonText.value = `${countdown}秒后重发`;
			     if (countdown <= 0) {
			       clearInterval(smsTimer);
			       smsButtonText.value = '发送验证码';
			       isSending.value = false;
			     }
			   }, 1000); 
	}else{
			 showToast(res.msg);  
	}
  })
  

};

const login = () =>{
	router.push({ name: 'login'});
}

const openTerms = () => {
  // 打开服务协议链接
  router.push({name:'xieyi2'})
};
</script>

<style lang="scss" scoped>
	.van-cell:after{
		display: none;
	}
	.gologin{
		    text-align: right;
		    color: #00c9a4;
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
				background: none;
				::v-deep .van-cell-group {
					margin: 0;
					background: none;
				}
				.van-cell{
					margin-bottom: 24px;
					height: 45px;
					display: flex;
					border-radius:9px;
					overflow: hidden;
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
						letter-spacing: 1px;
						font-size: 14px;
					}
				}
				.send_btn{
					position: absolute;
					left: 250px;
					top: 0;
					border-radius: 12px;
					width: 114px;
					height: 45px;
					font-size: 14px;
					background: #00c9a4;
					color: #fff;
					::v-deep .van-button__text{
						color: #fff;
						font-size: 14px;
						font-weight: 400;
					}
				}
			}
			.sms_input{
				width: 240px;
			}
			
			.forget{
				text-align: right;
				margin-bottom: 50px;
				padding: 0 10px;
				color: #111;
			}
			.tip{
				text-align: center;
				font-size: 13px;
				::v-deep span{
					color: #111;
				}
				.van-checkbox{
					justify-content: center;
				}
				.a{
					color: #00c9a4;
				}
				::v-deep .van-checkbox__icon{
					font-size: 14px;
					
				}
			}
		}
		
	}
</style>