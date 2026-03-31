<template>
	<view class="play_content22">
		<view class="top">
		  <van-icon class="return" name="arrow-left" style="font-size: 22px;" @click="left" />
		</view>
		<!-- 音乐播放器 -->
		<view class="music" :class="{'music2':item.type != 2?false:true}">
			<view class="music_play" v-if="item.type != 2">
				<music-play :item='item'/>
			</view>
			<view class="answer" :class="{'all':item.type != 2?false:true}">
				<view class="box">
					<view class="scroll">
						<van-image
						style="min-width: 100%;"
							v-if="item.type != 1 && item.image.length == 1"
							v-for="i in item.image"
						    class="img_bg"
						    :src="i"
							@touchstart="onTouchStart(item.image)"
						>
						<template v-slot:loading>
						    <van-loading type="spinner" size="20" />
						  </template>
						  </van-image>
						<view class="tips" v-if="item.type != 1 && item.image.length > 1">{{currentIndex+1}}/{{item.image.length}}</view>
						<van-swipe v-if="item.type != 1 && item.image.length > 1" :autoplay="0" lazy-render @change="changeImg($event)" >
						  <van-swipe-item v-for="img in item.image"  :key="image">
						    <van-image
							style="min-width: 100%;"
						        :src="img"
						    	@touchstart="onTouchStart(item.image)"
						    >
							<template v-slot:loading>
							    <van-loading type="spinner" size="20" />
							  </template>
							  </van-image>
						  </van-swipe-item>
						</van-swipe>
						<van-image
							v-if="item.type == 1"
						    class="img_bg"
							style="width: 40%;margin:20px 195px;min-width: 100%"
						    src="/static/assets/logo_b.jpg"
						>
						<template v-slot:loading>
						    <van-loading type="spinner" size="20" />
						  </template>
						  </van-image>
					</view>
				</view>
				
			</view>
		</view>
		<!-- 虚拟钢琴组件 -->
		<view class="piano_box" v-if="item.type != 2">
		  <virtual-piano />
		</view>
		
		<!-- 图片弹窗 -->
		<van-popup v-model:show="showImg">
			<van-image
			style="min-width: 100%;"
				@touchstart="onTouchEnd()"
			    :src="showImgUrl"
			><template v-slot:loading>
					    <van-loading type="spinner" size="20" />
					  </template>
					  </van-image>
		</van-popup>
	</view>

</template>

<script setup>
import { ref ,onMounted} from 'vue';
import { useRouter} from 'vue-router';
import VirtualPiano from '../common/piano.vue';
import musicPlay from '../common/music.vue';
import {onShow} from '@dcloudio/uni-app';
import {showImagePreview} from 'vant';


const router = useRouter();
const showAnswer = ref(false);	


const id = history.state.id;
const type  =  history.state.type;

const dataA = JSON.parse(history.state.item);
console.log(dataA)
const item = ref({
	title:dataA.title,
	image:JSON.parse(dataA.param3),
	file1:dataA.param2,
	type:dataA.param1,
});

const showImg = ref(false);
const touchTime = ref(0);
const touchTimeout = ref(null);
const showImgUrl = ref('');

const currentIndex = ref(0)
function changeImg(index){
	currentIndex.value = index;
}

function onTouchStart(img) {
	const currentTime = new Date().getTime();
	const timeDiff = currentTime - touchTime.value;
	touchTime.value = currentTime;
	if (timeDiff < 300) {
		console.log(img)
		let arr = [];
		try{
			img.forEach(e =>{
				arr.push(e.url || e)
			})
		}catch{
			arr = [img]
		}
		
		showImagePreview({
		images:arr,
		 closeable: true});
	}
}

function onTouchEnd() {
	// const currentTime = new Date().getTime();
	// const timeDiff = currentTime - touchTime.value;
	// touchTime.value = currentTime;
	// if (timeDiff < 300) {
	// 	showImg.value = false;
	// }
}

function left() {
  router.go(-1);
}


function toggleAnswer() {
  showAnswer.value = !showAnswer.value;
}


</script>

<style lang="scss" scoped>
	::v-deep .van-swipe__indicators{
		display: none;
	}
	::v-deep section{
		min-height: 18px;
	}

	.music2{
		height: 100% !important;
		.box{
			box-shadow: none !important;
			border: none !important;
			padding: 0 !important;
		}
	}
	.all{
		margin-left: 0!important;
		.box{
			left: 0 !important;
			width: 100% !important;
		}
	}
	.play_content22{
		background: #fff;
		border-radius: 14px;
		height: 100%;
		padding: 15px 15px 15px 15px;
		position: relative;
		.top{
			position: absolute;
			    top: 22px;
			    left: 19px;
			    z-index: 10;
			    font-size: 16px;
		}
		.return {
		  font-size: 30px;
		}
		.piano_box{
			position: absolute;
			bottom: 0;
			left: 0;
			width: 100%;
			height: 38%;
		}
		.music{
			height: 60%;
		    position: absolute;
		    width: 100%;
			position: relative;
			.music_play{
				width: 264px;
				height: 100%;
				position: absolute;
				top: 0;
				left: 0;
				z-index: 2;
			}
			.answer{
				margin-left: 276px;
				position: relative;
				height: 100%;
				.box{
				    position: absolute;
				    width: 100%;
				    height: 100%;
				    left: 0px;
				    border: 1px solid #eee;
				    border-radius: 12px;
				    padding: 20px;
					box-shadow: 0 0 6px #6b6b6b24;
					background: url(/static/assets/logo_b.jpg) no-repeat;
					background-position: center;
					background-size: 30%;
					.btn_c{
						    position: absolute;
						    right: 20px;
						    padding: 3px 10px;
						    z-index: 9;
						    border-radius: 22px;
						    font-size: 14px;
							top: 16px;
					}
					.scroll{
						overflow-y: auto;
						/* 隐藏滚动条 */
						scrollbar-width: none; /* Firefox */
						-ms-overflow-style: none; /* IE and Edge */
						width: 100%;
						height: 100%;
						background: #fff;
						.tips{
							position: absolute;
							bottom: 16px;
							z-index: 999;
							right: 16px;
							padding: 2px 13px;
							border-radius: 15px;
							background: #f3f3f3;
							font-size: 12px;
							
						}
					}
					.scroll::-webkit-scrollbar {
					    display: none; /* Chrome, Safari, Opera */
					}

				}
				
			}
		}

	}
	/* 响应式设计 */
	@media (max-width: 1024px) {
	    /* 在宽度小于等于1024px的平板设备上调整样式 */
		.play_content22{
			::v-deep .music{
				height: 408px;
				.play{
					.btn{
						.time{
							top: 50px;
						}
					}
				}
			}
	
		}
		::v-deep #waveform{
			margin-top: 15px;
		}
	
		.play_content22 .piano_box{
			height: calc(100% - 434px);
		}
	}
</style>
