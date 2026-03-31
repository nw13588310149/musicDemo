<template>
  <view class="app-container2">
	<!-- 左侧导航 -->
    <view class="sidebar">
	
	  <!-- 列表滚动 -->
	  <view class="scroll over_y">
		  <view
		  class="sidebar-item"
		  v-for="(item, index) in navItems"
		    :key="index"
		    @click="onSelectNavItem(index,item)">
		  		<van-swipe-cell>
		  		<view class="btn" :class="{'active':activeSidebar == index}">
		  			<van-icon class="icon" name="/static/assets/kj_navIcon.png"/>
		  			<view class="title">
		  				<view class="text">{{item.name}}</view>
		  				<view class="num thin">已储存{{item.count}}个文件</view>
		  			</view>
		  		</view>
		  		  <template #right>
		  		    <van-icon class="del" style="font-size: 20px;" @click="del(item)" name="/static/assets/delIcon2.png" />
		  		  </template>
		  		</van-swipe-cell>
		  </view>
	  </view>

	  <!-- 新增分类 -->
	  <view class="add_box"  @click="add()">
		<view class="van_button"><van-icon class="add_class" name="/static/assets/add_class.png"/>添加分类</view> 
	  </view>
    </view>

    <!-- 这里将是主体内容 -->
    <view class="content">
		<view class="top">
			<view class="add_kj" @click="add_kj()"><van-icon name="/static/assets/kejianAdd.png" style="margin-right: 6px;font-size: 24px;"/>上传课件</view>
		</view>
		<!-- 内容列表 -->
		<van-empty description="暂无课件,请上传!" v-if="listArr.length == 0" style="height: calc(100% - 50px);" image="/static/assets/empty_list.png" :image-size="[260, 260]"/>
		<van-grid :gutter="12" :column-num="3" :border='false'>
		    <van-grid-item v-for="(item,value) in listArr" :key="value" >
		      <view class="item-top">
				  <view class="text">{{item.title}}</view>
				  <view class="top-right" style="top: -2px;display: flex;justify-content: center;align-items: center;" v-if="item.param1 == 2">
					  <van-icon name="/static/assets/page.png" style="font-size: 20px;margin-right: 2px;margin-top: -2px;"/>
					  {{JSON.parse(item.param3).length}}页
				  </view>
				  <view class="top-right" v-if="item.param1 == 1">
				  		<van-icon @click="playMusic(item)" :name="!item.isPlaying?'/static/assets/jpq_play.jpg':'/static/assets/jpg_stop1.jpg'" style="font-size: 30px;position: relative;top: -4px;"/>
				  </view>
				  <view class="top-right" v-if="item.param1 == 3">
				  		<van-icon @click="playMusic(item)" :name="!item.isPlaying?'/static/assets/jpq_play.jpg':'/static/assets/jpg_stop1.jpg'" style="font-size: 30px;position: relative;top: -4px;"/>
				  </view>
			  </view>
			  <view class="item-bottom">
				  <van-swipe-cell class="cell">
				  <view @click="go(item)" style="color: #6A6A6A;width: 60%;font-size: 14px;" class="thin"><van-icon class="icon1"  name="/static/assets/kj_ckxq.png" />查看课件</view>
				  <van-icon class="icon_r" @click="fenxiang(item)"  name="/static/assets/kejian_nav2.png" />
				    <template #right>
				      <van-icon class="del" @click="delD(item)" style="font-size: 20px;margin-left: 18px;margin-top: -1px;" name="/static/assets/delIcon.png" />
				    </template>
				  </van-swipe-cell>

			  </view>
		    </van-grid-item>
		</van-grid>
	</view>
	
	<!-- 新建目录 -->
	<van-dialog class="add_log" v-model:show="addShow" title="新建分类" show-cancel-button @confirm="addMl">
	  <view class="kjBox2" style="padding: 10px 0px;">
	    <van-field v-model="mlTitle" placeholder="请输入分类名称" style="border-radius: 30px;box-shadow: 0 0 8px 0 #f3f3f3;"/>
	  </view>
	</van-dialog>
	
	<!-- 上传课件 -->
	<van-dialog :before-close='onBeforeClose' class="add_log add-box" v-model:show="addKjBox" title="上传课件" show-cancel-button @confirm="addMl2">
	  <view class="kjBox">
		<view class="title">课件标题</view>
	    <van-field class="input_box" v-model="mlTitle2" placeholder="请输入课件标题" />
		<view class="title">选择分类</view>
		<van-radio-group v-model="checked" shape="dot" class="group">
		  <van-radio name="1" checked-color="#00c9a4">音频</van-radio>
		  <van-radio name="2" checked-color="#00c9a4">谱例</van-radio>
		  <van-radio name="3" checked-color="#00c9a4">课件</van-radio>
		</van-radio-group>
		<view class="title" style="margin-top: 20px;margin-bottom: 16px;">上传文件</view>
		<!-- 音频上传 -->
		<van-field class="input_box" v-if="checked == 1 || checked == 3" v-model="voice_url"  placeholder="请输入音频链接" />
		<van-uploader v-if="checked == 1 || checked == 3" accept=".mp3,.WAV,.FLAC,.APE,.AAC,.Ogg" :after-read="afterRead">
		  <van-button class="scBtn" icon="plus" type="primary" style="background: #00c9a4;border: none;">上传文件</van-button>
		</van-uploader>
		<!-- 图片上传 -->
		<view style="margin-top: 10px;">
			<van-uploader v-if="checked == 2 || checked == 3" v-model="fileList" multiple :after-read="afterRead2"/>
		</view>
	  </view>
	</van-dialog>
	
	<!-- 分享课件 -->
	<van-popup class="fxLeftBox"  v-model:show="showL" position="left" style="width: 50%;height: 100%;" overlay-class="fxLeftOver">
		<view class="fxLeft">
			<view class="fxLeft_title">
				<view class="flex_return" @click="showL = false">
					<van-icon
					  class="returnIcon"
					  :name="'/static/assets/qunL.png'"
					/> 
					<view class="text">返回</view>
				</view>
			</view>
			<view class="fxContent">
				<view class="fxTitle">
					您即将分享的课件: 
					<view class="fxTitleName">{{fxItem.title}}</view>
				</view>
				<view class="fxList">
					您的班级群: 
					<view class="fxLi" v-for="item in classItem" @click="item.isCheck = !item.isCheck">
						<van-icon
						  class="fxLiIcon"
						  :name="'/static/assets/class.png'"
						/> 
						<view class="fxLiname">{{item.name}}</view>
						<van-icon
						  class="fxLiCheck"
						  :name="item.isCheck?'/static/assets/checked.png':'/static/assets/check.png'"
						/> 
					</view>
				</view>
				<view class="fxBtn">
					<view class="fxBBtn" @click="fasong">发送</view>
				</view>
			</view>
			
			
		</view>
	</van-popup>
  </view>
</template>

<script setup>
import { ref ,onBeforeUnmount } from 'vue';
import {sendMsg,getcoursewareList,addcoursewareList,delcoursewareList,fileUpload,addCourseware,getCourseware,delCourseware,classList} from '/api/home.js';
import { showToast , showConfirmDialog ,showLoadingToast, Toast} from 'vant';
import {useRouter} from 'vue-router';

const router = useRouter();

const navItems = ref([]);
const activeSidebar = ref(0);
const searchQuery = ref('');
const addShow = ref(false);
const mlTitle = ref("");
const mlTitle2 = ref("");
const activeDel = ref(-1);
const addKjBox = ref(false);
const checked = ref('1');
const showL = ref(false);
const voice_url = ref('');
const fileList = ref([]);
const navId = ref(12);
const listArr = ref([]);
const activeId = ref('');

const fxItem = ref({});
const classItem = ref([]);
function fenxiang(item){
	classList().then(res =>{
		if(res.code == 0){
			showL.value = true;
			fxItem.value = item;
			classItem.value = res.data;
		}else{
			showToast(res.msg)
		}
	})
}
function fasong(){
	let arr = [];
	classItem.value.forEach(e =>{
		if(e.isCheck){
			arr.push(e)
		}
	})
	if(arr.length == 0){
		showToast('请先选择要分享的班级群');
		return false;
	}
	
	let num = 0;
	arr.forEach(e =>{
		//发送消息
		let param = {
		  "classId": e.id,
		  "content": JSON.stringify(fxItem.value),
		  "param1": "kj",
		  "param2": "",
		  "param3": "",
		  "param4": "",
		  "param5": "",
		  "type": 3
		}
		sendMsg(param).then(res =>{
		  if(res.code == 0){
			num += 1;
			showL.value = false;
			if(num == arr.length){
				showToast('消息已成功发送')
			}
		  }else{
			  showToast(res.msg)
		  }
		})
	})
}

onBeforeUnmount(() => {
  stopAudioPlayback();
});

const onSelectNavItem = (index,item) => {
  stopAudioPlayback();
  activeSidebar.value = index;
  navId.value = item.id;
  list();
};

getcoursewareList().then(res =>{
	navItems.value = res.data;
	navId.value  = res.data[0].id;
	list();
})

function list(){
	let params = {
		  "categoryId": navId.value,
		  "current": 1,
		  "size": 1000
	}
	getCourseware(params).then(res =>{
		listArr.value = res.data;
	})
}

function go(item){
	if(item.param1 == 2){
		router.push({name:"detail2",state:{item:JSON.stringify(item)}})
	}else{
		router.push({name:"detail",state:{item:JSON.stringify(item)}})
	}
}

// 停止播放
function stopAudioPlayback() {
  listArr.value.forEach((listItem) => {
    if (listItem.isPlaying) {
      listItem.isPlaying = false;
    }
  });
  audioElement.pause();
}


// 音频播放
const audioElement = document.createElement('audio');

const isPlaying = ref(false);

// function playMusic(item) {
// 	item.isPlaying = !item.isPlaying;
//   if (!isPlaying.value) {
//     audioElement.src = item.param2;
//     audioElement.play();
// 	isPlaying.value = true;
//   } else {
//     isPlaying.value = false;	
// 	audioElement.pause();
//   }
// }
function playMusic(item) {
  if (item.isPlaying) {
    // 如果当前音频正在播放，则暂停它
    audioElement.pause();
  } else {
    // 停止其他正在播放的音频
    listArr.value.forEach((listItem) => {
      if (listItem.isPlaying) {
        listItem.isPlaying = false;
      }
    });

    // 播放当前音频
    audioElement.src = item.param2;
    audioElement.play();
  }

  // 更新当前音频的播放状态
  item.isPlaying = !item.isPlaying;
}

function add(){
  addShow.value = true;
  mlTitle.value = "";
}

function addMl(){
	if(mlTitle.value){
		addcoursewareList({id:'0',name:mlTitle.value}).then(res =>{
			if(res.code == 0){
				getcoursewareList().then(res =>{
					navItems.value = res.data;
				})
			}else{
				showToast(res.msg)
			}

		})
	}
}

function add_kj(){
	addKjBox.value = true;
	mlTitle2.value = "";
	fileList.value = [];
	voice_url.value = "";
	checked.value = '1';
}


function delD(item){
	showConfirmDialog({
	  confirmButtonText:"删除",
	  confirmButtonColor:"#ff004a",
	  message:
	    '删除后不可恢复，请谨慎操作！',
	})
	  .then(() => {
	    // on confirm
		delCourseware({id:item.id}).then(res =>{
			if(res.code == 0){
				getcoursewareList().then(res =>{
					navItems.value = res.data;
					list();
				})
			}else{
				showToast(res.msg)
			}
		})
	  })
	  .catch(() => {
	    // on cancel
	  });
}

function del(item){
	showConfirmDialog({
	  confirmButtonText:"删除",
	  confirmButtonColor:"#ff004a",
	  message:
	    '删除分类后将删除该分类下所有课件，请谨慎操作！',
	})
	  .then(() => {
	    // on confirm
		delcoursewareList({id:item.id}).then(res =>{
			if(res.code == 0){
				getcoursewareList().then(res =>{
					navItems.value = res.data;
				})
			}else{
				showToast(res.msg)
			}
		})
	  })
	  .catch(() => {
	    // on cancel
	  });
}

//上传音频
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
		 voice_url.value = res.data; 
	  }else{
		  showToast(res.msg)
	  }
	}).catch(error => {
	  console.error(error);
	});
}
//上传图片
function afterRead2(file){
	console.log(fileList)
	fileList.value.forEach((item,value) =>{
		if(fileList.value[value].url){
			return
		}
		fileList.value[value].status = 'uploading';
		fileList.value[value].message = '上传中...';
		const formData = new FormData();
		formData.append('file', fileList.value[value].file);
		fileUpload(formData).then(res => {
		  if(res.code == 0){
			 fileList.value[value].status = "";
			 fileList.value[value].message = '';
			 fileList.value[value].url = res.data;
		  }else{
			  fileList.value[value].status = "failed";
			  fileList.value[value].message = '上传失败';
		  }
		}).catch(error => {
		  console.error(error);
		});
	})

}

function onBeforeClose(action,done){
	if(action =='cancel'){
		addKjBox.value = false;
	}
}

//新增课件
function addMl2(){
	if(!mlTitle2.value){
		showToast('请输入课件标题');
		return false;
	}
	if(checked.value == 1 && !voice_url.value){
		showToast('请输入音频链接');
		return false;
	}
	if(checked.value == 2 && !fileList.value){
		showToast('请上传图片');
		return false;
	}
	if(checked.value == 3 && !fileList.value){
		showToast('请上传图片');
		return false;
	}
	if(checked.value == 3 && !voice_url.value){
		showToast('请输入音频链接');
		return false;
	}
	let url = [];
	let isOver = true;
	fileList.value.forEach((item,value) =>{
		if(!item.url || item.url == 'null'){
			isOver = false;
		}
		url.push(item.url)
	})
	if(!isOver){
		showToast('请等待上传完成');
		return false;
	}
	let params = {
		categoryId:navId.value,
		title:mlTitle2.value,
		param1:checked.value,
		param2:voice_url.value,
		param3:JSON.stringify(url),
	}
	addCourseware(params).then(res =>{
		if(res.code == 0){
			showToast('上传成功！');
			getcoursewareList().then(res =>{
				navItems.value = res.data;
				list();
			})
			addKjBox.value = false;
		}else{
			showToast(res.msg);
		}
	})
}

</script>

<style lang="scss" scoped>
.scBtn{
	color: #fff;
	::v-deep .van-icon{
		    width: 20px;
		    height: 20px;
		    color: rgb(0, 201, 164);
		    font-weight: 800;
		    font-size: 14px;
			position: relative;
			top: -0px;
			background: #fff;
			border-radius: 50%;
			display: flex;
			justify-content: center;
			align-items: center;
			
	}
	::v-deep .van-button__text{
		color: #fff;
	}
}	
::v-deep .van-cell:after{
	display: none;
}	
::v-deep .van-dialog__header{
	background: #fff;
}
::v-deep .add-box{

}
::v-deep .van-dialog__footer{
	position: absolute;
	width: 100%;
	bottom: 0;
}
::v-deep .van-swipe-cell__right{
	display: flex;
	align-items: center;
}
.app-container2 {
  display: flex;
  height: 100%;

  .sidebar {
	width: 166px;
    height: 100%;
	padding-bottom: 100px;
    overflow: hidden;
	position: relative;
	.scroll{
		height: calc(100% + 10px);
		border-radius: 9px;
	}
	.sidebar-item{
		    text-align: center;
		    height: 60px;
			margin-bottom: 12px;
			.btn{
				width: 166px;
				margin: 0 auto;
				height: 60px;
				line-height: 60px;
				position: relative;
				display: flex;
				align-items: center;
				justify-content: center;
				background: #fff;
				border-radius: 9px;
				font-size: 16px;
				color: #171a20;
				.icon{
					width: 35px;
					height: 35px;
					margin-right: 7px;
					
					::v-deep .van-icon__image{
						width: 35px;
						height: 35px;
					}
				}
				.title{
					width: 56%;
					height: 35px;
					position: relative;
					.text{
						position: absolute;
						top: -2px;
						left: 0;
						height: 20px;
						width: 100%;
						text-align: left;
						font-size: 16px;
						overflow: hidden;
						text-overflow: ellipsis;
						white-space: nowrap;
						line-height: 20px;
					}
					.num{
						font-size: 11px;
						color: #969799;
						height: 20px;
						position: absolute;
						left: 0;
						top: -1px;
					}
				}
				
			}
			.active{
				.title{
					.text{
						font-size: 18px;
						color: #000;
						}
					}
				}
				
			.del{
				    font-size: 20px;
				    width: 50px;
				    height: 30px;
				    text-align: center;
				    line-height: 30px;
					display: flex;
					    justify-content: center;
					    align-items: center;
			}
	}
    .sidebar-title {
      // 添加标题样式
		height: 42px;
		line-height: 42px;
		background: #111;
		color: #fff;
		text-align: center;
		font-size: 20px;
		letter-spacing: 4px;
		.title_icon{
			    background: #fff;
				color: #111;
			    border-radius: 50%;
			    width: 20px;
			    height: 20px;
			    font-size: 16px;
			    text-align: center;
			    line-height: 21px;
			    padding-left: 1px;
			    font-weight: 400;
			    margin-right: 10px;
		}
    }
	.van-sidebar{
		width: 100%;
		height: calc(100% - 100px);

		overflow-y: auto;
		.van-sidebar-item{
			border-bottom: 1px solid #f8f8f8;
			background: none;
			height: 40px;
			padding: 8px 28px;
			::v-deep .van-badge__wrapper{
				color: #fff;
				width: 84px;
				height: 24px;
				text-align: center;
				line-height: 24px;
				border-radius: 24px;
				letter-spacing: 2px;
				color: #333;
			}
		}
		.van-sidebar-item--select{
			::v-deep .van-badge__wrapper{
				background: #111;
				color: #fff;
			}
		}
		.van-sidebar-item::before{
			display: none;
		}

	}
	.add_box{
		position: absolute;
		bottom: 0;
		width: 100%;
		height: 80px;
		background: #fff;
		border-radius: 9px;
		padding:20px;
		.van_button{
			    border: none;
			    position: relative;
			    width: 100%;
			    font-size: 16px;
			    text-align: center;
			    display: flex;
			    flex-flow: column;
			    justify-content: center;
			    align-items: center;
			
			.add_class{
				width: 24px;
				height: 24px;
				font-size: 24px;
				position: relative;
				top: -4px;
			}
		}
	}
  }

  .content {
    width: calc(100% - 178px);
    margin-left: 12px;
    background: #fff;
    border-radius: 14px;
	padding: 12px 0px;
	position: relative;
	.top{
		position: absolute;
		bottom: 10px;
		left: 0;
		width: 100%;
		height: 43px;
		
		.add_kj{
		    float: right;
		    margin-right: 10px;
		    width: 135px;
		    height: 43px;
		    line-height: 43px;
		    background: #00c9a4;
		    text-align: center;
		    border-radius: 9px;
			color: #fff;
			font-size: 16px;
			display: flex;
			align-items: center;
			justify-content: center;
		}
	}
	.van-grid{
		::v-deep .van-grid-item{
			min-width: 187px;
		}
		::v-deep .van-grid-item__content--center {
	    align-items: center;
	    justify-content: center;
	    background: #f2f3f7;
	    border-radius: 14px;
	    border: none;
		.item-top{
			height: 44px;
			width: 100%;
			line-height: 26px;
			border-bottom: 2px dashed #fff;
			position: relative;
			font-size: 16px;
			padding: 0 10px;
			.text{
				width: calc(100% - 50px);
				overflow: hidden;
				text-overflow: ellipsis;
				white-space: nowrap;
			}
			.top-right{
				position: absolute;
				right: 10px;
				top: 2px;
				font-size: 13px;
			}
		}
		.item-top::before{
			    content: "";
			    width: 13px;
			    height: 13px;
			    left: -16px;
			    bottom: -7px;
			    background: #fff;
			    border-radius: 50%;
			    position: absolute;
		}
		.item-top::after{
			    content: "";
			    width: 13px;
			    height: 13px;
			    right: -16px;
			    bottom: -7px;
			    background: #fff;
			    border-radius: 50%;
			    position: absolute;
		}
		.item-bottom{
			width: 100%;
			height: 44px;
			line-height: 60px;
			padding: 0 10px;
			position: relative;
			color: #757575;
			font-size: 12px;
			.icon_l{
				margin-right: 10px;
			}
			.icon1{
				font-size: 22px;
				margin-right: 4px;
				position: relative;
				top: 6px;
			}
			.icon_r{
				position: absolute;
				right: 0px;
				bottom: 22px;
				font-size: 18px;
			}
			.del{
				width: 30px;
				text-align: right;
				font-size: 23px;
			}
		}
		}
	}
	
  }
  .kjBox{
	  padding: 16px;
	  .title{
		  position: relative;
		  padding-left: 10px;
	  }
	  .title::before{
		  content: "";
		  position: absolute;
		  left: 0;
		  bottom:5px;
		  width: 3px;
		  height: 12px;
		  background: #00c9a4;
		  top: 3px;
	  }
	  .input_box{
		box-shadow: 0 0 8px 0 #f3f3f3;
		border-radius: 9px;
		margin-top: 6px;
		margin-bottom: 20px;
	  }
	  .group{
		  display: flex;
		  margin-top: 10px;
		  .van-radio{
			  margin-right: 16px;
		  }
	  }
  }
}


</style>
