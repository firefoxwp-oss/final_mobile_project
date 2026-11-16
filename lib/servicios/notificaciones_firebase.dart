import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'servicio_notificaciones.dart';

/// Canal de Android de las notificaciones de procesamiento; es el mismo que
/// indica el servidor en cada mensaje.
const AndroidNotificationChannel canalProcesamientos =
    AndroidNotificationChannel(
      'procesamientos',
      'Procesamientos',
      description: 'Aviso cuando una canción termina de procesarse',
      importance: Importance.high,
    );

/// Mensajería push con Firebase Cloud Messaging.
///
/// Usa el token de registro, que es lo que el servidor envía con la API HTTP
/// v1 de FCM. `register()` y `onRegistered` (que reemplazan a `getToken()` en
/// firebase_messaging 17) entregan otro identificador, el de la instalación,
/// pensado para otro modo de envío; por eso se conservan las llamadas por
/// token.
class MensajeriaFirebase implements MensajeriaPush {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  @override
  Future<void> pedirPermiso() async {
    await _fcm.requestPermission();
  }

  @override
  // ignore: deprecated_member_use
  Future<String?> obtenerToken() => _fcm.getToken();

  @override
  // ignore: deprecated_member_use
  Stream<String> get tokensRenovados => _fcm.onTokenRefresh;

  @override
  Stream<NotificacionRecibida> get notificacionesEnPrimerPlano =>
      FirebaseMessaging.onMessage
          .where((RemoteMessage m) => m.notification != null)
          .map(
            (RemoteMessage m) => NotificacionRecibida(
              titulo: m.notification!.title ?? '',
              texto: m.notification!.body ?? '',
              datos: <String, String>{
                for (final MapEntry<String, dynamic> e in m.data.entries)
                  e.key: '${e.value}',
              },
            ),
          );

  @override
  // ignore: deprecated_member_use
  Future<void> borrarToken() => _fcm.deleteToken();
}

/// Notificaciones locales en la barra del sistema de Android.
class MostradorLocal implements MostradorNotificaciones {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _preparado = false;

  @override
  Future<void> preparar() async {
    if (_preparado) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(canalProcesamientos);
    _preparado = true;
  }

  @override
  Future<void> mostrar(int id, String titulo, String texto) => _plugin.show(
    id: id,
    title: titulo,
    body: texto,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        canalProcesamientos.id,
        canalProcesamientos.name,
        channelDescription: canalProcesamientos.description,
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );
}
