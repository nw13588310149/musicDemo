<template>
	<view class="tone_content">
		<view class="top">
		  <van-icon class="return" name="/static/assets/left1.png" @click="left" />
		  绝对音感-智能练习
<!-- 		  <view class="change">
			  作答模式
			  <van-switch class="switch" v-model="checked" active-color="#111"  size="22px" inactive-color="#dcdee0" />
		  </view> -->
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
				<view class="change_box" v-if="checked">
					<van-grid :border="false" :column-num="8" :gutter="2">
					  <van-grid-item class="" v-for="item in changeList">
						 <view class="change_btn" v-html="item" :class="{ 'active': isSelected(item),'wobble-hor-bottom':item == activeItem }"  @click="toggleSelection(item,isSelected(item))"></view>
					  </van-grid-item>
					</van-grid>
				</view>
				<view class="change_box2" v-if="!checked">
					<!-- 钢琴键盘 -->
					<view class="piano-key-wrap" id="piano-key-wrap" >
					
						<!-- 钢琴白键 -->
					  <view class="piano_f">
						  <view class="piano-key wkey"
						       v-for="(note, index) in Notes.white"
						       :key="note.keyCode"
						       :data-keyCode="note.keyCode"
						       :data-name="note.name"
							   :class="{ 'active': isKeyPressed(note.keyCode) }"
							   @touchstart.stop.prevent="clickPianoKey($event, note.keyCode)"
							   @touchend.stop.prevent="stopPianoKey($event, note.keyCode)"
							   >
							   <view class="topBox">
								   <view class="notenameBox">
								   	<view class="notename2">
								   	{{note.name2}}
									<view class="c"  :style="{
									  color: note.red ? '#fff' : ''
									}">{{note.name3}}</view>
								   </view>
								   				   
								   </view>
								   				
							   </view>
						  </view> 
					  </view>
					   <!-- 钢琴黑键 -->
					   <view class="piano_b" >
					   		  <view class="piano-key-black wkey"
					   		       v-for="(note,index) in Notes.black"
					   		       :key="note.keyCode"
					   		       :data-keyCode="note.keyCode"
					   		       :data-name="note.name"
								   :class="{ 'active': isKeyPressed(note.keyCode) }"
								   @touchstart.stop.prevent="clickPianoKey($event, note.keyCode)"
								   @touchend.stop.prevent="stopPianoKey($event, note.keyCode)"
								   :style="{marginLeft: `${getMarginLeft(index)}%`,top:index>12?'calc(200% + 10px)':'0',left:index>12?'-99.2%':'0'}"
									>
					   		    <view class="keytip">
					   		      
					   		    </view>
					   		  </view> 
					   </view>
					</view>
				</view>
				<view class="begin_box">
					<!-- <view class="begin reload" @click="reload()"><van-icon class="icon"  name="/static/assets/video_play.jpg" />重听</view> -->
					<view class="begin" @click="stop()"><van-icon class="icon"  :name="isStop?'/static/assets/jpq_play.jpg':'/static/assets/jpg_stop1.jpg'" />{{isStop?'开始':'暂停'}}</view>
				</view>

			</view>
		</view>
	</view>
	
	

</template>
<script setup>
import { ref, onMounted, onUnmounted, nextTick, watchEffect, computed ,watch} from 'vue';
import { useRouter } from 'vue-router';
import SampleLibrary from '/pages/common/lib/Tonejs-Instruments.js'
import { Howl, Howler } from 'howler';
import { CountDown,showConfirmDialog } from 'vant';
import * as Tone from 'tone';
import NotesData from '../common/config/notes';


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

//作答模式
const checked = ref(true);
const isShow = ref(false);
const keyPressed = ref([]);
const isKeyPressed = (keyCode) => {
	return keyPressed.value[keyCode] || false;
};

// 黑键位置计算
const getMarginLeft = (index) => {
      const baseMargin = 0; // 基础的 margin 值
      const n = Math.floor(index / 5); // 第几组黑键
      const remainder = index % 5; // 当前组内的位置
	  const keyWidth = ref(5.5);
      if (remainder === 0) {
        return index>4?keyWidth.value*1.3:keyWidth.value*0.65; 
      } else if (remainder === 1 || remainder === 3 || remainder === 4) {
        return keyWidth.value*0.3; 
      } else if (remainder === 2) {
        return keyWidth.value*1.3; 
      }
	  // 其他情况默认返回 0
	  return 0;
}

const stopPianoKey = (e,keyCode) => {
    keyPressed.value[keyCode] = false;
};

	const clickPianoKey = (e, keyCode) => {
	    // 记录触摸点按下的钢琴键状态
		keyPressed.value = { ...keyPressed.value, [keyCode]: true }
	    // 播放音符
	    let pressedNote = getNoteByKeyCode(keyCode);
	    if (pressedNote) {
	        playNote(pressedNote.url);
	    }
		return true;
	};

//重听状态检测
const reloadType = ref(false);

// 读取缓存
const data = JSON.parse(sessionStorage.getItem('item'));

// 倒计时
const circleText = "";

// 按键音
const Notes = ref(NotesData);

const totalDuration = data.time * 1000; // 总时长，例如30秒
const timeLeft = ref(totalDuration); // 剩余时间，初始化为总时长

//题目数
const numTm = ref(data.num);

//水波纹
const topOne = ref(-111);
const topTwo = ref(-111);
watch(timeLeft, (newValue) => {
	      const progress = (totalDuration - timeLeft.value) / totalDuration;
	      topOne.value = -111 + progress * (-203 + 111);
	      topTwo.value = -111 + progress * (-203 + 111);
});

const router = useRouter();
const numJd = ref(0); // 进度条数据
const activeItem = ref();

const tipText = ref('准备开始');// 提示文字



// 音符数据
const changeList = [
  'f', '<sup>#</sup>f', 'g', '<sup>#</sup>g', 'a', '<sup>b</sup>b', 'b', 'c<sup>1</sup>', '<sup>#</sup>c<sup>1</sup>',
  'd<sup>1</sup>', '<sup>b</sup>e<sup>1</sup>', 'e<sup>1</sup>', 'f<sup>1</sup>', '<sup>#</sup>f<sup>1</sup>', 'g<sup>1</sup>',
  '<sup>#</sup>g<sup>1</sup>', 'a<sup>1</sup>', '<sup>b</sup>b<sup>1</sup>', 'b<sup>1</sup>', 'c<sup>2</sup>', '<sup>#</sup>c<sup>2</sup>',
  'd<sup>2</sup>', '<sup>b</sup>e<sup>2</sup>', 'e<sup>2</sup>', 'f<sup>2</sup>', '<sup>#</sup>f<sup>2</sup>', 'g<sup>2</sup>', '<sup>#</sup>g<sup>2</sup>', 'a<sup>2</sup>'
];

// 音符转换，将显示用的音符转换为Tone.js可识别的音符
const noteMap = {
  'f': 'F3', '<sup>#</sup>f': 'F#3', 'g': 'G3', '<sup>#</sup>g': 'G#3', 'a': 'A3', '<sup>b</sup>b': 'A#3', 'b': 'B3',
  'c<sup>1</sup>': 'C4', '<sup>#</sup>c<sup>1</sup>': 'C#4', 'd<sup>1</sup>': 'D4', '<sup>b</sup>e<sup>1</sup>': 'D#4',
  'e<sup>1</sup>': 'E4', 'f<sup>1</sup>': 'F4', '<sup>#</sup>f<sup>1</sup>': 'F#4', 'g<sup>1</sup>': 'G4', '<sup>#</sup>g<sup>1</sup>': 'G#4',
  'a<sup>1</sup>': 'A4', '<sup>b</sup>b<sup>1</sup>': 'A#4', 'b<sup>1</sup>': 'B4', 'c<sup>2</sup>': 'C5', '<sup>#</sup>c<sup>2</sup>': 'C#5',
  'd<sup>2</sup>': 'D5', '<sup>b</sup>e<sup>2</sup>': 'D#5', 'e<sup>2</sup>': 'E5', 'f<sup>2</sup>': 'F5', '<sup>#</sup>f<sup>2</sup>': 'F#5',
  'g<sup>2</sup>': 'G5', '<sup>#</sup>g<sup>2</sup>': 'G#5', 'a<sup>2</sup>': 'A5'
};

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

const initNum = ref(0); // 精准计时，播放音频
const isStop = ref(true); // 是否暂停

let interval;
onMounted(() => {
  interval = setInterval(() => {
    if(isStop.value) return;
    if (timeLeft.value > 0) {
      if(numJd.value >= 100) {
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
        router.push({ name:"over", state: { id: idValue, all:JSON.stringify(allPlay.value) } });
        clearInterval(interval); // 清除定时器
      }
      initNum.value += 10;
      timeLeft.value -= 10; // 每秒减少1000毫秒
      if(initNum.value == 1000) {
        if(isOk.value) {
          synth.triggerAttackRelease('A4', '1n'); // 播放标准音
        } else {
          playRandomNote(); // 播放随机音频
        }
      } else if(initNum.value == 4000) {
        if(isOk.value) {
          playRandomNote(); // 播放随机音频
        }
      }
    } else {
      if(numJd.value >= 100) {
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
        router.push({ name:"over", state: { id: idValue } });
        clearInterval(interval); // 清除定时器
      } else {
        isStop.value  = true;
        tipText.value = '超时';
        isTure.value = 2;

        setTimeout(() => {
          isStop.value = false;
          isTure.value = 0;
          initNum.value  = 0;
          timeLeft.value = totalDuration;
		  console.log(numTm)
          numJd.value += 100/numTm.value; 
          nowType.value = "";
        }, 1000);
      }
    }
  }, 10);
});

onUnmounted(() => {
  clearInterval(interval); // 清除定时器
});

onMounted(async () => {
  init_draw();
});

const isTure = ref(0);

//重听
function reload(){
	
}

function colorA() {
  if(isTure.value == 0) {
    return '#111';
  } else if(isTure.value == 1) {
    return '#00c9a4';
  } else if(isTure.value == 2) {
    return '#e61f62';
  } else {
    return '#111';
  }
}

function colorA1() {
  if(isTure.value == 0) {
    return '#fff';
  } else if(isTure.value == 1) {
    return '#00c9a4';
  } else if(isTure.value == 2) {
    return '#e61f62';
  } else {
    return '#fff';
  }
}

const countDown = ref('');
function stop() {
  isStop.value = !isStop.value;
  if(isStop.value) {
    countDown.value.pause();
    tipText.value = '暂停';
  } else {
    countDown.value.start();
  }
}

const trueNum = ref(0);

function toggleSelection(item, type,event) {
	// #ifdef APP-PLUS 
	//触感反馈
	let UIImpactFeedbackGenerator = plus.ios.importClass(
		'UIImpactFeedbackGenerator'
	)
	let impact = new UIImpactFeedbackGenerator()
	impact.prepare()
	impact.init(1)
	impact.impactOccurred()
	// #endif
	
  if(isTure.value != 0) return;
  

  if(type) {
	activeItem.value = item;
	setTimeout(function(){
		activeItem.value=""
	},2000)
    isStop.value = true;
    const randomNote = noteMap[item.toLowerCase()];
	console.log(nowType.value)
    if(randomNote == nowType.value) {
      tipText.value = '正确';
      isTure.value = 1;
      trueNum.value += 1;
    } else {
      // 点击错误
      tipText.value = '错误';
      isTure.value = 2;
    }
    setTimeout(() => {
      isStop.value = false;
      isTure.value = 0;
      initNum.value  = 0;
      timeLeft.value = totalDuration;
      numJd.value += 100/numTm.value;
      nowType.value = "";
    }, 2000);
  }
}

// 返回上一页
function left() {
	showConfirmDialog({
	  message:
	    '是否退出当前练习',
	})
	  .then(() => {
	    // on confirm
		if(data?.data?.id) {
		  router.push({ name:"smartDictation", state:{ id:1 } });
		} else {
		  router.push({ name:"smartDictation", state:{ id:2 } });
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
    const sound = new Howl({
      src: [`/static/samples/piano/a80.mp3`],
      loop: false,
      html5: true,
      autoplay: true,
    });
    sound.play();
  } else {
    playRandomNote();
  }
}


function playRandomNote() {
  audioContext.resume();  // 确保音频上下文已恢复
  const items = data.item;
  const randomIndex = Math.floor(Math.random() * items.length);
  const randomNote = noteMap[items[randomIndex].toLowerCase()];
  if (randomNote) {
    nowType.value = randomNote;
    allPlay.value.push(randomNote);
    synth.triggerAttackRelease(randomNote, '1n');
    const target = getNoteByKeyCode(randomNote);

  }
}


const getNoteByKeyCode = (keyName) => {
  let target;
  let whiteNotes = Notes.value.white;
  let blackNotes = Notes.value.black;

  for (let i = 0; i < whiteNotes.length; i++) {
    if (whiteNotes[i].name == keyName) {
      target = whiteNotes[i];
      break;
    }
  }

  if (!target) {
    for (let i = 0; i < blackNotes.length; i++) {
      if (blackNotes[i].name == keyName) {
        target = blackNotes[i];
        break;
      }
    }
  }
  return target;
}

// 绘制波形图
const init_draw = () => {
  // 创建一个画布
  var ctx = uni.createCanvasContext('firstCanvas');

  // 获取画布宽高值
  const query = uni.createSelectorQuery();
  let width = "";
  let height = "";
  query.select('#firstCanvas').fields({ size: true }, (res) => {
    width = res.width;
    height = res.height;
  }).exec();

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
      const y = (waveformValues[i] + 0.5) * height - 80;

      ctx.fillRect(x, height * 0.5, 4, y);
      ctx.fillRect(x, height * 0.5, 4, -y);
    }

    ctx.lineWidth = 2;
    ctx.stroke();
    ctx.draw(); // 绘制到画布上
  }
  drawWaveform();
}



</script>

<style lang="scss" scoped>
	.change{
		position: absolute;
		right: 10px;
		display: flex;
		justify-content: center;
		align-items: center;
		font-size: 14px;
		.van-switch{
			margin-left: 10px;
		}
	}
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
					color: #6b6b6b;
					width: 50px;
					height: 50px;
					line-height: 44px;
					text-align: center;
					border-radius: 6px;
					background: #f6f7fb;
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
				margin-top: 30px;
				display: flex;
				justify-content: center;
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
				.reload{
					background: #e0f8f1;
					color:#00c9a4;
					margin-right: 20px;
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
