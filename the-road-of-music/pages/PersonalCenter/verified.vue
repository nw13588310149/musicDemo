<template>
	<view class="play_content24">
		<view class="top">
		  <van-icon class="return" name="/static/assets/goback.jpg" @click="left" />
		  实名认证
		</view>
		<!-- 信息栏 -->
		<view class="my_info">
			<!-- 步骤条 -->
			<van-steps :active="active" class="bzt">
			  <van-step>开始认证</van-step>
			  <van-step>上传资料</van-step>
			  <van-step>资料审核</van-step>
			  <van-step>审核结束</van-step>
			</van-steps>
			
			<!-- 内容栏 -->
			<view class="info info1" v-if="active == 0">
				<view class="box"  @click="change(1)">
					<van-icon class="return" name="/static/assets/student_c.png" />
					<view class="btn">
						<van-icon class="icon" :name="sf==0?'/static/assets/checked.png':'/static/assets/check.png'" />
						学生
					</view>
				</view>
				<view class="box"  @click="change(2)">
					<van-icon class="return" name="/static/assets/teacher_c.png" />
					<view class="btn">
						<van-icon class="icon" :name="sf==1?'/static/assets/checked.png':'/static/assets/check.png'" />
						老师
					</view>
				</view>
			</view>
			<view class="next" @click="next"  v-if="active == 0">下一步</view>
			<view class="info info2" :style="{marginTop:sf==1?'30px':'15%'}" v-if="active == 1">
				<view v-if="sf == 0">
					<view class="input">
						<van-field
						  v-model="username"
						  left-icon="/static/assets/login_phone.png"
						  placeholder="请输入姓名"
						/>
					</view>
					<view class="input">
						<van-field
						  v-model="idCard"
						  left-icon="/static/assets/login_phone.png"
						  placeholder="请输入身份证号码"
						/>
					</view>
				</view>
				<view v-if="sf == 1">
					<view class="sfBox">
						<view class="input">
							<van-field
							  v-model="username"
							  left-icon="/static/assets/login_phone.png"
							  placeholder="请输入姓名"
							/>
						</view>
						<view class="input cent">
							<van-field
							  v-model="idCard"
							  left-icon="/static/assets/login_phone.png"
							  placeholder="请输入身份证号码"
							/>
						</view>
						<view class="input" style="overflow: visible;">
<!-- 							<select v-model="value" class="select">
								<option :value="item.value" v-for="(item,index) in option">{{item.text}}</option>
							</select> -->
							<van-field
							  v-model="value"
							  left-icon="/static/assets/login_phone.png"
							  placeholder="请输入学校ID"
							/>
							<view class="tips" style="position: relative;top: -8px;color: #00c9a4;">提示:请准确输入学校ID,若无学校可填写 音乐之路</view>
						</view>
					</view>
					
					<view class="scBox" >
						<view class="card1" :class="{hide:fileList?.length>0}">
							<van-uploader v-model="fileList" :after-read="afterRead" />
						</view>
						<view class="card2" :class="{hide:fileList1?.length>0}">
							<van-uploader v-model="fileList1" :after-read="afterRead2" />
						</view>
					</view>
					<view class="title">上传身份证照片要求</view>
					<view class="tips" >
						请上传清晰彩色完整的原件照片,身份证各项信息及头像清晰可见容易识别;证件必须真实拍摄，不能使用复印件,图片大小不超过4M。上传身份证照片示例
					</view>
				</view>
				
				
				<view class="btnBox">
					<view class="btn go" @click="go()">上一步</view>
					<view class="btn" @click="submit">确认上传</view>
				</view>
			</view>
			<view class="info info2 info3" :style="{marginTop:sf==1?'30px':'30px'}" v-if="active == 2">
				<van-icon class="icon" name="/static/assets/ver2.png" />
				<view class="text">快马加鞭审核中...</view>
			</view>
			<view class="info info2 info3" :style="{marginTop:sf==1?'30px':'30px'}" v-if="active == 3">
				<van-icon class="icon" name="/static/assets/ver_sucess.png" />
				<view class="text">审核成功</view>
			</view>
		</view>
	</view>

</template>

<script setup>
import { ref ,onMounted} from 'vue';
import { useRouter} from 'vue-router';
import { showToast,showLoadingToast,showConfirmDialog} from 'vant';
import {fileUpload , submitCertification ,schoolList} from '/api/home.js';
import { forEach } from 'lodash';

const router = useRouter();
const url = ref({});
const active = ref(0);
const username = ref();
const idCard = ref();
const fileList = ref();
const fileList1 = ref();
const value = ref();
const option = ref([
	{text:"请选择所属学校",value:0}
])

const verifi = history.state.id;

if(verifi == "已认证" || verifi == "认证失败"){
	active.value = 3
}else if(verifi == "审核中"){
	active.value = 0
}

function left() {
  router.push({name:"info"});
}

const sf = ref(-1)
const sList = ref([]);
function next(){
	if(sf.value == -1){
		showToast("请先选择要认证的身份")
		return false;
	}
	
	if(sf.value == 1){
		schoolList().then(res =>{
			if(res.code == 0){
				sList.value = res.data;
				let arr = [{text:"请选择所属学校",value:0}];
				res.data.forEach(e =>{
					arr.push({text:e.name,value:e.id})
				})
				option.value = arr;
			}
		})
	}
	
	active.value += 1;
}

function go(){
	username.value = "";
	idCard.value = "";
	active.value -= 1;
}

function change(num){
	if(num == 1){
		if(sf.value == 0){
			sf.value = -1
		}else{
			sf.value = 0
		}
	}else{
		if(sf.value == 1){
			sf.value = -1
		}else{
			sf.value = 1
		}
	}
}

const card1 = ref();
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
		 card1.value = res.data;
	  }else{
		  showToast(res.msg)
	  }
	}).catch(error => {
	  console.error(error);
	});
}
const card2 = ref();
function afterRead2(file){
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
		 card2.value = res.data;
	  }else{
		  showToast(res.msg)
	  }
	}).catch(error => {
	  console.error(error);
	});
}

function submit(){
	if(sf.value == 0){
		if(!username.value){
			showToast('请输入姓名');
			return false;
		}
		if(!idCard.value){
			showToast('请输入身份证号码');
			return false;
		}
		
		showConfirmDialog({
		  confirmButtonText:"提交",
		  confirmButtonColor:"#ff004a",
		  message:
		    '资料上传后不可更改，请仔细核对！',
		})
		  .then(() => {
		    // on confirm
			let param = {
				"idcard": idCard.value,
				"nationalImg": "",
				"portraitImg": "",
				"realname": username.value,
				"role":'student',
				"schoolId":0
			}
			submitCertification(param).then(res =>{
				if(res.code == 0){
					active.value += 1;
					setTimeout(function(){
						active.value += 1;
					},2000)
				}else{
					showToast(res.msg)
				}
			})
		  })
		  .catch(() => {
		    // on cancel
		  });
		
	}else if(sf.value == 1){
		if(!username.value){
			showToast('请输入姓名');
			return false;
		}
		if(!idCard.value){
			showToast('请输入身份证号码');
			return false;
		}
		if(value.value == ""){
			showToast('请先填写所属学校ID');
			return false;
		}
		let isY = false;
		let sId = "";
		sList.value.forEach(e =>{
			if(e.id == value.value){
				isY = true;
				sId = e.id;
			}else if(value.value == "音乐之路"){
				isY = true;
				sId = 1111;
			}
		})
		if(!isY){
			showToast('暂无该学校，请联系我们合作');
			return false;
		}
		
		
		if(!card2.value || !card1.value){
			showToast('请上传完身份证照片');
			return false;
		}
		
		showConfirmDialog({
		  confirmButtonText:"提交",
		  confirmButtonColor:"#ff004a",
		  message:
		    '资料上传后不可更改，请仔细核对！',
		})
		  .then(() => {
		    // on confirm
			let param = {
				"idcard": idCard.value,
				"nationalImg": card2.value,
				"portraitImg": card1.value,
				"realname": username.value,
				"role":'teacher',
				"schoolId":sId
			}
			submitCertification(param).then(res =>{
				if(res.code == 0){
					active.value += 1;
					
				}else{
					showToast(res.msg)
				}
			})
			
		  })
		  .catch(() => {
		    // on cancel
		  });
	}
}
</script>

<style lang="scss" scoped>
	::v-deep .van-steps{
		overflow: visible;
	}
	::v-deep .van-step__circle{
		width: 18px;
		height: 18px;
		background-color: #D9D9D9;
	}
	::v-deep .van-step__line{
		height: 7px;
		top: 27px;
	}
	::v-deep .van-step--horizontal .van-step__icon{
		font-size: 20px;
		position: relative;
		left: -1px;
		
	}
	::v-deep .van-step__icon--active,::v-deep  .van-step__title--active,::v-deep  .van-step__icon--finish,::v-deep  .van-step__title--finish{
		color: #00c9a4;
	}
	::v-deep .van-step--horizontal .van-step__circle-container{
		background: none;
	}
	::v-deep .van-step--horizontal:first-child .van-step__title{
		margin-left: -19px;
	}
	::v-deep .van-step--horizontal .van-step__title{
		margin-left: 8px;
	}
	::v-deep .van-step--horizontal:last-child:not(:first-child) .van-step__title{
		position: relative;
		left: 34px;
	}
	::v-deep .van-step--finish .van-step__circle, ::v-deep .van-step--finish .van-step__line{
		background-color: #00c9a4;
	}
	::v-deep .van-step--horizontal .van-step__title{
		position: relative;
		top: 44px;
		font-size: 14px;
	}
	::v-deep .van-step--horizontal .van-step__circle-container{
		left:calc(var(--van-padding-xs) * -1.15)
	}
	::v-deep .van-step--horizontal:last-child:not(:first-child) .van-step__circle-container {
    right: -23px;
	}
	.play_content24{
		height: 100%;
		position: relative;
		background: #fff;
		border-radius: 9px;
		padding: 0 4px;
		.top{
			padding: 0 6px;
			height: 44px;
			display: flex;
			align-items: center;
			border-bottom: 1px solid #eeeeee;
			justify-content: center;
			font-size: 18px;
			.return {
			  font-size: 30px;
			  position: absolute;
			  left: 10px;
			}
		}
		
		.my_info{
			height: calc(100% - 59px);
			position: relative;
			padding: 25px;
			border-radius: 14px;
			background: #fff;
			margin-top: 15px;
			.bzt{
				width: 73%;
				margin: 0 auto;
				position: relative;
				top: -33px;
			}
			.info{
				display: flex;
				margin-top: 10%;
				.box{
					width: 50%;
					display: flex;
					align-items: center;
					justify-content: center;
					flex-direction: column;
					.return{
						font-size: 278px;
					}
					.btn{
						margin-top: 30px;
						color: #111;
						font-size: 16px;
						padding: 10px 20px;
						border-radius: 9px;
						display: flex;
						justify-content: center;
						align-items: center;
						width: 165px;
						height: 54px;
						.icon{
							margin-right: 17px;
							font-size: 23px;
						}
					}
				}
			}
			.next{
				    width: 120px;
				    height: 40px;
				    border-radius: 40px;
				    background: #00c9a4;
				    color: #fff;
				    font-size: 18px;
				    text-align: center;
				    line-height: 40px;
				    margin: 0 auto;
					margin-top: 40px;
			}
			.info1{
				padding: 0 100px;
			}
			.info2{
				display: block;
				.input{
					border: 1px solid #f3f3f3;
					margin-bottom: 15px;
					border-radius: 4px;
					overflow: hidden;
					::v-deep .van-icon{
						position: relative;
						top: 3px;
					}
					height: 46px;
					.select{
						width: 100%;
						height: 100%;
						border: none;
						padding: 0 12px;
					}
				}
				.btnBox{
					position: absolute;
					width: 100%;
					bottom: 60px;
					display: flex;
					justify-content: center;
					.btn{
						width: 120px;
						    height: 40px;
						    border-radius: 40px;
						    background: #00c9a4;
						    color: #fff;
						    font-size: 18px;
						    text-align: center;
						    line-height: 40px;
						    margin: 0 20px;
					}
					.go{
						background: #fff;
						border: 1px solid #00c9a4;
						color: #00c9a4;
					}
				}
				.scBox{
					display: flex;
					justify-content: center;
					.card1 ,.card2{
						margin: 10px 20px;
					}
					.hide{
						::v-deep .van-uploader__upload{
							display: none;
						}
					}
					::v-deep .van-uploader__upload{
						width: 272px;
						height: 163px;
					}
					::v-deep .van-uploader__upload-icon{
						display: none;
					}
					.card1 ::v-deep .van-uploader__upload{
						background: url(/static/assets/card1.png) no-repeat;
						background-size: contain;
					}
					.card1 ::v-deep .van-uploader__upload::after{
						content: "上传人像页照片";
						position: relative;
						top: 60px;
						font-size: 12px;
					}
					.card2 ::v-deep .van-uploader__upload{
						background: url(/static/assets/card2.png) no-repeat;
						background-size: contain;
					}
					.card2 ::v-deep .van-uploader__upload::after{
						content: "上传国徽页照片";
						position: relative;
						top: 60px;
						font-size: 12px;
					}
					::v-deep .van-uploader__preview-image{
						width: 272px;
						height: 163px;
					}
				}
				.title{
					color: #C2C2C2;
					font-size: 16px;
					position: relative;
					padding-left: 10px;
					font-weight: 400;
					font-family: 'Harmony_Light';
					margin-top: 45px;
				}
				.title::before{
					content: "";
					width: 3px;
					height: 12px;
					border-radius: 3px;
					background: #00c9a4;
					position: absolute;
					left: 0px;
					top: 4px;
				}
				.tips{
					margin-top: 15px;
					color: #C2C2C2;
					font-size: 12px;
					font-family: 'Harmony_Light';
					
				}
			}
			.info3{
				display:  flex;
				justify-content: center;
				padding-top: 20px;
				align-items: center;
				flex-direction: column;
				.icon{
					font-size: 400px;
				}
				.text{
					color: #00c9a4;
				}
			}
			.sfBox{
				display: flex;
				margin-bottom: 40px;
				.input{
					width: 32%;
					
				}
				.cent{
					margin: 0 2%;
				}
				.select{
					color: #969799;
					-webkit-appearance: none;
					-moz-appearance: none;
					appearance: none;
				}
				
			
			}
			
		}

	}
	::v-deep .van-field__control::-webkit-input-placeholder {
	color:#969799;
	}
</style>
