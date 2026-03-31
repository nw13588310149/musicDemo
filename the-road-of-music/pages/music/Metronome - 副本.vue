<template>
  <view class="virtual-metronome">
    <!-- 节拍器的内容 -->
	<view class="top">
		<van-icon class="top-left" name="/static/assets/jpq_icon.jpg" />
		<view class="top-center">
			<view class="tap" v-for="value in centerArr" :key="value" :class="{ 'highlight': value-1 === activeTap }"></view>
		</view>
		<van-icon @click="toggleMetronome" class="top-right" :name="isRunning?'/static/assets/jpg_stop1.jpg':'/static/assets/jpq_play.jpg'" />
	</view>
	<!-- 音色选择 -->
	<view>
		<view class="title"><view class="i"></view>音色选择</view>
		<van-grid :gutter="30" :column-num="4" :border='false' class="ys_change">
		    <van-grid-item v-for="value in 3" :class="activeYs === value ? 'active' : ''" :key="value" @click="change_ys(value)">
		      <view class="item-top">
				  {{value===3?'人声':'音色'+value}}
			  </view>
		    </van-grid-item>
		</van-grid>
	</view>
	<!-- 节拍选择 -->
	<view>
		<view class="title"><view class="i"></view>节拍选择</view>
		<van-grid :gutter="30" :column-num="4" :border='false' class="ys_change">
		    <van-grid-item v-for="(item , value) in jpArr" :class="activeTab === value ? 'active' : ''" :key="value" @click="selectTab(item,value)">
		      <view class="item-top">
				  {{item.num}}/{{item.all}}
			  </view>
		    </van-grid-item>
		</van-grid>
	</view>
	
	<!-- 滑块控制 -->
	<view class="slider">
		<view class="num">{{value}}</view>
		<van-icon class="btnl" name="/static/assets/jp_del.png" @click="change_value(-1)"/>
		<van-slider v-model="value" @change="onChange" :min="15" :max="300"/>
		<van-icon class="btnr" name="/static/assets/jp_add.png" @click="change_value(1)"/>
	</view>

  </view>
</template>

<script setup>
import { ref, watch, onUnmounted ,computed ,onMounted} from 'vue';
import * as Tone from 'tone';

const isRunning = ref(false); // 节拍器运行状态
const activeYs = ref(1); //选中音色
let player1;
let player2;
let player31;
let player32;
let player33;
let player34;
let player35;
let player36;
let player37;
let player38;
let player39;
let player310;
let player311;
let player312;

let players;

let player3;
let player4;
let player5;

onMounted(() => {
    // 创建音频播放器
    player1 = new Tone.Player("/static/samples/audio/beat0/audio1.mp3").toDestination();
    player2 = new Tone.Player("/static/samples/audio/beat0/audio2.mp3").toDestination();
    
	player3 = new Tone.Player("/static/samples/audio/beat2/3.mp3").toDestination();
	player4 = new Tone.Player("/static/samples/audio/beat2/2.mp3").toDestination();
	player5 = new Tone.Player("/static/samples/audio/beat2/4.mp3").toDestination();
	// 人声音频
    player31 = new Tone.Player("/static/samples/audio/beat3/1.mp3").toDestination();
	player32 = new Tone.Player("/static/samples/audio/beat3/2.mp3").toDestination();
	player33 = new Tone.Player("/static/samples/audio/beat3/3.mp3").toDestination();
	player34 = new Tone.Player("/static/samples/audio/beat3/4.mp3").toDestination();
	player35 = new Tone.Player("/static/samples/audio/beat3/5.mp3").toDestination();
	player36 = new Tone.Player("/static/samples/audio/beat3/6.mp3").toDestination();
	player37 = new Tone.Player("/static/samples/audio/beat3/7.mp3").toDestination();
	player38 = new Tone.Player("/static/samples/audio/beat3/8.mp3").toDestination();
	player39 = new Tone.Player("/static/samples/audio/beat3/9.mp3").toDestination();
	player310 = new Tone.Player("/static/samples/audio/beat3/10.mp3").toDestination();
	player311 = new Tone.Player("/static/samples/audio/beat3/11.mp3").toDestination();
	player312 = new Tone.Player("/static/samples/audio/beat3/12.mp3").toDestination();
	
	players = {
		player31,
		player32,
		player33,
		player34,
		player35,
		player36,
		player37,
		player38,
		player39,
		player310,
		player311,
		player312
	}
	
	// 确保音频文件预加载
	player1.autostart = false;
	player2.autostart = false;
	player31.autostart = false;
	player32.autostart = false;
	player33.autostart = false;
	player34.autostart = false;
	player35.autostart = false;
	player36.autostart = false;
	player37.autostart = false;
	player38.autostart = false;
	player39.autostart = false;
	player310.autostart = false;
	player311.autostart = false;
	player312.autostart = false;
	
	
	player1.load();
	player2.load();
	player31.load();
	player32.load();
	player33.load();
	player34.load();
	player35.load();
	player36.load();
	player37.load();
	player38.load();
	player39.load();
	player310.load();
	player311.load();
	player312.load();
});



// 节拍列表
const jpArr = ref([
	{num:1,all:4},
	{num:5,all:4},
	{num:12,all:8},
	{num:2,all:4},
	{num:3,all:8},
	{num:2,all:2},
	{num:3,all:4},
	{num:6,all:8},
	{num:3,all:2},
	{num:4,all:4},
	{num:9,all:8},
	{num:4,all:2}
])

const value = ref(42);
const activeTab = ref(0);
const centerArr = ref(1);
const activeTap = ref(0); //当前高亮Tap索引

// 节拍时间计算
let beatTime = computed(() => 60000 / value.value);
let timeoutId = ref(null);

// 音色切换
function change_ys(i){
	activeYs.value = i;
}
	
// 监听 BPM 变化并重新启动节拍器
watch(value, (newValue, oldValue) => {
    if (timeoutId.value) {
        clearTimeout(timeoutId.value);  // 停止当前计时器
    }
    scheduleTick();  // 重新启动节拍器
}, { immediate: true });

// 组件卸载时清除计时器
onUnmounted(() => {
    if (timeoutId.value) {
        clearTimeout(timeoutId.value);
    }
}); 

//手动改变速率
function change_value(i){
	value.value += i
}

// 速率控制
const onChange = (value) => {
	
};

function startMetronome() {
    if (!isRunning.value) {
        isRunning.value = true;
        scheduleTick(); // 启动节拍器
    }
}

function stopMetronome() {
    if (isRunning.value) {
        clearTimeout(timeoutId.value); // 停止当前的计时器
        isRunning.value = false;
		activeTap.value = -1;
    }
}


// 节拍选择
function selectTab(item,value) {
  activeTab.value = value;
  centerArr.value = item.num;
}

//节拍启停
function toggleMetronome() {
    if (isRunning.value) {
        stopMetronome();
    } else {
        startMetronome();
    }
}

//节拍播放
function scheduleTick() {
    const startTime = performance.now();
	let tickCount = 0;  // 节拍计数器

    function tick() {
       if (!isRunning.value) {
            return; // 如果节拍器不再运行，停止进一步的tick
        }		
        let currentTime = performance.now();
        let elapsed = currentTime - startTime;
        let nextTick = beatTime.value - (elapsed % beatTime.value);
        timeoutId.value = setTimeout(() => {
            // 更新高亮的tap
            activeTap.value = tickCount  % centerArr.value;
			
			console.log(activeYs.value)
			//节拍音频播放
			if(activeYs.value === 3){
				let name = 'player3' + (activeTap.value / 1 + 1);
				if (name in players) {
				    players[name].start();
				}
			}else if(activeYs.value === 2){
				if (activeTap.value == 0) {
					//人声处理
				    player4.start();
				} else {
					if(activeTab.value ==7){
						if(activeTap.value == 3){
							player5.start();
						}else{
							player3.start();
						}
					}else if(activeTab.value ==9){
						if(activeTap.value == 2){
							player5.start();
						}else{
							player3.start();
						}
					}else{
						player3.start();
					}
				}	
			}else{
				if (activeTap.value == 0) {
					//人声处理
				    player1.start();
				} else {
				    player2.start();
				}	
			}

			tickCount++;
            tick(); // 重新调度下一次Tick
        }, nextTick);
    }

    tick();
}
// 监听 BPM 变化并重新启动节拍器
watch(value, (newValue, oldValue) => {
    if (timeoutId.value) {
        clearTimeout(timeoutId.value);  // 停止当前计时器
    }
    scheduleTick();  // 重新启动节拍器
}, { immediate: true });

// 组件卸载时清除计时器
onUnmounted(() => {
    if (timeoutId.value) {
        clearTimeout(timeoutId.value);
    }
});

</script>

<style scoped>
.virtual-metronome{
  padding: 20px;
  position: relative;
  .top{
	  height: 94px;
	  border-radius: 14px;
	  background: #f6f7fb;
	  position: relative;
	  display: flex;
	  align-items: flex-end;
	  background: url(/static/assets/jpq_bg.jpg) no-repeat;
	  background-size: cover;
	  .top-left{
		font-size: 65px;
		position: absolute;
		left: 55px;
		top: 15px;
	  }
	  .top-right{
		position: absolute;
		font-size: 66px;
		right:55px;
		top: 14px;
	  }	  
	  .top-center{
		display: flex;
		justify-content: center;
		align-items: center;
		width: 100%;
		margin-bottom: 16px;
		.tap{
			    width: 18px;
			    height: 18px;
			    background: #111;
			    border-radius: 50%;
				margin-right: 10px;
		}
		.highlight {
		    background: #00c9a4;  /* 主题色高亮 */
		}
	  }
  }
  .title{
    color: #2e3345;
    font-weight: 400;
    letter-spacing: 1px;
    font-size: 17px;
    display: block;
    letter-spacing: 1px;
    margin-top: 36px;
	font-weight: 500;
  	.i{
  	display: inline-block;
  	width: 4px;
  	height: 16px;
  	background: #00c9a4;
  	border-radius: 9px;
  	margin-left: 4px;
  	position: relative;
  	top: 2px;
  	margin-right: 6px;
	
      }
  } 
  .ys_change{
	  margin-top: 18px;
	  width: 86%;
	  padding-left: 0 !important;
	  ::v-deep .van-grid-item__content{
		    background: #f6f7fb;
		    border-radius: 9px;
		    padding: 12px;
		    font-size: 18px;
		    letter-spacing: 2px;
	  }
	  .active::v-deep .van-grid-item__content{
		  background: #111;
		  .item-top{
			color: #fff;  
		  } 
	  }
  }
  .slider{
	position: absolute;
    bottom: 20px;
    width: calc(100% - 40px);
    background: #111;
    height: 50px;
    border-radius: 50px;
	.btnl{
		height: 38px;
		width: 38px;
		position: absolute;
		left: 8px;
		background: #fff;
		color: #00c9a4;
		border-radius: 50%;
		font-size: 38px;
		font-weight: 400;
		top: 6px;
	}
	.btnr{
		height: 38px;
		width: 38px;
		position: absolute;
		right: 8px;
		background: #fff;
		color: #00c9a4;
		border-radius: 50%;
		font-size: 38px;
		font-weight: 400;
		top: 6px;
	}
	.van-slider{
		width: calc(100% - 130px);
		    background: #3b3b3b;
		    border-radius: var(--van-radius-max);
		    cursor: pointer;
		    position: absolute;
		    left: 64px;
		    top: 20px;
		    height: 10px;
			
	}
	.van-slider::v-deep .van-slider__bar{
			background: #00c9a4;
	}
	.num{
		    position: absolute;
		    top: -40px;
		    width: 60px;
		    height: 26px;
		    line-height: 26px;
		    text-align: center;
		    background: #fcf3ef;
		    border-radius: 50px;
		    left: calc(50% - 30px);
		    font-size: 18px;
		    letter-spacing: 2px;
	}
  }
}

</style>
