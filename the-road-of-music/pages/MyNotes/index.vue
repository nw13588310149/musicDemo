<template>
  <view class="app-container21">
    <!-- 左侧导航 -->
    <view class="sidebar">
      <view class="sidebar-title"><van-icon class="title_icon" name="/static/assets/bottom_go.png" />我的笔记</view>
      <view class="all" @click="onSelectNavItem(0)">
        <van-icon class="icon" name="/static/assets/note_b.png" />笔记
		<view style="margin-left: 15px;font-size: 12px;">{{allNum}}</view>
      </view>
	  <view class="over_y" style="height: calc(100% - 190px);">
		  <view
		  class="sidebar-item"
		  v-for="(item, index) in navItems"
		    :key="index"
		    @click="onSelectNavItem(index,item)">
		  		<van-swipe-cell>
		  		<view class="btn" :class="{'active':activeSidebar == item.id}">{{item.name}}</view>
		  		  <template #right>
		  		    <van-icon class="del" @click="del(item)" name="/static/assets/delIcon2.png" />
		  		  </template>
		  		</van-swipe-cell> 
		  </view>
	  </view>
	  
	  <!-- 新增分类 -->
	  <view class="add_box">
	    <view class="van_button" @click="addShow = true"><van-icon class="add_class" name="/static/assets/add_class.png" />笔记分类</view> 
	  </view>
    </view>

    <!-- 这里将是主体内容 -->
    <view class="content">
      <!-- 头部导航 -->
      <view class="nav-items">
		  <view v-for="tab in tabs"
			  :key="tab"
			  :class="activeTab === tab ? 'active' : ''"
			  @click="selectTab(tab)">
			{{tab}}
		  </view>
		  <view class="add_bj" @click="add2()">
			  <van-icon name="/static/assets/jp_add.png" />
			  新建
		  </view>
      </view>
      <!-- 内容列表 -->
	  <view class="box">
		  <van-empty description="暂无笔记,请上传!" v-if="listArr.length == 0" style="height: calc(100% - 50px);" image="/static/assets/empty_note.png" :image-size="[260, 260]"/>
		<van-grid class="list" :gutter="10" :border="false" :column-num="4">
		  <van-grid-item v-for="(item,value) in listArr"  @click="goDetail(item)">
					<view class="img" :style="{backgroundImage: `url(${items[item.paperType].background})`}">
						<van-image :src="item.param1"/>
					</view>
		    <view style="width: 100%;">
					  <view class="title">{{item.title}}</view>
					  <view class="time thin">{{formatDate(item.createTime)}}</view>
				  </view>
				  <van-icon class="del" name="cross" @click.stop.prevent="delD(item)"/>
				  <!-- <van-icon class="del" name="/static/assets/bg_close.jpg" @click.stop.prevent="delD(item)"/> -->
		  </van-grid-item>
		</van-grid>  
	  </view>

	  <!-- 分页 -->
<!-- 	  <van-pagination class="page" v-model="currentPage" :total-items="50" :show-page-size="5">
	    <template #prev-text>
		  <view>
			  <van-icon name="arrow-left" />
		  </view>
	    </template>
	    <template #next-text>
	      
		  <view class="li">
			  <van-icon name="arrow" />
		  </view>
	    </template>
	    <template #page="{ text }">
			<view class="li">{{ text }}</view>
		</template>
	  </van-pagination> -->


    </view>
	<!-- 新建目录 -->
    <van-dialog class="add_log" v-model:show="addShow" title="新建目录" show-cancel-button @confirm="addMl">
      <view class="add_content">
        <van-field v-model="mlTitle" placeholder="请输入目录名称" />
      </view>
    </van-dialog>
	<!-- 新建笔记 -->
	<van-dialog class="add_log" v-model:show="addShow2" title="新建笔记" show-cancel-button @confirm="addBj">
	  <view class="add_content">
	    <van-field v-model="bjTitle" placeholder="请输入笔记标题" />
	  </view>
	</van-dialog>

  </view>
</template>

<script setup>
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import { showToast , showConfirmDialog ,showLoadingToast, Toast} from 'vant';
import {getnoteCategoryList,addnoteCategoryList,delnoteCategoryList,getnoteList,noteDelete,getnoteNum} from '/api/home.js';
const router = useRouter();

const navItems = ref([]);
const activeSidebar = ref(4);
const searchQuery = ref('');
const addShow = ref(false);
const addShow2 = ref(false);
const mlTitle = ref("");
const bjTitle = ref("");
const activeTab = ref('所有笔记'); // 初始化 activeTab
const listArr = ref([]);

const items = ref([
  { title: '五线谱', background: '/static/assets/bg_wxp2.jpg' },
  { title: '笔记本', background: '/static/assets/bg_bjb2.jpg' },
  { title: '白纸', background: '' },
]);

const tabs = ref([
  '所有笔记',
  '最近',
  '收藏',
  '未归档',
]);
getMl()

//获取笔记目录
function getMl(){
	getnoteCategoryList().then(res =>{
		navItems.value = res.data;
	})
}

//获取笔记数量
const allNum = ref();
getNum();
function getNum(){
	getnoteNum().then(res =>{
		if(res.code == 0){
			allNum.value = res.data;
		}
	})
}

getList()
//获取笔记列表目录
function getList(){
	let params = {
		  "categoryId": activeSidebar.value,
		  "current": 1,
		  "size": 15
	}
	getnoteList(params).then(res =>{
		listArr.value = res.data;
		getNum();
	})
}

const onSelectNavItem = (index,item) => {
	if(item){
		activeSidebar.value = item.id;
	}else{
		activeSidebar.value = index;
	}
	getList()
};

function goDetail(item){
	router.push({ name: 'noteDetail' ,state:{id:item.categoryId,title:item.title,type:item.paperType,param1:item.param1,sId:item.id}});
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
		noteDelete({id:item.id}).then(res =>{
			if(res.code == 0){
				getList();
			}else{
				showToast(res.msg)
			}
		})
	  })
	  .catch(() => {
	    // on cancel
	  });
}

function formatDate(dateTimeString) {
  const date = new Date(dateTimeString);
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0'); // 月份从0开始，需要+1
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function del(item){
	showConfirmDialog({
	  confirmButtonText:"删除",
	  confirmButtonColor:"#ff004a",
	  message:
	    '删除后不可恢复，请谨慎操作！',
	})
	  .then(() => {
	    // on confirm
		delnoteCategoryList({id:item.id}).then(res =>{
			if(res.code == 0){
				getMl();
				getNum();
			}else{
				showToast(res.msg)
			}
		})
	  })
	  .catch(() => {
	    // on cancel
	  });
}

function add(){
  addShow.value = true;
  mlTitle.value = "";
}
function add2(){
  addShow2.value = true;
  bjTitle.value = "";
}
function addMl(){
	addnoteCategoryList({id:0,name:mlTitle.value}).then(res =>{
		getMl()
	})
}
function addBj(){
  router.push({ name: 'note_bg' ,state:{id:activeSidebar.value,title:bjTitle.value}});
}

// 点击头部导航按钮时，切换 activeTab 的值
function selectTab(tab) {
  activeTab.value = tab;
}
</script>

<style lang="scss" scoped>
	::v-deep .van-dialog__header{
		background: none;
		font-weight: 200;
	}
	.add_content{
		border: 1px solid #f2f2f4;
	}
.app-container21 {
  display: flex;
  height: 100%;

  .sidebar {
    width: 112px;
    height: 100%;
    background: #fff;
    border-radius: 9px;
    overflow: hidden;
    position: relative;
	padding: 0 3px;
	.sidebar-item{
		    text-align: center;
		    height: 44px;
		    border-bottom: 1px solid #dddddd38;
			line-height: 44px;
			position: relative;
			top: -5px;
			.btn{
				padding: 0 5px;
				    width: 100%;
				    height: 34px;
				    line-height: 34px;
				    margin-top: 5px;
					letter-spacing: 2px;
					overflow: hidden;
					text-overflow: ellipsis;
					white-space: nowrap;
			}
			.btn.active{
				background: #F6F7FB;
				color: #171a20;
				border-radius: 9px;
			}
			.del{
				width: 40px;
				height: 34px;
				text-align: center;
				position: relative;
				display: flex;justify-content: center;align-items: center;
			}
	}
    .sidebar-title {
      // 添加标题样式
	  width: 100%;
      height: 34px;
      line-height: 34px;
	  background: #000;
	  border-radius: 9px;
      color: #fff;
      text-align: center;
      font-size: 16px;
      letter-spacing: 0px;
      font-weight: 400;
	  margin: 3px 0;
	  display: flex;
	  justify-content: center;
	  align-items: center;
      .title_icon {
        font-size: 20px;
        text-align: center;
        line-height: 20px;
        padding-left: 0px;
        font-weight: 400;
        margin-right: 6px;
		color: #171a20;
		position: relative;
		top: -1px;
      }
	  position: relative;
    }
	.sidebar-title::after{
		    content: "";
		    width: 15px;
		    height: 15px;
		    background: url(/static/assets/bottom_1.png) no-repeat;
		    background-size: cover;
		    position: absolute;
		    bottom: -14px;
		    right: 19px;
	}
    .all {
		margin: 17px 0px 14px 0px;
      height: 34px;
      line-height: 34px;
	  width: 100%;
      background: #F6F7FB;
      border-radius: 4px;
      font-size: 16px;
      font-weight: 400;
      padding: 0 4px;
	  color: #171a20;
	  display: flex;
	  justify-content: center;
	  align-items: center;
      .van-rolling-text {
        height: 26px;
        right: 0;
        float: right;
        font-size: 10px;
		margin-left: 17px;
        ::v-deep .van-rolling-text-item {
          width: 8px;
          height: 20px !important;
          --van-translate: -960px;
          .van-rolling-text-item__item {
            line-height: 20px !important;
            color: #111;
          }
        }
      }
      .icon {
        margin-right: 4px;
      }
    }
    .title {
      margin: 0 22px 0 24px;
	  color: #171a20;
      .add_class {
            float: right;
            font-size: 13px;
            margin-top: 5px;
            color: #00c9a4;
            font-weight: 600;
			position: relative;
			top: -1px;
      }
    }
    .icon_b {
      margin-left: 36px;
          font-size: 9px;
          position: relative;
          top: -11px;
          color: #171a20;
          font-weight: 400;
    }
    .van-sidebar {
      width: 100%;
      height: calc(100% - 100px);

      overflow-y: auto;
      .van-sidebar-item {
        background: none;
        height: 40px;
        padding: 8px 28px;
        ::v-deep .van-badge__wrapper {
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
      .van-sidebar-item--select {
        ::v-deep .van-badge__wrapper {
          background: #111;
          color: #fff;
        }
      }
      .van-sidebar-item::before {
        display: none;
      }
    }
	.add_box{
		position: absolute;
		bottom: 0;
		width: 100%;
		height: 100px;
		padding: 0px 3px 28px;
		.van_button{
			border: none;
			position: relative;
			width: 100%;
			margin-top: 40px;
			font-size: 16px;
			padding: 12px;
			text-align: center;
			.add_class{
				position: absolute;
				    top: -18px;
				    width: 24px;
				    height: 24px;
				    line-height: 24px;
				    border-radius: 50%;
				    font-weight: 400;
					font-size: 24px;
				    left: 41px;
			}
		}
	}
  }

  .content {
    width: calc(100% - 123px);
    margin-left: 11px;
	position: relative;
	.list{
		width: 100%;
		.img{
			width: 100%;
			height: 170px;
			background-size: 100%;
			background-repeat: no-repeat;
			overflow: hidden;
		}
	}
	.box{
		margin-top: 10px;
		background: #fff;
		border-radius: 9px;
		height: 100%;
		    height: calc(100% - 65px);
		padding: 10px 0;	
	}
	.nav-items{
		padding: 0 10px;
		background: #fff;
		height: 55px;
		border-radius: 9px;
		padding:6px 12px;
		view{
			display: inline-block;
		    font-size: 15px;
		    font-weight: 500;
			position: relative;
			margin: 7px 21px 0 0;
		}
		view.active{
			font-size: 16px;
			color: #171a20;
		}
		view.active:after{
			content: "";
		    width: 50%;
		    height: 4px;
		    position: absolute;
		    background: #00c9a4;
		    bottom: -9px;
		    left: 25%;
		    border-radius: 4px;
		}
		.add_bj{
			float: right;
		    background: #00c9a4;
		    color: #fff;
		    width: 84px;
			height: 33px;
		    border-radius: 9px;
			position: relative;
			top: 5px;
			display: flex;
			justify-content: center;
			align-items: center;
			margin: 0;
			margin-right: 0px;
			.van-icon{
			    color: #fff;
			    font-weight: 400;
				font-size: 20px;
			    margin-right: 8px;	
			}
		}
	}
    .van-grid {
		::v-deep .van-grid-item{
				 min-width: 187px; 
		}
      ::v-deep .van-grid-item__content--center {
        align-items: center;
        justify-content: center;
        border-radius: 4px;
        border: none;
		padding: 0;
		overflow: hidden;
		box-shadow: 0 0 8px 0 #f3f3f3;
		position: relative;
		.del{
			position: absolute;
		    top: 10px;
		    right: 10px;
		    font-size: 18px;
		    box-shadow: 0 0 8px 0 #f3f3f3;
		    border-radius: 100%;
		    width: 28px;
		    height: 28px;
		    background: #e5e5e5;
		    display: flex;
		    justify-content: center;
		    align-items: center;
		    color: #fff;
		}
		.title{
		    text-align: left;
			font-size: 14px;
			color: #171a20;
		    width: 100%;
		    padding: 10px 10px 2px 8px;
			overflow: hidden;
			text-overflow: ellipsis;
			white-space: nowrap;
		}
		.time{
			text-align: left;
		    width: 100%;
		    padding: 0px 10px 10px;
		    font-size: 12px;
			color: #6A6A6A;
		}
    
      }
    }

  }


  .page {
	display: flex;
	justify-content: flex-end;
	position: absolute;
	bottom: 20px;
	right: 20px;
	width: calc(100% - 20px);
	  ::v-deep *{
		  background: none;
		  border: none;
	  }
  }


}


</style>
