import 'dart:convert';

import 'package:http/http.dart' as http;

/// Lažan JWT (nije potpisan, samo `exp`); pravi se pri izvršavanju, da u
/// repozitorijumu ne postoji ništa nalik pravom tokenu.
String fakeJwt({Duration validFor = const Duration(hours: 1)}) {
  String part(Map<String, Object?> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().add(validFor).millisecondsSinceEpoch ~/ 1000;
  return '${part({'alg': 'none'})}.${part({'exp': exp, 'sub': 'u1'})}.fake';
}

/// Odgovor GoTrue-a sa sesijom.
Map<String, Object?> sessionBody({
  String userId = 'u1',
  String email = 'ana@mail.com',
  Duration validFor = const Duration(hours: 1),
}) => {
  'access_token': fakeJwt(validFor: validFor),
  'token_type': 'bearer',
  'expires_in': validFor.inSeconds,
  'refresh_token': 'fake-refresh',
  'user': {
    'id': userId,
    'email': email,
    'aud': 'authenticated',
    'created_at': '2026-10-30T12:00:00Z',
    'app_metadata': <String, Object?>{},
    'user_metadata': <String, Object?>{},
  },
};

http.Response jsonResponse(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const fakeUrl = 'http://supabase.test';
const fakeAnonKey = 'fake-anon-key';
