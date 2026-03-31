<template>
	<view class="schoolBox">
		<!-- 头像 -->
		<view class="info">
			<van-icon class="return" name="arrow-left" style="font-size: 22px;height: 22px;position: relative;margin-right:10px;left: -6px;" @click="handleEditClick" />
			<view class="tips"  @click="showPicker = !showPicker">{{classInfo.name}} <van-icon style="margin-left: 5px;" :name="showPicker?'arrow-up':'arrow-down'" /></view>
			<view class="tips">班主任: {{classInfo.headTeacher.realname}}</view>
			<view class="tips">班级人数: {{classInfo.studentCount}}人</view>
			<view class="qrcode_class add_class" @click="showQr">
				<van-icon class="icon" name="/static/assets/qrcode_class.png" />
				班级二维码
			</view>
		</view>
		
		<!-- 我的班级 -->
		<view class="teacher my_class">
			<view class="title">任课老师</view>
			<view class="class_li" v-for="item in classList.teacherList">
				<van-image
				  class="icon"
				  :src="item.headUrl"
				/> 
				<view class="name">{{item.realname || item.nickname}}</view>
				<view class="kc">{{item.realname == classInfo.headTeacher.realname?"班主任":"任课老师"}}</view>
			</view>
		</view>
		<view class="my_class" style="padding:16px 6px;">
			<view class="title" style="margin-left: 10px;">班级学生</view>
			<van-grid :gutter="10" :column-num="8" :border='false'>
				    <van-grid-item  v-for="item in classList.studentList">
						<van-swipe-cell class="cell">
							<view class="class_li">
								<van-image
								  class="icon"
								  :src="item.headUrl || '/static/assets/head.jpg'"
								/> 
								<view class="name">{{item.realname || item.nickname}} </view>
								
							</view>
							<template #right>
							  <van-icon class="del" @click="delD(item)" style="font-size: 16px;margin-left: 15px;" name="/static/assets/delIcon.png" />
							</template>

						</van-swipe-cell>
				    </van-grid-item>
			</van-grid>
			
		</view>
		
		<!-- 班级选择 -->
		<van-popup v-model:show="showPicker" round position="bottom">
		  <van-picker
		    :columns="columns"
		    @cancel="showPicker = false"
		    @confirm="onConfirm"
		  />
		</van-popup>
		
		<!-- 二维码弹窗 -->
		<van-dialog class="qrcode_box" v-model:show="showQrcode" :showConfirmButton='false'>
			<view style="background: #fff;border-radius:20px;">
				<view class="name">{{classInfo.name}}的二维码</view>
				<view style="text-align: center;">
					<van-image
						class="img"
						width="260"
						height="260"
						:src="qrImg"
					/>
				</view>
				<view class="btn">保存到相册</view>
				<view class="bottom">
					<view>使用场景</view>
					<view>学生可通过扫描当前二维码加入本班级。</view>
				</view>
			</view>
			<view class="close">
				<van-icon @click="showQrcode = false" name="/static/assets/bg_close.jpg" />
			</view>
		</van-dialog>
	</view>
</template>

<script setup>
import { ref} from 'vue';
import {useRouter} from 'vue-router';	
import { defineEmits } from 'vue';
import studentExercise from './student.vue';
import { showToast , showConfirmDialog ,showLoadingToast, Toast} from 'vant';
import {getMyInfo,classManageQrcode,classManageMemberList,classManageList,classManageMemberRemove} from '/api/home.js';

const info =ref({})
const showQrcode =ref(false);
const emit = defineEmits(['change-component'])
const classList = ref({});

let columns = []
const fieldValue = ref('');
const showPicker = ref(false);
const classAll = ref('');

const qrImg = ref('');
function showQr(){
	classManageQrcode({'id':classInfo.value.id}).then(res =>{
		if(res.code == 0){
			qrImg.value = res.data;
			showQrcode.value = true;
		}else{
			showToast(res.msg);
		}
	})
}

//获取班级列表
classManageList().then(res =>{
	if(res.code == 0){
		classAll.value = res.data;
		let list = [];
		res.data.forEach(e =>{
			list.push({ text: e.name, value: e.id})
		})
		columns = list;
	}else{
		showToast(res.msg)
	}
})

//获取班级信息
const classInfo = ref(JSON.parse(uni.getStorageSync("class")))
getList(classInfo.value.id)

//获取班级成员
function getList(id){
	classManageMemberList({'id':id}).then(res =>{
		classList.value = res.data;
	})
}

const emitChangeComponent = (component) => {
  // 向父组件发送事件请求，传递要切换的组件
	emit('change-component', component);
};

const handleEditClick = () => {
  // 发送事件请求，通知父组件切换组件
  emitChangeComponent(studentExercise); // 例如，这里切换到作业批改组件
};

//切换班级
function onConfirm(value){
	classInfo.value = classAll.value[value.selectedIndexes[0]];
	getList(classInfo.value.id)
	showPicker.value = false;
}

//移除学生
function delD(item){
	showConfirmDialog({
	  confirmButtonText:"移除",
	  confirmButtonColor:"#ff004a",
	  message:
	    '是否确认将该学生移除本班？',
	})
	  .then(() => {
	    // on confirm
		classManageMemberRemove({classId:classInfo.value.id,userId:item.id}).then(res =>{
			if(res.code == 0){
				showToast(item.realname+'已被移出本班级')
				getList(classInfo.value.id)
			}else{
				showToast(res.msg)
			}
		})
	  })
	  .catch(() => {
	    // on cancel
	  });
}
</script>

<style lang="scss" scoped>
	::v-deep .van-swipe-cell{
		width: 100%;
		height: 36px;
		border-radius: 36px;
	}
	::v-deep .van-swipe-cell__right{
		height: 36px;
		display: flex;
		align-items: center;
	}
	::v-deep .qrcode_box{
		width: 70%;
		background: none;
		.van-dialog__content{
			.name{
				text-align: center;
			    font-size: 20px;
			    padding: 40px 0 16px 0;
			}
			.sf{
				text-align: center;
				    padding: 5px 0;
				    font-size: 12px;
				    color: #888;
				    width: 90px;
				    margin: 0 auto;
				    background: #dcf7f0;
				    border-radius: 50px;
				    margin-bottom: 6px;
			}
			.phone{
				text-align: center;
				padding: 5px 0;
				font-size: 14px;
				color: #888;
			}
			.img{
				margin: 0 auto;
			}
			.btn{
			    margin: 0 auto;
			    background: #00c9a4;
			    color: #fff;
			    font-size: 16px;
			    padding: 5px 16px;
			    border-radius: 16px;
			    width: 140px;
			    text-align: center;
			    margin-top: 10px;
			}
			.bottom{
				border-top: 1px solid #e9e9e9;
				display: flex;
				justify-content: center;
				flex-direction: column;
				align-items: center;
				margin-top: 20px;
				padding-bottom: 20px;
				padding-top: 10px;
				view{
					height: 30px;
					line-height: 30px;
					color: #888;
				}
				
				
			}
			.close{
				position: relative;
				text-align: center;
				font-size: 30px;
				padding-top: 15px;
			}
		
		}
	}
	.schoolBox{
		height: 100%;
		
		.my_class{
			padding: 16px;
			::v-deep .van-grid-item__content{
				background: none;
				padding: 0;
			}
			.title{
				position: relative;
				padding-left: 6px;
				margin-bottom: 10px;
			}
			.title::before{
				content: "";
				position: absolute;
				left: 0;
				width: 3px;
				height: 14px;
				background: #00c9a4;
				border-radius: 4px;
				top: 2px;
			}
			.class_li{
				height: 36px;
				line-height: 36px;
				display: inline-block;
				width: 100%;
				font-size: 14px;
				font-weight: 400;
				align-items: center;
				position: relative;
				background: #f6f7fb;
				margin-bottom: 16px;
				border-radius: 30px;
				.icon{
				    width: 26px;
				    height: 26px;
				    margin-right: 10px;
				    border-radius: 50%;
				    margin-left: 8px;
				    margin-top: 5px;
					overflow: hidden;
				}
				.name{
					position: absolute;
					left: 40px;
					top: 0px;
					font-weight: 500;
				}
			}
			.class_li:nth-child(8n){
				margin-right: 0;
			}
		}
		.teacher{
			border-bottom: 1px solid #f8f8f8;
			.class_li{
				height: 50px;
				width: 150px;
				margin-right: 15px;
				.icon{
					width: 40px;
					height: 40px;
					margin-top: 5px;
					margin-left: 5px;
				}
				.name{
					left: 54px;
					font-size: 14px;
				}
				.kc{
					position: absolute;
					left: 54px;
					top: 16px;
					font-size: 10px;
					color: #696969;
				}
			}
		}
	}
	.info{
		padding: 12px;
		padding-top: 26px;
		padding-bottom: 26px;
		position: relative;
		border-bottom: 1px solid  #f8f8f8;
		overflow: hidden;
		display: flex;
		align-items: center;
		.tips{
			margin-right: 20px;
			background: #f6f7fb;
			padding: 4px 12px;
			font-size: 15px;
			border-radius: 4px;
			font-weight: 500;
		}
		.left_go{
			position: absolute;
		    width: 30px;
		    height: 30px;
		    text-align: center;
		    line-height: 30px;
		    border-radius: 50%;
		    background: #e1f8f2;
		    left: -2px;
		    top: -1px;
		}
		.add_class{
			position: absolute;
			right: 20px;
			top: 20px;
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
		.qrcode_class{
			right: 12px;
			width: 140px;
		}
		.head{
			width: 108px;
			height: 108px;
			border-radius:50%;
			overflow: hidden;
			border:1px solid #6b6b6b;
		}
		.info_right{
			position: absolute;
			height: 100%;
			top: 0;
			padding-left: 130px;
			padding-top: 36px;
			.name{
			    background: #111;
			    padding: 2px 12px;
			    border-radius: 20px;
			    color: #e9e9e9;
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