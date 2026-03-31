<template>
	<view class="play_content">
		<view class="top">
		  <van-icon class="return" name="arrow-left" style="font-size: 22px;" @click="left" />
		</view>
		<!-- 音乐播放器 -->
		<view class="music">
			<view class="music_play">
				<music-play :key="musicKey" :item='item' :all='all' @change-music="changeMusic"/>
			</view>
			<view class="answer">
				<!-- 分享按钮 -->
				<view class="fenxiang"  @click="fenxiang()">
					分享
				</view>
				<view class="box">
					<view class="changeBtn" v-if="type == 2 || type == 4 || type == 5">
						    <view class="btn-container">
						      <view class="btn" :class="{'active': showAnswer}" @click="toggleAnswer">五线谱</view>
						      <view class="btn" :class="{'active': !showAnswer}" @click="toggleAnswer">简谱</view>
						      <view class="slide" :style="slideStyle"></view>
						    </view>
					</view>
					<view class="changeBtn" v-if="type != 2  && type != 4 && type != 5">
						    <view class="btn-container">
						      <view class="btn" :class="{'active': showAnswer}" @click="toggleAnswer">显示</view>
						      <view class="btn" :class="{'active': !showAnswer}" @click="toggleAnswer">关闭</view>
						      <view class="slide" :style="slideStyle"></view>
						    </view>
					</view>
					<view class="scroll" v-if="type == 2 && imgArr == false">
						<van-empty v-if="!item.img1 && !showAnswer" description="暂无简谱" />
						<van-image
							style="min-width: 100%;"
						    class="img_bg"
							v-if="!showAnswer"
						    :src="item.img1"
						    :class="{ 'playing': isPlaying }"
							@touchstart="onTouchStart(item.img1)"
							>
					<template v-slot:loading>
					    <van-loading type="spinner" size="20" />
					  </template>
					  </van-image>
					<van-empty v-if="!item.img2 && showAnswer" description="暂无五线谱" />
						<van-image
							style="min-width: 100%;"
						    class="img_bg"
							v-if="showAnswer"
						    :src="item.img2"
							@touchstart="onTouchStart(item.img2)"
						    :class="{ 'playing': isPlaying }"
						>  <template v-slot:loading>
    <van-loading type="spinner" size="20" />
  </template>
</van-image>
					</view>
					<view class="scroll" v-if="type != 2  && imgArr == false" v-show="showAnswer">
						<van-image
							style="min-width: 100%;"
						    class="img_bg"
						    :src="item.img1"
						    :class="{ 'playing': isPlaying }"
							@touchstart="onTouchStart(item.img1)"
						>  <template v-slot:loading>
    <van-loading type="spinner" size="20" />
  </template>
</van-image>
					</view>
					
					<!-- 多图模式 -->
					<view class="scroll" id="scroll11" v-if="imgArr && showAnswer">
						<van-empty v-if="!item.img1" description="暂无五线谱" />
						<view class="tips" v-if="item.img1">{{currentIndex+1}}/{{item.img1.length}}</view>
						<van-swipe v-if="item?.img1" :autoplay="0" lazy-render @change="changeImg($event)">
						  <van-swipe-item v-for="img in item.img1" :key="img">
						    <van-image
								style="min-width: 100%;"
						        :src="img.url || img"
						    	@touchstart="onTouchStart(item.img1)"
						    >  <template v-slot:loading>
    <van-loading type="spinner" size="20" />
  </template>
</van-image>
						  </van-swipe-item>
						</van-swipe>
					</view>
					<view class="scroll" id="scroll12" v-if="type && imgArr && !showAnswer">
						<van-empty v-if="!item.img2" description="暂无简谱" />
						<view class="tips" v-if="item.img2">{{currentIndex+1}}/{{item.img2.length}}</view>
						<van-swipe v-if="item?.img2" :autoplay="0" lazy-render @change="changeImg($event)">
						  <van-swipe-item v-for="img in item.img2" :key="img">
						    <van-image
								style="min-width: 100%;"
						        :src="img.url || img"
						    	@touchstart="onTouchStart(item.img2)"
						    >  <template v-slot:loading>
    <van-loading type="spinner" size="20" />
  </template>
</van-image>
						  </van-swipe-item>
						</van-swipe>
					</view>

				</view>

				
			</view>
		</view>
		<!-- 虚拟钢琴组件 -->
		<view class="piano_box" v-if="item.type!=5 && item.type != 4">
		  <virtual-piano />
		</view>
		
		<!--内容组件 -->
		<view class="text_box3" v-if="item.type==5 || item.type == 4">
		  <view class="text_scroll">
			  <van-empty v-if="!item.longText1" description="暂无简介" />
			  <view v-html="item.longText1"></view>
		  </view>
		</view>
		
		<!-- 图片弹窗 -->
		<van-popup style="margin:0;width: 100%;max-width: 100%;" v-model:show="showImg">
			<van-image
				@touchstart="onTouchEnd()"
			    :src="showImgUrl"
			/>
		</van-popup>
		
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
						您即将分享的课件
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
		
		<view class="rotate" v-if="showRotate">
			<van-icon
			  class="left"
			  :name="'/static/assets/leftRotate.png'"
			  @click="rotateImage(-90)"
			/> 
			<van-icon
			  class="right"
			  :name="'/static/assets/rightRotate.png'"
			  @click="rotateImage(90)"
			/> 
		</view>
	</view>

</template>

<script setup>
import { ref ,onMounted ,computed,nextTick,watch} from 'vue';
import { useRouter} from 'vue-router';
import VirtualPiano from '../common/piano.vue';
import musicPlay from '../common/music.vue';
import {onShow} from '@dcloudio/uni-app';
import {getDetail,classList,sendMsg} from '/api/home.js';
import { showToast , showLoadingToast,showConfirmDialog,showImagePreview} from 'vant';
import { useStore } from 'vuex';

const store = useStore();

watch(() => store.getters.getId, (newId) => {
	getL(newId);
});


const router = useRouter();
const showAnswer = ref(false);	

const item = ref({});

const id = history.state.id;
const type  =  history.state.type;

const musicKey = ref(0);

const showImg = ref(false);
const touchTime = ref(0);
const touchTimeout = ref(null);
const showImgUrl = ref('');

const currentIndex = ref(0);

const detailN = ref({});
const fxItem = ref({});
const classItem = ref([]);
const showL = ref(false);
const showRotate = ref(false);
const vipExpireDate = store.getters.getInfo.vipExpireDate;

//乐理处理
const all = ref([]);
if(type == 3){
	if(history.state.all){
		all.value = JSON.parse(history.state.all);
	}
}

//切换课程
const changeMusic = (component) => {
	getL(component);
};

function fenxiang(){
	classList().then(res =>{
		if(res.code == 0){
			showL.value = true;
			fxItem.value = item.value;
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
		  "param1": "book",
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

const slideStyle = computed(() => ({
  left: showAnswer.value ? '0%' : '50%',
}));

function changeImg(index){
	currentIndex.value = index;
	
	nextTick(()=>{
		document.getElementById('scroll11').scrollTop = 0;
		document.getElementById('scroll22').scrollTop = 0;
	})

}

function onTouchStart(img) {
	const currentTime = new Date().getTime();
	const timeDiff = currentTime - touchTime.value;
	touchTime.value = currentTime;
	if (timeDiff < 300) {
		let arr = [];
		try{
			img.forEach(e =>{
				arr.push(e.url)
			})
		}catch{
			arr = [img]
		}

		showImagePreview({
		images:arr,
		startPosition: currentIndex.value,
		closeable: true,
		onClose() {
			showRotate.value = false;
		}});
		showRotate.value = true;
	}
}

const currentRotate = ref(0);
//旋转图片
function rotateImage(rote){
	const imgs = document.querySelectorAll('.van-image-preview__image img');
	if(rote == 90){
		if(currentRotate.value == 270){
			currentRotate.value = 0;
		}else{
			currentRotate.value += 90;
		}
	}else{
		if(currentRotate.value == 0){
			currentRotate.value = 270;
		}else{
			currentRotate.value -= 90;
		}
	}
	      imgs.forEach((img, index) => {
	        img.className = 'van-image__img'; // 清除之前的旋转类
	        if (currentRotate.value === 90) {
	          img.classList.add('rotate-90');
	        } else if (currentRotate.value === 180) {
	          img.classList.add('rotate-180');
	        } else if (currentRotate.value === 270) {
	          img.classList.add('rotate-270');
	        }
	      });
}

function onTouchEnd() {
	// const currentTime = new Date().getTime();
	// const timeDiff = currentTime - touchTime.value;
	// touchTime.value = currentTime;
	// if (timeDiff < 300) {
	// 	showImg.value = false;
	// }
}

const imgArr = ref(false);

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

//获取课程详情
getL(id);
function getL(id){
	musicKey.value = id;
	getDetail(id).then((res) => {
		
		if(res.data.vip == 1){
			if(vipExpireDate == null){
				showToast("您还未开通会员");
				router.push({name:"personal"})
				return false;
			}else if(!isFutureDate(vipExpireDate)){
				showToast("您的会员已过期，请续费");
				router.push({name:"personal"})
				return false;
			}else{
				
			}
		}
		
	item.value = res.data;
	//图片处理
	try{
		item.value.img1 = JSON.parse(item.value.img1);
		if(item.value.img1?.constructor == Object){
			item.value.img1 = item.value.img1.url;
		}else if(item.value.img1?.constructor == Array){
			try{
				let b = [];
				item.value.img1.forEach(e =>{
					b.push(JSON.parse(e))
				})
				item.value.img1 = b;
			}catch{
				
			}
	
			imgArr.value = true;
	
		}
	}catch{
		
	}
	try{
		item.value.img2 = JSON.parse(item.value.img2);
		if(item.value.img1?.constructor == Object){
			item.value.img2 = item.value.img2.url;
		}else if(item.value.img2?.constructor == Array){
			try{
				let b = [];
				item.value.img2.forEach(e =>{
					b.push(JSON.parse(e))
				})
				item.value.img2 = b;
			}catch{
				
			}
	
			imgArr.value = true;
		}
	}catch{
		
	}
	if(type == 3){
		showAnswer.value = true;
	}else if(type == 2){
		if(item.value.type == 4){
			showAnswer.value = true;
		}else{
			if(item.value.img1){
				showAnswer.value = true;
			}else if(item.value.img2){
				showAnswer.value = false;
			}
		}	
	}
	
	});
}




function left() {
	
		uni.setStorageSync('firstMenu',item.value.firstMenu)
		uni.setStorageSync('secondMenu',item.value.secondMenu)
		// router.go(-1);
		router.back();

}


function toggleAnswer() {
  showAnswer.value = !showAnswer.value;
}

// 收藏,取消收藏
function clickFavorite(){
	let param = {
		  "favorite": true,
		  "targetId": "1784958384170184706",
		  "type": 0
	}
	favoriteSave().then(res =>{
		
	})
}


</script>

<style lang="scss" scoped>

	::v-deep .van-swipe__indicators{
		display: none;
	}
	::v-deep section{
		min-height: 18px;
	}
	.rotate{
		position: fixed;
		bottom: 40px;
		left: 50%;
		width: 130px;
		height: 30px;
		z-index: 9999;
		display: flex;
		align-items: center;
		justify-content: center;
		transform: translateX(-50%);
		.left,.right{
			font-size: 30px;
			margin: 0 15px;
		}
	}

	.fenxiang{
		position: absolute; 
		padding: 5px 0px 4px 0;
		top: 15px;
		left: 15px;
		z-index: 99;
		width: 65px;
		height: 26px;
		background: #E0F8F1;
		color: #404040;
		font-size: 14px;
		display: flex;
		border-radius: 6px;
		align-items: center;
		justify-content: center;
		background-image: url(/static/assets/musicF.png);
		background-repeat: no-repeat;
		background-size: 18px;
		background-position: left 5px center;
		padding-left: 20px;
	}
	.changeBtn{
		display: flex;
		background: #E9E9E9;
		position: absolute;
		right: 10px;
		top: 10px;
		padding: 2px;
		border-radius: 40px;
		.btn-container {
		  position: relative;
		  display: flex;
		  width: 100%;
		  height: 100%;
		}
		.slide {
		  position: absolute;
		  top: 0;
		  bottom: 0;
		  left: 0;
		  width: 50%;
		  background-color: #fff;
		  border-radius: 50px;
		  transition: left 0.15s ease;
		  
		}
		.btn{
			  flex: 1;
			  text-align: center;
			  padding: 10px;
			  cursor: pointer;
			  z-index: 1;
			padding: 5px 10px;
			font-size: 14px;
			min-width: 70px;
			text-align: center;
			color: #999999;
		}
		.btn.active{
			color:#00c9a4;

		}
	}
	.play_content{
		background: #fff;
		border-radius: 9px;
		height: 100%;
		padding: 15px;
		position: relative;
		.top{
			position: absolute;
			top: 22px;
			left: 19px;
			z-index: 10;
			font-size: 16px;
		}
		.return {
		  font-size: 16px;
		}
		.piano_box{
			position: absolute;
			bottom: 0;
			left: 0;
			width: 100%;
			height: calc(100% - 484px);
		}
		.music{
			height: 457px;
		    position: absolute;
		    width: 100%;
			position: relative;
			.music_play{
				width: 264px;
				height: 100%;
				position: absolute;
				top: 0;
				left: 0;
				z-index: 2;
			}
			.answer{
				margin-left: 276px;
				position: relative;
				height: 100%;
				.box{
				    position: absolute;
				    width: 100%;
				    height: 100%;
				    left: 0;
				    border: 1px solid #eee;
				    border-radius: 12px;
				    padding: 20px;
					box-shadow: 0 0 6px #6b6b6b24;
					background: url(/static/assets/logo_b.png) no-repeat;
					background-position: center;
					background-size: 30%;
					.btn_c{
						   float: right;
						    right: 20px;
						    padding: 3px 10px;
						    z-index: 9;
						    border-radius: 22px;
						    font-size: 14px;
							top: 16px;
					}
					.scroll{
						overflow-y: auto;
						/* 隐藏滚动条 */
						scrollbar-width: none; /* Firefox */
						-ms-overflow-style: none; /* IE and Edge */
						width: 100%;
						height: calc(100% - 20px);
						margin-top: 30px;
						background: #fff;
						.tips{
							position: absolute;
							bottom: 16px;
							z-index: 999;
							right: 16px;
							padding: 2px 13px;
							border-radius: 15px;
							background: #f3f3f3;
							font-size: 12px;
							
						}
					}
					.scroll::-webkit-scrollbar {
					    display: none; /* Chrome, Safari, Opera */
					}
				}
			}
		}
		.text_box3{
			    margin-top: 16px;
			    box-shadow: 0 0 6px #6b6b6b24;
			    padding: 16px;
			    border-radius: 12px;
			    height: calc(100% - 470px);
				.text_scroll{
					height: 100%;
					overflow-y: auto;
					scrollbar-width: none; /* Firefox */
					-ms-overflow-style: none; /* IE and Edge */
				}
				.text_scroll::-webkit-scrollbar {
				    display: none; /* Chrome, Safari, Opera */
				}
		}

	}
	
	    /* 响应式设计 */
	    @media (max-width: 1024px) {
	        /* 在宽度小于等于1024px的平板设备上调整样式 */
			.play_content{
				::v-deep .music{
					height: 408px;
					.play{
						.btn{
							.time{
								top: 50px;
							}
						}
					}
				}
				.text_box3{
					    height: calc(100% - 420px);
				}

			}
			::v-deep #waveform{
				margin-top: 15px;
			}

			.play_content .piano_box{
				height: calc(100% - 434px);
			}
	    }
</style>
