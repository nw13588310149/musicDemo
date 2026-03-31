<template>
  <view class="app-container">
	<!-- 左侧导航 -->
    <view class="sidebar">
      <view class="box">
		  <view class="title">
			  <van-icon style="color: #00c9a4;" name="/static/assets/nav_bg.png" />
			绝对音感
		  </view>
		  <view class="btn_box">
			  <view class="btn" :class="{ 'active': activeSidebar == 1?true:false }" @click="tap(1)">学习</view>
			  <view class="btn" :class="{ 'active': activeSidebar == 2?true:false }" @click="tap(2)">智能练习</view>
		  </view>
	  </view>
      <view class="box">
		  <view class="title">
			 <van-icon style="color: #00c9a4;" name="/static/assets/nav_bg.png" /> 
			音程识别
		  </view>
		  <view class="btn_box">
			  <view class="btn" :class="{ 'active': activeSidebar == 3?true:false }" @click="tap(3)">学习</view>
			  <view class="btn" :class="{ 'active': activeSidebar == 4?true:false }" @click="tap(4)">智能练习</view>
		  </view>
	  </view>
      <view class="box">
		  <view class="title">
			  <van-icon style="color: #00c9a4;" name="/static/assets/nav_bg.png" />
			和弦识别
		  </view>
		  <view class="btn_box">
			  <view class="btn" :class="{ 'active': activeSidebar == 5?true:false }" @click="tap(5)">学习</view>
			  <view class="btn" :class="{ 'active': activeSidebar == 6?true:false }" @click="tap(6)">智能练习</view>
		  </view>
	  </view>			
    </view>

    <!-- 这里将是主体内容 -->
    <view class="contain">
		<!-- 动态组件 -->
		<component v-if="activeSidebar == 2 || activeSidebar == 4 || activeSidebar == 6" :is="currentComponent"></component>
		<!-- 内容列表 -->
		<view class="list_box" v-if="activeSidebar == 1 || activeSidebar == 3 || activeSidebar == 5">
			<view class="over_y" style="height: 100%;">
				<van-grid :gutter="12" :column-num="3" :border='false'>
				    <van-grid-item v-for="item in allList" :key="value" @click="go(item)">
				      <view class="text">第{{item.number}}课</view>
					  <view class="tip">{{item.param4}}</view>
				      <view class="top-right" style="display: flex;align-items: center;" v-if="item.unlock && item.stars<1">
				      	<van-icon style="color: #00c9a4;" name="/static/assets/zn_right.png" />
				      </view>
					  <view class="top-right" style="display: flex;align-items: center;" v-if="item.stars>0">
					  	<van-icon style="color: #00c9a4;font-size: 17px;margin-left: 6px;" name="/static/assets/stars2.png"  v-for="item in item.stars"/>
					  </view>
					  <view class="top-right" style="display: flex;align-items: center;" v-if="!item.unlock && item.stars<1">
					  	<van-icon style="color: #00c9a4;margin-right: 2px;" name="/static/assets/lock.png" />
					  </view>
				    </van-grid-item>
				</van-grid>
			</view>
		</view>

	</view>
  </view>
</template>

<script setup>
import { ref } from 'vue';
import {useRouter} from 'vue-router';
import ToneExercise from './ToneExercise.vue';
import IntervalExercise from './IntervalExercise.vue';
import ChordExercise from './ChordExercise.vue';
import { smartDictationList } from '../../api/home.js'
import { showToast} from 'vant';
import { useStore } from 'vuex';  // 引入 useStore
const store = useStore();  // 使用 useStore

// 音符转化
const noteMap = {	
    'F3':'f', 
    'F#3':'<sup>#</sup>f', 
    'G3g': 'g', 
    'G#3': 'sup>#</sup>g', 
    'A3': 'a', 
    'A#3': '<sup>b</sup>b', 
    'B3': 'b', 
    'C4': 'c<sup>1</sup>', 
    'C#4': '<sup>#</sup>c<sup>1</sup>', 
    'D4': 'd<sup>1</sup>', 
    'D#4': '<sup>b</sup>e<sup>1</sup>', 
    'E4': 'e<sup>1</sup>', 
    'F4': 'f<sup>1</sup>', 
    'F#4': '<sup>#</sup>f<sup>1</sup>', 
    'G4': 'g<sup>1</sup>', 
    'G#4': '<sup>#</sup>g<sup>1</sup>', 
    'A4': 'a<sup>1</sup>', 
    'A#4': '<sup>b</sup>b<sup>1</sup>', 
    'B4': 'b<sup>1</sup>', 
    'C5': 'c<sup>2</sup>', 
    'C#5': '<sup>#</sup>c<sup>2</sup>', 
    'D5': 'd<sup>2</sup>', 
    'D#5': '<sup>b</sup>e<sup>2</sup>', 
    'E5': 'e<sup>2</sup>', 
    'F5': 'f<sup>2</sup>', 
    'F#5': '<sup>#</sup>f<sup>2</sup>', 
    'G5': 'g<sup>2</sup>', 
    'G#5': '<sup>#</sup>g<sup>2</sup>', 
    'A5': 'a<sup>2</sup>'
};


const router = useRouter();

const activeSidebar = ref(1);
const searchQuery = ref('');



const onSelectNavItem = (index) => {
  activeSidebar.value = index;
};

const allList = ref([]);

getList(0)

function getList(type){
	smartDictationList({type:type}).then(res =>{
		if(res.code == 0){
			allList.value = res.data;
		}else{
			showToast(res.msg);
		}
	})
}

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

function go(e){
	if(e.number != 1){
		if(vipExpireDate == null){
			showToast("您还未开通会员");
			return false;
		}else if(!isFutureDate(vipExpireDate)){
			showToast("您的会员已过期，请续费");
			return false;
		}else{
		}
	}

	if(!e.unlock){
		showToast("该课程还未解锁");
		return false;
	}
	let arr = e.param1.split(",");
	let arr1 = [];
	arr.forEach(e =>{
		arr1.push(noteMap[e])
	})
	
	let item = {
		time:15,
		item:arr1,
		isOpen:true,
		data:e,
		num:20
		}
		sessionStorage.setItem('item',JSON.stringify(item))
		if(activeSidebar.value == 1){
			router.push({name:"answer"})
		}else if(activeSidebar.value == 3){
			router.push({name:"answer2"})
		}else if(activeSidebar.value == 5){
			router.push({name:"answer3"})
		}
}


const currentComponent = ref(null);
const tap = (num) => {
	activeSidebar.value = num;
  if (num === 2) {
    currentComponent.value = ToneExercise;
  } else if (num === 4) {
    currentComponent.value = IntervalExercise;
  } else if (num === 6) {
    currentComponent.value = ChordExercise;
  }else{
	if(num == 1){
		getList(0)
	}else if(num == 3){
		getList(1)
	}else if(num == 5){
		getList(2)
	}
  }
}

if(history.state.id){
	tap(history.state.id)
}
</script>

<style lang="scss" scoped>
.app-container {
  display: flex;
  height: 100%;
	.contain{
		margin-left: 10px;
		width: 100%;
	}
  .sidebar {
		width: 112px;
	    position: relative;
	    border-radius: 9px;
	.box{
		width: 112px;
		height: 146px;
		margin-bottom: 16px;
		background: #fff;
		background-size: cover;
		border-radius: 9px;
		.title{
			    height: 55px;
			    line-height: 55px;
			    width: 100%;
			    text-align: center;
			    font-size: 16px;
			    font-weight: 400;
			    color: #171a20;
				border-bottom: 1px solid #f1f1f1;
				display: flex;
				    align-items: center;
				    justify-content: center;
				.van-icon{
					font-size: 24px;
					margin-right: 6px;
				}
			.icon{
				width: 20px;
				height: 20px;
				border-radius: 50%;
				background: #fff;
				padding: 2px;
				position: relative;
				top: 4px;
				left: -4px;
			}
		}
		.btn_box{
			padding: 13px 17px;
			.btn{
				width: 79px;
				height: 25px;
				background: #F2F3F7;
				color: #171a20;
				text-align: center;
				border-radius: 20px;
				font-size: 14px;
				display: flex;
				justify-content: center;
				align-items: center; 
			}
			.btn.active{
				background: #00c9a4;
				color: #fff;
			}
			.btn:first-child{
				margin-bottom: 13px;
			}
		}
	}

  }
.list_box{
		background: #fff;
		border-radius: 14px;
		padding: 12px 0px;
		height: 100%;
		width: 100%;
		overflow-y: auto;
		-webkit-overflow-scrolling: touch; /* 兼容iOS滚动 */
		  scrollbar-width: none; /* Firefox */
		  -ms-overflow-style: none; /* IE/Edge */
		::v-deep .van-grid-item__content--center{
			height: 50px;
			line-height: 50px;
			position: relative;
			background: #F2F3F7;
			border-radius: 9px;
			overflow: hidden;
			position: relative;
			.top-right{
				position: absolute;
				right: 10px;
			}
			.text{
				position: absolute;
				width: 100%;
				padding-left: 15px;
				font-size: 15px;
				color: #111;
				top: -8px;
				
			}
			.tip{
				font-size: 12px;
				text-align: left;
				position: absolute;
				left: 15px;
				top:10px;
				color: #999;
				width: calc(100% - 55px);
				    overflow: hidden;
				    text-overflow: ellipsis;
				    white-space: nowrap;
			}
		}
		::v-deep .van-grid-item__content--center::before{
			position: absolute;
			left: 0;
			top: 0;
			height: 50px;
			width: 12px;
			content: '';
			background: #00c9a4;
			display: none;
		}
		
	}
	.list_box::-webkit-scrollbar {
	  display: none; /* Chrome/Safari/Opera */
	}
  .content {
    width: calc(100% - 156px);
    margin-left: 16px;
    border-radius: 9px;
	
	.van-grid{
		.van-grid-item{
			height: 40px;
			position: relative;
		}
		.van-grid-item::before{
			content: '';
			position: absolute;
			left: 0;
			top: 0;
			width: 14px;
			height: 40px;
			background: #111;
			border-radius: 9px 0 0 10px;
		}
		::v-deep .van-grid-item__content--center {
	    align-items: center;
	    justify-content: center;
	    background: #f2f3f7;
	    border-radius: 14px;
	    border: none;
		.item-top{
			width: 100%;
			position: relative;
			font-size: 15px;
			letter-spacing: 1px;
			padding: 0 10px;
			color: #656565;
			padding-left: 16px;
			.top-right{
				position: absolute;
				right: 10px;
				top: 2px;
				font-size: 16px;
			}
		}
		}
	}
	
  }
}


</style>
