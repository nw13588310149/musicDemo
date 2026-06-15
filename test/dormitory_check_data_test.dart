import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_music_flutter/features/smart_campus/data/dormitory_check_data.dart';

void main() {
  test('parses documented dormitory index field names', () {
    final result = parseDormitoryIndexOverview({
      'managedBuildingCount': 2,
      'totalBedCount': 60,
      'todayNormalCount': 55,
      'todayLateCount': 3,
      'todayAbsentCount': 2,
      'pendingMakeupCount': 4,
      'unhandledExceptionCount': 5,
    });

    expect(result.managedBuildingCount, 2);
    expect(result.bedCount, 60);
    expect(result.todayNormalCount, 55);
    expect(result.todayLateCount, 3);
    expect(result.todayAbsentCount, 2);
    expect(result.pendingMakeupCount, 4);
    expect(result.unclosedExceptionCount, 5);
  });

  test('parses room student realname and bed name', () {
    final rooms = parseDormitoryCheckRoomList([
      {
        'roomId': '2060000000000000001',
        'roomName': 'A-901',
        'buildingName': '女生公寓A座',
        'floorName': '9层',
        'allChecked': false,
        'userList': [
          {
            'userId': '2060000000000000002',
            'realname': '测试学生',
            'studentNo': 'S001',
            'bedName': '1号床',
            'headUrl': 'https://example.com/avatar.png',
            'status': '晚归',
          },
        ],
      },
    ]);

    expect(rooms, hasLength(1));
    expect(rooms.single.students.single.name, '测试学生');
    expect(rooms.single.students.single.bedName, '1号床');
    expect(
      rooms.single.students.single.status,
      DormitoryStudentCheckStatus.lateReturn,
    );
  });

  test('calculates selected history result statistics', () {
    final items = parseDormitoryCheckHistoryList({
      'records': [
        {'id': '1', 'userId': '11', 'status': '正常'},
        {'id': '2', 'userId': '12', 'status': '晚归'},
        {'id': '3', 'userId': '13', 'status': '未打卡'},
      ],
    });

    final stat = calculateDormitoryHistoryStat(items);
    expect(stat.bedCount, 3);
    expect(stat.normalCount, 1);
    expect(stat.lateCount, 1);
    expect(stat.notCheckedCount, 1);
  });

  test('calculates filtered room result statistics', () {
    final rooms = parseDormitoryCheckRoomList([
      {
        'roomId': '1',
        'userList': [
          {'userId': '11', 'status': '正常'},
          {'userId': '12', 'status': '晚归'},
          {'userId': '13', 'status': '未打卡'},
        ],
      },
    ]);

    final stat = calculateDormitoryRoomStat(rooms);
    expect(stat.bedCount, 3);
    expect(stat.normalCount, 1);
    expect(stat.lateCount, 1);
    expect(stat.notCheckedCount, 1);
  });

  test('parses documented detail approval and anomaly fields', () {
    final checkFields = parseDormitoryCheckDetailFields({
      'studentName': '测试学生',
      'status': '晚归',
      'anomalyReason': '排练晚归',
      'handleStatus': 1,
      'handleRemark': '已联系班主任',
    });
    final checkMap = {
      for (final field in checkFields) field.label: field.value,
    };
    expect(checkMap['异常原因'], '排练晚归');
    expect(checkMap['处理状态'], '已处理');

    final makeupFields = parseDormitoryMakeupDetailFields({
      'studentName': '测试学生',
      'status': 2,
      'approverName': '宿管老师',
      'approveRemark': '材料不足',
      'approveTime': '2026-06-14 12:00:00',
    });
    final makeupMap = {
      for (final field in makeupFields) field.label: field.value,
    };
    expect(makeupMap['审批人'], '宿管老师');
    expect(makeupMap['审批意见'], '材料不足');
    expect(makeupMap['审批时间'], '2026-06-14 12:00:00');
  });
}
