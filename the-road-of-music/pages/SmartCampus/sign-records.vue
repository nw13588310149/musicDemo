<template>
  <view class="app-container16">

    <!-- 主体内容区 -->
    <view class="contain">

      <!-- 签课记录内容 -->
      <view class="content">
        <!-- 筛选区域 - 固定不滚动 -->
        <view class="filter-section">
          <view class="filter-box">
            <view class="date-range">
              <view 
                class="date-btn"
                v-for="range in timeRanges" 
                :key="range"
                :class="{ active: selectedTimeRange === range }"
                @click="selectTimeRange(range)"
              >{{range}}</view>
            </view>
            
            <view class="date-picker">
              <view class="picker-item" @click="openDatePicker('start')">
                <text class="label">开始日期</text>
                <view class="value">
                  <text>{{selectedDateRange.start}}</text>
                  <van-icon name="calendar-o" />
                </view>
              </view>
              <view class="separator">
                <van-icon name="arrow" />
              </view>
              <view class="picker-item" @click="openDatePicker('end')">
                <text class="label">结束日期</text>
                <view class="value">
                  <text>{{selectedDateRange.end}}</text>
                  <van-icon name="calendar-o" />
                </view>
              </view>
            </view>
          </view>
        </view>

        <!-- 列表区域 - 可滚动 -->
        <view class="records-section">
          <view class="list-box">
            <view class="record-item" v-for="item in signRecords" :key="item.id">
              <!-- 左侧时间轴 -->
              <view class="time-line">
                <text class="time">{{formatTime(item.signTime, 'HH:mm')}}</text>
                <text class="date">{{formatTime(item.signTime, 'MM-DD')}}</text>
                <view class="line"></view>
              </view>
              
              <!-- 右侧内容区 -->
              <view class="content-box">
                <view class="header">
                  <view class="class-info">
                    <text class="name">{{item.className}}</text>
                    <text class="subject">{{item.subject}}</text>
                  </view>
                  <view class="status-tag" :class="item.status">{{item.statusText}}</view>
                </view>
                
                <view class="desc">{{item.content}}</view>
                
                <!-- 签课时间和课时信息 -->
                <view class="sign-info">
                  <view class="time-info">
                    <text class="label">签课时间：</text>
                    <text class="value">{{item.signTime}}</text>
                  </view>
                  <view class="hours">
                    <van-icon name="clock-o" />
                    <text>{{item.hours}}课时</text>
                  </view>
                </view>

                <!-- 驳回原因 -->
                <view class="reject-reason" v-if="item.status === 'rejected' && item.rejectReason">
                  <text class="label">驳回原因：</text>
                  <text class="value">{{item.rejectReason}}</text>
                  <view class="resubmit-btn" @click="resubmitSign(item)">重新提交</view>
                </view>
              </view>
            </view>
          </view>
        </view>
      </view>
    </view>

    <!-- 日历弹窗 -->
    <van-calendar 
      v-model:show="dateShow" 
      :min-date="minDate" 
      :max-date="maxDate" 
      @confirm="onConfirm" 
    />

    <!-- 班级选择器 -->
    <van-popup v-model:show="showPicker" round position="bottom">
      <van-picker
        :columns="columns"
        @cancel="showPicker = false"
        @confirm="onClassChange"
        show-toolbar
        title="选择班级"
      />
    </van-popup>

    <!-- 在主体内容区添加浮动签课按钮 -->
    <view class="quick-sign" @click="handleQuickSign">
      <van-icon name="plus" />
      <text>发起签课</text>
    </view>

    <!-- 修改签课弹窗 -->
    <van-popup
      v-model:show="showSignPopup"
      position="right"
      :style="{ width: '40%', height: '100%' }"
      closeable
      @close="closeSignPopup"
    >
      <view class="sign-form">
        <view class="form-header">
          <text class="title">{{ isResubmit ? '重新提交签课申请' : '发起签课申请' }}</text>
        </view>

        <!-- 替换scroll-view为普通view -->
        <view class="form-content">
          <view class="form-body">
            <!-- 课程选择区域 -->
            <template v-if="!isResubmit">
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
                      {{course.courseStartTime.split(' ')[1]}} {{course.className}} - {{course.subjectName}}
                    </option>
                  </select>
                </view>
              </view>
            </template>

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
            :disabled="submitting"
          >
            <van-loading v-if="submitting" size="20px" color="#fff" />
            <text>{{ submitting ? '提交中...' : '提交申请' }}</text>
          </button>
        </view>
      </view>
    </van-popup>
  </view>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import dayjs from 'dayjs';
import { showToast } from 'vant';
import { teacherSignInList, teacherSignInSave, courseList ,teacherSignInUpdate} from '/api/home.js';

const route = useRoute();
const router = useRouter();

// 在 script setup 顶部添加
const emit = defineEmits(['change-component']);

// 初始化日期范围函数
const initDateRange = () => {
  const now = dayjs();
  return {
    start: now.startOf('month').format('YYYY-MM-DD'),
    end: now.format('YYYY-MM-DD')
  };
};

// 状态定义 - 确保在使用前初始化
const showTop = ref(true);
const teacherId = route.query.teacherId;
const selectedTimeRange = ref('本月');
const selectedDateRange = ref(initDateRange());  // 使用初始化函数
const timeRanges = ['本周', '本月'];

// 日期选择器相关
const dateShow = ref(false);
const minDate = ref(dayjs().subtract(1, 'year').toDate());
const maxDate = ref(dayjs().add(1, 'year').toDate());
const pickerType = ref('start'); // 添加选择器类型

// 列表数据
const loading = ref(false);
const hasMore = ref(true);
const signRecords = ref([]);
const page = ref(1);
const pageSize = ref(10);

// 签课相关数据
const showSignPopup = ref(false);
const todayCourses = ref([]);
const selectedCourseId = ref('');
const currentCourse = ref(null);
const selectedHours = ref(1);
const teachingGoal = ref('');
const submitting = ref(false);
const isResubmit = ref(false);
const currentSignId = ref(null);

// 表单数据
const signForm = ref({
  hours: 1,
  content: ''
});

// 时间格式化函数
const formatTime = (time, format) => {
  if (!time) return '';
  return dayjs(time).format(format);
};

// 重新提交签课
const resubmitSign = (item) => {
  isResubmit.value = true;
  currentCourse.value = {
    id: item.courseId,
    name: `${item.className} - ${item.subject}`,
    time: item.signTime
  };
  signForm.value = {
    hours: item.hours,
    content: item.content
  };
  showSignPopup.value = true;
};

// 选择时间范围
const selectTimeRange = (range) => {
  selectedTimeRange.value = range;
  const now = dayjs();
  
  if (range === '本周') {
    selectedDateRange.value = {
      start: now.startOf('week').format('YYYY-MM-DD'),
      end: now.format('YYYY-MM-DD')
    };
  } else if (range === '本月') {
    selectedDateRange.value = {
      start: now.startOf('month').format('YYYY-MM-DD'),
      end: now.format('YYYY-MM-DD')
    };
  }
  
  getSignRecords();
};

// 获取签课记录
const getSignRecords = async () => {
  try {
    loading.value = true;
    const params = {
      beginDate: selectedDateRange.value.start,
      endDate: selectedDateRange.value.end,
      current: page.value,
      size: pageSize.value
    };
    
    const res = await teacherSignInList(params);
    if (res.code === 0) {
      signRecords.value = res.data.map(item => ({
        id: item.id,
        className: item.schoolClass.name,
        subject: item.subject.name,
        signTime: item.courseTime,
        hours: item.lessonCount,
        content: item.description,
        status: item.status === 0 ? 'pending' : item.status === 1 ? 'approved' : 'rejected',
        statusText: item.status === 0 ? '待审批' : item.status === 1 ? '已通过' : '已驳回',
        rejectReason: item.reason
      }));
    } else {
      showToast(res.msg || '获取签课记录失败');
    }
  } catch (error) {
    console.error('获取签课记录失败:', error);
    showToast('获取签课记录失败');
  } finally {
    loading.value = false;
  }
};

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
    
  } catch (error) {
    console.error('获取用户信息失败:', error);
    showToast('获取用户信息失败');
  } finally {
    loading.value = false;
  }
});

// 快捷签课按钮点击事件
const handleQuickSign = async () => {
  const today = dayjs().format('YYYY-MM-DD');
  
  try {
    const params = {
      beginDate: today,
      endDate: today,
      classId: "",
      teacherId: myInfo.value?.id
    };
    
    const res = await courseList(params);
    if (res.code === 0) {
      todayCourses.value = res.data[today] || [];
      
      if (todayCourses.value.length === 0) {
        showToast('今日没有课程安排');
        return;
      }
      
      // 重置表单
      signForm.value = {
        hours: 1,
        content: ''
      };
      selectedCourseId.value = '';
      currentCourse.value = null;
      isResubmit.value = false;
      
      showSignPopup.value = true;
    } else {
      showToast(res.msg || '获取课表失败');
    }
  } catch (error) {
    console.error('获取课表失败:', error);
    showToast('获取课表失败，请重试');
  }
};

// 处理课程选择变化
const handleCourseChange = () => {
  const selectedCourse = todayCourses.value.find(course => course.id === selectedCourseId.value);
  if (selectedCourse) {
    currentCourse.value = {
      id: selectedCourse.id,
      name: `${selectedCourse.className} - ${selectedCourse.subjectName}`,
      time: selectedCourse.courseStartTime,
      className: selectedCourse.className
    };
  } else {
    currentCourse.value = null;
  }
};

// 处理签课提交
const handleSign = async () => {
  if (submitting.value) return;
  
  // 表单验证
  if (!isResubmit.value && !selectedCourseId.value) {
    showToast('请选择课程');
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

  try {
    submitting.value = true;
    
    const api = isResubmit.value ? teacherSignInUpdate : teacherSignInSave;
    const params = {
      courseId: isResubmit.value ? currentCourse.value.id : selectedCourseId.value,
      description: signForm.value.content.trim(),
      lessonCount: signForm.value.hours
    };

    const res = await api(params);

    if (res.code === 0) {
      showToast('提交成功');
      closeSignPopup();
      await getSignRecords();
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

// 返回方法
const goBack = () => {
  emit('change-component', {
    name: 'course-stats',
    params: {
      timeRange: selectedTimeRange.value,
      dateRange: selectedDateRange.value
    }
  });
};

// 打开日期选择器
function openDatePicker(type) {
  pickerType.value = type;
  dateShow.value = true;
}

// 确认日期选择
function onConfirm(value) {
  const selectedDate = dayjs(value).format('YYYY-MM-DD');
  
  if (pickerType.value === 'start') {
    // 如果选择的开始日期大于结束日期，则同时更新结束日期
    if (dayjs(selectedDate).isAfter(selectedDateRange.value.end)) {
      selectedDateRange.value.end = selectedDate;
    }
    selectedDateRange.value.start = selectedDate;
  } else {
    // 如果选择的结束日期小于开始日期，则同时更新开始日期
    if (dayjs(selectedDate).isBefore(selectedDateRange.value.start)) {
      selectedDateRange.value.start = selectedDate;
    }
    selectedDateRange.value.end = selectedDate;
  }
  
  dateShow.value = false;
  getSignRecords();
}

// 组件挂载时初始化
onMounted(() => {
  if (props.params) {
    selectedTimeRange.value = props.params.timeRange || '本月';
    selectedDateRange.value = props.params.dateRange || initDateRange();
  }
  getSignRecords();
});

// 定义 props
const props = defineProps({
  params: {
    type: Object,
    default: () => ({})
  }
});

// 修改关闭弹窗方法
const closeSignPopup = () => {
  showSignPopup.value = false;
  isResubmit.value = false;
  signForm.value = {
    hours: 1,
    content: ''
  };
  currentCourse.value = null;
  selectedCourseId.value = '';
};
</script>

<style lang="scss" scoped>
.app-container16 {
  width: 100%;
  height: 100%;

  .top-nav2 {
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

  .contain {
    height: calc(100% - 56px);
    background: #fff;
    border-radius: 9px;
    margin-top: 12px;
    overflow: hidden;
    position: relative;

    .header {
      background: #fff;
      border-bottom: 1px solid #f6f7fb;

      .class-select {
        padding: 12px 16px;
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 4px;
        font-size: 15px;
        color: #333;
      }
    }

    .content {
      height: calc(100% - 44px);
      display: flex;
      flex-direction: column;


      .filter-section {
        padding: 12px 12px 0;
    

        .filter-box {
          background: #fff;
          border-radius: 12px;
          padding: 16px;
          box-shadow: 0 2px 8px rgba(0,0,0,0.02);

          .date-range {
            display: flex;
            gap: 12px;
            margin-bottom: 16px;

            .date-btn {
              flex: 1;
              height: 32px;
              line-height: 32px;
              text-align: center;
              background: #f6f7fb;
              border-radius: 16px;
              font-size: 14px;
              color: #666;

              &.active {
                background: #00c9a4;
                color: #fff;
              }
            }
          }

          .date-picker {
            display: flex;
            align-items: center;
            gap: 12px;

            .picker-item {
              flex: 1;
              
              .label {
                font-size: 12px;
                color: #999;
                margin-bottom: 8px;
                display: block;
              }

              .value {
                display: flex;
                align-items: center;
                justify-content: space-between;
                background: #f6f7fb;
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
              padding: 0 4px;
              margin-top: 20px;
              color: #ddd;
            }
          }
        }
      }

      .records-section {
        flex: 1;
        overflow-y: auto;
        padding: 0 16px;
        margin-top: 12px;
        
        &::-webkit-scrollbar {
          display: none;
        }

        .list-box {
          padding: 8px 0;
          
          .record-item {
            display: flex;
            margin-bottom: 24px;
            position: relative;

            // 左侧时间轴
            .time-line {
              width: 60px;
              display: flex;
              flex-direction: column;
              align-items: center;
              padding-top: 4px;
              position: relative;

              .time {
                font-size: 15px;
                color: #333;
                font-weight: 500;
                margin-bottom: 2px;
              }

              .date {
                font-size: 12px;
                color: #999;
              }

              .line {
                position: absolute;
                left: 50%;
                top: 48px;
                bottom: -24px;
                width: 1px;
                background: #f0f0f0;
                
                &::before {
                  content: '';
                  position: absolute;
                  top: -4px;
                  left: 50%;
                  transform: translateX(-50%);
                  width: 8px;
                  height: 8px;
                  border-radius: 50%;
                  background: #00c9a4;
                  border: 2px solid #e6f7f4;
                }
              }
            }

            // 右侧内容区
            .content-box {
              flex: 1;
              margin-left: 16px;
              background: #fff;
              border-radius: 12px;
              padding: 16px;
              box-shadow: 0 2px 12px rgba(0,0,0,0.03);
              transition: all 0.3s;

              &:hover {
                transform: translateY(-2px);
                box-shadow: 0 4px 16px rgba(0,0,0,0.06);
              }

              .header {
                display: flex;
                justify-content: space-between;
                align-items: center;
                margin-bottom: 12px;

                .class-info {
                  .name {
                    font-size: 15px;
                    font-weight: 500;
                    color: #333;
                    margin-right: 8px;
                  }

                  .subject {
                    font-size: 13px;
                    color: #666;
                    background: #f6f7fb;
                    padding: 2px 8px;
                    border-radius: 4px;
                  }
                }

                .status-tag {
                  padding: 2px 12px;
                  border-radius: 4px;
                  font-size: 12px;
                  font-weight: 500;

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
              }

              .desc {
                font-size: 14px;
                color: #666;
                line-height: 1.6;
                margin-bottom: 16px;
                padding: 12px;
                background: #f8f9fa;
                border-radius: 8px;
              }

              .sign-info {
                display: flex;
                justify-content: space-between;
                align-items: center;
                padding: 12px;
                background: #f8f9fa;
                border-radius: 8px;
                margin-bottom: 12px;

                .time-info {
                  .label {
                    font-size: 13px;
                    color: #999;
                    margin-right: 4px;
                  }

                  .value {
                    font-size: 13px;
                    color: #333;
                  }
                }

                .hours {
                  display: flex;
                  align-items: center;
                  gap: 4px;
                  color: #00c9a4;
                  font-size: 13px;
                  font-weight: 500;

                  .van-icon {
                    font-size: 14px;
                  }
                }
              }

              .reject-reason {
                padding: 12px;
                background: #fff5f5;
                border-radius: 8px;
                margin-top: 12px;
                position: relative;

                .label {
                  font-size: 13px;
                  color: #ff4d4f;
                  font-weight: 500;
                  margin-right: 4px;
                }

                .value {
                  font-size: 13px;
                  color: #666;
                  line-height: 1.5;
                }

                .resubmit-btn {
                  position: absolute;
                  right: 12px;
                  top: 50%;
                  transform: translateY(-50%);
                  padding: 4px 12px;
                  background: #ff4d4f;
                  color: #fff;
                  font-size: 12px;
                  border-radius: 4px;
                  cursor: pointer;

                  &:active {
                    opacity: 0.8;
                  }
                }
              }
            }

            &:last-child {
              margin-bottom: 0;
              
              .time-line .line {
                display: none;
              }
            }
          }
        }
      }
    }
  }
}

// 浮动签课按钮样式
.quick-sign {
  position: fixed;
  right: 20px;
  bottom: 40px;
  width: 120px;
  height: 44px;
  background: linear-gradient(135deg, #29b5a5 0%, #00c9a4 100%);
  border-radius: 22px;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 4px 12px rgba(0,201,164,0.2);
  transition: all 0.3s;
  z-index: 99;

  .van-icon {
    font-size: 18px;
    color: #fff;
    margin-right: 4px;
  }

  text {
    color: #fff;
    font-size: 14px;
    font-weight: 500;
  }

  &:active {
    transform: scale(0.95);
  }
}

// 签课弹窗样式
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