<template>
	<view class="kebiaoBox">
		<view class="top_box">
			<view class="top">
				<view class="btn" v-if="myInfo.id == activeClass.headTeacherId" @click="editKb">编辑课表</view>
				<view class="tips" @click="showPicker = !showPicker" v-if="classAll?.length > 1">{{activeClass.name}} <van-icon  style="margin-left: 5px;" :name="showPicker?'arrow-up':'arrow-down'" /></view>
				<view class="year" @click="dateShow = true">{{date}}</view>
				<view class="btn_box">
					<view class="left" @click="prevWeek">
						<van-icon name="arrow-left" />
					</view>
					<view class="right" @click="nextWeek">
						<van-icon name="arrow" />
					</view>
				</view>
			</view>
		</view>
		
		<!-- 日历表格 -->
		<view class="class_table">
			<view class="table_head">
				<view class="left">
					<view class="week">{{getChineseMonth(date)}}</view>
				</view>
				<view class="right">
					<view class="head_li" v-for="item in dataNav">
						<view class="week">{{item.name}}</view>
						<view class="time">{{item.value}}</view>
					</view>
				</view>
			</view>
			<view class="table_box">
				<view class="li" v-for="item in listAll">
					<view class="time">{{item.time}}</view>
					<view class="one" @click="editOne(item,0)">
						<view class="edit" v-if="isEdit && !item?.k0?.subjectName" >
							<van-icon class="icon"  name="/static/assets/add_kb.png" />
							<view class="text">待排课</view>
						</view>
						<view class="box" :style="{'background':item?.k0?.color}">
							<view class="name">{{item?.k0?.subjectName}}</view>
							<view class="user">{{item?.k0?.teacherRealname}}</view>
						</view>
					</view>
					<view class="one" @click="editOne(item,1)">
						<view class="edit" v-if="isEdit && !item?.k1?.subjectName" >
							<van-icon class="icon"   name="/static/assets/add_kb.png" />
							<view class="text">待排课</view>
						</view>
						<view class="box" :style="{'background':item?.k1?.color}">
							<view class="name">{{item?.k1?.subjectName}}</view>
							<view class="user">{{item?.k1?.teacherRealname}}</view>
						</view>
					</view>
					<view class="one" @click="editOne(item,2)">
						<view class="edit" v-if="isEdit && !item?.k2?.subjectName" >
							<van-icon class="icon"  name="/static/assets/add_kb.png" />
							<view class="text">待排课</view>
						</view>
						<view class="box" :style="{'background':item?.k2?.color}">
							<view class="name">{{item?.k2?.subjectName}}</view>
							<view class="user">{{item?.k2?.teacherRealname}}</view>
						</view>
					</view>
					<view class="one" @click="editOne(item,3)">
						<view class="edit" v-if="isEdit && !item?.k3?.subjectName" >
							<van-icon class="icon"   name="/static/assets/add_kb.png" />
							<view class="text">待排课</view>
						</view>
						<view class="box" :style="{'background':item?.k3?.color}">
							<view class="name">{{item?.k3?.subjectName}}</view>
							<view class="user">{{item?.k3?.teacherRealname}}</view>
						</view>
					</view>
					<view class="one" @click="editOne(item,4)">
						<view class="edit" v-if="isEdit && !item?.k4?.subjectName" >
							<van-icon class="icon"   name="/static/assets/add_kb.png" />
							<view class="text">待排课</view>
						</view>
						<view class="box" :style="{'background':item?.k4?.color}">
							<view class="name">{{item?.k4?.subjectName}}</view>
							<view class="user">{{item?.k4?.teacherRealname}}</view>
						</view>
					</view>
					<view class="one" @click="editOne(item,5)">
						<view class="edit" v-if="isEdit && !item?.k5?.subjectName" >
							<van-icon class="icon"   name="/static/assets/add_kb.png" />
							<view class="text">待排课</view>
						</view>
						<view class="box" :style="{'background':item?.k5?.color}">
							<view class="name">{{item?.k5?.subjectName}}</view>
							<view class="user">{{item?.k5?.teacherRealname}}</view>
						</view>
					</view>
					<view class="one" @click="editOne(item,6)">
						<view class="edit" v-if="isEdit && !item?.k6?.subjectName" >
							<van-icon class="icon"   name="/static/assets/add_kb.png" />
							<view class="text">待排课</view>
						</view>
						<view class="box" :style="{'background':item?.k6?.color}">
							<view class="name">{{item?.k6?.subjectName}}</view>
							<view class="user">{{item?.k6?.teacherRealname}}</view>
						</view>
					</view>
				</view>
				<!-- <view class="li liAdd" v-if="isEdit"  @click="addKc"><van-icon class="icon" v-if="isEdit" name="/static/assets/add_class.png"/>新增</view> -->
			</view>
		</view>
		
		<!-- 日历弹窗 -->
		<van-calendar v-model:show="dateShow"  :min-date="minDate" :max-date="maxDate" @confirm="onConfirm" />
		
		<!-- 课表编辑 -->
		<van-popup v-model:show="showE" position="right" style="width: 40%;height: 100%;">
			<view class="boxOne">
				<view class="title">课表编辑</view>
				<view class="content">
					<view class="li">
						<view class="name">班级</view>
						<view class="text">{{activeClass.name}}</view>
					</view>
					<view class="li">
						<view class="name">课程时间</view>
						<view class="text">第{{activeLine}}节课</view>
					</view>
					<view class="li">
						<view class="name">课程名称</view>
						<view class="text" style="top: 1px;">
							<van-dropdown-menu>
							  <van-dropdown-item v-model="subjectId" :options="option1" />
							</van-dropdown-menu>
						</view>
					</view>
					<view class="li">
						<view class="name">任课教师</view>
						<view class="text" style="top: 1px;">
							<van-dropdown-menu>
							  <van-dropdown-item v-model="teacherId" :options="option2" />
							</van-dropdown-menu>
						</view>
					</view>
					<view class="li">
						<view class="name">当前日期</view>
						<view class="text">
							{{getDayOfWeek(date,activeNum)}}
						</view>
					</view>
					<view class="li">
						<view class="name">是否复用</view>
						<view class="text" style="top: 1px;">
							<van-dropdown-menu>
							  <van-dropdown-item v-model="isXh" :options="option3" />
							</van-dropdown-menu>
						</view>
					</view>
					<view class="li" v-if="isXh == 0">
						<view class="name">复用日期</view>
						<view class="text" @click="showPicker2 = true">
							{{startTime}} - {{endTime}}
						</view>
					</view>
					<view class="li color-li">
						<view class="name">背景颜色</view>
						<view class="text color-field">
							<view class="color-picker-trigger" @tap.stop="openNativeColorPicker">
								<view class="color-swatch" :style="{ background: color }" />
								<text class="color-value">{{ color }}</text>
								<text class="color-hint">点击取色</text>
							</view>
							<view class="preset-colors">
								<view
									v-for="c in presetColors"
									:key="c"
									class="preset-dot"
									:style="{ background: c }"
									@tap.stop="setPresetColor(c)"
								/>
							</view>
						</view>
					</view>
				</view>
				<view class="editBtnT" @click="save">保存</view>
				
			</view>
		</van-popup>
		
		<!-- 班级选择 -->
		<van-popup v-model:show="showPicker" round position="bottom">
		  <van-picker
		    :columns="columns"
		    @cancel="showPicker = false"
		    @confirm="onChange"
		  />
		</van-popup>
		
		<!-- 日期选择 -->
		<van-popup v-model:show="showPicker2" round position="bottom">
			<van-picker-group
			  title="复用日期"
			  :tabs="['开始日期', '结束日期']"
			  @confirm="onConfirmDate"
			  @cancel="showPicker2 = false"
			>
			   <van-date-picker
			      v-model="startTime1"
			      :min-date="minDate"
			      :max-date="maxDate"
			    />
			   <van-date-picker v-model="endTime1" :min-date="minDate" :max-date="maxDate" />
			</van-picker-group>
		</van-popup>

		<!-- 必须在弹层外：transform 会阻止浏览器打开原生 color 面板 -->
		<input
			id="kebiao-native-color-input"
			ref="colorInputRef"
			class="native-color-input-hidden"
			type="color"
			:value="color"
			@input="onColorInput"
			@change="onColorInput"
		/>

	</view>
</template>

<script setup>
import { ref, computed, onMounted, watch, nextTick } from 'vue';
import {useRouter} from 'vue-router';
import {
	schoolTimeConfigList,
	classList,
	subjectList,
	teacherList,
	courseList,
	courseBatchSave
} from '/api/home.js';
import { showToast } from 'vant';
import dayjs from 'dayjs';

// 使用插件来处理 ISO 8601 标准格式
import customParseFormat from 'dayjs/plugin/customParseFormat';
import utc from 'dayjs/plugin/utc';
dayjs.extend(customParseFormat);
dayjs.extend(utc);

const showE = ref(false);
const subjectId = ref(1);
const teacherId = ref('未选择');
const activeClass = ref({});
const option1 = ref([]);
const option2 = ref([]);
const showPicker2 = ref(false);
let columns = []
const showPicker = ref(false);
const classAll = ref();
const isXh = ref(0);
const option3 = ref([{text:"开启",value:0},{text:"关闭",value:1}])
const color = ref("#ffffff");
/** 放在弹层外，用脚本 click 打开，避免 van-popup 的 transform 导致原生取色板无法弹出 */
const colorInputRef = ref(null);

const presetColors = [
	'#ffffff', '#fef3c7', '#fde68a', '#fed7aa', '#fecaca', '#fce7f3', '#e9d5ff', '#ddd6fe',
	'#dbeafe', '#bfdbfe', '#a5f3fc', '#99f6e4', '#d1fae5', '#bbf7d0', '#e5e7eb', '#94a3b8'
];

/** 原生 color：兼容 uni / H5 的 input、change */
function onColorInput(e) {
	const v = e?.detail?.value ?? e?.target?.value;
	if (typeof v === 'string' && v.length) {
		color.value = v;
	}
}

function setPresetColor(c) {
	color.value = c;
}

function openNativeColorPicker() {
	nextTick(() => {
		let el = colorInputRef.value;
		el = el && (el.$el || el);
		if (!el && typeof document !== 'undefined') {
			el = document.getElementById('kebiao-native-color-input');
		}
		if (el && typeof el.click === 'function') {
			el.click();
			return;
		}
		showToast({ message: '请使用下方预设颜色', type: 'fail' });
	});
}

const leftT = ref();
const listAll = ref([]);
const myInfo = JSON.parse(uni.getStorageSync('my'));
console.log(myInfo)
onMounted(() =>{
	classList().then(res =>{
		if(res.code == 0){
			if(res.data.length > 0){
				classAll.value = res.data;
				activeClass.value = res.data[0];
				console.log(activeClass.value)
				schoolTimeConfigList({classId:res.data[0].id}).then(res =>{
					if(res.code == 0){
						leftT.value = res.data;
						let arr = [];
						res.data.forEach(e =>{
							arr.push({line:e.lineNum,k0:"",k1:"",k2:"",k3:"",k4:"",k5:"",k6:"",time:e.timeBegin.substring(0, 5)})
						})
			
						listAll.value = arr;
					} else {
						showToast({ message: res.msg || "获取上课时段失败", type: "fail" });
					}
					getKb()
				}).catch(() => {
					showToast({ message: "获取上课时段异常", type: "fail" });
				})
				
				let list = [];
				res.data.forEach(e =>{
					list.push({ text: e.name, value: e.id})
				})
				columns = list;
				

			} else {
				showToast({ message: "暂无班级数据", type: "fail" });
			}
		} else {
			showToast({ message: res.msg || "获取班级列表失败", type: "fail" });
		}
	}).catch(() => {
		showToast({ message: "获取班级列表异常", type: "fail" });
	})

})

//获取班级课表
function getKb(){
	const param = {
		  "beginDate": getDayOfWeek(date.value,0),
		  "classId": activeClass.value.id,
		  "endDate": getDayOfWeek(date.value,6),
		  "teacherId": ""
	}
	courseList(param).then(res => {
		if (res.code !== 0) {
			showToast({ message: res.msg || "获取课表失败", type: "fail" });
			return;
		}
	    // 课表初始化
	    let arr = [];
		console.log(leftT.value)
	    leftT.value.forEach(e => {
	        arr.push({ line: e.lineNum, k0: "", k1: "", k2: "", k3: "", k4: "", k5: "", k6: "", time: e.timeBegin.substring(0, 5) });
	    });
	    listAll.value = arr;
	
	    const startDate = dayjs(date.value, "YYYY MM/DD");
	    if (!startDate.isValid()) {
	        return;
	    }
	    
	    const startDay = (startDate.day() + 6) % 7; // 将星期天的值调整到最后，星期一作为一周的开始
	    
	    for (let i = 0; i < 7; i++) {
	        const dayDate = startDate.add(i - startDay, 'day');
	        
	        const year = dayDate.year();
	        const month = dayDate.format('MM');
	        const day = dayDate.format('DD');
	        
	        const dateStr = `${year}-${month}-${day}`;
	        if (res.data && res.data[dateStr]) {
	            const data = res.data[dateStr];
	            data.forEach(e => {
	                listAll.value[e.lineNum - 1]['k' + i] = e;
	            });
	        }
	    }
	}).catch(() => {
		showToast({ message: "获取课表异常", type: "fail" });
	});
}

//切换班级
function onChange(value){
	activeClass.value = classAll.value[value.selectedIndexes[0]];
	showPicker.value = false;
	getKb()
}

//设定日期为前后一年
const currentDate = dayjs();
const startTime = ref(dayjs().format('YYYY-MM-DD'));
const endTime = ref(dayjs().add(180, 'day').format('YYYY-MM-DD'));

const startTime1 = ref(startTime.value.split('-'));
const endTime1 = ref(endTime.value.split('-'));

const minDate = ref(dayjs().subtract(1, 'year').toDate());
const maxDate = ref(dayjs().add(1, 'year').toDate());

const dataNav = computed(() => {
  const weekDays = ["一", "二", "三", "四", "五", "六", "日"];
  const startDate = dayjs(date.value, "YYYY MM/DD");

  if (!startDate.isValid()) {
    return [];
  }

  const startDay = (startDate.day() + 6) % 7;
  const weekData = [];

  for (let i = 0; i < 7; i++) {
    const dayDate = startDate.add(i - startDay, 'day');
    const month = dayDate.month() + 1;
    const day = dayDate.date();

    weekData.push({
      name: weekDays[i],
      value: `${month}/${day}`
    });
  }

  return weekData;
});

//日期
const dateShow = ref(false);
const date = ref(formatDateToCustom(new Date()));

//时间函数
function formatDateToCustom(date) {
  return dayjs(date).format('YYYY MM/DD');
}

//标准时间函数
function formatDateToCustomBZ(date) {
  return dayjs(date).format('YYYY-MM-DD');
}

//时间函数-获取周几
function getDayOfWeek(dateString, dayIndex) {
  const date = dayjs(dateString, "YYYY MM/DD");
  const startDay = (date.day() + 6) % 7; // 将星期天的值调整到最后，星期一作为一周的开始

  const targetDate = date.add(dayIndex - startDay, 'day');
  return targetDate.format('YYYY-MM-DD');
}

//时间函数 -月份
function getChineseMonth(date) {
  const monthNames = [
    "一月", "二月", "三月", "四月", "五月", "六月",
    "七月", "八月", "九月", "十月", "十一月", "十二月"
  ];
  
  // 确认日期解析正确
  const parsedDate = dayjs(date, "YYYY MM/DD");
  if (!parsedDate.isValid()) {
    console.error(`Invalid date: ${date}`);
    return '';
  }

  const monthIndex = parsedDate.month();

  return monthNames[monthIndex];
}

//上一周
function prevWeek() {
  date.value = dayjs(date.value, 'YYYY MM/DD').subtract(1, 'week').format('YYYY MM/DD');
}

//下一周
function nextWeek() {
  date.value = dayjs(date.value, 'YYYY MM/DD').add(1, 'week').format('YYYY MM/DD');
}

//确定时间
function onConfirm(value){
  date.value = formatDateToCustom(value);
  dateShow.value = false;
}

//确定日期
function onConfirmDate(){
  startTime.value = startTime1.value.join('-');
  endTime.value = endTime1.value.join('-');
  showPicker2.value = false;
}

//编辑课表
const isEdit = ref(false);
function editKb(){
  isEdit.value = !isEdit.value;
}

//新增课程
function addKc(){
  list.value.push({one:"",two:"",three:"",four:"",five:"",six:"",seven:"",time:"待设置"})
}

const activeNum = ref(0);
const activeLine = ref(1);

//编辑课程
function editOne(item,num){
	if(!isEdit.value){
		return false;
	}
  activeLine.value = item.line;
  activeNum.value = num;
  const cell = item["k" + num];
  color.value = cell && cell.color ? cell.color : "#ffffff";
  subjectList({classId:activeClass.value.id}).then(res =>{
    if (res.code !== 0) {
      showToast({ message: res.msg || "获取课程列表失败", type: "fail" });
      return;
    }
    let arr = [];
    (res.data || []).forEach(e =>{
      arr.push({text:e.name,value:e.id})
    })
    option1.value = arr;
  }).catch(() => {
    showToast({ message: "获取课程列表异常", type: "fail" });
  });
  teacherList({classId:activeClass.value.id}).then(res =>{
    if (res.code !== 0) {
      showToast({ message: res.msg || "获取教师列表失败", type: "fail" });
      return;
    }
    let arr = [];
    (res.data || []).forEach(e =>{
      arr.push({text:e.realname,value:e.id})
    })
    option2.value = arr;
  }).catch(() => {
    showToast({ message: "获取教师列表异常", type: "fail" });
  });
  showE.value = true;
}

//时间改变-更新课表
watch(date, (newValue, oldValue) => {
  if (newValue !== oldValue) {
    getKb(); // 更新课表数据
  }
});

/**
 * 课表列 activeNum 与 dayjs 星期对齐：表头「一…日」→ k0…k6
 * dayjs: 0=周日, 1=周一, …, 6=周六
 */
function activeColumnToJsWeekday(activeNum) {
  if (activeNum === 6) return 0;
  return activeNum + 1;
}

/**
 * 复用排课：在 [startDateStr, endDateStr] 内，取所有「指定星期几」的日期（含边界）。
 * 必须从「起始日当天或之后」第一次出现该星期几开始，不能用「含起始日那一周里的那个星期几」再整体 +1 周，
 * 否则起始日落在该周该星期几之后时，会错误地从下一周才开始（用户看到像「从下周才生效」）。
 */
function getDatesInRange(startDateStr, endDateStr, jsWeekday) {
  const result = [];
  const start = dayjs(startDateStr, "YYYY-MM-DD");
  const end = dayjs(endDateStr, "YYYY-MM-DD");
  if (!start.isValid() || !end.isValid() || start.isAfter(end, "day")) {
    return result;
  }
  const startD = start.day();
  const addDays = (jsWeekday - startD + 7) % 7;
  let current = start.add(addDays, "day");
  while (!current.isAfter(end, "day")) {
    result.push(current.format("YYYY-MM-DD"));
    current = current.add(1, "week");
  }
  return result;
}

//保存
function save() {
	const params = [];
	if (isXh.value == 0) {
		const startDate = dayjs(startTime.value).format('YYYY-MM-DD');
		const endDate = dayjs(endTime.value).format('YYYY-MM-DD');
		const jsWeekday = activeColumnToJsWeekday(activeNum.value);
		const datesInRange = getDatesInRange(startDate, endDate, jsWeekday);
		if (datesInRange.length === 0) {
			showToast({ message: '复用日期范围内没有匹配的星期，请调整起止日期', type: 'fail' });
			return;
		}
		for (const date of datesInRange) {
			params.push({
				classId: activeClass.value.id,
				subjectId: subjectId.value,
				teacherId: teacherId.value,
				lineNum: activeLine.value,
				date: date,
				color: color.value
			});
		}
	} else {
		params.push({
			classId: activeClass.value.id,
			subjectId: subjectId.value,
			teacherId: teacherId.value,
			lineNum: activeLine.value,
			date: getDayOfWeek(date.value, activeNum.value),
			color: color.value
		});
	}
	courseBatchSave(params)
		.then((res) => {
			if (res.code == 0) {
				showToast({ message: '保存成功', type: 'success' });
				showE.value = false;
				getKb();
			} else {
				showToast({ message: res.msg || '保存失败', type: 'fail' });
			}
		})
		.catch(() => {
			showToast({ message: '保存异常，请检查网络', type: 'fail' });
		});
}
</script>



<style lang="scss" scoped>
.kebiaoBox{
	height: 100%;
	::v-deep .van-calendar__selected-day{
		background: #2ccda1;
	}
	::v-deep .van-calendar__confirm{
		background: #2ccda1;
		border: none;
		.van-button__content{
			color: #fff;
		}
	}
	::v-deep .van-dropdown-menu__title:after{
		border: 4px solid;
		border-color: transparent transparent var(--van-gray-4) var(--van-gray-4);
	}
	::v-deep .van-picker__title{
		font-weight: 400;
	}
	::v-deep .van-picker__cancel,::v-deep .van-picker__confirm {
	        background: #ddd;
	        border-radius: 50px;
	        height: 30px;
	        margin: 10px;
	}
	::v-deep .van-picker__cancel {
        background: #E0F8F1;
        color: #2CCDA1;
    }
	::v-deep .van-picker__confirm {
        background: #2CCDA1;
        color: #fff !important;
    }
	::v-deep .van-tabs__line{
		background: #2CCDA1;
		height: 4px;
		width: 30px;
	}
	.top_box{
		padding: 20px 16px 10px 16px;
		.top{
			display: flex;
			height: 32px;
			line-height: 32px;
			.year{
				margin-left: auto;
				padding: 0px 10px;
				border-radius: 4px;
				font-weight: 400;
				color: #656a76;
				box-shadow: 0 1px 8px 0 #eeeeee;
			}
			.btn{
				box-shadow: 0 1px 8px 0 #f3f3f3;
				padding: 0 10px;
				border-radius: 4px;
				margin-right: 15px;
			}
			.tips{
				
				box-shadow: 0 1px 8px 0 #f3f3f3;
				padding: 0 10px;
				border-radius: 4px;
			}
			.zq{
				margin-left: 15px;
				background: #f2f3f7;
				padding: 0px 8px;
				border-radius: 4px;
				font-weight: 400;
				color: #656a76;
				letter-spacing: 2px;
			}
			.btn_box{
				width: 70px;
				height: 32px;
				display: flex;
				justify-content: center;
				line-height: 32px;
				margin-left: 15px;
				box-shadow: 0 1px 8px 0 #eeeeee;
				align-items: center;
				border-radius: 4px;
				.left,.right{
					width: 50%;
					text-align: center;
					color: #888;
					font-size: 18px;
					align-items: center;
				}
				.left{
					border-right: 1px solid #f6f7fb;
				}
			}
		}
	}

	.class_table{
		height: calc(100% - 70px);
		overflow-y: auto;
		scrollbar-width: none; /* Firefox */
		-ms-overflow-style: none; /* IE and Edge */
		.table_head{
			display: flex;
			justify-content: flex-end;
			border-radius: 6px;
			height: 66px;
			.left{
				align-items: center;
				display: flex;
				margin: 0 16px;
				width: calc(16% - 32px);
				.week{
					height: 40px;
					display: flex;
					width: 60px;
					margin: 0 auto;
					align-items: center;
					justify-content: center;
					box-shadow: 0 1px 8px 0 #eeeeee;
					border-radius: 4px;
				}
			}
			.right{
				width: calc(84% - 15px);
				margin-right: 15px;
				margin-top: 4px;
				border-radius: 4px;
				display: flex;
				justify-content: flex-end;
				box-shadow: 0 1px 8px 0 #eeeeee;
				padding: 10px 0;
			}
			.head_li{
			    width: 15.27%;
			    text-align: center;
			    border-right: 1px solid #eeeeee;
			    color: #4b505e;
				.week{
				    height: 20px;
				    line-height: 20px;
				    font-weight: 400;
				    letter-spacing: 2px;
				}
				.time{
					height: 28px;
					line-height: 28px;
					font-weight: 400;
					font-size: 18px;
				}
			}
			.head_li:last-child{
				border-right: none;
				 width: calc(14.7% - 10px);
			}
		}
	}
	.class_table::-webkit-scrollbar {
	  display: none;
	}

	.table_box{
		margin-top: 16px;
		border-top: 2px solid #f6f7fb;
		.li{
			border-bottom: 2px solid #f6f7fb;
			height: 62px;
			display: flex;
			justify-content: flex-end;
			line-height: 62px;
			text-align: center;
			.icon{
				position: relative;
				top: 2px;
				margin-left: 6px;
			}
			.one{
				width: 12%;
				border-right: 2px solid #f6f7fb;
				background: #fff;
				color: #4b505e;
				position: relative;
				.edit{
					position: absolute;
					z-index: 2;
					width: 100%;
					height: 100%;
					background: #eee;
					.icon{
						margin-left: 0;
						top: -10px;
					}
					.text{
						color: #bfbfbf;
						font-size: 12px;
						position: absolute;
						width: 100%;
						height: calc(100% - 10px);
						top: 10px;
					}
				}
				.box{
					z-index: 1;
					position: absolute;
					width: 100%;
					height: 100%;
					display: flex;
					flex-direction: column;
					
					.name{
						height: 70%;
						width: 100%;
						    display: flex;
						    align-items: center;
						    justify-content: center;
					}
					.user{
						position: relative;
						top: -15%;
						height: 30%;
						width: 100%;
						font-size: 12px;
						    display: flex;
						    align-items: center;
						    justify-content: center;
					}
				}
			}
			.one:last-child{
				border-right: none;
			}
			.time{
				flex-grow: 1;
			    border-right: 2px solid #f6f7fb;
			    font-weight: 400;
			    font-size: 18px;
			    letter-spacing: 1px;
			    color: #6b6b6b;
			}
		}
		.liAdd{
			justify-content: center;
			align-items: center;
			font-size: 18px;
			.icon{
				font-size: 24px;
				margin-right: 10px;
				position: relative;
				top: 0px;
			}
		}
	}
	.boxOne{
		width: 100%;
		height: 100%;
		.title{
			text-align: center;
			height: 50px;
			line-height: 50px;
			font-size: 18px;
			border-bottom: 1px solid #f6f7fb;
		}
		.content{
			padding: 10px;
		}
		.li{
			display: flex;
			position: relative;
			padding: 15px 10px;
			border-bottom: 1px solid #f2f3f7;
			.text{
				position: absolute;
				right: 10px;
			}
		}
		.editBtnT{
			width: 100px;
			    background: #2ccda1;
			    height: 36px;
			    text-align: center;
			    line-height: 36px;
			    border-radius: 9px;
			    color: #fff;
			    margin: 0 auto;
			    margin-top: 50px;
		}
		::v-deep .van-dropdown-menu__bar{
			background: none;
			box-shadow: none;
		}
		::v-deep .van-dropdown-menu__title--active{
			color:#2ccda1;
		}
		::v-deep .van-dropdown-item__option--active, ::v-deep .van-dropdown-item__option--active .van-dropdown-item__icon{
			color:#2ccda1;
		}
		::v-deep .van-dropdown-menu .van-overlay{
			background: rgba(0,0,0,.1);
		}
		.color-li .text.color-field {
			display: flex;
			flex-direction: column;
			align-items: flex-end;
			gap: 10px;
			max-width: 72%;
		}
		.color-picker-trigger {
			display: flex;
			align-items: center;
			gap: 6px;
			padding: 6px 10px;
			border: 1px solid #e5e7eb;
			border-radius: 8px;
			background: #fafafa;
			position:relative;
			top:-10px;
		}
		.color-swatch {
			width: 28px;
			height: 28px;
			border-radius: 6px;
			border: 1px solid #e5e7eb;
			flex-shrink: 0;
		}
		.color-value {
			font-size: 13px;
			color: #374151;
			font-family: ui-monospace, monospace;
		}
		.color-hint {
			font-size: 12px;
			color: #2ccda1;
		}
		.preset-colors {
			display: flex;
			flex-wrap: wrap;
			justify-content: flex-end;
			gap: 6px;
			max-width: 100%;
		}
		.preset-dot {
			width: 22px;
			height: 22px;
			border-radius: 4px;
			border: 1px solid rgba(0, 0, 0, 0.08);
			box-sizing: border-box;
		}
		.native-color-input-hidden {
			position: fixed;
			right: 8px;
			bottom: 8px;
			width: 56px;
			height: 56px;
			opacity: 0.01;
			z-index: 10050;
			border: none;
			padding: 0;
			cursor: pointer;
		}
	}
}
</style>