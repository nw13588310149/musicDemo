<template>
	<view class="camp2">
		<view class="top">
			<view class="left_icon">
				<van-icon class="left" name="/static/assets/left1.png" @click="goLeft"/>
			</view>
			<view class="right_btn">
				自动刷题
				<van-switch v-model="checked" active-color="#00c9a4" size="22px" />
			</view>
		</view>
		<view class="box">
			<view class="title" style="margin-bottom: 10px;">
				<view class="tips">单选题</view>
				<view class="sort">第{{initNum+1}}题:</view>
			</view>
			<view class="title">
				<view class="text" v-html="tmList[initNum]?.question.question"></view>
			</view>
			<view class="answerBox">
				<view class="answer">
					<view class="btn" @tap="sb(0)" :style="getStyle(0)">A</view>
					<view class="text" v-html="tmList[initNum]?.question.param1"></view>
				</view>
				<view class="answer">
					<view class="btn" @tap="sb(1)" :style="getStyle(1)">B</view>
					<view class="text" v-html="tmList[initNum]?.question.param2"></view>
				</view>
				<view class="answer">
					<view class="btn" @tap="sb(2)" :style="getStyle(2)">C</view>
					<view class="text" v-html="tmList[initNum]?.question.param3"></view>
				</view>
				<view class="answer">
					<view class="btn" @tap="sb(3)" :style="getStyle(3)">D</view>
					<view class="text" v-html="tmList[initNum]?.question.param4"></view>
				</view>
			</view>
			<view class="bottom" v-if="tmList[initNum]?.status != 0">
				<view class="ok">
					<view class="one">答案: <view class="text" style="color: #2fcfa3;" >{{getAnswer(tmList[initNum]?.question.answer)}}</view></view>
					<view class="two">您选择: <view class="text" :style="{'color': tmList[initNum]?.status == 1?'#2fcfa3':'#ec628f'}">{{getAnswer(tmList[initNum]?.answer)}}</view></view>
				</view>
				<view class="jx">
					<view class="title">题目解析:</view>
					<view class="text" style="font-size: 14px;" v-html="tmList[initNum]?.question.parse"></view>
				</view>
			</view>
			<view class="btnBox">
				<view class="left" @click="changeDel"><van-icon class="icon" name="arrow-left" />上一题</view>
				<view class="right" @click="changeAdd">下一题<van-icon class="icon"  name="arrow" /></view>
			</view>
		</view>
		
		<!-- 退出弹窗 -->
		<van-dialog class="qrcode_box" v-model:show="showQrcode" :showConfirmButton='false'>
			<view class="title">{{typeO()}}</view>
			<view class="order">
				<view class="li">
					<view class="num">{{allItem.notDoneCount}}</view>
					<view class="tit">未做题</view>
				</view>
				<view class="li">
					<view class="num">{{allItem.doneCount}}</view>
					<view class="tit">已做题</view>
				</view>
				<view class="li">
					<view class="num">{{allItem.errorCount}}</view>
					<view class="tit">错题</view>
				</view>
				<view class="li">
					<view class="num">{{Math.ceil((1 - allItem.errorCount / allItem.doneCount)*100 || 0)}}%</view>
					<view class="tit">正确率</view>
				</view>
			</view>
			<view class="btn close"  @click="showQrcode = false">继续练习</view>
			<view class="btn tj" @click="goExam"><view class="in">{{allItem.type != 'exam'?'考前密卷':'随机练习'}} <view class="tuijian">推荐</view></view></view>
			<view class="logout btn" @click="left">退出</view>
		</van-dialog>
	</view>
</template>

<script setup>
import { ref , onMounted } from 'vue';
import { useRouter } from 'vue-router';	
import { questionPracticeItemList , questionPracticeItemReport , getQuestionSummary} from '../../api/home.js'
import { showToast} from 'vant';

const router = useRouter();

let item = JSON.parse(history.state.id);
console.log(item)
const initNum = ref(item.num)
const tmList = ref([]);
questionPracticeItemList({practiceId:item.practiceId}).then(res =>{
	if(res.code == 0){
		tmList.value = res.data;
	}
})

const showQrcode =ref(false);
const checked = ref(false);

console.log(initNum.value,item.all)
if(initNum.value >= item.all){
	router.push({name:"camp_over",state:{id:history.state.id}})
}


function typeO(){
	if(type == 'sequence'){
		return '顺序练习'
	}else if(type == 'random'){
		return "随机练习"
	}else if(type =="exam"){
		return "考前密卷"
	}else if(type == "error"){
		return "错题集"
	}
}

function getAnswer(type){
	if(type == 0){
		return 'A'
	}else if(type == 1){
		return "B"
	}else if(type ==2){
		return "C"
	}else if(type == 3){
		return "D"
	}
}

function getStyle(type){
	if(type == tmList.value[initNum.value]?.answer){
		if(tmList.value[initNum.value].status == 1){
			return {background:'#00c9a4',color:'#fff'};
		}else if(tmList.value[initNum.value].status == 2){
			return {background:'#e61f62',color:'#fff'};
		}else{
			return ''
		}
	}else{
			return ''
		}
}

// 切换题目
function changeDel(){
	if(initNum.value - 1 < 0){
		showToast('已经是第一题了！');
		return false;
	}
	initNum.value -= 1;
	
}
function changeAdd(){
	if(initNum.value + 1 >=  item.all){
		showToast('已经是最后一题了！');
		return false;
	}
	initNum.value += 1;
	
}

//切换试卷
function goExam(){
	if(item.type == "exam"){
		item = maxItem.value.random;
	}else{
		item = maxItem.value.exam;
	}
	initNum.value = item.num;
	questionPracticeItemList({practiceId:item.practiceId}).then(res =>{
		if(res.code == 0){
			tmList.value = res.data;
			showQrcode.value = false;
		}
	})
}

//上报答案
function sb(type){
	if(tmList.value[initNum.value].status != 0){
		return false;
	}
	let params = {
		"answer": type,
		"questionPracticeItemId": tmList.value[initNum.value].id,
		"status": type== tmList.value[initNum.value].question.answer?1:2
	}
	questionPracticeItemReport(params).then(res =>{
		if(res.code == 0){
			 tmList.value[initNum.value].status = type==tmList.value[initNum.value].question.answer?1:2;
			 tmList.value[initNum.value].answer = type;
			 
			 if(checked.value){
				 setTimeout(function(){
				 		changeAdd()
				 },2000)
			 }
		}
	})
}


const allItem = ref({});	
const maxItem = ref({});

function goLeft(){
	getQuestionSummary().then(res =>{
		maxItem.value = res.data;
		allItem.value = res.data[item.type];
		showQrcode.value = true;
	})
}	
	

function left(){
	router.push({name:"camp"})
}
</script>

<style lang="scss" scoped>
	::v-deep .qrcode_box{
		width: 60%;
		height: 60%;

		.van-dialog__content{
			width: 100%;
			height: 100%;
			padding: 30px;
			background: #fff !important;
		}

		.title{
			width: 120px;
			height: 35px;
			background: #00c9a4;
			color: #111;
			border-radius: 8px;
			text-align: center;
			line-height: 35px;
			font-weight: 500;
			font-size: 18px;
			margin: 0 auto;

		}
		.order{
			margin-top: 80px;
			display: flex;
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
				font-weight: 400;
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
			margin-top: 80px;
			box-shadow: none;
			background: #00c9a4;
			color: #fff;
		}
		.logout{
			width: 120px;
			margin: 40px auto;
		}
	}
	.camp2{
		width: 100%;
		height: 100%;
		position: relative;
		.top{
			height: 42px;
			padding: 6px 10px;
			background: #fff;
			border-radius: 9px;
			position: relative;
			.left{
				font-size: 30px;
				width: 30px;
				height: 30px;
				background: #e1f7f2;
				text-align: center;
				text-align: center;
				border-radius: 50%;
			}
			.right_btn{
				position: absolute;
				right:12px;
				top: 0;
				height: 42px;
				display: flex;
				align-items: center;
				color: #969799;
				font-size: 15px;
				.van-switch{
					margin-left: 8px;
					color: #f4f4f4;
				}
			}
		}
		.box{
			margin-top: 16px;
			height: calc(100% - 57px);
			background: #fff;
			border-radius: 9px;
			padding: 20px;
			.title{
				display: flex;
				font-weight: 400;
				color: #333;
				margin-bottom: 20px;
				align-items: flex-start;
				.tips{
					background: #C219EE;
					width: 40px;
					height: 18px;
					border-radius: 4px;
					display: flex;
					justify-content: center;
					align-items: center;
					font-size: 10px;
					color: #fff;
					margin-right: 8px;
					margin-top: 1px;
				}
				.text ::v-deep p{
					display: flex;
					align-items: center;
					min-height: 60px;
					
				}
				::v-deep img{
					margin: 0 10px;
				}
			}
			.answerBox{
				display: flex;
				justify-content: space-between;
				flex-wrap: wrap;
				.answer{
					display: flex;
					min-height: 60px;
					align-items: center;
					width: 50%;
					.btn{
						width: 40px;
						height: 40px;
						line-height: 40px;
						text-align: center;
						border-radius: 50%;
						box-shadow: 0 0 8px 0 #eeeeee;
						margin-right: 20px;
						font-weight: 400;
						color: #333;
					}
					.text{
						max-width: calc(100% - 140px);
					}
				}
			}
			.bottom{
				margin-top: 20px;
				border-top: 1px solid #f6f7fb;
				.ok{
					display: flex;
					box-shadow: 0 0 8px 0 #eeeeee;
					margin-top:20px;
					padding: 10px 12px;
					border-radius: 4px;
					.one,.two{
						width: 140px;
						display: flex;
						font-weight: 400;
						.text{
							font-weight: 400;
							margin-left: 10px;
						}
					}
				}
				.jx{
					margin-top: 30px;
				}
			}
			.btnBox{
				position: absolute;
				bottom: 36px;
				left: 50%;
				width: 254px;
				height: 44px;
				line-height: 44px;
				display: flex;
				transform: translateX(-100px);
				box-shadow: 0 0 8px 0 #eeeeee;
				border-radius: 9px;
				.left,.right{
					width: 50%;
					text-align: center;
					font-weight: 400;
					font-size: 16px;
					color: #555;
					position: relative;
					.icon{
					    width: 30px;
					    height: 30px;
					    background: #e1f7f2;
					    color: #00c9a4;
					    border-radius: 50%;
					    font-size: 18px;
					    font-weight: 400;
					    line-height: 30px;
					    text-align: center;
					}
				}
				.left .icon{
					margin-right: 10px;
				}
				.right .icon{
					margin-left: 10px;
				}
				.left::after{
					content: "";
					position: absolute;
					right: 0;
					width: 1px;
					height: 30px;
					background: #eeeeee;
					top: 7px;
				}
			}
		}
	}
</style>