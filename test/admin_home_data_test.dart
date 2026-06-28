import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_music_flutter/features/smart_campus/data/admin_home_data.dart';

void main() {
  test('parseAdminHomeLoginChart fills missing dates with zero', () {
    final chart = parseAdminHomeLoginChart(
      [
        {'loginDate': '2026-06-16', 'count': 24},
        {'loginDate': '2026-06-17', 'count': 22},
        {'loginDate': '2026-06-18', 'count': 19},
      ],
      startDate: '2026-06-12',
      endDate: '2026-06-18',
    );

    expect(chart.points, hasLength(7));
    expect(chart.points.first.loginDate, '2026-06-12');
    expect(chart.points.first.count, 0);
    expect(chart.points[4].loginDate, '2026-06-16');
    expect(chart.points[4].count, 24);
    expect(chart.points.last.count, 19);
    expect(chart.values, [0, 0, 0, 0, 24, 22, 19]);
    expect(chart.xLabels.first, '周五');
    expect(chart.xLabels.last, '周四');
  });

  test('parseAdminHomeWorkReminders reads list and nested data', () {
    final reminders = parseAdminHomeWorkReminders([
      {
        'tag': '预警',
        'title': '高三音乐实验班·昨晚查寝1人未打卡未闭环',
        'subtitle': '宿管端已登记，待确认是否转晚归备案。',
      },
      {
        'type': '提醒',
        'title': '校园通知草稿超 7 日未发布',
        'content': '通知管理后台累计 12 条草稿，请及时审核或归档。',
      },
    ]);

    expect(reminders, hasLength(2));
    expect(reminders.first.tag, '预警');
    expect(reminders.first.title, contains('查寝'));
    expect(reminders.last.tag, '提醒');
    expect(reminders.last.subtitle, contains('12 条草稿'));
  });

  test('parseAdminHomeWorkReminders skips rows without title', () {
    final reminders = parseAdminHomeWorkReminders({
      'data': [
        {'title': '有效提醒', 'subtitle': '副标题'},
        {'subtitle': '只有副标题'},
      ],
    });

    expect(reminders, hasLength(1));
    expect(reminders.single.title, '有效提醒');
  });
}
