<template>
  <view class="video-companion2">
    <view class="top-nav">
      <view class="title"><van-icon class="right_icon" name="/static/assets/right.png" /></view>
      <view class="nav-items">
        <van-button plain class="btn" type="default" v-for="item in nav" :class="activeTab.id == item.id ? 'active  animate__animated  animate__bounceIn' : ''" style="position: relative;" @click="selectTab(item)">
				<view class="text">{{item.name}}</view>
		</van-button>
	  </view>
    </view>
    <view class="content-area">
		<scroll-view :scroll-top="scrollTop" scroll-with-animation scroll-y @scrolltolower="loadMore"  class="scrollBox2" >
		<view class="gd">
			<!-- 轮播图 -->
			<van-swipe :autoplay="4000" :duration="300" lazy-render class="swipe" indicator-color='#fff'>
			  <van-swipe-item v-for="image in banner" :key="image" >
			    <img :src="image.img" />
			  </van-swipe-item>
			</van-swipe>
			<!-- banner图 -->
<!-- 			<van-image
				style="border-radius: 9px;overflow: hidden;"
			  class="banner"
			  :src="banner[0]?.img"
			/> -->
			<!-- 副导航 -->
			<view class="nav_min">
				<view class="scroll">
					<view class="item" v-for="item in activeTab.children" :key="item" :class="activeNav == item.id ? 'active' : ''" @click="changeT(item)">
						{{item.name}}
					</view>
				</view>
			</view>
			
			<!-- 主内容 -->
				<van-empty v-if="videoList.length == 0" style="height: auto;" description="暂无数据哦!" image="/static/assets/empty_list.png" :image-size="[260, 260]"/>
				<!-- 视频列表 -->
				<van-grid class="conttent_box" :border="false" :column-num="5" :gutter="6" v-if="videoList.length > 0">
				  <van-grid-item class="li" v-for="item in videoList" :key="item">
				    <!-- 视频项内容 -->
						<view class="box">
								<view class="play" @click="tap(item)">
									<van-image
											class="banner"
											src="/static/assets/video_play.jpg"
									/> 
									</view>
									<view class="is_vip" v-if="isHide">{{item.vip==0?'免费':"会员"}}</view>
									<van-image
											@click="tap(item)"
											class="img"
											fit="cover"
											position="left"
																	 :src="item.coverImg"
																/> 
																<view class="tit">{{item.name}}</view>
																<view class="time">
																	<view class="left thin">{{item.duration}}</view>
																	<view class="right thin">{{item.playCount}}</view>
								</view>
						</view>
				  </van-grid-item>
				</van-grid>
				     
			</view>
		</scroll-view>
    </view>
	
	<!-- 视频弹出层 -->
	<van-popup
	  v-model:show="showRight"
	  position="right"
	  :style="{ width: '50%', height: '100%' }"
	  @close="handlePopupClose"
	>
	<view class="video_detail">
		<!-- 视频播放器 -->
		<view class="video_box">
			<view class="video_container" id="dplayer"></view>
		</view>
		
		<!-- 选择层 -->
		<view class="change_box">
			<view class="xq btn" :class="{'active':activeBtn == 1}" @click="activeBtn = 1">视频详情</view>
			<view class="jp btn" :class="{'active':activeBtn == 2}" @click="activeBtn = 2">查看谱例</view>
		</view>
		
		<view v-if="activeBtn == 1" class="scrollBox">
			<!-- 发布者 -->
			<view class="user">
				<van-image class="user_head" src="/static/assets/logo.jpg" />
			</view>
			<!-- 视频详情 -->
			<view class="videoD">
				<van-collapse v-model="videoD1">
				  <van-collapse-item :title="videoDetail?.name" name="1">
					  <view class="thin">
						{{videoDetail?.param3}}  
					  </view>
					<view class="thin" style="text-align: right;font-size: 9px;color: #999999;padding-top: 6px;">视频来源于网络，如有侵权，请立即联系删除。</view>
				  </van-collapse-item>
				</van-collapse>
			</view>
			<!-- 按扭区 -->
			<view class="btn_box">
				<van-icon :name="'/static/assets/video_1.png'" @click="toggleAnswer()"/>
				<van-icon class="like" v-if="!videoDetail?.isFavorite" name="/static/assets/video_2.png" @click="editVideo(videoDetail)"/>
				<van-icon class="like" v-if="videoDetail?.isFavorite" name="/static/assets/video_yes.png" style="color:#00c9a4;" @click="editVideo(videoDetail)"/>
				<van-icon name="/static/assets/video_3.png" @click="fenxiang(videoDetail)"/>
			</view>
			<!-- 系列视频 -->
			<view class="list_title">相关视频</view>
			<view class="scroll">
				<view class="conttent_box">
					<view class="li" v-for="item in videoDetail?.seriesVideoList" @click="tap(item)">
						<view class="box">
							 <view class="play" >
								<van-image
								  class="banner"
								  src="/static/assets/video_play.jpg"
								/> 
							 </view>
							 <view class="is_vip" v-if="isHide">{{item.vip==0?'免费':'会员'}}</view>
							<van-image
								 class="img"
								 fit="cover"
								 position="left"
								 :src="item.coverImg"
							/> 
							<view class="time">
								<view class="left thin">{{item.duration}}</view>
								<view class="right thin">{{item.playCount}}</view>
							</view>
							<view class="tit">{{item.name}}</view>
						
						</view> 
					</view>
				</view>
				
			</view>
		</view>
		<view v-if="activeBtn == 2" class="img_scroll">
			<van-empty description="暂无谱例" v-if="!videoDetail.param1"/>
			<view  v-if="videoDetail.param1">
				<van-image style="width: 100%;" v-if="videoDetail?.param1.length == 1" :src="videoDetail?.param1" @touchstart="onTouchStart(videoDetail?.param1)"/>
				<van-image style="width: 100%;" v-for="item in videoDetail?.param1" v-if="videoDetail?.param1.length > 1" :src="item" @touchstart="onTouchStart(item)"/>
			</view>
		</view>
	</view>
	</van-popup>
	
	<!-- 图片弹窗 -->
	<van-popup v-model:show="showImg">
		<van-image
			@touchstart="onTouchEnd()"
		    :src="showImgUrl"
		/>
	</van-popup>
	
	<!-- 分享课件 -->
	<van-popup class="fxLeftBox"  v-model:show="showL" position="left" style="width: 50%;height: 100%;" overlay-class="fxLeftOver">
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
					您即将分享的视频: 
					<view class="fxTitleName">{{fxItem.name}}</view>
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
import { ref ,nextTick,watch} from 'vue';
import { useRouter } from 'vue-router';
import {sendMsg,classList, postMenulist, getVideolist ,getVideoDetail,favoriteSave,bannerList} from '../../api/home.js'
import Hls from 'hls.js';
import DPlayer from 'dplayer';
import { showToast } from 'vant';
import { useStore } from 'vuex';
import 'animate.css'
const store = useStore();

const isHide = ref(uni.getStorageSync("checkStatus"));

const router = useRouter();
const nav = ref([]);
const showImg = ref(false);
const showImgUrl = ref('');
const touchTime = ref(0);
const touchTimeout = ref(null);

const activeBtn = ref(1);

const activeTab = ref({});
const activeNav = ref(0);

const list = ref([]);
const allList = ref([]);

const videoList = ref([]);
const showRight = ref(false);
const videoD1 = ref(['1']);

const banner = ref([]);
const scrollTop = ref(0);

const fxItem = ref({});
const classItem = ref([]);
const showL = ref(false);


watch(() => store.getters.getTime, (newId, oldId) => {
      showRight.value = true;
	  tap({ id: store.getters.getId });
});		
function fenxiang(item){
	classList().then(res =>{
		if(res.code == 0){
			showL.value = true;
			fxItem.value = item;
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
		  "param1": "video",
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


function onTouchStart(img) {
	const currentTime = new Date().getTime();
	const timeDiff = currentTime - touchTime.value;
	touchTime.value = currentTime;
	if (timeDiff < 300) {
		showImgUrl.value = img;
		showImg.value = true;
	}
}

function onTouchEnd() {
	const currentTime = new Date().getTime();
	const timeDiff = currentTime - touchTime.value;
	touchTime.value = currentTime;
	if (timeDiff < 300) {
		showImg.value = false;
	}
}

//判断是否收藏跳转

if(history.state.id){
	tap(history.state)
}

bannerList({contentType:1}).then(res =>{
	if(res.code == 0){
		banner.value = res.data;
	}

})

// 获取菜单列表，并确保“全部”始终在第一个
postMenulist(6).then((res) => {
    const allMenu = { id: null, name: "全部" };
    const sortedData = res.data.sort((a, b) => {
        const order = [ "声乐", "歌剧", "键盘", "中国乐器","西洋乐器","音乐会",'大师课'];
        return order.indexOf(a.name.trim()) - order.indexOf(b.name.trim());
    });
	let a = []
	sortedData.forEach(e =>{
		a.push(e)
	})
    nav.value = [allMenu, ...a]; // 把“全部”放在数组首位
    activeTab.value = allMenu; // 默认选中“全部”
    updateContentArea();
});

// 收藏视频
function editVideo(item){

		let param = {
			"favorite": !item.isFavorite,
			"targetId": item.id,
			"type": 6
		}
		
		favoriteSave(param).then(res =>{
			if(res.code == 0){
				videoDetail.value.isFavorite = !videoDetail.value.isFavorite
				if(videoDetail.value.isFavorite){
					showToast({message:'您已成功收藏',teleport:'.btn_box'})
				}else{
					showToast({message:'您已取消收藏',teleport:'.btn_box'})
				}
			}else{
				showToast(res.msg)
			}
		})
}

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
	activeNav.value = ""
	currentPage = 1;
	getList()
	scrollTop.value = -100;
}

let currentPage = 1;
let hasMoreData = true; // 标记是否还有更多数据可加载
// 获取视频列表
function getList(){
	const parms = ref({
	    current: currentPage,
	    firstMenu: activeTab.value.id || null,
	    secondMenu: activeNav.value || null,
	    size: 20
	})
	getVideolist(parms.value).then((res) => {
	    // 处理视频列表数据
		videoList.value = res.data;
		scrollTop.value = 0
		hasMoreData = true;
	})
}

// 加载更多数据
const loadMore = () => {
	if (!hasMoreData) return; // 没有更多数据时停止加载
  currentPage++;
  getVideolist({current: currentPage,
	    firstMenu: activeTab.value.id || null,
	    secondMenu: activeNav.value || null,
	    size: 20}).then((res) => {
    videoList.value = [...videoList.value, ...res.data];
	hasMoreData = res.data.length > 0; // 更新是否还有更多数据可加载的状态
  });
};

const parms = ref({
    current: 1,
    firstMenu: activeTab.value.id || null,
    secondMenu: activeNav.value || null,
    size: 20
})

// 二级目录切换
function changeT(item){
	activeNav.value = item.id;
	currentPage = 1;
	getList()
}

getVideolist(parms.value).then((res) => {
    // 处理视频列表数据
	videoList.value = res.data;
})

function selectTab(tab) {
    activeTab.value = tab;
    updateContentArea();
}

const videoDetail = ref();

function isFutureDate(dateString) {
  // 将输入的日期字符串转换为日期对象
  const inputDate = new Date(dateString);
  
  // 获取当前日期的时间戳，忽略时间部分
  const currentDate = new Date();
  currentDate.setHours(0, 0, 0, 0);
  
  // 比较输入日期和当前日期
  if (inputDate >= currentDate) {
    return true; // 输入日期是未来的时间或是今天
  } else {
    return false; // 输入日期是过去的时间
  }
}
const vipExpireDate = store.getters.getInfo.vipExpireDate;

let dpPlay = "";
function tap(value) {
	if(value.vip == 1){
		if(vipExpireDate == null){
			showToast("您还未开通会员");
			return false;
		}else if(!isFutureDate(vipExpireDate)){
			showToast("您的会员已过期，请续费");
			return false;
		}else{
		}
	}
	showRight.value = true;
	getVideoDetail(value.id).then((res)=>{
		videoDetail.value = res.data;
		let img = "";
		try{
			img = JSON.parse(videoDetail.value.param1)

		}catch{
			img = videoDetail.value.param1;
		}
		if(img[0] == ''){
			img = ""
		}

		videoDetail.value.param1 = img
		dpPlay = new DPlayer({
		  container: document.getElementById('dplayer'),
		  video: {
		    url: videoDetail.value.url,
		    pic: videoDetail.value.coverImg
		  },
		  autoplay: false // 根据需要设定是否自动播放
		});
	})
}

// 弹窗关闭
function handlePopupClose() {
  // 弹窗关闭时执行的操作
  // 可以在这里添加一些清理操作，如暂停视频播放或注销播放器
    if (dpPlay) {
      dpPlay.pause();
    }
}

</script>


<style scoped lang="scss">
	::v-deep .uni-scroll-view{
		overflow-y: auto;
		scrollbar-width: none; /* Firefox */
		-ms-overflow-style: none; /* IE and Edge */
	}
	::v-deep .van-swipe-item{
		height: auto;
	}
	::v-deep .van-button__content{
		padding-top: 1px;
	}
	.swipe{
		border-radius: 9px;
		position: relative;
		img{
			width: 100%;
			height: 100%;
		}
		::v-deep .van-swipe__indicators{
			position: absolute;
			right: 15px;
			bottom: 15px;
			transform: none;
			left: auto;
			.van-swipe__indicator--active{
				width: 14px;
				border-radius: 14px;
			}
		}
	}
	::v-deep .dplayer-controller .dplayer-icons .dplayer-full:hover .dplayer-full-in-icon{
		display: none;
	}
	::v-deep .dplayer-played{
		background: #00c9a4 !important;
	}
	::v-deep .dplayer-thumb{
		background: #00c9a4 !important;
	}
	
.video-companion2 {
	height: 100%;
	::v-deep .van-overlay{
		background: rgb(0 0 0 / 8%);
	}
	::v-deep .van-popup--right{
		box-shadow: none;
	}
	.scrollBox2{
		height: 100%;
		overflow-y: auto;
		overflow-x: hidden;
		-webkit-overflow-scrolling: touch; /* 兼容iOS滚动 */
		scrollbar-width: none; /* Firefox */
		-ms-overflow-style: none; /* IE/Edge */
	}
	.scrollBox2::-webkit-scrollbar {
	  display: none;
	}
	
	.video_detail{
		position: relative; 
		height: 100%; 
			#dplayer{
				width: 100%;
				height: 332px;
			}

			.scrollBox,.img_scroll{
				
				height: calc(100% - 378px);
				overflow-y: auto;
				-webkit-overflow-scrolling: touch; /* 兼容iOS滚动 */
				  scrollbar-width: none; /* Firefox */
				  -ms-overflow-style: none; /* IE/Edge */
			}
			.scrollBox::-webkit-scrollbar ,.img_scroll::-webkit-scrollbar{
			  display: none; /* Chrome/Safari/Opera */
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
					width: 90px;
					margin-left: 16px;
				}
				.name{
					position: absolute;
				    left: 56px;
				    top: 17px;
				    font-size: 13px;
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
				font-size: 16px;
				position: relative;
				padding-left: 24px;
				padding-bottom: 15px;
			}
			.list_title::before{
				content: "";
				    position: absolute;
				    left: 16px;
				    top: 14px;
				    width: 3px;
				    height: 12px;
				    border-radius: 4px;
				    background: #00c9a4;
				
			}
			.btn_box{
				font-size: 26px;
				display: flex;
				margin-top: 20px;
				padding:16px 5px;
				border-bottom: 1px solid #f8f8f8;
				justify-content: center;
				position: relative;
				.van-icon{
					color: rgba(255, 255, 255, 0.7);
				}
				
				.like{
					margin: 0 30%;
					position: relative;

				}
				::v-deep .van-toast{
					position: absolute;
					top: -16px;
					left: 67px;
					white-space: nowrap;
					overflow: visible;
					background: #23BF95 !important;
				}
				::v-deep .van-toast::before{
					position: absolute;
					bottom:-7px;
					left: 15px;
					content: '';
					border-radius: 12px;
					  border-left: 10px solid transparent; /* 左边框透明 */
					  border-right: 10px solid transparent; /* 右边框透明 */
					  border-top: 12px solid #23BF95; /* 上边框实心 */
				}
			}
			// .scroll{
			// 	        height: calc(100% - 614px);
			// 				 width: 100%;
			// 				 overflow-y: auto;
			// 				 -webkit-overflow-scrolling: touch; /* 兼容iOS滚动 */
			// 				   scrollbar-width: none; /* Firefox */
			// 				   -ms-overflow-style: none; /* IE/Edge */
			// }
			// .scroll::-webkit-scrollbar {
			//   display: none; /* Chrome/Safari/Opera */
			// }
			.conttent_box{
				padding: 0 15px;
				.li{
					border-radius: 9px;
					height: 100%;
					width: 100%;
					flex: 0 0 auto; /* 不要改变项目的大小 */
					margin-right: 10px; /* 设置盒子之间的间距 */
					margin-bottom: 10px;
					box-shadow: 0 0 8px 0 #eeeeee;
					padding: 5px;
					.box{
						position: relative;
						height: 70px;
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
							    left: 86px;
							    top: 0;
							    background: #fbe5bd;padding-left:2px !important;
							    color: #785c38;
							    height: 14px;
							    z-index: 9;
							    font-size: 9px;
							    line-height: 14px;
							    width: 30px;
							    text-align: center;
							    border-radius: 0 6px 0 8px;
						}
						.img{
							height: 70px;
							width: 116px;
							border-radius: 6px 8px 6px 6px;
							overflow: hidden;
						}
						.tit{
							position: absolute;
							left: 120px;
						    height: 30px;
			                line-height: 26px;
			                padding: 0 5px;
			                font-size: 14px;
							color:#222;
							top: 7px;
							font-weight: 400;
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
							    margin-top: 6px;
							    position: absolute;
							    left: 118px;
							    top: 35px;
							.left{
								border-radius: 20px;
								padding: 0 5px;
								float: left;
								padding-left: 20px;
								position: absolute;
								color:#222;
								height: 16px;
								display: flex;
								align-items: center;
								background: #f2f2f4;
								padding-top: 2px;
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
								height: 16px;
								display: flex;
								align-items: center;
								background: #f2f2f4;
								padding-top: 2px;
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
	  margin-left: 4.5px;
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
	padding-left: 0px;
    /* Add button styling if necessary */
	.btn{
		height: 28px;
		border: none;
		background: #f6f7fb;
		border-radius: 4px;
		margin: 0 5px;
		font-size: 16px;
		color:#fff;
		// transition: background-color 0.3s; /* 背景色过渡 */
		.text{
			z-index: 99;
			position: relative;
		}
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
	.active ::v-deep .text{
		color: #fff;
	}
	
  }

  .content-area {
	margin-top: 12px;
    height: calc(100% - 55px);
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
		height: 27px;
		margin: 15px 0 9px 0;
		.scroll{
			width: 100%;
			overflow-x: auto;
			-webkit-overflow-scrolling: touch; /* 兼容iOS滚动 */
			white-space: nowrap; /* 禁止换行 */ 
			scrollbar-width: none; /* Firefox */
			-ms-overflow-style: none; /* IE/Edge */
			display: flex;
		}
		.scroll::-webkit-scrollbar {
		  display: none; /* Chrome/Safari/Opera */
		}
		.item{
				display: flex;
				align-items: center;
                padding: 8px 10px 6px 10px;
                background-color: #f6f7fb;
                text-align: center;
                margin-right: 8px;
                border-radius: 4px;
                font-size: 14px;
                font-weight: 500;
		}
		.item.active{
			background: #111;
			color: #fff;
		}
	}
	.conttent_box{
		padding-left: 6px!important;
		margin: 0 -10px;
		.li{
			min-width: 0;
			.box{
				box-shadow: 0 0 8px 0 #eeeeee;
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
                        background: #fbe5bd;padding-left:2px !important;
                        color: #785c38;
                        height: 16px;
                        z-index: 9;
                        font-size: 10px;
                        line-height: 16px;
                        width: 34px;
                        text-align: center;
                        border-radius: 0 0 0 8px;
				}
				.img{
					height: 94px;
					width: 100%;
					border-radius: 0 11px 0 0;
					overflow: hidden;
				}
				.tit{
				    height: 30px;
                    line-height: 26px;
                    padding: 0 5px;
                    font-size: 14px;
                    font-weight: 400;
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
						    height: 16px;
						    display: flex;
							align-items: center;
						    color: #3a3a3a;
							padding-top: 2px;
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
						display: flex;
						align-items: center;
						color: #3a3a3a;
						padding-top: 2px;
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
	  height: auto !important;
  }
  .gd::-webkit-scrollbar {
    display: none;
  }
}
</style>
