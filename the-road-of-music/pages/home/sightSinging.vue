<template>
  <view class="app-container10">
	<!-- 左侧导航 -->
    <view class="sidebar">
		<view v-for="(item, index) in navItems"
		 class="item"
		 style="text-align: left;"
          :key="item.name"
		  :class="{'active':item.id == activeSidebar}"
          @click="onSelectNavItem(item.id)">
			<van-icon class="icon" name="/static/assets/item_bg.png" />
			{{item.name}}
		</view>
    </view>

    <!-- 这里将是主体内容 -->
    <view class="content scroll">
		<van-empty v-if="list.length == 0" description="暂无数据哦!" image="/static/assets/empty_list.png" :image-size="[260, 260]"/>
		<view class="over_y" style="height: 100%;" v-if="list">
			<!-- 内容列表 -->
			<view class="li" v-for="item in list" :key="item" v-if="isShot">
					<view class="titlte">{{item.name}}</view>
					<van-grid :gutter="12" :column-num="3" :border='false'>
						    <van-grid-item class="list_item" v-for="a in item.list" :key="value" @click="tap(a)">
								<view class="tip" v-if="isHide">{{a.vip==0?'免费':'会员'}}</view>
								<van-icon class="icon" name="/static/assets/icon_yf2.jpg" />
								<view class="item-top" :style="{top:a.shortText1?'-7px':'0px'}">
								  {{a.title}}
								</view>
								<view class="item-bottom thin">
									{{a.shortText1}}
								</view>
						    </van-grid-item>
					</van-grid>
				</view>
				
				<van-grid :gutter="12" :column-num="3" :border='false' v-if="!isShot">
					    <van-grid-item class="list_item" v-for="a in list" :key="value" @click="tap(a)">
							<view class="tip" v-if="isHide">{{a.vip==0?'免费':'会员'}}</view>
							<van-icon class="icon" name="/static/assets/icon_yf2.jpg" />
							<view class="item-top" :style="{top:a.shortText1?'-7px':'0px'}">
							  {{a.title}}
							</view>
							<view class="item-bottom thin">
								{{a.shortText1}}
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
import {postMenulist , getTextbooklist , getSchoolbooklist} from '../../api/home.js'
import { useStore } from 'vuex';  // 引入 useStore
import { showToast} from 'vant';
const store = useStore();  // 使用 useStore
const router = useRouter();
const navItems = ref([
  { name: '基础练习' },
  { name: '无调号各调式' },
  { name: '一升各调式' },
  { name: '一降各调式' },
]);
const activeSidebar = ref(1);
const searchQuery = ref('');
const list = ref({});

const vipExpireDate = store.getters.getInfo.vipExpireDate;
const isHide = ref(uni.getStorageSync("checkStatus"));


const getMenulist = async () => {
  try {
    const result = await postMenulist(1);
    navItems.value = result.data;
	if(uni.getStorageSync('firstMenu')){
		navItems.value.forEach(e =>{
			if(e.id == uni.getStorageSync('firstMenu')){
				onSelectNavItem(e.id)
			}
		})
	}
  } catch (error) {
    console.error('错误信息:', error);
  }
};

const isShot = ref(false);
const getlist = async () => {
	try {
		list.value = "";
		const data = {
			current:1,
			firstMenu:activeSidebar.value,
			province:"甘肃",
			secondMenu:null,
			size:1000,
			type:1
		}
	  const result = await (!history.state.school ? getTextbooklist(data) : getSchoolbooklist(data));
		
		if(result.data[0]?.shortText2){
			const groupedData = groupByShortText1(result.data);
			
			list.value = groupedData;
			isShot.value = true;
		}else{
			isShot.value = false;
			list.value = result.data;
		}
	
	document.getElementsByClassName('scroll')[0].scrollTop = 0;
	
	} catch (error) {
	  console.error('错误信息:', error);
	}
};


// 根据 shortText1 的值对数据进行分组
const groupByShortText1 = (data) => {
  const groupedData = {};
  data.forEach(item => {
    const { id, title, subTitle, shortText1 ,shortText2 ,vip} = item;
    
    if (!groupedData[shortText2]) {
      groupedData[shortText2] = {
		  name:item.shortText2,
		  list:[]
	  };
    }
    groupedData[shortText2].list.push({ id, title, subTitle, shortText1 ,shortText2,vip});
  });
  return groupedData;
};

const onSelectNavItem = (index) => {
  activeSidebar.value = index;
  getlist()
};


function tap(value) {

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
	
	let arr = [];
	for(let b in list.value){
		let e = list.value[b];
		if(e.list){
			e.list.forEach(a =>{
				arr.push(a.id)
			})
		}else{
			arr.push(e.id)
		}
	}
    router.push({ name: 'music', state: { id: value.id ,type:3,all:JSON.stringify(arr)} });
}

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

onMounted(() => {
  getMenulist(); //获取列表目录
  getlist(); //获取课件列表
});
</script>

<style lang="scss" scoped>
.app-container10 {
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
	padding: 12px 0;
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
					letter-spacing: 1px;
					height: 24px;
					line-height: 24px;
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
