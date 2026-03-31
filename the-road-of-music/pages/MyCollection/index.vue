<template>
  <view class="music-companion">
    <view class="top-nav">
      <view class="title"><van-icon class="right_icon" name="/static/assets/right.png" /></view>
      <view class="nav-items">
        <van-button plain class="btn" type="default" v-for="item in nav" :class="activeTab.id == item.id ? 'active  animate__animated  animate__bounceIn' : ''" @click="selectTab(item)">{{item.name}}</van-button>
      </view>
    </view>
    <view class="content-area">
		<van-empty description="收藏夹是空的,快去收藏喜欢的内容吧!" v-if="videoList.length == 0" style="height: calc(100% - 50px);" image="/static/assets/empty_fav.png" :image-size="[260, 260]"/>
		<view class="gd" v-if="videoList.length != 0">
			<!-- 主内容 -->
			<van-grid class="kj" style="padding: 0;padding-left: 6px;" :gutter="10" :column-num="4" :border='false' v-if="getTypeNumber(activeTab.name) != 6">
			    <van-grid-item v-for="(item,value) in videoList" :key="value" >
			      <view class="item-top">
					  <view class="text">{{item.target.title}}</view>
					  <view class="top-right">
					  		<van-icon @click="playMusic(item)" :name="!item.isPlaying?'/static/assets/jpq_play.jpg':'/static/assets/jpg_stop1.jpg'" style="font-size: 30px;position: relative;top: -4px;"/>
					  </view>
				  </view>
				  <view class="item-bottom">
					  <van-swipe-cell class="cell" style="padding-bottom: 5px;">
					  <view @click="go(item)" class="thin" style="color: rgb(106, 106, 106);width: 60%;"><van-icon class="icon1"  name="/static/assets/kj_ckxq.png" />查看详情</view>
					  <van-icon  @click="fenxiang(item)" class="icon_r"  name="/static/assets/kejian_nav2.png" />
					    <template #right>
					      <van-icon class="del" @click="delD(item)" style="font-size: 20px;margin-top: -1px;" name="/static/assets/delIcon.png" />
					    </template>
					  </van-swipe-cell>
				  </view>
			    </van-grid-item>
			</van-grid>
			<van-grid class="conttent_box" style="padding: 0;" :border="false" :column-num="4" :gutter="10" v-if="getTypeNumber(activeTab.name) == 6">
			  <van-grid-item class="li" v-for="item in videoList">
				 <view class="box" >
				 		<view class="play" >
				 						<van-image
										@click="tap(item)"
				 						  class="banner"
				 						  src="/static/assets/video_play.jpg"
				 						/> 
				 					 </view>
				 					 <view class="is_vip">{{item.target.vip?'免费':"会员"}}</view>
				 					<van-image

				 						 class="img"
				 						 fit="cover"
				 						 position="left"
				 						 :src="item.target.coverImg"
				 					/> 
									<view class="tit">{{item.target.name}}</view>
									<van-swipe-cell class="cell spCell" style="padding-bottom: 6px;">
									<view class="x">
										<view @click="tap(item)" class="thin" style="color: #6A6A6A;"><van-icon class="icon1" style="font-size: 20px;"  name="/static/assets/kj_ckxq.png" /><view class="text">查看详情</view></view>
										<van-icon @click="fenxiang(item)" class="icon_r"  name="/static/assets/kejian_nav2.png" />
									</view>
									<template #right>
									    <van-icon class="del" @click="delD(item)" style="font-size: 20px;margin-top: -2px;" name="/static/assets/delIcon.png" />
									  </template>
									</van-swipe-cell>
									  
				 					
				 </view> 
			    
			  </van-grid-item>
			</van-grid>
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
					您即将分享的收藏
					<view class="fxTitleName">{{fxItem.title || fxItem.name}}</view>
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
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import { getFavoriteDetailList, getFavoriteList ,favoriteSave,classList,sendMsg} from '../../api/home.js'
import {showToast , showLoadingToast,showConfirmDialog } from 'vant';
import 'animate.css'

const router = useRouter();
const nav = ref([]);

const activeTab = ref({});
const activeNav = ref(0);

const list = ref([]);
const allList = ref([]);
const videoList = ref([]);

const detailN = ref({});
const fxItem = ref({});
const classItem = ref([]);
const showL = ref(false);

const mbType = ref(0);
function fenxiang(item){
	mbType.value = item.type;
	classList().then(res =>{
		if(res.code == 0){
			showL.value = true;
			fxItem.value = item.target;
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
		  "param1": mbType.value == 6?'video':"book",
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


// 获取菜单列表，并确保“全部”始终在第一个
getFavoriteList().then((res) => {
	if(res.code == 401){
		showConfirmDialog({
		  title: '提示',
		  confirmButtonText:"去登录",
		  message:
		    '还未登录，请先登录！',
		})
		  .then(() => {
		    // on confirm
			router.push({name:"login"})
		  })
		  .catch(() => {
		    // on cancel
		  });
	}else{
		nav.value = res.data;
		activeTab.value = res.data[0]; 
		updateContentArea();
	}
})


function getTypeNumber(typeName) {
  const typeMap = {
    '视唱': 1,
    '乐理': 2,
    '听写': 3,
    '声乐': 4,
	'视频':6,
    '器乐': 5,
    '集训营': 7,
    '模考': 8,
    '资讯': 9,
    '答题': 10
  };

  return typeMap[typeName] || null; // 返回相应编号或null（如果类型不存在）
}



// 当选中不同的tab时更新内容区域
function updateContentArea() {
	const parms = ref({
	    current: 1,
	    type: getTypeNumber(activeTab.value.name),
	    size: 100
	})
	getFavoriteDetailList(parms.value).then((res) => {
	    // 处理视频列表数据
		videoList.value = res.data;
	})
}

const parms = ref({
    current: 1,
    firstMenu: activeTab.value.id || null,
    secondMenu: activeNav.value || null,
    size: 10
})


function selectTab(tab) {
    activeTab.value = tab;
    updateContentArea();
}

function tap(value) {
    router.push({ name: 'video', state: { id: value.target.id } });
}

function go(item){
	
	router.push({ name: 'music', state: { id: item.target.id ,type:item.type} });
	// router.push({ name: 'music', state: { id: item.id , type:item.type} });
}

function delD(item){
	showConfirmDialog({
	  confirmButtonText:"确认",
	  confirmButtonColor:"#ff004a",
	  message:
	    '是否确认取消收藏！',
	})
	  .then(() => {
	    // on confirm
		let param = {
			"favorite": 0,
			"targetId": item.targetId,
			"type": item.type
		}
		
		favoriteSave(param).then(res =>{
			if(res.code == 0){
				updateContentArea();
			}else{
				showToast(res.msg)
			}
		})
	  })
	  .catch(() => {
	    // on cancel
	  });
}
</script>


<style scoped lang="scss">
	::v-deep .img .van-image__img{
		border-radius: 0 11px 0 0;
		overflow: hidden;
	}
.music-companion {
	height: 100%;
  .top-nav {
    display: flex;
    justify-content: flex-start;
    align-items: center;
    height: 44px;
	background: #fff;
	border-radius: 9px;
	overflow: hidden;
  }
  
  .kj.van-grid{
	  ::v-deep .van-grid-item{
		 min-width: 187px; 
	  }
  	::v-deep .van-grid-item__content--center {
      align-items: center;
      justify-content: center;
      background: #f2f3f7;
      border-radius: 14px;
      border: none;
	  height: 120px;
  	.item-top{
  		height: 44px;
  		width: 100%;
  		line-height: 26px;
  		border-bottom: 2px dashed #fff;
  		position: relative;
  		font-size: 16px;
  		padding: 0 10px;
		.text{
			width: calc(100% - 31px);
			overflow: hidden;
			text-overflow: ellipsis;
			white-space: nowrap;
		}
  		.top-right{
  			position: absolute;
  			right: 10px;
  			top: 2px;
  			font-size: 12px;
  		}
  	}
  	.item-top::before{
  		    content: "";
  		    width: 13px;
  		    height: 13px;
  		    left: -16px;
  		    bottom: -7px;
  		    background: #fff;
  		    border-radius: 50%;
  		    position: absolute;
  	}
  	.item-top::after{
  		    content: "";
  		    width: 13px;
  		    height: 13px;
  		    right: -16px;
  		    bottom: -7px;
  		    background: #fff;
  		    border-radius: 50%;
  		    position: absolute;
  	}
  	.item-bottom{
  		width: 100%;
  		height: 44px;
  		line-height: 60px;
  		padding: 0 10px;
  		position: relative;
  		color: #757575;
  		font-size: 12px;
  		.icon_l{
  			margin-right: 10px;
  		}
  		.icon1{
  			font-size: 20px;
  			margin-right: 4px;
  			position: relative;
  			top: 5px;
  		}
  		.icon_r{
  			position: absolute;
  			right: 5px;
  			bottom: 22px;
  			font-size: 18px;
  		}
  		.del{
  			font-size: 16px;
  		}
  	}
  	}
  }

  .title {
    width: 44px;
    height: 44px;
    line-height: 44px;
  	text-align: center;
  	font-size: 18px;
  	color: #fff;
  	letter-spacing: 4px;
  	display: flex;
  	justify-content: center;
  	align-items: center;
    /* Add title styling */
  	.right_icon{
  			font-size: 29px;
  			}
  }

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
		background: #000;
	}
	::v-deep span{
		color: #545454;
	}
	.active ::v-deep span{
		color: #fff;
	}
  }

  .content-area {
	margin-top: 12px;
    height:calc(100% - 56px);
	background: #fff;
	border-radius: 9px;
	padding: 12px;
	padding-right: 1px;
	padding-left: 4px;
	view{
		height: 100%;
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
	.conttent_box{
		padding-left: 6px!important;

		.li{
			.box{
				box-shadow: 0 0 8px 0 #f3f3f3;
				border-radius: 9px;
				overflow: hidden;
				position: relative;
				width: 100%;
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
                        background: #fbe5bd;
                        color: #785c38;
                        height: 16px;
                        z-index: 9;
                        font-size: 10px;
                        display: flex;
						justify-content: center;
						align-items: center;
                        width: 34px;
                        text-align: center;
                        border-radius: 0 0 0 8px;
				}
				.img{
					height: 94px;
					width: 100%;

				}

				.tit{
				    height: 30px;
                    line-height: 26px;
                    padding: 0 10px;
                    font-size: 14px;
                    font-weight: 400;
					padding-top: 2px;
					overflow: hidden;
					text-overflow: ellipsis;
					white-space: nowrap;
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
		padding: 0px;
	}
  }
  .gd{
	  overflow-y: auto;
	  overflow-x: hidden;
	  height: calc(100% - 10px) !important;
  }
  .gd::-webkit-scrollbar {
    display: none;
  }

  ::v-deep .van-swipe-cell__right{
  		  width: 40px;
		  display: flex;
		  justify-content: center;
		  align-items: center;
  }
  .spCell{
	  .x{
		  display: flex;
		  padding:2px 10px;
		  align-items: center;
		  position: relative;
		  top: -2px;
		  height: 30px;
		  .thin{
			  display: flex;
			  align-items: center;
			  .text{
				  font-size: 12px;
				  line-height: 26px;
				  color: rgb(106, 106, 106);
				  font-family: "Harmony_Light";
			  }
		  }
		  .icon_r{
			  position: absolute;
			  right: 12px;
			  top: 8px;
		  }
		  .icon1{
			  margin-right: 5px;
		  }
	  }
  }
}
</style>
