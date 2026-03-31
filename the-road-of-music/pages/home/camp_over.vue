<template>
	<view class="campOver">
		<view class="top">
			<view class="left_icon">
				<van-icon class="left" name="/static/assets/left.png" @click="left"/>
			</view>
		</view>
		<view class="content">
			<view class="title">恭喜您练完了所有题目!</view>
			<view class="order">
				<view class="li">
					<view class="num">{{data?.doneCount}}</view>
					<view class="tit">已做题</view>
				</view>
				<view class="li">
					<view class="num">{{data?.errorCount}}</view>
					<view class="tit">错题</view>
				</view>
				<view class="li">
					<view class="num">{{(Math.floor(1 - data?.errorCount/data?.doneCount))*100}}%</view>
					<view class="tit">正确率</view>
				</view>
			</view>
			<view class="btn close"  @click="left">随机练习</view>
			<view class="btn tj" @click="reload">重新练习</view>
		</view>
	</view>
</template>

<script setup>
import { ref , onMounted } from 'vue';
import { useRouter } from 'vue-router';	
import { getQuestionSummary , questionPracticeCreate} from '../../api/home.js'

const router = useRouter();


const item = JSON.parse(history.state.id);
const data = ref({});

getQuestionSummary().then(res =>{
		if(item.title == "顺序练习"){
			data.value = res.data.sequence;
		}else if(item.title == "随机练习"){
			data.value = res.data.random;
		}else if(item.title == "考前密卷"){
			data.value = res.data.exam;
		}else if(item.title == "错题集"){
			data.value = res.data.error;
		}
	})

function reload(){
	let title = "";
	if(item.title == "顺序练习"){
		title = 'sequence';
	}else if(item.title == "随机练习"){
		title = 'random';
	}else if(item.title == "考前密卷"){
		title = 'exam';
	}else if(item.title == "错题集"){
		title = 'error';
	}
	questionPracticeCreate({"practiceType": title,"size": '150'}).then(res =>{
		if(res.code == 0){
			router.push({name:"camp"})
		}
	})
}
	
function left(){
	router.push({name:"camp"})
}	
</script>

<style lang="scss" scoped>
.campOver{
			width: 100%;
			height: 100%;

		.top{
			height: 42px;
			padding: 7px 10px;
			background: #fff;
			border-radius: 9px;
			.left{
				width: 28px;
				height: 28px;
				background: #e1f7f2;
				text-align: center;
				line-height: 28px;
				text-align: center;
				border-radius: 50%;
				display: flex;
				justify-content: center;
				align-items: center;
			}
		}	
		.content{
			background: #fff;
			border-radius: 9px;
			margin-top: 15px;
			padding: 10% 15% 10% 15%;
			height: calc(100% - 58px);
		}
		}
		.title{
			width: 210px;
			height: 35px;
			color: #111;
			border-radius: 8px;
			text-align: center;
			line-height: 35px;
			font-weight: 500;
			font-size: 18px;
			margin: 0 auto;
		}
		.order{
			margin-top: 90px;
			display: flex;
			width: 90%;
			margin-left: 5%;
			justify-content: center;
			
			.li{
				width: 25%;
				text-align: center;
				.num{
					font-weight: 400;
					font-size: 18px;
				}
				.tit{
					margin-top: 12px;
					color: #bababb;
					font-size: 14px;
				}
			}
		}
		.btn{
			box-shadow: 0 0 8px 0 #eeeeee;
			height: 36px;
			border-radius: 36px;
			text-align: center;
			line-height: 36px;
			margin-top: 20px;
			.in{
				display: inline-block;
				position: relative;
				// font-weight: 400;
				.tuijian{
					    position: absolute;
					    background: url(/static/assets/tuijian.png) no-repeat;
					    background-size: contain;
					    font-size: 12px;
					    height: 30px;
					    width: 30px;
					    line-height: 20px;
					    right: -30px;
					    top: -7px;
						font-weight: 400;
					
				}
			}
		}
		.close{
			margin-top: 90px;
			box-shadow: none;
			background: #00c9a4;
			color: #fff;
		}
		.logout{
			width: 120px;
			margin: 40px auto;
		}	
</style>