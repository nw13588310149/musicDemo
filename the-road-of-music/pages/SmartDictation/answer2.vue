<template>
	<view class="tone_content">
		<view class="top">
		  <van-icon class="return" name="/static/assets/left1.png" @click="left" />
		  音程识别-智能练习
		  <view class="btnB" v-if="data?.data?.id"> 
			  <view  class="li" v-for="item in ycList" v-html="item" @click="onChangeTime3(item)" :class="activeYc == item ? 'active' : ''">
			  	
			  </view>
		  </view>
		</view>
		<!-- 内容区 -->
		<view class="box">
			<div class="box_top">
				<view class="left">
					<!-- 倒计时 -->
					<van-circle
					  class="circle"
					  :current-rate="currentRate"
					  :stroke-width="100"
					  rate="rate"
					  :color="{
					  							'0%': '#baddd8',
					  							'100%': '#29b5a5',
					  						}"
					  layer-color="#d0e7e4"
					  :text="circleText"
					/>
					<!-- <van-icon v-if="isTure == 0" class="icon change_icon"  name="/static/assets/bg_one.jpg" /> -->
					<!-- <van-icon v-if="isTure != 0" class="icon change_icon"  :name="isTure == 1?'/static/assets/bg_yes.jpg':'/static/assets/bg_no.jpg'" /> -->
					<view class="box2" :style="{'background':colorA1()}">
						<view class="box2_bg" v-if="colorA1() == '#fff'">
							<view class="one" :style="{'top':topOne+'px'}"></view>
							<view class="two" :style="{'top':topTwo+'px'}"></view>
						</view>
						<van-count-down v-show='!isStop' style="position: absolute;z-index: 99;font-family: 'douyu';font-size: 12px;" millisecond :time="timeLeft" ref="countDown" format="ss:SS" />
						<view v-show='isStop' class="tips" style="background: none;font-family: 'douyu';font-size: 16px;" :style="{'color':isTure != 0?'#fff':'#4e4e4e'}">{{tipText}}</view>
					</view>
				</view>
				<view class="right">
					<!-- 音频可视化 -->
					<canvas ref="visualizer" class="audio-visualizer" canvas-id="firstCanvas" id="firstCanvas"></canvas>
				</view>
			</div>
			<view class="set_box">
				<!-- 进度条 -->
				<div style="position: relative;margin-bottom: 30px;">
				<van-progress :percentage="numJd"  stroke-width="10" color="#00c9a4" :show-pivot='false' >
				</van-progress>	
				<view class="jd" :style="{'left':numJd+'%'}">{{numJd/(100/numTm)}}/{{numTm}}</view>
				</div>
				
				<!-- 选择区 -->
				<view class="change_box">
					<van-grid :border="false" :column-num="8" :gutter="2">
					  <van-grid-item class="" v-for="item in changeList">
						 <view class="change_btn" v-html="item" :class="{ 'active': isSelected(item),'wobble-hor-bottom':item == activeItem }"  @click="toggleSelection(item,isSelected(item))"></view>
					  </van-grid-item>
					</van-grid>
				</view>
				<!-- <view>1{{text}}</view> -->
				<view class="begin_box">
					<view class="begin" @click="stop()"><van-icon class="icon"  :name="isStop?'/static/assets/jpq_play.jpg':'/static/assets/jpg_stop1.jpg'" />{{isStop?'开始':'暂停'}}</view>
				</view>

			</view>
		</view>
	</view>
	
	

</template>
<script setup>
import { ref ,onMounted ,onUnmounted,nextTick ,watchEffect,computed,watch} from 'vue';
import { useRouter} from 'vue-router';
import SampleLibrary from '/pages/common/lib/Tonejs-Instruments.js'
import * as Tone from 'tone';
import { CountDown,showConfirmDialog } from 'vant';
import dataAll  from './data1.js'
import { indexOf } from 'lodash';

// 创建或获取 Tone.js 的音频上下文
const audioContext = Tone.getContext().rawContext;

// 确保音频上下文在用户交互时被解锁
const unlockAudioContext = () => {
  if (audioContext.state === 'suspended') {
    audioContext.resume();
  }
};

// 添加用户交互事件监听器
document.addEventListener('click', unlockAudioContext);
document.addEventListener('touchstart', unlockAudioContext);

document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible') {
    audioContext.resume();
  }
});

//读取缓存
const data = JSON.parse(sessionStorage.getItem('item'));
if(data?.data?.id){
	data.item = data.data.param3.split(',');
}

//倒计时
const circleText = "";

const totalDuration = data.time * 1000; // 总时长，例如30秒
const timeLeft = ref(totalDuration); // 剩余时间，初始化为总时长
const activeItem = ref();
//水波纹
const topOne = ref(-111);
const topTwo = ref(-111);
watch(timeLeft, (newValue) => {
	      const progress = (totalDuration - timeLeft.value) / totalDuration;
	      topOne.value = -111 + progress * (-203 + 111);
	      topTwo.value = -111 + progress * (-203 + 111);
});

const router = useRouter();
const numJd = ref(0); //进度条数据

const tipText = ref('准备开始');//提示文字

const ycList = ['旋律音程','和声音程']
const activeYc = ref('和声音程');

// 音符数据
const changeList = [
	'纯一','纯八','大二','小二','大三','小三','纯四','增四/减五','纯五','大六','小六','大七','小七'
]


const nowType = ref('');

const allPlay = ref([]);

// 定义动画时长，单位为秒
const isOk = ref(false); // 来自缓存的isOk状态
isOk.value = data.isOpen; 


// 计算当前的比率
const currentRate = computed(() => {
  return (1 - timeLeft.value / totalDuration) * 100;
});

// 当倒计时结束时更新状态
const handleCountDownFinish = () => {
};

const initNum = ref(0); //精准计时，播放音频
const isStop = ref(true); //是否暂停

//题目数
const numTm = ref(data.num);

let interval;
onMounted(() => {
   interval = setInterval(() => {
	   if(isStop.value) return;
     if (timeLeft.value > 0) {
		 if(numJd.value >= 100){

		 			 let num  = trueNum.value;
		 			 let idValue = 0;
		 			 if(num >= numTm.value) {
		 			   idValue = 3;
		 			 } else if(num >= numTm.value * 2/3) {
		 			   idValue = 2;
		 			 } else if(num >= numTm.value * 1/3) {
		 			   idValue = 1
		 			 } else {
		 			   idValue = 0;
		 			 }
		 			 router.push({name:"over",state: { id: idValue ,all:JSON.stringify(allPlay.value)} })
		 			clearInterval(interval); // 清除定时器
		}
		initNum.value += 10;
		timeLeft.value -= 10; // 每秒减少1000毫秒
		if(initNum.value == 1000){
			if(isOk.value){
				synth.triggerAttackRelease('A4', '1n'); //播放标准音
			}else{
				playRandomNote();//播放随机音频
			}
		}else if(initNum.value == 4000){
			if(isOk.value){
				playRandomNote();//播放随机音频
			}
		}
     } else {
		 if(numJd.value >= 100){
			 let num  = trueNum.value;
			 let idValue = 0;
			 if(num >= numTm.value) {
			   idValue = 3;
			 } else if(num >= numTm.value * 2/3) {
			   idValue = 2;
			 } else if(num >= numTm.value * 1/3) {
			   idValue = 1
			 } else {
			   idValue = 0;
			 }
			 router.push({name:"over",state: { id: idValue } })
			clearInterval(interval); // 清除定时器
		 }else{
			 isStop.value  = true;
			 tipText.value = '超时'
			 isTure.value = 2;
			 
			 setTimeout(function(){
			 	isStop.value = false
			 	isTure.value = 0;
			 	initNum.value  = 0;
			 	timeLeft.value = totalDuration;
			 	numJd.value += 100/numTm.value; 
				answerTrue.value =""
			 },1000)
		 }
       
     }
   }, 10);
});
onUnmounted(() => {
  clearInterval(interval); // 清除定时器
});

onMounted(async () => {
	init_draw()
});

const isTure = ref(0);


function onChangeTime3(item){
	activeYc.value = item;
}

function colorA(){
	if(isTure.value == 0){
		return '#111'
	}else if(isTure.value == 1){
		return '#00c9a4'
	}else if(isTure.value == 2){
		return '#e61f62'
	}else{
		return '#111'
	}
}

function colorA1(){
	if(isTure.value == 0){
		return '#fff'
	}else if(isTure.value == 1){
		return '#00c9a4'
	}else if(isTure.value == 2){
		return '#e61f62'
	}else{
		return '#fff'
	}
}


const countDown = ref('')
function stop(){
	isStop.value = !isStop.value;
	if(isStop.value){
		countDown.value.pause();
		tipText.value = '暂停'
	}else{
		countDown.value.start();
	}
}

const trueNum = ref(0);

function toggleSelection(item,type){
	if(isTure.value != 0) return;

	if(type){
		activeItem.value = item;
		setTimeout(function(){
			activeItem.value=""
		},2000)
		isStop.value = true;

		if(item == answerTrue.value){
			tipText.value = '正确'
			isTure.value = 1;
			trueNum.value += 1;
		}else{
			//点击错误
			tipText.value = '错误'
			isTure.value = 2;
		}
		setTimeout(function(){
			isStop.value = false
			isTure.value = 0;
			initNum.value  = 0;
			timeLeft.value = totalDuration;
			numJd.value += 100/numTm.value; 
			answerTrue.value = "";
		},2000)
	}
}

//返回上一页
function left() {
	showConfirmDialog({
	  message:
	    '是否退出当前练习',
	})
	  .then(() => {
	    // on confirm
		if(data?.data?.id){
			router.push({name:"smartDictation",state:{id:3}})
		}else{
			router.push({name:"smartDictation",state:{id:4}})
		}
	  })
	  .catch(() => {
	    // on cancel
	  });
}

// 检查是否已选中
function isSelected(item) {
  return data.item.includes(item);
}


// 创建一个合成器和分析器
const synth = SampleLibrary.load({
    instruments: "piano"
}).toDestination();

// 更改为波形数据分析器
const analyser = new Tone.Waveform(64);
synth.connect(analyser);

// 处理音频播放
function handleAudioPlayback(secondsPassed, playedFirstSecond, playedThirdSecond) {
  const currentSecond = Math.floor(secondsPassed);
  if (currentSecond === 1 && !playedFirstSecond) {
    playedFirstSecond = true;
    playNoteBasedOnCondition();
  } else if (currentSecond === 3 && !playedThirdSecond && isOk.value) {
    playedThirdSecond = true;
    playRandomNote();
  }
  return { playedFirstSecond, playedThirdSecond };
}

function playNoteBasedOnCondition() {
	audioContext.resume();  // 确保音频上下文已恢复
  if (isOk.value) {
    synth.triggerAttackRelease('A1', '1n');
  } else {
    playRandomNote();
  }
}

const jbarr = ["F3","G3","A3","B3","C4","D4","E4","F4","G4","A4","B4", "C5","D5", "E5", "F5","G5","A5"];

//获取根音
let playInit = [];
dataAll.根音.s1.forEach((e,i) =>{
	if(i>=dataAll.根音.s2.indexOf(data.min) && i <= dataAll.根音.s2.indexOf(data.max)){
		// 是否过滤基本音
		if(data.isJb && jbarr.indexOf(e) == -1){
			
		}else{
			playInit.push({name:e,code:i})
		}
	}
})


const answerTrue = ref("");


// 随机
function getRandomPair(arr) {
    if (arr.length !== 2) {
        throw new Error("Array must contain exactly two elements");
    }
    const [a, b] = arr;
    if (Math.random() < 0.5) {
        return { a, b };
    } else {
        return { a: b, b: a };
    }
}

const text = ref([])
//随机音处理
function playRandomNote() {
	audioContext.resume();  // 确保音频上下文已恢复
	if(data?.data?.id){
		let input = data.data.param1;		
		const result = input.match(/\[(.*?)\]/g).map(item => item.slice(1, -1).split(','));
		
		const randomIndex = Math.floor(Math.random() * result.length);
		const init = getRandomPair(result[randomIndex])
		
		let num = dataAll.根音.s1.indexOf(result[randomIndex][0]);
		data.item.forEach(e =>{
			if(result[randomIndex][1] == dataAll[e].s1[num]){
				answerTrue.value = e;

				allPlay.value.push(answerTrue.value)
			}
		})
		
		//是否和弦
		if(activeYc.value == '旋律音程'){
			synth.triggerAttackRelease(init.a, '1n')
			setTimeout(function(){
			synth.triggerAttackRelease(init.b, '1n')	
			},2000)
		}else{
			synth.triggerAttackRelease(init.a, '1n')
			synth.triggerAttackRelease(init.b, '1n')	
		}
		

		

		
	}else{
		const items = data.item;
		// 1.0 获取当前随机值
		const randomIndex = Math.floor(Math.random() * items.length);
		
		// 2.0 获取根音
		const randomInit = Math.floor(Math.random() * playInit.length);
		const playOne = playInit[randomInit].name;
		
		// 3.0获取对应音

		const playTwo = dataAll[items[randomIndex]].s1[playInit[randomInit].code];
		

		if(playTwo && playTwo != 'null'){

			text.value.push([playOne,playTwo])
			//是否和弦
			if(data.ycfs == '旋律音程'){
				synth.triggerAttackRelease(playOne, '1n')
				setTimeout(function(){
				synth.triggerAttackRelease(playTwo, '1n')	
				},1000)
			}else{
				synth.triggerAttackRelease(playOne, '1n')
				synth.triggerAttackRelease(playTwo, '1n')
		
			}
			
			answerTrue.value = items[randomIndex];
			allPlay.value.push(answerTrue.value)
		}else{
			playRandomNote()
		}
	}
}


//绘制波形图
const init_draw = () =>{
	// 创建一个画布
	var ctx = uni.createCanvasContext('firstCanvas');
	
	
	// 获取画布宽高值
	const query = uni.createSelectorQuery();
	let width = "";
	let height = "";
	query.select('#firstCanvas').fields({size:true},(res)=>{
		width = res.width;
		height = res.height;
	}).exec()
	
	// 设置背景颜色
	ctx.fillStyle = "#29f0ae";
	ctx.fillRect(0, 0, width, height);

	// 波形颜色
	
	// 绘制波形
	function drawWaveform() {
	    requestAnimationFrame(drawWaveform);
	    const waveformValues = analyser.getValue();
	
	    ctx.clearRect(0, 0, width, height);
	    ctx.beginPath();
	    ctx.moveTo(0, height / 2);
		ctx.fillStyle = "#00c9a4";
	    // 绘制波形
	    for (let i = 0; i < waveformValues.length; i++) {
	        const x = (i / waveformValues.length) * width;
			const y = (waveformValues[i] + 0.5) * height - 80 ;

	        ctx.fillRect(x, height*0.5, 4, y);
			ctx.fillRect(x, height*0.5, 4, -y);
	    }
	
	    ctx.lineWidth = 2;
	    ctx.stroke();
		ctx.draw(); // 绘制到画布上
	}
	drawWaveform();
}
</script>
<style lang="scss" scoped>
	.active{
		background: #111 !important;
		color: #fff !important;
		::v-deep sup{
			color: #fff !important;
		}
	}
	#firstCanvas{
		width: 90%;
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
			  top: 7px;
			  font-size: 30px;
			}
			.btnB{
				position: absolute;
				right: 10px;
				width:180px;
				top: 11px;
				.li{
					display: inline-block;
					width: 68px;
					box-shadow: 0 0 8px 0 #f3f3f3;
					color: #6b6b6b;
					font-size: 13px;
					padding: 2px 8px;
					border-radius: 4px;
					margin-left: 15px;
				}
			}
		}
		.box{
			  height: calc(100% - 54px);
			  margin-top: 10px;
			  border-radius: 9px;
			  overflow: hidden;
			  position: relative;
			  background: #fff;
			  padding: 20px;
			  .box2{
				      position: absolute;
				      width: 95px;
				      height: 95px;
				      border-radius: 50%;
				      background: #fff;
					  display: flex;
					justify-content: center;
					align-items: center;
					overflow: hidden;
					.box2_bg{
						width: 100%;
						height: 100%;
						border-radius: 50%;
						background: #00c9a4;
						overflow: hidden;
						.one,.two{
						  content: '';
						  width: 200px;
						  height: 200px;
						  left: -50px;
						  position: absolute;
						  z-index: 5;
						}
						.one{
							border-radius: 44%;
							background: #ffffff;
							animation: rotatewaveeff53 6s linear infinite;
						}
						.two{
							border-radius: 38%;
							background: rgb(255,255,255,0.5);
							animation: rotatewaveeff53 8s linear infinite;
						}
					}	
					@keyframes rotatewaveeff53{
					  0% {
					    transform: rotate(0deg);
					  }
					  100% {
					    transform: rotate(360deg);
					  }
					}
			  }
			  .box_top{
				  background: #f6f7fb;
				  height: 170px;
				  border-radius: 8px;
				  position: relative;
				  .left{
						width: 30%;
					    display: flex;
					    justify-content: center;
					    align-items: center;
					    height: 100%;
						.tips{
							position: absolute;
							    z-index: 9;
							    width: 50px;
							    background: #f6f7fb;
							    text-align: center;
							    font-size: 20px;
							    letter-spacing: 2px;
							    font-weight: 400;
						}
						.circle{
							width: 130px;
							height: 130px;
							position: absolute;
							z-index: 2;
							::v-deep .van-circle__text{
								font-size: 20px;
							}
						}
						.change_icon{
							position: absolute;
							z-index: 1;
							font-size: 153px;
						}
				  }
				  .right{
					  position: absolute;
					  left: 30%;
					  height: 100%;
					  width: 70%;
					  top: 0;
					  #waveform{
					  	height: 40px;
					  	margin-top: 36px;
					  	display:flex;
					  	justify-content: center;
					  	position: relative;
					  	::v-deep div{
					  		width: 80%;
					  		.scroll{
					  			width: 50%;
					  		}
					  	}
					  }
					  #waveform::after {
					      content: "";
					      position: absolute;
					      top: 0;
					      left: 0;
					      width: 100%;
					      height: 100%;
					      pointer-events: none;
					   }
				  }
			  }
			  
			.canva_box{
				height: 190px;
				position: relative;

				.time{
					position: absolute;
					bottom: 0;
					width: 100%;
				}
			}
			.set_box{
				padding: 20px 100px;
				height: calc(100% - 190px);
				position: relative;
				padding-top: 50px;
				.jd{
					background: url(/static/assets/bg_text.jpg) no-repeat;
					    position: absolute;
					    top: -40px;
					    font-size: 20px;
					    background-size: cover;
					    width: 50px;
					    height: 38px;
					    text-align: center;
					    line-height: 32px;
					    transform: translateX(-26px);
						color: #fff;
						    font-size: 14px;
				}
			}
			.change_box{
				margin-top: 12px;
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
				.isOk{
					background: #e9e9e9;
				}
				
				::v-deep .van-grid-item__content{
					background: none;
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
					    color: #111515;
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
					sup{
						color: #fff;
					}
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
				display: flex;
				justify-content: center;
				position: absolute;
				width: calc(100% - 200px);
				bottom: 13px;
				.begin{
					display: inline-block;
					width: 120px;
					height: 45px;
					line-height: 45px;
					color: #fff;
					background: #00c9a4;
					text-align: center;
					font-size: 18px;
					letter-spacing: 2px;
					border-radius: 50px;
					.van-icon{
						font-size: 25px;
						margin-right: 10px;
						position: relative;
						top: 6px;
					}
				}
			}
		}

	}
	/* 响应式设计 */
	@media (max-width: 1024px) {
	    /* 在宽度小于等于1024px的平板设备上调整样式 */
		.tone_content .box .begin_box{
			    display: flex;
			    justify-content: center;
			    position: absolute;
			    width: calc(100% - 200px);
			    bottom: -20px;
		}
	
		
	}
	// 动画效果
	.wobble-hor-bottom {
		-webkit-animation: wobble-hor-bottom 0.8s both;
		        animation: wobble-hor-bottom 0.8s both;
	}
	/* ----------------------------------------------
	 * Generated by Animista on 2024-7-6 19:30:55
	 * Licensed under FreeBSD License.
	 * See http://animista.net/license for more info. 
	 * w: http://animista.net, t: @cssanimista
	 * ---------------------------------------------- */
	
	/**
	 * ----------------------------------------
	 * animation wobble-hor-bottom
	 * ----------------------------------------
	 */
	@-webkit-keyframes wobble-hor-bottom {
	  0%,
	  100% {
	    -webkit-transform: translateX(0%);
	            transform: translateX(0%);
	    -webkit-transform-origin: 50% 50%;
	            transform-origin: 50% 50%;
	  }
	  15% {
	    -webkit-transform: translateX(-30px) rotate(-6deg);
	            transform: translateX(-30px) rotate(-6deg);
	  }
	  30% {
	    -webkit-transform: translateX(15px) rotate(6deg);
	            transform: translateX(15px) rotate(6deg);
	  }
	  45% {
	    -webkit-transform: translateX(-15px) rotate(-3.6deg);
	            transform: translateX(-15px) rotate(-3.6deg);
	  }
	  60% {
	    -webkit-transform: translateX(9px) rotate(2.4deg);
	            transform: translateX(9px) rotate(2.4deg);
	  }
	  75% {
	    -webkit-transform: translateX(-6px) rotate(-1.2deg);
	            transform: translateX(-6px) rotate(-1.2deg);
	  }
	}
	@keyframes wobble-hor-bottom {
	  0%,
	  100% {
	    -webkit-transform: translateX(0%);
	            transform: translateX(0%);
	    -webkit-transform-origin: 50% 50%;
	            transform-origin: 50% 50%;
	  }
	  15% {
	    -webkit-transform: translateX(-30px) rotate(-6deg);
	            transform: translateX(-30px) rotate(-6deg);
	  }
	  30% {
	    -webkit-transform: translateX(15px) rotate(6deg);
	            transform: translateX(15px) rotate(6deg);
	  }
	  45% {
	    -webkit-transform: translateX(-15px) rotate(-3.6deg);
	            transform: translateX(-15px) rotate(-3.6deg);
	  }
	  60% {
	    -webkit-transform: translateX(9px) rotate(2.4deg);
	            transform: translateX(9px) rotate(2.4deg);
	  }
	  75% {
	    -webkit-transform: translateX(-6px) rotate(-1.2deg);
	            transform: translateX(-6px) rotate(-1.2deg);
	  }
	}
</style>
