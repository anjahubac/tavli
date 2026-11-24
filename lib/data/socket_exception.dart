// `SocketException` iz `dart:io` na svim platformama osim weba. U pregledaču
// `dart:io` ne postoji, a prekid veze stiže kao `http.ClientException`, koju
// svaki poziv već hvata; ovde je samo tip koji se nikad ne baca.
export 'socket_exception_io.dart'
    if (dart.library.js_interop) 'socket_exception_web.dart';
