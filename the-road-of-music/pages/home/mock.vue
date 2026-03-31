<template>
  <view class="music-companion2">
    <view class="top-nav">
      <view class="title">最新<van-icon class="right_icon" name="arrow" /></view>
      <view class="nav-items">
        <van-button plain class="btn" type="default" v-for="item in nav" :class="activeTab == item ? 'active' : ''" @click="selectTab(item)">{{item}}</van-button>

      </view>
    </view>
    <view class="content-area">
		<view class="gd">
			<!-- banner图 -->
			<van-image
			  class="banner"
			  src="/static/assets/video_banner.jpg"
			/>
			
			<!-- 主内容 -->
			<view class="conttent_box">
				<view class="li" v-for="item in 6">
					<view class="box">
							<van-image
								class="img"
								fit="cover"
								position="left"
								src="/static/assets/video_banner.jpg"
							> 
							<view class="is_vip">最新</view>
							</van-image>
							<view class="right">
								<view class="title">音乐听写系列教程2024</view>
								<view class="bottom">
									<view class="num">2024.04.27</view>
									<view class="num2">13255</view>
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
const router = useRouter();
const nav = ref([
	'统考','校考'
]);

const activeTab = ref('统考');
const activeNav = ref();

const list = ref([]);
const allList = ref([]);

const videoList = ref([]);


function selectTab(tab) {
    activeTab.value = tab;
}

</script>


<style scoped>
.music-companion2 {
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
    width: 88px;
    height: 44px;
    line-height: 44px;
	background: #111;
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
		margin-top: 20px;
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
	  height: calc(100% - 10px) !important;
  }
  .gd::-webkit-scrollbar {
    display: none;
  }
}
</style>
