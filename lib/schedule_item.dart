class ScheduleItem {
  // (앞쪽 로직에서는 mainCategory, subCategory, travelInfo, maxDistance 등도 담는데,
  //  여기서는 실제 “추천받은 결과”에 필요한 필드만 포함해둡니다.)
  String? placeId;
  String? placeName;
  String? placeAddress;
  String? placeImage;
  String? travelInfo;
  String? maxDistance;

  ScheduleItem({
    this.placeId,
    this.placeName,
    this.placeAddress,
    this.placeImage,
    this.travelInfo,
    this.maxDistance,
  });

  /// 서버에서 내려준 JSON을 기반으로 객체를 생성할 때,
  /// JSON 필드명이 실제 서버와 1:1 매칭되어야 합니다.
  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    return ScheduleItem(
      placeId: json['id']?.toString() ??
          json['placeId']?.toString() ??
          json['place_id']?.toString(),
      // 백엔드에서 camelCase 혹은 snake_case 로 내려올 수 있으므로 두 경우 모두 처리
      placeName: json['placeName'] as String? ?? json['place_name'] as String?,
      placeAddress:
          json['placeAddress'] as String? ?? json['place_address'] as String?,
      placeImage:
          json['placeImage'] as String? ?? json['place_image'] as String?,

      travelInfo:
          json['travelInfo'] as String? ?? json['travel_info'] as String?,
      maxDistance:
          json['maxDistance'] as String? ?? json['max_distance'] as String?,
    );
  }

  /// Flutter → 서버로 “AI 코스 요청”을 보낼 때 사용하는 toJson()
  Map<String, dynamic> toJson() {
    return {
      // AI 요청용 payload. (메인/서브 카테고리, travelInfo, maxDistance 등)
      'main_category': mainCategory,
      'sub_category': subCategory,
      'travel_info': travelInfo,
      'max_distance': maxDistance,
      // 추천 결과 보여줄 때 place_id 등은 서버에서 내려줍니다.
    };
  }

  Map<String, dynamic> toCourseJson() {
    return {
      'placeId': placeId,
      'placeName': placeName,
      'placeAddress': placeAddress,
      'placeImage': placeImage,
      'main_category': mainCategory,
      'sub_category': subCategory,
      'travel_info': travelInfo,
      'max_distance': maxDistance,
    };
  }

  // (실제 저장할 데이터가 더 필요하다면 여기에 필드를 추가하십시오.)
  String? mainCategory;
  String? subCategory;
}

/*class CourseModel {
  final int id;
  final int userId;
  final String courseName;
  final String courseDescription;
  final List<String> hashtags; // e.g. ['야경','데이트']
  final DateTime? selectedDate; // e.g. "2025-06-05"
  final List<String> withWho; // e.g. ['연인과', '가족과']
  final List<String> purpose; // e.g. ['데이트','맛집탐방']
  final List<ScheduleItem> schedules; // 일정(장소) 리스트

  CourseModel({
    required this.id,
    required this.userId,
    required this.courseName,
    required this.courseDescription,
    required this.hashtags,
    this.selectedDate,
    required this.withWho,
    required this.purpose,
    required this.schedules,
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    // JSON 구조에 맞춰 필드를 파싱합니다.
    // (만약 JSON 키명이 다르다면 여기에서 adjust)
    return CourseModel(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      courseName: json['course_name'] as String? ?? '',
      courseDescription: json['course_description'] as String? ?? '',
      hashtags: (json['hashtags'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      selectedDate: json['selected_date'] != null
          ? DateTime.parse(json['selected_date'] as String)
          : null,
      withWho: (json['with_who'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      purpose: (json['purpose'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      schedules: (json['schedules'] as List<dynamic>? ?? [])
          .map((sch) => ScheduleItem.fromJson(sch as Map<String, dynamic>))
          .toList(),
    );
  }
}*/
class CourseModel {
  final int id;
  final int userId;
  final String courseName;
  final String courseDescription;
  final List<String> hashtags;
  final DateTime? selectedDate;
  final List<String> withWho;
  final List<String> purpose;
  final List<ScheduleItem> schedules;

  CourseModel({
    required this.id,
    required this.userId,
    required this.courseName,
    required this.courseDescription,
    required this.hashtags,
    this.selectedDate,
    required this.withWho,
    required this.purpose,
    required this.schedules,
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    // ’id’ 칼럼은 반드시 들어온다고 가정 (DB 제약조건)
    final rawId = json['id'];
    if (rawId == null) {
      throw Exception("CourseModel.fromJson: 'id'가 null 입니다. JSON: $json");
    }

    // 서버에서 넘어오는 key 이름이 'userId' 이므로, 'user_id'가 아니라 'userId'로 읽어야 함
    final rawUserId = json['userId'];
    if (rawUserId == null) {
      throw Exception("CourseModel.fromJson: 'userId'가 null 입니다. JSON: $json");
    }

    // hashtags, withWho, purpose 등은 배열이거나 null 일 수 있으므로 null 체크 후 빈 리스트로 변환
    final rawHashtags = json['hashtags'] as List<dynamic>?;
    final rawWithWho = json['withWho'] as List<dynamic>?;
    final rawPurpose = json['purpose'] as List<dynamic>?;

    // schedules 필드 역시 null 가능성을 고려
    final rawSchedules = json['schedules'] as List<dynamic>?;

    return CourseModel(
      // id와 userId는 숫자 혹은 문자열 형태로 들어올 수 있으므로 안전하게 파싱
      id: rawId is int ? rawId : int.parse(rawId.toString()),
      userId: rawUserId is int ? rawUserId : int.parse(rawUserId.toString()),

      // courseName, courseDescription도 camelCase 로 내려오므로 그대로 꺼냅니다
      courseName: (json['courseName'] as String?) ?? '',
      courseDescription: (json['courseDescription'] as String?) ?? '',

      // hashtags, withWho, purpose 는 TEXT[] 타입이므로 리스트로 변환하거나 빈 리스트로 초기화
      hashtags: rawHashtags != null
          ? rawHashtags.map((e) => e.toString()).toList()
          : <String>[],

      // selectedDate 는 문자열로 내려올 수 있으므로 tryParse
      selectedDate: json['selectedDate'] != null
          ? DateTime.tryParse(json['selectedDate'] as String)
          : null,

      // withWho, purpose 도 LIST<String> 으로 변환
      withWho: rawWithWho != null
          ? rawWithWho.map((e) => e.toString()).toList()
          : <String>[],

      purpose: rawPurpose != null
          ? rawPurpose.map((e) => e.toString()).toList()
          : <String>[],

      // schedules 배열 안에 있는 JSON 객체도 ScheduleItem.fromJson 을 통해 변환
      schedules: rawSchedules != null
          ? rawSchedules
              .map((sch) => ScheduleItem.fromJson(sch as Map<String, dynamic>))
              .toList()
          : <ScheduleItem>[],
    );
  }
}
