<template>
  <view class="right">
	  <!-- 轮播图 -->
	  <view class="schoolName">
		<view class="schoolNameContent">
			{{schoolInfo?.name}}
		</view>
	  </view>
	  <!-- 通知区 -->
	  <view style="position: relative;">
		  <view class="btn_r">
		  		<!-- 学习进度 -->
		  		<view class="notice1 jd">
		  		  <view class="top">
		  		    <text class="title"><view class="i"></view>学习进度</text>
		  		  </view>
		  		  <view class="bottom bottom2">
		  		    <view class="li_jd" v-for="item in jdList">
		  				<view class="sj">{{item.text}}</view>
		  				<van-progress class="jdt" :percentage="item.num" :show-pivot='false' :color='item.color' :style="{'background':item.bg}"/>
		  		        <view class="bfh">{{item.num}}%</view>
		  		    </view>
		  		  </view>
		  		</view>
		  </view>
		  <!-- 乐器区 -->
		  <view class="box2">
		    <view class="left">
		      <view class="li" @click="gosY">
		        <image src="/static/assets/homeIcon9.png" class="icon"></image>
		        <text class="text">声乐</text>
		      </view>
		  	<view class="li" @click="goQY">
		  	  <image style="width: 98px;height: 95px;" src="/static/assets/homeIcon10.png" class="icon"></image>
		  	  <text class="text">器乐</text>
		  	</view>
		    </view>
		  </view>
	  </view>
	  <!-- 按扭区 -->
	  <view style="display: flex;">
		  <view class="btn_box">
		    <view class="btn_l">
		      <!-- 按钮循环事件-->
		      <view class="btn" v-for="item in btnArray" @click="onButtonClick(item)">
		        <text class="text">{{item.name}}</text>
		  	  <van-image
		  	    class="icon"
		  	    :src="item.icon"
		  	  />
		      </view>
		    </view>
		    
		  </view>
	  </view>
  
  <!-- 添加咨询（最新）部分 -->
  <view class="title_new" style="margin-top: 10px;">
    <view class="latest" style="height: 23px;"><text style="position: absolute;z-index: 9;">校园资讯</text></view>
    <view class="more" @click="goMore">更多<van-icon style="font-weight: 400;" name="arrow" /></view>
  </view>
  <view class="ul">
    <!-- 动态生成列表项 -->
    <view class="ul_li" v-for="(item, index) in homeList" :key="index" @click="go(item)">
      <text class="zx">最新</text>
      <text class="p1">{{ item.shortText1 || '最新资讯'}}</text>
      <text class="p2 thin">{{ item.title }}</text>
      <view class="p3">
        <!-- 动态生成标签 -->
        <view class="bq thin" v-for="(tag, index) in item.tags" :key="index">
          {{ tag }}
        </view>
      </view>
      <view class="p4">
        <view class="time_y thin">{{ formatTime(item.createTime) }}</view>
        <view class="time_s thin">
			<van-icon
			  class="icon"
			  style="font-size: 12px;"
			  name="/static/assets/views.png"
			/>
			{{ item.viewCount }}
		</view>
      </view>
    </view>
  </view>
  
  <!-- 即将上线 -->
  <van-dialog class="qrcode_box" v-model:show="showQrcode" :showConfirmButton='false'>
  	<view style="border-radius:20px;overflow: hidden;">
		<van-image
		  src="/static/assets/sx.jpg"
		/>

  	</view>
  	<view class="close">
  		<van-icon @click="showQrcode = false" name="/static/assets/bg_close.jpg" />
  	</view>
  </van-dialog>
 </view>
</template>

<script setup>
import { ref , onMounted , watch,computed,onUnmounted} from 'vue';
import { useRouter } from 'vue-router';
import { onShow } from '@dcloudio/uni-app';
import { bannerList ,homeLatestInfo , schoolHomeLearningProgress,getMyInfo,nextSchoolCourse,courseList,classList,updateSchool} from '../../api/home.js'
import { useStore } from 'vuex';  // 引入 useStore
import {showToast} from 'vant';
import dayjs from 'dayjs';
// 使用插件来处理 ISO 8601 标准格式
import customParseFormat from 'dayjs/plugin/customParseFormat';
import utc from 'dayjs/plugin/utc';
dayjs.extend(customParseFormat);
dayjs.extend(utc);
const router = useRouter();
const store = useStore();  // 使用 useStore
const myInfo = ref({});

const schoolInfo = ref();

// 页面加载时开始动画
onMounted(() => {
	getInfo();
	
	  // 每分钟更新当前时间
	  const intervalId = setInterval(() => {
	    now.value = new Date();
	  }, 60000);
	  
	    // 在组件卸载前清除定时器
	    onUnmounted(() => {
	      clearInterval(intervalId);
	    });
		
	//获取学校信息
	updateSchool().then( res =>{
		if(res.code == 0){
			schoolInfo.value = res.data;
			console.log(schoolInfo.value)
		}
	})

});


const date = ref(formatDateToCustom(new Date()));

//时间函数
function formatDateToCustom(date) {
  return dayjs(date).format('YYYY MM/DD');
}


//时间函数-获取周几
function getDayOfWeek(dateString, dayIndex) {
  const date = dayjs(dateString, 'YYYY-MM-DD');
  const startDay = (date.day() + 6) % 7; // 将星期天的值调整到最后，星期一作为一周的开始

  const targetDate = date.add(dayIndex - startDay, 'day');
  return targetDate.format('YYYY-MM-DD');
}

// 获取课表
const kbData = ref({});
function getKb(id,type){
	
	const param = {
		  "beginDate": getDayOfWeek(date.value,0),
		  "classId":type==1?id:"",
		  "endDate": getDayOfWeek(date.value,6),
		  "teacherId":type ==0?id:""
	}
	courseList(param).then(res => {
		if(res.code == 0){
			const weekDays = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"];
			const startDate = dayjs(date.value,'YYYY-MM-DD');
			
			if (!startDate.isValid()) {
			  return [];
			}
			
			const startDay = (startDate.day() + 6) % 7;
			const weekData = [];
			for (let i = 0; i < 7; i++) {
			  const dayDate = startDate.add(i - startDay, 'day');
			  const formattedDate = dayDate.format('YYYY-MM-DD'); // 格式化日期为 YYYY-MM-DD
			
			  weekData.push({
			    name: weekDays[i],
			    value: formattedDate,
			    now: dayDate.isSame(startDate, 'day') // 使用 isSame 方法比较日期
			  });
			}
			let a = [];
			weekData.forEach(e=>{
				if(res.data[e.value]){
					a.push(res.data[e.value].length)
				}else{
					a.push(0);
				}
			})
			kbData.value = a;
		}

	});
}



const now = ref(new Date());
const syDate = computed(() => {
  // 假设 nextKC.date 和 nextKC.timeBegin 可以直接组合成一个有效的日期时间字符串
  const targetDateTime = new Date(`${nextKC.value.date}T${nextKC.value.timeBegin}`);
  
  // 计算两个时间的差值，结果单位为毫秒
  const diff = targetDateTime - now.value;

  // 将毫秒转换为分钟
  const minutesDiff = Math.floor(diff / 1000 / 60);
  
  if (minutesDiff > 1440) {
    const daysDiff = Math.floor(minutesDiff / 1440);
    const remainingHours = Math.floor((minutesDiff % 1440) / 60);
    return `${daysDiff}天`;
  } else if (minutesDiff > 60) {
    return `${Math.floor(minutesDiff / 60)}小时`;
  } else {
    return `${minutesDiff}分钟`;
  }
});



//获取日期
const dataNav = computed(() => {
  const weekDays = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"];
  const startDate = dayjs(date.value,'YYYY-MM-DD');
  
  if (!startDate.isValid()) {
    return [];
  }

  const startDay = (startDate.day() + 6) % 7;
  const weekData = [];
  for (let i = 0; i < 7; i++) {
    const dayDate = startDate.add(i - startDay, 'day');
    const month = dayDate.month() + 1;
    const day = dayDate.date();
	
    weekData.push({
      name: weekDays[i],
      value: `${day}`,
	  now:dayDate.date() == startDate.date()
    });
  }

  return weekData;
});

function getInfo(){
	getMyInfo().then(res =>{
		if(res.code == 0){
			myInfo.value = res.data.user;
			store.dispatch('updateInfo', res.data.user);  // 更新 Vuex 中的 info 状态
			
			if(res.data.user.role == "teacher"){
				getKb(res.data.user.id,0)
			}else{
				//获取我的班级
					classList().then(res =>{
						if(res.code == 0){
							if(res.data.length > 0){
								getKb(res.data[0].id,1)
							}
						}
					})
			}
			
		}else{
			showToast(res.msg);
		}
	})
}

const token = uni.getStorageSync('token');
if(!token){
	router.push({name:"login"})
}
const images = ref([]);
bannerList({"contentType":0}).then(res =>{

	if(res.code == 0){
		images.value = res.data;
	}
})
const homeList = ref([]);
homeLatestInfo({"province": "甘肃"}).then(res =>{
	if(res.code == 0){
		res.data.forEach(e =>{
			try{
				e.tags = e.shortText2.split("，")
			}catch{
				
			}
		})
		homeList.value = res.data;
		
	}
})
schoolHomeLearningProgress({"province": "甘肃"}).then(res =>{

	if(res.code == 0){
		jdList.value = [
	{text:"听写",num:0,targetNum:res.data.tx,color:"rgba(253 131 162 / 70%)",bg:"#F7EBFA"},
	{text:"视唱",num:0,targetNum:res.data.sc,color:"rgba(165, 146, 244 ,0.7)",bg:"#F1EEFF"},
	{text:"乐理",num:0,targetNum:res.data.yl,color:"rgba(44, 205, 161,0.7)",bg:"#E8F7F3"},
]

	// 为每个进度条创建动画
	jdList.value.forEach((item, index) => {
	  const interval = setInterval(() => {
	    // 逐步增加 num 值
	    if (item.num < item.targetNum) {
	      item.num++;
	    } else {
	      clearInterval(interval); // 达到目标值后清除计时器
	    }
	  }, 6); // 动画速度，调整为合适的毫秒值
	});
	}
})

// Ref for image sources
function go(e){
	router.push({name:"consultationDetail",state:{id:e.id}})
}

function goQY(){
	 uni.removeStorageSync('firstMenu');
	 uni.removeStorageSync('secondMenu');
	 router.push({ name: 'instrumental' ,state:{"school":schoolInfo.value.id}})
}
function gosY(){
	 uni.removeStorageSync('firstMenu');
	 uni.removeStorageSync('secondMenu');
	 router.push({ name: 'voice' ,state:{"school":schoolInfo.value.id}})
}

function goKb(){
	router.push({ name: 'smart-campus',state:{name:'我的课表'}})
}
// 按扭组
const btnArray = ref([])
	btnArray.value = [
	{name:"听写",icon:"/static/assets/homeIcon3.png",url:'Dictation',init:8},
	{name:"视唱",icon:"/static/assets/homeIcon1.png",url:'sightSinging',init:1},
	{name:"乐理",icon:"/static/assets/homeIcon2.png",url:'musicTheory',init:5},
	{name:"答题",icon:"/static/assets/homeIcon4.png",url:'answerQuestions'},
	{name:"视频",icon:"/static/assets/homeIcon5.png",url:'videoCenter'}]



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

zxkc();
const nextKC = ref({});
//获取最新课程
function zxkc(){
	nextSchoolCourse().then(res =>{
		if(res.code == 0){
			nextKC.value = res.data[0];
		}
	})
}

//更多
function goMore(){
	router.push({name:'consultation'})
}
// 进度表
const jdList = ref([])
// 通知列表数据
const items = ref([
  {
    label: '最新',
    title: '旋律',
    subtitle: '无升降号各调性旋律练习',
    tags: ['c 自认大调', 'a 大调', 'b 小调'],
    date: '01.18',
    time: '半月前 14:38'
  },
  {
    label: '最新',
    title: '旋律',
    subtitle: '无升降号各调性旋律练习',
    tags: ['c 自认大调', 'a 大调', 'b 小调'],
    date: '01.18',
    time: '半月前 14:38'
  },
  {
    label: '最新',
    title: '旋律',
    subtitle: '无升降号各调性旋律练习',
    tags: ['c 自认大调', 'a 大调', 'b 小调'],
    date: '01.18',
    time: '半月前 14:38'
  },
  {
    label: '最新',
    title: '旋律',
    subtitle: '无升降号各调性旋律练习',
    tags: ['c 自认大调', 'a 大调', 'b 小调'],
    date: '01.18',
    time: '半月前 14:38'
  },

]);


// Function to handle button click
function onButtonClick(item) {
	if(item.name == "商城" || item.name == "模考"){
		showQrcode.value = true;
	}else if(item.name == "视频"){
		// 处理视频中心按钮点击
		router.push({ name: item.url, state:{school:schoolInfo.value.id} });
	}else{
		uni.setStorageSync('firstMenu',item.init)
		router.push({ name: item.url ,state:{school:schoolInfo.value.id}});
	}
}

const showQrcode = ref(false);
</script>

<style scoped lang="scss">
	::v-deep .van-swipe-item{
		height: auto;
	}
	::v-deep .van-overlay{
		background: rgba(0,0,0,.8);
	}
	.schoolName{
		height: 244px;
		background: url(/static/assets/school_bg.png) no-repeat;
		background-size: 100% 100%;
		border-radius: 9px;
		position: relative;
		overflow: hidden;
	}
	.schoolName::before {
	    content: '';
	    position: absolute;
	    top: 0;
	    left: 0;
	    right: 0;
	    bottom: 0;
	    background: inherit; /* 继承背景 */
	    filter: blur(10px); /* 高斯模糊 */
	    z-index: -1; /* 确保模糊背景在文字后面 */
	}
	.schoolNameContent {
	    position: relative;
		height: 100%;
	    z-index: 1;
	    backdrop-filter: blur(10px); /* 毛玻璃效果 */
	    padding: 10px;
	    border-radius: 9px;
	    background: rgba(255, 255, 255, 0.2); /* 半透明背景增加毛玻璃感 */
		display: flex;
		justify-content: center;
		align-items: center;
		font-size: 50px;
		font-family: 'douyu';
		letter-spacing: 6px;
		color: #fff;
	}
	.right{
		position: relative;
		height: 100%;
		overflow-y: auto;
		-webkit-overflow-scrolling: touch; /* 兼容iOS滚动 */
		scrollbar-width: none; /* Firefox */
		-ms-overflow-style: none; /* IE/Edge */
	}
	.right::-webkit-scrollbar{
	  display: none; /* Chrome/Safari/Opera */
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
.btn_box{
		margin-top: 16px;
        width: 100%;
        position: relative;
	.btn_l {
	  width: 100%;
	  .btn {
	    background: #fff;
	    border-radius: 9px;
	    width: 19%;
	    height: 100px;
	    margin-right: 1.25%;
	    margin-bottom: 16px; /* 添加下边距 */
		float: left;
		font-size: 24px;
		display: flex;
		justify-content: center;
		align-items: center;
	    .text {
			height: 24px;
	      left: 22px;
	      font-size: 18px;
	      letter-spacing: 5px;
	      top: 21px;
	      font-weight: 400;
		  color: #171a20;
	    }
	    .icon {
		  margin-left: 8%;
	      width: 34px;
	      height: 34px;
	    }
	  }
	  .btn:nth-child(5n){
		  margin-right: 0;
	  }
	}

}
.btn_r{
	margin-top: 16px;
    width: 38.8%;
    height: 130px;
    background: #fff;
    border-radius: 9px;
	overflow: hidden;
	
	.notice1{
		height: 60px;
		border-bottom: 1px solid #f2f3f7;
		position: relative;
	}
	.kecheng{
		height: 188px;
		border-bottom: none;
		.scroll_x{
			margin: 7px;
			overflow-x: auto;
			-webkit-overflow-scrolling: touch; /* 兼容iOS滚动 */
			scrollbar-width: none; /* Firefox */
			-ms-overflow-style: none; /* IE/Edge */
		}
		.scroll_x::-webkit-scrollbar{
		  display: none; /* Chrome/Safari/Opera */
		}
		.riqi{
			display: flex;
			width: 363px;
			.head_li{
				flex-shrink: 0;
				display: flex;
				justify-content: center;
				width: 53px;
				height: 73px;
				flex-direction: column;
				align-items: center;
				margin-right: 9px;
				box-shadow: 0 0 4px 0 #f3f3f3;
				font-size: 10px;
				border-radius: 4px;
				.week{
					margin-bottom: 7px;
					color: #333333;
					font-size: 12px;
				}
				.time{
					font-size: 15px;
					margin-bottom: 10px;
					color: #000;
				}
				.all{
					width: 43px;
					height: 17px;
					display: flex;
					align-items: center;
					justify-content: center;
					background: #F7F7F7;
					font-size: 10px;
					color: #979797;
					border-radius: 4px;
					padding-top: 1px;
				}
			}
			.head_li:first-child{
				position: relative;
				overflow: hidden;
			}
			.head_li:first-child::before{
				content: "";
				position: absolute;
				background: #00c9a4;
				width: 30px;
				height: 30px;
				left: -18px;
				top: -18px;
				transform: rotate(45deg);
				
			}
			.active{
				background: #00c9a4;
				.week,.time{
					color: #fff;	
				}
				.all{
					background: #fff;
				}
			}
		}
		.tongzhi{
			width: 278px;
			height: 84px;
			border-radius: 4px;
			margin-top: -1px;
			padding: 0 5px;
			margin-left: 7px;
			.title{
				height: 29px;
				border-bottom: 1px solid #F5F5F5;
				font-size: 14px;
				position: relative;
				padding-left: 8px;
				padding: 5.5px 8px;
			}
			.title::before{
				content: "";
				position: absolute;
				width: 3px;
				height: 12px;
				background: #00c9a4;
				border-radius: 2px;
				top: 7.5px;
				left: 0;
			}
			.tzBottom{
				padding: 10px 0px 8px 0px;
				.one{
					display: flex;
					.date{
						width: 48px;
						height: 19px;
						font-size: 10px;
						color: #000;
						background: #FCF3EE;
						border-radius: 2px;
						display: flex;
						justify-content: center;
						align-items: center;
						margin-right: 8px;
						font-size: 12px;
						border-radius: 30px;
					}
					.time{
						width: 90px;
						height: 19px;
						display: flex;
						justify-content: center;
						align-items: center;
						font-size: 10px;
						color: #000;
						font-size: 12px;
						background: #FCF3EE;
						border-radius: 30px;
					}
					.kc{
						margin-left: auto;
						padding: 0 10px;
						height: 24px;
						background: #F1EEFF;
						color: #6242DF;
						border-radius: 26px;
						font-size: 12px;
						display: flex;
						justify-content: center;
						align-items: center;
					}
				}
				.two{
					display: flex;
					margin-top: 6px;
					height: 18px;
					align-items: center;
					.head{
						border-radius: 50%;
						overflow: hidden;
						margin-right: 4px;
					}
					.text{
						font-size: 12px;
						color: #999999;
					}
					.time{
						font-size: 12px;
						color: #999999;
						margin-left: auto;
					}
				}
			}
		}
	}
	.notice2{
		margin-top: 16px;
		border-bottom: 1px solid #f2f3f7 !important;
	}
	.notice1 .top{
		.title{
		color: #3a3a3a;
		border-bottom: 1px solid #F5F5F5;
		font-weight: 400;
		font-size: 14px;
		display: block;
		padding: 15px 0;
			.i{
			display: inline-block;
			width: 3px;
			height: 12px;
			background: #00c9a4;
			border-radius: 9px;
			margin-left: 0px;
			position: relative;
			top: 1px;
			margin-right: 6px;
		    }
		} 
		.time_y{
		position: absolute;
		right: 60px;
		background: #fcf3ef;
		padding: 2px 10px;
		border-radius: 4px;
		font-size: 12px;
		top: 0;
		}
		.time_s{
		position: absolute;
		right: 0px;
		top: 0px;
		background: #fcf3ef;
		padding: 2px 10px;
		border-radius: 4px;
		font-size: 12px;
		}
	}
	.notice1 .bottom{
	    position: absolute;
	    top: 64px;
	    left: 14px;
	    font-size: 14px;
	    width: 100%;
		.name{
		    font-weight: 400;
		    background: #f2f2ff;
		    width: 48px;
		    padding: 0 2px;
		    border-radius: 4px;
			position: absolute;
			font-size: 12px;
			right: -11px;
			text-align: center;
			padding: 1px 0;
			color: #888;
		}
		.ls{
		    position: absolute;
		    right: 14px;
		    font-weight: 400;
		    top: 0;
		    left: -2px;
		    font-weight: 400;
		    color: #969799;
		    font-size: 13px;
			}
	}
}
.box2{
    position: absolute;
	width: 60%;
	top: 0;
	right: 0;
	.left{
	    width: 100%;
		display: flex;
		.li{
			position: relative;
			width: 49%;
			height: 130px;
			background: #fff;
			border-radius: 9px;
			margin-right: 2%;
			.icon{
				width: 96px;
				height:99px;
				position: absolute;
				right: 0;
				bottom: 0;
			}
			.text{
				font-weight: 400;
				font-size: 22px;
				letter-spacing: 6px;
				position: absolute;
				left: 60px;
				top: 52px;
				color:#333333;
			}
		}
		.li:last-child{
			margin-right: 0;
		}
	}
}
.notice1.jd{
	background: #fff;
	margin-top: -4px;
	border-radius: 6px;
	height: 100px;
	border-bottom: none;
	padding: 0 12px;
	.title{
		padding-bottom: 6px;
		margin-bottom: 4px;
	}
	.li_jd{
	    border-radius: 4px;
	    font-size: 7px;
	    height: 12px;
	    line-height: 12px;
	    position: relative;
	    margin-bottom:11px;
		.van-progress{
			position: absolute;
			z-index: 1;
			width: 100%;
			height: 100%;
		}
		.sj{
			position: absolute;
			z-index: 2;
			color: #888;
			font-size: 12px;
		}
		.jdt{
			margin-left: 31px;
		    width: calc(100% - 86px);
			border-radius: 15px;
			overflow: hidden;
		}
		.bfh{
			position: absolute;
			right: 30px;
			top: 0px;
			color: #2e3345;
			z-index: 2;
			}
	    }
}
.title_new{
	padding: 10px;
	color: #2e3345;
	font-weight: 400;
	letter-spacing: 1px;
	font-size: 15px;
	padding-left: 0px;
	font-size: 16px;
	letter-spacing: 5px;
	margin-bottom: 2px;
	padding-top: 9px;
	position: relative;
	.latest{
		position: relative;
		background: url(/static/assets/syzx.png) no-repeat;
		background-size: 24px 7px;
		background-position: left bottom 2px;
		::v-deep span{
			font-size: 16px;
			color: #333;
			letter-spacing: 1px;
		}
	}
	.i{
		display: inline-block;
		    width: 14px;
		    height: 14px;
		    background: #00c9a496;
		    border-radius: 9px;
		    margin-left: 4px;
		    position: absolute;
		    bottom: 0px;
		    left: -5px;
		    margin-right: 10px;
	}
	.more{
		    position: absolute;
		    right: 0;
		    bottom: 7px;
		    font-size: 12px;
		    letter-spacing: 1px;
		    background: #fff;
		    padding: 3px 2px;
		    border-radius: 4px;
		    color: #6b6b6b;
		    padding-left: 7px;
			.right{
				position: relative;
				top: -1px;
				left: 2px;
				display: inline-block;
			}
	}
}
.ul{
    position: relative;
    display: flex;
    flex-wrap: wrap;
    margin-bottom: 20px;
	.ul_li:nth-child(4n){
		margin-right: 0;
	}
	.ul_li{
	    width: 24%;
	    margin-right: 1.333%;
	    background: #fff;
	    border-radius: 12px;
	    padding: 10px 14px;
	    box-sizing: border-box;
	    font-size: 12px;
	    height: 133px;
	    position: relative;
	    margin-bottom: 14px;
		text{
			display: block;
		}
	    }
	.p1{
	    font-size: 15px;
	    font-weight: 400;
	    letter-spacing: 1px;
		position: relative;
		top: 7px;
	    }	
	.zx{
	    text-align: center;
	    position: absolute;
	    right: 0;
	    top: 0;
	    width: 48px;
	    background: #00c9a4;
	    border-radius: 0 14px;
	    font-size: 10px;
	    padding: 2px 0;
		::v-deep span{
			color:#fff;
		}
	    }	
	.p4{
	    font-size: 10px;
	    position: relative;
	    width: 100%;
	    height: 18px;
		margin-top: 16px;
		.time_y{
		        position: absolute;
		        left: 0;
		        bottom: 0;
				color: #888888;
		    }
		.time_s{
		        position: absolute;
		        right: 0;
		        bottom: 0;
				color: #888888;
				display: flex;
				align-items: center;
				.icon{
					margin-right: 4px;
					position: relative;
					top: 0px;
				}
		    }	
	    }	
	.p2{
	    margin-top: 14px;
	    font-size: 13px;
	    letter-spacing: 1px;
	    position: relative;
		color: #7F7F7F;
		padding-right: 0px;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	    }	
	.p3{
	    font-size: 10px;
	    margin: 10px 0 3px 0;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
		.bq{
		    background: #f5f5f5;
		        margin-right: 4px;
		        display: inline-block;
		        padding: 1px 10px;
		        border-radius: 17px;
				color: #888888;
		    }
	    }	
	}
	::v-deep .qrcode_box{
		width: 50%;
		background: none;
		.van-dialog__content{
		
			.close{
				position: relative;
				text-align: center;
				font-size: 30px;
				padding-top: 15px;
			}
		
		}
	}
	
	/* 响应式设计 */
	@media (max-width: 1024px) {
	    /* 在宽度小于等于1024px的平板设备上调整样式 */
		.title_new{
			margin-top: 5px;
		}
	
		
	}
</style>
