<template>
  <view class="student-attendance">
    <!-- 头部统计卡片 -->
    <view class="stat-cards">
      <view class="stat-card">
        <text class="value success">{{attendanceRecords.sum.status0Count}}</text>
        <text class="label">出勤</text>
      </view>
      <view class="stat-card">
        <text class="value warning">{{attendanceRecords.sum.status1Count}}</text>
        <text class="label">迟到</text>
      </view>
      <view class="stat-card">
        <text class="value danger">{{attendanceRecords.sum.status2Count}}</text>
        <text class="label">缺勤</text>
      </view>
      <view class="stat-card">
        <text class="value info">{{attendanceRecords.sum.status3Count}}</text>
        <text class="label">请假</text>
      </view>
    </view>

    <!-- 操作栏 -->
    <view class="action-bar">
      <text class="title"></text>
      <van-button 
        round 
        type="primary" 
        size="small"
        color="#00c9a4"
        @click="showLeaveForm = true"
      >
        申请请假
      </van-button>
    </view>

    <!-- 标签 -->
    <van-tabs v-model:active="activeTab" color="#00c9a4">
      <van-tab name="attendance" title="考勤记录">
        <van-pull-refresh v-model="refreshing" @refresh="onRefresh">
          <!-- 添加调试信息 -->
          <view v-if="loading">加载中...</view>
          <view v-else-if="attendanceRecords.list.length === 0">
            <van-empty description="暂无考勤记录" />
          </view>
          <view v-else class="record-list">
            <view 
              class="record-item"
              v-for="record in attendanceRecords.list"
              :key="record.id"
            >
              <view class="record-header">
                <view class="date-info">
                  <text class="date">{{formatDateTime(record.createTime)}}</text>
                </view>
                <view class="status-tag" :class="'v'+record.status">
                  {{getStatusText(record.status)}}
                </view>
              </view>
              <view class="record-content">
                <view class="course-info">
                  <text class="label">课程:</text>
                  <text class="value">{{record.subject.name}}</text>
                </view>
                <view class="teacher-info">
                  <text class="label">教师:</text>
                  <text class="value">{{record.teacher.realname}}</text>
                </view>
              </view>
              <view class="detail" v-if="record.reason">
                <text class="label">请假原因：</text>
                <text class="text">{{record.reason}}</text>
              </view>
            </view>
          </view>
          
          <!-- 分页加载 -->
          <van-loading v-if="loading" />
          <view v-if="!loading && hasMore" class="load-more" @click="loadMore">
            加载更多
          </view>
          <view v-if="!loading && !hasMore && attendanceRecords.list.length > 0" class="no-more">
            没有更多数据了
          </view>
        </van-pull-refresh>
      </van-tab>
      
      <van-tab name="leave" title="请假记录">
        <van-pull-refresh v-model="refreshing" @refresh="() => fetchLeaveRecords(true)">
          <view class="record-list">
            <view 
              class="record-item"
              v-for="record in leaveRecords.list"
              :key="record.id"
            >
              <view class="record-header">
                <view class="date-info">
                  <text class="date">{{formatDateTime(record.createTime)}}</text>
                </view>
                <view class="status-tag" :class="getLeaveStatusClass(record.status)">
                  {{getLeaveStatusText(record.status)}}
                </view>
              </view>
              <view class="record-content">
                <view class="time-info">
                  <text class="label">请假时间:</text>
                  <text class="value">{{formatDateTime(record.startTime)}} 至 {{formatDateTime(record.endTime)}}</text>
                </view>
                <view class="type-info">
                  <text class="label">请假类型:</text>
                  <text class="value">{{record.type === 0 ? '病假' : '事假'}}</text>
                </view>
              </view>
              <view class="detail">
                <text class="label">请假原因：</text>
                <text class="text">{{record.leaveReason}}</text>
              </view>
              <view class="detail" v-if="record.auditReason">
                <text class="label">审核意见：</text>
                <text class="text">{{record.auditReason}}</text>
              </view>
            </view>
            <van-empty v-if="!leaveRecords.list.length" description="暂无请假记录" />
          </view>
          
          <!-- 分页加载 -->
          <van-loading v-if="leaveRecords.loading" />
          <view v-if="!leaveRecords.loading && leaveRecords.hasMore" class="load-more" @click="loadMoreLeave">
            加载更多
          </view>
          <view v-if="!leaveRecords.loading && !leaveRecords.hasMore" class="no-more">
            没有更多数据了
          </view>
        </van-pull-refresh>
      </van-tab>
    </van-tabs>

    <!-- 请假表单弹窗 -->
    <van-popup
      v-model:show="showLeaveForm" 
      round
      position="bottom"
      :style="{ height: '70%' }"
    >
      <view class="leave-form">
        <view class="form-header">
          <text class="title">请假申请</text>
          <van-icon name="cross" @click="showLeaveForm = false" />
        </view>
        <view class="form-content" style="overflow: hidden;">
          <view class="form-item">
            <text class="label">请假类型</text>
            <van-radio-group v-model="leaveForm.type" direction="horizontal">
              <van-radio name="sick" checked-color="#00c9a4">病假</van-radio>
              <van-radio name="personal" checked-color="#00c9a4">事假</van-radio>
            </van-radio-group>
          </view>
          <view class="form-item">
            <text class="label">开始时间</text>
            <view class="date-picker" @click="showStartPicker = true">
              {{leaveForm.startTime || '请选择开始时间'}}
            </view>
          </view>
          <view class="form-item">
            <text class="label">结束时间</text>
            <view class="date-picker" @click="showEndPicker = true">
              {{leaveForm.endTime || '请选择结束时间'}}
            </view>
          </view>
          <view class="form-item">
            <text class="label">请假原因</text>
            <textarea
              v-model="leaveForm.reason"
              class="reason-input"
              placeholder="请输入请假原因（必填）"
            />
          </view>
        </view>
        <view class="form-footer">
          <van-button 
            round 
            block 
            type="primary" 
            color="#00c9a4"
            @click="submitLeave"
          >
            提交申请
          </van-button>
        </view>
      </view>
    </van-popup>

    <!-- 添加开始时间选择器弹窗 -->
    <van-popup v-model:show="showStartPicker" round position="bottom">
      <van-picker-group
        title="开始时间"
        :tabs="['日期', '时间']"
        @confirm="onStartTimeConfirm"
        @cancel="showStartPicker = false"
      >
        <van-date-picker
          v-model="startDate"
          :min-date="minDate"
          :max-date="maxDate"
        />
        <van-time-picker
          v-model="startTime"
          :min-hour="0"
          :max-hour="23"
        />
      </van-picker-group>
    </van-popup>

    <!-- 添加结束时间选择器弹窗 -->
    <van-popup v-model:show="showEndPicker" round position="bottom">
      <van-picker-group
        title="结束时间"
        :tabs="['日期', '时间']"
        @confirm="onEndTimeConfirm"
        @cancel="showEndPicker = false"
      >
        <van-date-picker
          v-model="endDate"
          :min-date="getMinEndDate"
          :max-date="maxDate"
        />
        <van-time-picker
          v-model="endTime"
          :min-hour="0"
          :max-hour="23"
        />
      </van-picker-group>
    </van-popup>
  </view>
</template>

<script setup>
import { ref, onMounted, watch, computed } from 'vue';
import { showToast } from 'vant';
import dayjs from 'dayjs';
import { studentSignInList, studentLeaveSave, studentLeaveList} from '../../api/home.js';

// 考勤记录分页相关
const page = ref(1);
const pageSize = ref(20);
const total = ref(0);
const loading = ref(false);
const hasMore = ref(true);

// 考勤记录列表
const attendanceRecords = ref({
  list: [],
  sum: {
    status0Count: 0,
    status1Count: 0,
    status2Count: 0,
    status3Count: 0
  }
});

// 请假表单
const showLeaveForm = ref(false);
const leaveForm = ref({
  type: 'sick',
  startTime: '',
  endTime: '',
  reason: ''
});

// 刷新相关
const refreshing = ref(false);

// 时间选择相关
const showStartPicker = ref(false);
const showEndPicker = ref(false);
const startDate = ref(['2024', '03', '21']); // 默认当前日期
const startTime = ref(['12', '00']); // 默认12:00
const endDate = ref(['2024', '03', '21']);
const endTime = ref(['12', '00']);
const minDate = new Date();
const maxDate = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // 30天后

// 获取状态文本
const getStatusText = (status) => {
  const statusMap = {
    0: '已到',
    1: '迟到',
    2: '缺勤',
    3: '请假'
  };
  return statusMap[status] || status;
};

// 获取考勤记录
const fetchAttendanceRecords = async (isRefresh = false) => {
  if(isRefresh) {
    page.value = 1;
    attendanceRecords.value.list = [];
  }
  
  loading.value = true;
  try {
    const params = {
      current: page.value,
      size: pageSize.value
    };
    
    const res = await studentSignInList(params);
    console.log('考勤记录返回数据:', res); // 添加日志查看返回数据结构
    
    if(res.code === 0) {
      const records = res.data?.records || res.data?.list || [];
      const summary = res.data?.sum || res.data?.summary || {
        status0Count: 0,
        status1Count: 0,
        status2Count: 0,
        status3Count: 0
      };
      
      if(isRefresh) {
        attendanceRecords.value.list = records;
      } else {
        attendanceRecords.value.list.push(...records);
      }
      
      // 更新统计数据
      attendanceRecords.value.sum = {
        status0Count: parseInt(summary.status0Count || 0),
        status1Count: parseInt(summary.status1Count || 0),
        status2Count: parseInt(summary.status2Count || 0),
        status3Count: parseInt(summary.status3Count || 0)
      };
      
      total.value = res.data?.total || 0;
      hasMore.value = records.length === pageSize.value;
    } else {
      showToast(res.msg || '获取考勤记录失败');
    }
  } catch(error) {
    console.error('获取考勤记录失败:', error);
    showToast('获取考勤记录失败');
  } finally {
    loading.value = false;
    if(isRefresh) {
      refreshing.value = false;
    }
  }
};

// 加载更多
const loadMore = () => {
  if(loading.value || !hasMore.value) return;
  page.value++;
  fetchAttendanceRecords();
};

// 下拉刷新
const onRefresh = async () => {
  refreshing.value = true;
  try {
    await fetchAttendanceRecords(true);
  } finally {
    refreshing.value = false;
  }
};

// 时确认处理函数
const onStartTimeConfirm = () => {
  const dateStr = startDate.value.join('-');
  const timeStr = startTime.value.join(':');
  leaveForm.value.startTime = `${dateStr} ${timeStr}`;
  showStartPicker.value = false;
};

const onEndTimeConfirm = () => {
  const dateStr = endDate.value.join('-');
  const timeStr = endTime.value.join(':');
  leaveForm.value.endTime = `${dateStr} ${timeStr}`;
  showEndPicker.value = false;
};

// 重置表单时需要清空时间
const resetLeaveForm = () => {
  leaveForm.value = {
    type: 'sick',
    startTime: '',
    endTime: '',
    reason: ''
  };
  // 重置时间选择器的值为当前时间
  const now = dayjs();
  startDate.value = [now.format('YYYY'), now.format('MM'), now.format('DD')];
  startTime.value = [now.format('HH'), now.format('mm')];
  endDate.value = [now.format('YYYY'), now.format('MM'), now.format('DD')];
  endTime.value = [now.format('HH'), now.format('mm')];
};

// 关闭弹窗时重置表单
watch(showLeaveForm, (newVal) => {
  if (!newVal) {
    resetLeaveForm();
  }
});

// 添加时间格式化函数
const formatter = (type, val) => {
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

// 计算结束时间的最小日期
const getMinEndDate = computed(() => {
  if (startDate.value && startDate.value.length === 3) {
    return new Date(
      parseInt(startDate.value[0]),
      parseInt(startDate.value[1]) - 1,
      parseInt(startDate.value[2])
    );
  }
  return minDate;
});

// 监听开始时间变化，更新结束时间
watch(startDate, (newVal) => {
  if (newVal) {
    const startDateObj = new Date(
      parseInt(newVal[0]),
      parseInt(newVal[1]) - 1,
      parseInt(newVal[2])
    );
    const endDateObj = new Date(
      parseInt(endDate.value[0]),
      parseInt(endDate.value[1]) - 1,
      parseInt(endDate.value[2])
    );
    
    // 如果结束日期小于开始日期，则将结束日期设置为开始日期
    if (endDateObj < startDateObj) {
      endDate.value = [...newVal];
    }
  }
});

// 提交请假申请
const submitLeave = async () => {
  // 表单验证
  if (!leaveForm.value.startTime) {
    showToast('请选择开始时间');
    return;
  }
  if (!leaveForm.value.endTime) {
    showToast('请选择结束时间');
    return;
  }
  if (!leaveForm.value.reason) {
    showToast('请输入请假原因');
    return;
  }

  try {
    const params = {
      startTime: dayjs(leaveForm.value.startTime).format('YYYY-MM-DD HH:mm:ss'),
      endTime: dayjs(leaveForm.value.endTime).format('YYYY-MM-DD HH:mm:ss'),
      leaveReason: leaveForm.value.reason,
      type: leaveForm.value.type === 'sick' ? 0 : 1
    };

    const res = await studentLeaveSave(params);
    if (res.code === 0) {
      showToast({
        type: 'success',
        message: '请假申请提交成功'
      });
      showLeaveForm.value = false; // 关闭弹窗
      fetchAttendanceRecords(true); // 刷新列表
    } else {
      showToast(res.msg || '提交失败');
    }
  } catch (error) {
    console.error('提交请假申请失败:', error);
    showToast('提交请假申请失败，请重试');
  }
};

// 添加请假记录列表相关数据
const leaveRecords = ref({
  list: [],
  loading: false,
  hasMore: true,
  page: 1,
  pageSize: 20
});

// 获取请假记录
const fetchLeaveRecords = async (isRefresh = false) => {
  if(isRefresh) {
    leaveRecords.value.page = 1;
    leaveRecords.value.list = [];
  }
  
  leaveRecords.value.loading = true;
  try {
    const params = {
      current: leaveRecords.value.page,
      size: leaveRecords.value.pageSize
    };
    
    const res = await studentLeaveList(params);
    if(res.code === 0) {
      const records = Array.isArray(res.data) ? res.data : [];
      
      if(isRefresh) {
        leaveRecords.value.list = records;
      } else {
        leaveRecords.value.list.push(...records);
      }
      
      // 根据返回数据长度判断是否还有更多
      leaveRecords.value.hasMore = records.length === leaveRecords.value.pageSize;
    } else {
      showToast(res.msg || '获取请假记录失败');
    }
  } catch(error) {
    console.error('获取请假记录失败:', error);
    showToast('获取请假记录失败');
  } finally {
    leaveRecords.value.loading = false;
  }
};

// 加载更多请假记录
const loadMoreLeave = () => {
  if(leaveRecords.value.loading || !leaveRecords.value.hasMore) return;
  leaveRecords.value.page++;
  fetchLeaveRecords();
};

// 修改 template 部分，在 action-bar 下方添加标签页
const activeTab = ref('attendance'); // 'attendance' 或 'leave'

// 添加请假记录状态相关函数
const getLeaveStatusText = (status) => {
  const statusMap = {
    0: '待审核',
    1: '已通过',
    2: '已拒绝'
  };
  return statusMap[status] || status;
};

const getLeaveStatusClass = (status) => {
  const classMap = {
    0: 'v-pending',
    1: 'v-approved',
    2: 'v-rejected'
  };
  return classMap[status] || '';
};

// 监听标签切换
watch(activeTab, (newVal) => {
  if(newVal === 'leave' && !leaveRecords.value.list.length) {
    fetchLeaveRecords(true);
  }
});

// 添加时间格式化函数
const formatDateTime = (dateTimeStr) => {
  if (!dateTimeStr) return '';
  return dayjs(dateTimeStr).format('YYYY-MM-DD HH:mm');
};

onMounted(async () => {
  console.log('组件挂载，开始获取考勤记录');
  await fetchAttendanceRecords(true);
});
</script>

<style lang="scss" scoped>
.student-attendance {
  height: 100%;
  background: #fff;
  padding: 16px;
  display: flex;
  flex-direction: column;

  .stat-cards {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 12px;
    margin-bottom: 16px;

    .stat-card {
      background: #fff;
      padding: 16px;
      border-radius: 12px;
      text-align: center;
      box-shadow: 0 2px 8px rgba(0,0,0,0.05);

      .value {
        display: block;
        font-size: 24px;
        font-weight: 500;
        margin-bottom: 4px;

        &.success { color: #00c9a4; }
        &.warning { color: #faad14; }
        &.danger { color: #ff4d4f; }
        &.info { color: #1890ff; }
      }

      .label {
        font-size: 13px;
        color: #666;
      }
    }
  }

  ::v-deep .van-tabs__content{
    height: calc(100% - 290px);
    min-height: 300px;
    overflow: auto;
    &::-webkit-scrollbar {
      display: none;
    }
    -ms-overflow-style: none;  /* IE and Edge */
    scrollbar-width: none;  /* Firefox */
  }
  .action-bar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 16px;
    padding: 0 4px;

    .title {
      font-size: 16px;
      font-weight: 500;
      color: #333;
    }
  }

  .record-list {
    flex: 1;
    overflow-y: auto;

    .record-item {
      background: #fff;
      border-radius: 12px;
      padding: 16px;
      margin-bottom: 12px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.05);

      .record-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 12px;

        .date-info {
          .date {
            font-size: 15px;
            font-weight: 500;
            color: #333;
            margin-right: 8px;
          }

          .time {
            font-size: 13px;
            color: #666;
          }
        }
      }

      .record-content {
        background: #f8f9fa;
        padding: 12px;
        border-radius: 8px;
        margin-bottom: 12px;

        .course-info,
        .teacher-info {
          display: flex;
          align-items: center;
          margin-bottom: 8px;

          &:last-child {
            margin-bottom: 0;
          }

          .label {
            font-size: 13px;
            color: #666;
            margin-right: 8px;
            width: 42px;
          }

          .value {
            font-size: 14px;
            color: #333;
          }
        }
      }

      .status-tag {
        display: inline-block;
        padding: 4px 12px;
        border-radius: 4px;
        font-size: 12px;
        margin-bottom: 8px;

        &.v0 {
          background: #e6f7f4;
          color: #00c9a4;
        }

        &.v1 {
          background: #fff7e6;
          color: #faad14;
        }

        &.v2 {
          background: #fff1f0;
          color: #ff4d4f;
        }

        &.v3 {
          background: #e6f7ff;
          color: #1890ff;
        }
      }

      .detail {
        background: #f8f9fa;
        padding: 12px;
        border-radius: 8px;

        .label {
          font-size: 13px;
          color: #666;
        }

        .text {
          font-size: 14px;
          color: #333;
        }
      }
    }
  }

  .leave-form {
    height: 100%;
    display: flex;
    flex-direction: column;

    .form-header {
      padding: 16px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      border-bottom: 1px solid #eee;

      .title {
        font-size: 16px;
        font-weight: 500;
      }
    }

    .form-content {
      flex: 1;
      padding: 16px;
      overflow-y: auto;

      .form-item {
        margin-bottom: 20px;

        .label {
          display: block;
          font-size: 14px;
          color: #333;
          margin-bottom: 8px;
        }

        .date-picker {
          background: #f6f7fb;
          padding: 12px;
          border-radius: 8px;
          font-size: 14px;
          color: #333;
        }

        .reason-input {
          width: 100%;
          height: 120px;
          padding: 12px;
          border: 1px solid #eee;
          border-radius: 8px;
          font-size: 14px;
          resize: none;

          &:focus {
            border-color: #00c9a4;
            outline: none;
          }
        }
      }
    }

    .form-footer {
      padding: 16px;
      border-top: 1px solid #eee;
    }
  }

  .load-more {
    text-align: center;
    padding: 16px;
    color: #00c9a4;
    font-size: 14px;
  }

  .no-more {
    text-align: center;
    padding: 16px;
    color: #999;
    font-size: 14px;
  }
}

:deep(.van-datetime-picker) {
  .van-picker__title {
    font-size: 16px;
    font-weight: 500;
  }
  
  .van-picker-column__item {
    font-size: 16px;
  }
}

:deep(.van-popup) {
  border-radius: 16px 16px 0 0;
}

// 添加日期选择器相关样式
.date-picker {
  background: #f6f7fb;
  padding: 12px;
  border-radius: 8px;
  font-size: 14px;
  color: #333;
  cursor: pointer;
}

:deep(.van-picker) {
  .van-picker__title {
    font-size: 16px;
    font-weight: 500;
  }
  
  .van-picker__cancel,
  .van-picker__confirm {
    background: #ddd;
    border-radius: 50px;
    height: 30px;
    margin: 10px;
  }
  
  .van-picker__cancel {
    background: #E0F8F1;
    color: #2CCDA1;
  }
  
  .van-picker__confirm {
    background: #2CCDA1;
    color: #fff !important;
  }
}

:deep(.van-tabs__line) {
  background: #2CCDA1;
  height: 4px;
  width: 30px;
}

// 添加新的状态样式
.status-tag {
  &.v-pending {
    background: #e6f7ff;
    color: #1890ff;
  }
  
  &.v-approved {
    background: #e6f7f4;
    color: #00c9a4;
  }
  
  &.v-rejected {
    background: #fff1f0;
    color: #ff4d4f;
  }
}

.time-info,
.type-info {
  display: flex;
  align-items: center;
  margin-bottom: 8px;

  &:last-child {
    margin-bottom: 0;
  }

  .label {
    font-size: 13px;
    color: #666;
    margin-right: 8px;
    width: 70px;
  }

  .value {
    font-size: 14px;
    color: #333;
  }
}
</style> 