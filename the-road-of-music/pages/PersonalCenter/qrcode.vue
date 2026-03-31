<template>
	<view class="play_content24">
		<view class="top">
		  <van-icon class="return" name="/static/assets/goback.jpg" @click="left" />
		</view>
		<!-- 信息栏 -->
		<view class="my_info">
			<van-image
			  width="500"
			  height="500"
			  :src="url"
			/>
		</view>
	</view>

</template>

<script setup>
import { ref ,onMounted} from 'vue';
import { useRouter} from 'vue-router';
import {getqrcode} from '/api/home.js';
import { showToast} from 'vant';

const router = useRouter();

const url = ref({});


function left() {
  router.push({name:"personal"});
}

getqrcode().then(res =>{
	if(res.code == 0){
		url.value = res.data;
	}else{
		showToast(res.msg);
	}
})



</script>

<style lang="scss" scoped>
	.play_content24{
		height: 100%;
		position: relative;
		.top{
			padding: 7px 10px 5px 16px;
			border-radius: 14px;
			background: #fff;
		}
		.return {
		  font-size: 30px;
		}
		.my_info{
			display: flex;
			justify-content: center;
			align-items: center;
			height: calc(100% - 61px);
			position: relative;
			padding: 30px;
			border-radius: 14px;
			background: #fff;
			margin-top: 16px;
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
					    font-size: 18px;
					    color: #353535;
					    letter-spacing: 1px;
				}
				.icon_r{
					font-size: 18px;
					color: #6b6b6b;
					font-weight: 400;
				}
				.text{
					font-size: 18px;
					color: #6b6b6b;
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
