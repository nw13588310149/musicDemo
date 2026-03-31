<template>
	<view class="play_content24">
		<view class="top">
		  <van-icon class="return" name="/static/assets/left1.png" @click="left1" />
		  联系我们
		</view>
			<view class="my_info">
				<h1>联系邮箱</h1>
				<p>yyzl654770206@outlook.com</p>
			</view>
	</view>

</template>

<script setup>
import { ref ,onMounted} from 'vue';
import { useRouter} from 'vue-router';
import {logout} from '/api/home.js';
import { showToast , showLoadingToast} from 'vant';
import { useStore } from 'vuex';  // 引入 useStore

const store = useStore();  // 使用 useStore

const router = useRouter();

const myInfo = ref({});
const type = history.state.id;

function left1() {
  router.go(-1);
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
			overflow-y: auto;
			overflow-x: hidden;
			-webkit-overflow-scrolling: touch; /* 兼容iOS滚动 */
			scrollbar-width: none; /* Firefox */
			-ms-overflow-style: none; /* IE/Edge */
			  h1 {
			        color: #00c9a4;
					font-size: 24px;
			    }
			    h2 {
					font-size: 18px;
			        color: #00c9a4;
			    }
			    p {
			        margin: 14px 0;
					font-size: 14px;
			    }
			    .container {
			        background-color: #fff;
			        padding: 20px;
			        border-radius: 8px;
			        box-shadow: 0 0 10px rgba(0,0,0,0.1);
			    }
			
		}

	}
</style>
