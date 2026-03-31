<template>
  <!-- 钢琴组件 -->
  <view class="piano" :class="{ 'expand': is_expand }">

	<!-- 音频可视化 -->
	<view style="height: calc(100% - 306px);">
		<van-image
			style="    width: 300px;
    margin: 0 auto;
    display: flex;
    position: relative;
    top: 30px;"
		    fit="contain"
		    class="img_bg"
		    src="/static/assets/music2.gif"
		/>
	</view>
	<!-- 按扭区 -->
	<view class="btn_box">
		<van-icon class="btn_all" :style="{'font-size':is_expand?'30px':'30px'}" :name="is_expand?'/static/assets/expand_c.png':'/static/assets/expand_o.png'" @click="expand()"/>
	</view>
	<!-- 钢琴组件 -->
	<view class="piano22" :class="{ 'expand': is_expand }">
		<!-- 键盘拖动条 -->
		<view class="tdt">
			<button class="btnl" @click="delWidth()"></button>
			<!-- 滑块控制 -->
			<movable-area class="scroll" id="scroll1">
				<movable-view class="scroll_btn" :x="btn_left" :style="{width: `${allWidth}%`,backgroundSize:`${btn_width}px`,backgroundPositionX:`-${btn_left}px`}"  @change="onChange" direction="horizontal"></movable-view>
			</movable-area>
			<button class="btnr" @click="adjustWidth()"></button>
		</view>
		<!-- 显示隐藏 -->
		<van-icon class="eye" :name="isShow?'/static/assets/eye_close.jpg':'/static/assets/eye_open.jpg'" @click="showChange()"/>
	  <!-- 钢琴键盘 -->
	  <view class="piano-key-wrap" @touchmove.stop.prevent="touchMoveOnKey($event)">
	
			<!-- 钢琴白键 -->
	    <view :style="{'white-space': 'nowrap','transform': `translateX(-${left}%)`,'top': '-10px','position':'relative'}" >
			  <view class="piano-key wkey"
			       v-for="(note, index) in Notes.white"
			       :key="note.keyCode"
			       :data-keyCode="note.keyCode"
			       :data-name="note.name"
			       :class="{ 'active': isKeyPressed(note.keyCode)}"
			       :style="{ width: `${keyWidth}%` }"
				        @touchstart.stop.prevent="clickPianoKey($event, note.keyCode)"
				        @touchend.stop.prevent="stopPianoKey($event, note.keyCode)"
				   >
				   <view class="topBox">
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
					   <view class="notename" v-show="isShow">
					   				{{note.text}}
					   		<view class="dian" v-if="note.a && note.a == '..'"><view class="a1">.</view><view class="a2">.</view></view>
					   					<view class="dian" v-if="note.a && note.a == '.'"><view class="a1">.</view></view>
					   					<view class="dian" v-if="note.a && note.a == '1.'"><view class="a3">.</view></view>
					   					<view class="dian" v-if="note.a && note.a == '1..'"><view class="a3">.</view><view class="a4">.</view></view>
					   					<view class="dian" v-if="note.a && note.a == '1...'"><view class="a3">.</view><view class="a4">.</view><view class="a5">.</view></view>
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
					   @touchstart.stop.prevent="clickPianoKey2($event, note.keyCode)"
					   @touchend.stop.prevent="stopPianoKey($event, note.keyCode)"
						>
		   		    <view class="keytip">
		   		      
		   		    </view>
		   		  </view> 
		   </view>
	  </view>
	</view>
  </view>
</template>

<script setup>
import { useStore } from 'vuex'
import { ref, onMounted, onBeforeUnmount, computed ,nextTick ,getCurrentInstance} from 'vue'
import NotesData from '/pages/common/config/notes'
import SampleLibrary from '/pages/common/lib/Tonejs-Instruments.js'
import VirtualPiano from '/pages/common/piano.vue';

import * as Tone from 'tone';


const store = useStore()
const Notes = ref(NotesData)

const synth =  SampleLibrary.load({
    instruments: "piano"
}).toMaster();

onMounted(() => {

});

onBeforeUnmount(() => {
    store.commit('adjustWidth')
	store.commit('delWidth')
});





// 确保音频上下文的状态
const audioContext = Tone.getContext().rawContext;

// 确保音频上下文在用户交互时被解锁
const unlockAudioContext = () => {
  if (audioContext.state === 'suspended') {
    audioContext.resume();
  }
};

// 触发单个音符播放
function playNote(note) {
	unlockAudioContext();
	 synth.triggerAttackRelease(note.name, "1n");

}


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
  
  let w = 0 ;
  const query = uni.createSelectorQuery().in(this);
  query.select('#scroll1').boundingClientRect(data => {
    w = data.width;
  }).exec();
  // jpCenter();
  btn_left.value = (100 - allWidth.value)/200 * w;
  left.value = (100 - allWidth.value)/2
};

const delWidth = () => {
  store.commit('delWidth');
    left.value = 0;
  //计算实际宽度
  const width = Notes.value.white.length/1 * keyWidth.value/1;
  allWidth.value = 100 /width*100;
  
  let w = 0 ;
  const query = uni.createSelectorQuery().in(this);
  query.select('#scroll1').boundingClientRect(data => {
    w = data.width;
  }).exec();
  // jpCenter();
  btn_left.value = (100 - allWidth.value)/200 * w;
    left.value = (100 - allWidth.value)/2 < 0?0:(100 - allWidth.value)/2;
};

const allWidth = ref(100);

//白键位置计算
const bgComputed = (index,red) =>{
	if(red){
		return '#00c9a4'
	}else{
			if(index < 7){
				return "rgba(253, 188, 210, 0.8)"
			}else if( index < 14 && index >= 7){
				return 'rgba(172, 175, 254, 0.8)'
			}else if( index < 21 && index >= 14){
				return 'rgba(254, 229, 198, 0.8)'
			}else if( index < 28 && index >= 21){
				return 'rgba(166, 255, 251, 0.8)'
			}else if( index < 35 && index >= 28){
				return 'rgba(164, 254, 190, 0.8)'
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
	
	const activeNum = ref('');
	
	//触摸移动
	const touchMoveOnKey = (event, index, keyCode) => {
		
	    // 1.获取键盘初始偏移量
	    let pianoLeft = 0;
		let sleft = 0;
	    const query = uni.createSelectorQuery().in(this);
	    query.select('.piano-key-wrap').boundingClientRect(data => {
	        pianoLeft = data.left;
			sleft = left.value/100 * data.width;
	    }).exec();
	    
	    //2.获取当前滑动偏移量
	    const touch = event.touches[0];
	    const touchX = touch.clientX + sleft;
	    const touchY = touch.clientY;
	    
	    //3.获取当前键盘宽度
	    let keyWidth = 0;
	    query.select('.piano-key').boundingClientRect(data => {
	        keyWidth = data.width;
	    }).exec();
	    
	    //4.获取当前再键盘内的偏移量
	    let leftO = touchX - pianoLeft;
	    //5.判断在第几个键
	    let numA = Math.floor(leftO/keyWidth);
	    //6.刚进入此键
		if(numA != activeNum.value){
			activeNum.value = numA;
			let item = Notes.value.white[numA];
			let isA = keyPressed.value[item.keyCode];
			if(isA === false || isA === undefined){
			    if(item){
			        let pressedNote = getNoteByKeyCode(item.keyCode);
	
			        if (pressedNote) {
			            // 更新按键状态
						keyPressed.value = { ...keyPressed.value, [item.keyCode]: true };
						for (let key in keyPressed.value) {
						  if(key != item.keyCode){
							  keyPressed.value[key] = false;
						  }
						}
			            playNote(pressedNote);
			        }
	
			    }
			}
		}
	    
	
	}
	// 触摸开始
	const touchStart = (e, keyCode) => {
	    // 记录触摸点按下的钢琴键状态
		keyPressed.value = { ...keyPressed.value, [keyCode]: true }
	    // 播放音符
	    let pressedNote = getNoteByKeyCode(keyCode);
		console.log(pressedNote)
	    if (pressedNote) {
	        playNote(pressedNote);
	    }
	};
	
	// 触摸结束
	const stopPianoKey = (e,keyCode) => {
	    // 清除相应触摸点的状态
		for (let key in keyPressed.value) {
		  keyPressed.value[key] = false;
		}
	};
	
	// 修改clickPianoKey和stopPianoKey方法调用相应的触摸处理函数
	const clickPianoKey = (e, keyCode) => {
	    touchStart(e, keyCode);
	};
	const clickPianoKey2 = (e, keyCode) => {
		e.stopPropagation(); // 阻止事件冒泡
	    touchStart(e, keyCode);
	};

	
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



const is_expand = ref(false)


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
	z-index: 99;
	.audio-visualizer{
		height: calc(100% - 343px);
	}
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
	.piano22{
		height: 266px !important;
	}
}	
.piano {
  width: 100%;
  height: 100%;
  position: relative;
  .audio-visualizer {
    width: 100%;
    height: calc(100% - 306px);;
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
	background: linear-gradient(-20deg, #333, #171a20, #333);
	height: 41px;
	.btn_all{
		position: absolute;
		top: 7px;
		font-size: 28px;
		right: 10px;
		color: #fff;
	}
  }
  .piano22 {
    width: 100%;
    height:280px;
	top: 40px;
    position: relative;
    .audio-visualizer {
      width: 100%;
      height: calc(100% - 350px);;
    }
    .tdt{
  	position: absolute;
  	width: 100%;
  	bottom: 229px;
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
		background-size: 36px;
  	}
  	.btnr{
  		height: 36px;
  		width: 36px;
  		position: absolute;
  		right: 10px;
  		background-image: url(/static/assets/add.png);
  		background-repeat: no-repeat;
		background-size: 36px;
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
  		}	
  	}
    }
    .eye{
    	position: absolute;
          right: 5px;
          bottom: 180px;
          z-index: 10;
          font-size: 26px;
    }
    .piano-key-wrap{
  	  position: absolute;
  	  bottom: 4px;
  	  height: 226px;
  	  width: 100%;
  	  overflow-x: auto;
  	  overflow-y: hidden;
  
  	  .piano-key {
  	  	width: 2.775%;
  	    padding-bottom: 20%;
  		display: inline-block;
  		position: relative;
  		height: 220px;
  	    margin: 0;
  	    background: #fff;
  	    /* background: linear-gradient(-30deg, #f5f5f5, #fff); */
  	    border: 1px solid #000;
  	    box-shadow: inset 0 1px 0 #fff, inset 0 -1px 0 #fff, inset 1px 0 0 #fff, inset -1px 0 0 #fff, 0 4px 3px rgba(0,0,0,.7);
  	    border-radius: 0 0 5px 5px;
  		.topBox{
  			position: absolute;
  			width: 100%;
  			height: 100%;
  			top: 0;
  			left: 0;
  			display: flex;
  			justify-content: flex-end;
  			flex-wrap: wrap;
  			flex-direction: column;
  		}
  		.notename{
  			width: 100%;
  			height: 32px;
  			text-align: center;
  			position: relative;
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
  					top: -38px;
  				}
  				.a4{
  					height: 5px;
  					position: absolute;
  					width: 100%;
  					top: -43px;
  				}
  				.a5{
  					height: 5px;
  					position: absolute;
  					width: 100%;
  					top: -45px;
  				}
  			}
  			
  		}
  		.notenameBox{
  			display: flex;
  			justify-content: center;
  			height: 34px;
  			width: 100%;
  			position: relative;
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
  	  	height: 220px;
  	  	background: linear-gradient(
  				to right,
  				rgba(0,0,0,.6) 0%,
  				rgba(0,0,0,0.5) 20%,
  				rgba(0,0,0,0.4) 40%,
  				rgba(0,0,0,0.4) 50%,
  				rgba(0,0,0,0.4) 60%,
  				rgba(0,0,0,0.5) 80%,
  				rgba(0,0,0,0.6) 100%	
  			);
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
  				background: linear-gradient(0deg, #696969 31%, #171a20, #000)
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



</style>
