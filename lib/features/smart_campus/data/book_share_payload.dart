/// 群聊 `sendMsg(type=3, param1=book)` 的 content JSON 结构。
///
/// 与 1.0 chat.vue / 群聊列表 `latestMsg` 解析口径一致：
/// - [type]：教材类型（1 视唱 / 2 乐理 / 3 听写 / 4 声乐 / 5 器乐 / 10 试题 …）
/// - [subtitle]：列表副标题（通常 shortText2）
/// - [shortText3]：封面图 URL
Map<String, dynamic> buildBookShareContent({
  required int id,
  required String title,
  required int type,
  String coverUrl = '',
  String subtitle = '',
}) {
  return <String, dynamic>{
    'id': id,
    'title': title,
    'type': type,
    'shortText3': coverUrl,
    'subtitle': subtitle,
  };
}

/// musicPlay / answerEnd2 分享时兜底教材 type：
/// 详情接口未带回 type 时，视唱多题入口 `args.type == 3` 仍按视唱(type=1) 分享。
int resolveMusicPlayShareBookType({
  required int detailType,
  int? routeType,
}) {
  if (detailType > 0) return detailType;
  if (routeType == 3) return 1;
  return 0;
}
