<template>
	<view class="play_content24">
		<view class="top">
		  <van-icon class="return" name="/static/assets/left1.png" @click="left" />
		</view>
		<!-- 信息栏 -->
		<view class="my_info">
			<view class="li"  @click="eHead =true">
				<view class="title">头像</view>
				<view class="avtor">
					<van-image
						width="40"
						height="40"
						:src="myInfo?.headUrl || '/static/assets/head.jpg'"
					/>
				</view>
				<van-icon class="icon_r" name="arrow" />
				<view class="btn" ></view>
			</view>
			<view class="li" @click="eName = true">
				<view class="title">昵称</view>
				<view class="text">
					{{myInfo?.nickname}}
				</view>
				 <van-icon class="icon_r" name="arrow" />
				 <view class="btn"></view>
			</view>
			<view class="li">
				<view class="title">姓名</view>
				<view class="text">
					{{myInfo?.realname}}
				</view>
			</view>
			<view class="li"  @click="showPicker = true" >
				<view class="title">性别</view>
				<view class="text">
					{{myInfo?.gender}}
				</view>
				 <van-icon class="icon_r" name="arrow" />
				 <view class="btn"></view>
			</view>
			<view class="li" @click="showDate = true">
				<view class="title">生日</view>
				<view class="text">
					{{myInfo?.birthday}}
				</view>
				 <van-icon class="icon_r" name="arrow" />
				 <view class="btn"   ></view>
			</view>
			<view class="li">
				<view class="title">身份</view>
				<view class="text">
					{{myInfo?.identity}}
				</view>
				 <!-- <van-icon class="icon_r" name="arrow" @click="showdIdentity = true" /> -->
			</view>
			<view class="li"  @click="shiming">
				<view class="title">实名认证</view>
				<view class="text" >
					{{myInfo?.verified}}
				</view>
				 <van-icon v-if="myInfo?.verified != '已认证'" class="icon_r" name="arrow"  />
				 <view class="btn"></view>
			</view>
			<view class="li"  @click="showCity = true">
				<view class="title">所在地区</view>
				<view class="text">
					{{myInfo?.province}}
				</view>
				 <van-icon class="icon_r" name="arrow"  />
				 <view class="btn"></view>
			</view>
			<view class="li"  @click="eScholl = true">
				<view class="title">所在学校</view>
				<view class="text">
					{{myInfo?.school}}
				</view>
				 <van-icon class="icon_r" name="arrow" />
				 <view class="btn" ></view>
			</view>
			<view class="li"  @click="eIntroduce = true">
				<view class="title">个人简介</view>
				<view class="text">
					{{myInfo?.introduce}}
				</view>
				 <van-icon class="icon_r" name="arrow"  />
				 <view class="btn"></view>
			</view>
			<view class="li" @click="openPasswordDialog">
				<view class="title">修改密码</view>
				<view class="text"></view>
				<van-icon class="icon_r" name="arrow" />
				<view class="btn"></view>
			</view>
		</view>
		
		<!-- 性别 -->
		<van-popup v-model:show="showPicker" round position="bottom">
		  <van-picker
		    :columns="columns"
		    @cancel="showPicker = false"
		    @confirm="onConfirm"
		  />
		</van-popup>
		
		<!-- 昵称 -->
		<van-dialog class="add_log" v-model:show="eName" title="修改昵称" show-cancel-button @confirm="editName">
		  <view class="add_content">
		    <van-field v-model="nameTitle" placeholder="请输入新昵称" />
		  </view>
		</van-dialog>
		
		<!-- 生日 -->
		<van-popup v-model:show="showDate" round position="bottom">
		  <van-date-picker
		    v-model="currentDate"
		    title="选择日期"
		    :min-date="minDate"
		    :max-date="maxDate"
			@cancel="showDate = false"
			@confirm="onConfirm2"
		  />
		</van-popup>
		
		<!-- 身份 -->
		<van-popup v-model:show="showdIdentity" round position="bottom">
		  <van-picker
		    :columns="columnsIdentity"
		    @cancel="showdIdentity = false"
		    @confirm="onConfirmIdentity"
		  />
		</van-popup>
		
		<!-- 省份 -->
		<van-popup v-model:show="showCity" round position="bottom">
		  <van-picker
		    :columns="columnsCity"
		    @cancel="showCity = false"
		    @confirm="onConfirmCity"
		  />
		</van-popup>
		
		<!-- 个人简介 -->
		<van-dialog class="add_log" v-model:show="eIntroduce" title="修改个人简介" show-cancel-button @confirm="editIntroduce">
		  <view class="add_content">
		    <van-field v-model="introduceTitle" placeholder="请输入个人简介" />
		  </view>
		</van-dialog>
		
		<!-- 头像 -->
		<van-dialog class="add_log edit_head" v-model:show="eHead" title="修改头像" show-cancel-button @confirm="editHead">
			<view class="head">
				<van-image
					style="border-radius: 50%;overflow: hidden;"
					width="200"
					height="200"
					:src="new_head || myInfo?.headUrl || '/static/assets/head.jpg'"
				/>
				<van-uploader class="upload" :after-read="afterRead">
				  <van-button icon="plus" type="primary">上传新头像</van-button>
				</van-uploader>
			</view>
		</van-dialog>
		
		<!-- 学校 -->
		<van-dialog class="add_log" v-model:show="eScholl" title="修改学校" show-cancel-button @confirm="editScholl">
		  <view class="add_content">
		    <van-field v-model="schollTitle" placeholder="请输入学校名称" />
		  </view>
		</van-dialog>

		<!-- 修改密码 -->
		<van-dialog
			class="add_log"
			v-model:show="showPasswordDialog"
			title="修改密码"
			show-cancel-button
			:before-close="beforePasswordClose"
		>
			<view class="add_content">
				<van-field v-model="oldPassword" type="password" placeholder="请输入原密码" />
				<van-field v-model="newPassword" type="password" placeholder="请输入新密码" />
				<van-field v-model="confirmPassword" type="password" placeholder="请再次输入新密码" />
			</view>
		</van-dialog>
	</view>

</template>

<script setup>
import { ref ,onMounted} from 'vue';
import { useRouter} from 'vue-router';
import {getMyInfo,editMyInfo,fileUpload,getCity,updatePassword} from '/api/home.js';
import { showToast , showLoadingToast} from 'vant';
import { useStore } from 'vuex';  // 引入 useStore

const store = useStore();  // 使用 useStore

const router = useRouter();

const myInfo = ref({});

function left() {
	console.log(history.state )
	if(history.state.back == "/verifie"){
		router.push({name:"personal"});
	}else{
		router.go(-1);
	}
}

getInfo();
function getInfo(){
	getMyInfo().then(res =>{
		if(res.code == 0){
			myInfo.value = res.data.user;
			store.dispatch('updateInfo', res.data.user);  // 更新 Vuex 中的 info 状态
		}else{
			showToast(res.msg);
		}
	})
}

//性别
const columns = [
      { text: '男', value: '男' },
      { text: '女', value: '女' },
    ];
const fieldValue = ref('');
const showPicker = ref(false);

const onConfirm = ({ selectedOptions }) => {
	editMyInfo({gender:selectedOptions[0].text}).then(res =>{
		if(res.code == 0){
			showToast('修改成功！');
			getInfo();
		}else{
			showToast(res.msg);
		}
		showPicker.value = false;
	})
};

//身份
const columnsIdentity = [
      { text: '学生', value: '学生' },
      { text: '老师', value: '老师' },
    ];
const IdentityValue = ref('');
const showdIdentity = ref(false);

const onConfirmIdentity = ({ selectedOptions }) => {
	editMyInfo({identity:selectedOptions[0].text}).then(res =>{
		if(res.code == 0){
			showToast('修改成功！');
			getInfo();
		}else{
			showToast(res.msg);
		}
		showdIdentity.value = false;
	})
};

//省份
let columnsCity = [];
getCity().then(res =>{
	columnsCity = [];
	res.data.forEach(item =>{
		columnsCity.push({ text: item.name, value: item.name })
	})
})
const showCity = ref(false);

const onConfirmCity = ({ selectedOptions }) => {
	editMyInfo({province:selectedOptions[0].text}).then(res =>{
		if(res.code == 0){
			showToast('修改成功！');
			getInfo();
		}else{
			showToast(res.msg);
		}
		showCity.value = false;
	})
};

//昵称
const eName = ref(false);
const nameTitle = ref('');

function editName(){
	if(nameTitle){
		editMyInfo({nickname:nameTitle.value}).then(res =>{
			if(res.code == 0){
				showToast('修改成功！');
				getInfo();
			}else{
				showToast(res.msg);
			}
			showPicker.value = false;
		})
	}
}

//学校
const eScholl = ref(false);
const schollTitle = ref('');

function editScholl(){
	if(nameTitle){
		editMyInfo({school:schollTitle.value}).then(res =>{
			if(res.code == 0){
				showToast('修改成功！');
				getInfo();
			}else{
				showToast(res.msg);
			}
			showPicker.value = false;
		})
	}
}

//生日
const showDate = ref(false);
const currentDate = ref(['2010', '01', '01']);
let minDate = new Date(1950, 0, 1);
let maxDate = new Date(2014, 12, 31);

function onConfirm2(){
	let params = currentDate.value[0]+'-'+currentDate.value[1]+'-'+currentDate.value[2];
	editMyInfo({birthday:params}).then(res =>{
		if(res.code == 0){
			showToast('修改成功！');
			getInfo();
		}else{
			showToast(res.msg);
		}
		showDate.value = false;
	})
}

//个人简介
const eIntroduce =ref(false);
const introduceTitle = ref('');

function editIntroduce(){
	if(introduceTitle.value){
		editMyInfo({introduce:introduceTitle.value}).then(res =>{
			if(res.code == 0){
				showToast('修改成功！');
				getInfo();
			}else{
				showToast(res.msg);
			}
			eIntroduce.value = false;
		})
	}

}

//头像
const eHead = ref(false);
const new_head =ref('');
function afterRead(file){
	const formData = new FormData();
	formData.append('file', file.file);
	let load = showLoadingToast({
	  message: '上传中...',
	  forbidClick: true,
	  loadingType: 'spinner',
	  duration:0,
	});
	fileUpload(formData).then(res => {
	  load.close();
	  if(res.code == 0){
		 new_head.value = res.data;
	  }else{
		  showToast(res.msg)
	  }
	}).catch(error => {
	  console.error(error);
	});
}

function editHead(){
	if(new_head.value){
		editMyInfo({headUrl:new_head.value}).then(res =>{
			if(res.code == 0){
				showToast('修改成功！');
				getInfo();
			}else{
				showToast(res.msg);
			}
			eIntroduce.value = false;
		})
	}
}

function shiming(){
	router.push({name:"verified",state:{id:myInfo.value.verified}})
}

const showPasswordDialog = ref(false);
const oldPassword = ref('');
const newPassword = ref('');
const confirmPassword = ref('');

function openPasswordDialog() {
	oldPassword.value = '';
	newPassword.value = '';
	confirmPassword.value = '';
	showPasswordDialog.value = true;
}

function beforePasswordClose(action) {
	if (action === 'cancel') {
		oldPassword.value = '';
		newPassword.value = '';
		confirmPassword.value = '';
		return true;
	}
	const oldPwd = oldPassword.value?.trim();
	const newPwd = newPassword.value?.trim();
	const confirmPwd = confirmPassword.value?.trim();
	if (!oldPwd) {
		showToast('请输入原密码');
		return false;
	}
	if (!newPwd) {
		showToast('请输入新密码');
		return false;
	}
	if (newPwd !== confirmPwd) {
		showToast('两次新密码不一致');
		return false;
	}
	if (newPwd === oldPwd) {
		showToast('新密码不能与旧密码相同');
		return false;
	}
	return updatePassword({ oldPassword: oldPwd, newPassword: newPwd })
		.then((res) => {
			if (res.code === 0) {
				showToast('修改成功');
				oldPassword.value = '';
				newPassword.value = '';
				confirmPassword.value = '';
				return true;
			}
			showToast(res.msg || '修改失败');
			return false;
		})
		.catch(() => {
			showToast('网络异常，请稍后重试');
			return false;
		});
}
</script>

<style lang="scss" scoped>
	::v-deep .van-dialog__header{
		background: none;
		font-weight: 400;
	}
	::v-deep .edit_head{
		.van-dialog__footer{
			position: absolute;
			bottom: 0;
			width: 100%;
		}
		.head{
			text-align: center;
			margin-top:50px;
		}
		.upload{
			width: 100%;
			text-align: center;
			display: flex;
			justify-content: center;
			margin-top: 30px;
			margin-bottom: 5px;
			.van-button--normal{
				background: #00c9a4;
				color: #fff;
				border: none;
				.van-button__content{
					color: #fff;
				}
			}
		}
	}
	.add_content{
		border: 1px solid #f2f2f4;
	}
	.play_content24{
		height: 100%;
		position: relative;
		.top{
			height: 44px;
			border-radius: 9px;
			display: flex;
			align-items: center;
			padding-left: 12px;
			background: #fff;
		}
		.return {
		  font-size: 30px;
		}
		.my_info{
			height: calc(100% - 54px);
			position: relative;
			padding: 20px 25px;
			border-radius: 9px;
			background: #fff;
			margin-top: 10px;
			.li{
				    position: relative;
				    display: flex;
				    justify-content: flex-end;
				    border-bottom: 1px solid #f2f2f4;
				    height: 56px;
				    line-height: 56px;
				    align-items: center;
				.title{
					position: absolute;
					    left: 0;
					    font-size: 15px;
					    color: #353535;
					    letter-spacing: 1px;
						font-family: 'Harmony_Regular';
				}
				.icon_r{
					font-size: 18px;
					color: #6b6b6b;
					font-weight: 400;
					position: relative;
					top: -1px;
					font-weight: 400;
				}
				.text{
					font-size: 14px;
					color: #999999;
					margin-right: 10px;
					font-family: 'Harmony_Regular';
				}
				.avtor{
					.van-image{
						border-radius: 50%;
						overflow: hidden;
						position: relative;
						top: 7px;
					}
					margin-right: 10px;
				}
				.btn{
					position: absolute;
					width: 100px;
					height: 50px;
				}
			}
			
		}

	}
</style>
