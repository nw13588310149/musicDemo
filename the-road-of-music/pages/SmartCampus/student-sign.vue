<template>
  <view class="student-sign">
    <van-loading v-if="loading" type="spinner" vertical>加载中...</van-loading>
    <template v-else>
      <!-- 今日课程签到区域 -->
      <view class="section today-classes">
        <view class="section-header">
          <text class="title">今日课程</text>
          <view class="date">{{ formatDate(new Date()) }}</view>
        </view>
        
        <view class="class-list" v-if="todayClasses.length > 0">
          <view 
            class="class-card" 
            v-for="item in todayClasses" 
            :key="item.id"
            :class="{ 
              'signed': item.signStatus === 'completed',
              'in-progress': item.signStatus === 'in-progress'
            }"
          >
            <view class="class-info">
              <view class="subject">{{ item.subjectName }}</view>
              <view class="time">{{ formatTime(item.startTime) }} - {{ formatTime(item.endTime) }}</view>
              <view class="teacher">授课教师：{{ item.teacherName }}</view>
            </view>
            <view class="sign-status">
              <view class="status-tag" :class="getStatusClass(item)">{{ getStatusText(item) }}</view>
              
              <!-- 开始上课按钮 -->
              <view 
                v-if="canStartClass(item)" 
                class="action-btn start-btn"
                @click="openStartClassDialog(item)"
              >
                <van-icon name="play-circle" />
                <text>开始上课</text>
              </view>
              
              <!-- 结束上课按钮 -->
              <view 
                v-if="canEndClass(item)" 
                class="action-btn end-btn"
                @click="openEndClassDialog(item)"
              >
                <van-icon name="success" />
                <text>结束上课</text>
              </view>
            </view>
          </view>
        </view>
        
        <van-empty 
          v-else 
          description="今日暂无课程安排" 
          image="/static/assets/empty_list.png" 
          :image-size="[160, 160]"
        />
      </view>
      
      <!-- 签到历史记录 -->
      <view class="section sign-history">
        <view class="section-header">
          <text class="title">签到记录</text>
          <view class="more" @click="viewAllHistory">
            查看全部<van-icon name="arrow" />
          </view>
        </view>
        
        <view class="history-list" v-if="signHistory.length > 0">
          <view 
            class="history-item" 
            v-for="item in signHistory.slice(0, 5)" 
            :key="item.id"
          >
            <view class="history-date">{{ formatDate(item.signTime) }}</view>
            <view class="history-content">
              <view class="subject">{{ item.subjectName }}</view>
              <view class="time">{{ formatTime(item.startTime) }} - {{ formatTime(item.endTime) }}</view>
              <view class="status-tag" :class="item.status">{{ item.statusText }}</view>
            </view>
          </view>
        </view>
        
        <van-empty 
          v-else 
          description="暂无签到记录" 
          image="/static/assets/empty_list.png" 
          :image-size="[160, 160]"
        />
      </view>
      
      <!-- 签到统计 -->
      <view class="section sign-stats">
        <view class="section-header">
          <text class="title">签到统计</text>
        </view>
        
        <view class="stats-cards">
          <view class="stats-card">
            <view class="value">{{ stats.totalClasses }}</view>
            <view class="label">总课程数</view>
          </view>
          <view class="stats-card">
            <view class="value">{{ stats.signedClasses }}</view>
            <view class="label">已签到</view>
          </view>
          <view class="stats-card">
            <view class="value">{{ stats.missedClasses }}</view>
            <view class="label">未签到</view>
          </view>
          <view class="stats-card">
            <view class="value">{{ stats.attendanceRate }}%</view>
            <view class="label">出勤率</view>
          </view>
        </view>
      </view>
      
      <!-- 开始上课弹窗 -->
      <van-dialog
        v-model:show="showStartClassDialog"
        title="开始上课"
        show-cancel-button
        @confirm="handleStartClass"
        :before-close="beforeDialogClose"
      >
        <view class="sign-dialog-content" v-if="currentClass">
          <view class="dialog-info">
            <view class="info-item">
              <text class="label">课程名称：</text>
              <text class="value">{{ currentClass.subjectName }}</text>
            </view>
            <view class="info-item">
              <text class="label">上课时间：</text>
              <text class="value">{{ formatTime(currentClass.startTime) }} - {{ formatTime(currentClass.endTime) }}</text>
            </view>
            <view class="info-item">
              <text class="label">授课教师：</text>
              <text class="value">{{ currentClass.teacherName }}</text>
            </view>
          </view>
          
          <view class="sign-form">
            <view class="form-item">
              <text class="label">签到备注</text>
              <textarea
                v-model="signForm.startRemark"
                placeholder="可选填写签到备注信息"
                class="remark-input"
                :maxlength="100"
              />
              <text class="word-count">{{ signForm.startRemark?.length || 0 }}/100</text>
            </view>
          </view>
        </view>
      </van-dialog>
      
      <!-- 结束上课弹窗 -->
      <van-dialog
        v-model:show="showEndClassDialog"
        title="结束上课"
        show-cancel-button
        @confirm="handleEndClass"
        :before-close="beforeDialogClose"
      >
        <view class="sign-dialog-content" v-if="currentClass">
          <view class="dialog-info">
            <view class="info-item">
              <text class="label">课程名称：</text>
              <text class="value">{{ currentClass.subjectName }}</text>
            </view>
            <view class="info-item">
              <text class="label">上课时间：</text>
              <text class="value">{{ formatTime(currentClass.startTime) }} - {{ formatTime(currentClass.endTime) }}</text>
            </view>
            <view class="info-item">
              <text class="label">授课教师：</text>
              <text class="value">{{ currentClass.teacherName }}</text>
            </view>
          </view>
          
          <view class="sign-form">
            <view class="form-item">
              <text class="label">课程总结</text>
              <textarea
                v-model="signForm.endRemark"
                placeholder="请简要总结本节课的内容和收获"
                class="remark-input"
                :maxlength="200"
              />
              <text class="word-count">{{ signForm.endRemark?.length || 0 }}/200</text>
            </view>
          </view>
        </view>
      </van-dialog>
    </template>
  </view>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue';
import { showToast } from 'vant';
import dayjs from 'dayjs';
import { getMyInfo } from '/api/home.js';
import { defineEmits } from 'vue';

const emit = defineEmits(['change-component']);

// 加载状态
const loading = ref(false);

// 用户信息
const myInfo = ref(null);

// 今日课程列表
const todayClasses = ref([]);

// 签到历史记录
const signHistory = ref([]);

// 签到统计数据
const stats = ref({
  totalClasses: 0,
  signedClasses: 0,
  missedClasses: 0,
  attendanceRate: 0
});

// 签到弹窗相关
const showStartClassDialog = ref(false);
const showEndClassDialog = ref(false);
const currentClass = ref(null);
const signForm = ref({
  startRemark: '',
  endRemark: ''
});

// 初始化数据
onMounted(async () => {
  loading.value = true;
  try {
    await loadUserInfo();
    await Promise.all([
      loadTodayClasses(),
      loadSignHistory(),
      loadSignStats()
    ]);
  } catch (error) {
    console.error('初始化数据失败:', error);
    showToast('加载数据失败，请重试');
  } finally {
    loading.value = false;
  }
});

// 加载用户信息
const loadUserInfo = async () => {
  try {
    const cachedInfo = uni.getStorageSync('my');
    if (cachedInfo) {
      myInfo.value = JSON.parse(cachedInfo);
    }
    
    const res = await getMyInfo();
    if (res.code === 0) {
      myInfo.value = res.data.user;
      uni.setStorageSync('my', JSON.stringify(res.data.user));
    }
  } catch (error) {
    console.error('获取用户信息失败:', error);
    showToast('获取用户信息失败');
  }
};

// 加载今日课程
const loadTodayClasses = async () => {
  // 获取当前时间
  const now = new Date();
  
  // 创建一个当前时间前后5分钟的时间范围，用于模拟"开始上课"按钮
  const startClassTime = new Date(now.getTime());
  startClassTime.setMinutes(now.getMinutes() - 2); // 设置为2分钟前
  
  const startClassEndTime = new Date(startClassTime.getTime());
  startClassEndTime.setHours(startClassEndTime.getHours() + 1); // 课程持续1小时
  
  // 创建一个当前时间前后5分钟的时间范围，用于模拟"结束上课"按钮
  const endClassTime = new Date(now.getTime());
  endClassTime.setHours(now.getHours() - 1); // 设置为1小时前
  
  const endClassEndTime = new Date(now.getTime());
  endClassEndTime.setMinutes(now.getMinutes() + 2); // 设置为当前时间后2分钟
  
  // 模拟数据，实际项目中应该调用API
  todayClasses.value = [
    {
      id: 1,
      subjectName: '乐理课',
      startTime: startClassTime.toISOString(),
      endTime: startClassEndTime.toISOString(),
      teacherName: '张老师',
      signStatus: 'not_started', // 'not_started', 'in_progress', 'completed'
      startSignTime: null,
      endSignTime: null,
      teacherId: 101
    },
    {
      id: 2,
      subjectName: '声乐课',
      startTime: endClassTime.toISOString(),
      endTime: endClassEndTime.toISOString(),
      teacherName: '李老师',
      signStatus: 'in_progress',
      startSignTime: endClassTime.toISOString(),
      endSignTime: null,
      teacherId: 102
    },
    {
      id: 3,
      subjectName: '器乐课',
      startTime: '2024-03-18 14:00:00',
      endTime: '2024-03-18 15:30:00',
      teacherName: '王老师',
      signStatus: 'completed',
      startSignTime: '2024-03-18 13:58:00',
      endSignTime: '2024-03-18 15:32:00',
      teacherId: 103
    }
  ];
  
  // 更新课程状态
  updateClassStatus();
};

// 更新课程状态
const updateClassStatus = () => {
  const now = new Date();
  
  todayClasses.value.forEach(item => {
    const startTime = new Date(item.startTime);
    const endTime = new Date(item.endTime);
    
    // 如果课程已经完成签到，不需要更新状态
    if (item.signStatus === 'completed') {
      return;
    }
    
    // 如果课程已经开始但还没结束
    if (item.signStatus === 'in_progress') {
      // 检查是否已经过了结束时间
      if (now > endTime) {
        // 如果已经过了结束时间但没有结束签到，标记为需要结束
        item.needEndSign = true;
      }
      return;
    }
    
    // 如果课程还没开始
    if (now < startTime) {
      item.signStatus = 'not_started';
    } 
    // 如果课程已经开始但没有开始签到
    else if (now >= startTime && now <= endTime) {
      item.needStartSign = true;
    }
    // 如果课程已经结束但没有任何签到
    else if (now > endTime) {
      item.signStatus = 'missed';
    }
  });
};

// 加载签到历史
const loadSignHistory = async () => {
  // 模拟数据，实际项目中应该调用API
  signHistory.value = [
    {
      id: 1,
      subjectName: '乐理课',
      startTime: '2024-03-17 08:30:00',
      endTime: '2024-03-17 10:00:00',
      signTime: '2024-03-17 08:35:00',
      status: 'success',
      statusText: '已签到'
    },
    {
      id: 2,
      subjectName: '声乐课',
      startTime: '2024-03-16 10:30:00',
      endTime: '2024-03-16 12:00:00',
      signTime: '2024-03-16 10:40:00',
      status: 'success',
      statusText: '已签到'
    },
    {
      id: 3,
      subjectName: '器乐课',
      startTime: '2024-03-15 14:00:00',
      endTime: '2024-03-15 15:30:00',
      signTime: null,
      status: 'missed',
      statusText: '未签到'
    }
  ];
};

// 加载签到统计
const loadSignStats = async () => {
  // 模拟数据，实际项目中应该调用API
  stats.value = {
    totalClasses: 30,
    signedClasses: 28,
    missedClasses: 2,
    attendanceRate: 93
  };
};

// 格式化日期
const formatDate = (dateString) => {
  return dayjs(dateString).format('YYYY-MM-DD');
};

// 格式化时间
const formatTime = (dateString) => {
  return dayjs(dateString).format('HH:mm');
};

// 获取状态样式类
const getStatusClass = (item) => {
  switch (item.signStatus) {
    case 'completed':
      return 'success';
    case 'in_progress':
      return 'in-progress';
    case 'missed':
      return 'missed';
    default:
      return 'pending';
  }
};

// 获取状态文本
const getStatusText = (item) => {
  switch (item.signStatus) {
    case 'completed':
      return '已完成';
    case 'in_progress':
      return '上课中';
    case 'missed':
      return '已错过';
    default:
      const now = new Date();
      const startTime = new Date(item.startTime);
      
      if (now < startTime) return '待上课';
      return '未签到';
  }
};

// 判断是否可以开始上课
const canStartClass = (item) => {
  if (item.signStatus !== 'not_started') return false;
  
  const now = new Date();
  const startTime = new Date(item.startTime);
  
  // 课程开始前5分钟到课程开始后5分钟内可以开始上课
  const signStartTime = new Date(startTime.getTime() - 5 * 60 * 1000);
  const signEndTime = new Date(startTime.getTime() + 5 * 60 * 1000);
  
  return now >= signStartTime && now <= signEndTime;
};

// 判断是否可以结束上课
const canEndClass = (item) => {
  if (item.signStatus !== 'in_progress') return false;
  
  const now = new Date();
  const endTime = new Date(item.endTime);
  
  // 课程结束前5分钟到课程结束后5分钟内可以结束上课
  const signStartTime = new Date(endTime.getTime() - 5 * 60 * 1000);
  const signEndTime = new Date(endTime.getTime() + 5 * 60 * 1000);
  
  return now >= signStartTime && now <= signEndTime;
};

// 打开开始上课弹窗
const openStartClassDialog = (item) => {
  currentClass.value = item;
  signForm.value.startRemark = '';
  showStartClassDialog.value = true;
};

// 打开结束上课弹窗
const openEndClassDialog = (item) => {
  currentClass.value = item;
  signForm.value.endRemark = '';
  showEndClassDialog.value = true;
};

// 处理开始上课
const handleStartClass = async () => {
  if (!currentClass.value) {
    showToast('签到数据异常');
    return;
  }
  
  try {
    loading.value = true;
    
    // 模拟API调用
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // 更新课程状态
    const index = todayClasses.value.findIndex(item => item.id === currentClass.value.id);
    if (index !== -1) {
      todayClasses.value[index].signStatus = 'in_progress';
      todayClasses.value[index].startSignTime = new Date().toISOString();
    }
    
    showToast('开始上课成功');
  } catch (error) {
    console.error('开始上课失败:', error);
    showToast('开始上课失败，请重试');
  } finally {
    loading.value = false;
    showStartClassDialog.value = false;
  }
};

// 处理结束上课
const handleEndClass = async () => {
  if (!currentClass.value) {
    showToast('签到数据异常');
    return;
  }
  
  if (!signForm.value.endRemark?.trim()) {
    showToast('请填写课程总结');
    return;
  }
  
  try {
    loading.value = true;
    
    // 模拟API调用
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // 更新课程状态
    const index = todayClasses.value.findIndex(item => item.id === currentClass.value.id);
    if (index !== -1) {
      todayClasses.value[index].signStatus = 'completed';
      todayClasses.value[index].endSignTime = new Date().toISOString();
    }
    
    // 更新签到历史
    signHistory.value.unshift({
      id: Date.now(),
      subjectName: currentClass.value.subjectName,
      startTime: currentClass.value.startTime,
      endTime: currentClass.value.endTime,
      signTime: new Date().toISOString(),
      status: 'success',
      statusText: '已签到'
    });
    
    // 更新统计数据
    stats.value.signedClasses++;
    stats.value.attendanceRate = Math.round((stats.value.signedClasses / stats.value.totalClasses) * 100);
    
    showToast('结束上课成功');
  } catch (error) {
    console.error('结束上课失败:', error);
    showToast('结束上课失败，请重试');
  } finally {
    loading.value = false;
    showEndClassDialog.value = false;
  }
};

// 弹窗关闭前处理
const beforeDialogClose = (action, done) => {
  if (action === 'confirm') {
    // 确认按钮点击时，不立即关闭，等待handleSign完成
    return false;
  }
  // 取消按钮点击时，直接关闭
  done();
};

// 查看全部签到历史
const viewAllHistory = () => {
  emit('change-component', {
    name: 'sign-history',
    params: {
      studentId: myInfo.value?.id
    }
  });
};
</script>

<style lang="scss" scoped>
.student-sign {
  padding: 16px;
  height: 100%;
  overflow-y: auto;
  background: #f5f7fa;
  
  &::-webkit-scrollbar {
    display: none;
  }
  
  .section {
    background: #fff;
    border-radius: 12px;
    padding: 20px;
    margin-bottom: 16px;
    box-shadow: 0 2px 12px rgba(0, 0, 0, 0.05);
    
    .section-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 16px;
      
      .title {
        font-size: 16px;
        font-weight: 500;
        color: #333;
        position: relative;
        padding-left: 12px;
        
        &::before {
          content: '';
          position: absolute;
          left: 0;
          top: 50%;
          transform: translateY(-50%);
          width: 4px;
          height: 16px;
          background: #00c9a4;
          border-radius: 2px;
        }
      }
      
      .date {
        font-size: 14px;
        color: #666;
      }
      
      .more {
        font-size: 14px;
        color: #00c9a4;
        display: flex;
        align-items: center;
        cursor: pointer;
        
        .van-icon {
          font-size: 12px;
          margin-left: 4px;
        }
      }
    }
  }
  
  .class-list {
    .class-card {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 16px;
      background: #f8f9fa;
      border-radius: 8px;
      margin-bottom: 12px;
      border-left: 4px solid #ddd;
      transition: all 0.3s;
      
      &:last-child {
        margin-bottom: 0;
      }
      
      &.signed {
        border-left-color: #00c9a4;
      }
      
      &.in-progress {
        border-left-color: #ff9900;
        background: #fffbf0;
      }
      
      .class-info {
        .subject {
          font-size: 16px;
          font-weight: 500;
          color: #333;
          margin-bottom: 8px;
        }
        
        .time {
          font-size: 14px;
          color: #666;
          margin-bottom: 4px;
        }
        
        .teacher {
          font-size: 13px;
          color: #999;
        }
      }
      
      .sign-status {
        display: flex;
        flex-direction: column;
        align-items: flex-end;
        gap: 12px;
        
        .status-tag {
          padding: 4px 12px;
          border-radius: 12px;
          font-size: 12px;
          
          &.success {
            background: #e6f7f4;
            color: #00c9a4;
          }
          
          &.in-progress {
            background: #fff7e6;
            color: #ff9900;
          }
          
          &.pending {
            background: #f2f3f5;
            color: #909399;
          }
          
          &.missed {
            background: #fee;
            color: #ff4d4f;
          }
        }
        
        .action-btn {
          display: flex;
          align-items: center;
          padding: 8px 16px;
          border-radius: 6px;
          font-size: 14px;
          font-weight: 500;
          cursor: pointer;
          transition: all 0.2s ease;
          box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
          
          .van-icon {
            margin-right: 6px;
            position: relative;
            top: 1px;
          }
          
          &:active {
            transform: translateY(1px);
            box-shadow: none;
          }
        }
        
        .start-btn {
          background-color: #ffffff;
          color: #00c9a4;
          border: 1px solid #00c9a4;
          
          .van-icon {
            color: #00c9a4;
          }
          
          &:hover {
            background-color: #f0faf8;
          }
        }
        
        .end-btn {
          background-color: #ffffff;
          color: #ff9900;
          border: 1px solid #ff9900;
          
          .van-icon {
            color: #ff9900;
          }
          
          &:hover {
            background-color: #fff9f0;
          }
        }
      }
    }
  }
  
  .history-list {
    .history-item {
      display: flex;
      padding: 12px 0;
      border-bottom: 1px solid #f5f5f5;
      
      &:last-child {
        border-bottom: none;
        padding-bottom: 0;
      }
      
      .history-date {
        width: 80px;
        font-size: 14px;
        color: #666;
      }
      
      .history-content {
        flex: 1;
        position: relative;
        
        .subject {
          font-size: 15px;
          font-weight: 500;
          color: #333;
          margin-bottom: 4px;
        }
        
        .time {
          font-size: 13px;
          color: #999;
        }
        
        .status-tag {
          position: absolute;
          right: 0;
          top: 0;
          padding: 2px 8px;
          border-radius: 10px;
          font-size: 12px;
          
          &.success {
            background: #e6f7f4;
            color: #00c9a4;
          }
          
          &.missed {
            background: #fee;
            color: #ff4d4f;
          }
        }
      }
    }
  }
  
  .stats-cards {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 12px;
    
    .stats-card {
      background: #f8f9fa;
      border-radius: 8px;
      padding: 16px;
      text-align: center;
      
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
  
  .sign-dialog-content {
    padding: 0 16px;
    
    .dialog-info {
      margin-bottom: 16px;
      
      .info-item {
        margin-bottom: 8px;
        display: flex;
        
        &:last-child {
          margin-bottom: 0;
        }
        
        .label {
          width: 80px;
          font-size: 14px;
          color: #666;
        }
        
        .value {
          flex: 1;
          font-size: 14px;
          color: #333;
          font-weight: 500;
        }
      }
    }
    
    .sign-form {
      .form-item {
        position: relative;
        margin-bottom: 16px;
        
        &:last-child {
          margin-bottom: 0;
        }
        
        .label {
          display: block;
          font-size: 14px;
          color: #333;
          margin-bottom: 8px;
        }
        
        .remark-input {
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
        
        .word-count {
          position: absolute;
          right: 12px;
          bottom: 12px;
          font-size: 12px;
          color: #999;
        }
      }
    }
  }
}
</style>
