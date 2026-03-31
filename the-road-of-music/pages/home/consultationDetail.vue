<template>
  <view class="music-companion26">
    <view class="content-area">
		<view class="top-nav">
		  <view class="title"><van-icon class="right_icon" style="font-size: 30px;" name="/static/assets/left1.png" @click="router.go(-1)"/></view>
		</view>
		<view class="gd">
			<view class="biaoti">
				{{detail?.title}}
			</view>
			<view class="tips">
				<view class="name">音乐之路</view>
				<view class="time">{{detail?.updateTime}}</view>
			</view>
			<!-- 主内容 -->
			<view class="conttent_box" v-html="detail.longText1">
			
			</view>
			<view class="btnB">
				<view style="color: #999999;">阅读 {{detail?.viewCount}}</view>
				<view class="fx" @click="fenxiang(detail)">分享<van-icon class="icon" name="/static/assets/fenxiang.png"/></view>
			</view>

		</view>


    </view>
	
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
					您即将分享的资讯
					<view class="fxTitleName">{{fxItem.title}}</view>
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
						  :name="item.isCheck?'/static/assets/checked.png':'/static/assets/check.png'"
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
import { ref ,watch} from 'vue';
import { useRouter } from 'vue-router';
import {getDetail,classList,sendMsg} from '../../api/home.js' 
import { showToast , showLoadingToast,showConfirmDialog} from 'vant';
import { useStore } from 'vuex';
const store = useStore();
const router = useRouter();
const id = history.state.id;
watch(() => store.getters.getId, (newId) => {
	getDetail(newId).then(res =>{
		if(res.code == 0){
			detail.value = res.data;
		}
	})
});

const fxItem = ref({});
const classItem = ref([]);
const showL = ref(false);
function fenxiang(item){
	classList().then(res =>{
		if(res.code == 0){
			showL.value = true;
			fxItem.value = item;
			console.log(fxItem.value)
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
		  "param1": "news",
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

const detail = ref({});
getDetail(id).then(res =>{
	if(res.code == 0){
		detail.value = res.data;
	}
})

</script>


<style scoped>
.music-companion26 {
	height: 100%;
  .nav-items {
    display: flex;
	padding-left: 5px;
    /* Add button styling if necessary */
	.btn{
		height: 28px;
		border: none;
		background: #f6f7fb;
		border-radius: 4px;
		margin: 0 5px;
		font-size: 16px;
		color:#fff;

	}
	.active{
		background: #111;
	}
	::v-deep span{
		color: #545454;
	}
	.active ::v-deep span{
		color: #fff;
	}
  }

  .content-area {
    height:100%;
	background: #fff;
	border-radius: 9px;
	padding: 0 4px;
	.top-nav{
		height: 52px;
		display: flex;
		align-items: center;
		padding-left: 10px;
		border-bottom: 1px solid #eeeeee;
	}
	.biaoti{
		color: #313131;
		font-size: 18px;
	}
	.btnB{
		margin: 20px 0;
		margin-top: 50px;
		position: relative;
		color: #999999;
		font-size: 14px;
		.fx{
			position: absolute;
			right: 0;
			top: 0;
			color: #999999;
			.icon{
				margin-left: 5px;
				font-size: 16px;
				position: relative;
				top: 2px;
			}
		}
	}
	.tips{
		display: flex;
		margin-top: 10px;
		.name{
			font-size: 14px;
			color: #999999;
			font-family: 'Harmony_Light';
		}
		.time{
			color: #999999;
			font-size: 14px;
			font-family: 'Harmony_Light';
			margin-left: 12px;
		}
	}
	.banner{
		width: 100%;
	}
	.nav_min{
		height: 24px;
		margin: 15px 0;
		.scroll{
			width: 70%;
			overflow-x: auto;
			-webkit-overflow-scrolling: touch; /* 兼容iOS滚动 */
			white-space: nowrap; /* 禁止换行 */ 
			scrollbar-width: none; /* Firefox */
			-ms-overflow-style: none; /* IE/Edge */
			
		}
		.scroll::-webkit-scrollbar {
		  display: none; /* Chrome/Safari/Opera */
		}
		.item{
				display: inline-block;
                padding: 0 10px;
                height: 24px;
                background-color: #f6f7fb;
                text-align: center;
                margin-right: 8px;
                border-radius: 2px;
                line-height: 24px;
                font-size: 14px;
                font-weight: 500;
		}
	}
	::v-deep img{
		max-width: 100%;
	}
	.conttent_box{

		margin-top: 20px;
		min-height: calc(100% - 130px);
		.li:nth-child(2n) {
			margin-left: 5px !important;
			margin-right: 0 !important;
		}
		.li{
			width: calc(50% - 5px);
			height: 80px;
			float: left;
			margin-right: 5px;
			margin-bottom: 10px;
			border-radius: 4px;
			.box{
				border: 1px solid #f2f3f7;
				border-radius: 9px;
				overflow: hidden;
				position: relative;
				min-width: 187px;
				.img{
					width: 70px;
					height: 70px;
					margin: 4px;
					border-radius: 9px;
					overflow: hidden;
				}
				.right{
					position: absolute;
					top: 0;
					left: 0;
					width: 100%;
					height: 100%;
					padding-left: 85px;
					.title{
						width: 100%;
					    background: none;
						padding-top: 19px;
					    color: #171a20;
					    text-align: left;
						font-size: 14px;
					}
					.bottom{
						position: absolute;
						width: 370px;
						bottom: 0;
						height: 30px;
						font-size: 12px;
						display: flex;
						.num{
							background-color: #f2f2f4;
							font-size: 10px;
							padding: 4px 7px;
							height: 20px;
							border-radius: 8px;
							margin-right: 14px;
						}
						.num2{
							background-color: #f2f2f4;
							font-size: 10px;
							padding: 4px 7px;
							height: 20px;
							border-radius: 8px;
							margin-right: 14px;
						}
					}
				}
				.play{
						position: absolute;
                        width: 36px;
                        height: 36px;
                        z-index: 9;
                        left: calc(50% - 18px);
                        height: 36px;
                        top: 30px;
				}
				.is_vip{
						position: absolute;
                        right: 0;
                        top: 0;
                        background: #00c9a4;
                        color: #fff;
                        height: 24px;
                        z-index: 9;
                        font-size: 10px;
                        line-height: 24px;
                        width: 34px;
                        text-align: center;
                        border-radius: 0 0 0 8px;
				}
				
				.tit{
				    height: 30px;
                    line-height: 26px;
                    padding: 0 5px;
                    font-size: 14px;
                    font-weight: 400;
				}
				.time{
					height: 16px;
					line-height: 16px;
					padding: 0 5px;
					font-size: 10px;
					margin-bottom: 6px;
					.left{
						background: #f2f2f4;
						border-radius: 20px;
						padding: 0 5px;
						float: left;
						padding-left: 20px;
						position: relative;
					}
					.left::before{
							content: "";
                            background: url(/static/assets/play_time.jpg) no-repeat;
                            width: 14px;
                            height: 14px;
                            background-size: 14px;
                            position: absolute;
                            left: 2px;
                            top: 1px;
					}
					.right{
						float: right;
						background: #f2f2f4;
						border-radius: 20px;
						padding: 0 5px;
						padding-left: 20px;
						position: relative;
					}
					.right::before{
							content: "";
					        background: url(/static/assets/play_num.jpg) no-repeat;
					        width: 14px;
					        height: 14px;
					        background-size: 14px;
					        position: absolute;
					        left: 2px;
					        top: 1px;
					}
				}
			}
			
		}
	}
	::v-deep .van-grid-item__content{
		padding: 5px;
	}
  }
  .gd{
	  overflow: auto;
	  height: calc(100% - 80px) !important;
	  padding: 28px 18px;
  }
  .gd::-webkit-scrollbar {
    display: none;
  }
}
</style>
