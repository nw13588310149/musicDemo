<template>
  <view class="sign-history">
    <van-loading v-if="loading" type="spinner" vertical>加载中...</van-loading>
    <template v-else>
      <!-- 筛选区域 -->
      <view class="filter-section">
        <view class="date-filter">
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
        
        <view class="status-filter">
          <view class="status-tabs">
            <view 
              class="status-tab" 
              v-for="tab in statusTabs" 
              :key="tab.value"
              :class="{ active: activeStatus === tab.value }"
              @click="activeStatus = tab.value"
            >
              {{ tab.label }}
            </view>
          </view>
        </view>
      </view>
      
      <!-- 签到记录列表 -->
      <view class="history-list" v-if="filteredHistory.length > 0">
        <view 
          class="history-item" 
          v-for="item in filteredHistory" 
          :key="item.id"
        >
          <view class="item-header">
            <view class="date">{{ formatDate(item.date) }}</view>
            <view class="status-tag" :class="item.status">{{ item.statusText }}</view>
          </view>
          
          <view class="item-content">
            <view class="course-info">
              <view class="subject">{{ item.subjectName }}</view>
              <view class="time">{{ formatTime(item.startTime) }} - {{ formatTime(item.endTime) }}</view>
              <view class="teacher">授课教师：{{ item.teacherName }}</view>
            </view>
            
            <view class="sign-info" v-if="item.signTime">
              <view class="sign-time">签到时间：{{ formatDateTime(item.signTime) }}</view>
              <view class="sign-remark" v-if="item.remark">备注：{{ item.remark }}</view>
            </view>
          </view>
        </view>
      </view>
      
      <van-empty 
        v-else 
        description="暂无签到记录" 
        image="/static/assets/empty_list.png" 
        :image-size="[160, 160]"
      />
      
      <!-- 加载更多 -->
      <view class="load-more" v-if="hasMoreData && !loading && filteredHistory.length > 0">
        <van-button plain size="small" @click="loadMore">加载更多</van-button>
      </view>
    </template>
  </view>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { showToast } from 'vant';
import dayjs from 'dayjs';
import { getMyInfo } from '/api/home.js';

// 加载状态
const loading = ref(false);

// 用户信息
const myInfo = ref(null);

// 时间范围
const timeRange = ref('本月');
const timeRanges = ['本周', '本月', '本学期'];

// 状态筛选
const activeStatus = ref('all');
const statusTabs = [
  { label: '全部', value: 'all' },
  { label: '已签到', value: 'success' },
  { label: '未签到', value: 'missed' }
];

// 签到历史记录
const signHistory = ref([]);

// 分页相关
const page = ref(1);
const pageSize = ref(20);
const hasMoreData = ref(true);

// 日期范围
const dateRange = computed(() => {
  const now = dayjs();
  
  switch (timeRange.value) {
    case '本周':
      return {
        start: now.startOf('week').format('YYYY-MM-DD'),
        end: now.endOf('week').format('YYYY-MM-DD')
      };
    case '本月':
      return {
        start: now.startOf('month').format('YYYY-MM-DD'),
        end: now.endOf('month').format('YYYY-MM-DD')
      };
    case '本学期':
      // 假设学期从2月到7月，8月到1月
      const month = now.month() + 1;
      if (month >= 2 && month <= 7) {
        return {
          start: dayjs(`${now.year()}-02-01`).format('YYYY-MM-DD'),
          end: dayjs(`${now.year()}-07-31`).format('YYYY-MM-DD')
        };
      } else {
        return {
          start: dayjs(`${now.year()}-08-01`).format('YYYY-MM-DD'),
          end: month <= 12 ? dayjs(`${now.year()}-01-31`).add(1, 'year').format('YYYY-MM-DD') : dayjs(`${now.year()}-01-31`).format('YYYY-MM-DD')
        };
      }
    default:
      return {
        start: now.startOf('month').format('YYYY-MM-DD'),
        end: now.format('YYYY-MM-DD')
      };
  }
});

// 筛选后的历史记录
const filteredHistory = computed(() => {
  if (activeStatus.value === 'all') {
    return signHistory.value;
  }
  
  return signHistory.value.filter(item => item.status === activeStatus.value);
});

// 初始化数据
onMounted(async () => {
  loading.value = true;
  try {
    await loadUserInfo();
    await loadSignHistory();
  } catch (error) {
    console.error('初始化数据失败:', error);
    showToast('加载数据失败，请重试');
  } finally {
    loading.value = false;
  }
});

// 监听筛选条件变化
watch([timeRange, activeStatus], async () => {
  page.value = 1;
  hasMoreData.value = true;
  signHistory.value = [];
  
  loading.value = true;
  try {
    await loadSignHistory();
  } catch (error) {
    console.error('加载签到历史失败:', error);
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

// 加载签到历史
const loadSignHistory = async () => {
  // 模拟API调用
  await new Promise(resolve => setTimeout(resolve, 500));
  
  // 模拟数据，实际项目中应该调用API
  const mockData = [];
  
  // 生成模拟数据
  for (let i = 0; i < 20; i++) {
    const date = dayjs().subtract(i, 'day');
    const isSigned = Math.random() > 0.2; // 80%概率已签到
    
    mockData.push({
      id: Date.now() + i,
      date: date.format('YYYY-MM-DD'),
      subjectName: ['乐理课', '声乐课', '器乐课', '作曲课'][Math.floor(Math.random() * 4)],
      startTime: `${date.format('YYYY-MM-DD')} ${['08:30:00', '10:30:00', '14:00:00', '16:00:00'][Math.floor(Math.random() * 4)]}`,
      endTime: `${date.format('YYYY-MM-DD')} ${['10:00:00', '12:00:00', '15:30:00', '17:30:00'][Math.floor(Math.random() * 4)]}`,
      teacherName: ['张老师', '李老师', '王老师', '赵老师'][Math.floor(Math.random() * 4)],
      status: isSigned ? 'success' : 'missed',
      statusText: isSigned ? '已签到' : '未签到',
      signTime: isSigned ? date.add(Math.floor(Math.random() * 10), 'minute').format('YYYY-MM-DD HH:mm:ss') : null,
      remark: isSigned && Math.random() > 0.5 ? '按时上课' : ''
    });
  }
  
  // 筛选日期范围内的数据
  const filteredData = mockData.filter(item => {
    const itemDate = dayjs(item.date);
    return itemDate.isAfter(dayjs(dateRange.value.start).subtract(1, 'day')) && 
           itemDate.isBefore(dayjs(dateRange.value.end).add(1, 'day'));
  });
  
  // 模拟分页
  const startIndex = (page.value - 1) * pageSize.value;
  const endIndex = startIndex + pageSize.value;
  const pagedData = filteredData.slice(startIndex, endIndex);
  
  // 更新数据
  if (page.value === 1) {
    signHistory.value = pagedData;
  } else {
    signHistory.value = [...signHistory.value, ...pagedData];
  }
  
  // 判断是否还有更多数据
  hasMoreData.value = endIndex < filteredData.length;
};

// 加载更多数据
const loadMore = async () => {
  if (!hasMoreData.value || loading.value) return;
  
  page.value++;
  loading.value = true;
  
  try {
    await loadSignHistory();
  } catch (error) {
    console.error('加载更多数据失败:', error);
    showToast('加载更多数据失败，请重试');
    page.value--; // 恢复页码
  } finally {
    loading.value = false;
  }
};

// 格式化日期
const formatDate = (dateString) => {
  return dayjs(dateString).format('YYYY-MM-DD');
};

// 格式化时间
const formatTime = (dateString) => {
  return dayjs(dateString).format('HH:mm');
};

// 格式化日期时间
const formatDateTime = (dateString) => {
  return dayjs(dateString).format('YYYY-MM-DD HH:mm:ss');
};
</script>

<style lang="scss" scoped>
.sign-history {
  padding: 16px;
  height: 100%;
  overflow-y: auto;
  background: #f5f7fa;
  
  &::-webkit-scrollbar {
    display: none;
  }
  
  .filter-section {
    background: #fff;
    border-radius: 12px;
    padding: 16px;
    margin-bottom: 16px;
    box-shadow: 0 2px 12px rgba(0, 0, 0, 0.05);
    
    .date-filter {
      margin-bottom: 16px;
      
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
    
    .status-filter {
      .status-tabs {
        display: flex;
        border-radius: 8px;
        background: #f5f7fa;
        padding: 4px;
        
        .status-tab {
          flex: 1;
          text-align: center;
          padding: 8px 0;
          font-size: 14px;
          color: #666;
          border-radius: 6px;
          transition: all 0.3s;
          cursor: pointer;
          
          &.active {
            background: #00c9a4;
            color: #fff;
            font-weight: 500;
          }
        }
      }
    }
  }
  
  .history-list {
    .history-item {
      background: #fff;
      border-radius: 12px;
      padding: 16px;
      margin-bottom: 12px;
      box-shadow: 0 2px 12px rgba(0, 0, 0, 0.05);
      
      .item-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 12px;
        padding-bottom: 12px;
        border-bottom: 1px solid #f5f5f5;
        
        .date {
          font-size: 16px;
          font-weight: 500;
          color: #333;
        }
        
        .status-tag {
          padding: 4px 12px;
          border-radius: 12px;
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
      
      .item-content {
        .course-info {
          margin-bottom: 12px;
          
          .subject {
            font-size: 15px;
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
        
        .sign-info {
          font-size: 13px;
          color: #666;
          background: #f8f9fa;
          padding: 12px;
          border-radius: 8px;
          
          .sign-time {
            margin-bottom: 4px;
          }
        }
      }
    }
  }
  
  .load-more {
    text-align: center;
    margin: 20px 0;
    
    .van-button {
      width: 120px;
      color: #00c9a4;
      border-color: #00c9a4;
    }
  }
}
</style>
