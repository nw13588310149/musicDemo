<template>
  <view class="song-container">
	<view class="left">
		<view class="title">
			音乐风格
		</view>
		<view class="tip">
			<image class="icon" src="/static/assets/answer.png" />
			<text class="texts">描述你想要的音乐风格(例如原声流行音乐)。小音不认识艺术家的名字,但确实熟悉音乐的流派和氛围</text>
		</view>
		<view class="textarea">
			<textarea class="text" v-model="mode"  placeholder="输入音乐风格等形容词"/>
		</view>
		<view class="title">
			标题
		</view>
		<view class="tip">
			<image class="icon" src="/static/assets/answer.png" />
			<text class="texts">给你的歌曲起一个标题,以便分享、发现和整理</text>
		</view>
		<view class="textarea">
			<textarea class="text" v-model="title" placeholder="输入标题"/>
		</view>
		<view class="btn" @click="sub">
			<view class="center">
				<image class="icon" src="/static/assets/musicNew.png" />
				创造
			</view>
			
		</view>
		
		<view class="lyBox" v-if="showLy">
			<image class="return"  src="/static/assets/left1.png" @click="showLy=false"/>
			<view class="lyTitle">{{ activeItem.title || activeItem.prompt.split('\n')[0]}}</view>
			<view class="overY">
				<pre class="lyText" v-html="activeItem.lyric"></pre>
			</view>
		</view>
	</view>
	<view class="right">
		<image class="reload"  src="/static/assets/reload.png" @click="getAll"/>
		<!-- 加载中 -->
		<view class="loading" v-if="loading">
		    <image class="black" src="/static/assets/music_p.gif" />
		</view>
		<view class="over">
			<view class="li" v-for="(item,index) in allMusic" @click="play(item,index)">
				<view class="none" v-if="!item.duration">生成中...</view>
				<view class="img">
					<image class="playIcon" src="/static/assets/video_play.jpg" />
					<image class="image" :src="item.image_url" />
					<view class="time">{{formatTime(item.duration)}}</view>
				</view>
				<view class="text">
					<text class="title">{{ item.title || item.prompt.split('\n')[0]}}</text>
					<text class="tips">{{item.tags || '(无风格)'}}</text>
				</view>
			</view>
		</view>
	</view>
	

	
	<view class="palyBox" v-if="activeItem">
		<image class="image" :src="activeItem.image_url" />
		<image class="leftIcon" src="/static/assets/play_left.png" @click="prevTrack" />
		<image class="playIcon" :src="isPlay ? '/static/assets/play_stop.png' : '/static/assets/play_play.png'" @click="playChage"/>
		<image class="rightIcon" src="/static/assets/play_right.png" @click="nextTrack" />
		<view class="info">
			<view class="top">
				<view class="title">{{activeItem.title || activeItem.prompt.split('\n')[0]}}</view>
				<view class="tips" >- {{activeItem.tags || '(无风格)'}}</view>
				<view class="time">
					<view class="now">{{formatTime(num)}}</view>
					<view class="allT">/{{formatTime(maxNum2)}}</view>
				</view>
			</view>
			<view class="bottom">
				<!-- 音频进度条 -->
				<van-slider class="prog" v-model="num" @change="onChange" :min="0" :max="maxNum2"/>
			</view>
		</view>
		<image class="lycir" src="/static/assets/lycir.png" @click="showLy = !showLy" />
	</view>
  </view>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import axios from 'axios';
import { showToast , showLoadingToast ,closeToast} from 'vant';

const url = 'https://ai.yyzl0931.com/api/get_limit';
const mode = ref("");
const title = ref("");
const activeItem = ref("");

axios.get(url)
  .then(response => {
    // 处理成功响应
    console.log('API Response:', response.data);
  })
  .catch(error => {
    // 处理错误
    console.error('API Request Error:', error.message);
  });

const sub = ()=>{
	if(!mode.value){
		showToast('请输入风格等提示词！');
		return false
	}
	if(!title.value){
		showToast('请输入音乐标题！');
		return false
	}
	
	let url = "https://ai.yyzl0931.com/api/custom_generate";
	let data = {
		"prompt": "",
		"make_instrumental": false,
		"wait_audio": false,
		"tags":mode.value,
		"title":title.value,
}
	showToast('开始生成')
	axios.post(url,data)
	  .then(response => {
	    // 处理成功响应
		getAll()
		title.value = "";
		mode.value = "";
	    console.log('API Response:', response.data);
	  })
	  .catch(error => {
	    // 处理错误
		showToast("当前额度已使用完")
	    console.error('API Request Error:', error.message);
	  });
}

// 获取所有音乐
const allMusic = ref("");
const loading = ref(false);
const getAll = ()=>{
	loading.value = true;
	let url = "https://ai.yyzl0931.com/api/get";
	axios.get(url)
	  .then(response => {
	    // 处理成功响应
		if(response.status == 200){
			allMusic.value = response.data;
			loading.value = false;
			// allMusic.value = response.data.reverse();
		}
	  })
	  .catch(error => {
	    // 处理错误
	    console.error('API Request Error:', error.message);
	  });
}
getAll();

//时间转化
function formatTime(seconds) {
    // 计算分钟数
    const minutes = Math.floor(seconds / 60);
    // 计算剩余的秒数
    const remainingSeconds = Math.floor(seconds % 60);
    // 返回"分:秒"的结构，不进行秒数的补零操作
    return `${minutes}:${remainingSeconds}`;
}

//音乐播放
const isPlay = ref(false);
const num = ref(0);
const maxNum2 = ref(0);
const innerAudioContext = uni.createInnerAudioContext();
const activePlay = ref(0);
innerAudioContext.autoplay = true;
innerAudioContext.onPlay(() => {
  	maxNum2.value = innerAudioContext.duration;
	num.value = innerAudioContext.currentTime;
});

// 监听音频播放进度，实时更新进度条
innerAudioContext.onTimeUpdate(() => {
    num.value = innerAudioContext.currentTime;
});

innerAudioContext.onError((res) => {
  console.log(res.errMsg);
  console.log(res.errCode);
});

//音频播放结束
innerAudioContext.onEnded((res) => {
	isPlay.value = false;
})
const play = (item,index) =>{
	activePlay.value = index;
	activeItem.value = item;
	isPlay.value = true;
	innerAudioContext.src = item.audio_url;
}

const onChange = ()=>{
	innerAudioContext.seek(num.value);
}

const playChage = ()=>{
	if(isPlay.value){
		innerAudioContext.pause();
	}else{
		innerAudioContext.play();
	}
	isPlay.value = !isPlay.value;
}

// 上一首
const prevTrack = () => {
	if (activePlay.value > 0) {
	    activePlay.value--;
	} else {
	    activePlay.value = allMusic.value.length - 1; 
	}
	
	activeItem.value = allMusic.value[activePlay.value];
	isPlay.value = true;
	innerAudioContext.src = activeItem.value.audio_url;
	
}

//下一首
const nextTrack = () => {
	if (activePlay.value < allMusic.value.length - 1) {
	    activePlay.value++;
	} else {
	    activePlay.value = 0;
	}
	
	activeItem.value = allMusic.value[activePlay.value];
	isPlay.value = true;
	innerAudioContext.src = activeItem.value.audio_url;
	
}

const showLy = ref(false);
</script>

<style scoped>
	@keyframes move-bg {
	  to {
	    background-position: -400% 0;
	  }
	}
.song-container{
	background: #fff;
	height: 100%;
	border-radius: 9px;
	display: flex;
	flex-direction: row;
	position: relative;
	.left{
		width: 40%;
		border-right: 1px solid #f3f3f3;
		padding: 15px;
		position: relative;
		
		.text{
			box-shadow: 0 0 8px #f3f3f3;
			border-radius: 9px;
			margin: 10px 0 20px 0;
			padding: 15px !important;
			width: 100%;
			font-size: 15px;
			padding: 0 15px;
		}
	}
	.right{
		width: 60%;
		padding-left: 40px;
		position: relative;
		.reload{
			position: absolute;
			right: 15px;
			width: 30px;
			height: 30px;
			z-index: 10;
		}
		.loading{
			position: absolute;
			width: 100%;
			height: 100%;
			left: 0;
			top: 0;
			display: flex;
			justify-content: center;
			align-items: center;
			background: #fff;
			z-index: 8;
			.black{
				width: 50px;
				height: 50px;
			}
		}
		.text{
			box-shadow: 0 0 8px #f3f3f3;
			border-radius: 9px;
			margin: 10px 0 20px 0;
			padding: 15px;
			width: 100%;
			font-size: 15px;
			padding: 0 15px;
			padding-top: 5px;
		}
	}
	.title{
		position: relative;
		display: flex;
		align-items: center;
		font-size: 16px;
		.icon{
			margin-left: 6px;
			width: 16px;
			height: 16px;
		}
	}
	.tip{
		padding: 10px 0;
		display: flex;
		flex-direction: row;
		padding-left: 20px;
		.icon{
			position: absolute;
			left: 16px;
			width: 14px;
			height: 14px;
		}
		.texts{
			font-size: 10px;
			color: #969799;
			
		}
	}

	.btn {
	      background: linear-gradient(90deg, #8d28fc, #0afdec, #0afdec, #8d28fc);
	      background-size: 400%;
	      border-radius: 50px;
	      box-sizing: border-box;
	      cursor: pointer;
	      font-size: 16px;
	      padding: 4px;
	      text-align: center;
	      -webkit-text-decoration: none;
	      text-decoration: none;
	      transform: translate(0);
	      width: 60%;
		  margin: 0 20%;
	      z-index: 1;
		  margin-top: 30px;
		  
		  .center{
			  background: #ffffffa3;
			      border-radius: 46px;
			      font-weight: 700;
			      height: 46px;
			      width: 100%;
				 display: flex;
				  justify-content: center;
				  align-items: center;
				  letter-spacing: 2px;
				  .icon {
				  		width: 20px;
				  		height: 20px;
				  		margin-right: 8px;
					}
			}
	}
	
	.btn:before {
	      animation: move-bg 5s infinite alternate;
	      background: linear-gradient(90deg, #8d28fc, #0afdec, #0afdec, #8d28fc);
	      background-size: 400%;
	      border-radius: 50px;
	      bottom: -2px;
	      content: "";
	      filter: blur(5px);
	      left: -2px;
	      position: absolute;
	      right: -2px;
	      top: -2px;
	      z-index: -1;
	}
	.over::-webkit-scrollbar {
	  display: none;
	}
	.right{
		padding: 12px;
		padding-left: 30px;
		.over{
			height: 100%;
			padding-right: 50px;
			overflow-y: auto;
			-webkit-overflow-scrolling: touch; /* 兼容iOS滚动 */
			scrollbar-width: none; /* Firefox */
			-ms-overflow-style: none; /* IE/Edge */
		}

		.li{
			display: flex;
			flex-direction: row;
			margin-bottom: 10px;
			position: relative;
			.none{
				position: absolute;
				width: 100%;
				height: 100%;
				background: #dddddd9e;
				z-index: 6;
				left: 0;
				top: 0;
				border-radius: 4px;
				display: flex;
				justify-content: center;
				align-items: center;
			}
			.img{
				position: relative;
				.playIcon{
					position: absolute;
					width: 26px;
					height: 26px;
					z-index: 3;
					left: 50%;
					top:50%;
					transform: translateX(-50%) translateY(-50%);
				}
				.image{
					width: 67.2px;
					height: 92.4px;
					border-radius: 6px;
				}
				.time{
					position: absolute;
					right: 2px;
					bottom: 10px;
					font-size: 13px;
					background: rgba(14, 8, 8, 0.7);
					color: #fff;
					display: inline-block;
					width: 33px;
					text-align: center;
					border-radius: 4px;
					padding: 1px 4px;
				}
			}
			.text{
				margin: 0;
				box-shadow: none;
				border: none;
				display: flex;
				flex-direction: column;
				.title:before{
					display:none;
				}
				.title{
					padding-left: 0;
					margin-bottom: 5px;
				}
				.tips{
					font-size: 12px;
				}
			}
			.time{
				display: flex;
				justify-content: center;
				align-items: center;
				padding-right: 20px;
			}
		}
	}
	.palyBox{
		position: fixed;
		width: 100%;
		height: 82px;
		bottom: 0;
		left: 0;
		z-index: 9;
		    background: rgba(0, 0, 0, 0.1);
		    backdrop-filter: blur(10px);
		    -webkit-backdrop-filter: blur(10px);
		    border: 1px solid rgba(255, 255, 255, 0.18);
		    padding: 5px 20px;
		    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
		display: flex;
		flex-direction: row;
		align-items: center;	
		.image{
			width: 44.8px;
			height: 61.6px;
			border-radius: 4px;
			margin-right: 30px;
		}	
		.leftIcon ,.rightIcon{
			width: 20px;
			height: 20px;
		}
		.playIcon{
			width: 40px;
			height: 40px;
			margin: 0 16px;
		}
		.info{
			margin-left: 40px;
			/* width: calc(100% - 360px); */
			width: calc( 100% - 300px);
			.top{
				display: flex;
				flex-direction: row;
				align-items: center;
				.tips{
					color: #999;
					margin-left: 5px;
					font-size: 13px;
					align-items: center;
					overflow:hidden; 
					text-overflow:ellipsis; 
					white-space:nowrap; 
					max-width: 660px;
				}
				.time{
					font-size: 13px;
					margin-left: auto;
					display: flex;
					align-items: flex-end;
					flex-direction: row;
					.allT{
						font-size: 14px;
						color: #000;
					}
				}
			}
			.bottom{
				margin-top:10px;
				::v-deep .van-slider__button{
					width: 12px;
					height: 12px;
					background: #00c9a4;
				}
				::v-deep .van-slider__bar{
					background: #00c9a4;
				}
			}
		}
		.lycir{
			width: 36px;
			height: 36px;
			margin-left: 20px;
		}
		
	}
	.lyBox{
		position: absolute;
		width: 100%;
		height: 100%;
		z-index: 9;
		background: #fff;
		border-radius: 9px; 
		top: 0;
		left: 0;	
		
		.return{
			position: absolute;
			left: 15px;
			top: 15px;
			width: 24px;
			height: 24px;
		}
		.lyTitle{
			padding: 20px;
			padding-top: 40px;
			font-size: 20px;
			display: flex;
			align-items: center;
			justify-content: center;
		}
		.overY{
			height: calc(100% - 156px);
			overflow-y: auto;
			-webkit-overflow-scrolling: touch; /* 兼容iOS滚动 */
			scrollbar-width: none; /* Firefox */
			-ms-overflow-style: none; /* IE/Edge */
		}
		.overY::-webkit-scrollbar {
		  display: none;
		}
		.lyText{
			display: flex;
			align-items: center;
			justify-content: center;
			text-align: center;
			line-height: 30px;
		}
	}
}
</style>