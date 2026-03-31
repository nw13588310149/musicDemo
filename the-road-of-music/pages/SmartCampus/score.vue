<template>
	<view class="score">
		<van-empty v-if="!activeClass" description="请先加入班级" />
		<!-- 切换班级 -->
		<view class="top">
			<view class="tips" v-if="classAll?.length > 1" @click="showPicker = !showPicker">{{activeClass.name}} <van-icon style="margin-left: 5px;" :name="showPicker?'arrow-up':'arrow-down'" /></view>
		</view>
	
		<van-empty v-if="examArr.length == 0" description="还没有考试哦" />
		<view class="list">
			<view class="li" v-for="item in examArr">
				<van-icon class="icon" name="/static/assets/score.png" />
				<view class="x">
					<view class="name">{{item.name}}</view>
					<view class="time">{{item.createTime}}</view>
				</view>
				<view class="btn" @click="detail(item)">查看</view>
				<van-icon class="icon_right" name='/static/assets/qunRigth.png'/>
			</view>
		</view>
		<!-- 班级选择 -->
		<van-popup v-model:show="showPicker" round position="bottom">
		  <van-picker
		    :columns="columns"
		    @cancel="showPicker = false"
		    @confirm="onChange"
		  />
		</van-popup>
		
		<!-- 成绩弹窗 -->
		<van-dialog class="qrcode_box" v-model:show="showQrcode" :showConfirmButton='false'>
			<view style="background: #fff;border-radius:9px;">
				<view class="title">{{scoreDetail?.exam?.name}}</view>
				<view class="info">
					<view class="li" v-for="(item,index) in scoreDetail?.subjects1">
						<view class="name">{{item}}</view>
						<view class="num">{{scoreDetail?.studentList[0].scoreList[index]}}</view>
					</view>
				</view>
				<view class="tip">{{scoreDetail.studentList[0].studentRealname}}同学{{scoreDetail?.exam?.name}}成绩</view>
			</view>
			<view class="close">
				<van-icon @click="showQrcode = false" name="/static/assets/bg_close.jpg" />
			</view>
		</van-dialog>
		
		<view class="all"  v-if="showAll">
			<view class="title">
				<van-icon class="return" @click="showAll = false" name="/static/assets/left1.png"  />
				{{activeClass.name}}{{scoreDetail?.exam?.name}}成绩表
			</view>
			<view class="border">
				<view class="table">
					<view class="head">
						<view class="li">序号</view>
						<view class="li li1">姓名</view>
						<view class="li li1" v-for="item in scoreDetail?.subjects1">{{item}}</view>
					</view>
					<view class="area" v-for="(item,index) in scoreDetail.studentList">
						<view class="li">{{index+1}}</view>
						<view class="li li1">{{item.studentRealname}}</view>
						<view class="li li1" v-for="a in item.scoreList">{{a}}</view>
					</view>
				</view>
			</view>
		</view>
	</view>
	
</template>

<script setup>
import { ref , computed ,onMounted,watch} from 'vue';
import {useRouter} from 'vue-router';	
import {classList ,examList,examScoreList} from '/api/home.js';
import { showToast } from 'vant';
import { useStore } from 'vuex';

let columns = [];
const showPicker = ref(false);
const classAll = ref();
const activeClass = ref({});
const showQrcode = ref(false);
const store = useStore();

const myInfo = JSON.parse(uni.getStorageSync('my'));
const examArr = ref([]);
const showAll = ref(false);
const schoolName = ref();
onMounted(() =>{
	classList().then(res =>{
		if(res.code == 0){
			if(res.data.length > 0){
				classAll.value = res.data;
				activeClass.value = res.data[0];
				
				let list = [];
				res.data.forEach(e =>{
					list.push({ text: e.name, value: e.id})
				})
				columns = list;
				getExam();
			}
		}
	})
})

watch(showAll, (newValue, oldValue) => {
	store.dispatch('updateIsShow', newValue);
});

//获取考试列表
function getExam(){
	console.log(activeClass)
	examList({"classId": activeClass.value.id}).then(res =>{
		if(res.code == 0){
			examArr.value = res.data;
		}
	})
}

//获取考试成绩
const scoreDetail = ref({});
function detail(item){
	examScoreList({classId:activeClass.value.id,'examId':item.id}).then(res =>{
		if(res.code == 0){
			scoreDetail.value = res.data;
			scoreDetail.value.subjects1 = scoreDetail.value.exam.subjects.split(',');
			
			console.log(myInfo)
			if(myInfo.role == "teacher"){
				showAll.value = true;
			}else{
				showQrcode.value = true;
			}
		}
	})
}

//切换班级
function onChange(value){
	activeClass.value = classAll.value[value.selectedIndexes[0]];
	showPicker.value = false;
	getExam()
}

</script>

<style lang="scss" scoped>
	.score{
		height: 100%;
		
		.top{
			display: flex;
			justify-content: flex-end;
			position: relative;

			.tips{
				margin-right: 15px;
				margin-top: 15px;
				box-shadow: 0 0 8px 0 #f3f3f3;
				padding: 5px 10px;
				border-radius: 4px;
			}
		}
		.list{
			margin-top: 20px;
			padding: 0 15px 0 10px;
			.li{
				display: flex;
				border-bottom: 1px solid #f6f7fb;
				height: 56px;
				line-height: 56px;
				align-items: center;
				.btn{
					margin-left: auto;
					margin-right: 5px;
					font-size: 13px;
					color: #999999;
				}
				.icon_right{
					font-size: 12px;
					position: relative;
					top:0px;
				}
				.icon{
					font-size: 34px;
				}
				.x{
					margin-left: 10px;
					.name{
						height: 30px;
						line-height: 30px;
						font-size: 14px;
					}
					.time{
						height: 18px;
						line-height: 3px;
						font-size: 12px;
						color: #6A6A6A;
					}
				}
				
			}
		}
		::v-deep .qrcode_box{
			width: 649px;
			height: 526px;
			border-radius: 9px;
			background: none;
			margin-top: 80px;
			.van-dialog__content{
				.title{
					height: 55px;
					line-height: 55px;
					text-align: center;
					font-size: 16px;
					color: #000;
					border-bottom: 1px solid #EEEEEE;
				}
				.li{
					display: flex;
					border-bottom: 1px solid #EEEEEE;
					height: 52px;
					line-height: 52px;
					font-size: 16px;

					.name{
						width: 243px;
						text-align: center;
						border-right: 1px solid #EEEEEE;
					}
					.num{
						margin: 0 auto;
					}
				}
				.tip{
					height: 52px;
					text-align: center;
					line-height: 52px;
					color: #000;
					font-size: 12px;
				}
				.close{
					position: relative;
					text-align: center;
					font-size: 30px;
					padding-top: 15px;
				}
			
			}
		}
		.all{
			position: absolute;
			width: 100%;
			height: 100%;
			top: 0;
			left: 0;
			background: #fff;
			.title{
				height: 52px;
				display: flex;
				justify-content: center;
				align-items: center;
				position: relative;
				border-bottom: 1px solid #EEEEEE;
				.return{
					position: absolute;
					font-size: 30px;
					left: 10px;
				}
			}
			.border{
				padding: 31px 33px;
			}
			.table{
				border-left: 1px solid #EEEEEE;
				border-right: 1px solid #EEEEEE;
				.head,.area{
					border-bottom: 1px solid #EEEEEE;
					display: flex;
					.li{
						border-right: 1px solid #EEEEEE;
						min-width: 86px;
						height: 50px;
						line-height: 50px;
						text-align: center;
						font-size: 16px;
						color: #000;
					}
					.li1{
						width: 114px;
					}
				}
				.head{
					border-top: 1px solid #EEEEEE;
				}
			}
		}
	}
</style>