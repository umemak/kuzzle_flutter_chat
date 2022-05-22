class Message {
  final String id;
  final String username;
  final String value;
  final int createdAt;
  Message(
      {required this.id,
      required this.username,
      required this.value,
      required this.createdAt});
  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['_id'],
        username: json['_source']['username'],
        value: json['_source']['value'],
        createdAt: json['_source']['_kuzzle_info']['createdAt'],
      );
}
