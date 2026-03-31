<template>
	<view class="tone_content">
		<view class="top">
		  绝对音感-智能练习
		</view>
		<!-- 内容区 -->
		<view class="box">

			<view class="set_box">
				<!-- 选择区 -->
				<view class="change_box">
					<van-grid :border="false" :column-num="8" :gutter="2" >
					  <van-grid-item class="" v-for="item in changeList">
						 <view class="change_btn" v-html="item" :class="{ 'active': isSelected(item) }" @click="toggleSelection(item)"></view>
					  </van-grid-item>
					</van-grid>
				</view>
				<view class="time" style="margin-top: 30px;">
					<view class="title">回答时间</view>
					<view class="li" v-for="item in timeList" @click="onChangeTime(item)" :class="activeTime == item.num ? 'active' : ''">{{item.name}}</view>
				</view>
				
				<view class="time">
					<view class="title">标准音开关</view>
					<van-switch class="switch" v-model="checked" active-color="#111"  size="22px" inactive-color="#dcdee0" />
				</view>
				
				<view class="time">
					<view class="title">练习题数</view>
					<view class="li" v-for="item in tiList" @click="onChangeTime2(item)" :class="activeTime2 == item.num ? 'active' : ''">{{item.name}}</view>
				</view>

				
			</view>
			<view class="begin_box">
				<view class="begin" @click="go()"><van-icon class="icon"  name="/static/assets/jpq_play.jpg" /><view style="position: relative;left: -3px;color: #fff;">开始</view></view>
			</view>
		</view>
	</view>
	
	

</template>
<script setup>
import { ref ,onMounted ,nextTick} from 'vue';
import { useRouter} from 'vue-router';
import {onShow} from '@dcloudio/uni-app';
import {getDetail} from '/api/home.js';
import SampleLibrary from '/pages/common/lib/Tonejs-Instruments.js'
import * as Tone from 'tone';
import { showToast} from 'vant';
import { useStore } from 'vuex';  // 引入 useStore
const store = useStore();  // 使用 useStore




const checked =ref(true)

var set={
    elem: "#waveform",
    width: 600,
    height: 200,
    scale: 2,
    speed: 9,
    phase: 21.8,
    fps: 20,
    keep: true,
    lineWidth: 3,
    linear1: [0, "rgba(150,96,238,1)", 0.2, "rgba(170,79,249,1)", 1, "rgba(53,199,253,1)"],
    linear2: [0, "rgba(209,130,255,0.6)", 1, "rgba(53,199,255,0.6)"],
    linearBg: [0, "rgba(255,255,255,0.2)", 1, "rgba(54,197,252,0.2)"]
}



const waveContainer = ref(null);

// 创建一个合成器和分析器
const synth = SampleLibrary.load({
    instruments: "piano"
}).toMaster();

// 更改为波形数据分析器
const analyser = new Tone.Waveform(1024);
  
synth.connect(analyser);

const activeTime = ref('15');
const activeTime2 = ref('15');
const active = ref('f')
const changeList = [
	'f',
	'<sup>#</sup>f',
	'g',
	'<sup>#</sup>g',
	'a',
	'<sup>b</sup>b',
	'b',
	'c<sup>1</sup>',
	'<sup>#</sup>c<sup>1</sup>',
	'd<sup>1</sup>',
	'<sup>b</sup>e<sup>1</sup>',
	'e<sup>1</sup>',
	'f<sup>1</sup>',
	'<sup>#</sup>f<sup>1</sup>',
	'g<sup>1</sup>',
	'<sup>#</sup>g<sup>1</sup>',
	'a<sup>1</sup>',
	'<sup>b</sup>b<sup>1</sup>',
	'b<sup>1</sup>',
	'c<sup>2</sup>',
	'<sup>#</sup>c<sup>2</sup>',
	'd<sup>2</sup>',
	'<sup>b</sup>e<sup>2</sup>',
	'e<sup>2</sup>',
	'f<sup>2</sup>',
	'<sup>#</sup>f<sup>2</sup>',
	'g<sup>2</sup>',
	'<sup>#</sup>g<sup>2</sup>',
	'a<sup>2</sup>'
]

const timeList = [
	{num:7,name:"7s"},
	{num:10,name:"10s"},
	{num:15,name:"15s"},
	{num:20,name:"20s"},
	{num:25,name:"25s"},
	{num:30,name:"30s"},
	{num:0,name:"无限"},
]

const tiList = ref([
	{num:10,name:"10题"},
	{num:15,name:"15题"},
	{num:20,name:"20题"},
	{num:25,name:"25题"},
])

const router = useRouter();
const showAnswer = ref(true);	
const show = ref(false);
const show1 = ref(false);
const num = ref(20)
const item = ref({});
const id = history.state.id;

getDetail(id).then((res)=>{
	item.value = res.data;
})

function onChangeTime(item){
	activeTime.value = item.num;
}

function onChangeTime2(item){
	activeTime2.value = item.num;
}

function left() {
  router.go(-1);
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
		num:activeTime2.value,
		}
		sessionStorage.setItem('item',JSON.stringify(item))
		router.push({name:"answer"})
	
}

function openZy(){
	show.value = true;
}
function openDa(){
	show1.value = true;
}

function toggleAnswer() {
  showAnswer.value = !showAnswer.value;
}

// 音符转换，将显示用的音符转换为Tone.js可识别的音符
const noteMap = {	
    'f': 'F3', 
    '<sup>#</sup>f': 'F#3', 
    'g': 'G3', 
    '<sup>#</sup>g': 'G#3', 
    'a': 'A3', 
    '<sup>b</sup>b': 'A#3', 
    'b': 'B3', 
    'c<sup>1</sup>': 'C4', 
    '<sup>#</sup>c<sup>1</sup>': 'C#4', 
    'd<sup>1</sup>': 'D4', 
    '<sup>b</sup>e<sup>1</sup>': 'D#4', 
    'e<sup>1</sup>': 'E4', 
    'f<sup>1</sup>': 'F4', 
    '<sup>#</sup>f<sup>1</sup>': 'F#4', 
    'g<sup>1</sup>': 'G4', 
    '<sup>#</sup>g<sup>1</sup>': 'G#4', 
    'a<sup>1</sup>': 'A4', 
    '<sup>b</sup>b<sup>1</sup>': 'A#4', 
    'b<sup>1</sup>': 'B4', 
    'c<sup>2</sup>': 'C6', 
    '<sup>#</sup>c<sup>2</sup>': 'C#6', 
    'd<sup>2</sup>': 'D6', 
    '<sup>b</sup>e<sup>2</sup>': 'D#6', 
    'e<sup>2</sup>': 'E6', 
    'f<sup>2</sup>': 'F6', 
    '<sup>#</sup>f<sup>2</sup>': 'F#6', 
    'g<sup>2</sup>': 'G6', 
    '<sup>#</sup>g<sup>2</sup>': 'G#6', 
    'a<sup>2</sup>': 'A6'
};
var rec,wave;
const myWave = ref(null);
onMounted(() => {
  // const settings = {
  //   elem: "#waveform",
  //   width: 600,
  //   height: 200,
  //   scale: 2,
  //   speed: 9,
  //   phase: 21.8,
  //   fps: 20,
  //   keep: true,
  //   lineWidth: 3,
  //   linear1: [0, "rgba(150,96,238,1)", 0.2, "rgba(170,79,249,1)", 1, "rgba(53,199,253,1)"],
  //   linear2: [0, "rgba(209,130,255,0.6)", 1, "rgba(53,199,255,0.6)"],
  //   linearBg: [0, "rgba(255,255,255,0.2)", 1, "rgba(54,197,252,0.2)"]
  // };
  // myWave.value = new WaveView(settings);
});

function renderWaveform() {
  const waveformData = analyser.getValue();
  myWave.value.draw(waveformData, 50, 44100);
  requestAnimationFrame(renderWaveform); // 在下一帧继续更新波形图
}

// 播放音符并更新波形
function playNote(note) {
  const toneNote = noteMap[note.toLowerCase()];
  if (toneNote) {
    synth.triggerAttackRelease(toneNote, '1n');
  }
  active.value = note
}

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

// 已选中的项数组
const selectedItems = ref([]);


</script>

<style lang="scss" scoped>
	#firstCanvas{
		width: 100%;
		height: 100%;	
	}
	.canva_box ::v-deep canvas{
		width: 100%;
		height: 100%;
	}

	.tone_content{
		height: 100%;
		position: relative;
		.top{
			position: relative;
			background: #fff;
			border-radius: 8px;
			height: 44px;
			display: flex;
			justify-content: center;
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
				position: relative;

				.time{
					position: absolute;
					bottom: 0;
					width: 100%;
				}
			}
			.set_box{
				padding: 20px 80px;
				height: calc(100% - 106px);
				overflow-y: auto;
				-webkit-overflow-scrolling: touch; /* 兼容iOS滚动 */
				  scrollbar-width: none; /* Firefox */
				  -ms-overflow-style: none; /* IE/Edge */
			}
			.change_box{
				margin-top: 12px;
				margin-bottom: 40px;
				.change_btn{
					line-height: 63px;
					    background: #e9e9e9;
					    color: #6b6b6b;
					    width: 63px;
					    height: 63px;
					    text-align: center;
					    border-radius: 6px;
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
				.title{
					    background: #00c9a4;
					    color: #fff;
					    font-size: 13px;
					    padding: 2px 8px;
					    border-radius: 4px;
				}
				.switch{
					margin-left: 15px;
					height: 24px;
					::v-deep .van-switch__node{
						width: 20px;
						height: 20px;
						left: 4px;
					}
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
			.begin_box{
				margin-top: 60px;
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

	}
</style>
