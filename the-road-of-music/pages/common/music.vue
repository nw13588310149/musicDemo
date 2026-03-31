<template>
    <view class="play">
        <!-- 加载中 -->
        <view class="loading" v-if="loading">
            <van-icon class="black" name="/static/assets/music_p.gif" />
        </view>
        <!-- 封面图 -->
        <view class="img">
            <van-image
                fit="contain"
                class="img_bg"
                src="/static/assets/music_radio.png"
                :class="{ 'playing': isPlaying, 'rotate-animation': isAudioPlaying }"
            /> 
            <van-image
                class="music_p"
                src="/static/assets/music_p1.png"
                :class="{ 'playing': isPlaying, 'rotate-animation': isAudioPlaying }"
            />
            <van-icon class="black" name="/static/assets/music_p2.png" />
        </view>
        <!-- 音乐名称 -->
        <view class="title">
            <view class="wz" v-if="item">
                <van-notice-bar class="text" :speed="40" scrollable :text="item.title" />
            </view>
        </view>
        
        <!-- 音频可视化 -->
        <div id="waveform"></div>
        <!-- 控制按钮 -->
        <view class="btn">
            <view class="time">
                <text class="speed-tag">{{ speedNumber }}×</text>
                <view class="init">{{initNum}}</view><view style="margin: 0 2px;">/</view>{{maxNum}}
            </view>
            <van-icon class="left" name="/static/assets/play_left.jpg" @click="changeMusic(activeIndex-1)"/>
            <van-icon @click="playMusic" class="center" :name="isPlaying ? '/static/assets/play_stop.png' : '/static/assets/play_play.png'" />
            <van-icon class="right" name="/static/assets/play_right.jpg" @click="changeMusic(activeIndex+1)"/>
        </view>
        
        <!-- 音频进度条 -->
        <van-slider class="prog" v-model="num" @change="onChange" :min="0" :max="maxNum2"/>
        
        <!-- 控制按钮2 -->
        <view class="bottom_box">
            <van-icon @click="chage(-0.1)" name="/static/assets/play_del.png" />
			<view class="sjB van-icon" v-if="urlList?.length>1 && isArr">
				<van-icon :name="getsx()" @click="changeSx" style="font-size: 22px;" />
			</view>
			<view class="favB van-icon">
				<van-icon :name="item.isFavorite ? '/static/assets/fav_yes.png' : '/static/assets/fav_no.png'" style="font-size: 18px;position: relative;top: -1px;" @click="fav"/>
			</view>
            <van-icon @click='chage(0.1)' name="/static/assets/play_add.png" />
            <van-icon name="/static/assets/play_list.png" style="font-size: 20px;top: -2px;" v-if="urlList?.length>1 && isArr" @click="showRight1 = !showRight1"/>
        </view>
        
        <!-- 左侧弹出 -->
        <van-popup
            class="left_box"
            v-model:show="showRight1"
            position="left"
            :overlay="false"
            teleport="body"
            :style="{ width: '193px', height: '100%' }"
        >
            <view class="top">
                <van-icon style="font-size: 20px;" name="/static/assets/go_left.png" @click="showRight1 = false"/>
            </view>
            <view class="list">
                <view class="li" v-for="(item,value) in urlList" @click="changeMusic(value)">
                    <view class="sort">{{value + 1}}
                        <view class="dt" v-if="activeIndex == value">
                            <van-image
                                fit="contain"
                                class="img_bg"
                                src="/static/assets/music.gif"
                                :class="{ 'playing': isPlaying, 'rotate-animation': isAudioPlaying }"
                            />
                        </view>
                    </view>
                    
                    <view class="text">{{item.filename.split('.').shift()}}</view>
                </view>
            </view>
        </van-popup>
    </view>
</template>

<script setup>
import { ref, watchEffect, defineEmits, computed } from 'vue';
import WaveSurfer from 'wavesurfer.js';
import RegionsPlugin from 'wavesurfer.js/dist/plugins/regions.esm.js'
import { showToast } from 'vant';    
import {favoriteSave , textbookRecordSave} from '/api/home.js';

const props = defineProps({
  item: Object,
  all:Array
});

const showRight1 =ref(false);

const loading = ref(true);

const isPlaying = ref(false);
const isAudioPlaying = ref(false); // 控制旋转动画

let wavesurfer;
let mediaStreamDestination;

const num = ref(0);
const initNum = ref('00:00');
const maxNum = ref('00:00');
const maxNum2 = ref(0);

const sudu = ref( uni.getStorageSync('sudu') || 1);
const speedNumber = computed(() => Number(sudu.value).toFixed(1));
const urlList = ref([]);
const activeIndex = ref(0);

const isA = ref(false);
const isB = ref(false);
const isAB = ref(false);

const startA = ref(0);
const startB = ref(0);

function fav(){
    if(props.item){
        let param = {
            "favorite": !props.item.isFavorite,
            "targetId": props.item.id,
            "type": props.item.type
        }
        
        favoriteSave(param).then(res =>{
            if(res.code == 0){
                props.item.isFavorite = !props.item.isFavorite;
				if(props.item.isFavorite){
					showToast({message:'您已成功收藏',teleport:'.favB'})
				}else{
					showToast({message:'您已取消收藏',teleport:'.favB'})
				}
            }else{
                showToast(res.msg)
            }
        })
    }
}

const sxType = ref(0)
function getsx(){
    if(sxType.value == 0){
        return '/static/assets/play-sx.png'
    }else if(sxType.value == 1){
        return '/static/assets/play-xh.png'
    }else if(sxType.value == 2){
        return '/static/assets/play_sj.png'
    }
}
function changeSx(){
    if(sxType.value == 2){
        sxType.value = 0;
    }else{
        sxType.value += 1;
    }
    if(sxType.value == 0){
		showToast({message:'已切换到顺序播放',teleport:'.sjB'})
    }else if(sxType.value == 1){
		showToast({message:'已切换到单曲循环',teleport:'.sjB'})
    }else if(sxType.value == 2){
		showToast({message:'已切换到随机循环',teleport:'.sjB'})
    }
}

function clickA(){
    isA.value = !isA.value;
    let stop = true;
    if(isA.value && stop){
        wavesurfer.on('audioprocess', (playTime) => {
            if(stop){
                startA.value = playTime;
                console.log(startA.value)
                stop = false
            }
          
        });
    }else{
        startA.value = 0;
    }
}
function clickB(){
    isB.value = !isB.value;
    let stop = true;
    if(isB.value && stop){
        wavesurfer.on('audioprocess', (playTime) => {
            if(stop){
                startB.value = playTime;
                stop = false;
            }
          
        });
    }else{
        startB.value = 0;
    }
}

let wsRegions = "";
function clickAB(){

    isAB.value = !isAB.value;
    if(isAB.value){
        loop.value = true;

         wsRegions.addRegion({
              start: startA.value,
              end: startB.value,
              loop: true,
              drag: false,
              resize: false,
            })
            
            region.play()
            
            
        
    }else{
        wsRegions.clearRegions();
        loop.value = false;
    }
}

const emit = defineEmits(['change-music'])
const nowTitle = ref("");
// 音频切换
function changeMusic(num){
    // 乐理切换
    if(props?.all?.length > 0){
		// 销毁当前的 wavesurfer 实例
		if (wavesurfer) {
		    wavesurfer.destroy();
		    wavesurfer = null;
		}
        // 向父组件发送事件请求，传递要切换的音频
        let newDetail = '';
        props.all.forEach((e,i) =>{
            if(e == props.item.id){
                if(i == 0 && num == -1){
                    newDetail = props.all[props.all.length - 1]; //最后一个
                }else if(i == props.all.length - 1 && num == 1){
                    newDetail = props.all[0]; //第一个
                }else{
                    if(num == 1){
                        newDetail = props.all[i+1];
                    }else{
                        newDetail = props.all[i-1];
                    }
                }
            }
        })
        
        emit('change-music', newDetail);
    }else{
        if(urlList.value.length > 1 && isArr.value){
			// 销毁当前的 wavesurfer 实例
			if (wavesurfer) {
			    wavesurfer.destroy();
			    wavesurfer = null;
			}
            activeIndex.value = num;

            initializeWaveSurfer(urlList.value[activeIndex.value].url);
            if(!isPlaying.value){
                isPlaying.value = true
            }
            nowTitle.value = urlList.value[activeIndex.value].filename.split('.').shift()
            wavesurfer.on("ready",function(){
				wavesurfer.setPlaybackRate(sudu.value);
                wavesurfer.play();
            });
            
        }
    }
}

//倍速播放
function chage(value){
      sudu.value += value;
      if (sudu.value < 0.1) sudu.value = 0.1; // 最小速度限制
      if (sudu.value > 2) sudu.value = 2;       // 最大速度限制
      sudu.value = parseFloat(sudu.value.toFixed(1)); // 保留一位小数
      showToast({message:'当前倍速：' + sudu.value,});
      wavesurfer.setPlaybackRate(sudu.value);
	  uni.setStorageSync('sudu',sudu.value)
}

// 时间格式化函数
function formatTime(seconds) {
  const minutes = Math.floor(seconds / 60);
  const secondsLeft = Math.floor(seconds % 60);
  return `${minutes.toString().padStart(2, '0')}:${secondsLeft.toString().padStart(2, '0')}`;
}

const isArr = ref(false)

const loop = ref(true);

watchEffect(() => {
    let url = props.item.file1; // 假设默认情况下 URL 就是 file1 的值
    if (props.item.file1 && typeof props.item.file1 === 'string') {
        try {
            const parsedFile1 = JSON.parse(props.item.file1);
            if (Array.isArray(parsedFile1) && parsedFile1.length > 0) {
                url = parsedFile1;
            }
            isArr.value = true;
            urlList.value = url;
        } catch (error) {
            // 如果解析失败，仍然使用默认的 file1 值作为 URL
        }
    }
    try{
        url = JSON.parse(props.item.file1)
    }catch{
        url = url
    }
    console.log(url)
    if (url?.length == 1) {
              if (url[0]?.constructor === Array) {
                url = url[0];
              }
            }
    try{
        let a = []
        url.forEach(e =>{
            a.push(JSON.parse(e))
        })
        url = a;
    }catch{
        
    }    

    urlList.value = url;

    // 初始化 wavesurfer 实例
    setTimeout(() => {
        initializeWaveSurfer(url);
    }, 5);

});

function initializeWaveSurfer(url) {
	//销毁旧实例
	 if (wavesurfer) {
	        wavesurfer.destroy();
	        wavesurfer = null;
	    }
	
    wavesurfer = WaveSurfer.create({
        container: '#waveform',
        waveColor: '#5c5c5c',
        progressColor: '#00c9a4',
        minPxPerSec: 100,
        dragToSeek: true,
        height: 40,
        barWidth: 7,
        barRadius: 7,
        hideScrollbar: true,
		backend: 'MediaElementWebAudio'
    });
	wavesurfer.setVolume(1);
	


    // 音频格式兼容
    let newUrl = "";
    if(isArr.value){
        if(url[activeIndex.value].url){
            newUrl = url[activeIndex.value].url;
            nowTitle.value = urlList.value[activeIndex.value].filename.split('.').shift()
        }else{
			console.log(url)
            // newUrl = url[activeIndex.value]
			newUrl = url;
        }
    }else{
        newUrl = url;
    }
    try{
        newUrl = JSON.parse(newUrl).url
    }catch{
        newUrl = newUrl;
    }

	wavesurfer = wavesurfer;
    wavesurfer.load(newUrl);

    wsRegions = wavesurfer.registerPlugin(RegionsPlugin.create());
    // 订阅波形图播放事件以更新进度
    wavesurfer.on('audioprocess', (playTime) => {
        num.value = playTime;
        initNum.value = formatTime(playTime);
    });

    // 当音频播放完成时触发
    wavesurfer.on('finish', () => {
        isPlaying.value = false;
        isAudioPlaying.value = false;
        initNum.value = '00:00';
        num.value = 0;
        wavesurfer.seekTo(0); // 跳转到音频的开始位置
        
        let playN = 0;
		
        if(sxType.value == 0){
            if(activeIndex.value == urlList.value.length -1){
                playN = 0
            }else{
                playN = activeIndex.value +1;
            }
			if(props.item.type == 3){
				changeMusic(playN);
			}
        }else if(sxType.value == 1){
            playN = activeIndex.value;
			changeMusic(playN);
        }else if(sxType.value == 2){
            playN = Math.floor(Math.random() * urlList.value.length)
			changeMusic(playN);
        }
        
        //上报学习进度
        if(props.item.type == 1 || props.item.type == 3){
            textbookRecordSave({textbookId:props.item.id});
        }
        
    });

    wavesurfer.on('ready', () => {
        loading.value = false;
        maxNum2.value = wavesurfer.getDuration();
        maxNum.value = formatTime(wavesurfer.getDuration());
		
		// // 创建一个 MediaStreamDestination
		// mediaStreamDestination = wavesurfer.backend.ac.createMediaStreamDestination();
		// wavesurfer.backend.setFilter(mediaStreamDestination);
		
		// // 将生成的 MediaStream 保存到 Vuex
		// store.dispatch('updateAudioStream', mediaStreamDestination.stream);
    });
    
    wavesurfer.on('decode', () => {
        let activeRegion = null;
        wsRegions.on('region-in', (region) => {
            activeRegion = region;
        });
        wsRegions.on('region-out', (region) => {
            if (activeRegion === region) {
                if (loop.value) {
                    region.play();
                } else {
                    activeRegion = null;
                }
            }
        });
        wsRegions.on('region-clicked', (region, e) => {
            e.stopPropagation(); // prevent triggering a click on the waveform
            activeRegion = region;
            region.play();
            region.setOptions({ color: randomColor() });
        });
        // Reset the active region when the user clicks anywhere in the waveform
        wavesurfer.on('interaction', () => {
            activeRegion = null;
        });
    });
}

function playMusic() {
	wavesurfer.setPlaybackRate(sudu.value);
    wavesurfer.playPause();
    isPlaying.value = !isPlaying.value;
    isAudioPlaying.value = !isAudioPlaying.value; // 切换播放状态
}

// 用于处理滑块改变时的逻辑
function onChange(newVal) {
    wavesurfer.seekTo(newVal / maxNum2.value);
    num.value = newVal;
    initNum.value = formatTime(newVal);
}
</script>


<style lang="scss" scoped>
	.loading{
		position: absolute;
		width: 100%;
		height: 100%;
		background: rgba(255,255,255,.7);
		z-index: 999;
		display: flex;
		justify-content: center;
		align-items: center;
		border-radius: 14px;
		overflow: hidden;
		.black{
			font-size: 35px;
		}
	}
	::v-deep .van-overlay{
		background:rgba(0,0,0,.2)
	}
	.left_box{
		padding: 15px;
		.top{
			font-size: 30px;
			display: flex;
			justify-content: flex-end;
		}
		.list{
			height: calc(100% - 30px);
			padding-top: 10px;
			overflow-y: auto;
			-webkit-overflow-scrolling: touch; /* 兼容iOS滚动 */
			  scrollbar-width: none; /* Firefox */
			  -ms-overflow-style: none; /* IE/Edge */
		}
		.list::-webkit-scrollbar{
		  display: none; /* Chrome/Safari/Opera */
		}
		.li{
			display: flex;
			margin-bottom: 15px;
			justify-content: center;
			.sort{
				width: 40px;
				height: 40px;
				background: #00c9a4;
				color: #fff;
				font-size: 16px;
				border-radius: 6px;
				text-align: center;
				line-height: 40px;
				position: relative;
				.dt{
					position: absolute;
					width: 40px;
					height: 40px;
					top: 0;
					left: 0;
					background: rgba(0,0,0,.3);
					border-radius: 6px;
					display: flex;
					justify-content: center;
					align-items: center;
					.img_bg{
						width: 30px;
						height: 30px;
					}
				}
			}
			.text{
				margin-left: 10px;
				line-height: 40px;
				font-size: 14px;
			}
		}
	}
	#waveform{
		height: 40px;
		margin-top: 36px;
		display:flex;
		padding-left: 10%;
		position: relative;
		::v-deep div{
			width: 90%;
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

.play {
    width: 100%;
    background: url(/static/assets/play_bg.png) no-repeat;
    height: 100%;
    background-size: 100% 100%;
    position: absolute;
	border-radius: 14px;
	box-shadow: 0 0 6px #6b6b6b24;
    .img {
           background: url(/static/assets/music_bg.png) no-repeat;
           background-size: 100%;
           height: 160px;
           width: 160px;
			margin: 0 auto;
			margin-top: 28px;
			padding: 15px;
			position: relative;
			.music_p{
				position: absolute;
				right: 18px;
				top: 17px;
				width: 57px;
				transform-origin: top right;
				transform: rotate(-18deg);
				transition: transform 1s; /* 添加过渡属性 */
				&.playing {
				    transform: rotate(7deg);
				}
			}
			.black{
				position: absolute;
				right: 14px;
				top: 14px;
				z-index:10;
			}
        .img_bg {
            width: 100%;
			height: 100%;
            height: auto !important;
            overflow: hidden;
            aspect-ratio: 1;
            animation: rotate 5s linear infinite; 
			&.playing.rotate-animation {
			    animation-play-state: running;
			}
			&:not(.playing) {
			    animation-play-state: paused;
			}
        }
    }
    .title {
        display: flex;
        justify-content: center;
		margin-top: 11px;
        .wz {
            width: 129px;
			height: 18px;
			line-height: 18px;
            background: #ededed;
            font-size: 10px;
            border-radius: 12px;
            color: #000;
			.text{
				height: 18px;
				background: none;
				font-size: 11px;
				
			}
        }
    }
	.set{
		display: flex;
		justify-content: flex-end;
		padding-right: 26px;
		position: relative;
		top: 15px;
		.a,.b,.ab{
			padding: 0 6px;
			height: 14px;
			background: #D9D9D9;
			color: #000;
			font-size: 10px;
			margin-left: 8px;
			text-align: center;
			line-height: 14px;
			border-radius: 3px;
		}
		.active{
			background: #00c9a4;
			color: #fff;
		}
	}
    .btn {
        display: flex;
        justify-content: center;
        font-size: 14px;
        position: absolute;
        width: 100%;
        bottom: 19%;
        align-items: center;
		.time{
			position: absolute;
			top: 58px;
			width: 100%;
			display: flex;
			justify-content: flex-end;
			padding: 0 20px;
			align-items: center;
			font-size: 9px;
			color: #4e4f50;
			.speed-tag {
				position: absolute;
				left: 20px;
				font-size: 10px;
				font-weight: 700;
				color: #00c9a4;
				letter-spacing: 0.02em;
				font-variant-numeric: tabular-nums;
			}
			.init{
				color:#00c9a4;
				font-size: 10px;
			}
		}
		.left,.right{
			font-size: 20px;
		}
        .center {
            margin: 0 28px;
            font-size: 50px;
        }
    }
	.bottom_box{
		position: absolute;
		bottom: 11px;
		width: 100%;
		display: flex;
		justify-content: center;
		align-items: center;
		height: 30px;
		::v-deep .van-toast{
			position: absolute;
			top: -30px;
			left: 0;
			white-space: nowrap;
			overflow: visible;
			background: #23BF95 !important;
		}
		::v-deep .van-toast::before{
			position: absolute;
			bottom:-7px;
			left: 15px;
			content: '';
			border-radius: 12px;
			  border-left: 10px solid transparent; /* 左边框透明 */
			  border-right: 10px solid transparent; /* 右边框透明 */
			  border-top: 12px solid #23BF95; /* 上边框实心 */
		}
		.sjB{
			::v-deep .van-toast{
				width: 120px;
				max-width: 120px;
			}
		}
		.van-icon{
			display: flex;
			width: 25%;
			justify-content: center;
			align-items: center;
			font-size: 22px;
		}
	}
	.prog{
		position: absolute;
		bottom: 59px;
		width: 84%;
		left: 8%;
		background: #b3b3b3;
		::v-deep .van-slider__bar{
			background: #00c9a4;
		}
		::v-deep .van-slider__button{
			background: #00c9a4;
			width: 6px;
			height: 6px;
			position: relative;
		}
		::v-deep .van-slider__button::before{
			content: "";
			position: absolute;
			width: 50px;
			height: 50px;
			top: -23px;
			left: -23px;
		}
	}
}

@keyframes rotate {
    from {
        transform: translate(0, 0) rotate(0deg); /* 从原始位置开始旋转 */
    }
    to {
        transform: translate(0, 0) rotate(360deg); /* 旋转360度 */
    }
}


</style>
