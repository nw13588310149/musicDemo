<template>
  <view class="music-companion2">
<!--    <view class="top-nav">
      <view class="title"><van-icon class="right_icon" name="/static/assets/right.png" /></view>
      <view class="nav-items">
        <van-button plain class="btn" type="default" v-for="item in nav" :class="activeTab.id == item.id ? 'active' : ''" @click="selectTab(item)">{{item.name}}</van-button>
      </view>
    </view> -->
    <view class="content-area">
		<view class="gd">
			<!-- banner图 --> 
			<van-image
			  class="banner"
			  src="/static/assets/video_banner.jpg"
			/>
			
			<!-- 主内容 -->
			<view class="conttent_box">
				<view class="li" v-for="item in list">
					<view class="box" @click="go(item)">
							<van-image
								class="img"
								fit="cover"
								position="left"
								:src="item.shortText3"
							> 
							<view class="is_vip">最新</view>
							</van-image>
							<view class="right">
								<view class="title">{{item.title}}</view>
								<view class="bottom">
									<view class="num">{{formatTime(item.createTime)}}</view>
									<view class="num2">{{item.viewCount}}</view>
								</view>
							</view> 
					</view> 
				</view>
			</view>

		</view>


    </view>
  </view>
</template>

<script setup>
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import {postMenulist , getTextbooklist ,homeLatestInfo} from '../../api/home.js' 
const router = useRouter();
const nav = ref([
	'统考','校考'
]);

const activeTab = ref({id:36});
const activeNav = ref();
const list = ref([]);

const getMenulist = async () => {
  try {
    const result = await postMenulist(9);
    nav.value = result.data[0].children;
  } catch (error) {
    console.error('错误信息:', error);
  }
};
getMenulist()

const allList = ref([]);

const videoList = ref([]);

function go(e){
	router.push({name:"consultationDetail",state:{id:e.id}})
}

const getlist = async () => {
  try {
	const data = {
		current:1,
		firstMenu:"",
		province:"甘肃",
		secondMenu:"",
		size:1000,
		type:9
	}
    const result = await getTextbooklist(data);
	
	list.value = result.data;
	
  } catch (error) {
    console.error('错误信息:', error);
  }
};
getlist()
function selectTab(tab) {
    activeTab.value = tab;
	getlist()
}

function formatTime(timeString) {
    const currentTime = new Date();
    const targetTime = new Date(timeString);

    const timeDifference = Math.abs(currentTime - targetTime);
    const minutesDifference = Math.floor(timeDifference / (1000 * 60));
    const hoursDifference = Math.floor(minutesDifference / 60);
    const daysDifference = Math.floor(hoursDifference / 24);
    const monthsDifference = Math.floor(daysDifference / 30);
    const yearsDifference = Math.floor(monthsDifference / 12);

    if (minutesDifference < 1) {
        return '刚刚';
    } else if (minutesDifference < 60) {
        return `${minutesDifference}分钟前`;
    } else if (hoursDifference < 24) {
        return `${hoursDifference}小时前`;
    } else if (daysDifference < 30) {
        return `${daysDifference}天前`;
    } else if (monthsDifference < 12) {
        return `${monthsDifference}月前`;
    } else {
        return timeString.split(' ')[0]; // 返回日期部分
    }
}

</script>


<style scoped>
	::v-deep .img .van-image__img{
		border-radius: 9px 12px 9px 9px;
		overflow: hidden;
	}
.music-companion2 {
	height: 100%;
  .top-nav {
    display: flex;
    justify-content: flex-start;
    align-items: center;
    height: 44px;
	background: #fff;
	border-radius: 9px;
	overflow: hidden;
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
	/* margin-top: 12px; */
    height: 100%;
	background: #fff;
	border-radius: 9px;
	padding: 12px;
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
		margin-top: 9px;
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
				border-radius: 9px;
				overflow: hidden;
				position: relative;
				min-width: 187px;
				box-shadow: 0 0 8px #f3f3f3;
				.img{
					width: 66px;
					height: 66px;
					margin: 6px;
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
						width: 90%;
					    background: none;
						padding-top: 13px;
					    color: #171a20;
					    text-align: left;
						font-size: 14px;
						overflow: hidden;
						text-overflow: ellipsis;
						white-space: nowrap;
					}
					.bottom{
						position: absolute;
						width: 370px;
						bottom: 6px;
						height: 30px;
						font-size: 12px;
						display: flex;
						.num{
							background-color: #f2f2f4;
							font-size: 10px;
							padding: 4px 7px;
							height: 20px;
							border-radius: 20px;
							margin-right: 14px;
						}
						.num2{
							background-color: #f2f2f4;
							font-size: 10px;
							padding: 4px 7px;
							height: 20px;
							border-radius: 20px;
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
                        height: 14px;
                        z-index: 9;
                        font-size: 8px;
                        line-height: 14px;
                        width: 30px;
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
		.li:nth-of-type(n+4){
			.is_vip{
				display: none;
			}
			::v-deep .img .van-image__img{
				border-radius: 9px 9px 9px 9px;
				overflow: hidden;
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
