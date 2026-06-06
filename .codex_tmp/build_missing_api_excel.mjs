import fs from "node:fs/promises";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const outputDir = "outputs/smart_campus_missing_apis";
await fs.mkdir(outputDir, { recursive: true });

const rows = [
  ["班主任", "首页工作台", "P1", "新增", "POST", "/app/school/v2/teacher/headTeacherIndex", "返回班级概览、待办提醒、近期动态和首页统计", "无或 classId", "确认缺失：当前首页部分统计和动态为静态展示"],
  ["班主任", "班级工作台", "P1", "新增", "POST", "/app/school/v2/teacher/headTeacherClassOverview", "返回班级人数、家长绑定、请假、作业、考勤等综合统计", "classId", "确认缺失：现有 classList/studentList 无综合统计"],
  ["班主任", "签课管理-大班课", "P0", "新增", "POST", "/app/school/v2/teacher/courseClassSignAll", "一键完成大班课全班签到", "courseId、students[{studentId,signStatus,remark}]", "页面未接：当前点击后只修改本地状态"],
  ["班主任", "签课管理-大班课", "P0", "新增", "POST", "/app/school/v2/teacher/courseClassStudentSignUpdate", "教师修改大班课单个学生签到状态", "courseId、studentId、signStatus、remark", "页面未接：当前点击学生头像只修改本地状态"],
  ["班主任", "签课管理-大班课", "P0", "新增", "POST", "/app/school/v2/teacher/courseClassSignDetail", "返回大班课应到学生与当前签到状态", "courseId", "确认缺失：大课签到面板需要权威名单和状态"],
  ["班主任", "课堂考勤", "P0", "新增", "POST", "/app/school/v2/teacher/courseTeacherSignHistory", "查询教师本人历史上下课签到记录", "beginDate、endDate、current、size", "当前历史签到为演示数据"],
  ["班主任", "课堂考勤", "P0", "新增", "POST", "/app/school/v2/teacher/courseAttendanceHistory", "查询班级课程历史签到情况", "classId、courseId、beginDate、endDate、status、current、size", "用于班级课程考勤历史"],
  ["班主任", "课堂考勤", "P1", "新增", "POST", "/app/school/v2/teacher/courseAttendanceStat", "今日、本周、本月课程签到统计", "classId、beginDate、endDate", "正常、迟到、缺勤、请假等"],
  ["班主任", "课堂考勤", "P1", "新增", "POST", "/app/school/v2/teacher/courseAttendanceRecentList", "页面最近签到记录", "classId、size", "当前最近记录为演示数据"],
  ["班主任", "宿舍动态", "P0", "新增", "POST", "/app/school/v2/teacher/classDormitoryDynamicList", "查询班级学生最新查寝动态", "classId、status、current、size", "当前页面为演示数据"],
  ["班主任", "宿舍动态-补卡审核", "P0", "新增", "POST", "/app/school/v2/teacher/classDormitoryMakeupList", "查询本班学生查寝补卡申请", "classId、status、current、size", "页面未接：补卡审核列表为演示数据"],
  ["班主任", "宿舍动态-补卡审核", "P0", "新增", "POST", "/app/school/v2/teacher/classDormitoryMakeupAudit", "通过或驳回学生查寝补卡申请", "id、status、auditReason", "页面未接：当前通过/驳回只修改本地状态"],
  ["班主任", "宿舍动态-补卡审核", "P1", "新增", "POST", "/app/school/v2/teacher/classDormitoryMakeupDetail", "查询补卡申请详情和审批流程", "id", "确认缺失"],
  ["班主任", "宿舍历史", "P0", "新增", "POST", "/app/school/v2/teacher/classDormitoryCheckHistory", "查询班级学生历史查寝记录", "classId、studentId、beginDate、endDate、status、current、size", "当前页面为演示数据"],
  ["班主任", "宿舍历史", "P1", "新增", "POST", "/app/school/v2/teacher/classDormitoryCheckStat", "班级正常、晚归、未归、请假统计", "classId、beginDate、endDate", "用于顶部统计"],
  ["班主任", "宿舍历史", "P1", "新增", "POST", "/app/school/v2/teacher/classDormitoryCheckDetail", "查看单次查寝详情、异常原因和处理记录", "id", "需要返回处理状态和处理备注"],

  ["任课老师", "课堂考勤", "P0", "新增", "POST", "/app/school/v2/teacher/courseTeacherSignHistory", "教师本人上下课签到历史", "beginDate、endDate、current、size", "可与班主任共用"],
  ["任课老师", "首页工作台", "P1", "新增", "POST", "/app/school/v2/teacher/courseTeacherIndex", "返回任课老师首页统计、当前课程和今日课表概览", "无", "确认缺失：当前首页部分数据为静态展示"],
  ["任课老师", "签课管理-大班课", "P0", "新增", "POST", "/app/school/v2/teacher/courseClassSignAll", "一键完成大班课全班签到", "courseId、students[{studentId,signStatus,remark}]", "页面未接：当前点击后只修改本地状态"],
  ["任课老师", "签课管理-大班课", "P0", "新增", "POST", "/app/school/v2/teacher/courseClassStudentSignUpdate", "教师修改大班课单个学生签到状态", "courseId、studentId、signStatus、remark", "页面未接：当前点击学生头像只修改本地状态"],
  ["任课老师", "签课管理-大班课", "P0", "新增", "POST", "/app/school/v2/teacher/courseClassSignDetail", "返回大班课应到学生与当前签到状态", "courseId", "确认缺失：大课签到面板需要权威名单和状态"],
  ["任课老师", "课堂考勤", "P0", "新增", "POST", "/app/school/v2/teacher/courseAttendanceHistory", "查询所授课程历史考勤", "courseId、beginDate、endDate、status、current、size", "当前历史记录为演示数据"],
  ["任课老师", "课堂考勤", "P1", "新增", "POST", "/app/school/v2/teacher/courseAttendanceStat", "课程签到率、迟到、缺勤等统计", "courseId、beginDate、endDate", "可与班主任共用"],
  ["任课老师", "课堂考勤", "P1", "新增", "POST", "/app/school/v2/teacher/courseAttendanceRecentList", "最近签到记录", "courseId、size", "当前最近记录为演示数据"],
  ["任课老师", "考试批阅", "P1", "扩展", "POST", "/app/school/v2/teacher/examStudentList", "返回考试评分状态与评分进度", "现有参数", "建议增加 scored、absent、scoreStatus 等字段"],
  ["任课老师", "考试批阅", "P1", "扩展", "POST", "/app/school/v2/teacher/examStudentStat", "返回完整考试成绩统计", "现有参数", "建议增加分数段、最高分、最低分、及格率、优秀率"],
  ["任课老师", "考试批阅", "P1", "新增", "POST", "/app/school/v2/teacher/examStudentRemind", "对未提交考试材料的学生发送催交通知", "examId、subjectId、studentIds", "页面未接：页面存在“催交/详情”动作"],
  ["任课老师", "学生花名册/成绩详情", "P1", "扩展", "POST", "/app/school/v2/teacher/studentExamRecordList", "返回更完整学生成绩详情", "studentId", "建议增加教师名称、评语、资源类型和资源名称"],

  ["宿管", "个人到岗打卡", "P0", "新增", "POST", "/app/school/v2/dormitory/staffSignIn", "宿管到岗打卡并记录定位", "longitude、latitude、address、remark", "后端使用服务器时间并校验电子围栏"],
  ["宿管", "个人到岗打卡", "P0", "新增", "POST", "/app/school/v2/dormitory/staffSignOut", "宿管离岗打卡并记录定位", "longitude、latitude、address、remark", "后端使用服务器时间并校验电子围栏"],
  ["宿管", "个人到岗打卡", "P0", "新增", "POST", "/app/school/v2/dormitory/staffSignHistory", "宿管本人历史打卡记录", "beginDate、endDate、status、current、size", "当前页面使用本地演示记录"],
  ["宿管", "个人到岗打卡", "P1", "新增", "POST", "/app/school/v2/dormitory/staffSignStat", "宿管到岗率、迟到、缺勤统计", "beginDate、endDate", "用于顶部统计"],
  ["宿管", "首页工作台", "P1", "新增", "POST", "/app/school/v2/dormitory/index", "返回今日值班、当前事项、待审补卡、异常未闭环等首页数据", "无", "确认缺失：当前事项和今日值班为静态数据"],
  ["宿管", "查寝历史", "P1", "新增", "POST", "/app/school/v2/dormitory/dormitoryCheckHistory", "查询历史查寝批次和结果", "buildingId、floorId、roomId、beginDate、endDate、status、current、size", "现有房间列表接口不能完整承担历史查询"],
  ["宿管", "查寝历史", "P1", "新增", "POST", "/app/school/v2/dormitory/dormitoryCheckDetail", "查询单次查寝批次详情", "id", "返回房间及学生状态明细"],
  ["宿管", "查寝历史", "P2", "新增", "POST", "/app/school/v2/dormitory/dormitoryCheckExport", "导出查寝记录", "筛选参数同历史接口", "返回导出任务或文件地址"],
  ["宿管", "查寝异常处理", "P1", "新增", "POST", "/app/school/v2/dormitory/dormitoryCheckExceptionHandle", "填写异常原因、处理结果和备注", "checkId、studentId、handleStatus、remark", "需要保留处理人和处理时间"],
  ["宿管", "补卡审核", "P0", "新增", "POST", "/app/school/v2/dormitory/dormitoryMakeupList", "查询学生查寝补卡申请", "buildingId、status、current、size", "确认缺失：宿管端首页有待审补卡业务"],
  ["宿管", "补卡审核", "P0", "新增", "POST", "/app/school/v2/dormitory/dormitoryMakeupAudit", "通过或驳回学生查寝补卡申请", "id、status、auditReason", "确认缺失"],
  ["宿管", "补卡审核", "P1", "新增", "POST", "/app/school/v2/dormitory/dormitoryMakeupDetail", "查询补卡申请详情与审批流程", "id", "确认缺失"],

  ["学生", "课堂签到", "P0", "新增", "POST", "/app/school/v2/student/courseSignHistory", "学生签到历史列表", "beginDate、endDate、status、current、size", "当前签到历史为演示数据"],
  ["学生", "课堂签到", "P1", "新增", "POST", "/app/school/v2/student/courseSignStat", "正常、迟到、缺勤、请假统计", "beginDate、endDate", "当前统计为演示数据"],
  ["学生", "课堂签到", "P1", "新增", "POST", "/app/school/v2/student/courseSignRecentList", "最近签到记录", "size", "当前最近记录为演示数据"],
  ["学生", "课堂签到", "P1", "新增", "POST", "/app/school/v2/student/courseSignDetail", "单次签到详情", "id", "返回教师、课程、签到和签退时间"],
  ["学生", "课堂签到-申请补签", "P0", "新增", "POST", "/app/school/v2/student/courseSignMakeupSave", "对缺勤课程发起补签申请", "courseId、signType、reason、attachment", "页面未接：页面已有“申请补签”但没有动作接口"],
  ["学生", "课堂签到-申请补签", "P1", "新增", "POST", "/app/school/v2/student/courseSignMakeupList", "查询本人补签申请记录与审批状态", "status、current、size", "确认缺失"],
  ["学生", "课堂签到-申请补签", "P1", "新增", "POST", "/app/school/v2/student/courseSignMakeupDetail", "查询单次补签申请详情", "id", "确认缺失"],
  ["学生", "我的查寝", "P0", "新增", "POST", "/app/school/v2/student/myDormitoryInfo", "当前学生宿舍楼、楼层、房间、床位信息", "无", "当前页面整体为演示数据"],
  ["学生", "我的查寝", "P0", "新增", "POST", "/app/school/v2/student/dormitoryCheckHistory", "当前学生历史查寝记录", "beginDate、endDate、status、current、size", "当前页面整体为演示数据"],
  ["学生", "我的查寝", "P1", "新增", "POST", "/app/school/v2/student/dormitoryCheckStat", "正常、晚归、未归、请假统计", "beginDate、endDate", "用于顶部统计"],
  ["学生", "我的查寝", "P1", "新增", "POST", "/app/school/v2/student/dormitoryCheckDetail", "单次查寝详情和异常原因", "id", "建议返回处理状态及备注"],
  ["学生", "我的查寝-申请补卡", "P0", "新增", "POST", "/app/school/v2/student/dormitoryMakeupSave", "提交晨检或晚查寝补卡申请", "date、scene、reason、attachment", "页面未接：当前提交只增加本地待审数量"],
  ["学生", "我的查寝-申请补卡", "P1", "新增", "POST", "/app/school/v2/student/dormitoryMakeupList", "查询本人查寝补卡申请与审批状态", "status、current、size", "确认缺失"],
  ["学生", "我的查寝-申请补卡", "P1", "新增", "POST", "/app/school/v2/student/dormitoryMakeupDetail", "查询补卡申请详情与审批流程", "id", "确认缺失"],
  ["学生", "我的查寝-申请补卡", "P2", "新增", "POST", "/app/school/v2/student/dormitoryMakeupCancel", "撤销待审批的查寝补卡申请", "id", "建议能力"],
  ["学生", "请假管理", "P0", "新增", "POST", "/app/school/v2/student/studentLeaveCancel", "撤销审批中的学生请假申请", "id", "页面未接：页面设计包含“撤销申请”，现有 Swagger 无接口"],
  ["学生", "我的成绩", "P1", "扩展", "POST", "/app/school/v2/student/examOverview", "支持学期筛选和按科目查询趋势", "semesterId、subjectId", "当前接口无筛选参数"],
  ["学生", "我的成绩", "P1", "扩展", "POST", "/app/school/v2/student/examOverview", "趋势返回每场班级排名和学校排名", "现有 trendList 增加字段", "建议增加 classRank、schoolRank"],
  ["学生", "我的成绩", "P1", "扩展", "POST", "/app/school/v2/student/examRecordList", "各科成绩返回任课教师及资源元数据", "现有 subjectScores 增加字段", "建议增加 teacherName、resourceType、resourceName"],
  ["学生", "我的作业", "P1", "扩展", "POST", "/app/school/v2/student/studentHomeworkSum", "支持按老师统计平均分", "增加 teacherAvgScores", "现有接口仅有科目均分和分数段"],
  ["学生", "我的作业", "P1", "扩展", "POST", "/app/school/v2/student/studentHomeworkSum", "返回作业状态数量统计", "增加 total、pending、submitted、reviewed、overdue", "用于页面顶部统计"],
  ["学生", "我的作业", "P1", "扩展", "POST", "/app/school/v2/student/studentHomeworkSum", "返回班级、年级排名和变化趋势", "增加 classRank、schoolRank、rankTrend", "用于页面排名卡片"],
  ["班主任", "家校沟通", "P1", "扩展", "POST", "/app/school/v2/teacher/chatSend", "支持发送图片和附件消息", "增加 messageType、fileUrl、fileName", "页面未接：图片和附件按钮当前为空操作"],
];

const detailedRows = rows.map((row) => {
  const note = row[8];
  const conclusion = note.includes("页面未接")
    ? "页面动作未接接口"
    : row[3] === "扩展"
      ? "接口需扩展"
      : "Swagger 确认缺失";
  return [...row.slice(0, 5), conclusion, ...row.slice(5)];
});

const wb = Workbook.create();
const detail = wb.worksheets.add("接口缺失明细");
const summary = wb.worksheets.add("身份汇总");
const notes = wb.worksheets.add("后端开发说明");

const headers = ["身份", "具体页面", "优先级", "类型", "方法", "核查结论", "建议接口", "具体用途", "建议参数/字段", "备注"];
detail.getRangeByIndexes(0, 0, 1, headers.length).values = [headers];
detail.getRangeByIndexes(1, 0, detailedRows.length, headers.length).values = detailedRows;
detail.tables.add(`A1:J${detailedRows.length + 1}`, true, "MissingApiDetails").style = "TableStyleMedium4";
detail.freezePanes.freezeRows(1);
detail.freezePanes.freezeColumns(2);
detail.showGridLines = false;
detail.getRange("A1:J1").format = { fill: "#4F46E5", font: { bold: true, color: "#FFFFFF" }, wrapText: true };
detail.getRange(`A2:J${rows.length + 1}`).format = { wrapText: true, verticalAlignment: "top" };
detail.getRange(`C2:C${rows.length + 1}`).conditionalFormats.add("containsText", { text: "P0", format: { fill: "#FEE2E2", font: { bold: true, color: "#B91C1C" } } });
detail.getRange(`C2:C${rows.length + 1}`).conditionalFormats.add("containsText", { text: "P1", format: { fill: "#FEF3C7", font: { bold: true, color: "#92400E" } } });
detail.getRange(`C2:C${rows.length + 1}`).conditionalFormats.add("containsText", { text: "P2", format: { fill: "#DBEAFE", font: { bold: true, color: "#1D4ED8" } } });
const widths = [12, 22, 10, 10, 10, 22, 48, 38, 52, 44];
widths.forEach((w, i) => detail.getRangeByIndexes(0, i, rows.length + 1, 1).format.columnWidth = w);
detail.getRange(`A1:I${rows.length + 1}`).format.rowHeight = 34;

const roles = ["班主任", "任课老师", "宿管", "学生"];
const summaryRows = roles.map((role) => {
  const rr = rows.filter((r) => r[0] === role);
  return [role, rr.length, rr.filter((r) => r[2] === "P0").length, rr.filter((r) => r[2] === "P1").length, rr.filter((r) => r[2] === "P2").length, rr.filter((r) => r[3] === "新增").length, rr.filter((r) => r[3] === "扩展").length];
});
summary.getRange("A1:G1").merge();
summary.getRange("A1").values = [["智慧校园缺失接口汇总"]];
summary.getRange("A1:G1").format = { fill: "#312E81", font: { bold: true, color: "#FFFFFF", size: 18 }, horizontalAlignment: "center", verticalAlignment: "center" };
summary.getRange("A3:G3").values = [["身份", "总项数", "P0", "P1", "P2", "新增接口", "扩展接口"]];
summary.getRange("A4:G7").values = summaryRows;
summary.tables.add("A3:G7", true, "RoleSummary").style = "TableStyleMedium4";
summary.getRange("A9:B13").values = [
  ["优先级", "说明"],
  ["P0", "页面核心功能无法使用或仍为演示数据"],
  ["P1", "页面可使用，但关键统计、详情或字段缺失"],
  ["P2", "筛选、导出等增强能力"],
  ["合计", rows.length],
];
summary.getRange("A9:B13").format = { wrapText: true, borders: { preset: "all", style: "thin", color: "#D1D5DB" } };
summary.getRange("A9:B9").format = { fill: "#E0E7FF", font: { bold: true, color: "#312E81" } };
summary.getRange("A1:G13").format.rowHeight = 30;
[18, 48, 12, 12, 12, 16, 16].forEach((w, i) => summary.getRangeByIndexes(0, i, 13, 1).format.columnWidth = w);
summary.getRange("A10:B13").format.rowHeight = 45;
summary.freezePanes.freezeRows(3);
summary.showGridLines = false;

notes.getRange("A1:D1").merge();
notes.getRange("A1").values = [["后端开发与接口约定建议"]];
notes.getRange("A1:D1").format = { fill: "#312E81", font: { bold: true, color: "#FFFFFF", size: 18 }, horizontalAlignment: "center" };
notes.getRange("A3:B10").values = [
  ["主题", "建议"],
  ["分页", "列表统一使用 current、size；返回 records、total、current、size。"],
  ["时间", "日期统一 yyyy-MM-dd，时间统一 yyyy-MM-dd HH:mm:ss；签到时间必须使用服务器时间。"],
  ["状态字典", "签到、查寝、请假、评分状态需提供统一枚举和中文含义。"],
  ["ID 类型", "雪花 ID 在 JSON 中统一返回字符串，避免前端 JavaScript 精度丢失。"],
  ["定位打卡", "后端校验电子围栏，记录经纬度、地址、设备、打卡人和服务器时间。"],
  ["详情接口", "详情需返回处理人、处理时间、处理状态、异常原因和备注。"],
  ["导出", "大数据导出建议返回异步任务 ID 或文件地址。"],
];
notes.getRange("A12:D12").merge();
notes.getRange("A12").values = [["说明：本表仅包含已核查确认的班主任、任课老师、宿管和学生端缺失项；教务管理端尚未完成 Swagger 全量审计。"]];
notes.getRange("A3:B10").format = { wrapText: true, verticalAlignment: "top", borders: { preset: "all", style: "thin", color: "#D1D5DB" } };
notes.getRange("A3:B3").format = { fill: "#4F46E5", font: { bold: true, color: "#FFFFFF" } };
notes.getRange("A12:D12").format = { fill: "#FEF3C7", font: { color: "#92400E", italic: true }, wrapText: true };
notes.getRange("A1:D12").format.rowHeight = 32;
notes.getRange("A:A").format.columnWidth = 18;
notes.getRange("B:B").format.columnWidth = 80;
notes.showGridLines = false;

const inspection = await wb.inspect({ kind: "table", range: "接口缺失明细!A1:J8", include: "values,formulas", tableMaxRows: 8, tableMaxCols: 10 });
console.log(inspection.ndjson);
const errors = await wb.inspect({ kind: "match", searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A", options: { useRegex: true, maxResults: 50 }, summary: "formula error scan" });
console.log(errors.ndjson);
for (const sheetName of ["接口缺失明细", "身份汇总", "后端开发说明"]) {
  const preview = await wb.render({ sheetName, autoCrop: "all", scale: 0.8, format: "png" });
  await fs.writeFile(`${outputDir}/${sheetName}.png`, new Uint8Array(await preview.arrayBuffer()));
}
const xlsx = await SpreadsheetFile.exportXlsx(wb);
await xlsx.save(`${outputDir}/智慧校园缺失接口清单-全量复核版.xlsx`);
