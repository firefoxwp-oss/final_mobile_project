import 'dart:async';

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

  @override
  Stream<String> get cancionesTocadas => FirebaseMessaging.onMessageOpenedApp
      .map(_cancion)
      .where((String? c) => c != null)
      .cast<String>();

  @override
  Future<String?> cancionAlAbrir() async {
    final RemoteMessage? mensaje = await _fcm.getInitialMessage();
    return mensaje == null ? null : _cancion(mensaje);
  }

  String? _cancion(RemoteMessage mensaje) => mensaje.data['job_id'] as String?;
}

/// Notificaciones locales en la barra del sistema de Android.
class MostradorLocal implements MostradorNotificaciones {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<String> _tocadas =
      StreamController<String>.broadcast();
  bool _preparado = false;

  @override
  Future<void> preparar() async {
    if (_preparado) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse respuesta) {
        final String? cancion = respuesta.payload;
        if (cancion != null) _tocadas.add(cancion);
      },
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(canalProcesamientos);
    _preparado = true;
  }

  @override
  Future<void> mostrar(
    int id,
    String titulo,
    String texto, {
    String? cancion,
  }) => _plugin.show(
    id: id,
    title: titulo,
    body: texto,
    payload: cancion,
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

  @override
  Stream<String> get cancionesTocadas => _tocadas.stream;

  @override
  Future<String?> cancionAlAbrir() async {
    final NotificationAppLaunchDetails? inicio = await _plugin
        .getNotificationAppLaunchDetails();
    if (!(inicio?.didNotificationLaunchApp ?? false)) return null;
    return inicio?.notificationResponse?.payload;
  }
}
