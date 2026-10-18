class NotificationPayload {
  const NotificationPayload({
    required this.orderId,
    required this.title,
    required this.body,
    this.type = 'ORDER_NOTIFICATION',
    this.entityId,
  });

  final String orderId;
  final String title;
  final String body;
  final String type;
  final String? entityId;

  Map<String, dynamic> toMap() => {
    'orderId': orderId,
    'title': title,
    'body': body,
    'type': type,
    if (entityId != null) 'entityId': entityId,
  };

  factory NotificationPayload.fromMap(Map<String, dynamic> map) {
    return NotificationPayload(
      orderId: map['orderId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      type: map['type']?.toString() ?? 'ORDER_NOTIFICATION',
      entityId: map['entityId']?.toString(),
    );
  }
}
