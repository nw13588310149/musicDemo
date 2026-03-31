<template>
	<view class="app-container16">
		<!-- 头部导航 -->
		<view class="top-nav" v-if="activeSidebar == '我的班级'">
		  <view class="nav-items">
			<view class="btn" type="default" v-for="item in navItems"  :class="activeSidebar == item?.name ? 'active' : ''" @click="tap(item)">
				<van-icon class="icon" :name="item.icon" />
				<view class="text">{{item.name}}</view>
			</view>
		  </view>
		</view>
		
		<!-- 返回 -->
		<view class="top-nav2" v-if="activeSidebar  != '我的班级' && showTop">
			  <van-icon class="return" name="/static/assets/left1.png" @click="handleReturn" />
			  {{activeSidebar}}
		</view>
  
	  <!-- 这里将是主体内容 -->
	  <view class="contain" :style="{height:showTop?(activeSidebar == '我的班级'?'calc(100% - 92px)':'calc(100% - 56px)'):'100%','marginTop':showTop?'12px':'0'}">
		  <!-- 动态组件 -->
		  <component @change-component="handleChangeComponent" :is="currentComponent"></component>
  
	  </view>
	  
	  <!-- 即将上线 -->
	  <van-dialog class="qrcode_box" v-model:show="showQrcode" :showConfirmButton='false'>
		  <view style="border-radius:20px;overflow: hidden;">
			  <van-image
				src="/static/assets/sx.jpg"
			  />
	  
		  </view>
		  <view class="close">
			  <van-icon @click="showQrcode = false" name="/static/assets/bg_close.jpg" />
		  </view>
	  </van-dialog>
	</view>
  </template>
  
  <script setup>
  import { ref ,watch,computed } from 'vue';
  import {useRouter} from 'vue-router';
  import classExercise from './class.vue';
  import studentExercise from './student.vue';
  import kebiaoExercise from './kebiao.vue';
  import scoreExercise from './score.vue';
  import workExercise from './work.vue';
  import studentDetailExercise from './student_detail.vue';
  import {getMyInfo} from '/api/home.js';
  import { useStore } from 'vuex';
  import attendanceExercise from './attendance.vue';
  import courseStatsExercise from './course-stats.vue';
  import signApprovalsExercise from './sign-approvals.vue';
  import signRecordsExercise from './sign-records.vue';
  import { markRaw } from 'vue'
  import studentAttendanceExercise from './student-attendance.vue';
  import studentSignExercise from './student-sign.vue';
  import studentSignHistoryExercise from './student-sign-history.vue';
  
  // 将 components 提升到全局作用域
  const components = {
	classExercise: markRaw(classExercise),
	studentExercise: markRaw(studentExercise),
	kebiaoExercise: markRaw(kebiaoExercise),
	scoreExercise: markRaw(scoreExercise),
	workExercise: markRaw(workExercise),
	studentDetailExercise: markRaw(studentDetailExercise),
	attendanceExercise: markRaw(attendanceExercise),
	courseStatsExercise: markRaw(courseStatsExercise),
	signRecordsExercise: markRaw(signRecordsExercise),
	signApprovalsExercise: markRaw(signApprovalsExercise),
	studentAttendanceExercise: markRaw(studentAttendanceExercise),
	studentSignExercise: markRaw(studentSignExercise),
	studentSignHistoryExercise: markRaw(studentSignHistoryExercise),
  };
  
  const store = useStore();
  const navItems = ref([]);
  
  const sf = ref(false);
  
  const showTop = ref(true);
  
  const isShow = computed(() => store.getters.getIsShow);
  watch(isShow, (newValue, oldValue) => {
	showTop.value = !newValue;
  });
  
  getMyInfo().then(res =>{
	  uni.setStorageSync('my',JSON.stringify(res.data.user))
	  if(res.code == 0){
		  if(res.data.user.role == 'teacher'){
			  sf.value = true;
			  
			  navItems.value = [
				  { name: '我的班级', path: components.classExercise, sf: false, icon: "/static/assets/school1.png" },
				  { name: '班级管理', path: components.studentExercise, sf: true, icon: "/static/assets/school2.png" },
				  { name: '我的课表', path: components.kebiaoExercise, sf: false, icon: "/static/assets/school3.png" },
				  { name: '月考成绩', path: components.scoreExercise, sf: false, icon: "/static/assets/school4.png" },
				  // { name: '作业批改', path: components.workExercise, sf: true, icon: "/static/assets/school5.png" },
				  { name: '考勤管理', path: components.attendanceExercise, sf: true, icon: "/static/assets/school1.png" },
				  { name: '课时统计', path: components.courseStatsExercise, sf: false, icon: "/static/assets/school3.png" }
			  ];
			  
			  if(!uni.getStorageSync('checkStatus')){
				  navItems.value = [
					  { name: '我的班级', path: components.classExercise, sf: false, icon: "/static/assets/school1.png" },
					  { name: '班级管理', path: components.studentExercise, sf: true, icon: "/static/assets/school2.png" },
					  { name: '我的课表', path: components.kebiaoExercise, sf: false, icon: "/static/assets/school3.png" },
					  { name: '月考成绩', path: components.scoreExercise, sf: false, icon: "/static/assets/school4.png" }
				  ];
			  }
		  }else{
			  sf.value = false;
			  navItems.value = [
				  { name: '我的班级', path: components.classExercise, sf: false, icon: "/static/assets/school1.png" },
				  { name: '我的课表', path: components.kebiaoExercise, sf: false, icon: "/static/assets/school3.png" },
				  { name: '月考成绩', path: components.scoreExercise, sf: false, icon: "/static/assets/school4.png" },
				  { name: '我的考勤', path: components.studentAttendanceExercise, sf: false, icon: "/static/assets/school1.png" },
				  { name: '课堂签到', path: components.studentSignExercise, sf: false, icon: "/static/assets/school5.png" }
			  ]
		  }
	  }
  })
  
  const router = useRouter();
  const lName = history.state.name;
  const activeSidebar = ref('我的班级');
  const currentComponent = ref(classExercise);
  if(lName == "我的课表"){
	  activeSidebar.value = '我的课表'
	  currentComponent.value = components.kebiaoExercise;
  }
  const searchQuery = ref('');
  
  
  const changeComponent = (component) => {
	currentComponent.value = component;
  };
  
  const showQrcode = ref(false);
  const tap = (item) => {
	  if(item.name == "作业批改"){
		  showQrcode.value = true;
	  }else{
		  activeSidebar.value = item.name;
		  currentComponent.value = item.path;
	  }
  }

  // 处理返回按钮点击
  const handleReturn = () => {
    if (activeSidebar.value === '签课记录' || activeSidebar.value === '签课审批') {
      // 如果是从课时统计进入的签课记录或审批，返回到课时统计
      currentComponent.value = components.courseStatsExercise;
      activeSidebar.value = '课时统计';
    } else if (activeSidebar.value === '签到历史') {
      // 如果是从学生签到进入的历史，返回到课堂签到
      currentComponent.value = components.studentSignExercise;
      activeSidebar.value = '课堂签到';
    } else {
      // 其他情况返回到我的班级
      tap(navItems.value[0]);
    }
  }
  
  const handleChangeComponent = (data) => {
    // 如果传入的是对象，说明是带参数的跳转
    if (typeof data === 'object') {
      switch (data.name) {
        case 'sign-records':
          currentComponent.value = components.signRecordsExercise;
          activeSidebar.value = '签课记录';
          // 传递参数
          if (data.params) {
            currentComponent.value.params = data.params;
          }
          break;
        case 'sign-approvals':
          currentComponent.value = components.signApprovalsExercise;
          activeSidebar.value = '签课审批';
          // 传递参数
          if (data.params) {
            currentComponent.value.params = data.params;
          }
          break;
        case 'course-stats':
          currentComponent.value = components.courseStatsExercise;
          activeSidebar.value = '课时统计';
          // 传递参数
          if (data.params) {
            currentComponent.value.params = data.params;
          }
          break;
        case 'sign-history':
          currentComponent.value = components.studentSignHistoryExercise;
          activeSidebar.value = '签到历史';
          // 传递参数
          if (data.params) {
            currentComponent.value.params = data.params;
          }
          break;
        default:
          // 如果没有匹配的组件名，直接使用传入的组件
          currentComponent.value = data;
      }
    } else {
      // 如果传入的不是对象，说明是直接的组件切换
      currentComponent.value = data;
    }
  };
  
  const exercises = computed(() => {
    const myInfo = JSON.parse(uni.getStorageSync('my') || '{}');
    const isTeacher = myInfo.role === 'teacher';
    
    return {
      attendanceExercise: markRaw(isTeacher ? attendanceExercise : studentAttendanceExercise),
      courseStatsExercise: markRaw(courseStatsExercise),
      signRecordsExercise: markRaw(signRecordsExercise),
      signApprovalsExercise: markRaw(signApprovalsExercise)
    };
  });
  </script>
  
  <style lang="scss" scoped>
  .app-container16 {
	width: 100%;
	height: 100%;
	  .contain{
		  height: calc(100% - 92px);
		  background: #fff;
		  border-radius: 9px;
		  margin-top: 12px;
		  overflow: hidden;
		  position: relative;
	  }
	  .top-nav2{
		  justify-content: center;
		  text-align: center;
		  height: 44px;
		  border-radius: 9px;
		  display: flex;
		  align-items: center;
		  background: #fff;
		  position: relative;
		  .return {
			font-size: 30px;
			position: absolute;
			left: 12px;
		  }
	  }
	  .top-nav {
		display: flex;
		justify-content: flex-start;
		align-items: center;
		height: 81px;
		background: #fff;
		  border-radius: 9px;
		  overflow: hidden;
		  .title {
			width: 44px;
			height: 44px;
			line-height: 44px;
			  text-align: center;
			  font-size: 18px;
			  color: #fff;
			  letter-spacing: 4px;
			  display: flex;
			  align-items: center;
			  justify-content: center;
			/* Add title styling */
			  .right_icon{
				  font-size: 29px;
			  }
		  }
		  
		  .nav-items {
			display: flex;
			  padding-left: 5px;
			/* Add button styling if necessary */
			  .btn{
				  border: none;
				  border-radius: 4px;
				  margin: 0 16px;
				  font-size: 16px;
				  color:#fff;
				  display: flex;
				  flex-direction: column;
				  text-align: center;
				  align-items: center;
				  .icon{
					  font-size: 36px;
				  }
				  .text{
					  font-size: 14px;
					  margin-top: 7px;
				  }
			  }
			  .active{
  
			  }
			  ::v-deep span{
				  color: #545454;
			  }
			  .active ::v-deep span{
				  color: #fff;
			  }
		  }
	  }
	.sidebar {
	  width: 120px;
		  position: relative;
		  background: #fff;
		  border-radius: 14px;
		  padding: 10px;
	  .box{
		  width: 98px;
		  height: 88px;
		  margin-bottom: 16px;
		  background: url(/static/assets/tx_bg.jpg) no-repeat;
		  background-size: cover;
		  border-radius: 6px;
		  overflow: hidden;
		  .title{
				  height: 88px;
				  line-height: 148px;
				  width: 100%;
				  text-align: center;
				  font-size: 16px;
				  font-weight: 400;
				  color: #fff;
				  display: flex;
				  justify-content: center;
				  align-items: center;
				  flex-direction: column;
				  position: relative;
				  top: 16px;
				  .nav_icon{
					  position: absolute;
					  font-size: 24px;
					  top: 6px;
				  }
			  .icon{
				  width: 20px;
				  height: 20px;
				  border-radius: 50%;
				  background: #fff;
				  padding: 2px;
				  position: relative;
				  top: 4px;
				  left: -4px;
			  }
		  }
		  .btn_box{
			  margin: 0 10px;
			  border-top: 1px solid;
			  padding-top: 14px;
			  .btn{
				  width: 78px;
				  background: #fff;
				  color: #1e1e1e;
				  text-align: center;
				  border-radius: 20px;
				  font-size: 14px;
			  }
			  .btn.active{
				  background: #00c9a4;
				  color: #fff;
			  }
			  .btn:first-child{
				  margin-bottom: 10px;
			  }
		  }
	  }
  
	}
  .list_box{
		  background: #fff;
		  border-radius: 14px;
		  padding: 20px 10px;
		  height: 100%;
		  width: 100%;
		  overflow-y: auto;
		  ::v-deep .van-grid-item__content--center{
			  height: 40px;
			  line-height: 40px;
			  position: relative;
			  background: rgb(242 243 247);
			  border-radius: 4px;
			  overflow: hidden;
			  margin-bottom: 5px;
			  .top-right{
				  position: absolute;
				  right: 10px;
			  }
			  .text{
				  padding-left: 20px;
				  font-size: 15px;
				  color: #171a20;
			  }
		  }
		  ::v-deep .van-grid-item__content--center::before{
			  position: absolute;
			  left: 0;
			  top: 0;
			  height: 40px;
			  width: 12px;
			  content: '';
			  background: #00c9a4;
		  }
		  
	  }
	.content {
	  width: calc(100% - 156px);
	  margin-left: 16px;
	  border-radius: 9px;
	  
	  .van-grid{
		  .van-grid-item{
			  height: 40px;
			  position: relative;
		  }
		  .van-grid-item::before{
			  content: '';
			  position: absolute;
			  left: 0;
			  top: 0;
			  width: 14px;
			  height: 40px;
			  background: #111;
			  border-radius: 9px 0 0 10px;
		  }
		  ::v-deep .van-grid-item__content--center {
		  align-items: center;
		  justify-content: center;
		  background: #f2f3f7;
		  border-radius: 14px;
		  border: none;
		  .item-top{
			  width: 100%;
			  position: relative;
			  font-size: 15px;
			  letter-spacing: 1px;
			  padding: 0 10px;
			  color: #656565;
			  padding-left: 16px;
			  .top-right{
				  position: absolute;
				  right: 10px;
				  top: 2px;
				  font-size: 16px;
			  }
		  }
		  }
	  }
	  
	}
	::v-deep .qrcode_box{
		width: 50%;
		background: none;
		.van-dialog__content{
		
			.close{
				position: relative;
				text-align: center;
				font-size: 30px;
				padding-top: 15px;
			}
		
		}
	}
  }
  
  
  </style>