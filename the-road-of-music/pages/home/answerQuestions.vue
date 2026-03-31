<template>
  <view class="app-container20">
	<!-- 左侧导航 -->
    <view class="sidebar" >
		<view v-for="(item, index) in navItems"
		 class="item"
          :key="item.name"
		  :class="{'active':item.id == activeSidebar?.id}"
          @click="onSelectNavItem(item)">
			<van-icon class="icon" name="/static/assets/item_bg.png" />
			{{item.name}}
		</view>
    </view>

    <!-- 这里将是主体内容 -->
    <view class="content">
		<view class="top-nav" v-if="navData.length > 0">
		  <view class="title"><van-icon class="right_icon" name="arrow" /></view>
		  <view class="nav-items">
		    <van-button plain class="btn" type="default" v-for="item in navData" :class="activeSecond == item.id ? 'active' : ''" @click="selectTab(item)">{{item.name}}</van-button>
		  </view>
		</view>
		<!-- 头部二级目录 如果有 -->
		    <view class="li" v-for="(group, key) in data" :key="key">
		      <view class="titlte">{{ key }}</view>
		      <van-grid :gutter="12" :column-num="3" :border="false">
		        <van-grid-item class="list_item" v-for="item in group" :key="item.id" @click="tap(item)">
					<view class="tip" v-if="isHide">{{item.vip==0?'免费':'会员'}}</view>
		          <van-icon class="icon" name="/static/assets/icon_yf2.jpg" />
		          <view class="item-top">
		            {{ item.title }}
		          </view>
		        </van-grid-item>
		      </van-grid>
		    </view>
		<view class="box">
			<view class="scroll">
				<van-empty v-if="list.length == 0" description="暂无数据哦!" image="/static/assets/empty_list.png" :image-size="[260, 260]"/>
				<!-- 内容列表 -->
				<view class="li" v-for="item in list" :key="item" v-if="isShot">
					<view class="titlte">{{item.name}}</view>
					<van-grid :gutter="12" :column-num="3" :border='false'>
						    <van-grid-item class="list_item" v-for="a in item.list" :key="value" @click="tap(a)">
								<view class="tip" v-if="isHide">{{a.vip==0?'免费':'会员'}}</view>
								<van-icon class="icon" name="/static/assets/icon_yf2.jpg" />
								<view class="item-top" :style="{top:a.shortText2?'-7px':'0px'}">
								  {{a.title}}
								</view>
								<view class="item-bottom thin">
									{{a.shortText2}}
								</view>
								
						    </van-grid-item>
					</van-grid>
				</view>
				
				<van-grid :gutter="12" :column-num="3" :border='false' v-if="!isShot">
					    <van-grid-item class="list_item" v-for="a in list" :key="value" @click="tap(a)">
							<view class="tip" v-if="isHide">{{a.vip==0?'免费':'会员'}}</view>
							<van-icon class="icon" name="/static/assets/icon_yf2.jpg" />
							<view class="item-top" :style="{top:a.shortText2?'-7px':'0px'}">
							  {{a.title}}
							</view>
							<view class="item-bottom thin">
								{{a.shortText2}}
							</view>
					    </van-grid-item>
				</van-grid>
			</view>
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
  { name: '听写' },
  { name: '乐理' },
  { name: '视唱' },
]);
const list = ref({});
const navData = ref([]);
const activeSidebar = ref({id:63});
const searchQuery = ref('');
const activeSecond = ref(65);
const onSelectNavItem = (index) => {
  activeSidebar.value = index;
  let isT = false;
  if(activeSidebar.value.children?.length>0){
	  activeSidebar.value.children.forEach(e =>{
		  if(e.id == uni.getStorageSync('secondMenu')){
		  	activeSecond.value =  e.id;
			isT = true;
		  }
	  })
	  if(isT == false){
		  activeSecond.value =  activeSidebar.value.children[0].id;
	  }
  }else{
	activeSecond.value = "";  
  }
  navData.value =  activeSidebar.value.children || [];
  getlist()
};

const selectTab = (item) => {
  activeSecond.value = item.id;
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
const vipExpireDate = store.getters.getInfo.vipExpireDate;
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
	if(activeSidebar.value.id == 63 || activeSidebar.value.id == 64){
		router.push({ name: 'answerEnd2', state: { id: value.id } });
	}else{
		router.push({ name: 'answerEnd', state: { id: value.id } });
	}
}

onMounted(() => {
  getMenulist(); //获取列表目录
  getlist(); //获取课件列表
});

const getMenulist = async () => {
  try {
    const result = await postMenulist(10);
	const sortedData = result.data.sort((a, b) => {
	    const order = [ "听写", "视唱", "乐理"];
	    return order.indexOf(a.name.trim()) - order.indexOf(b.name.trim());
	});
	navItems.value = sortedData;
	if(uni.getStorageSync('firstMenu')){
		navItems.value.forEach(e =>{
			if(e.id == uni.getStorageSync('firstMenu')){
				onSelectNavItem(e)
			}
		})
	}else{
		onSelectNavItem(navItems.value[0])
	}
  } catch (error) {
    console.error('错误信息:', error);
  }
};

const isShot = ref(false);
const getlist = async () => {
  try {
	const data = {
		current:1,
		firstMenu:activeSidebar.value.id,
		province:store.getters.getInfo.province || "甘肃",
		secondMenu:activeSecond.value,
		size:1000,
		type:10
	}
	const result = await (!history.state.school ? getTextbooklist(data) : getSchoolbooklist(data));
	
	if(result.data[0]?.shortText1){
		const groupedData = groupByShortText1(result.data);
		
		list.value = groupedData;
		isShot.value = true;
	}else{
		isShot.value = false;
		list.value = result.data;
	}


  } catch (error) {
    console.error('错误信息:', error);
  }
};

// 根据 shortText1 的值对数据进行分组
const groupByShortText1 = (data) => {
  const groupedData = {};

  data.forEach(item => {
    const { id, title, subTitle, shortText1 ,shortText2,vip} = item;
    
    if (!groupedData[shortText1]) {
      groupedData[shortText1] = {
		  name:item.shortText1,
		  list:[]
	  };
    }
	
    groupedData[shortText1].list.push({ id, title, subTitle, shortText1 ,shortText2,vip});
  });
  return groupedData;
};
</script>

<style lang="scss" scoped>
.app-container20 {
  display: flex;
  height: 100%;
	.li{
		margin-top: 22px;
		.titlte{
			padding: 10px;
			position: relative;
			padding-left: 23px;
			margin-bottom: 6px;
			color: #171a20;
			padding-top: 0;
			font-size: 16px;
		}
		.titlte::before{
		    content: "";
		    position: absolute;
		    left: 15px;
		    top: 3px;
		    width: 3px;
		    height: 13px;
		    background: #00c9a4;
			border-radius: 9px;
		}
	}
	.li:first-child{
		margin-top: 0;
	}
  .sidebar {
	  width: 112px;
	.item{
	    width: 100%;
		background: #fff;
	    text-align: center;
	    font-size: 16px;
		background-size: contain;
	    margin-bottom: 10px;
	    height: 98px;
	    border-radius: 6px;
		color: #171a20;
		display: flex;
		flex-wrap: wrap;
		justify-content: center;
		align-items: center;
		padding: 0 14px;
		.icon{
			margin-right: 8px;
			font-size: 26px;
		}
	}
	.item.active{
		font-weight: 400;
		font-size: 17px;
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
  .top-nav {
    display: flex;
    justify-content: flex-start;
    align-items: center;
    height: 55px;
  	background: #fff;
  	border-radius: 9px;
  	overflow: hidden;
	margin-bottom: 10px;
	flex-shrink:0;
	.title {
	  height: 28px;
	  line-height: 28px;
		text-align: center;
		font-size: 28px;
		color: #fff;
		letter-spacing: 4px;
		padding: 0 12px;

		.right_icon{
		    background: #00c9a4;
		    border-radius: 50%;
		    width: 24px;
		    height: 24px;
		    font-size: 14px;
		    text-align: center;
		    line-height: 24px;
		    font-weight: 900;
		    color: #111;
		    padding-left: 4px;
		    position: relative;
		    top: -5px;
		}
		
	}
	
  }
	::v-deep .van-button{
		height: 35px;
		line-height: 35px;
		margin-right: 20px;
		font-size: 16px;
		color: #171a20;
		border-radius: 6px;
		border: none;
		background: #F6F7FB;
	}
	
	.active{
		background: #111;
	}
	::v-deep span{
		color: #545454;
	}
	.active ::v-deep span{
		color: #fff;
	}

  .content {
    width: calc(100% - 124px);
    margin-left: 12px;
    border-radius: 9px;
	overflow: hidden;
	display: flex;
	flex-direction: column;
	.box{
		.scroll{
			padding-bottom: 70px;
			height: 100%;
			overflow-y: auto;
			-webkit-overflow-scrolling: touch; /* 兼容iOS滚动 */
			scrollbar-width: none; /* Firefox */
			-ms-overflow-style: none; /* IE/Edge */
		}
		background: #fff;
		border-radius: 9px;
		height: 100%;
		padding: 12px 0;

	}
	.box::-webkit-scrollbar{
	  display: none; /* Chrome/Safari/Opera */
	}
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
				padding-left: 69px;
				.tip{
					position: absolute;
					right: 0;
					top: 0;
					width: 40px;
					background: #fbe5bd;padding-left:2px !important;
					border-radius: 0 4px 0 10px;
					font-size: 9px;
					padding: 1px 0;
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
					font-size: 14px;
					position: relative;
					letter-spacing: 0px;
					height: 24px;
					line-height: 24px;
					color: #171a20;
					overflow: hidden;
					text-overflow: ellipsis;
					white-space: nowrap;
				}
				.item-bottom{
					font-size: 12px;
					position: relative;
					top: -9px;
					color: #6A6A6A;
					overflow: hidden;
					text-overflow: ellipsis;
					white-space: nowrap;
				}
			}
		}
	}
	
  }
}


</style>
