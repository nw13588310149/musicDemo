<template>
	<view class="play_content24">
		<view class="top">
		  <van-icon class="return" name="/static/assets/left1.png" @click="left1" />
		  系统设置
		</view>
		<!-- 信息栏 -->
		<view class="my_info">
			<view class="li">
				<view class="title">版本更新</view>
				<view class="text">
					1.11
				</view>
			</view>
			<view class="li">
				<view class="title">隐私政策</view>
				<van-icon class="icon_r" name="arrow"  @click="goXy(1)"/>
			</view>
			<view class="li">
				<view class="title">用户协议</view>
				 <van-icon class="icon_r" name="arrow" @click="goXy(2)" />
			</view>
			<view class="li" @click="clearCache">
				<view class="title">清理缓存</view>
				 <van-icon class="icon_r" name="arrow"/>
			</view>
			<view class="li" @click="zx">
				<view class="title">注销账号</view>
				 <van-icon class="icon_r" name="arrow"/>
			</view>
			<view class="li">
				<view class="title">退出登录</view>
				 <van-icon class="icon_r" name="arrow" @click="logO" />
			</view>
		</view>
		

		
	</view>

</template>

<script setup>
import { ref ,onMounted} from 'vue';
import { useRouter} from 'vue-router';
import {logout , feedbackSave} from '/api/home.js';
import { stopGlobalWebSocket } from '../../utils/wsClient.js';
import { showToast , showLoadingToast} from 'vant';
import { useStore } from 'vuex';  // 引入 useStore

const store = useStore();  // 使用 useStore

const router = useRouter();

const myInfo = ref({});

function left1() {
  router.go(-1);
}

function clearCache() {
  try {
    uni.clearStorageSync();
    showToast('缓存已清理');
  } catch (e) {
    showToast('清理缓存失败');
  }
}

function logO(){
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
}

function goXy(type){
	router.push({name:'xieyi',state:{id:type}})
}

const zx = ()=>{
	feedbackSave({content:"注销账号"}).then(res =>{
		if(res.code == 0){
			showToast('您的请求已经提交，我们将尽快为您处理');
		}else{
			showToast(res.msg);
		}
	})
}


</script>

<style lang="scss" scoped>
	::v-deep .van-dialog__header{
		background: none;
		font-weight: 400;
	}
	::v-deep .edit_head{
		width: 70%;
		height: 70%;
		.van-dialog__footer{
			position: absolute;
			bottom: 0;
			width: 100%;
		}
		.head{
			text-align: center;
			margin-top:50px;
		}
		.upload{
			width: 100%;
			text-align: center;
			display: flex;
			justify-content: center;
			margin-top: 40px;
			.van-button--normal{
				background: #00c9a4;
				border: none;
			}
		}
	}
	.add_content{
		border: 1px solid #f2f2f4;
	}
	.play_content24{
		height: 100%;
		position: relative;
		.top{
			justify-content: center;
			text-align: center;
			height: 44px;
			border-radius: 9px;
			display: flex;
			align-items: center;
			padding-left: 10px;
			background: #fff;
			position: relative;
		}
		.return {
		  font-size: 30px;
		  position: absolute;
		  left: 10px;
		}
		.my_info{
			height: calc(100% - 54px);
			position: relative;
			padding: 30px;
			border-radius: 9px;
			background: #fff;
			margin-top: 10px;
			.li{
				    position: relative;
				    display: flex;
				    justify-content: flex-end;
				    border-bottom: 1px solid #f2f2f4;
				    height: 56px;
				    line-height: 56px;
				    align-items: center;
				.title{
					position: absolute;
					    left: 0;
					    font-size: 15px;
					    color: #353535;
					    letter-spacing: 1px;
				}
				.icon_r{
					font-size: 18px;
					color: #6b6b6b;
					font-weight: 400;
					position: relative;
					top: -1px;
					font-weight: 400;
				}
				.text{
					font-size: 14px;
					color: #999999;
					margin-right: 10px;
				}
				.avtor{
					.van-image{
						border-radius: 50%;
						overflow: hidden;
						position: relative;
						top: 7px;
					}
					margin-right: 10px;
				}
			}
			
		}

	}
</style>
