<template>
  <!-- 钢琴组件 -->
  <view class="piano" :class="{ 'expand': is_expand }">

	<!-- 音频可视化 -->
	<canvas ref="visualizer" class="audio-visualizer" canvas-id="firstCanvas" id="firstCanvas"></canvas>
	<!-- 按扭区 -->
	<view class="btn_box">
		<van-icon class="btn_all" :name="is_expand?'/static/assets/expand_c.png':'expand-o'" @click="expand()"/>
	</view>
    <!-- 钢琴键盘 -->
	<view class="piano_box">
	<!-- 钢琴组件 -->
	<view class="piano2">
		<!-- 键盘拖动条 -->
		<view class="tdt">
			<button class="btnl" @click="delWidth()"></button>
			<!-- 滑块控制 -->
			<movable-area class="scroll" id="scroll1">
				<movable-view class="scroll_btn" :style="{width: `${allWidth}%`,backgroundSize:`${btn_width}px`,backgroundPositionX:`-${btn_left}px`}"  @change="onChange" direction="horizontal"></movable-view>
			</movable-area>
			<button class="btnr" @click="adjustWidth()"></button>
		</view>
	  <!-- 钢琴键盘 -->
	  <view class="piano-key-wrap">
			<!-- 显示隐藏 -->
			<van-icon class="eye" :name="isShow?'/static/assets/eye_close.jpg':'/static/assets/eye_open.jpg'" @click="showChange()"/>
			<!-- 钢琴白键 -->
	    <view :style="{'white-space': 'nowrap','transform': `translateX(-${left}%)`,'top': '-10px','position':'relative'}">
			  <view class="piano-key wkey"
			       v-for="(note, index) in Notes.white"
			       :key="note.keyCode"
			       :data-keyCode="note.keyCode"
			       :data-name="note.name"
			       :class="{ 'active': isKeyPressed(note.keyCode) }"
			       :style="{ width: `${keyWidth}%` }"
			       @mousedown.stop="clickPianoKey($event, note.keyCode)">
				   <view class="notename" v-show="isShow">
				   				{{note.text}}
				   		<view class="dian" v-if="note.a && note.a == '..'"><view class="a1">.</view><view class="a2">.</view></view>
						<view class="dian" v-if="note.a && note.a == '.'"><view class="a1">.</view></view>
						<view class="dian" v-if="note.a && note.a == '1.'"><view class="a3">.</view></view>
						<view class="dian" v-if="note.a && note.a == '1..'"><view class="a3">.</view><view class="a4">.</view></view>
						<view class="dian" v-if="note.a && note.a == '1...'"><view class="a3">.</view><view class="a4">.</view><view class="a5">.</view></view>
				   </view>
					<view class="notenameBox" v-show="isShow">
						<view class="notename2"  :style="{
						  background: bgComputed(index, note.red),
						  color: note.red ? '#fff' : ''
						}">
						{{note.name2}}
										<view class="c"  :style="{
						  color: note.red ? '#fff' : ''
						}">{{note.name3}}</view>
					</view>
	
					</view>
			  </view> 
		  </view>
		   <!-- 钢琴黑键 -->
		   <view class="piano_b" :style="{'white-space': 'nowrap','transform': `translateX(-${left}%)`}">
		   		  <view class="piano-key-black wkey"
		   		       v-for="(note,index) in Notes.black"
		   		       :key="note.keyCode"
		   		       :data-keyCode="note.keyCode"
		   		       :data-name="note.name"
					   :class="{ 'active': isKeyPressed(note.keyCode) }"
		   		       :style="{ width: `${keyWidth*0.7}%`,marginLeft: `${getMarginLeft(index)}%`}"
					   @mousedown.stop="clickPianoKey($event, note.keyCode)"
						>
		   		    <view class="keytip">
		   		      
		   		    </view>
		   		  </view> 
		   </view>
	  </view>
	</view>
	</view>

  </view>
</template>

<script setup>
import { useStore } from 'vuex'
import { ref, onMounted, onBeforeUnmount, computed ,nextTick } from 'vue'
import NotesData from '/pages/common/config/notes'
import SampleLibrary from '/pages/common/lib/Tonejs-Instruments.js'
import VirtualPiano from '/pages/common/piano.vue';
import * as Tone from 'tone';

const store = useStore()
const Notes = ref(NotesData)

const synth =  SampleLibrary.load({
    instruments: "piano"
}).toMaster();

onBeforeUnmount(() => {
    store.commit('adjustWidth')
	store.commit('delWidth')
});

const keyWidth = computed(() => store.state.keyWidth)
const keyPressed = ref([]);
const btn_width =ref(858);

const keyUp = (keyCode) => {
    keyPressed.value[keyCode] = false;
};
 
const isKeyPressed = (keyCode) => {
	return keyPressed.value[keyCode] || false;
};

const adjustWidth = () => {
  store.commit('adjustWidth');
  
  left.value = 0;
  //计算实际宽度
  const width = Notes.value.white.length/1 * keyWidth.value/1;
  allWidth.value = 100 /width*100;
};

const delWidth = () => {
  store.commit('delWidth');
    left.value = 0;
  //计算实际宽度
  const width = Notes.value.white.length/1 * keyWidth.value/1;
  allWidth.value = 100 /width*100;
};

const allWidth = ref(100);

//白键位置计算
const bgComputed = (index,red) =>{
	if(red){
		return '#6f53ed'
	}else{
			if(index < 7){
				return "#ccccd6"
			}else if( index < 14 && index >= 7){
				return '#93b5cf'
			}else if( index < 21 && index >= 14){
				return '#a4cab6'
			}else if( index < 28 && index >= 21){
				return '#fbb957'
			}else if( index < 35 && index >= 28){
				return '#ee8055'
			} 
		}
		
	}
	
	// 黑键位置计算
	const getMarginLeft = (index) => {
      const baseMargin = 0; // 基础的 margin 值
      const n = Math.floor(index / 5); // 第几组黑键
      const remainder = index % 5; // 当前组内的位置

      if (remainder === 0) {
        return index>4?keyWidth.value*1.3:keyWidth.value*(1 - 0.35); 
      } else if (remainder === 1 || remainder === 3 || remainder === 4) {
        return keyWidth.value*0.3; 
      } else if (remainder === 2) {
        return keyWidth.value*1.3; 
      }
	  // 其他情况默认返回 0
	  return 0;
    }
	
   // 鼠标操作，点击按键播放
    const clickPianoKey = (e, keyCode) => {
	    keyPressed.value = { ...keyPressed.value, [keyCode]: true }; // Spread existing object and update key
	  
	    let pressedNote = getNoteByKeyCode(keyCode);
	    if (pressedNote) {
	      playNote(pressedNote.name);
	    }
		
		    setTimeout(() => {
		      keyPressed.value = { ...keyPressed.value, [keyCode]: false }; // Reset key to false after 2 seconds
		    }, 300); // 2 seconds
    }
	
	const getNoteByKeyCode = (keyCode) => {
	  let target;
	  let whiteNotes = Notes.value.white;
	  let blackNotes = Notes.value.black;
	
	  for (let i = 0; i < whiteNotes.length; i++) {
	    if (whiteNotes[i].keyCode == keyCode) {
	      target = whiteNotes[i];
	      break;
	    }
	  }
	
	  if (!target) {
	    for (let i = 0; i < blackNotes.length; i++) {
	      if (blackNotes[i].keyCode == keyCode) {
	        target = blackNotes[i];
	        break;
	      }
	    }
	  }
	  return target;
	}

	
	// 触发单个音符播放
	const playNote = (notename = 'C4', duration = '1n')=> {
		console.log(notename,duration)
	  try {
	    synth.triggerAttackRelease(notename, duration);
	  } catch (e) {}
	}
	
const left = ref(0);
const btn_left = ref(0);
const onChange = (event) => {
    const scrollPosition = event.detail.x;  
	btn_left.value = scrollPosition;
	let w = 0;
	const query = uni.createSelectorQuery().in(this);
	                query.select('#scroll1').boundingClientRect(data => {
	                  w = data.width;
					  btn_width.value = w;
	}).exec();
	left.value = (scrollPosition/w * (Notes.value.white.length/1 * keyWidth.value/1));

};


// 创建一个音频分析器
const analyser = new Tone.Analyser('fft', 128);
// const analyser = new Tone.Waveform(128);
synth.connect(analyser);
analyser.toDestination();

const is_expand = ref(false)

onMounted(() => {
	init_draw()  //绘画初始化
})
var canvasContext;
const init_draw = () =>{
	// 创建一个画布
	canvasContext = uni.createCanvasContext('firstCanvas');
	
	// 获取画布宽高值
	const query = uni.createSelectorQuery();
	let ctx_w = "";
	let ctx_h = "";
	query.select('#firstCanvas').fields({size:true},(res)=>{
		ctx_w = res.width;
		ctx_h = res.height - 2; //减去帽头高度
	}).exec()
	
	// 频谱条设置
	const meterWidth = 10; //宽度
	const gap = 2; //频谱条间距
	const capHeight = 2;//帽头高度
	const capStyle = '#fff';//帽头颜色
	const meterNum = ctx_w /(meterWidth + gap); //计算频谱条数量
	
	let capYPositionArray = [];//帽头位置数组
	
	const gradient = canvasContext.createCircularGradient(0,0,0,300);
	gradient.addColorStop(1,'#44bbcc'); //颜色
	
function draw() {
    requestAnimationFrame(draw);

    //绘制音频柱状图
    const values = analyser.getValue();

    canvasContext.clearRect(0, 0, ctx_w, ctx_h); // 清除画布

    let barWidth = (ctx_w / values.length) * 2.5;
    let barHeight;
    let x = 0;
    const spacing = 3; // 柱状图间距
    const defaultHeight = 2; // 默认柱状图高度
    for (let i = 0; i < values.length; i++) {
        barHeight = (values[i] + 140) * 4 || defaultHeight; // 应用默认高度
        let colorValue = 210 + Math.floor(Math.random() * 5);
        canvasContext.beginPath();

        const cornerRadius =10; // 圆角半径
        const x0 = x + spacing / 2; // 添加间距的偏移量
		let y0;
		if(is_expand.value){
			y0 = ctx_h - barHeight / 2 + 120;
		}else{
			y0 = ctx_h - barHeight / 2;
		}

        canvasContext.moveTo(x0, y0);
        canvasContext.lineTo(x0, y0 + cornerRadius);
        canvasContext.arcTo(x0, y0, x0 + cornerRadius, y0, cornerRadius);
        canvasContext.lineTo(x0 + barWidth - cornerRadius, y0);
        canvasContext.arcTo(x0 + barWidth, y0, x0 + barWidth, y0 + cornerRadius, cornerRadius);
        canvasContext.lineTo(x0 + barWidth, y0 + barHeight / 2);
        canvasContext.lineTo(x0, y0 + barHeight / 2);

        canvasContext.fillStyle = 'rgb(44,' + colorValue + ',161)';
        canvasContext.fill();
        canvasContext.closePath();
        x += barWidth + spacing;
    }
    canvasContext.draw(); // 绘制到画布上
}

	draw();
}


const isShow = ref(false);
const showChange = () =>{
	isShow.value = !isShow.value;
	
}

//全屏化

const expand = () => {
  is_expand.value = !is_expand.value;
};
	

</script>

<style scoped>
.piano.expand{
	transition: opacity 3s;
	position: fixed;
	width: 100%;
	height: 100%;
	top: 0;
	left: 0;
	background: #fff;
	.piano-key-wrap{
		bottom: 0;
	}
	.tdt{
		bottom: 252px !important;
	}
	.btn_box{
		bottom: 302px;
	}
	.piano-key-wrap{
		bottom: 0px !important;
		height: 252px !important;
	}
	.piano-key{
		height: 256px !important;
	}
}	
.piano {
  width: 100%;
  height: 100%;
  position: relative;
  .audio-visualizer {
    width: 100%;
    height: calc(100% - 285px);;
  }
  .piano_box{
	  position: absolute;
	  bottom: 0;
	  width: 100%;
	  ::v-deep .piano-key{
		  height: 197px;
	  }
  }
  .btn_box{
	position: absolute;
	width: 100%;
	bottom: 246px;
	background: #e1e3f7;
	height: 38px;
	.btn_all{
		position: absolute;
		top: 5px;
		font-size: 28px;
		right: 10px;
	}
  }

.piano2 {
  width: 100%;
  height: 100%;
  position: relative;
  .audio-visualizer {
    width: 100%;
    height: calc(100% - 350px);;
  }
  .btn_box{
	position: absolute;
	width: 100%;
	bottom: 312px;
	background: #e1e3f7;
	height: 38px;
	.btn_all{
		position: absolute;
		top: 5px;
		font-size: 28px;
		right: 10px;
	}
  }
  .tdt{
	position: absolute;
	width: 100%;
	bottom: 196px;
	background: linear-gradient(-20deg, #333, #171a20, #333);
	height: 50px;
	button{
		background-repeat: no-repeat;
		background-color: rgba(255, 255, 255, .1);
		border-radius: 50%;
		background-position: center;
		background-size: 20px;
		top: 6px;
	}
	.btnl{
		height: 36px;
		width: 36px;
		position: absolute;
		left: 10px;
		background-image: url(/static/assets/del.png);
		background-repeat: no-repeat;
	}
	.btnr{
		height: 36px;
		width: 36px;
		position: absolute;
		right: 10px;
		background-image: url(/static/assets/add.png);
		background-repeat: no-repeat;
	}
	.scroll{
		    width: calc(100% - 120px);
		    height: 34px;
		    margin-top: 8px;
		    margin-left: 60px;
		    background: url(/static/assets/piano_bg1.jpg);
		    border-radius: 7px;
			position: relative;
			overflow: hidden;
			background-size: cover;
		.scroll_btn{
				position: absolute;
			    height: 100%;
			    width: 80%;
			    background: url(/static/assets/piano_bg.jpg);
			    border: 1px solid #6f52ed;
		}	
	}
  }
  .piano-key-wrap{
	  position: absolute;
	  bottom: 4px;
	  height: 192px;
	  width: 100%;
	  overflow-x: auto;
	  overflow-y: hidden;
	  .eye{
			position: absolute;
            right: 5px;
            top: 10px;
            z-index: 10;
            font-size: 26px;
	  }
	  .piano-key {
	  	width: 2.775%;
	    padding-bottom: 20%;
		display: inline-block;
		position: relative;
		height: 196px;
	    margin: 0;
	    background: #fff;
	    background: linear-gradient(-30deg, #f5f5f5, #fff);
	    border: 1px solid #ccc;
	    box-shadow: inset 0 1px 0 #fff, inset 0 -1px 0 #fff, inset 1px 0 0 #fff, inset -1px 0 0 #fff, 0 4px 3px rgba(0,0,0,.7);
	    border-radius: 0 0 5px 5px;
		.notename{
			position: absolute;
			bottom: 10%;
			width: 100%;
			text-align: center;
			.dian{
				position: absolute;
				height: 10px;
				width: 100%;
				.a1{
					position: absolute;
					width: 100%;
					height: 5px;
					top: -14px;
				}
				.a2{
					height: 5px;
					position: absolute;
					width: 100%;
					top: -10px;
				}
				.a3{
					height: 5px;
					position: absolute;
					width: 100%;
					top: -34px;
				}
				.a4{
					height: 5px;
					position: absolute;
					width: 100%;
					top: -39px;
				}
				.a5{
					height: 5px;
					position: absolute;
					width: 100%;
					top: -46px;
				}
			}
			
		}
		.notenameBox{
			display: flex;
			justify-content: center;
			bottom: 40%;
			position: absolute;
			width: 100%;
		}
		.notename2{
			height: 18px;
			position: absolute;
			text-align: center;
			background: #ccccd6;
			border-radius: 2px;
			font-size: 14px;
			aspect-ratio: 1;
			display: flex;
			justify-content: center;
			align-items: center;
			z-index: 9;
			.c{
				position: relative;
				top: -3px;
				right: 0px;
				font-size: 10px;
				float: left;
			}
		}
	  }
	  .piano-key.active{
	  	box-shadow: 0 2px 2px rgba(0,0,0,.4);
	  	height: 186px;
	  	background: #efefef;
	  }
  }


  .piano_b{
	white-space: nowrap;  
	position: absolute;
	top: 0;
	height: 52%;
	width: 100%;
	.piano-key-black{
		    height: 100%;
		    background: linear-gradient(-20deg, #333, #171a20, #333);
		    border-color: #666 #222 #111 #555;
		    border-style: solid;
		    border-width: 1px 2px 7px;
		    border-radius: 0 0 2px 2px;
		    box-shadow: inset 0 -1px 2px hsla(0,0%,100%,.4), 0 2px 3px rgba(0,0,0,.4);
		    overflow: hidden;
			display: inline-block;
	}
	.piano-key-black.active{
				border-bottom-width: 2px;
				box-shadow: inset 0 -1px 1px hsla(0,0%,100%,.4), 0 1px 0 rgba(0,0,0,.8), 0 2px 2px rgba(0,0,0,.4), 0 -1px 0 #171a20;
			}
  }
}




.piano-key.white {
  background-color: white;
}

.piano-key.black {
  background-color: black;
  color: white;
}

/* 滚动条的整体样式 */
/* 隐藏默认滚动条 */
::-webkit-scrollbar {
  display: none;
}


  

}




.piano-key.white {
  background-color: white;
}

.piano-key.black {
  background-color: black;
  color: white;
}

/* 滚动条的整体样式 */
/* 隐藏默认滚动条 */
::-webkit-scrollbar {
  display: none;
}



</style>
