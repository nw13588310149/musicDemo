// apiService.js 
import axios from 'axios';
import {ref} from 'vue';

// Base URL of your API
let baseURL = 'https://api.yyzl0931.com/';

// Create an instance of Axios with custom configuration
let apiToken = ref(uni.getStorageSync('token') || '');
let api = axios.create({
  baseURL,
  timeout: 1000000, // Timeout in milliseconds (adjust as needed)
  headers: {
    'Content-Type': 'application/json',
    // Add any custom headers here
	'app-token':apiToken.value
  },
});

//屏蔽
export const getCheck = async () => {
  try {
	api = axios.create({
	  baseURL,
	  timeout: 10000, // Timeout in milliseconds (adjust as needed)
	  headers: {
	    'Content-Type': 'application/json',
	    // Add any custom headers here
		'app-token':apiToken.value,
		'platform':"ipad",
		"ver":"1.0.1"
	  },
	})  
	  
    const response = await api.get('/app/common/dict/check');
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

export const updateToken = (token) => {
  apiToken.value = token;
  api = axios.create({
    baseURL,
    timeout:60000, // Timeout in milliseconds (adjust as needed)
    headers: {
      'Content-Type': 'application/json',
      // Add any custom headers here
  	'app-token':apiToken.value
    },
  });
};

// Function to handle errors
const handleError = (error) => {
  console.error('接口错误:', error);
  throw error; // Rethrow the error to handle it in components
};

//获取个人信息
export const getMyInfo = async (data) => {
  try {
    const response = await api.post('/app/user/myInfo');
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 获取菜单列表
export const postMenulist = async (data) => {
  try {
	  // type 类型:1-视唱 2-乐理 3-听写 4-声乐 5-器乐 6-视频
    const response = await api.post('/app/common/menuList', {'type':data});
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 获取课程列表
export const getTextbooklist = async (data) => {
  try {
	  // type 类型:1-视唱 2-乐理 3-听写 4-声乐 5-器乐
    const response = await api.post('/app/user/textbookList', data);
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

export const getSchoolbooklist = async (data) => {
  try {
	  // type 类型:1-视唱 2-乐理 3-听写 4-声乐 5-器乐
    const response = await api.post('/app/user/schoolTextbookList', data);
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 获取课程详情
export const getDetail = async (data) => {
  try {
	  // type 类型:1-视唱 2-乐理 3-听写 4-声乐 5-器乐
    const response = await api.post('/app/user/textbookDetail', {'id':data})
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 发送短信-注册
export const sendSmsApi = async (data) => {
  try {
	  // type 类型:1-视唱 2-乐理 3-听写 4-声乐 5-器乐
    const response = await api.post('/app/user/sendSmsCode', {'mobile':data,'type':0})
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 发送短信-重置密码
export const sendSmsApi1 = async (data) => {
  try {
    const response = await api.post('/app/user/sendSmsCode', {'mobile':data,'type':1})
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 注册
export const register = async (data) => {
  try {
	  // type 类型:1-视唱 2-乐理 3-听写 4-声乐 5-器乐
    const response = await api.post('/app/user/register', data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 密码重置
export const forget = async (data) => {
  try {
    const response = await api.post('/app/user/resetPassword', data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 登录
export const login = async (data) => {
  try {
	  // type 类型:1-视唱 2-乐理 3-听写 4-声乐 5-器乐
    const response = await api.post('/app/user/mobileLogin', data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 获取视频列表
export const getVideolist = async (data) => {
  try {
    const response = await api.post('/app/user/videoTutorialList', data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 获取视频详情
export const getVideoDetail = async (data) => {
  try {
	  // type 类型:1-视唱 2-乐理 3-听写 4-声乐 5-器乐
    const response = await api.post('/app/user/videoTutorialDetail', {'id':data})
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 获取收藏类目列表
export const getFavoriteList = async (data) => {
  try {
    const response = await api.post('/app/user/customFavoriteCategoryList')
    return response.data;
  } catch (error) {
    handleError(error);
  }
};
// 获取收藏列表
export const getFavoriteDetailList = async (data) => {
  try {
    const response = await api.post('/app/user/favoriteList',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 视频教程收藏/取消收藏
export const favoriteSave = async (data) => {
  try {
    const response = await api.post('/app/user/favoriteSave',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 课件类目列表
export const getcoursewareList = async (data) => {
  try {
    const response = await api.post('/app/user/coursewareCategoryList',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 退出登录
export const logout = async (data) => {
  try {
    const response = await api.post('/app/user/logout',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 课件类目列表-新增
export const addcoursewareList = async (data) => {
  try {
    const response = await api.post('/app/user/coursewareCategorySave',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 课件类目列表-删除
export const delcoursewareList = async (data) => {
  try {
    const response = await api.post('/app/user/coursewareCategoryDelete',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 文件上传
export const fileUpload = async (data) => {
  try {
    const response = await api.post('/app/user/fileUpload', data, {
      headers: {
        'Content-Type': 'multipart/form-data'
      }
    });
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 课件列表-新增
export const addCourseware = async (data) => {
  try {
    const response = await api.post('/app/user/coursewareSave',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};
// 课件列表-获取
export const getCourseware = async (data) => {
  try {
    const response = await api.post('/app/user/coursewareList',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};
// 课件列表-删除
export const delCourseware = async (data) => {
  try {
    const response = await api.post('/app/user/coursewareDelete',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 笔记目录列表-获取
export const getnoteCategoryList = async (data) => {
  try {
    const response = await api.post('/app/user/noteCategoryList',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 笔记总数-获取
export const getnoteNum = async (data) => {
  try {
    const response = await api.post('/app/user/noteCount',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 笔记目录列表-新增
export const addnoteCategoryList = async (data) => {
  try {
    const response = await api.post('/app/user/noteCategorySave',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 笔记目录列表-删除
export const delnoteCategoryList = async (data) => {
  try {
    const response = await api.post('/app/user/noteCategoryDelete',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 笔记列表-获取
export const getnoteList = async (data) => {
  try {
    const response = await api.post('/app/user/noteList',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 录音目录列表-获取
export const getrecordingGateList = async (data) => {
  try {
    const response = await api.post('/app/user/recordingCategoryList',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 录音目录列表-删除
export const delrecordingGateList = async (data) => {
  try {
    const response = await api.post('/app/user/recordingCategoryDelete',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 录音目录列表-新增
export const addrecordingGateList = async (data) => {
  try {
    const response = await api.post('/app/user/recordingCategorySave',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 录音作品-新增
export const addrecordingList = async (data) => {
  try {
    const response = await api.post('/app/user/recordingSave',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 录音作品-删除
export const recordingDelete = async (data) => {
  try {
    const response = await api.post('/app/user/recordingDelete',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 录音作品-列表
export const recordingList = async (data) => {
  try {
    const response = await api.post('/app/user/recordingList',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 获取二维码
export const getqrcode = async (data) => {
  try {
    const response = await api.post('/app/user/myQrcode',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 获取班级二维码
export const classManageQrcode = async (data) => {
  try {
    const response = await api.post('/app/school/class/classManageQrcode',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 修改个人资料
export const editMyInfo = async (data) => {
  try {
    const response = await api.post('/app/user/userinfoUpdate',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 修改密码
export const updatePassword = async (data) => {
  try {
    const response = await api.post('/app/user/updatePassword', data);
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 获取省份地区
export const getCity = async (data) => {
  try {
    const response = await api.post('/app/common/provinceCityList',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 刷题-数据汇总
export const getQuestionSummary = async (data) => {
  try {
    const response = await api.post('/app/user/questionPracticeSummary',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 刷题-生成题目
export const questionPracticeCreate = async (data) => {
  try {
    const response = await api.post('/app/user/questionPracticeCreate',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 刷题-题目列表
export const questionPracticeItemList = async (data) => {
  try {
    const response = await api.post('/app/user/questionPracticeItemList',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 刷题-上报答案
export const questionPracticeItemReport = async (data) => {
  try {
    const response = await api.post('/app/user/questionPracticeItemReport',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 获取轮播图
export const bannerList = async (data) => {
  try {
    const response = await api.post('/app/user/bannerList',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 智能听写--获取列表
export const smartDictationList = async (data) => {
  try {
    const response = await api.post('/app/user/smartDictationList',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 首页--获取资讯
export const homeLatestInfo = async (data) => {
  try {
    const response = await api.post('/app/user/homeLatestInfo',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 首页--获取学习进度
export const homeLearningProgress = async (data) => {
  try {
    const response = await api.post('/app/user/homeLearningProgress',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 校园课件--获取学习进度
export const schoolHomeLearningProgress = async (data) => {
  try {
    const response = await api.post('/app/user/schoolHomeLearningProgress',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 智能听写--记录上报
export const smartDictationRecordSave = async (data) => {
  try {
    const response = await api.post('/app/user/smartDictationRecordSave',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 笔记--新增
export const noteSave = async (data) => {
  try {
    const response = await api.post('/app/user/noteSave',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 笔记--删除
export const noteDelete = async (data) => {
  try {
    const response = await api.post('/app/user/noteDelete',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// vip - 套餐列表
export const vipList = async (data) => {
  try {
    const response = await api.post('/app/user/vipList',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// vip - 兑换
export const vipCardRedeem = async (data) => {
  try {
    const response = await api.post('/app/user/vipCardRedeem',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 意见反馈
export const feedbackSave = async (data) => {
  try {
    const response = await api.post('/app/user/feedbackSave',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 学习进度上报
export const textbookRecordSave = async (data) => {
  try {
    const response = await api.post('/app/user/textbookRecordSave',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};


// 班级列表
export const classManageList = async (data) => {
  try {
    const response = await api.post('/app/school/class/classManageList',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 课表时间
export const schoolTimeConfigList = async (data) => {
  try {
    const response = await api.post('/app/school/course/schoolTimeConfigList',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//新增班级 
export const classManageSave = async (data) => {
  try {
    const response = await api.post('/app/school/class/classManageSave',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//获取班级成员列表 
export const classManageMemberList = async (data) => {
  try {
    const response = await api.post('/app/school/class/classManageMemberList',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//扫码进入班级
export const classQrcodeEnter = async (data) => {
  try {
    const response = await api.post('/app/school/class/classQrcodeEnter',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//我的班级
export const classList = async (data) => {
  try {
    const response = await api.post('/app/school/chat/classList',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//移除学生
export const classManageMemberRemove = async (data) => {
  try {
    const response = await api.post('/app/school/class/classManageMemberRemove',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//获取科目列表
export const subjectList = async (data) => {
  try {
    const response = await api.post('/app/school/course/subjectList',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//获取班级教师列表
export const teacherList = async (data) => {
  try {
    const response = await api.post('/app/school/course/teacherList',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//获取课表
export const courseList = async (data) => {
  try {
    const response = await api.post('/app/school/course/courseList',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//批量保存课表
export const courseBatchSave = async (data) => {
  try {
    const response = await api.post('/app/school/course/courseBatchSave',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//消息轮询
export const syncMsg = async (data) => {
  try {
    const response = await api.post('/app/school/chat/syncMsg',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//发送消息
export const sendMsg = async (data) => {
  try {
    const response = await api.post('/app/school/chat/sendMsg',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 撤回/删除群聊消息
export const deleteMsg = async (data) => {
  try {
    const response = await api.post('/app/school/chat/deleteMsg', data);
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//提交认证
export const submitCertification = async (data) => {
  try {
    const response = await api.post('/app/user/submitCertification',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//学校列表
export const schoolList = async (data) => {
  try {
    const response = await api.post('/app/user/schoolList',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//班级详情
export const classDetail = async (data) => {
  try {
    const response = await api.post('/app/school/chat/classDetail',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// 设置群公告
export const updateAnnouncement = async (data) => {
  try {
    const response = await api.post('/app/school/chat/updateAnnouncement', data);
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//班级禁言
export const classManageMute = async (data) => {
  try {
    const response = await api.post('/app/school/class/classManageMute',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//解散班级
export const classManageDelete = async (data) => {
  try {
    const response = await api.post('/app/school/class/classManageDelete',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//考试列表
export const examList = async (data) => {
  try {
    const response = await api.post('/app/school/exam/examList',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//成绩列表
export const examScoreList = async (data) => {
  try {
    const response = await api.post('/app/school/exam/examScoreList',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//获取最新上课消息
export const nextSchoolCourse = async (data) => {
  try {
    const response = await api.post('/app/user/nextSchoolCourse',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//上报Cid
export const reportCid = async (data) => {
  try {
    const response = await api.post('/app/user/reportCid',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//获取未读消息总数
export const getUnReadMsgCount = async (data) => {
  try {
    const response = await api.post('/app/msg/getUnReadMsgCount',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//获取消息列表
export const msgList = async (data) => {
  try {
    const response = await api.post('/app/msg/list',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//更新已读状态
export const updateRead = async (data) => {
  try {
    const response = await api.post('/app/msg/updateRead',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//获取所在学校
export const updateSchool = async (data) => {
  try {
    const response = await api.post('/app/user/mySchool',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//学生查看自己的考勤记录
export const studentSignInList = async (data) => {
  try {
    const response = await api.post('/app/school/student/sign-in/studentSignInList',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//学生查看自己的请假记录
export const studentLeaveList = async (data) => {
  try {
    const response = await api.post('/app/school/student/sign-in/studentLeaveList',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//学生发起请假
export const studentLeaveSave = async (data) => {
  try {
    const response = await api.post('/app/school/student/sign-in/studentLeaveSave',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//教师统计分析
export const teacherStatisticalAnalysis = async (data) => {
  try {
    const response = await api.post('/app/school/student/sign-in/teacherStatisticalAnalysis',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//班主任审核学生的请假记录
export const teacherStudentLeaveAudit = async (data) => {
  try {
    const response = await api.post('/app/school/student/sign-in/teacherStudentLeaveAudit',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//班主任查看管辖班级学生的请假纪录
export const teacherStudentLeaveList = async (data) => {
  try {
    const response = await api.post('/app/school/student/sign-in/teacherStudentLeaveList',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//任课老师查看学生的签到纪录列表
export const teacherStudentSignInList = async (data) => {
  try {
    const response = await api.post('/app/school/student/sign-in/teacherStudentSignInList',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//任课老师一键到齐
export const teacherStudentSignInOneKey = async (data) => {
  try {
    const response = await api.post('/app/school/student/sign-in/teacherStudentSignInOneKey',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//任课老师修改学生签到状态
export const teacherStudentSignInUpdate = async (data) => {
  try {
    const response = await api.post('/app/school/student/sign-in/teacherStudentSignInUpdate',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//老师签到记录
export const teacherSignInList = async (data) => {
  try {
    const response = await api.post('/app/school/teacher/sign-in/teacherSignInList',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//老师签到记录保存
export const teacherSignInSave = async (data) => {
  try {
    const response = await api.post('/app/school/teacher/sign-in/teacherSignInSave',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//老师签到统计分析
export const teacherSignInStatisticalAnalysis = async (data) => {
  try {
    const response = await api.post('/app/school/teacher/sign-in/teacherSignInStatisticalAnalysis',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//老师签到记录更新
export const teacherSignInUpdate = async (data) => {
  try {
    const response = await api.post('/app/school/teacher/sign-in/teacherSignInUpdate',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//班主任签到记录审核
export const headTeacherSignInAudit = async (data) => {
  try {
    const response = await api.post('/app/school/teacher/sign-in/headTeacherSignInAudit',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//班主任签到记录列表查询
export const headTeacherSignInList = async (data) => {
  try {
    const response = await api.post('/app/school/teacher/sign-in/headTeacherSignInList',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

//班主任课时统计
export const headTeacherCourseStatistics = async (data) => {
  try {
    const response = await api.post('/app/school/teacher/sign-in/headTeacherCourseStatistics',data)
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// AI 问答 — 会话列表
export const chatGptSessionList = async (data) => {
  try {
    const response = await api.post('/app/user/chat-gpt/sessionList', data);
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// AI 问答 — 创建会话
export const chatGptSessionCreate = async (data) => {
  try {
    const response = await api.post('/app/user/chat-gpt/sessionCreate', data);
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// AI 问答 — 删除会话
export const chatGptSessionDelete = async (data) => {
  try {
    const response = await api.post('/app/user/chat-gpt/sessionDelete', data);
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// AI 问答 — 会话消息列表
export const chatGptMsgList = async (data) => {
  try {
    const response = await api.post('/app/user/chat-gpt/msgList', data);
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

// AI 问答 — 发送消息（模型侧可能较慢，单独加长超时）
export const chatGptSend = async (data) => {
  try {
    const response = await api.post('/app/user/chat-gpt/send', data, { timeout: 120000 });
    return response.data;
  } catch (error) {
    handleError(error);
  }
};

