<template>
	<view class="schoolBox">
		<!-- 头像 -->
		<view class="info">
			<van-image
			  class="head"
			  :src="info.headUrl"
			/> 
			<view class="info_right">
				<view class="name">{{info.nickname || '未命名'}}</view>
				<view class="phone">{{info.mobile || '13588310149'}}</view>
				<view class="sf">老师</view>
			</view>
			<view class="add_class" @click="addShow = true">
				<van-icon class="icon" name="/static/assets/add_class.png" />
				新建班级
			</view>
		</view>
		
		<!-- 我的班级 -->
		<view class="my_class">
			<view class="class_li" v-for="item in list">
				<van-image
				  class="icon"
				  :src="'/static/assets/class.png'"
				/> 
				<view class="name" style="min-width:100px;">
					<view class="xxBg">{{item.name}}</view>
				</view>
				<view class="admin" style="min-width: 100px;">
					<view class="xxBg">班主任:{{item.headTeacher.realname}}</view>
				</view>
				<view class="num">
					<view class="xxBg">班级人数:{{item.studentCount}}人</view>
				</view>
				<view class="btn thin" @click="handleEditClick(item)">编辑</view>
			</view>
		</view>
		
		<!-- 新增班级 -->
		<van-dialog class="add_log" v-model:show="addShow" title="新建班级" show-cancel-button @confirm="addClass">
		  <view class="add_content">
		    <van-field v-model="classTile" placeholder="请输入班级名称" />
		  </view>
		</van-dialog>
	</view>
</template>

<script setup>
import { ref,onMounted } from 'vue';
import {useRouter} from 'vue-router';	
import studentDetailExercise from './student_detail.vue';
import { defineEmits } from 'vue';
import {classManageList , classManageSave ,getMyInfo} from '/api/home.js';
import { showToast , showLoadingToast ,showSuccessToast} from 'vant';

const info =ref({})
const emit = defineEmits(['change-component'])
const addShow = ref(false);
const classTile = ref("");
const list = ref([]);

onMounted(() =>{
	getClass();
	getInfo();
})

//获取班级列表
function getClass(){
	classManageList().then(res =>{
		if(res.code == 0){
			list.value = res.data;
		}else{
			showToast(res.msg)
		}
	})
}
//获取班主任信息
function getInfo(){
	getMyInfo().then(res =>{
		if(res.code == 0){
			info.value = res.data.user;
		}else{
			showToast(res.msg)
		}
	})
}



const emitChangeComponent = (component) => {
  // 向父组件发送事件请求，传递要切换的组件
	emit('change-component', component);
};

const handleEditClick = (item) => {
	uni.setStorageSync('class',JSON.stringify(item))
  // 发送事件请求，通知父组件切换组件
  emitChangeComponent(studentDetailExercise); // 例如，这里切换到作业批改组件
};

function addClass(){
	if(classTile){
		classManageSave({name:classTile.value}).then(res =>{
			if(res.code == 0){
				showSuccessToast('班级添加成功');
				getClass();
			}else{
				showToast(res.msg);
			}
			showPicker.value = false;
		})
	}
}

</script>

<style lang="scss" scoped>
	::v-deep .van-dialog__header{
		background: none;
		font-weight: 400;
	}
	.schoolBox{
		height: 100%;
		.xxBg{
			display: inline;
			background: #FCF3EE;
			padding: 2px 8px;
			border-radius: 6px;
		}
		.my_class{
			padding: 12px;
			.class_li{
				height: 56px;
				line-height: 56px;
				display: flex;
				font-size: 14px;
				font-weight: 400;
				align-items: center;
					border-bottom: 1px solid #f6f7fb;
				.icon{
					width: 30px;
					height: 30px;
					margin-right: 10px;
				}
				.name{
					margin-right: 40px;
				}
				.admin{
					margin-right: 40px;
				}
				.btn{
					margin-left: auto;
				    font-size: 12px;
				    background: #e0f8f1;
				    padding: 4px 8px;
				    height: 22px;
				    line-height: 15px;
				    font-weight: 400;
				    border-radius: 4px;
				    color: #00c9a4;
					
				}
			}
		}
	}
	.info{
		padding: 12px;
		position: relative;
		padding-left: 12px;
		border-bottom: 1px solid  #f8f8f8;
		.add_class{
			position: absolute;
			right: 12px;
			top: 12px;
			width: 120px;
			height: 32px;
			line-height: 32px;
			border-radius: 4px;
			background: #00c9a4;
			color: #e1f8f2;
			text-align: center;
			.icon{
				margin-right: 4px;
				position: relative;
				top: 4px;
				font-size: 20px;
			}
		}
		.head{
			width: 108px;
			height: 108px;
			border-radius:50%;
			overflow: hidden;
		}
		.info_right{
			position: absolute;
			height: 100%;
			top: 0;
			padding-left: 130px;
			padding-top: 36px;
			.name{
			    padding: 2px 0px;
			    border-radius: 20px;
			    color: #000;
			    font-size: 16px;
				.edit{
				    position: relative;
				    left: 7px;
				    top: -1px;
				    background: #00c9a4;
				    border-radius: 50%;
				    font-size: 14px;
				    width: 18px;
				    height: 18px;
				    color: #111;
				    text-align: center;
				    line-height: 18px;
	
				}
			}
			.phone{
				    margin: 7px 0;
				    font-size: 14px;
					font-weight: 400;
			}
			.sf{
				font-size: 12px;
				font-weight: 400;
				padding: 2px 10px;
				background: #e1f8f2;
				border-radius: 9px;
				display: inline-block;
			}
	
		}
	
	}
</style>