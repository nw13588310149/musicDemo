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
}
