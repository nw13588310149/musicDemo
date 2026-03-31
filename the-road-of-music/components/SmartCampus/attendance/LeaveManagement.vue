<template>
  <view class="leave-management">
    <view class="leave-header">
      <view class="header-left">
        <view class="filter-tabs">
          <view 
            class="tab-item" 
            v-for="option in leaveStatusOptions" 
            :key="option.value"
            :class="{ active: leaveStatus === option.value }"
            @click="leaveStatus = option.value"
          >
            {{option.text}}
            <text class="count" v-if="getStatusCount(option.value)">
              {{getStatusCount(option.value)}}
            </text>
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
</template>

<script setup>
import { ref, computed, watch } from 'vue';
import { showToast, showDialog } from 'vant';
import dayjs from 'dayjs';
import { teacherStudentLeaveList, teacherStudentLeaveAudit } from '/api/home.js';

const props = defineProps({
  classId: {
    type: [String, Number],
    required: true
  }
});

// 状态选项
const leaveStatusOptions = [
  { text: '全部', value: 'all' },
  { text: '待审批', value: 'pending' },
  { text: '已批准', value: 'approved' },
  { text: '已拒绝', value: 'rejected' }
];

// 组件状态
const leaveStatus = ref('all');
const leaveList = ref([]);
const current = ref(1);
const size = ref(10);

// 计算属性
const filteredLeaveList = computed(() => {
  if (leaveStatus.value === 'all') return leaveList.value;
  return leaveList.value.filter(item => item.status === leaveStatus.value);
});

// 获取请假记录
const getLeaveList = async () => {
  try {
    const params = {
      classId: props.classId,
      current: current.value,
      size: size.value,
      status: leaveStatus.value === 'all' ? undefined : getStatusCode(leaveStatus.value)
    };
    
    const res = await teacherStudentLeaveList(params);
    if (res.code === 0) {
      leaveList.value = res.data.map(item => ({
        id: item.id,
        studentId: item.studentId,
        studentName: item.studentId,
        studentHead: '/static/assets/head.jpg',
        type: item.type === 1 ? 'sick' : 'personal',
        startTime: item.startTime,
        endTime: item.endTime,
        reason: item.leaveReason,
        status: getStatusValue(item.status),
        createTime: item.createTime,
        auditReason: item.auditReason
      }));
    } else {
      showToast(res.msg || '获取请假记录失败');
    }
  } catch (error) {
    console.error('获取请假记录失败:', error);
    showToast('获取请假记录失败');
  }
};

// 处理请假申请
const handleLeave = async (leaveId, action) => {
  const actionText = action === 'approve' ? '批准' : '拒绝';
  try {
    await showDialog({
      title: `${actionText}请假`,
      message: `确定要${actionText}这条请假申请吗？`,
      confirmButtonText: '确定',
      confirmButtonColor: action === 'approve' ? '#00c9a4' : '#ff4d4f'
    });
    
    const res = await teacherStudentLeaveAudit({
      id: leaveId,
      status: action === 'approve' ? 1 : 2,
      auditReason: ''
    });
    
    if (res.code === 0) {
      showToast({
        type: 'success',
        message: `已${actionText}`
      });
      getLeaveList();
    } else {
      showToast(res.msg || '处理失败');
    }
  } catch (error) {
    if (error.toString().includes('cancel')) return;
    console.error('处理请假失败:', error);
    showToast('处理失败');
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

// 状态码转换
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

// 监听状态变化
watch(leaveStatus, () => {
  current.value = 1;
  getLeaveList();
});

// 初始化
onMounted(() => {
  getLeaveList();
});
</script>

<style lang="scss" scoped>
.leave-management {
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
</style> 