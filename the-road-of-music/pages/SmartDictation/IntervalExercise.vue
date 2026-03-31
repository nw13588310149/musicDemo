<template>
	<view class="tone_content1">
		<view class="top" style="justify-content: center;">
		  音程识别-智能练习
		</view>
		<!-- 内容区 -->
		<view class="box">
			<view class="set_box">
				<!-- 选择区 -->
				<view class="change_box" style="margin: 10px -14px;">
					<van-grid :border="false" :column-num="5" :gutter="2">
					  <van-grid-item class="" v-for="item in changeList">
						 <view class="change_btn" v-html="item" :class="{ 'active': isSelected(item) }" @click="toggleSelection(item)"></view>
					  </van-grid-item>
					</van-grid>
				</view>
				<view class="time">
					<view class="title">回答时间</view>
					<view class="li" v-for="item in timeList" @click="onChangeTime(item)" :class="activeTime == item.num ? 'active' : ''">{{item.name}}</view>
				</view>
				<view class="time">
					<view class="title">最低音</view>
					<view class="scroll">
						<view  class="li" v-for="item in minList" v-html="item" @click="onChangeTime1(item)" :class="activeMin == item ? 'active' : ''"></view>
					</view>
				</view>
				<view class="time">
					<view class="title">最高音</view>
					<view class="scroll">
						<view  class="li" v-for="item in maxList" v-html="item" @click="onChangeTime2(item)" :class="activeMax == item ? 'active' : ''"></view>
					</view>
				</view>
				<view class="time">
					<view class="title">音程方式</view>
					<view class="scroll">
						<view  class="li" v-for="item in ycList" v-html="item" @click="onChangeTime3(item)" :class="activeYc == item ? 'active' : ''">
							
						</view>
					</view>
				</view>
				<view class="time">
					<view class="title">练习题数</view>
					<view class="li" v-for="item in tiList" @click="onChangeTime9(item)" :class="activeTime2 == item.num ? 'active' : ''">{{item.name}}</view>
				</view>
				<view class="time">
					<view class="title">标准音开关</view>
					<van-switch class="switch" v-model="checked" active-color="#111"  size="22px" inactive-color="#dcdee0" />
				</view>
				<view class="time">
					<view class="title">只练基本音级</view>
					<van-switch class="switch" v-model="checkedJb" active-color="#111"  size="22px" inactive-color="#dcdee0" />
				</view>
				
				
			</view>
			<view class="begin_box">
				<view class="begin" @click="go()"><van-icon class="icon"  name="/static/assets/jpq_play.jpg" /><view style="position: relative;left: -3px;color: #fff;">开始</view></view>
			</view>
		</view>
	</view>
	
	

</template>

<script setup>
import { ref ,onMounted} from 'vue';
import { useRouter} from 'vue-router';
import { showToast} from 'vant';
import { useStore } from 'vuex';  // 引入 useStore
const store = useStore();  // 使用 useStore

const activeTime = ref('15');
const activeMin = ref('f');
const activeMax = ref('a<sup>2</sup>');
const activeYc = ref('旋律音程');
const checked = ref(false);
const checkedJb = ref(false);


const ycList = ['旋律音程','和声音程']
const glList = ['只练基本音','全部练']

const changeList = [
	'纯一','纯八','大二','小二','大三','小三','纯四','增四/减五','纯五','大六','小六','大七','小七'
]
const minList = [
	'f',
	'<sup>#</sup>f',
	'g',
	'<sup>#</sup>g',
	'a',
	'<sup>b</sup>b',
	'b',
	'c<sup>1</sup>',
	// '<sup>#</sup>c<sup>1</sup>',
	// 'd<sup>1</sup>',
	// '<sup>b</sup>e<sup>1</sup>',
	// 'f<sup>1</sup>',
	// '<sup>#</sup>f<sup>1</sup>',
	// 'g<sup>1</sup>',
	// '<sup>#</sup>g<sup>1</sup>',
	// 'a<sup>1</sup>',
	]
const maxList = [
	'f<sup>2</sup>',
	'#f<sup>2</sup>',
	'g<sup>2</sup>',
	'#g<sup>2</sup>',
	'a<sup>2</sup>',
	]
const activeTime2 = ref('15');
const timeList = [
	{num:10,name:"10s"},
	{num:15,name:"15s"},
	{num:20,name:"20s"},
	{num:25,name:"25s"},
	{num:30,name:"30s"},
	{num:0,name:"无限"},
]
function onChangeTime9(item){
	activeTime2.value = item.num;
}


const router = useRouter();
const showAnswer = ref(true);	
const show = ref(false);
const show1 = ref(false);
const num = ref(20)
const item = ref({});
// 已选中的项数组
const selectedItems = ref([]);



function left() {
  router.go(-1);
}

const tiList = ref([
	{num:10,name:"10题"},
	{num:15,name:"15题"},
	{num:20,name:"20题"},
	{num:25,name:"25题"},
])


// 切换选中状态
function toggleSelection(item) {
  const index = selectedItems.value.indexOf(item);
  if (index === -1) {
    selectedItems.value.push(item);
  } else {
    selectedItems.value.splice(index, 1);
  }
}
// 检查是否已选中
function isSelected(item) {
  return selectedItems.value.includes(item);
}
function onChangeTime(item){
	activeTime.value = item.num;
}
function onChangeTime1(item){
	activeMin.value = item;
}
function onChangeTime2(item){
	activeMax.value = item;
}
function onChangeTime3(item){
	activeYc.value = item;
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

//开始
function go(){
	if(vipExpireDate == null){
		showToast("您还未开通会员");
		return false;
	}else if(!isFutureDate(vipExpireDate)){
		showToast("您的会员已过期，请续费");
		return false;
	}else{
	}
	if(selectedItems.value == 0){
		return
	}
	let item = {
		time:activeTime.value,
		item:selectedItems.value,
		isOpen:checked.value,
		isJb:checkedJb.value,
		ycfs:activeYc.value,
		min:activeMin.value,
		max:activeMax.value,
		type:2,
		num:activeTime2.value,
		}
		sessionStorage.setItem('item',JSON.stringify(item))
		router.push({name:"answer2"})
	
}
</script>

<style lang="scss" scoped>
	.li.active ::v-deep sup{
		color: #fff;
	}
	.tone_content1{
		height: 100%;
		position: relative;
		.top{
			position: relative;
			background: #fff;
			border-radius: 8px;
			height: 44px;
			display: flex;
			justify-content: flex-start;
			align-items: center;
			.btn{
				padding: 3px 10px;
				background: #f6f7fb;
				margin-left:15px;
				font-weight: 500;
				border-radius: 8px;
				font-size:14px;
			}
			.return {
			  position: absolute;
			  left: 10px;
			  top: 3px;
			  font-size: 26px;
			}
		}
		.box{
			height: calc(100% - 54px);
			background: #fff;
			margin-top: 10px;
			border-radius: 9px;
			overflow: hidden;
			.canva_box{
				background: #d6f4ed;
				height: 190px;
			}
			.set_box{
				margin: 20px 40px;
				padding: 0 40px;
				height: calc(100% - 125px);
				overflow-y: auto;
				-webkit-overflow-scrolling: touch; /* 兼容iOS滚动 */
				  scrollbar-width: none; /* Firefox */
				  -ms-overflow-style: none; /* IE/Edge */
			}
			.change_box{
				margin: 20px -10px;
				
				.change_btn{
					    width: 110px;
					    background: #e9e9e9;
					    color: #6b6b6b;
					    min-width: 50px;
					    text-align: center;
					    border-radius: 6px;
					    height: 50px;
					    line-height: 50px;
					    margin-bottom: 10px;
				}
				.change_btn.active{
					background: #00c9a4;
					color: #fff;
					sup{
						color: #fff;
					}
				}
				
				::v-deep .van-grid-item__content--center{
					padding: 8px;
				}
			}
			.time{
				background-color: #e9e9e9;
				border-radius: 6px;
				margin-top: 12px;
				display: flex;
				height: 42px;
				padding: 10px;
				position: relative;
				margin-bottom: 12px;
				.switch{
					margin-left: 15px;
					height: 24px;
					::v-deep .van-switch__node{
						width: 20px;
						height: 20px;
						left: 4px;
					}
				}
				.title{
					    background: #00c9a4;
					    color: #fff;
					    font-size: 13px;
					    padding: 2px 8px;
					    border-radius: 4px;
				}
				.li{
					background: #fff;
					color: #6b6b6b;
					font-size: 13px;
					padding: 2px 8px;
					border-radius: 4px;
					margin-left: 15px;
				}
				.li.active{
					background: #171a20;
					color: #fff;
				}
				.scroll{
					position: absolute;
					left: 94px;
					    width: calc(100% - 108px);
					    overflow-x: auto;
						overflow-x: auto;
						-webkit-overflow-scrolling: touch; /* 兼容iOS滚动 */
						white-space: nowrap; /* 禁止换行 */ 
						scrollbar-width: none; /* Firefox */
						-ms-overflow-style: none; /* IE/Edge */
						
						.li{
							display: inline-block;
							margin-left: 0;
							margin-right: 15px;
						}
				}
				.scroll::-webkit-scrollbar {
				  display: none; /* Chrome/Safari/Opera */
				}
				
			}

		}
		.begin_box{
			display: flex;
			justify-content: center;
			position: absolute;
			width: 100%;
			bottom: 50px;
			.begin{
				display: inline-block;
				width: 120px;
				height: 50px;
				line-height: 50px;
				color: #fff;
				background: #00c9a4;
				text-align: center;
				font-size: 22px;
				letter-spacing: 2px;
				border-radius: 50px;
				display: flex;
				justify-content: center;
				align-items: center;
				.van-icon{
					font-size: 32px;
					margin-right: 12px;
			
				}
			}
		}

	}
</style>
