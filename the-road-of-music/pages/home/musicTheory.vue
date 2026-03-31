<template>
  <view class="app-container30">
	<!-- 左侧导航 -->
    <view class="sidebar">
		<view v-for="(item, index) in navItems"
		 class="item"
          :key="item.name"
		  :class="{'active':item.id == activeSidebar.id}"
          @click="onSelectNavItem(item)">
		  <van-icon class="icon" name="/static/assets/item_bg.png" />
			{{item.name}}
		</view>
    </view>

    <!-- 这里将是主体内容 -->
    <view class="content scroll">
		<!-- 头部二级目录 如果有 -->
		<view class="top-nav" v-if="activeSidebar?.children">
		  <view class="title"><van-icon class="right_icon" name="arrow" /></view>
		  <view class="nav-items">
		    <van-button v-for="item in activeSidebar?.children" plain class="btn" type="default" :class="item.id === activeSecond ? 'active' : ''" @click="selectTab(item.id)">{{item.name}}</van-button>
		  </view>
		</view>
		<view class="box" style="height: 100%;">
			<van-empty v-if="list.length == 0" description="暂无数据哦!" image="/static/assets/empty_list.png" :image-size="[260, 260]"/>
			<!-- 内容列表 -->
			<van-grid :gutter="12" :column-num="3" :border='false'>
				    <van-grid-item class="list_item" v-for="value in list" :key="value" @click="tap(value)">
						<view class="tip" v-if="isHide">{{value.vip==0?'免费':'会员'}}</view>
						<van-icon class="icon" name="/static/assets/icon_yf2.jpg" />
						<view class="item-top">
						  {{value.title}}
						</view>

				    </van-grid-item>
			</van-grid>

		</view>
	</view>
  </view>
</template>

<script setup>
import { ref , onMounted} from 'vue';
import { useRouter } from 'vue-router';
import {postMenulist , getTextbooklist ,getSchoolbooklist} from '../../api/home.js'
import { useStore } from 'vuex';  // 引入 useStore
import { showToast} from 'vant';
const store = useStore();  // 使用 useStore
const router = useRouter();
const isHide = ref(uni.getStorageSync("checkStatus"));
const navItems = ref([
  { name: '章节讲义' },
  { name: '专项练习' },
  { name: '音乐常识' },
]);
const list = ref({});
const vipExpireDate = store.getters.getInfo.vipExpireDate;

const activeSidebar = ref({id:5});
const searchQuery = ref('');
const activeSecond = ref("");

const onSelectNavItem = (index) => {
  activeSidebar.value = index;
  if(activeSidebar.value.children?.length>0){
	 activeSecond.value =  activeSidebar.value.children[0].id;
  }else{
	activeSecond.value = "";  
  }
  getlist()
};

const selectTab = (id) => {
  activeSecond.value = id;
  getlist()
};

function isFutureDate(dateString) {
  // 将输入的日期字符串转换为日期对象
  const inputDate = new Date(dateString);
  
  // 获取当前日期的时间戳，忽略时间部分
  const currentDate = new Date();
  currentDate.setHours(0, 0, 0, 0);
  
  // 比较输入日期和当前日期
  if (inputDate >= currentDate) {
    return true; // 输入日期是未来的时间或是今天
  } else {
    return false; // 输入日期是过去的时间
  }
}

function tap(value){
	if(value.vip == 1){
		if(vipExpireDate == null){
			showToast("您还未开通会员");
			return false;
		}else if(!isFutureDate(vipExpireDate)){
			showToast("您的会员已过期，请续费");
			return false;
		}else{
			
		}
	}
	if(activeSidebar.value == 6){
			router.push({ name: 'theory', state: { id: value.id ,type:'1'} });
	}else{
			router.push({ name: 'theory', state: { id: value.id } });
	}
}

onMounted(() => {
  getMenulist(); //获取列表目录
  getlist(); //获取课件列表
});

const getMenulist = async () => {
  try {
    const result = await postMenulist(2);
    navItems.value = result.data;
	console.log(uni.getStorageSync('firstMenu'))
	if(uni.getStorageSync('firstMenu')){
		navItems.value.forEach(e =>{
			if(e.id == uni.getStorageSync('firstMenu')){
				onSelectNavItem(e)
			}
		})
	}
  } catch (error) {
    console.error('错误信息:', error);
  }
};
const getlist = async () => {
  try {
	const data = {
		current:1,
		firstMenu:activeSidebar.value.id,
		province:"甘肃",
		secondMenu:activeSecond.value,
		size:1000,
		type:2
	}
    const result = await (!history.state.school ? getTextbooklist(data) : getSchoolbooklist(data));
	
    list.value = result.data;
		document.getElementsByClassName('scroll')[0].scrollTop = 0;
  } catch (error) {
    console.error('错误信息:', error);
  }
};


</script>

<style lang="scss" scoped>
.app-container30 {
  display: flex;
  height: 100%;

  .sidebar {
	width: 118px;
	position: relative;
	.item{
	    width: 100%;
	    text-align: center;
	    font-size: 15px;
		background: #fff;
		border-radius: 9px;
	    margin-bottom: 10px;
	    height: 103px;
		padding: 10px;
		color: #171a20;
		display: flex;
		justify-content: center;
		align-items: center;
		.icon{
			margin-right: 8px;
			font-size: 26px;
		}
	}
	.item.active{
		font-weight: 400;
		font-size: 16px;
		position: relative;
	}
	.item.active::after{
		content: "";
		position: absolute;
		right: 0;
		bottom: 0;
		background: url(/static/assets/active_jb.png) no-repeat;
		background-size: 20px;
		width: 20px;
		height: 20px;
	}
  }

  .content {
    width: calc(100% - 130px);
    margin-left: 12px;
    background: #fff;
    border-radius: 9px;
	padding: 12px 0px;
	overflow: auto;
	.van-grid{
		.van-grid-item{
			height: 56px;
			min-width: 0;
			::v-deep .van-grid-item__content{
				height: 56px;
				background: #f2f3f7;
				border-radius: 4px;
				overflow: hidden;
				display: block;
				position: relative;
				padding-left: 70px;
				.tip{
					position: absolute;
					right: 0;
					top: 0;
					width: 40px;
					background:#fbe5bd;
					border-radius: 0 4px 0 10px;
					font-size: 9px;
					padding: 1px 0;
					padding-left: 2px;
					text-align: center;
					color: #785c38;
					letter-spacing: 1px;
				}

				.icon{
					position: absolute;
				    font-size: 42px;
				    top: 7px;
				    left: 9px;
				    border-radius: 4px;
				    overflow: hidden;
				}
				.item-top{
					
					width: 100% !important;
					font-size: 14px;
					position: relative;
					letter-spacing: 1px;
					height: 24px;
					line-height: 24px;
					overflow: hidden;
					white-space: nowrap;
					text-overflow: ellipsis;
				}
			}
		}
	}
	
  }
}


</style>
