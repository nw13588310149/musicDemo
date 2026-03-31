<template>
  <view class="sign-approvals">
    <van-loading v-if="loading" type="spinner" vertical>加载中...</van-loading>
    <template v-else>
      <!-- 主体内容区 -->
      <view class="content">
        <!-- 班级选择和日期范围 -->
        <view class="header">
          <view class="class-select" v-if="classAll?.length > 1" @click="handleShowPicker">
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

        <!-- 状态筛选 -->
        <view class="filter-section">
          <view class="filter-tabs">
            <view 
              class="tab-item" 
              :class="{ active: status === item.value }"
              v-for="item in statusOptions" 
              :key="item.value"
              @click="handleStatusChange(item.value)"
            >
              {{item.label}}
            </view>
          </view>
        </view>

        <!-- 审批列表 -->
        <van-pull-refresh v-model="refreshing" @refresh="onRefresh">
          <view class="approval-list" :class="{ 'list-loading': listLoading }">
            <view class="loading-wrapper" v-if="listLoading" style="display: flex; justify-content: center; align-items: center; width: 100%; padding: 20px 0;">
              <van-loading type="spinner" vertical>加载中...</van-loading>
            </view>
            <template v-else>
              <template v-if="approvalList.length > 0">
                <view 
                  class="approval-item" 
                  v-for="item in approvalList" 
                  :key="item.id"
                >
                  <view class="status-tag" :class="item.status">{{item.statusText}}</view>
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
                    <view v-if="item.status === 'rejected'" class="reject-reason">
                      <text class="label">驳回原因：</text>
                      <text class="text">{{item.rejectReason}}</text>
                    </view>
                  </view>
                  
                  <view class="actions" v-if="item.status === 'pending'">
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
              <van-empty v-else description="暂无审批记录" />
            </template>
          </view>
        </van-pull-refresh>

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
      </view>
    </template>
  </view>
</template>

<style lang="scss" scoped>
.sign-approvals {
  height: 100%;
  
  .content {
    height: 100%;
    padding: 16px;
    display: flex;
    flex-direction: column;

    .header {
      margin-bottom: 16px;

      .class-select {
        display: inline-flex;
        align-items: center;
        padding: 8px 16px;
        background: #fff;
        border-radius: 8px;
        cursor: pointer;
        transition: all 0.3s;
        margin-bottom: 12px;
        box-shadow: 0 2px 12px rgba(0,0,0,0.05);

        text {
          font-size: 15px;
          color: #333;
          margin-right: 4px;
        }

        .van-icon {
          font-size: 14px;
          color: #999;
        }

        &:hover {
          background: #f8f9fa;
        }
      }

      .date-range {
        display: flex;
        gap: 12px;

        .van-button {
          flex: 1;
          height: 32px;
          font-size: 14px;
          background: #fff;
          border: none;
          box-shadow: 0 2px 12px rgba(0,0,0,0.05);

          &--primary {
            font-weight: 500;
            background: #00c9a4;
            color: #fff;
          }
        }
      }
    }

    .date-filter {
      background: #fff;
      border-radius: 12px;
      margin-bottom: 16px;
      box-shadow: 0 2px 12px rgba(0,0,0,0.05);
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
            background: #f8f9fa;
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

    .filter-section {
      margin-bottom: 16px;

      .filter-tabs {
        display: flex;
        gap: 12px;
        background: #fff;
        border-radius: 12px;
        padding: 16px;
        box-shadow: 0 2px 12px rgba(0,0,0,0.05);

        .tab-item {
          flex: 1;
          height: 36px;
          display: flex;
          align-items: center;
          justify-content: center;
          background: #f8f9fa;
          border-radius: 18px;
          font-size: 14px;
          color: #666;
          cursor: pointer;
          transition: all 0.3s;

          &.active {
            background: #00c9a4;
            color: #fff;
          }

          &:hover:not(.active) {
            background: #f0f3f8;
          }
        }
      }
    }

    .approval-list {
      flex: 1;
      overflow-y: auto;
      padding: 0 4px;
      position: relative;

      &.list-loading {
        display: flex;
        align-items: center;
        justify-content: center;
      }

      .approval-item {
        background: #fff;
        border-radius: 12px;
        padding: 16px;
        margin-bottom: 16px;
        box-shadow: 0 2px 12px rgba(0,0,0,0.03);
        transition: all 0.3s;

        &:hover {
          transform: translateY(-2px);
          box-shadow: 0 4px 16px rgba(0,0,0,0.06);
        }

        .status-tag {
          display: inline-block;
          padding: 4px 12px;
          border-radius: 4px;
          font-size: 12px;
          margin-bottom: 12px;

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

        .teacher-info {
          display: flex;
          align-items: center;
          margin-bottom: 12px;

          .info {
            margin-left: 12px;

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
        }

        .sign-info {
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
            background: #fff;
            padding: 12px;
            border-radius: 8px;
            margin-bottom: 12px;

            .label {
              font-size: 13px;
              color: #666;
            }

            .text {
              font-size: 14px;
              color: #333;
              line-height: 1.5;
            }
          }

          .reject-reason {
            background: #fff5f5;
            padding: 12px;
            border-radius: 8px;

            .label {
              font-size: 13px;
              color: #ff4d4f;
              font-weight: 500;
            }

            .text {
              font-size: 13px;
              color: #666;
              line-height: 1.5;
            }
          }
        }

        .actions {
          display: flex;
          justify-content: flex-end;
          gap: 12px;
          margin-top: 16px;

          .van-button {
            min-width: 80px;
          }
        }
      }
    }
  }

  .reject-dialog-content {
    padding: 16px;

    .reject-reason-input {
      width: 100%;
      height: 100px;
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
</style>

<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { showToast } from 'vant';
import dayjs from 'dayjs';
import { 
  headTeacherSignInList,
  headTeacherSignInAudit,
  classList 
} from '/api/home.js';

const router = useRouter();
const route = useRoute();

// 状态筛选选项
const statusOptions = [
  { label: '全部', value: -1 },
  { label: '待审批', value: 0 },
  { label: '已通过', value: 1 },
  { label: '已驳回', value: 2 }
];

// 筛选条件
const status = ref(0); // 默认显示待审批
const dateRange = ref({
  start: dayjs().subtract(30, 'day').format('YYYY-MM-DD'),
  end: dayjs().format('YYYY-MM-DD')
});

// 驳回相关
const showRejectReason = ref(false);
const rejectReason = ref('');
const currentApproval = ref(null);

// 添加班级选择相关数据
const showPicker = ref(false);
const columns = ref([]);
const classAll = ref([]);
const activeClass = ref({});

// 加载状态
const loading = ref(false);
const refreshing = ref(false);

// 审批列表数据
const approvalList = ref([]);
const pagination = ref({
  current: 1,
  size: 10,
  total: 0
});

// 时间范围
const timeRange = ref('本月');
const timeRanges = ['本周', '本月'];

// 日期选择相关
const showStartCalendar = ref(false);
const showEndCalendar = ref(false);
const minDate = ref(new Date(2020, 0, 1));
const maxDate = ref(new Date(2025, 11, 31));

// 添加列表加载状态
const listLoading = ref(false);

// 修改状态切换处理函数
const handleStatusChange = async (newStatus) => {
  if (status.value === newStatus) return;
  
  listLoading.value = true;
  status.value = newStatus;
  
  try {
    await fetchApprovalList();
  } finally {
    listLoading.value = false;
  }
};

// 修改获取审批列表函数
const fetchApprovalList = async () => {
  try {
    const params = {
      beginDate: dateRange.value.start,
      endDate: dateRange.value.end,
      classId: activeClass.value?.id || undefined,
      current: pagination.value.current,
      size: pagination.value.size,
      status: status.value === -1 ? undefined : status.value
    };

    const res = await headTeacherSignInList(params);
    if (res.code === 0) {
      approvalList.value = (res.data.list || []).map(item => ({
        id: item.id,
        teacherName: item.teacher?.realname || item.teacher?.nickname || '未知教师',
        teacherAvatar: item.teacher?.headUrl || '/static/assets/head.jpg',
        subject: item.subject?.name || '未知科目',
        signTime: item.courseTime || item.createTime,
        hours: item.lessonCount || 0,
        content: item.description || '',
        className: item.schoolClass?.name || '未知班级',
        status: getStatusType(item.status),
        statusText: getStatusText(item.status),
        rejectReason: item.reason
      }));

      pagination.value = {
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

// 监听器，移除全局loading
watch([dateRange, () => activeClass.value?.id], () => {
  listLoading.value = true;
  fetchApprovalList().finally(() => {
    listLoading.value = false;
  });
}, { deep: true });

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
  // 更新列表数据
  fetchApprovalList();
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
  // 更新列表数据
  fetchApprovalList();
};

// 获取班级列表
const initClassList = async () => {
  try {
    const res = await classList();
    if (res.code === 0 && res.data.length > 0) {
      classAll.value = res.data;
      
      // 更新选择器的列选项
      columns.value = res.data.map(item => ({
        text: item.name,
        value: item.id
      }));
      
      // 设置默认班级
      const defaultClass = uni.getStorageSync('defaultClass');
      if (defaultClass) {
        const parsedClass = JSON.parse(defaultClass);
        const existingClass = res.data.find(item => item.id === parsedClass.id);
        if (existingClass) {
          activeClass.value = existingClass;
        } else {
          activeClass.value = res.data[0];
          uni.setStorageSync('defaultClass', JSON.stringify(res.data[0]));
        }
      } else {
        activeClass.value = res.data[0];
        uni.setStorageSync('defaultClass', JSON.stringify(res.data[0]));
      }
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
  // 重新获取列表数据
  fetchApprovalList();
};

// 修改班级选择器的显示逻辑
const handleShowPicker = async () => {
  if (classAll.value.length === 0) {
    await initClassList();
  }
  showPicker.value = true;
};

// 获取状态类型
const getStatusType = (status) => {
  switch (status) {
    case 0: return 'pending';
    case 1: return 'approved';
    case 2: return 'rejected';
    default: return 'pending';
  }
};

// 获取状态文本
const getStatusText = (status) => {
  switch (status) {
    case 0: return '待审批';
    case 1: return '已通过';
    case 2: return '已驳回';
    default: return '待审批';
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
      fetchApprovalList();
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

// 显示驳回对话框
const showRejectDialog = (item) => {
  currentApproval.value = item;
  rejectReason.value = '';
  showRejectReason.value = true;
};

// 下拉刷新
const onRefresh = async () => {
  refreshing.value = true;
  await fetchApprovalList();
};

onMounted(async () => {
  loading.value = true;
  try {
    // 获取路由参数
    const { classId, timeRange: routeTimeRange, dateRange: routeDateRange } = route.query;
    
    // 初始化班级列表
    await initClassList();
    
    // 如果有传入的班级ID，则设置当前班级
    if (classId) {
      const targetClass = classAll.value.find(item => item.id === classId);
      if (targetClass) {
        activeClass.value = targetClass;
        uni.setStorageSync('defaultClass', JSON.stringify(targetClass));
      }
    }
    
    // 如果有传入的时间范围，则使用传入的值
    if (routeTimeRange) {
      timeRange.value = routeTimeRange;
    }
    
    // 如果有传入的日期范围，则使用传入的值
    if (routeDateRange) {
      try {
        const parsedDateRange = typeof routeDateRange === 'object' ? routeDateRange : JSON.parse(routeDateRange);
        dateRange.value = parsedDateRange;
      } catch (error) {
        console.error('解析日期范围失败:', error);
      }
    }
    
    // 获取审批列表
    await fetchApprovalList();
  } catch (error) {
    console.error('初始化失败:', error);
    showToast('初始化失败');
  } finally {
    loading.value = false;
  }
});
</script> 