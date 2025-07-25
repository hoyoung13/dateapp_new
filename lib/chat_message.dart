enum MessageType { text, place, course, image, collection }

class ChatMessage {
  final MessageType type;
  final int senderId;
  final String? text;
  final int? placeId;
  final String? placeName;
  final String? placeImage;
  final int? courseId;
  final String? courseName;
  final String? imageUrl;
  final int? collectionId;
  final String? collectionName;

  // 생성자: 일반 텍스트 메시지
  ChatMessage.text({
    required this.senderId,
    required String content,
  })  : type = MessageType.text,
        text = content,
        placeId = null,
        placeName = null,
        placeImage = null,
        courseId = null,
        courseName = null,
        imageUrl = null,
        collectionId = null,
        collectionName = null;
  // 생성자: 장소 메시지
  ChatMessage.place({
    required this.senderId,
    required this.placeId,
    required this.placeName,
    this.placeImage,
  })  : type = MessageType.place,
        text = null,
        courseId = null,
        courseName = null,
        imageUrl = null,
        collectionId = null,
        collectionName = null;
  // 생성자: 코스 메시지
  ChatMessage.course({
    required this.senderId,
    required this.courseId,
    required this.courseName,
  })  : type = MessageType.course,
        text = null,
        placeId = null,
        placeName = null,
        placeImage = null,
        imageUrl = null,
        collectionId = null,
        collectionName = null;

  // 생성자: 이미지 메시지
  ChatMessage.image({
    required this.senderId,
    required this.imageUrl,
  })  : type = MessageType.image,
        text = null,
        placeId = null,
        placeName = null,
        placeImage = null,
        courseId = null,
        courseName = null,
        collectionId = null,
        collectionName = null;

  // 생성자: 컬렉션 메시지
  ChatMessage.collection({
    required this.senderId,
    required this.collectionId,
    required this.collectionName,
  })  : type = MessageType.collection,
        text = null,
        placeId = null,
        placeName = null,
        placeImage = null,
        courseId = null,
        courseName = null,
        imageUrl = null;

  /// 서버로 전송할 때 사용
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'type': type.toString().split('.').last,
      'sender_id': senderId,
    };
    switch (type) {
      case MessageType.text:
        map['content'] = text;
        break;
      case MessageType.place:
        map['place_id'] = placeId;
        break;
      case MessageType.course:
        map['course_id'] = courseId;
        break;
      case MessageType.image:
        map['image_url'] = imageUrl;
        break;
      case MessageType.collection:
        map['collection_id'] = collectionId;
        break;
    }
    return map;
  }
}
