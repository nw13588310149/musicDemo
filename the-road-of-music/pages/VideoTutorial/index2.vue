<template>
  <view class="video-companion2">
    <view class="top-nav">
      <view class="title"><van-icon class="right_icon" name="arrow" /></view>
      <view class="nav-items">
        <van-button plain class="btn" type="default" v-for="item in nav" :class="activeTab.id == item.id ? 'active' : ''" @click="selectTab(item)">{{item.name}}</van-button>

      </view>
    </view>
    <view class="content-area">
		<view class="gd">
			<!-- banner图 -->
			<van-image
			  class="banner"
			  src="/static/assets/video_banner.jpg"
			/>
			<!-- 副导航 -->
			<view class="nav_min">
				<view class="scroll">
					<view class="item" v-for="item in activeTab.children" :key="item" :class="activeNav.id == item.id ? 'active' : ''">
						{{item.name}}
					</view>
				</view>
			</view>
			
			<!-- 主内容 -->
			<van-grid class="conttent_box" :border="false" :column-num="5" :gutter="6">
			  <van-grid-item class="li" v-for="item in videoList">
				 <view class="box">
					 <view class="play" @click="tap(item)">
						<van-image
						  class="banner"
						  src="/static/assets/video_play.jpg"
						/> 
					 </view>
					 <view class="is_vip">{{item.vip?'免费':"会员"}}</view>
					<van-image
						@click="tap(item)"
						 class="img"
						 fit="cover"
						 position="left"
						 :src="item.coverImg"
					/> 
					<view class="tit">{{item.name}}</view>
					<view class="time">
						<view class="left">{{item.duration}}</view>
						<view class="right">{{item.playCount}}</view>
					</view>
				 </view>
			  </van-grid-item>
			</van-grid>
		</view>


    </view>
	
	<!-- 视频弹出层 -->
	<van-popup
	  v-model:show="showRight"
	  position="right"
	  :style="{ width: '50%', height: '100%' }"
	>
	<view class="video_detail">
		<!-- 视频播放器 -->
		<view class="video_box video_container">
			<video id="myVideo"
			:src="videoDetail.url"
			@error="videoErrorCallback" 
			enable-danmu
			controls></video>
		</view>
		
		<!-- 选择层 -->
		<view class="change_box">
			<view class="xq btn" :class="{'active':activeBtn == 1}" @click="activeBtn = 1">视频详情</view>
			<view class="jp btn" :class="{'active':activeBtn == 2}" @click="activeBtn = 2">查看谱例</view>
		</view>
		
		<view v-if="activeBtn == 1">
			<!-- 发布者 -->
			<view class="user">
				<van-icon class="user_head" name="/static/assets/logo_radio.jpg" />
				<view class="name">音乐之路</view>
			</view>
			<!-- 视频详情 -->
			<view class="videoD">
				<van-collapse v-model="videoD1">
				  <van-collapse-item :title="videoDetail?.name" name="1">
				    {{videoDetail?.param3}}
				  </van-collapse-item>
				</van-collapse>
			</view>
			<!-- 按扭区 -->
			<view class="btn_box">
				<van-icon :name="showAnswer?'/static/assets/video_1.png':'/static/assets/video_1.png'" @click="toggleAnswer()"/>
				<van-icon class="like" v-if="!videoDetail?.isFavorite" name="/static/assets/video_2.png" @click="editVideo()"/>
				<van-icon class="like" v-if="videoDetail?.isFavorite" name="/static/assets/video_2.png" style="color:#00c9a4;" @click="editVideo()"/>
				<van-icon name="/static/assets/video_3.png" />
			</view>
			<!-- 系列视频 -->
			<view class="list_title">相关视频</view>
			<view class="scroll">
				<view class="conttent_box">
					<view class="li" v-for="item in videoDetail?.seriesVideoList">
						<view class="box">
							 <view class="play" @click="tap(item)">
								<van-image
								  class="banner"
								  src="/static/assets/video_play.jpg"
								/> 
							 </view>
							 <view class="is_vip">{{item.vip?'免费':'会员'}}</view>
							<van-image
								 class="img"
								 fit="cover"
								 position="left"
								 :src="item.coverImg"
							/> 
							<view class="time">
								<view class="left">{{item.duration}}</view>
								<view class="right">{{item.playCount}}</view>
							</view>
							<view class="tit">{{item.name}}</view>
						
						</view> 
					</view>
				</view>
				
			</view>
		</view>
		<view v-if="activeBtn == 2">
			<van-empty description="暂无谱例" v-if="!videoDetail.param1"/>
			<view class="img_scroll"  v-if="videoDetail.param1">
				<van-image style="width: 100%;" :src="videoDetail?.param1"/>
			</view>
		</view>
	</view>
	</van-popup>
  </view>
</template>

<script setup>
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import { postMenulist, getVideolist ,getVideoDetail,favoriteSave} from '../../api/home.js'

const router = useRouter();
const nav = ref([]);

const activeBtn = ref(1);

const activeTab = ref({});
const activeNav = ref(0);

const list = ref([]);
const allList = ref([]);

const videoList = ref([]);
const showRight = ref(false);
const videoD1 = ref(['1']);

// 获取菜单列表，并确保“全部”始终在第一个
postMenulist(6).then((res) => {
    const allMenu = { id: null, name: "全部" };
    nav.value = [allMenu, ...res.data]; // 把“全部”放在数组首位
    activeTab.value = allMenu; // 默认选中“全部”
    updateContentArea();
})

// 当选中不同的tab时更新内容区域
function updateContentArea() {
    if (activeTab.value.name === "全部") {
        // 当选中“全部”时，显示所有列表
        allList.value = []; // 重置allList
        nav.value.forEach(tab => {
			if(tab.name == "全部"){
				tab.children = [];
			}
            tab.children && tab.children.forEach(child => allList.value.push(child));
        });
        activeTab.value.children = allList.value;
    } else {
        // 显示选中tab的children
        activeTab.value.children = activeTab.value.children || [];
    }
	
	const parms = ref({
	    current: 1,
	    firstMenu: activeTab.value.id || null,
	    secondMenu: activeNav.value || null,
	    size: 10
	})
	getVideolist(parms.value).then((res) => {
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

getVideolist(parms.value).then((res) => {
    // 处理视频列表数据
	videoList.value = res.data;
})

function selectTab(tab) {
    activeTab.value = tab;
    updateContentArea();
}

const videoDetail = ref();
function tap(value) {
	// console.log(value.id)
    // router.push({ name: 'video', state: { id: value.id } });
	showRight.value = true;
	getVideoDetail(value.id).then((res)=>{
		videoDetail.value = res.data;
	})
}
</script>


<style scoped lang="scss" scoped>
	
.video-companion2 {
	::v-deep .van-overlay{
		background: rgb(0 0 0 / 8%);
	}
	::v-deep .van-popup--right{
		box-shadow: none;
	}
	.video_detail{
		position: relative; 
		height: 100%; 
		overflow: hidden;
		.video_box ,#myVideo{
			width: 100%;
			height: 332px;
		}
			.change_box{
				height: 46px;
				line-height: 46px;
				display: flex;
				border-bottom: 1px solid #f6f7fb;
				.btn{
					width: 50%;
					text-align: center;
					font-size: 15px;
					color: #666;
				}
				.btn.active{
					color: #00c9a4;
					position: relative;
				}
				.btn.active::after{
				    content: "";
				    position: absolute;
				    width: 14px;
				    height: 3px;
				    bottom: 0px;
				    left: 50%;
				    background: #00c9a4;
				    transform: translateX(-7px);
				    border-radius: 3px;
				}
			}
			.user{
				height: 40px;
				padding-top: 10px;
				position: relative;
				.user_head{
					font-size: 30px;
					border-radius: 100%;
					margin-left: 20px;
				}
				.name{
					position: absolute;
				    left: 60px;
				    top: 17px;
				    font-size: 12px;
				    color: #444;
				}
			}
			::v-deep .van-hairline--top-bottom:after, .van-hairline-unset--top-bottom:after{
				display: none !important;
			}
			::v-deep .van-collapse-item__title--expanded:after{
				display: none !important;
			}
			::v-deep .van-cell__title{
				margin-top: 10px;
			    font-size: 16px;
			    font-weight: 500;
			    color: #171a20;
			    letter-spacing: 0px;
			}
			::v-deep .van-collapse-item__content{
				font-size: 12px;
				padding: 0 16px;
			}
			.list_title{
				padding: 10px 15px;
			}
			.btn_box{
				font-size: 22px;
				display: flex;
				margin-top: 20px;
				padding:16px 5px;
				border-bottom: 1px solid #f8f8f8;
				justify-content: center;
				
				.van-icon{
					color: rgba(255, 255, 255, 0.7);
				}
				
				.like{
					margin: 0 30%;
				}
			}
			.scroll{
				        height: calc(100% - 614px);
							 width: 100%;
							 overflow-y: auto;
							 -webkit-overflow-scrolling: touch; /* 兼容iOS滚动 */
							   scrollbar-width: none; /* Firefox */
							   -ms-overflow-style: none; /* IE/Edge */
			}
			.scroll::-webkit-scrollbar {
			  display: none; /* Chrome/Safari/Opera */
			}
			.conttent_box{
				padding: 0 15px;
				.li{
					height: 100%;
					width: 100%;
					flex: 0 0 auto; /* 不要改变项目的大小 */
					margin-right: 10px; /* 设置盒子之间的间距 */
					margin-bottom: 10px;
					.box{
						position: relative;
						.play{
							    position: absolute;
							    width: 30px;
							    height: 30px;
							    z-index: 9;
							    left: 43px;
							    height: 36px;
							    top: 18px;
						}
						.is_vip{
							    position: absolute;
							    left: 82px;
							    top: 0;
							    background: #00c9a4;
							    color: rgba(0, 0, 0, 0.5);
							    height: 24px;
							    z-index: 9;
							    font-size: 10px;
							    line-height: 24px;
							    width: 34px;
							    text-align: center;
							    border-radius: 0 6px 0 8px;
						}
						.img{
							height: 65px;
							width: 116px;
							border-radius: 6px;
							overflow: hidden;
						}
						.tit{
							position: absolute;
							left: 120px;
						    height: 30px;
			                line-height: 26px;
			                padding: 0 5px;
			                font-size: 14px;
			                font-weight: 400;
							color:#222;
							top: 16px;
							font-weight: 400;
						}
						.time{
							    height: 16px;
							    line-height: 16px;
							    padding: 0 5px;
							    font-size: 10px;
							    margin-bottom: 6px;
							    margin-top: 6px;
							    position: absolute;
							    left: 120px;
							    top: 40px;
							.left{
								border-radius: 20px;
								padding: 0 5px;
								float: left;
								padding-left: 20px;
								position: absolute;
								color:#222;
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
								float: left;
								border-radius: 20px;
								padding: 0 5px;
								padding-left: 20px;
								position: relative;
								margin-left: 10px;
								color:#222;
								right: -50px;
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
		}
  .top-nav {
    display: flex;
    justify-content: flex-start;
    align-items: center;
    height: 44px;
	background: #fff;
	border-radius: 9px;
	overflow: hidden;
  }

  .title {
    width: 44px;
    height: 44px;
    line-height: 44px;
	text-align: center;
	font-size: 18px;
	color: #fff;
	letter-spacing: 4px;
    /* Add title styling */
	.right_icon{
			background: #00c9a4;
            border-radius: 50%;
            width: 18px;
            height: 18px;
            font-size: 12px;
            text-align: center;
            line-height: 18px;
            font-weight: 900;
            color: #111;
            padding-left: 4px;
            position: relative;
            top: -2px;
            right: -3px;
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
	margin-top: 12px;
    height: 650px;
	background: #fff;
	border-radius: 9px;
	padding: 15px;
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
		margin: 0 -10px;
		.li{
			.box{
				border: 1px solid #ddd;
				border-radius: 9px;
				overflow: hidden;
				position: relative;
				min-width: 171px;
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
                        color: rgba(0, 0, 0, 0.5);
                        height: 24px;
                        z-index: 9;
                        font-size: 10px;
                        line-height: 24px;
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
	  height: calc(100% - 10px) !important;
  }
  .gd::-webkit-scrollbar {
    display: none;
  }
}
</style>
