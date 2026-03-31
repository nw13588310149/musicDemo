<template>
  <view class="attendance-record">
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
            @click="handleBatchAttendance"
          >
            一键到齐
          </van-button>
        </view>
      </view>

      <!-- 考勤统计卡片 -->
      <view class="stat-cards">
        <view class="stat-card" v-for="(value, key) in stats" :key="key">
          <text class="value" :class="getStatusClass(key)">{{value}}</text>
          <text class="label">{{getStatusLabel(key)}}</text>
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
                  @click="handleBatchAttendance"
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
          :description="'当前班级暂无可签到课程 ' + dayjs().format('YYYY-MM-DD HH:mm:ss')"
        />
      </view>
    </template>
  </view>
</template>

<script setup>
import { ref, computed } from 'vue';
import { showToast, showDialog } from 'vant';
import dayjs from 'dayjs';
import { teacherStudentSignInList, teacherStudentSignInOneKey, teacherStudentSignInUpdate } from '/api/home.js';

const props = defineProps({
  classId: {
    type: [String, Number],
    required: true
  },
  currentSignableCourse: {
    type: Object,
    default: null
  }
});

// 状态常量
const STATUS_TEXT = {
  present: '出勤',
  absent: '缺勤',
  late: '迟到',
  leave: '请假'
};

const STATUS_MAP = {
  0: 'present',
  1: 'absent',
  2: 'late',
  3: 'leave'
};

// 组件状态
const searchName = ref('');
const studentList = ref([]);
const stats = ref({
  total: 0,
  present: 0,
  absent: 0,
  late: 0,
  leave: 0
});

// 计算属性
const filteredStudentList = computed(() => {
  if (!searchName.value) return studentList.value;
  return studentList.value.filter(student => 
    (student.realname || student.nickname)
      .toLowerCase()
      .includes(searchName.value.toLowerCase())
  );
});

// 获取状态样式
const getStatusClass = (status) => {
  const classMap = {
    present: 'success',
    absent: 'danger',
    late: 'warning',
    leave: 'warning'
  };
  return classMap[status] || '';
};

// 获取状态标签
const getStatusLabel = (key) => {
  const labelMap = {
    total: '应到人数',
    present: '实到人数',
    absent: '缺勤人数',
    late: '迟到人数',
    leave: '请假人数'
  };
  return labelMap[key] || key;
};

// 获取状态颜色
const getStatusColor = (status) => {
  const colorMap = {
    present: '#00c9a4',
    absent: '#ff4d4f',
    late: '#faad14',
    leave: '#1890ff'
  };
  return colorMap[status] || '#999';
};

// 获取签到列表
const getSignInList = async () => {
  if (!props.classId) {
    console.warn('班级ID不能为空');
    return;
  }

  try {
    const params = {
      classId: props.classId,
      courseId: props.currentSignableCourse?.id,
      current: 1,
      date: dayjs().format('YYYY-MM-DD'),
      size: 100
    };
    
    const res = await teacherStudentSignInList(params);
    if (res.code === 0) {
      studentList.value = res.data.list.map(item => ({
        id: item.studentId,
        realname: item.student.realname,
        nickname: item.student.nickname,
        headUrl: item.student.headUrl,
        status: STATUS_MAP[item.status],
        checkTime: dayjs(item.createTime).format('HH:mm:ss'),
        mobile: item.student.mobile,
        signId: item.id
      }));
      
      stats.value = {
        total: studentList.value.length,
        present: Number(res.data.sum.status0Count) || 0,
        absent: Number(res.data.sum.status1Count) || 0,
        late: Number(res.data.sum.status2Count) || 0,
        leave: Number(res.data.sum.status3Count) || 0
      };
    } else {
      showToast(res.msg || '获取签到列表失败');
    }
  } catch (error) {
    console.error('获取签到列表失败:', error);
    showToast('获取签到列表失败');
  }
};

// 处理状态变化
const handleStatusChange = async (student) => {
  const statusCode = Object.entries(STATUS_MAP).find(([code, status]) => status === student.status)?.[0];
  
  try {
    const res = await teacherStudentSignInUpdate({
      id: student.signId,
      status: statusCode
    });
    
    if (res.code === 0) {
      await getSignInList(); // 刷新列表
    } else {
      showToast(res.msg || '更新状态失败');
    }
  } catch (error) {
    console.error('更新状态失败:', error);
    showToast('更新状态失败');
  }
};

// 一键到齐
const handleBatchAttendance = async () => {
  if (!props.currentSignableCourse) {
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
    
    const res = await teacherStudentSignInOneKey({
      classId: props.classId
    });
    
    if (res.code === 0) {
      showToast({
        type: 'success',
        message: '考勤完成'
      });
      await getSignInList();
    } else {
      showToast(res.msg || '一键到齐失败');
    }
  } catch (error) {
    if (error.toString().includes('cancel')) return;
    console.error('一键到齐失败:', error);
    showToast('一键到齐失败');
  }
};

// 监听课程���化
watch(() => props.currentSignableCourse, async (newVal) => {
  if (newVal && props.classId) {
    await getSignInList();
  }
}, { immediate: true });

// 监听班级变化
watch(() => props.classId, async (newVal) => {
  if (newVal && props.currentSignableCourse) {
    await getSignInList();
  }
});
</script>

<style lang="scss" scoped>
.attendance-record {
  .action-bar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 16px;

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
      gap: 8px;
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

      .value {
        display: block;
        font-size: 24px;
        font-weight: bold;
        margin-bottom: 4px;

        &.success { color: #00c9a4; }
        &.danger { color: #ff4d4f; }
        &.warning { color: #faad14; }
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

  .empty-attendance {
    padding: 40px;
    text-align: center;
  }

  .no-course {
    padding: 40px;
    text-align: center;
  }
}
</style> 