<template>
  <view class="statistics-analysis">
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

    <!-- 日期选择器 -->
    <van-popup 
      v-model:show="showStatsDatePicker" 
      round 
      position="bottom"
    >
      <van-datetime-picker
        type="date"
        :min-date="minDate"
        :max-date="maxDate"
        :value="currentDate"
        @confirm="onStatsDateConfirm"
        @cancel="showStatsDatePicker = false"
      />
    </van-popup>
  </view>
</template>

<script setup>
import { ref, onMounted, watch } from 'vue';
import { showToast } from 'vant';
import dayjs from 'dayjs';
import { teacherStatisticalAnalysis } from '/api/home.js';

const props = defineProps({
  classId: {
    type: [String, Number],
    required: true
  }
});

// 日期相关
const currentDate = ref(dayjs().format('YYYY-MM-DD'));
const showStatsDatePicker = ref(false);
const statsDatePickerType = ref('statsStart');
const minDate = ref(dayjs().subtract(1, 'year').toDate());
const maxDate = ref(dayjs().add(1, 'year').toDate());

// 时间范围相关
const timeRange = ref('本周');
const timeRanges = ['本周', '本月'];
const statsDateRange = ref({
  start: dayjs().startOf('week').format('YYYY-MM-DD'),
  end: dayjs().format('YYYY-MM-DD')
});

// 统计数据
const statsData = ref({
  attendanceRate: 0,
  details: [
    { type: 'present', label: '出勤', count: 0, rate: 0, color: '#00c9a4' },
    { type: 'late', label: '迟到', count: 0, rate: 0, color: '#faad14' },
    { type: 'absent', label: '缺勤', count: 0, rate: 0, color: '#ff4d4f' },
    { type: 'leave', label: '请假', count: 0, rate: 0, color: '#1890ff' }
  ]
});

// 排名数据
const rankingList = ref([]);

// 获取统计数据
const getStatsData = async () => {
  if (!props.classId) {
    console.warn('班级ID不能为空');
    return;
  }

  try {
    const params = {
      beginDate: statsDateRange.value.start,
      endDate: statsDateRange.value.end,
      classId: props.classId
    };
    
    const res = await teacherStatisticalAnalysis(params);
    if (res.code === 0) {
      const sum = res.data.sum;
      
      // 更新统计数据
      statsData.value = {
        attendanceRate: Number(sum.rate0) || 0,
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
          rate: Number(item.rate0) || 0,
          attendCount: Number(item.status0Count) || 0,
          totalCount: Number(item.allCount) || 0
        }))
        .sort((a, b) => b.rate - a.rate);
      }
    } else {
      showToast(res.msg || '获取统计数据失败');
    }
  } catch (error) {
    console.error('获取统计数据失败:', error);
    showToast('获取统计数据失败');
  }
};

// 监听班级变化
watch(() => props.classId, async (newVal) => {
  if (newVal) {
    await getStatsData();
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
  await getStatsData();
};

// 选择快捷时间范围
const selectTimeRange = async (range) => {
  timeRange.value = range;
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
  await getStatsData();
};

// 获取奖牌表情
const getMedal = (index) => {
  const medals = ['🥇', '🥈', '🥉'];
  return medals[index];
};

// 初始化
onMounted(() => {
  if (props.classId) {
    getStatsData();
  }
});
</script>

<style lang="scss" scoped>
.statistics-analysis {
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
</style> 