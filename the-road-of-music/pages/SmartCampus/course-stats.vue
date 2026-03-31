<template>
  <view class="course-stats">
    <van-loading v-if="loading" type="spinner" vertical>加载中...</van-loading>
    <template v-else>
      <!-- 身份切换 -->
      <view class="role-switch">
        <text>{{isHeadTeacher ? '班主任视图' : '任课老师视图'}}</text>
        <van-switch
          v-model="isHeadTeacher"
          size="24px"
          active-color="#00c9a4"
          inactive-color="#969799"
        />
      </view>

      <!-- 班主任视图 -->
      <template v-if="isHeadTeacher">
        <view class="header">
          <view class="class-select" v-if="classAll?.length > 1" @click="showPicker = !showPicker">
            <text>{{activeClass.name}}</text>
            <van-icon :name="showPicker ? 'arrow-up' : 'arrow-down'" />
          </view>
          <view class="date-range">
            <van-button 
              round 
              size="small" 
              :type="timeRange === range ? 'primary' : 'default'"
              :color="timeRange === range ? '#00c9a4' : ''"
              v-for="range in timeRanges" 
              :key="range"
              @click="timeRange = range"
            >{{range}}</van-button>
          </view>
        </view>
          <!-- 日期筛选 -->
        <view class="date-filter">
          <view class="date-range-picker">
            <view class="date-item" @click="showStartCalendar = true">
              <text class="label">开始日期</text>
              <view class="value">
                <text>{{dateRange.start}}</text>
                <van-icon name="calendar-o" />
              </view>
            </view>
            <view class="separator">
              <van-icon name="arrow" />
            </view>
            <view class="date-item" @click="showEndCalendar = true">
              <text class="label">结束日期</text>
              <view class="value">
                <text>{{dateRange.end}}</text>
                <van-icon name="calendar-o" />
              </view>
            </view>
          </view>
        </view>

        <!-- 日历选择器 -->
        <van-calendar
          v-model:show="showStartCalendar"
          :min-date="minDate"
          :max-date="maxDate"
          @confirm="onStartDateConfirm"
          color="#00c9a4"
          title="选择开始日期"
          :show-confirm="true"
          :round="true"
          position="bottom"
        />

        <van-calendar
          v-model:show="showEndCalendar"
          :min-date="minDate"
          :max-date="maxDate"
          @confirm="onEndDateConfirm"
          color="#00c9a4"
          title="选择结束日期"
          :show-confirm="true"
          :round="true"
          position="bottom"
        />

        <!-- 统计卡片 -->
        <view class="stat-cards">
          <view class="stat-card">
            <view class="value">{{stats.totalHours}}</view>
            <view class="label">总课时</view>
          </view>
          <view class="stat-card">
            <view class="value">{{stats.completedHours}}</view>
            <view class="label">已完成成课时</view>
          </view>
          <view class="stat-card">
            <view class="value">{{stats.remainingHours}}</view>
            <view class="label">剩余课时</view>
          </view>
          <view class="stat-card">
            <view class="value">{{stats.completionRate}}%</view>
            <view class="label">完成率</view>
          </view>
        </view>

        <!-- 签课审批模块 -->
        <view class="sign-approval-section">
          <view class="section-title">
            <text>签课审批</text>
            <view class="more" @click="viewAllApprovals">
              <text>查看全部</text>
              <van-icon name="arrow" />
            </view>
          </view>
          
          <view class="approval-list">
            <template v-if="pendingApprovals.length > 0">
              <view 
                class="approval-item" 
                v-for="item in pendingApprovals" 
                :key="item.id"
              >
                <view class="teacher-info">
                  <van-image
                    class="avatar"
                    round
                    width="40"
                    height="40"
                    :src="item.teacherAvatar"
                  />
                  <view class="info">
                    <text class="name">{{item.teacherName}}</text>
                    <text class="subject">{{item.subject}}</text>
                  </view>
                </view>
                
                <view class="sign-info">
                  <view class="course-detail">
                    <text class="time">{{item.signTime}}</text>
                    <text class="hours">{{item.hours}}课时</text>
                  </view>
                  <view class="content">
                    <text class="label">课程内容：</text>
                    <text class="text">{{item.content}}</text>
                  </view>
                </view>
                
                <view class="actions">
                  <van-button 
                    size="small" 
                    type="primary" 
                    color="#00c9a4"
                    @click="handleApproval(item.id, 'approve')"
                  >通过</van-button>
                  <van-button 
                    size="small" 
                    @click="showRejectDialog(item)"
                  >驳回</van-button>
                </view>
              </view>
            </template>
            <van-empty v-else description="暂无待审批的签课申请" image="/static/assets/empty_list.png" :image-size="[160, 160]"/>
          </view>
        </view>

        <!-- 课程类型统计等内容 -->
        <view class="course-types">
          <view class="section-title">
            <text>课程类型统计</text> 
          </view>
          <view class="type-list">
            <view 
              class="type-item" 
              v-for="item in courseTypes" 
              :key="item.type"
            >
              <view class="info">
                <view class="name">{{item.name}}</view>
                <view class="count">{{item.completedHours}}/{{item.totalHours}}课时</view>
              </view>
              <view class="progress-bar">
                <view 
                  class="progress" 
                  :style="{
                    width: (item.completedHours / item.totalHours * 100) + '%'
                  }"
                  :data-progress="Math.round(item.completedHours / item.totalHours * 100)"
                ></view>
              </view>
            </view>
          </view>
        </view>

        <!-- 教师课时统计 -->
        <view class="teacher-stats">
          <view class="section-title">
            <text>教师课时统计</text>
          </view>
          <view class="teacher-list">
            <view 
              class="teacher-item"
              v-for="teacher in teacherStatsList"
              :key="teacher.id"
            >
              <view class="teacher-info">
                <van-image
                  class="avatar"
                  round
                  width="40"
                  height="40"
                  :src="teacher.headUrl"
                />
                <view class="info">
                  <text class="name">{{teacher.name}}</text>
                  <text class="subject">{{teacher.subject}}</text>
                </view>
              </view>
              <view class="stats-info">
                <view class="stat-box">
                  <text class="value">{{teacher.totalHours}}</text>
                  <text class="label">总课时</text>
                </view>
                <view class="stat-box">
                  <text class="value">{{teacher.completedHours}}</text>
                  <text class="label">已完成</text>
                </view>
                <view class="stat-box">
                  <text class="value">{{teacher.remainingHours}}</text>
                  <text class="label">剩余</text>
                </view>
              </view>
            </view>
          </view>
        </view>
      </template>

      <!-- 任课老师视图 -->
      <template v-else>
        <!-- 签课管理模块移最上方 -->
        <view class="sign-course-section">
          <view class="section-title">
            <text>签课管理</text>
            <view class="more" @click="viewAllSignRecords">
              <text>查看全部</text>
              <van-icon name="arrow" />
            </view>
          </view>
          
          <!-- 最近签课记录 - 只显示3条 -->
          <view class="recent-signs">
            <template v-if="recentSigns.length > 0">
              <view class="sign-item" v-for="item in recentSigns.slice(0, 3)" :key="item.id">
                <view class="status-tag" :class="item.status">{{item.statusText}}</view>
                <view class="sign-content">
                  <view class="title">
                    <text class="class-name">{{item.className}}</text>
                    <text class="subject">{{item.subject}}</text>
                  </view>
                  <view class="details">
                    <text class="time">{{item.signTime}}</text>
                    <text class="hours">{{item.hours}}课时</text>
                    <text class="description">课程内容：{{item.description || '无'}}</text>
                    <text v-if="item.status === 'rejected'" class="reject-reason">
                      驳回原因：{{item.rejectReason || '无'}}
                    </text>
                  </view>
                </view>
              </view>
            </template>
            <van-empty v-else description="暂无数据哦!" image="/static/assets/empty_list.png" :image-size="[160, 160]"/>
          </view>

          <!-- 快捷签课按钮 -->
          <view class="quick-sign" @click="openSignPopup">
            <van-icon name="plus" />
            <text>发起签课</text>
          </view>
        </view>

        <!-- 其他统计 -->
        <!-- <view class="header">
          <view class="date-range">
            <van-button 
              round 
              size="small" 
              :type="timeRange === range ? 'primary' : 'default'"
              :color="timeRange === range ? '#00c9a4' : ''"
              v-for="range in timeRanges" 
              :key="range"
              @click="timeRange = range"
            >{{range}}</van-button>
          </view>
        </view> -->

        <!-- 统计卡片 -->
        <view class="stat-cards">
          <view class="stat-card">
            <view class="value">{{teacherStats.totalClasses}}</view>
            <view class="label">任课班级</view>
          </view>
          <view class="stat-card">
            <view class="value">{{teacherStats.totalHours}}</view>
            <view class="label">总课时</view>
          </view>
          <view class="stat-card">
            <view class="value">{{teacherStats.completedHours}}</view>
            <view class="label">已完成</view>
          </view>
          <view class="stat-card">
            <view class="value">{{teacherStats.completionRate}}%</view>
            <view class="label">完成率</view>
          </view>
        </view>

        <!-- 修改班级课时统计，移除签课按钮 -->
        <view class="class-stats">
          <view class="section-title">
            <text>班级课时统计</text>
          </view>
          <view class="class-list">
            <view 
              class="class-item" 
              v-for="item in teacherClassStats" 
              :key="item.id"
            >
              <view class="class-info">
                <text class="name">{{item.className}}</text>
                <text class="subject">{{item.subject}}</text>
              </view>
              <view class="progress-info">
                <view class="progress-bar">
                  <view 
                    class="progress" 
                    :style="{
                      width: item.completionRate + '%',
                      background: '#00c9a4'
                    }"
                  ></view>
                </view>
                <view class="hours">
                  <text class="completed">{{item.completedHours}}</text>
                  <text class="separator">/</text>
                  <text class="total">{{item.totalHours}}课时</text>
                  <text class="rate">({{item.completionRate}}%)</text>
                </view>
              </view>
            </view>
          </view>
        </view>
      </template>

      <!-- 班级选择器 -->
      <van-popup v-model:show="showPicker" round position="bottom">
        <van-picker
          :columns="columns"
          @cancel="showPicker = false"
          @confirm="onSelectClass"
          show-toolbar
          title="选择班级"
        />
      </van-popup>

      <!-- 日期选择器 -->
      <van-popup 
        v-model:show="showDatePicker" 
        round 
        position="bottom"
        :style="{ height: '40%' }"
      >
        <view class="date-picker-header">
          <text>选择{{datePickerType === 'start' ? '开始' : '结束'}}日期</text>
          <van-icon name="cross" @click="showDatePicker = false" />
        </view>
        <van-datetime-picker
          type="date"
          :min-date="minDate"
          :max-date="maxDate"
          :value="currentDate"
          @confirm="onDateConfirm"
          @cancel="showDatePicker = false"
          :formatter="dateFormatter"
          :filter="dateFilter"
        />
      </van-popup>

      <!-- 修改签课弹窗部分 -->
      <van-popup
        v-model:show="showSignPopup"
        position="right"
        :style="{ width: '40%', height: '100%' }"
        closeable
        @close="closeSignPopup"
      >
        <view class="sign-form">
          <view class="form-header">
            <text class="title">发起签课申请</text>
          </view>

          <!-- 替换scroll-view为普通view -->
          <view class="form-content">
            <view class="form-body">
              <!-- 课程选择区域 -->
              <view class="form-group">
                <view class="form-item">
                  <text class="label required">选择课程</text>
                  <select 
                    class="course-select"
                    v-model="selectedCourseId"
                    @change="handleCourseChange"
                  >
                    <option value="">请选择课程</option>
                    <option 
                      v-for="course in todayCourses" 
                      :key="course.id"
                      :value="course.id"
                    >
                      {{course.courseStartTime ? course.courseStartTime.split(' ')[1] : ''}} {{course.className || ''}} - {{course.subjectName || ''}}
                    </option>
                  </select>
                </view>
              </view>

              <!-- 课程信息展示 -->
              <view class="form-group info-group" v-if="currentCourse">
                <view class="info-item">
                  <text class="info-label">课程名称</text>
                  <text class="info-value">{{ currentCourse.name }}</text>
                </view>
                <view class="info-item">
                  <text class="info-label">上课时间</text>
                  <text class="info-value">{{ currentCourse.time }}</text>
                </view>
              </view>

              <!-- 签课详情区域 -->
              <view class="form-group">
                <view class="form-item">
                  <text class="label required">课时数</text>
                  <view class="hours-wrapper">
                    <van-stepper
                      v-model="signForm.hours"
                      :min="1"
                      :max="8" 
                      :step="1"
                      input-width="80px"
                      button-size="28px"
                    />
                    <text class="unit">课时</text>
                  </view>
                  <text class="tip">每课时45分钟，单次最多可签8课时</text>
                </view>

                <view class="form-item">
                  <text class="label required">课程内容</text>
                  <textarea 
                    class="content-input"
                    v-model="signForm.content"
                    placeholder="请输入本节课程内容"
                    :maxlength="200"
                  />
                  <text class="word-count">{{ signForm.content?.length || 0 }}/200</text>
                </view>
              </view>

              <!-- 签课说明区域 -->
              <view class="notice-box">
                <view class="notice-header">
                  <van-icon name="info-o" />
                  <text>签课说明</text>
                </view>
                <view class="notice-items">
                  <view class="notice-item">
                    <view class="dot"></view>
                    <text>请在课程结束后及时发起签课申请</text>
                  </view>
                  <view class="notice-item">
                    <view class="dot"></view>
                    <text>每节课程仅可发起一次签课申请</text>
                  </view>
                  <view class="notice-item">
                    <view class="dot"></view>
                    <text>签课申请提交后需等待班主任审批</text>
                  </view>
                </view>
              </view>
            </view>
          </view>

          <view class="form-footer">
            <button 
              class="submit-button" 
              :class="{ loading: submitting }" 
              @click="handleSign"
              :disabled="submitting || !selectedCourseId"
            >
              <van-loading v-if="submitting" size="20px" color="#fff" />
              <text>{{ submitting ? '提交中...' : '提交申请' }}</text>
            </button>
          </view>
        </view>
      </van-popup>

      <!-- 驳回原因弹窗 -->
      <van-dialog
        v-model:show="showRejectReason"
        title="驳回原因"
        show-cancel-button
        @confirm="handleReject"
      >
        <view class="reject-dialog-content">
          <textarea
            v-model="rejectReason"
            placeholder="请输入驳回原因"
            class="reject-reason-input"
          />
        </view>
      </van-dialog>
    </template>
  </view>
</template>

<script setup>
import { ref, onMounted, watch } from 'vue';
import { showToast } from 'vant';
import { classList } from '/api/home.js';
import dayjs from 'dayjs';
import { useRouter } from 'vue-router';
import { 
  getMyInfo,
  teacherSignInList,
  teacherSignInSave,
  teacherSignInStatisticalAnalysis,
  teacherSignInUpdate,
  headTeacherSignInAudit,
  headTeacherSignInList,
  courseList,
  headTeacherCourseStatistics
} from '/api/home.js';
import { defineEmits } from 'vue';

const emit = defineEmits(['change-component']);
const router = useRouter();

// 添加用户信息状态
const myInfo = ref(null);

// 初始化获取用户信息
onMounted(async () => {
  loading.value = true;
  try {
    const cachedInfo = uni.getStorageSync('my');
    if (cachedInfo) {
      myInfo.value = JSON.parse(cachedInfo);
    }
    
    const res = await getMyInfo();
    if (res.code === 0) {
      myInfo.value = res.data.user;
      uni.setStorageSync('my', JSON.stringify(res.data.user));
      
      // 初始化班级列表
      await initClassList();
      
      // 设置默认时间范围为本月
      dateRange.value = {
        start: dayjs().startOf('month').format('YYYY-MM-DD'),
        end: dayjs().endOf('month').format('YYYY-MM-DD')
      };
    }
  } catch (error) {
    console.error('获取用户信息失败:', error);
    showToast('获取用户信息失败');
  } finally {
    loading.value = false;
  }
});

// 判断是否是班主任
const isHeadTeacher = ref(false);

// 监听身份切换
watch(isHeadTeacher, async (newValue) => {
  if (newValue) {
    // 切换到班主任视图时，获取审批列表和统计数据
    await Promise.all([
      getApprovalList(),
      getHeadTeacherStats()
    ]);
  }
});

// 班级相关
const showPicker = ref(false);
const columns = ref([]);
const classAll = ref([]);
const activeClass = ref({});

// 时间范围
const timeRange = ref('本月');
const timeRanges = ['本周', '本月'];

// 监听时间范围变化
watch(timeRange, (newRange) => {
  switch (newRange) {
    case '本周':
      dateRange.value = {
        start: dayjs().startOf('week').format('YYYY-MM-DD'),
        end: dayjs().endOf('week').format('YYYY-MM-DD')
      };
      break;
    case '本月':
      dateRange.value = {
        start: dayjs().startOf('month').format('YYYY-MM-DD'),
        end: dayjs().endOf('month').format('YYYY-MM-DD')
      };
      break;
  }
  // 更新统计数据
  updateStats();
});

// 日期筛选相关
const showStartCalendar = ref(false);
const showEndCalendar = ref(false);
const minDate = ref(new Date(2020, 0, 1));
const maxDate = ref(new Date(2025, 11, 31));
const dateRange = ref({
  start: dayjs().startOf('month').format('YYYY-MM-DD'),
  end: dayjs().format('YYYY-MM-DD')
});

// 统计数据
const stats = ref({
  totalHours: 0,
  completedHours: 0,
  remainingHours: 0,
  completionRate: 0
});

// 课程类型统计
const courseTypes = ref([
  { 
    type: 'theory',
    name: '乐理课',
    totalHours: 400,
    completedHours: 320,
    color: '#00c9a4'
  },
  { 
    type: 'vocal',
    name: '声乐课',
    totalHours: 400,
    completedHours: 280,
    color: '#00c9a4'
  },
  { 
    type: 'instrument',
    name: '器乐课',
    totalHours: 400,
    completedHours: 260,
    color: '#00c9a4'
  },
  { 
    type: 'composition',
    name: '作曲课',
    totalHours: 200,
    completedHours: 140,
    color: '#00c9a4'
  },
  { 
    type: 'ensemble',
    name: '合奏课',
    totalHours: 200,
    completedHours: 160,
    color: '#00c9a4'
  }
]);

// 教师课时统计
const teacherStatsList = ref([
  {
    id: 1,
    name: '张老师',
    subject: '乐理课',
    headUrl: '/static/assets/head.jpg',
    totalHours: 400,
    completedHours: 320,
    remainingHours: 80
  },
  {
    id: 2,
    name: '李老师',
    subject: '声乐课',
    headUrl: '/static/assets/head.jpg',
    totalHours: 400,
    completedHours: 280,
    remainingHours: 120
  },
  {
    id: 3,
    name: '王老师',
    subject: '器乐课',
    headUrl: '/static/assets/head.jpg',
    totalHours: 400,
    completedHours: 260,
    remainingHours: 140
  },
  {
    id: 4,
    name: '赵老师',
    subject: '作曲课',
    headUrl: '/static/assets/head.jpg',
    totalHours: 200,
    completedHours: 140,
    remainingHours: 60
  },
  {
    id: 5,
    name: '合奏课老师',
    subject: '合奏课',
    headUrl: '/static/assets/head.jpg',
    totalHours: 200,
    completedHours: 160,
    remainingHours: 40
  }
]);

// 任课老师统计数据
const teacherStats = ref({
  totalClasses: 5,
  totalHours: 600,
  completedHours: 400,
  completionRate: 67
});

// 任课老师班级统计
const teacherClassStats = ref([
  {
    id: 1,
    className: '音乐一班',
    subject: '乐理课',
    totalHours: 120,
    completedHours: 80
  },
  {
    id: 2,
    className: '音乐二班',
    subject: '乐理课',
    totalHours: 120,
    completedHours: 90
  },
  {
    id: 3,
    className: '音乐三班',
    subject: '声乐课',
    totalHours: 120,
    completedHours: 70
  },
  {
    id: 4,
    className: '音乐四班',
    subject: '器乐课',
    totalHours: 120,
    completedHours: 85
  },
  {
    id: 5,
    className: '音乐五班',
    subject: '乐理课',
    totalHours: 120,
    completedHours: 75
  }
]);

// 签课审批列表
const pendingApprovals = ref([]);
const approvalPagination = ref({
  current: 1,
  size: 10,
  total: 0
});

// 获取签课审批列表
const getApprovalList = async () => {
  try {
    const params = {
      beginDate: dateRange.value.start,
      endDate: dateRange.value.end,
      classId: activeClass.value?.id,
      current: approvalPagination.value.current,
      size: approvalPagination.value.size,
      status: 0 // 0表示待审批
    };

    const res = await headTeacherSignInList(params);
    if (res.code === 0) {
      // 更新统计数据
      if (res.data.sum) {
        stats.value = {
          totalHours: Number(res.data.sum.allLessonCount) || 0,
          completedHours: Number(res.data.sum.sumLessonCount) || 0,
          remainingHours: Number(res.data.sum.remainingLessonCount) || 0,
          completionRate: Number(res.data.sum.completionRate) || 0
        };
      }

      // 转换审批列表数据格式
      pendingApprovals.value = (res.data.list || []).map(item => ({
        id: item.id,
        teacherName: item.teacher?.realname || item.teacher?.nickname || '未知教师',
        teacherAvatar: item.teacher?.headUrl || '/static/assets/head.jpg',
        subject: item.subject?.name || '未知科目',
        signTime: item.courseTime || item.createTime,
        hours: item.lessonCount || 0,
        content: item.description || '',
        className: item.schoolClass?.name || '未知班级'
      }));

      // 更新分页信息
      approvalPagination.value = {
        current: res.data.current || 1,
        size: res.data.size || 10,
        total: res.data.total || 0
      };
    } else {
      showToast(res.msg || '获取审批列表失败');
    }
  } catch (error) {
    console.error('获取审批列表失败:', error);
    showToast('获取审批列表失败');
  }
};

// 处理审批
const handleApproval = async (id, action) => {
  try {
    const params = {
      id: id,
      status: action === 'approve' ? 1 : 2, // 1表示通过，2表示驳回
      reason: action === 'reject' ? rejectReason.value : undefined // 只有驳回时才需要原因
    };
    
    const res = await headTeacherSignInAudit(params);
    if (res.code === 0) {
      showToast(`${action === 'approve' ? '通过' : '驳回'}成功`);
      // 刷新审批列表
      getApprovalList();
      // 如果是驳回，关闭驳回原因弹窗
      if (action === 'reject') {
        showRejectReason.value = false;
        rejectReason.value = ''; // 清空驳回原因
      }
    } else {
      showToast(res.msg || `${action === 'approve' ? '通过' : '驳回'}失败`);
    }
  } catch (error) {
    console.error('审批操作失败:', error);
    showToast('审批操作失败，请重试');
  }
};

// 处理驳回
const handleReject = async () => {
  if (!rejectReason.value?.trim()) {
    showToast('请输入驳回原因');
    return;
  }
  
  if (!currentApproval.value?.id) {
    showToast('审批数据异常，请刷新后重试');
    return;
  }
  
  await handleApproval(currentApproval.value.id, 'reject');
};

// 在 watch 中添加对时间范围和班级变化的监听
watch([dateRange, () => activeClass.value?.id], () => {
  if (isHeadTeacher.value) {
    getApprovalList();
    getHeadTeacherStats(); // 添加获取班主任统计数据
  }
}, { deep: true });

// 在 onMounted 中添加初始化获取
onMounted(async () => {
  // ... 其他初始化代码 ...
  
  // 如果是班主任，获取审批列表和统计数据
  if (isHeadTeacher.value) {
    await Promise.all([
      getApprovalList(),
      getHeadTeacherStats()
    ]);
  }
});

// 回相关
const showRejectReason = ref(false);
const rejectReason = ref('');
const currentApproval = ref(null);

// 显示驳回对话框
const showRejectDialog = (item) => {
  currentApproval.value = item;
  rejectReason.value = '';
  showRejectReason.value = true;
};

// 查看全部审批记录
const viewAllApprovals = () => {
  if (!myInfo.value) {
    showToast('获取用户信息失败，请重试');
    return;
  }

  // 发送事件通知父组件切换到课审批组
  emit('change-component', {
    name: 'sign-approvals',
    params: {
      classId: activeClass.value?.id,
      timeRange: timeRange.value,
      dateRange: dateRange.value
    }
  });
};

// 初始化数据
onMounted(() => {
  // 默认设置为任课老师视图
  isHeadTeacher.value = false;
  initClassList();
});

// 获取班级列表
const initClassList = async () => {
  try {
    const res = await classList();
    if (res.code === 0 && res.data.length > 0) {
      classAll.value = res.data;
      const defaultClass = uni.getStorageSync('defaultClass');
      if (defaultClass) {
        activeClass.value = JSON.parse(defaultClass);
      } else {
        activeClass.value = res.data[0];
        uni.setStorageSync('defaultClass', JSON.stringify(res.data[0]));
      }
      
      columns.value = res.data.map(item => ({
        text: item.name,
        value: item.id
      }));
    } else {
      showToast('暂无班级数据');
    }
  } catch (error) {
    console.error('获取班级列表失败:', error);
    showToast('获取班级列表失败');
  }
};

// 选择班级
const onSelectClass = (value) => {
  activeClass.value = classAll.value[value.selectedIndexes[0]];
  uni.setStorageSync('defaultClass', JSON.stringify(activeClass.value));
  showPicker.value = false;
  // TODO: 新获取统计数据
};

// 导出统计
const exportStats = () => {
  showToast('导出功能开发中...');
};

// 处理开始日期选择
const onStartDateConfirm = (date) => {
  const selectedDate = dayjs(date).format('YYYY-MM-DD');
  // 确保开始日期不大于结束日期
  if (dayjs(selectedDate).isAfter(dateRange.value.end)) {
    showToast('开始日期不能大于结束日期');
    return;
  }
  dateRange.value.start = selectedDate;
  showStartCalendar.value = false;
  // 更新统计数据
  updateStats();
};

// 处理结束日期选择
const onEndDateConfirm = (date) => {
  const selectedDate = dayjs(date).format('YYYY-MM-DD');
  // 确保结束日期不小于开始日期
  if (dayjs(selectedDate).isBefore(dateRange.value.start)) {
    showToast('结束日期不能小于开始日期');
    return;
  }
  dateRange.value.end = selectedDate;
  showEndCalendar.value = false;
  // 更新统计数据
  updateStats();
};

// 更新统计数据
const updateStats = async () => {
  await Promise.all([
    getTeacherSignInList(),
    getTeacherSignInStats()
  ]);
};

// 期格式化
const dateFormatter = (type, val) => {
  if (type === 'year') {
    return `${val}年`;
  }
  if (type === 'month') {
    return `${val}月`;
  }
  if (type === 'day') {
    return `${val}日`;
  }
  return val;
};

// 日期过滤
const dateFilter = (type, options) => {
  if (type === 'month') {
    return options.filter(option => option % 2 === 0);
  }
  return options;
};

// 打开签课弹窗
const showSignPopup = ref(false);
const currentClass = ref(null);
const signForm = ref({
  courseName: '',
  courseTime: '',
  hours: '',
  content: '',
});

// 判断是否可签课
const canSign = (item) => {
  const now = new Date();
  const hour = now.getHours();
  
  // 断是否在允许签课时间段内例如：8:00-22:00）
  if (hour < 8 || hour >= 22) {
    return false;
  }
  
  // 判断是否有未处理的签课申请
  if (hasPendingSign(item)) {
    return false;
  }
  
  return item.completedHours < item.totalHours;
};

// 判断是否有待处理的签课申请
const hasPendingSign = (item) => {
  // TODO: 根据实际业务逻辑判断是否有待理的签课申请
  return item.pendingSign;
};

// 获签课按钮文本
const getSignBtnText = (item) => {
  if (hasPendingSign(item)) {
    return '审批中';
  }
  if (!canSign(item)) {
    const now = new Date();
    const hour = now.getHours();
    if (hour < 8 || hour >= 22) {
      return '非签课时段';
    }
    return '已完成';
  }
  return '签课';
};

// 关闭签课弹窗时重置表单
const closeSignPopup = () => {
  signForm.value = {
    hours: 1,
    content: '',
  };
  selectedCourseId.value = '';
  currentCourse.value = null;
  showSignPopup.value = false;
};

// 时间格式化
const timeFormatter = (type, val) => {
  if (type === 'year') {
    return `${val}年`;
  }
  if (type === 'month') {
    return `${val}月`;
  }
  if (type === 'day') {
    return `${val}日`;
  }
  if (type === 'hour') {
    return `${val}时`;
  }
  if (type === 'minute') {
    return `${val}分`;
  }
  return val;
};

// 添加提交状态
const submitting = ref(false);

// 优化处理签课方法
const handleSign = async () => {
  // 表单验证
  if (!selectedCourseId.value) {
    showToast('请选择要签到的课程');
    return;
  }
  
  if (!signForm.value.hours) {
    showToast('请输入课时数');
    return;
  }
  
  if (!signForm.value.content?.trim()) {
    showToast('请输入课程内容');
    return;
  }

  const hours = Number(signForm.value.hours);
  if (isNaN(hours) || hours < 1 || hours > 8) {
    showToast('请输入有效的课时数(1-8)');
    return;
  }

  try {
    submitting.value = true;
    
    // 获取当前选中的课程
    const currentCourse = todayCourses.value.find(course => course.id === selectedCourseId.value);
    if (!currentCourse) {
      showToast('请选择要签到的课程');
      return;
    }

    // 调用签课 API
    const res = await teacherSignInSave({
      courseId: currentCourse.id,
      description: signForm.value.content,
      lessonCount: hours
    });

    if (res.code === 0) {
      showToast('签课申请已提交');
      closeSignPopup();
      
      // 刷新签课列表和统计数据
      await updateStats();
    } else {
      showToast(res.msg || '提交失败');
    }
  } catch (error) {
    console.error('提交签课申请失败:', error);
    showToast('提交失败，请重试');
  } finally {
    submitting.value = false;
  }
};

const recentSigns = ref([
  {
    id: 1,
    className: '音乐一班',
    subject: '乐理课',
    signTime: '2024-03-18 10:00',
    hours: 2,
    status: 'pending',
    statusText: '待审批'
  },
  {
    id: 2,
    className: '音乐二班',
    subject: '声乐课',
    signTime: '2024-03-18 09:00',
    hours: 1,
    status: 'approved',
    statusText: '已通过'
  },
  {
    id: 3,
    className: '音乐三班',
    subject: '器乐课',
    signTime: '2024-03-17 14:00',
    hours: 2,
    status: 'rejected',
    statusText: '已驳回',
    rejectReason: '课程内容描述不够详细，请补充具体教学内容'
  }
]);

// 修改查看全部签课记录的方法
const viewAllSignRecords = () => {
  if (!myInfo.value) {
    showToast('获取用户信息失败，请重试');
    return;
  }

  // 发送事件通知父组件切换到签课记录组件
  emit('change-component', {
    name: 'sign-records',
    params: {
      teacherId: myInfo.value.id,
      timeRange: timeRange.value,
      dateRange: dateRange.value
    }
  });
};

// 添加课程选择相关的数据
const todayCourses = ref([]);
const selectedCourseId = ref('');

// 打开签课弹窗
const openSignPopup = async () => {
  const today = dayjs().format('YYYY-MM-DD');
  
  try {
    // 显示加载状态
    loading.value = true;
    
    // 获取课表数据
    const params = {
      beginDate: today,
      endDate: today,
      teacherId: myInfo.value?.id
    };
    
    // 如果是班主任，添加班级ID
    if (activeClass.value?.id) {
      params.classId = activeClass.value.id;
    }
    
    const res = await courseList(params);
    if (res.code === 0) {
      // 获取今天的课程列表
      const todayCourseList = res.data[today] || [];
      todayCourses.value = todayCourseList;
      
      if (todayCourseList.length === 0) {
        showToast('今日没有课程安排');
        return;
      }
      
      // 重置表单数据
      signForm.value = {
        hours: 1,
        content: '',
      };
      
      // 默认选择第一节课
      selectedCourseId.value = todayCourseList[0].id;
      
      // 设置当前课程信息
      currentCourse.value = {
        name: `${todayCourseList[0].className} - ${todayCourseList[0].subjectName}`,
        time: todayCourseList[0].courseStartTime
      };
      
      // 显示弹窗
      showSignPopup.value = true;
    } else {
      showToast(res.msg || '获取课表失败');
    }
  } catch (error) {
    console.error('获取课表失败:', error);
    showToast('获取课表失败，请重试');
  } finally {
    // 无论成功失败都关闭加载状态
    loading.value = false;
  }
};

// 处理课程选择变化
const handleCourseChange = (event) => {
  const courseId = event.target.value;
  if (!courseId) {
    currentCourse.value = null;
    return;
  }
  
  const selectedCourse = todayCourses.value.find(course => course.id === courseId);
  
  if (selectedCourse) {
    // 更新当前选中的课程信息
    currentCourse.value = {
      name: `${selectedCourse.className} - ${selectedCourse.subjectName}`,
      time: selectedCourse.courseStartTime
    };
  } else {
    // 清空当前课程信息
    currentCourse.value = null;
  }
};

const loading = ref(false);

// 获取签课列表
const getTeacherSignInList = async () => {
  try {
    const params = {
      beginDate: dateRange.value.start,
      endDate: dateRange.value.end,
      classId: activeClass.value?.id,
      current: 1,
      size: 10,
      status: 0
    };
    const res = await teacherSignInList(params);
    if (res.code === 0 && res.data) {
      // 更新签课记录列表
      recentSigns.value = res.data.map(item => ({
        id: item.id,
        className: item.schoolClass.name,
        subject: item.subject.name,
        signTime: item.courseTime,
        hours: item.lessonCount,
        description: item.description,
        status: item.status === 0 ? 'pending' : item.status === 1 ? 'approved' : 'rejected',
        statusText: item.status === 0 ? '待审批' : item.status === 1 ? '已通过' : '已驳回',
        rejectReason: item.reason
      }));
    } else {
      recentSigns.value = [];
    }
  } catch (error) {
    console.error('获取签课记录失败:', error);
    recentSigns.value = [];
    showToast('获取签课记录失败');
  }
};

// 获取签课统计数据
const getTeacherSignInStats = async () => {
  try {
    const params = {
      beginDate: dateRange.value.start,
      endDate: dateRange.value.end
    };
    const res = await teacherSignInStatisticalAnalysis(params);
    if (res.code === 0) {
      const { sum, classList } = res.data;
      
      // 更新教师总体统计数据
      teacherStats.value = {
        totalClasses: Number(sum.classCount) || 0,
        totalHours: Number(sum.allLessonCount) || 0,
        completedHours: Number(sum.sumLessonCount) || 0,
        completionRate: Number(sum.completionRate) || 0
      };

      // 更新班级统计数据
      teacherClassStats.value = classList.map(item => ({
        id: item.classId,
        className: item.schoolClass.name,
        subject: item.subject.name,
        totalHours: Number(item.allLessonCount),
        completedHours: Number(item.sumLessonCount),
        completionRate: Number(item.completionRate)
      }));
    } else {
      showToast(res.msg || '获取统计数据失败');
    }
  } catch (error) {
    console.error('获取统计数据失败:', error);
    showToast('获取统计数据失败');
  }
};

// 获取班主任课程统计数据
const getHeadTeacherStats = async () => {
  try {
    const params = {
      beginDate: dateRange.value.start,
      endDate: dateRange.value.end,
      classId: activeClass.value?.id,
      current: 1,
      size: 10
    };

    const res = await headTeacherCourseStatistics(params);
    if (res.code === 0) {
      // 更新课程类型统计
      if (res.data.courseList) {
        courseTypes.value = res.data.courseList.map(item => ({
          type: item.subjectId,
          name: item.subject?.name || '未知课程',
          totalHours: Number(item.allLessonCount) || 0,
          completedHours: Number(item.sumLessonCount) || 0,
          color: '#00c9a4'
        }));

        // 计算总体统计数据
        const totalStats = res.data.courseList.reduce((acc, curr) => {
          acc.totalHours += Number(curr.allLessonCount) || 0;
          acc.completedHours += Number(curr.sumLessonCount) || 0;
          return acc;
        }, { totalHours: 0, completedHours: 0 });

        // 更新总体统计数据
        stats.value = {
          totalHours: totalStats.totalHours,
          completedHours: totalStats.completedHours,
          remainingHours: totalStats.totalHours - totalStats.completedHours,
          completionRate: totalStats.totalHours > 0 
            ? Math.round((totalStats.completedHours / totalStats.totalHours) * 100) 
            : 0
        };
      }

      // 更新教师统计列表
      if (res.data.teacherList) {
        teacherStatsList.value = res.data.teacherList.map(item => ({
          id: item.teacherId,
          name: item.teacher?.realname || item.teacher?.nickname || '未知教师',
          subject: item.subject?.name || '未知科目',
          headUrl: item.teacher?.headUrl || '/static/assets/head.jpg',
          totalHours: Number(item.allLessonCount) || 0,
          completedHours: Number(item.sumLessonCount) || 0,
          remainingHours: Number(item.remainingLessonCount) || 0,
          completionRate: Number(item.completionRate) || 0
        }));
      }
    } else {
      showToast(res.msg || '获取统计数据失败');
    }
  } catch (error) {
    console.error('获取统计数据失败:', error);
    showToast('获取统计数据失败');
  }
};

// 在组件挂载时获取数据
onMounted(async () => {
  // 默认设置为任课老师视图
  isHeadTeacher.value = false;
  await initClassList();
  await updateStats();
});

// 在 script setup 中添加
const currentCourse = ref(null);
</script>

<style lang="scss" scoped>
.course-stats {
  height: 100%;
  padding: 16px;
  overflow-y: auto;
  &::-webkit-scrollbar {
    display: none;
  }
  scrollbar-width: none;
  -ms-overflow-style: none;

  .header {
    margin-bottom: 20px;

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

    .date-range {
      display: flex;
      gap: 12px;

      .van-button {
        flex: 1;
        height: 32px;
        font-size: 14px;

        &--primary {
          font-weight: 500;
        }
      }
    }
  }

  .stat-cards {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 12px;
    margin-bottom: 20px;

    .stat-card {
      background: #fff;
      border-radius: 12px;
      padding: 20px;
      text-align: center;
      box-shadow: 0 2px 12px rgba(0,0,0,0.05);

      .value {
        font-size: 24px;
        font-weight: bold;
        color: #00c9a4;
        margin-bottom: 8px;
      }

      .label {
        font-size: 14px;
        color: #666;
      }
    }
  }

  .section-title {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 16px;
    padding: 0 4px;

    text {
      font-size: 16px;
      font-weight: 500;
      color: #333;
    }
  }

  .course-types {
    background: #fff;
    border-radius: 12px;
    padding: 20px;
    margin-bottom: 20px;
    box-shadow: 0 2px 12px rgba(0,0,0,0.05);

    .type-list {
      .type-item {
        display: flex;
        align-items: center;
        margin-bottom: 20px;
        position: relative;

        &:last-child {
          margin-bottom: 0;
        }

        .info {
          width: 120px;

          .name {
            font-size: 14px;
            color: #333;
            margin-bottom: 4px;
          }

          .count {
            font-size: 12px;
            color: #999;
          }
        }

        .progress-bar {
          flex: 1;
          height: 24px;
          background: #f6f7fb;
          border-radius: 12px;
          margin: 0 16px;
          padding: 4px;
          box-shadow: inset 0 2px 4px rgba(0,0,0,0.05);
          position: relative;

          .progress {
            height: 100%;
            border-radius: 8px;
            background: #00c9a4;
            position: relative;
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            display: flex;
            align-items: center;
            justify-content: flex-end;
            padding-right: 10px;
            color: #fff;
            font-size: 14px;
            font-weight: 500;
            min-width: 40px;

            &::before {
              content: attr(data-progress) '%';
              position: relative;
              z-index: 2;
            }

            &::after {
              content: '';
              position: absolute;
              top: 0;
              left: 0;
              right: 0;
              height: 50%;
              background: linear-gradient(
                to bottom,
                rgba(255,255,255,0.2),
                rgba(255,255,255,0)
              );
              border-radius: 8px 8px 0 0;
            }
          }
        }

        .rate {
          display: none;
        }
      }
    }
  }

  .teacher-stats {
    background: #fff;
    border-radius: 12px;
    padding: 20px;
    box-shadow: 0 2px 12px rgba(0,0,0,0.05);

    .teacher-list {
      .teacher-item {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 16px 0;
        border-bottom: 1px solid #f5f5f5;

        &:last-child {
          border-bottom: none;
          padding-bottom: 0;
        }

        &:first-child {
          padding-top: 0;
        }

        .teacher-info {
          display: flex;
          align-items: center;

          .avatar {
            margin-right: 12px;
          }

          .info {
            .name {
              display: block;
              font-size: 15px;
              font-weight: 500;
              color: #333;
              margin-bottom: 4px;
            }

            .subject {
              font-size: 12px;
              color: #999;
            }
          }
        }

        .stats-info {
          display: flex;
          gap: 24px;

          .stat-box {
            text-align: center;

            .value {
              display: block;
              font-size: 16px;
              font-weight: 500;
              color: #333;
              margin-bottom: 2px;
            }

            .label {
              font-size: 12px;
              color: #999;
            }
          }
        }
      }
    }
  }

  /* 任老师班级统计样式 */
  .class-stats {
    background: #fff;
    border-radius: 12px;
    padding: 20px;
    box-shadow: 0 2px 12px rgba(0,0,0,0.05);

    .class-list {
      .class-item {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 16px 0;
        border-bottom: 1px solid #f5f5f5;

        &:last-child {
          border-bottom: none;
          padding-bottom: 0;
        }

        &:first-child {
          padding-top: 0;
        }

        .class-info {
          width: 150px;

          .name {
            display: block;
            font-size: 15px;
            font-weight: 500;
            color: #333;
            margin-bottom: 4px;
          }

          .subject {
            font-size: 12px;
            color: #999;
          }
        }

        .progress-info {
          flex: 1;
          display: flex;
          align-items: center;
          gap: 16px;

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

          .hours {
            min-width: 100px;
            text-align: right;
            font-size: 14px;

            .completed {
              color: #00c9a4;
              font-weight: 500;
            }

            .separator {
              margin: 0 4px;
              color: #999;
            }

            .total {
              color: #666;
            }
          }
        }
      }
    }
  }

  .role-switch {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: 12px;
    margin-bottom: 20px;
    padding: 0 4px;

    text {
      font-size: 14px;
      color: #666;
    }

    ::v-deep .van-switch {
      .van-switch__node {
        background: #fff;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
      }
    }
  }

  .date-filter {
    background: #fff;
    border-radius: 12px;
    margin-bottom: 20px;
    box-shadow: 0 2px 12px rgba(0,0,0,0.05);
    overflow: hidden;
    padding: 16px;

    .date-range-picker {
      display: flex;
      align-items: center;
      justify-content: space-between;

      .date-item {
        flex: 1;
        cursor: pointer;
        transition: all 0.3s;

        &:hover {
          opacity: 0.8;
        }

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
        margin-top: 20px;

        .van-icon {
          font-size: 16px;
        }
      }
    }
  }

  .date-picker-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 16px;
    border-bottom: 1px solid #f5f5f5;

    text {
      font-size: 16px;
      font-weight: 500;
      color: #333;
    }

    .van-icon {
      font-size: 20px;
      color: #999;
      cursor: pointer;

      &:hover {
        color: #666;
      }
    }
  }

  .sign-popup {
    height: 100%;
    display: flex;
    flex-direction: column;

    .popup-header {
      padding: 16px 20px;
      border-bottom: 1px solid #f5f5f5;
      text-align: center;

      .title {
        font-size: 18px;
        font-weight: 500;
        color: #333;
      }
    }

    .popup-content {
      flex: 1;
      padding: 20px;
      overflow-y: auto;

      .form-item {
        margin-bottom: 20px;

        .label {
          display: flex;
          align-items: center;
          margin-bottom: 8px;
          font-size: 15px;
          color: #333;

          .required {
            color: #ff4d4f;
            margin-left: 4px;
          }

          .optional {
            color: #999;
            font-size: 13px;
            margin-left: 4px;
          }
        }

        .input {
          width: 100%;
          height: 40px;
          padding: 8px 12px;
          border: 1px solid #e8e8e8;
          border-radius: 4px;
          font-size: 14px;
          transition: all 0.3s;

          &:focus {
            border-color: #00c9a4;
            box-shadow: 0 0 0 2px rgba(0,201,164,0.1);
          }

          &.textarea {
            height: 100px;
            resize: none;
          }

          &.readonly {
            background-color: #f5f7fa;
            border-color: #e8e8e8;
            color: #666;
            cursor: not-allowed;
            user-select: none;
            
            // 添加一个微的内阴影效果
            box-shadow: inset 0 1px 2px rgba(0,0,0,0.05);
            
            // 禁用悬停和焦点果
            &:hover, &:focus {
              border-color: #e8e8e8;
              box-shadow: inset 0 1px 2px rgba(0,0,0,0.05);
            }
          }
        }

        .number-input {
          display: flex;
          align-items: center;
          gap: 8px;

          .unit {
            font-size: 14px;
            color: #666;
          }
        }

        .tip {
          display: block;
          margin-top: 4px;
          font-size: 12px;
          color: #999;
        }
      }

      .notice {
        margin-top: 32px;
        padding: 16px;
        background: #f8f8f8;
        border-radius: 8px;

        .van-icon {
          font-size: 16px;
          color: #ff9900;
          margin-right: 4px;
          vertical-align: -2px;
        }

        text {
          font-size: 14px;
          font-weight: 500;
          color: #333;
        }

        .notice-item {
          margin-top: 8px;
          font-size: 13px;
          color: #666;
          line-height: 1.5;
        }
      }
    }

    .popup-footer {
      padding: 16px 20px;
      border-top: 1px solid #f5f5f5;
      
      .van-button {
        height: 44px;
        font-size: 16px;
      }
    }
  }

  .time-picker {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 8px 12px;
    border: 1px solid #eee;
    border-radius: 4px;
    color: #333;
    font-size: 14px;
    cursor: pointer;

    &:hover {
      border-color: #00c9a4;
    }
  }

  .sign-course-section {
    background: #fff;
    border-radius: 12px;
    padding: 20px;
    margin-bottom: 20px;
    box-shadow: 0 2px 12px rgba(0,0,0,0.05);

    .section-title {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 16px;

      text {
        font-size: 16px;
        font-weight: 500;
        color: #333;
      }

      .more {
        display: flex;
        align-items: center;
        font-size: 14px;
        color: #00c9a4;
        cursor: pointer;
        padding: 4px 8px;
        border-radius: 4px;
        transition: all 0.3s;

        text {
          margin-right: 4px;
        }

        .van-icon {
          font-size: 12px;
        }

        &:hover {
          background: rgba(0, 201, 164, 0.1);
        }

        &:active {
          background: rgba(0, 201, 164, 0.2);
        }
      }
    }

    .recent-signs {
      .sign-item {
        display: flex;
        align-items: center;
        padding: 12px 0;
        border-bottom: 1px solid #f5f5f5;

        &:last-child {
          border-bottom: none;
        }

        .status-tag {
          padding: 2px 8px;
          border-radius: 4px;
          font-size: 12px;
          margin-right: 12px;

          &.pending {
            background: #fff7e6;
            color: #ffa500;
          }

          &.approved {
            background: #e6f7f4;
            color: #00c9a4;
          }

          &.rejected {
            background: #fee;
            color: #ff4d4f;
          }
        }

        .sign-content {
          flex: 1;

          .title {
            margin-bottom: 4px;

            .class-name {
              font-size: 14px;
              font-weight: 500;
              margin-right: 8px;
            }

            .subject {
              font-size: 13px;
              color: #666;
            }
          }

          .details {
            font-size: 12px;
            color: #999;

            .time {
              margin-right: 16px;
            }

            .description {
              display: block;
              margin-top: 4px;
              color: #666;
              line-height: 1.4;
            }

            .reject-reason {
              display: block;
              margin-top: 4px;
              font-size: 12px;
              color: #ff4d4f;
              line-height: 1.4;
            }
          }
        }
      }

      .empty-tip {
        text-align: center;
        color: #999;
        font-size: 14px;
        padding: 20px 0;
      }

      // 制大高度，超出显示滚动条
      max-height: 260px;
      overflow-y: auto;
      scrollbar-width: none; /* Firefox */
      -ms-overflow-style: none; /* IE and Edge */
      &::-webkit-scrollbar {
        display: none; /* Chrome, Safari and Opera */
      }
      
      &::-webkit-scrollbar {
        width: 4px;
      }
      
      &::-webkit-scrollbar-thumb {
        background: #e0e0e0;
        border-radius: 2px;
      }
    }

    .quick-sign {
      margin-top: 16px;
      height: 48px;
      background: linear-gradient(135deg, #29b5a5 0%, #00c9a4 100%);
      border-radius: 24px;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      transition: all 0.3s;
      box-shadow: 0 4px 12px rgba(0,201,164,0.2);

      .van-icon {
        font-size: 20px;
        color: #fff;
        margin-right: 8px;
      }

      text {
        font-size: 15px;
        color: #fff;
        font-weight: 500;
        letter-spacing: 1px;
      }

      &:hover {
        transform: translateY(-2px);
        box-shadow: 0 6px 16px rgba(0,201,164,0.3);
      }

      &:active {
        transform: translateY(0);
        box-shadow: 0 4px 12px rgba(0,201,164,0.2);
      }
    }
  }

  .form-item {
    position: relative; // 将相对定位移到这里
    margin-bottom: 24px;

    &:last-child {
      margin-bottom: 0;
    }

    .required {
      color: #ff4d4f;
      margin-left: 4px;
    }
    
    .label {
      display: flex;
      align-items: center;
    }
  }

  .sign-approval-section {
    background: #fff;
    border-radius: 12px;
    padding: 20px;
    margin-bottom: 20px;
    box-shadow: 0 2px 12px rgba(0,0,0,0.05);

    .approval-list {
      .approval-item {
        padding: 16px;
        border-bottom: 1px solid #f5f5f5;
        
        &:last-child {
          border-bottom: none;
        }

        .teacher-info {
          display: flex;
          align-items: center;
          margin-bottom: 12px;

          .avatar {
            margin-right: 12px;
          }

          .info {
            .name {
              font-size: 15px;
              font-weight: 500;
              color: #333;
              margin-right: 8px;
            }

            .subject {
              font-size: 13px;
              color: #666;
            }
          }
        }

        .sign-info {
          margin-bottom: 12px;

          .course-detail {
            margin-bottom: 8px;
            
            .time {
              font-size: 13px;
              color: #666;
              margin-right: 16px;
            }

            .hours {
              font-size: 13px;
              color: #00c9a4;
              font-weight: 500;
            }
          }

          .content {
            font-size: 13px;
            line-height: 1.5;
            
            .label {
              color: #666;
            }
            
            .text {
              color: #333;
            }
          }
        }

        .actions {
          display: flex;
          justify-content: flex-end;
          gap: 12px;

          .van-button {
            min-width: 64px;
            
            &--default {
              border-color: #ddd;
            }
          }
        }
      }

      .empty-tip {
        text-align: center;
        color: #999;
        font-size: 14px;
        padding: 32px 0;
      }
    }
  }

  .reject-dialog-content {
    padding: 16px;

    .reject-reason-input {
      width: 100%;
      height: 100px;
      padding: 8px;
      border: 1px solid #ddd;
      border-radius: 4px;
      font-size: 14px;
      resize: none;

      &:focus {
        border-color: #00c9a4;
        outline: none;
      }
    }
  }

  .class-stats {
    .hours {
      .rate {
        margin-left: 8px;
        color: #00c9a4;
        font-size: 12px;
      }
    }
  }
}

.boxOne {
  width: 100%;
  height: 100%;
  background: #fff;
  
  .title {
    text-align: center;
    height: 56px;
    line-height: 56px;
    font-size: 18px;
    font-weight: 500;
    color: #333;
    border-bottom: 1px solid #f6f7fb;
    position: relative;
    
    &::after {
      content: '';
      position: absolute;
      bottom: 0;
      left: 50%;
      transform: translateX(-50%);
      width: 40px;
      height: 3px;
      background: #00c9a4;
      border-radius: 2px;
    }
  }
  
  .content {
    padding: 20px;
    
    .li {
      display: flex;
      position: relative;
      padding: 16px;
      border-bottom: 1px solid #f2f3f7;
      transition: all 0.3s;
      
      &:hover {
        background: #f8f9fa;
      }
      
      .name {
        font-size: 15px;
        color: #333;
        width: 90px;
        font-weight: 500;
      }
      
      .text {
        position: absolute;
        right: 16px;
        min-width: 200px;
        
        .content-textarea {
          width: 100%;
          height: 120px;
          padding: 12px;
          border: 1px solid #e8e8e8;
          border-radius: 8px;
          font-size: 14px;
          resize: none;
          transition: all 0.3s;
          background: #f8f9fa;
          
          &:focus {
            border-color: #00c9a4;
            background: #fff;
            box-shadow: 0 0 0 3px rgba(0, 201, 164, 0.1);
            outline: none;
          }

          &::placeholder {
            color: #999;
          }
        }

        .unit {
          margin-left: 12px;
          color: #666;
          font-size: 14px;
        }
      }

      ::v-deep .van-stepper {
        background: #f8f9fa;
        border-radius: 8px;
        overflow: hidden;

        .van-stepper__minus,
        .van-stepper__plus {
          background: #fff;
          border: 1px solid #e8e8e8;
          color: #666;
          
          &:active {
            background: #f5f5f5;
          }
        }

        .van-stepper__input {
          background: #fff;
          border: 1px solid #e8e8e8;
          border-left: none;
          border-right: none;
          color: #333;
          font-weight: 500;
        }
      }

      ::v-deep .van-dropdown-menu {
        background: #f8f9fa;
        border-radius: 8px;
        overflow: hidden;
        border: 1px solid #e8e8e8;
        
        .van-dropdown-menu__title {
          padding: 8px 16px;
          font-size: 14px;
        }
      }
    }

    .notice {
      margin-top: 24px;
      padding: 20px;
      background: #f8f9fa;
      border-radius: 12px;
      border: 1px solid #e8e8e8;

      .van-icon {
        font-size: 18px;
        color: #ff9900;
        margin-right: 8px;
        vertical-align: -3px;
      }

      text {
        font-size: 15px;
        font-weight: 500;
        color: #333;
      }

      .notice-item {
        margin-top: 12px;
        padding-left: 26px;
        font-size: 14px;
        color: #666;
        line-height: 1.6;
        position: relative;

        &::before {
          content: '';
          position: absolute;
          left: 10px;
          top: 8px;
          width: 4px;
          height: 4px;
          border-radius: 50%;
          background: #00c9a4;
        }
      }
    }
  }
  
  .editBtnT {
    width: 180px;
    background: linear-gradient(135deg, #29b5a5 0%, #00c9a4 100%);
    height: 44px;
    text-align: center;
    line-height: 44px;
    border-radius: 22px;
    color: #fff;
    font-size: 16px;
    font-weight: 500;
    margin: 0 auto;
    margin-top: 40px;
    cursor: pointer;
    transition: all 0.3s;
    box-shadow: 0 4px 12px rgba(0, 201, 164, 0.2);
    
    &:hover {
      transform: translateY(-2px);
      box-shadow: 0 6px 16px rgba(0, 201, 164, 0.3);
    }
    
    &:active {
      transform: translateY(0);
      opacity: 0.9;
    }
  }
  
  ::v-deep .van-dropdown-menu__bar {
    background: none;
    box-shadow: none;
  }
  
  ::v-deep .van-dropdown-menu__title--active {
    color: #00c9a4;
  }
  
  ::v-deep .van-dropdown-item__option--active,
  ::v-deep .van-dropdown-item__option--active .van-dropdown-item__icon {
    color: #00c9a4;
  }
  
  ::v-deep .van-dropdown-menu .van-overlay {
    background: rgba(0,0,0,0.1);
  }

  ::v-deep .van-popup__close-icon {
    color: #999;
    font-size: 20px;
    top: 16px;
    right: 16px;
    transition: all 0.3s;

    &:hover {
      color: #666;
      transform: rotate(90deg);
    }
  }
}

.sign-form {
  height: 100%;
  display: flex;
  flex-direction: column;
  background: #fff;

  .form-header {
    padding: 24px 20px;
    text-align: center;
    position: relative;
    border-bottom: 1px solid #f5f5f5;
    background: linear-gradient(to right, #f8f9fa, #fff);

    .title {
      font-size: 18px;
      font-weight: 500;
      color: #333;
      letter-spacing: 0.5px;
      position: relative;
      display: inline-block;
      
      &::after {
        content: '';
        position: absolute;
        bottom: -8px;
        left: 50%;
        transform: translateX(-50%);
        width: 24px;
        height: 3px;
        background: #00c9a4;
        border-radius: 2px;
      }
    }
  }

  .form-content {
    flex: 1;
    overflow-y: auto;
    padding: 20px;
    -webkit-overflow-scrolling: touch;
    background: #fff;
    
    // 隐藏滚动条
    &::-webkit-scrollbar {
      display: none;
    }
    scrollbar-width: none;
    -ms-overflow-style: none;
    
    .form-body {
      padding: 0;

      .form-group {
        background: #fff;
        padding: 20px;
        margin-bottom: 20px;
        border-radius: 12px;
        box-shadow: 0 2px 8px rgba(0, 0, 0, 0.02);
        transition: all 0.3s;

        &:hover {
          box-shadow: 0 4px 12px rgba(0, 0, 0, 0.04);
          transform: translateY(-1px);
        }

        &.info-group {
          background: #f8f9fa;
          border: 1px solid #f0f0f0;
          padding: 16px;

          .info-item {
            display: flex;
            align-items: center;
            margin-bottom: 12px;

            &:last-child {
              margin-bottom: 0;
            }

            .info-label {
              width: 80px;
              font-size: 14px;
              color: #666;
              position: relative;
              padding-left: 12px;

              &::before {
                content: '';
                position: absolute;
                left: 0;
                top: 50%;
                transform: translateY(-50%);
                width: 4px;
                height: 4px;
                background: #00c9a4;
                border-radius: 50%;
              }
            }

            .info-value {
              flex: 1;
              font-size: 14px;
              color: #333;
              font-weight: 500;
            }
          }
        }

        .form-item {
          position: relative;
          margin-bottom: 24px;

          &:last-child {
            margin-bottom: 0;
          }

          .label {
            display: flex;
            align-items: center;
            font-size: 14px;
            color: #333;
            margin-bottom: 10px;
            font-weight: 500;

            &.required::after {
              content: '*';
              color: #ff4d4f;
              margin-left: 4px;
              font-family: SimSun, sans-serif;
            }
          }

          .course-select {
            width: 100%;
            height: 40px;
            padding: 0 16px;
            border: 1px solid #eee;
            border-radius: 8px;
            font-size: 14px;
            color: #333;
            background: #fff;
            appearance: none;
            -webkit-appearance: none;
            background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 12 12'%3E%3Cpath fill='%23999' d='M6 8.825L1.175 4 2.238 2.938 6 6.7l3.763-3.762L10.825 4z'/%3E%3C/svg%3E");
            background-repeat: no-repeat;
            background-position: right 16px center;
            background-size: 12px;
            cursor: pointer;
            transition: all 0.3s;
            
            &:hover {
              border-color: #00c9a4;
              box-shadow: 0 0 0 3px rgba(0, 201, 164, 0.1);
            }
            
            &:focus {
              border-color: #00c9a4;
              outline: none;
              box-shadow: 0 0 0 3px rgba(0, 201, 164, 0.1);
            }

            option {
              padding: 12px;
              font-size: 14px;
              color: #333;
            }
          }

          .hours-wrapper {
            display: flex;
            align-items: center;
            margin-bottom: 8px;

            ::v-deep .van-stepper {
              background: #f8f9fa;
              border-radius: 8px;
              padding: 4px;
              border: 1px solid #eee;

              .van-stepper__minus,
              .van-stepper__plus {
                width: 32px;
                height: 32px;
                background: #fff;
                border: 1px solid #eee;
                border-radius: 6px;
                
                &:active {
                  background: #f5f5f5;
                }
              }

              .van-stepper__input {
                height: 32px;
                margin: 0 8px;
                background: #fff;
                border: 1px solid #eee;
                border-radius: 6px;
                font-size: 15px;
                color: #333;
                font-weight: 500;
              }
            }

            .unit {
              margin-left: 12px;
              font-size: 14px;
              color: #666;
              background: #f8f9fa;
              padding: 6px 12px;
              border-radius: 6px;
            }
          }

          .tip {
            font-size: 12px;
            color: #999;
            margin-top: 8px;
            padding-left: 16px;
            position: relative;

            &::before {
              content: '';
              position: absolute;
              left: 6px;
              top: 50%;
              transform: translateY(-50%);
              width: 3px;
              height: 3px;
              background: #999;
              border-radius: 50%;
            }
          }

          .content-input {
            width: 100%;
            height: 120px;
            padding: 16px;
            padding-bottom: 32px;
            background: #fff;
            border: 1px solid #eee;
            border-radius: 8px;
            font-size: 14px;
            line-height: 1.6;
            resize: none;
            transition: all 0.3s;

            &:hover {
              border-color: #00c9a4;
              box-shadow: 0 0 0 3px rgba(0, 201, 164, 0.1);
            }

            &:focus {
              border-color: #00c9a4;
              outline: none;
              box-shadow: 0 0 0 3px rgba(0, 201, 164, 0.1);
            }

            &::placeholder {
              color: #999;
            }
          }

          .word-count {
            position: absolute;
            right: 16px;
            bottom: 8px;
            font-size: 12px;
            color: #999;
            padding: 2px 8px;
            pointer-events: none;
          }
        }
      }

      .notice-box {
        background: #fffbe6;
        border-radius: 8px;
        padding: 20px;
        margin-top: 24px;
        border: 1px solid rgba(250, 173, 20, 0.2);

        .notice-header {
          display: flex;
          align-items: center;
          margin-bottom: 16px;

          .van-icon {
            font-size: 18px;
            color: #faad14;
            margin-right: 8px;
          }

          text {
            font-size: 15px;
            font-weight: 500;
            color: #333;
          }
        }

        .notice-items {
          .notice-item {
            display: flex;
            align-items: flex-start;
            margin-bottom: 12px;

            &:last-child {
              margin-bottom: 0;
            }

            .dot {
              width: 6px;
              height: 6px;
              border-radius: 50%;
              background: #faad14;
              margin-top: 8px;
              margin-right: 10px;
              flex-shrink: 0;
            }

            text {
              flex: 1;
              font-size: 13px;
              color: #666;
              line-height: 1.6;
            }
          }
        }
      }
    }
  }

  .form-footer {
    padding: 20px;
    background: #fff;
    border-top: 1px solid #f5f5f5;

    .submit-button {
      width: 100%;
      height: 48px;
      display: flex;
      align-items: center;
      justify-content: center;
      background: linear-gradient(135deg, #29b5a5 0%, #00c9a4 100%);
      border: none;
      border-radius: 24px;
      color: #fff;
      font-size: 16px;
      font-weight: 500;
      cursor: pointer;
      transition: all 0.3s;
      box-shadow: 0 4px 12px rgba(0, 201, 164, 0.2);

      &:hover:not(:disabled) {
        transform: translateY(-2px);
        box-shadow: 0 6px 16px rgba(0, 201, 164, 0.3);
      }

      &:active:not(:disabled) {
        transform: translateY(0);
        opacity: 0.9;
      }

      &:disabled {
        opacity: 0.7;
        cursor: not-allowed;
        box-shadow: none;
      }

      &.loading {
        opacity: 0.7;
      }

      .van-loading {
        margin-right: 8px;
      }
    }
  }
}

// 关闭按钮样式
::v-deep .van-popup__close-icon {
  color: #999;
  font-size: 20px;
  top: 20px;
  right: 20px;
  transition: all 0.3s;
  z-index: 1;

  &:hover {
    color: #666;
    transform: rotate(90deg);
  }
}
</style> 