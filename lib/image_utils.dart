import 'constants.dart';

String resolveImageUrl(String url) =>
    url.startsWith('http') ? url : '$BASE_URL$url';
