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
      <van-slider v-model="value" @change="onChange" @drag-start="handleDragStart" @drag-end="handleDragEnd" :min="15" :max="300"/>
      <van-icon class="btnr" name="/static/assets/jp_add.png" @click="change_value(1)"/>
    </view>
  </view>
</template>

<script setup>
import { ref, watch, onUnmounted, computed, onMounted } from 'vue';
import { Howl } from 'howler';

const isRunning = ref(false); // 节拍器运行状态
const activeYs = ref(1); // 选中音色
const value = ref(42);
const activeTab = ref(0);
const centerArr = ref(1);
const activeTap = ref(0); // 当前高亮Tap索引
const isSliding = ref(false); // 是否正在滑动

let timeoutId = ref(null);
let tickCount = ref(0);  // 节拍计数器
let lastTickTime = ref(0);

const urlList = {
  player1: new Howl({ src: "/static/samples/audio/beat0/audio1.mp3", autoplay: false, loop: false, volume: 1 ,html5:true}),
  player2: new Howl({ src: "/static/samples/audio/beat0/audio2.mp3", autoplay: false, loop: false, volume: 1 ,html5:true}),
  player3: new Howl({ src: "/static/samples/audio/beat2/3.mp3", autoplay: false, loop: false, volume: 1 ,html5:true}),
  player4: new Howl({ src: "/static/samples/audio/beat2/2.mp3", autoplay: false, loop: false, volume: 1 ,html5:true}),
  player5: new Howl({ src: "/static/samples/audio/beat2/4.mp3", autoplay: false, loop: false, volume: 1 ,html5:true}),
  player31: new Howl({ src: "/static/samples/audio/beat3/1.mp3", autoplay: false, loop: false, volume: 1 ,html5:true}),
  player32: new Howl({ src: "/static/samples/audio/beat3/2.mp3", autoplay: false, loop: false, volume: 1 ,html5:true}),
  player33: new Howl({ src: "/static/samples/audio/beat3/3.mp3", autoplay: false, loop: false, volume: 1 ,html5:true}),
  player34: new Howl({ src: "/static/samples/audio/beat3/4.mp3", autoplay: false, loop: false, volume: 1 ,html5:true}),
  player35: new Howl({ src: "/static/samples/audio/beat3/5.mp3", autoplay: false, loop: false, volume: 1 ,html5:true}),
  player36: new Howl({ src: "/static/samples/audio/beat3/6.mp3", autoplay: false, loop: false, volume: 1 ,html5:true}),
  player37: new Howl({ src: "/static/samples/audio/beat3/7.mp3", autoplay: false, loop: false, volume: 1 ,html5:true}),
  player38: new Howl({ src: "/static/samples/audio/beat3/8.mp3", autoplay: false, loop: false, volume: 1 ,html5:true}),
  player39: new Howl({ src: "/static/samples/audio/beat3/9.mp3", autoplay: false, loop: false, volume: 1 ,html5:true}),
  player310: new Howl({ src: "/static/samples/audio/beat3/10.mp3", autoplay: false, loop: false, volume: 1 ,html5:true}),
  player311: new Howl({ src: "/static/samples/audio/beat3/11.mp3", autoplay: false, loop: false, volume: 1 ,html5:true}),
  player312: new Howl({ src: "/static/samples/audio/beat3/12.mp3", autoplay: false, loop: false, volume: 1 ,html5:true}),
};

onMounted(() => {
  // 初始化 Howl 对象
  Object.values(urlList).forEach(howl => {
    if (!howl._state) {
      howl.load();
    }
  });
});

// 节拍列表
const jpArr = ref([
  { num: 1, all: 4 },
  { num: 5, all: 4 },
  { num: 12, all: 8 },
  { num: 2, all: 4 },
  { num: 3, all: 8 },
  { num: 2, all: 2 },
  { num: 3, all: 4 },
  { num: 6, all: 8 },
  { num: 3, all: 2 },
  { num: 4, all: 4 },
  { num: 9, all: 8 },
  { num: 4, all: 2 }
]);

// 节拍时间计算
const beatTime = computed(() => 60000 / value.value);

// 音色切换
function change_ys(i) {
  activeYs.value = i;
}

// 手动改变速率
function change_value(i) {
  value.value += i;
  if (isRunning.value && !isSliding.value) {
    stopMetronome();
    startMetronome();
  }
}

// 速率控制
const onChange = (val) => {
  value.value = val;
};

// 滑动开始时触发事件
const handleDragStart = () => {
  isSliding.value = true;
};

// 滑动结束后触发事件
const handleDragEnd = () => {
  isSliding.value = false;
  if (isRunning.value) {
    stopMetronome();
    // 手动触发一次音频播放
    try {
      urlList.player1.play(); // 或者选择适合的音频播放
    } catch (e) {}
    startMetronome();
  }
};


// 节拍选择
function selectTab(item, val) {
  activeTab.value = val;
  centerArr.value = item.num;
  tickCount.value = 0;  // 重置节拍计数器
  if (isRunning.value) {
    stopMetronome();
    startMetronome();
  }
}

// 节拍启停
function toggleMetronome() {
  if (isRunning.value) {
    stopMetronome();
  } else {
    startMetronome();
  }
}

// 节拍器启动
function startMetronome() {
  if (!isRunning.value) {
    isRunning.value = true;
    scheduleTick(); // 启动节拍器
  }
}

// 节拍器停止
function stopMetronome() {
  if (isRunning.value) {
    clearTimeout(timeoutId.value); // 停止当前的计时器
    isRunning.value = false;
    activeTap.value = -1;
  }
}

// 节拍播放
function scheduleTick() {
  const startTime = performance.now();
  tickCount.value = 0;  // 节拍计数器
  lastTickTime.value = startTime;

  function tick() {
    if (!isRunning.value) {
      return; // 如果节拍器不再运行，停止进一步的tick
    }

    const currentTime = performance.now();
    const elapsed = currentTime - lastTickTime.value;

    if (elapsed >= beatTime.value) {
      lastTickTime.value = currentTime - (elapsed % beatTime.value);
      activeTap.value = tickCount.value % centerArr.value;

      // 节拍音频播放
      if (activeYs.value === 3) {
        let name = 'player3' + (activeTap.value / 1 + 1);
        try {
          urlList[name].play();
        } catch (e) {}

      } else if (activeYs.value === 2) {
        if (activeTap.value == 0) {
          try {
            urlList.player4.play();
          } catch (e) {}
        } else {
          if (activeTab.value == 7) {
            if (activeTap.value == 3) {
              try {
                urlList.player5.play();
              } catch (e) {}
            } else {
              try {
                urlList.player3.play();
              } catch (e) {}
            }
          } else if (activeTab.value == 9) {
            if (activeTap.value == 2) {
              try {
                urlList.player5.play();
              } catch (e) {}
            } else {
              try {
                urlList.player3.play();
              } catch (e) {}
            }
          } else {
            try {
              urlList.player3.play();
            } catch (e) {}
          }
        }
      } else {
        if (activeTap.value == 0) {
          try {
            urlList.player1.play();
          } catch (e) {}
        } else {
          try {
            urlList.player2.play();
          } catch (e) {}
        }
      }

      tickCount.value++;
    }

    timeoutId.value = setTimeout(tick, 0);
  }

  tick();
}

// 监听 BPM 变化并重新启动节拍器
watch(value, (newValue, oldValue) => {
  if (isRunning.value && !isSliding.value) {
    stopMetronome();
    startMetronome();
  }
}, { immediate: true });

// 组件卸载时清除计时器
onUnmounted(() => {
  stopMetronome();
  // 清除 Howl 对象
  Object.values(urlList).forEach(howl => {
    howl.stop();
    howl.unload();
  });
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
