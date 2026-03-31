<template>
	<view class="play_content24">
		<view class="top">
		  <van-icon class="return" name="/static/assets/left1.png" @click="left" />
		  意见反馈
		</view>
		<!-- 信息栏 -->
		<view class="my_info">
			<van-cell-group inset style="margin: 0;">
			  <van-field
				class="message"
			    v-model="message"
			    rows="20"
			    autosize
			    type="textarea"
			    maxlength="400"
			    placeholder="请输入APP存在的问题或给我们的反馈,我们会第一时间处理!"
			    show-word-limit
			  />
			</van-cell-group>
			<view class="btn" @click="tijiao">
				提交
			</view>
		</view>			
	</view>

</template>

<script setup>
import { ref ,onMounted} from 'vue';
import { useRouter} from 'vue-router';
import {feedbackSave} from '/api/home.js';
import { showToast , showLoadingToast} from 'vant';
const router = useRouter();

function left() {
  router.push({name:"personal"});
}

const message = ref("");

function tijiao(){
	if(!message.value){
		showToast('请输入要提交的内容');
		return
	}
	feedbackSave({content:message.value}).then(res =>{
		if(res.code == 0){
			showToast('您反馈的内容已提交，我们将尽快处理，谢谢');
			message.value = ""
		}else{
			showToast(res.msg);
		}
	})
}
</script>

<style lang="scss" scoped>
	.message{
		width: 100%;
		background: #f8f8f8;
		::v-deep .van-field__control{
			font-size: 14px;
		}
		::v-deep .van-field__word-limit{
			color: #ddd;
		}
	}
	.btn{
		width: 120px;
		    height: 50px;
		    line-height: 50px;
		    text-align: center;
		    font-size: 20px;
		    background: #00c9a4;
		    border-radius: 50px;
		    color: #fff;
		    margin: 0 auto;
		    margin-top: 30px;
	}
	::v-deep .van-dialog__header{
		background: none;
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
			height: 44px;
			border-radius: 9px;
			display: flex;
			align-items: center;
			padding-left: 10px;
			background: #fff;
		}
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
		  left: 12px;
		}
		.my_info{
			height: calc(100% - 54px);
			position: relative;
			padding: 12px;
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
					    font-size: 16px;
					    color: #353535;
					    letter-spacing: 1px;
						font-family: 'Harmony_Light';
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
					font-family: 'Harmony_Light';
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
