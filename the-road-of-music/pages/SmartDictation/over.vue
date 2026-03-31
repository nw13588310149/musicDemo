<template>
	<view class="contain">
		<van-image
		  class="icon yanhua"
		  src="/static/assets/yanhua.gif"
		/>
		<view class="top">
		  <van-icon class="return" name="/static/assets/goback.jpg" @click="left" />
		  <!-- <view class="change" v-for="item in listChange" v-html="item.name"></view> -->
		</view>
		<view class="content1">
			<view class="sucess">
				<van-icon style="font-size: 90px;" :class="id>0?'animate__animated animate__zoomIn':''" :name="id>0?'/static/assets/xx_yes.png':'/static/assets/xx_no.png'" />
				<van-icon :class="id>1?'animate__animated animate__zoomIn':''" style="margin: 0 15px;" :name="id>1?'/static/assets/xx_yes.png':'/static/assets/xx_no.png'" />
				<van-icon style="font-size: 90px;" :class="id>2?'animate__animated animate__zoomIn':''" :name="id>2?'/static/assets/xx_yes.png':'/static/assets/xx_no.png'" />
			</view>
			<view class="text">{{id>2?'非常好':id>1?'很好':"再接再厉"}}</view>
			<view class="tip" v-if="id">至少赢得2颗星，方可进入下一课！</view>
			<view class="scroll">
				<view class="li" v-for="item in listChange">
					<view class="title" v-html="item.name"></view>
					<!-- 进度条 -->
					<van-progress :percentage="item.num/25*100"  stroke-width="10" color="#00c9a4" :show-pivot='false' />
				</view>
			</view>
			<view class="begin_box">
				<view class="begin" @click="left">再试一次</view>
			</view>
		</view>
	</view>
</template>

<script setup>
import { ref ,onMounted ,onUnmounted,nextTick ,watchEffect,computed} from 'vue';
import { useRouter} from 'vue-router';
import router from '../../router';
import { smartDictationRecordSave } from '../../api/home.js'
import 'animate.css'

const id = ref(0);
onMounted(() =>{
	var yanhuaElement = document.querySelector('.yanhua');
	setTimeout(function(){
		yanhuaElement.classList.add('hidden');
	},1500)
	
	for(let i = 1 ; i<= history.state.id; i++){
		setTimeout(function(){
			id.value = i;
		},1000*i+200)
	}
})

const noteMap = {	
    'F3':'f', 
    'F#3':'<sup>#</sup>f', 
    'G3g': 'g', 
    'G#3': 'sup>#</sup>g', 
    'A3': 'a', 
    'A#3': '<sup>b</sup>b', 
    'B3': 'b', 
    'C4': 'c<sup>1</sup>', 
    'C#4': '<sup>#</sup>c<sup>1</sup>', 
    'D4': 'd<sup>1</sup>', 
    'D#4': '<sup>b</sup>e<sup>1</sup>', 
    'E4': 'e<sup>1</sup>', 
    'F4': 'f<sup>1</sup>', 
    'F#4': '<sup>#</sup>f<sup>1</sup>', 
    'G4': 'g<sup>1</sup>', 
    'G#4': '<sup>#</sup>g<sup>1</sup>', 
    'A4': 'a<sup>1</sup>', 
    'A#4': '<sup>b</sup>b<sup>1</sup>', 
    'B4': 'b<sup>1</sup>', 
    'C5': 'c<sup>2</sup>', 
    'C#5': '<sup>#</sup>c<sup>2</sup>', 
    'D5': 'd<sup>2</sup>', 
    'D#5': '<sup>b</sup>e<sup>2</sup>', 
    'E5': 'e<sup>2</sup>', 
    'F5': 'f<sup>2</sup>', 
    'F#5': '<sup>#</sup>f<sup>2</sup>', 
    'G5': 'g<sup>2</sup>', 
    'G#5': '<sup>#</sup>g<sup>2</sup>', 
    'A5': 'a<sup>2</sup>'
};

const listChange = ref([]);


const all =  JSON.parse(history.state.all);
const parsedItem = JSON.parse(sessionStorage.getItem('item')).item;
const parseId = JSON.parse(sessionStorage.getItem('item'))?.data?.id || '';


if(JSON.parse(sessionStorage.getItem('item')).data){
		smartDictationRecordSave({smartDictationId:JSON.parse(sessionStorage.getItem('item')).data.id,stars:history.state.id}).then(res =>{
		
		})
}



// 定义一个函数来统计数组中每个元素出现的次数
function countOccurrences(arr) {
    return arr.reduce((acc, curr) => {
        acc[curr] = (acc[curr] || 0) + 1;
        return acc;
    }, {});
}

// 统计 all 数组中每个音符出现的次数
const allOccurrences = countOccurrences(all);

if(history.state.back == "/answer"){
	for(let key in allOccurrences){
		listChange.value.push({name:noteMap[key],num:allOccurrences[key]})
	}
}else if(history.state.back == "/answer2" || history.state.back == "/answer3"){
	for(let key in allOccurrences){
		listChange.value.push({name:key,num:allOccurrences[key]})
	}
}

console.log(parsedItem)
function left(){
	if(history.state.back == "/answer"){
		if(parseId){
			router.push({name:"smartDictation",state:{id:1}})
		}else{
			router.push({name:"smartDictation",state:{id:2}})
		}
	}else if(history.state.back == "/answer2"){
		if(parseId){
			router.push({name:"smartDictation",state:{id:3}})
		}else{
			router.push({name:"smartDictation",state:{id:4}})
		}
	}else if(history.state.back == "/answer3"){
		if(parseId){
			router.push({name:"smartDictation",state:{id:5}})
		}else{
			router.push({name:"smartDictation",state:{id:6}})
		}
	}
}

</script>

<style lang="scss" scoped>
	.hidden{
		display: none !important;
	}
	.yanhua{
		    position: absolute;
		    width: 360px;
		    height: 360px;
		    left: 50%;
		    transform: translateX(-180px);
	}
	.contain{
		width: 100%;
		height: 100%;
		position: relative;
	}
	.top{
		    background: #fff;
		    height: 40px;
		    border-radius: 8px;
			display: flex;
			justify-content: flex-start;
			align-items: center;
		.return{
			font-size: 30px;
			margin: 5px;
			margin-left: 15px;
		}
		.change{
			    background: #eee;
			    width: 40px;
			    height: 26px;
			    text-align: center;
			    margin-left: 20px;
			    line-height: 26px;
			    font-size: 14px;
			    border-radius: 4px;
				color: #171a20;
				font-weight: 400;
		}
	}
	.content1{
		background: #fff;
		    margin-top: 10px;
		    border-radius: 8px;
		    padding: 20px;
		    height: calc(100% - 50px);
		    width: 100%;
		.sucess{
			display: flex;
			    justify-content: center;
			    font-size: 100px;
			    padding: 50px;
				
		}	
		.text{
			font-size: 24px;
			font-weight: 400;
			color: #111;
			text-align: center;
		}
		.tip{
			text-align: center;
			margin-top: 10px;
			color: #6b6b6b;
		}
		.scroll{
			width: 90%;
			margin-left: 5%;
			margin-top: 50px;
			height: 300px;
			overflow-y: auto;
			.li{
				position: relative;
				margin-bottom: 40px;
				padding-left: 70px;
				.title{
					position: absolute;
					    left: 0px;
					    top: -6px;
					    font-size: 18px;
					    font-weight: 400;
				}
			}
		}
		.begin_box{
			display: flex;
			justify-content: center;
			position: absolute;
			bottom: 40px;
			width: 100%;
			left: 0;
			.begin{
				display: inline-block;
				width: 120px;
				height: 50px;
				line-height: 50px;
				color: #fff;
				background: #00c9a4;
				text-align: center;
				font-size: 16px;
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
</style>