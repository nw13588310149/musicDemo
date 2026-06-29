import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_music_flutter/features/smart_campus/data/principal_inbox_data.dart';

void main() {
  test('counts pending from headmaster list array data', () {
    const response = {
      'code': 0,
      'msg': 'ok',
      'data': [
        {
          'id': '28',
          'schoolId': '2066563244679475201',
          'userId': '2066705433485066242',
          'msgType': '建议',
          'isAnonymous': 1,
          'content': '2212',
          'attachments': '',
          'status': 0,
          'createTime': '2026-06-29 23:33:12',
        },
      ],
    };

    expect(parsePrincipalInboxPendingCount(response), 1);
    expect(parsePrincipalInboxList(response), hasLength(1));
    expect(parsePrincipalInboxList(response).first.msgType, '建议');
  });
}
