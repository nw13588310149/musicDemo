<template>
  <view class="attendance">
    <!-- 头部导航 -->
    <view class="header">
      <view class="class-select" v-if="classAll?.length > 1" @click="showPicker = !showPicker">
        <text>{{activeClass.name}}</text>
        <van-icon :name="showPicker ? 'arrow-up' : 'arrow-down'" />
      </view>
      <van-tabs v-model:active="activeTab" color="#00c9a4">
        <van-tab title="考勤记录" name="record" />
        <van-tab title="请假管理" name="leave" />
        <van-tab title="统计分析" name="stats" />
      </van-tabs>
    </view>

    <!-- 考勤记录 -->
    <view class="content" v-show="activeTab === 'record'">
      <template v-if="currentSignableCourse">
        <!-- 顶部操作栏 -->
        <view class="action-bar">
          <view class="search-box">
            <van-search
              v-model="searchName"
              placeholder="搜索学生姓名"
              shape="round"
              background="transparent"
            />
          </view>
          <view class="buttons">
            <van-button 
              round 
              size="small" 
              type="primary"
              color="#00c9a4"
              @click="handleBatchAttendance('present')"
            >
              一键到齐
            </van-button>
          </view>
        </view>

        <!-- 考勤统计卡片 -->
        <view class="stat-cards">
          <view class="stat-card">
            <text class="value">{{stats.total || 0}}</text>
            <text class="label">应到人数</text>
          </view>
          <view class="stat-card">
            <text class="value success">{{stats.present || 0}}</text>
            <text class="label">实到人数</text>
          </view>
          <view class="stat-card">
            <text class="value danger">{{stats.absent || 0}}</text>
            <text class="label">缺勤人数</text>
          </view>
          <view class="stat-card">
            <text class="value warning">{{stats.leave || 0}}</text>
            <text class="label">请假人数</text>
          </view>
        </view>

        <!-- 考勤列表 -->
        <view class="attendance-list">
          <template v-if="studentList.length > 0">
            <view 
              class="student-item" 
              v-for="student in filteredStudentList" 
              :key="student.id"
            >
              <view class="student-info">
                <van-image
                  class="avatar"
                  round
                  width="40"
                  height="40"
                  :src="student.headUrl || '/static/assets/head.jpg'"
                />
                <view class="info">
                  <text class="name">{{student.realname || student.nickname}}</text>
                  <text class="id">手机号：{{student.mobile}}</text>
                </view>
              </view>
              <view class="status-group">
                <van-radio-group 
                  v-model="student.status" 
                  direction="horizontal"
                  @change="handleStatusChange(student)"
                >
                  <van-radio 
                    v-for="(text, status) in STATUS_TEXT" 
                    :key="status"
                    :name="status"
                    :checked-color="getStatusColor(status)"
                  >
                    {{text}}
                  </van-radio>
                </van-radio-group>
              </view>
            </view>
          </template>
          <template v-else>
            <view class="empty-attendance">
              <van-empty
                image="search"
                description="暂无签到记录，请点击一键到齐开始考勤"
              >
                <template #bottom>
                  <van-button 
                    round 
                    type="primary" 
                    color="#00c9a4"
                    size="small"
                    @click="handleBatchAttendance('present')"
                  >
                    一键到齐
                  </van-button>
                </template>
              </van-empty>
            </view>
          </template>
        </view>

      </template>
      
      <template v-else>
        <view class="no-course">
          <van-empty
            image="search"
            :description="`当前班级暂无可签到课程
${dayjs().format('YYYY-MM-DD HH:mm:ss')}`"
          />
        </view>
      </template>
    </view>

    <!-- 请假管理 -->
    <view class="content leave-content" v-show="activeTab === 'leave'">
      <view class="leave-header">
        <view class="header-left">
          <view class="title"></view>
          <view class="filter-tabs">
            <view 
              class="tab-item" 
              v-for="option in leaveStatusOptions" 
              :key="option.value"
              :class="{ active: leaveStatus === option.value }"
              @click="leaveStatus = option.value"
            >
              {{option.text}}
              <!-- <text class="count" v-if="getStatusCount(option.value)">
                {{getStatusCount(option.value)}}
              </text> -->
            </view>
          </view>
        </view>
      </view>

      <view class="leave-list">
        <view class="empty" v-if="!leaveList.length">
          <van-empty description="暂无请假记录" />
        </view>
        <view class="leave-item" v-for="leave in filteredLeaveList" :key="leave.id">
          <view class="leave-card">
            <view class="card-header">
              <view class="student-info">
                <van-image
                  class="avatar"
                  width="40" 
                  height="40"
                  round
                  :src="leave.studentHead"
                />
                <view class="info">
                  <view class="name">{{leave.studentName}}</view>
                  <view class="status" :class="leave.status">
                    <van-icon :name="getStatusIcon(leave.status)" />
                    {{getLeaveStatus(leave.status)}}
                  </view>
                </view>
              </view>
              <view class="type-tag" :class="leave.type">
                <van-icon :name="getTypeIcon(leave.type)" />
                {{getLeaveType(leave.type)}}
              </view>
            </view>
            <view class="card-content">
              <view class="time-range">
                <van-icon name="clock-o" />
                <text>{{leave.startTime}} 至 {{leave.endTime}}</text>
                <text class="duration">{{getDuration(leave.startTime, leave.endTime)}}天</text>
              </view>
              <view class="reason">
                <text class="label">请假原因：</text>
                <text>{{leave.reason}}</text>
              </view>
              <view class="create-time">
                <van-icon name="underway-o" />
                申请时间：{{leave.createTime}}
              </view>
            </view>
            <view class="card-footer" v-if="leave.status === 'pending'">
              <van-button 
                round
                size="small"
                plain
                type="danger"
                icon="close"
                @click="handleLeave(leave.id, 'reject')"
              >拒绝</van-button>
              <van-button 
                round
                size="small" 
                type="primary"
                color="#00c9a4"
                icon="success"
                @click="handleLeave(leave.id, 'approve')"
              >批准</van-button>
            </view>
          </view>
        </view>
      </view>
    </view>

    <!-- 统计分析 -->
    <view class="content stats-content" v-show="activeTab === 'stats'">
      <view class="filter-bar">
        <view class="filter-group">
          <!-- 快捷时间选择 -->
          <view class="quick-range">
            <van-button 
              round 
              size="small" 
              :type="timeRange === range ? 'primary' : 'default'"
              :color="timeRange === range ? '#00c9a4' : ''"
              v-for="range in timeRanges" 
              :key="range"
              @click="selectTimeRange(range)"
            >{{range}}</van-button>
          </view>
          <!-- 自定义时间范围 -->
          <view class="date-range-picker">
            <view class="date-item" @click="openDatePicker('statsStart')">
              <text class="label">开始日期</text>
              <view class="value">
                <text>{{statsDateRange.start || '请选择'}}</text>
                <van-icon name="calendar-o" />
              </view>
            </view>
            <view class="separator">
              <van-icon name="arrow" />
            </view>
            <view class="date-item" @click="openDatePicker('statsEnd')">
              <text class="label">结束日期</text>
              <view class="value">
                <text>{{statsDateRange.end || '请选择'}}</text>
                <van-icon name="calendar-o" />
              </view>
            </view>
          </view>
        </view>
      </view>

      <!-- 统计图表 -->
      <view class="stats-charts">
        <!-- 考勤率统计卡片 -->
        <view class="chart-card">
          <view class="card-header">
            <text class="title">考勤率统计</text>
            <view class="rate">
              <text class="value">{{statsData.attendanceRate}}%</text>
              <text class="label">总考勤率</text>
            </view>
          </view>
          <view class="card-content">
            <view class="stat-item" v-for="item in statsData.details" :key="item.type">
              <view class="info">
                <text class="label">{{item.label}}</text>
                <text class="count">{{item.count}}人次</text>
              </view>
              <view class="progress-bar">
                <view 
                  class="progress" 
                  :style="{width: item.rate + '%', background: item.color}"
                ></view>
              </view>
              <text class="rate">{{item.rate}}%</text>
            </view>
          </view>
        </view>
      </view>

      <!-- 考勤排名 -->
      <view class="ranking-list">
        <view class="ranking-header">
          <text class="title">考勤排名</text>
        </view>
        <view class="ranking-table">
          <view class="table-header">
            <text>排名</text>
            <text>姓名</text>
            <text>出勤率</text>
            <text>出勤/总课时</text>
          </view>
          <view 
            class="table-row" 
            v-for="(item, index) in rankingList" 
            :key="index"
            :class="{'top3': index < 3}"
          >
            <view class="rank">
              <text v-if="index < 3" class="medal">{{getMedal(index)}}</text>
              <text v-else>{{index + 1}}</text>
            </view>
            <view class="student-info">
              <van-image class="avatar" round :src="item.headUrl" />
              <text>{{item.name}}</text>
            </view>
            <view class="rate">
              <view class="progress-bar">
                <view 
                  class="progress" 
                  :style="{width: item.rate + '%'}"
                ></view>
              </view>
              <text>{{item.rate}}%</text>
            </view>
            <view class="count">{{item.attendCount}}/{{item.totalCount}}</view>
          </view>
        </view>
      </view>
    </view>

    <!-- 弹窗组件 -->
    <van-calendar 
      v-model:show="showCalendar" 
      @confirm="onSelectDate" 
      :min-date="minDate"
      :max-date="maxDate"
      color="#00c9a4"
    />
    
    <van-popup v-model:show="showPicker" round position="bottom">
      <van-picker
        :columns="columns"
        @cancel="showPicker = false"
        @confirm="onSelectClass"
        show-toolbar
        title="选择班级"
      />
    </van-popup>

    <!-- 请假单 -->
    <van-popup
      v-model:show="showLeaveForm"
      round
      position="bottom"
      :style="{ height: '70%' }"
    >
      <view class="leave-form">
        <view class="form-header">
          <text>请假申请</text>
          <van-icon name="cross" @click="showLeaveForm = false" />
        </view>
        
        <view class="form-content">
          <van-cell-group>
            <van-field
              v-model="leaveForm.studentName"
              label="学生姓名"
              placeholder="请选择学生"
              readonly
              @click="showStudentPicker = true"
            />
            
            <van-field
              v-model="leaveForm.type"
              label="请假类型"
              placeholder="请选择请假类型"
              readonly
              @click="showTypePicker = true"
            />
            
            <van-field
              v-model="leaveForm.startTime"
              label="开始时间"
              placeholder="请选择开始时间"
              readonly
              @click="showDatePicker = true; dateType = 'start'"
            />
            
            <van-field
              v-model="leaveForm.endTime"
              label="结束时间"
              placeholder="请选择结束时间"
              readonly
              @click="showDatePicker = true; dateType = 'end'"
            />
            
            <van-field
              v-model="leaveForm.reason"
              label="请假原因"
              type="textarea"
              placeholder="请输入请假原因"
              autosize
            />
          </van-cell-group>
          
          <view class="upload-box">
            <text class="label">附件上传</text>
            <van-uploader
              :after-read="afterRead"
              v-model="leaveForm.attachments"
              multiple
              :max-count="3"
            />
          </view>
        </view>
        
        <view class="form-footer">
          <van-button block type="primary" color="#00c9a4" @click="submitLeave">
            提交申请
          </van-button>
        </view>
      </view>
    </van-popup>

    <!-- 日期选择器 -->
    <van-calendar 
      v-model:show="showStatsDatePicker"
      :min-date="minDate"
      :max-date="maxDate" 
      @confirm="onStatsDateConfirm"
    />
  </view>
</template>

<script setup>
import { ref, onMounted, watch, computed, onUnmounted } from 'vue';
import { showToast, showDialog } from 'vant';
import dayjs from 'dayjs';
import { classList, classManageMemberList, courseList, teacherStudentSignInList, teacherStudentSignInOneKey ,teacherStudentSignInUpdate, teacherStudentLeaveList, teacherStudentLeaveAudit, teacherStatisticalAnalysis} from '/api/home.js';

// 日期相关
const currentDate = ref(dayjs().format('YYYY-MM-DD'));
const showCalendar = ref(false);
const minDate = ref(dayjs().subtract(1, 'year').toDate());
const maxDate = ref(dayjs().add(1, 'year').toDate());

// 班级相关
const showPicker = ref(false);
const columns = ref([]);
const classAll = ref([]);
const activeClass = ref({});
const activeTab = ref('record'); // 默认选中考勤记录tab

// 学生列表
const studentList = ref([
  {
    id: 1,
    realname: '张三',
    nickname: '小张',
    studentId: '2024001',
    headUrl: '/static/assets/head.jpg',
    status: 'present',
    checkTime: '08:00:00'
  },
  {
    id: 2,
    realname: '李四',
    nickname: '小李',
    studentId: '2024002', 
    headUrl: '/static/assets/head.jpg',
    status: 'late',
    checkTime: '08:15:00'
  },
  {
    id: 3,
    realname: '王五',
    nickname: '小王',
    studentId: '2024003',
    headUrl: '/static/assets/head.jpg',
    status: 'absent',
    checkTime: ''
  },
  {
    id: 4,
    realname: '赵六',
    nickname: '小',
    studentId: '2024004',
    headUrl: '/static/assets/head.jpg',
    status: 'leave',
    checkTime: ''
  },
  {
    id: 5,
    realname: '孙七',
    nickname: '小',
    studentId: '2024005',
    headUrl: '/static/assets/head.jpg',
    status: 'present',
    checkTime: '07:55:00'
  }
]);

// 考勤统计
const stats = ref({
  total: 5,
  present: 2,
  absent: 1,
  leave: 1,
  late: 1
});

// 请假相关状态
const showLeaveForm = ref(false);
const leaveStatus = ref('all');
const leaveStatusOptions = [
  { text: '全部', value: 'all' },
  { text: '待审批', value: 'pending' },
  { text: '已批准', value: 'approved' },
  { text: '已拒绝', value: 'rejected' }
];

const leaveForm = ref({
  studentId: '',
  studentName: '',
  type: 'sick', // sick: 病假, personal: 事假
  startTime: '',
  endTime: '',
  reason: '',
  attachments: []
});

const leaveList = ref([
  {
    id: 1,
    studentName: '张三',
    studentHead: '/static/assets/head.jpg',
    type: 'sick',
    status: 'pending',
    startTime: '2024-03-20',
    endTime: '2024-03-21',
    reason: '感冒发烧',
    createTime: '2024-03-19 14:30'
  },
  {
    id: 2,
    studentName: '李四',
    studentHead: '/static/assets/head.jpg',
    type: 'personal',
    status: 'approved',
    startTime: '2024-03-22',
    endTime: '2024-03-23',
    reason: '参加比赛',
    createTime: '2024-03-19 15:20'
  },
  {
    id: 3,
    studentName: '王五',
    studentHead: '/static/assets/head.jpg',
    type: 'sick',
    status: 'rejected',
    startTime: '2024-03-24',
    endTime: '2024-03-25',
    reason: '身体不适',
    createTime: '2024-03-19 16:10'
  }
]);

const showDatePicker = ref(false);
const dateType = ref('start'); // start: 开始时间, end: 结束时间

// 统计分析相关
const showStatsDatePicker = ref(false);
const statsDatePickerType = ref('statsStart');
const statsDateRange = ref({
  start: dayjs().startOf('week').format('YYYY-MM-DD'),
  end: dayjs().format('YYYY-MM-DD')
});

// 统计数据
const statsData = ref({
  attendanceRate: 95,
  details: [
    { type: 'present', label: '出勤', count: 120, rate: 80, color: '#00c9a4' },
    { type: 'late', label: '迟到', count: 15, rate: 10, color: '#faad14' },
    { type: 'absent', label: '缺勤', count: 8, rate: 5, color: '#ff4d4f' },
    { type: 'leave', label: '请假', count: 7, rate: 5, color: '#1890ff' }
  ]
});

// 排名数据
const rankingList = ref([
  { 
    name: '张三',
    headUrl: '/static/assets/head.jpg',
    rate: 98,
    attendCount: 49,
    totalCount: 50
  },
  { 
    name: '李四',
    headUrl: '/static/assets/head.jpg',
    rate: 96,
    attendCount: 48,
    totalCount: 50
  },
  { 
    name: '王五',
    headUrl: '/static/assets/head.jpg',
    rate: 94,
    attendCount: 47,
    totalCount: 50
  },
  { 
    name: '赵六',
    headUrl: '/static/assets/head.jpg',
    rate: 92,
    attendCount: 46,
    totalCount: 50
  },
  { 
    name: '孙七',
    headUrl: '/static/assets/head.jpg',
    rate: 90,
    attendCount: 45,
    totalCount: 50
  }
]);

// 时间范围相关
const timeRange = ref('本周');
const timeRanges = ['本周', '本月'];

// 添加以下数据和方法
const searchName = ref('');

// 过滤后的学生列表
const filteredStudentList = computed(() => {
  if (!searchName.value) return studentList.value;
  return studentList.value.filter(student => 
    (student.realname || student.nickname)
      .toLowerCase()
      .includes(searchName.value.toLowerCase())
  );
});

// 添加分页相关的状态
const current = ref(1);
const size = ref(10);
const total = ref(0);

// 添加状态映射
const STATUS_MAP = {
  0: 'present',  // 出勤
  1: 'absent',   // 缺勤
  2: 'late',     // 迟到
  3: 'leave'     // 请假
};

const STATUS_TEXT = {
  present: '出勤',
  absent: '缺勤',
  late: '迟到',
  leave: '请假'
};

// 添加获取课表的相关状态
const todayCourses = ref([]);
const userInfo = ref(uni.getStorageSync('userInfo') || {});

// 当前可签到的课程
const currentSignableCourse = ref(null);

// 判断是否在课程时间范围内
const checkCourseTime = (course) => {
  const now = dayjs();
  const courseTime = dayjs(course.createTime);
  const startTime = courseTime.subtract(10, 'minute');
  const endTime = courseTime.add(50, 'minute');
  
  return now.isAfter(startTime) && now.isBefore(endTime);
};

// 检查当前是否有可签到课程
const checkCurrentCourse = async () => {
  if (!todayCourses.value || !todayCourses.value[currentDate.value]) {
    currentSignableCourse.value = null;
    return;
  }
  
  const signable = todayCourses.value[currentDate.value].find(course => checkCourseTime(course));
  currentSignableCourse.value = signable || null;
  
  // 如果有可签到课程，获取签到列表
  if (currentSignableCourse.value) {
    await getSignInList();
  }
};

// 获取课表数据的方法
const getCourseList = async () => {
  try {
    const today = dayjs();
    const params = {
      beginDate: today.startOf('day').format('YYYY-MM-DD HH:mm:ss'),
      endDate: today.endOf('day').format('YYYY-MM-DD HH:mm:ss'),
      classId: activeClass.value?.id,
      teacherId: userInfo.value?.id
    };
    
    const res = await courseList(params);
    if (res.code === 0) {
      todayCourses.value = res.data || [];
      // 检查当前可签到课程
      await checkCurrentCourse();
    } else {
      showToast('获取课表失败');
    }
  } catch (error) {
    console.error('获取课表失败:', error);
    showToast('获取课表失败');
  }
};

// 修改 getSignInList 方法
const getSignInList = async () => {
  try {
    const params = {
      classId: activeClass.value?.id,
      courseId: currentSignableCourse.value?.id,
      current: current.value,
      date: currentDate.value,
      size: size.value
    };
    
    const res = await teacherStudentSignInList(params);
    if (res.code === 0) {
      // 更新学生列表
      studentList.value = res.data.list.map(item => ({
        id: item.studentId,
        realname: item.student.realname,
        nickname: item.student.nickname,
        headUrl: item.student.headUrl,
        status: STATUS_MAP[item.status],
        checkTime: dayjs(item.createTime).format('HH:mm:ss'),
        mobile: item.student.mobile,
        signId: item.id // 保存签到记录ID，用于后续更新
      }));
      
      // 更新统计数据
      stats.value = {
        total: studentList.value.length,
        present: Number(res.data.sum.status0Count) || 0, // 出勤
        absent: Number(res.data.sum.status1Count) || 0,  // 缺勤
        late: Number(res.data.sum.status2Count) || 0,    // 迟到
        leave: Number(res.data.sum.status3Count) || 0    // 请假
      };
      
      // 设置是否显示一键到齐提示
      const noAttendance = Object.values(res.data.sum).every(count => Number(count) === 0);
      isAttending.value = !noAttendance;
    } else {

    }
  } catch (error) {
    console.error('获取签到列表失败:', error);

  }
};

// 修改 handleBatchAttendance 方法
const handleBatchAttendance = async (status) => {
  if (!currentSignableCourse.value) {
    showToast('当前没有可签到的课程');
    return;
  }

  try {
    await showDialog({
      title: '一键考勤',
      message: '确定将所有学生标记为已到吗？',
      confirmButtonText: '确定',
      confirmButtonColor: '#00c9a4',
    });
    
    // 调用一键到齐接口
    const res = await teacherStudentSignInOneKey({
      classId: activeClass.value?.id
    });
    
    if (res.code === 0) {
      showToast({
        type: 'success',
        message: '考勤完成'
      });
      
      // 重新获取签到列表
      await getSignInList();
    } else {
      showToast(res.msg || '一键到齐失败');
    }
  } catch (error) {
    if (error.toString().includes('cancel')) return; // 用户取消操作
    console.error('一键到齐失败:', error);
    showToast('一键到齐失败');
  }
};

// 监听班级变化，新获取课
watch(() => activeClass.value?.id, (newVal) => {
  if (newVal) {
    getCourseList();
  }
});

// 在初始化数据的方法中添加获取课表的调用
const initData = async () => {
  await initClassList();
  if (activeClass.value?.id) {
    await getCourseList();
  }
};

// 修改 onMounted
onMounted(() => {
  initData();
  checkInterval = setInterval(checkCurrentCourse, 60000); // 每分钟检查一次
});

onUnmounted(() => {
  if (checkInterval) {
    clearInterval(checkInterval);
  }
});

// 获取班级列表
const initClassList = async () => {
  try {
    const res = await classList();
    if (res.code === 0 && res.data.length > 0) {
      classAll.value = res.data;
      // 获取默认班级
      const defaultClass = uni.getStorageSync('defaultClass');
      if (defaultClass) {
        activeClass.value = JSON.parse(defaultClass);
      } else {
        activeClass.value = res.data[0];
        uni.setStorageSync('defaultClass', JSON.stringify(res.data[0]));
      }
      
      // 设置选择器数据
      columns.value = res.data.map(item => ({
        text: item.name,
        value: item.id
      }));

      // 获取学生列表
      await getStudentList();
    } else {
      showToast('暂无班级数据');
    }
  } catch (error) {
    console.error('获取班级列表失败:', error);
    showToast('获取班级列表失败');
  }
};

// 获取学生列表
const getStudentList = async () => {
  try {
    // 使用模拟数据
    // 实际项目中这里会调用API获取数据
    updateStats();
  } catch (error) {
    console.error('获取学生列表失败:', error);
    showToast('获取学生列表失败');
  }
};

// 更新统计数据
const updateStats = async () => {
  stats.value = {
    total: studentList.value.length,
    present: studentList.value.filter(s => s.status === 'present').length,
    absent: studentList.value.filter(s => s.status === 'absent').length,
    leave: studentList.value.filter(s => s.status === 'leave').length,
    late: studentList.value.filter(s => s.status === 'late').length
  };
};

// 监听状态变化
watch(() => studentList.value.map(s => s.status), () => {
  updateStats();
}, { deep: true });

// 选择班级
const onSelectClass = async (value) => {
  activeClass.value = classAll.value[value.selectedIndexes[0]];
  uni.setStorageSync('defaultClass', JSON.stringify(activeClass.value));
  showPicker.value = false;
  await getStudentList();
  await getLeaveList();
};

// 选择日期
const onSelectDate = (value) => {
  currentDate.value = dayjs(value).format('YYYY-MM-DD');
  showCalendar.value = false;
  // TODO: 获取选中日期的���勤记录
};

// 处理考勤态变化
const handleStatusChange = async (student) => {
  // 根据状态映射转换status
  const statusCode = Object.entries(STATUS_MAP).find(([code, status]) => status === student.status)?.[0];
  
  await teacherStudentSignInUpdate({
    id: student.signId,
    status: statusCode
  });
  if(res.code === 0){
    
  }else{
    showToast(res.msg);
  } 
  updateStats();
};

// 保存考勤
const saveAttendance = async () => {
  if (!isAttending.value) {
    showToast('请先开始考勤');
    return;
  }

  const attendanceData = {
    classId: activeClass.value.id,
    date: currentDate.value,
    records: studentList.value.map(student => ({
      studentId: student.id,
      status: student.status,
      checkTime: student.checkTime
    }))
  };

  // TODO: 调用保存考勤API
  console.log('保存考勤数据:', attendanceData);
  showToast('保存成功');
  isAttending.value = false;
  // 停止计时
  clearInterval(timerInterval);
};

// 获取请假记录
const getLeaveList = async () => {
  try {
    const params = {
      classId: activeClass.value?.id,
      current: current.value,
      size: size.value,
      status: leaveStatus.value === 'all' ? undefined : getStatusCode(leaveStatus.value)
    };
    
    const res = await teacherStudentLeaveList(params);
    if (res.code === 0) {
      // 转换接口数据为组件所需格式
      if (!res.data || res.data.length === 0) {
        leaveList.value = [];
        nextTick(() => {
          // 强制更新视图
          leaveList.value = [...leaveList.value];
        });
        return;
      }
      
      leaveList.value = res.data.map(item => ({
        id: item.id,
        studentId: item.studentId,
        studentName: item.student.realname || item.student.nickname, // 使用studentId作为名称，因为接口没返回name
        studentHead: item.student.headUrl || '/static/assets/head.jpg',
        type: item.type === 1 ? 'sick' : 'personal',
        startTime: item.startTime,
        endTime: item.endTime,
        reason: item.leaveReason,
        status: getStatusValue(item.status),
        createTime: item.createTime,
        auditReason: item.auditReason
      }));

      nextTick(() => {
        // 强制更新视图
        leaveList.value = [...leaveList.value];
      });
    }
  } catch (error) {
    console.error('获取请假记录失败:', error);
  }
};

// 处理请假申请
const handleLeave = async (leaveId, action) => {
  const actionText = action === 'approve' ? '批准' : '拒绝';
  try {
    const result = await showDialog({
      title: `${actionText}请假`,
      message: `确定要${actionText}这条请假申请吗？`,
      confirmButtonText: '确定',
      showCancelButton: true,
      cancelButtonText: "取消",
      confirmButtonColor: action === 'approve' ? '#00c9a4' : '#ff4d4f'
    }).catch(() => {
      // 用户点击取消或关闭
      return false;
    });

    // 如果用户取消或关闭对话框，直接返回
    if (!result) {
      return;
    }
    
    // TODO: 调处理请假API
    await teacherStudentLeaveAudit({
      id: leaveId,
      status: action === 'approve' ? 1 : 2,
      auditReason: '' // 可选的审批意见
    });
    
    showToast({
      type: 'success',
      message: `已${actionText}`
    });
    
    // 刷新请假列表
    getLeaveList();
  } catch (error) {
    console.error('处理请假失败:', error);
    showToast('处理失败');
  }
};

// 提交请假申请
const submitLeave = async () => {
  if (!leaveForm.value.studentId || !leaveForm.value.startTime || !leaveForm.value.endTime || !leaveForm.value.reason) {
    showToast('请填写完整信息');
    return;
  }
  
  try {
    // TODO: 调用提交请假API
    // await submitLeaveRequest({
    //   ...leaveForm.value,
    //   classId: activeClass.value.id,
    //   createTime: dayjs().format('YYYY-MM-DD HH:mm:ss')
    // });
    
    showToast({
      type: 'success',
      message: '提交成功'
    });
    
    showLeaveForm.value = false;
    getLeaveList();
  } catch (error) {
    console.error('提交请假失败:', error);
    showToast('提交失败');
  }
};

// 获取请假状态文本
const getLeaveStatus = (status) => {
  const statusMap = {
    pending: '待审批',
    approved: '已批准',
    rejected: '已拒绝'
  };
  return statusMap[status] || status;
};

// 获取请假类型文本
const getLeaveType = (type) => {
  const typeMap = {
    sick: '病假',
    personal: '事假'
  };
  return typeMap[type] || type;
};

// 监听请假状态变化
watch(leaveStatus, () => {
  current.value = 1; // 切换状态时重置页码
  getLeaveList();
});

// 获取状态图标
const getStatusIcon = (status) => {
  const iconMap = {
    pending: 'clock-o',
    approved: 'passed',
    rejected: 'close'
  };
  return iconMap[status] || 'question-o';
};

// 获取请假类型图标
const getTypeIcon = (type) => {
  const iconMap = {
    sick: 'hotel-o',
    personal: 'friends-o'
  };
  return iconMap[type] || 'question-o';
};

// 计算请假天数
const getDuration = (start, end) => {
  const startDate = dayjs(start);
  const endDate = dayjs(end);
  return endDate.diff(startDate, 'day') + 1;
};

// 获取各状态数量
const getStatusCount = (status) => {
  if (status === 'all') return leaveList.value.length;
  return leaveList.value.filter(item => item.status === status).length;
};

// 滤请假列表
const filteredLeaveList = computed(() => {
  if (leaveStatus.value === 'all') return leaveList.value;
  return leaveList.value.filter(item => item.status === leaveStatus.value);
});

// 导出排名
const exportRanking = () => {
  showToast('导出功能开发中...');
};

// 获取牌表情
const getMedal = (index) => {
  const medals = ['🥇', '🥈', '🥉'];
  return medals[index];
};

// 格式化时间
const formatTime = (seconds) => {
  const minutes = Math.floor(seconds / 60);
  const remainingSeconds = seconds % 60;
  return `${String(minutes).padStart(2, '0')}:${String(remainingSeconds).padStart(2, '0')}`;
};

// 组件卸载时清理计时器
onUnmounted(() => {
  if (timerInterval) {
    clearInterval(timerInterval);
  }
});

// 打开统计日期选择器
const openDatePicker = (type) => {
  statsDatePickerType.value = type;
  showStatsDatePicker.value = true;
};

// 确认统计日期选择
const onStatsDateConfirm = async (value) => {
  const formatDate = dayjs(value).format('YYYY-MM-DD');
  statsDateRange.value[statsDatePickerType.value === 'statsStart' ? 'start' : 'end'] = formatDate;
  showStatsDatePicker.value = false;
  
  // 更新统计数据
  await getStatsData();
};

// 更新统计数据
const updateStatsData = async () => {
  await getStatsData();
};

// 选择快捷时间范围
const selectTimeRange = async (range) => {
  timeRange.value = range;
  // 根据选择更新日期范围
  switch(range) {
    case '本周':
      statsDateRange.value = {
        start: dayjs().startOf('week').format('YYYY-MM-DD'),
        end: dayjs().format('YYYY-MM-DD')
      };
      break;
    case '本月':
      statsDateRange.value = {
        start: dayjs().startOf('month').format('YYYY-MM-DD'),
        end: dayjs().format('YYYY-MM-DD')
      };
      break;
  }
  // 更新统计数据
  await getStatsData();
};

// 在 script setup 中添加
const isAttending = ref(false);

// 添加获取状态颜色的方法
const getStatusColor = (status) => {
  const colorMap = {
    present: '#00c9a4',
    absent: '#ff4d4f',
    late: '#faad14',
    leave: '#1890ff'
  };
  return colorMap[status] || '#999';
};

// 添加状态码转换方法
const getStatusCode = (status) => {
  const statusMap = {
    'pending': 0,
    'approved': 1,
    'rejected': 2
  };
  return statusMap[status];
};

const getStatusValue = (code) => {
  const statusMap = {
    0: 'pending',
    1: 'approved',
    2: 'rejected'
  };
  return statusMap[code];
};

// 修改 watch 监听器，当切换到请假管理时调用接口
watch(activeTab, async (newTab) => {
  if (newTab === 'leave') {
    await getLeaveList();
  } else if (newTab === 'stats') {
    await getStatsData();
  }else{
    await getLeaveList();
  }
});

// 添加获取统计数据的方法
const getStatsData = async () => {
  try {
    const params = {
      beginDate: statsDateRange.value.start,
      endDate: statsDateRange.value.end,
      classId: activeClass.value?.id
    };
    
    const res = await teacherStatisticalAnalysis(params);
    if (res.code === 0) {
      const sum = res.data.sum;
      
      // 更新统计数据
      statsData.value = {
        attendanceRate: Number(sum.rate0) || 0, // 使用出勤率作为总考勤率
        details: [
          { 
            type: 'present', 
            label: '出勤', 
            count: Number(sum.status0Count) || 0,
            rate: Number(sum.rate0) || 0,
            color: '#00c9a4' 
          },
          { 
            type: 'late', 
            label: '迟到', 
            count: Number(sum.status2Count) || 0,
            rate: Number(sum.rate2) || 0,
            color: '#faad14' 
          },
          { 
            type: 'absent', 
            label: '缺勤', 
            count: Number(sum.status1Count) || 0,
            rate: Number(sum.rate1) || 0,
            color: '#ff4d4f' 
          },
          { 
            type: 'leave', 
            label: '请假', 
            count: Number(sum.status3Count) || 0,
            rate: Number(sum.rate3) || 0,
            color: '#1890ff' 
          }
        ]
      };
      
      // 更新排名列表
      if (res.data.studentList) {
        rankingList.value = res.data.studentList.map(item => ({
          name: item.student.realname || item.student.nickname,
          headUrl: item.student.headUrl || '/static/assets/head.jpg',
          rate: Number(item.rate0) || 0, // 使用出勤率
          attendCount: Number(item.status0Count) || 0, // 出勤次数
          totalCount: Number(item.allCount) || 0 // 总课时
        }))
        .sort((a, b) => b.rate - a.rate); // 按出勤率降序排序
      }
    } else {
      showToast(res.msg || '获取统计数据失败');
    }
  } catch (error) {
    console.error('获取统计数据失败:', error);
    showToast('获取统计数据失败');
  }
};
</script>

<style lang="scss" scoped>
.attendance {
  height: 100%;
  display: flex;
  flex-direction: column;

  :deep .van-calendar__selected-day{
	  background: #00c9a4;
  }
  :deep .van-calendar__confirm{
	  background: #00c9a4;
	  border:none;
	  .van-button__text{
		  color: #fff;
	  }
  }
  .header {
    background: #fff;
    padding: 12px 16px;
    box-shadow: 0 1px 2px rgba(0,0,0,0.05);
    z-index: 10;

    .class-select {
      display: inline-flex;
      align-items: center;
      padding: 6px 12px;
      background: #f6f7fb;
      border-radius: 4px;
      margin-bottom: 12px;
      cursor: pointer;
      transition: all 0.3s;

      text {
        margin-right: 4px;
        font-size: 14px;
      }

      &:hover {
        background: #f0f3f8;
      }
    }

    ::v-deep .van-tabs__wrap {
      height: 36px;

      .van-tabs__line {
        width: 20px;
        height: 3px;
        border-radius: 2px;
      }
    }
  }

  .content {
    flex: 1;
    padding: 16px;
    overflow-y: auto;
    &::-webkit-scrollbar {
      display: none;
    }
    scrollbar-width: none;
    -ms-overflow-style: none;

    .action-bar {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 16px;

      .date-picker {
        display: flex;
        align-items: center;
        padding: 8px 12px;
        background: #fff;
        border-radius: 4px;
        box-shadow: 0 2px 8px rgba(0,0,0,0.05);
        cursor: pointer;

        .van-icon {
          margin-right: 6px;
          color: #00c9a4;
        }

        text {
          font-size: 14px;
          color: #333;
        }
      }

      .search-box {
        flex: 1;
        margin: 0 12px;
        
        ::v-deep .van-search {
          padding: 0;
          
          .van-search__content {
            background: #fff;
            border: 1px solid #eee;
          }
        }
      }

      .buttons {
        display: flex;
        gap: 8px;  // 增加按钮间距

        .van-button {
          min-width: 80px;  // 设置最小宽度
          height: 32px;
          
          &--plain {
            border-color: #ddd;
            color: #666;
            
            &:active {
              opacity: 0.8;
            }
          }
        }
      }
    }

    .stat-cards {
      display: grid;
      grid-template-columns: repeat(4, 1fr);
      gap: 12px;
      margin-bottom: 16px;

      .stat-card {
        background: #fff;
        border-radius: 8px;
        padding: 16px;
        text-align: center;
        box-shadow: 0 2px 8px rgba(0,0,0,0.05);
        position: relative;
        overflow: hidden;

        &::after {
          content: '';
          position: absolute;
          top: 0;
          left: 0;
          right: 0;
          height: 3px;
          background: #00c9a4;
        }

        .value {
          display: block;
          font-size: 24px;
          font-weight: bold;
          color: #00c9a4;
          margin-bottom: 4px;

          &.success { color: #00c9a4; }
          &.danger { 
            color: #ff4d4f;
            & + .stat-card::after { background: #ff4d4f; }
          }
          &.warning { 
            color: #faad14;
            & + .stat-card::after { background: #faad14; }
          }
        }

        .label {
          font-size: 13px;
          color: #666;
        }
      }
    }

    .attendance-list {
      background: #fff;
      border-radius: 8px;
      padding: 16px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.05);
      overflow-y: auto;
      &::-webkit-scrollbar {
        display: none;
      }
      scrollbar-width: none;
      -ms-overflow-style: none;

      .student-item {
        display: flex;
        align-items: flex-start;
        padding: 12px 0;
        border-bottom: 1px solid #f5f5f5;

        &:last-child {
          border-bottom: none;
        }

        .student-info {
          display: flex;
          align-items: center;
          width: 200px;

          .avatar {
            margin-right: 12px;
          }

          .info {
            .name {
              display: block;
              font-size: 14px;
              font-weight: 500;
              margin-bottom: 4px;
            }

            .id {
              font-size: 12px;
              color: #999;
            }
          }
        }

        .status-group {
          flex: 1;
          display: flex;
          align-items: center;
          justify-content: flex-end;
          margin: auto;
          
          ::v-deep .van-radio-group {
            display: flex;
            gap: 16px;
            
            .van-radio {
              margin: 0;
              
              &__label {
                color: #666;
                margin-left: 4px;
              }
            }
          }
        }
      }
    }
  }

  .submit-btn {
    position: fixed;
    bottom: 20px;
    left: 16px;
    right: 16px;
    padding: 0 20px;
    z-index: 99;

    ::v-deep .van-button {
      transition: all 0.3s ease;
      
      &:active {
        transform: translateY(1px);
        box-shadow: 0 2px 8px rgba(0,201,164,0.15) !important;
      }
    }
  }

  .leave-content {
    flex: 1;
    padding: 16px;
    overflow-y: auto;
    &::-webkit-scrollbar {
      display: none;
    }
    scrollbar-width: none;
    -ms-overflow-style: none;

    .leave-header {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      margin-bottom: 20px;
      padding: 0 4px;

      .header-left {
        display: flex;
        flex-direction: column;
        gap: 16px;

        .title {
          font-size: 18px;
          font-weight: 600;
          color: #333;
        }

        .filter-tabs {
          display: flex;
          gap: 12px;
          
          .tab-item {
            padding: 6px 16px;
            border-radius: 20px;
            font-size: 14px;
            color: #666;
            background: #f5f5f5;
            cursor: pointer;
            transition: all 0.3s;
            position: relative;
            
            &.active {
              color: #00c9a4;
              background: #e6fff9;
              font-weight: 500;
            }
            
            .count {
              position: absolute;
              top: -8px;
              right: -8px;
              min-width: 16px;
              height: 16px;
              line-height: 16px;
              text-align: center;
              background: #ff4d4f;
              color: #fff;
              border-radius: 8px;
              font-size: 12px;
              padding: 0 4px;
            }
          }
        }
      }

      .right {
        .van-button {
          height: 36px;
          padding: 0 20px;
          box-shadow: 0 4px 12px rgba(0,201,164,0.15);
          font-weight: 500;
          transition: all 0.3s;

          &:hover {
            transform: translateY(-1px);
            box-shadow: 0 6px 16px rgba(0,201,164,0.2);
          }

          .van-icon {
            font-size: 16px;
          }
        }
      }
    }

    .leave-list {
      .empty {
        padding: 40px 0;
      }

      .leave-item {
        margin-bottom: 16px;
      }

      .leave-card {
        background: #fff;
        border-radius: 16px;
        overflow: hidden;
        box-shadow: 0 4px 16px rgba(0,0,0,0.06);
        transition: all 0.3s;

        &:hover {
          transform: translateY(-2px);
          box-shadow: 0 8px 24px rgba(0,0,0,0.08);
        }

        .card-header {
          padding: 20px;
          display: flex;
          justify-content: space-between;
          align-items: center;
          border-bottom: 1px solid rgba(0,0,0,0.05);
          background: linear-gradient(135deg, #fff 0%, #f8fafc 100%);

          .student-info {
            display: flex;
            align-items: center;

            .avatar {
              margin-right: 16px;
              border: 2px solid #fff;
              box-shadow: 0 4px 12px rgba(0,0,0,0.1);
            }

            .info {
              .name {
                font-size: 16px;
                font-weight: 500;
                margin-bottom: 6px;
                color: #333;
              }

              .status {
                font-size: 13px;
                padding: 4px 12px;
                border-radius: 20px;
                display: inline-flex;
                align-items: center;
                gap: 4px;

                .van-icon {
                  font-size: 14px;
                }

                &.pending {
                  color: #faad14;
                  background: #fffbe6;
                }
                &.approved {
                  color: #52c41a;
                  background: #f6ffed;
                }
                &.rejected {
                  color: #ff4d4f;
                  background: #fff2f0;
                }
              }
            }
          }

          .type-tag {
            padding: 6px 16px;
            border-radius: 20px;
            font-size: 13px;
            font-weight: 500;
            display: flex;
            align-items: center;
            gap: 4px;
            
            .van-icon {
              font-size: 16px;
            }
            
            &.sick {
              background: linear-gradient(135deg, #e6f7ff 0%, #bae7ff 100%);
              color: #0050b3;
            }
            
            &.personal {
              background: linear-gradient(135deg, #f6ffed 0%, #d9f7be 100%);
              color: #237804;
            }
          }
        }

        .card-content {
          padding: 20px;
          background: #fff;

          .time-range {
            color: #666;
            margin-bottom: 16px;
            font-size: 14px;
            display: flex;
            align-items: center;

            .van-icon {
              margin-right: 8px;
              color: #00c9a4;
              font-size: 16px;
            }

            .duration {
              margin-left: auto;
              padding: 2px 8px;
              background: #f6f7fb;
              border-radius: 10px;
              font-size: 12px;
              color: #666;
            }
          }

          .reason {
            margin-bottom: 16px;
            font-size: 14px;
            line-height: 1.6;
            color: #333;
            
            .label {
              color: #999;
              margin-right: 8px;
            }
          }

          .create-time {
            font-size: 13px;
            color: #999;
            display: flex;
            align-items: center;

            .van-icon {
              margin-right: 8px;
              font-size: 14px;
            }
          }
        }

        .card-footer {
          padding: 16px 20px;
          display: flex;
          justify-content: flex-end;
          gap: 12px;
          border-top: 1px solid rgba(0,0,0,0.05);
          background: #fff;

          .van-button {
            min-width: 88px;
            height: 36px;
            font-weight: 500;
            transition: all 0.3s;

            .van-icon {
              font-size: 16px;
              position: relative;
              top: -1px;
            }

            &:hover {
              transform: translateY(-1px);
              box-shadow: 0 4px 12px rgba(0,0,0,0.1);
            }
          }
        }
      }
    }
  }

  .stats-content {
    flex: 1;
    padding: 16px;
    overflow-y: auto;
    &::-webkit-scrollbar {
      display: none;
    }
    scrollbar-width: none;
    -ms-overflow-style: none;

    .filter-bar {
      margin-bottom: 20px;

      .filter-group {
        .quick-range {
          display: flex;
          gap: 12px;
          margin-bottom: 16px;
          padding: 0 16px;

          .van-button {
            flex: 1;
            height: 32px;
            font-size: 14px;

            &--primary {
              font-weight: 500;
            }
          }
        }

        .date-range-picker {
          display: flex;
          align-items: center;
          justify-content: space-between;
          background: #fff;
          border-radius: 8px;
          padding: 16px;
          box-shadow: 0 2px 8px rgba(0,0,0,0.05);
          
          .date-item {
            flex: 1;
            cursor: pointer;
            
            .label {
              font-size: 12px;
              color: #999;
              margin-bottom: 4px;
              display: block;
            }
            
            .value {
              display: flex;
              align-items: center;
              justify-content: space-between;
              background: #f5f7fa;
              padding: 8px 12px;
              border-radius: 6px;
              
              text {
                font-size: 14px;
                color: #333;
              }
              
              .van-icon {
                font-size: 16px;
                color: #00c9a4;
              }
            }
          }
          
          .separator {
            padding: 0 16px;
            color: #ddd;
            display: flex;
            align-items: center;
            
            .van-icon {
              font-size: 16px;
            }
          }
        }
      }
    }

    .stats-charts {
      display: grid;
      gap: 16px;
      margin-bottom: 20px;

      .chart-card {
        background: #fff;
        border-radius: 12px;
        overflow: hidden;
        box-shadow: 0 2px 12px rgba(0,0,0,0.05);

        .card-header {
          padding: 16px 20px;
          border-bottom: 1px solid #f5f5f5;
          display: flex;
          justify-content: space-between;
          align-items: center;

          .title {
            font-size: 16px;
            font-weight: 500;
            color: #333;
          }

          .rate {
            text-align: right;

            .value {
              font-size: 24px;
              font-weight: bold;
              color: #00c9a4;
            }

            .label {
              font-size: 12px;
              color: #999;
              margin-left: 8px;
            }
          }

          .legend {
            display: flex;
            gap: 16px;

            .legend-item {
              display: flex;
              align-items: center;
              gap: 4px;
              font-size: 12px;
              color: #666;

              .dot {
                width: 8px;
                height: 8px;
                border-radius: 50%;
              }
            }
          }
        }

        .card-content {
          padding: 20px;

          .stat-item {
            display: flex;
            align-items: center;
            gap: 12px;
            margin-bottom: 16px;

            &:last-child {
              margin-bottom: 0;
            }

            .info {
              width: 100px;
              
              .label {
                font-size: 14px;
                color: #666;
              }

              .count {
                display: block;
                font-size: 12px;
                color: #999;
                margin-top: 2px;
              }
            }

            .progress-bar {
              flex: 1;
              height: 8px;
              background: #f5f5f5;
              border-radius: 4px;
              overflow: hidden;

              .progress {
                height: 100%;
                border-radius: 4px;
                transition: width 0.3s ease;
              }
            }

            .rate {
              width: 50px;
              text-align: right;
              font-size: 14px;
              color: #666;
            }
          }

          .trend-chart {
            height: 300px;

            .chart-placeholder {
              height: 100%;
              display: flex;
              align-items: center;
              justify-content: center;
              background: #f9f9f9;
              border-radius: 8px;
              color: #999;
            }
          }
        }
      }
    }

    .ranking-list {
      background: #fff;
      border-radius: 12px;
      overflow: hidden;
      box-shadow: 0 2px 12px rgba(0,0,0,0.05);

      .ranking-header {
        padding: 16px 20px;
        border-bottom: 1px solid #f5f5f5;
        display: flex;
        justify-content: space-between;
        align-items: center;

        .title {
          font-size: 16px;
          font-weight: 500;
          color: #333;
        }
      }

      .ranking-table {
        .table-header {
          display: grid;
          grid-template-columns: 80px 200px 1fr 120px;
          padding: 12px 20px;
          background: #f9f9f9;
          font-size: 14px;
          color: #666;
        }

        .table-row {
          display: grid;
          grid-template-columns: 80px 200px 1fr 120px;
          padding: 16px 20px;
          align-items: center;
          border-bottom: 1px solid #f5f5f5;
          transition: all 0.3s;

          &:hover {
            background: #f9f9f9;
          }

          &.top3 {
            background: #fff9f0;

            &:hover {
              background: #fff5e6;
            }

            .rank {
              color: #faad14;
            }
          }

          .rank {
            font-size: 16px;
            font-weight: 500;
            color: #999;

            .medal {
              font-size: 20px;
            }
          }

          .student-info {
            display: flex;
            align-items: center;
            gap: 12px;

            .avatar {
              width: 32px;
              height: 32px;
            }
          }

          .rate {
            display: flex;
            align-items: center;
            gap: 12px;

            .progress-bar {
              flex: 1;
              height: 6px;
              background: #f5f5f5;
              border-radius: 3px;
              overflow: hidden;

              .progress {
                height: 100%;
                background: #00c9a4;
                border-radius: 3px;
              }
            }

            text {
              font-size: 14px;
              color: #666;
            }
          }

          .count {
            font-size: 14px;
            color: #666;
            text-align: center;
          }
        }
      }
    }
  }
}

.no-course {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 100%;
  padding: 40px;
  
  ::v-deep .van-empty__description {
    white-space: pre-line;
    color: #666;
  }
}

.empty-attendance {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 40px;
  background: #fff;
  border-radius: 8px;
  margin-top: 16px;
  
  ::v-deep .van-empty {
    padding: 0;
  }
  
  .van-button {
    margin-top: 16px;
  }
}
</style> 