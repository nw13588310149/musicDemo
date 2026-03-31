<template>
  <view class="left-nav" :class="{ collapsed: isCollapsed }">
    <view class="content" v-if="!isCollapsed">
      <view class="nav">
        <view class="zk" @click="toggleCollapse"></view>
        <view class="slide" v-if="activeIndex !== activeNav.length -1 && activeIndex !== -1" :style="slideStyle"></view>
        <view v-for="(item, index) in activeNav" :key="index"
              class="li"
              :class="{ 'li-active': item.active }"
              @click="navigateTo(item.path)">
          <van-icon class="icon" :name="item.active ? item.icon2 : item.icon" :style="{ fontSize: item.name === '小艺同学' ? '22px' : '20px', width: item.name === '小艺同学' ? '22px' : '20px', height: item.name === '小艺同学' ? '22px' : '20px' }"/>
          <text class="wz" :style="{ marginLeft: item.name === '小艺同学' ? '-2px' : '0px' }">
            {{ item.name }}
            <view v-if="item.badge" class="badge" :style="{ background: item.color } " >
              {{ item.badge }}
            </view>
          </text>
        </view>
      </view>
    </view>
    <view class="content2" v-if="isCollapsed">
      <view class="zk" @click="toggleCollapse"></view>
      <view class="slide slide2" v-if="activeIndex !== activeNav.length -1 && activeIndex !== -1" :style="slideStyle"></view>
      <view v-for="(item, index) in activeNav" :key="index"
            class="li"
            :class="{ 'li-active': item.active }"
            @click="navigateTo(item.path)">
        <van-icon class="icon" :name="item.active ? item.icon2 : item.icon"  :style="{ fontSize: item.name === '小艺同学' ? '22px' : '20px', width: item.name === '小艺同学' ? '22px' : '20px', height: item.name === '小艺同学' ? '22px' : '20px' }"/>
      </view>
    </view>
  </view>
</template>

<script setup>
import { useStore } from 'vuex';
import { ref, computed, watch, onMounted, onBeforeUnmount, nextTick } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { defineEmits, watchEffect } from 'vue';
import { CountDown,showConfirmDialog } from 'vant';
import { updateSchool } from '../api/home.js';
import bus from '../utils/eventBus.js';

const isOpen = ref(false);

const store = useStore();
const emit = defineEmits(['toggleCollapse']);
const router = useRouter();
const route = useRoute();
const isCollapsed = ref(false);

function toggleCollapse() {
  isCollapsed.value = !isCollapsed.value;
  emit('toggleCollapse', isCollapsed.value);
  store.commit('setCollapsed', !store.state.isCollapsed);
}

const navItems = ref([
  { name: '首页', icon: '/static/assets/nav_index.png', icon2: '/static/assets/nav_indexA.png', badge: '', active: true, color: '', path: '/', isShow: true },
  { name: '我的云盘', icon: '/static/assets/nav_kj.png', icon2: '/static/assets/nav_kjA.png', badge: '', active: false, color: '#aa96f5', path: '/courseware', isShow: true },
  { name: '视频中心', icon: '/static/assets/nav_play.png', icon2: '/static/assets/nav_palyA.png', badge: '', active: false, color: '', path: '/video-tutorial', isShow: true },
  { name: '智能听写', icon: '/static/assets/nav_tx.png', icon2: '/static/assets/nav_txA.png', badge: '', active: false, color: '', path: '/smart-dictation', isShow: true },
  { name: '音乐伴侣', icon: '/static/assets/nav_music.png', icon2: '/static/assets/nav_musicA.png', badge: '', active: false, color: '', path: '/music', isShow: true },
  { name: '智慧校园', icon: '/static/assets/nav_sc.png', icon2: '/static/assets/nav_scA.png', badge: '', active: false, color: '#e61f62', path: '/smart-campus', isShow: true },
  { name: '我的笔记', icon: '/static/assets/nav_note.png', icon2: '/static/assets/nav_noteA.png', badge: '', active: false, color: '#fea566', path: '/my-notes', isShow: true },
  { name: '录音系统', icon: '/static/assets/nav_ly.png', icon2: '/static/assets/nav_lyA.png', badge: '', active: false, color: '', path: '/recording', isShow: true },
  { name: '我的收藏', icon: '/static/assets/nav_fav.png', icon2: '/static/assets/nav_favA.png', badge: '', active: false, color: '', path: '/my-collection', isShow: true },
  { name: '个人中心', icon: '/static/assets/nav_person.png', icon2: '/static/assets/nav_personA.png', badge: '', active: false, color: '', path: '/personal-center', isShow: true },
  { name: '帮助与反馈', icon: '/static/assets/nav_help.png', icon2: '/static/assets/nav_help.png', badge: '', active: false, color: '', path: '/fankui', isShow: true }
]);

function buildNavItems(coursewareSwitch) {
  const home = {
    name: '首页',
    icon: '/static/assets/nav_index.png',
    icon2: '/static/assets/nav_indexA.png',
    badge: '',
    active: true,
    color: '',
    path: '/',
    isShow: true
  };
  const aiItem = {
    name: '小艺同学',
    icon: '/static/assets/nav_ai.png',
    icon2: '/static/assets/nav_aiA.png',
    badge: '',
    active: false,
    color: '',
    path: '/personal-Ai',
    isShow: true
  };
  const schoolItem = {
    name: '校园课件',
    icon: '/static/assets/nav_school.png',
    icon2: '/static/assets/nav_schoolA.png',
    badge: '',
    active: false,
    color: '#aa96f5',
    path: '/school',
    isShow: isOpen.value
  };
  const tail = [
    { name: '我的云盘', icon: '/static/assets/nav_kj.png', icon2: '/static/assets/nav_kjA.png', badge: '', active: false, color: '#aa96f5', path: '/courseware', isShow: true },
    { name: '视频中心', icon: '/static/assets/nav_play.png', icon2: '/static/assets/nav_palyA.png', badge: '', active: false, color: '', path: '/video-tutorial', isShow: true },
    { name: '智能听写', icon: '/static/assets/nav_tx.png', icon2: '/static/assets/nav_txA.png', badge: '', active: false, color: '', path: '/smart-dictation', isShow: true },
    { name: '音乐伴侣', icon: '/static/assets/nav_music.png', icon2: '/static/assets/nav_musicA.png', badge: '', active: false, color: '', path: '/music', isShow: true },
    { name: '智慧校园', icon: '/static/assets/nav_sc.png', icon2: '/static/assets/nav_scA.png', badge: '', active: false, color: '#e61f62', path: '/smart-campus', isShow: true },
    { name: '我的笔记', icon: '/static/assets/nav_note.png', icon2: '/static/assets/nav_noteA.png', badge: '', active: false, color: '#fea566', path: '/my-notes', isShow: true },
    { name: '录音系统', icon: '/static/assets/nav_ly.png', icon2: '/static/assets/nav_lyA.png', badge: '', active: false, color: '', path: '/recording', isShow: true },
    { name: '我的收藏', icon: '/static/assets/nav_fav.png', icon2: '/static/assets/nav_favA.png', badge: '', active: false, color: '', path: '/my-collection', isShow: true },
    { name: '个人中心', icon: '/static/assets/nav_person.png', icon2: '/static/assets/nav_personA.png', badge: '', active: false, color: '', path: '/personal-center', isShow: true },
    { name: '帮助与反馈', icon: '/static/assets/nav_help.png', icon2: '/static/assets/nav_help.png', badge: '', active: false, color: '', path: '/fankui', isShow: true }
  ];
  if (coursewareSwitch) {
    return [home, aiItem, schoolItem, ...tail];
  }
  return [home, aiItem, ...tail];
}

async function refreshSchoolNav() {
  try {
    const res = await updateSchool();
    if (res && res.code === 0 && res.data != null) {
      navItems.value = buildNavItems(!!res.data.coursewareSwitch);
      activeIndex.value = navItems.value.findIndex((item) => item.path === route.path);
    }
  } catch (e) {
    /* 未登录或接口失败时保留默认导航 */
  }
}

const activeIndex = ref(navItems.value.findIndex((item) => item.path === route.path));

let unwatch = null;
onMounted(() => {
  unwatch = router.afterEach(() => {});
  refreshSchoolNav();
  bus.on('login-success', refreshSchoolNav);
});

onBeforeUnmount(() => {
  if (typeof unwatch === 'function') unwatch();
  bus.off('login-success', refreshSchoolNav);
});

// 计算属性，用于确定哪个导航项是激活的
const activeNav = computed(() => {
  return navItems.value.map((item, index) => {
    if (item.path === route.path) {
      activeIndex.value = index;
    }
    return {
      ...item,
      active: item.path === route.path,
    };
  });
});

const slideStyle = computed(() => {
  return {
    top: `${activeIndex.value * 50 + 15}px`, // 50px 是每个 li 元素的高度，包括 margin
    transition: 'top 0.1s ease', // 添加平滑过渡效果
  };
});

// 导航点击切换事件
function navigateTo(path) {
	if(history.state.current == "/answer" || history.state.current == "/answer2" || history.state.current == "/answer3"){
		showConfirmDialog({
		  message:
		    '是否退出当前练习',
		})
		  .then(() => {
		    // on confirm
			router.push(path);
		  })
		  .catch(() => {
		    // on cancel
		  });
	}else{
		router.push(path);
	}
}

// 监听路由变化，更新 activeIndex
watch(route, async () => {
  activeIndex.value = navItems.value.findIndex(item => item.path === route.path);
  await nextTick(); // 等待DOM更新完成
  const pages = history.state.current;
  if (pages === '/smart-campus' || pages === '/chat') {
    navItems.value[5].badge = 0;
  }
});

const num = ref(0);
watchEffect(() => {
  const list = store.getters.getMsg;
  num.value = list.length; // 修正这里的赋值逻辑
  navItems.value[5].badge = num.value;
});
</script>


<style scoped>
.left-nav {
  padding: 0 12px 0 18px;
  width: 205px;
  height: 100%;
  position: relative;
}

.left-nav.collapsed {
  width: 71px; /* 设置缩入后的宽度 */
}
.slide2{
	background: #e0f8f1 !important;
	width: 40px !important;
	height: 40px !important;
	margin-top: 3px;
}

.content {
  background: #fff;
  border-radius: 9px;
  height: 100%;
  overflow: hidden;
}

.nav {
  background: #fff;
  border-radius: 9px;
  padding: 15px;
  height: 100%;
  display: flex;
  flex-direction: column;
  position: relative;
}

.li {
  width: 100%;
  height: 46px;
  line-height: 46px;
  display: flex;
  align-items: center;
  justify-content: flex-start;
  color: #171a20;
  margin-bottom: 4px;
  border-radius: 6px;
  z-index: 1;
}
.li:last-child {
  margin-top: auto;
  padding:0 10%;
  position: relative;
  top: 16px;
  background: none !important;
      display: flex;
      justify-content: center;
}
.li:last-child .icon {
  width: 16px;
  height: 16px;
  font-size: 16px;
  margin-left: 0px;
}
.li:last-child .wz {
  color: #999999;
  letter-spacing: 0px;
  font-size: 13px !important;
}
.li:last-child .wz ::v-deep span {
  color: #939393;
  font-size: 13px !important;
}

.li-active {
  /* background: #f6f7fb; */
  font-weight: 400;
}
.li-active .wz ::v-deep span {
  color: #000;
  font-size: 19px;
  position: relative;
}
.li-active .icon {
  width: 22px;
  height: 22px;
  font-size: 22px;
}

.icon {
  margin-right: 10px;
  width: 20px;
  height: 20px;
  margin-left: 20px;
  font-size: 20px;
}

.wz {
  position: relative;
  font-size: 18px;
  color: #171a20;
  top:1px;
  transition: font-size 0.1s; /* 设置字体大小变化的过渡时间 */
}
.wz ::v-deep span{
	  transition: font-size 0.1s; /* 设置字体大小变化的过渡时间 */
}

.badge {
	min-width: 18px;
    font-size: 11px;
    position: absolute;
    right: -11px;
    top: 6px;
    height: 14px;
    line-height: 14px;
    justify-content: center;
    display: flex;
    align-items: center;
    text-align: center;
    padding: 0 4px;
    border-radius: 14px;
    color: white;
}

.slide {
  position: absolute;
  width: calc(100% - 30px);
  height: 46px;
  background: #f6f7fb;
  border-radius: 6px;
  z-index: 0;
  transition: top 0.1s ease; /* 平滑过渡效��� */
}
.left-nav.collapsed .slide {
  width: calc(100% - 10px); /* 调整缩入状态下的 slide 宽度 */
}
.zk{
	font-size: 50px;
	position: absolute;
	right: 0;
	top: 78%;
	width: 18px;
	height: 36px;
	transform: translateY(-50px);
	background: url("/static/assets/xz.png") no-repeat;
	background-size: 200% 100%;
	z-index: 9;
}
.content2{
	background: #fff;
	position: absolute;
	left: 0;
	height: 100%;
	padding: 15px 4px 15px 4px;
	border-radius: 0 9px 9px 0;
	display: flex;
	flex-direction: column;
	align-items: center;
	.li{
		display: flex;
		.icon{
			margin: 0 15px;
		}
	}
	.zk{
		background: url(/static/assets/xy.png) no-repeat;
		background-size: 200% 100%;
		background-position: 100% 0;
		right: -18px;
		z-index: 99;
	}
}
.content2 .li:last-child{
		position: absolute;
		bottom: 0;
		left: 4px;
		padding: 0;
	}
</style>

