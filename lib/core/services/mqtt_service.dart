import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/node_model.dart';

class MqttService extends ChangeNotifier {
  static const String broker = 'mqtt.iot.pro.vn';
  static const int port = 443;
  
  MqttServerClient? _client;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  List<NodeModel> _currentNodes = [];

  // Stream để truyền dữ liệu sang DeviceProvider
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  MqttService();

  // ═══════════════════════════════════════════════════════════
  //  KẾT NỐI
  // ═══════════════════════════════════════════════════════════
  Future<bool> connect() async {
    if (_isConnected) {
      return true;
    }

    final clientId = 'flutter_${DateTime.now().millisecondsSinceEpoch}';

    _client = MqttServerClient('wss://mqtt.iot.pro.vn/mqtt', clientId);
    _client!.port = port;
    _client!.useWebSocket = true;
    _client!.websocketProtocols = MqttClientConstants.protocolsSingleDefault;
    
    _client!.logging(on: false); 
    _client!.keepAlivePeriod = 60;
    _client!.autoReconnect = true;
    _client!.onConnected = _onConnected;
    _client!.onDisconnected = _onDisconnected;
    _client!.onAutoReconnect = _onAutoReconnect;
    _client!.onAutoReconnected = _onAutoReconnected;
    _client!.onSubscribed = _onSubscribed;

    final connMsg = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillTopic('tele/flutter_app/status')
        .withWillMessage('offline')
        .withWillRetain()
        .withWillQos(MqttQos.atLeastOnce);

    _client!.connectionMessage = connMsg;

    try {
      if (kDebugMode) print('MQTT: Đang kết nối tới ${_client!.server} qua port ${_client!.port} ...');
      await _client!.connect().timeout(const Duration(seconds: 10));
    } catch (e) {
      if (kDebugMode) print('MQTT: Lỗi kết nối - $e');
      _isConnected = false;
      notifyListeners();
      return false;
    }

    if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
      _isConnected = true;
      _listenMessages();
      notifyListeners();
      return true;
    }

    return false;
  }

  // ═══════════════════════════════════════════════════════════
  //  SUBSCRIBE TỰ ĐỘNG THEO DANH SÁCH NODE
  // ═══════════════════════════════════════════════════════════
  void subscribeNodes(List<NodeModel> nodes) {
    _currentNodes = nodes;
    if (_client == null || !_isConnected) return;
    
    final topics = <String>[];
    
    for (var node in nodes) {
      if (node.chipId.isEmpty) continue;
      final cId = node.chipId;
      
      topics.add('tele/$cId/status'); // Online/Offline status

      if (node.templateType == 'kitchen_living') {
        topics.addAll([
          'tele/${cId}_temp_livingroom/status',
          'tele/${cId}_humi_living_room/status',
          'tele/${cId}_led1/status',
          'tele/${cId}_fan_livingroom/status',
          'tele/${cId}_door_livingroom1/status',
          'tele/${cId}_gas_livingroom/status',
          'tele/${cId}_fire_livingroom/status',
          'tele/${cId}_rain_livingroom/status',
          'tele/${cId}_dryer_livingroom/status',
        ]);
      } else if (node.templateType == 'bedroom') {
        topics.addAll([
          'tele/${cId}_led_bedroom/status',
          'tele/${cId}_fan_bedroom/status',
          'tele/${cId}_curtain/status',
        ]);
      }
    }

    for (final t in topics) {
      _client!.subscribe(t, MqttQos.atLeastOnce);
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  LẮNG NGHE MESSAGE
  // ═══════════════════════════════════════════════════════════
  void _listenMessages() {
    _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      if (c == null || c.isEmpty) return;

      final recMsg = c[0].payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(
          recMsg.payload.message);
      final topic = c[0].topic;

      // if (kDebugMode) {
      //   print('MQTT RX: [$topic] → $payload');
      // }

      dynamic value;
      try {
        final json = jsonDecode(payload);
        value = json['value'];
      } catch (_) {
        value = payload.trim();
      }

      _messageController.add({
        'topic': topic,
        'value': value,
        'raw': payload,
      });
    });
  }

  // ═══════════════════════════════════════════════════════════
  //  PUBLISH LỆNH
  // ═══════════════════════════════════════════════════════════
  void publish(String topic, String message) {
    if (!_isConnected || _client == null) return;

    final builder = MqttClientPayloadBuilder();
    builder.addString(message);

    if (kDebugMode) print('MQTT TX: [$topic] → $message');

    _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  // Helper cho lệnh
  void publishCommand(String chipId, String deviceSuffix, String command) {
    publish('cmnd/${chipId}_$deviceSuffix/POWER', command);
  }

  // ═══════════════════════════════════════════════════════════
  //  CALLBACKS
  // ═══════════════════════════════════════════════════════════
  void _onConnected() {
    if (kDebugMode) print('MQTT: ✅ Đã kết nối thành công');
    _isConnected = true;
    notifyListeners();
  }

  void _onDisconnected() {
    if (kDebugMode) print('MQTT: ⚠️ Đã ngắt kết nối');
    _isConnected = false;
    notifyListeners();
  }

  void _onAutoReconnect() {
    if (kDebugMode) print('MQTT: 🔄 Đang tự động kết nối lại...');
  }

  void _onAutoReconnected() {
    if (kDebugMode) print('MQTT: ✅ Tự động kết nối lại thành công');
    _isConnected = true;
    subscribeNodes(_currentNodes);
    notifyListeners();
  }

  void _onSubscribed(String topic) {
    // if (kDebugMode) print('MQTT: 📡 Đã subscribe: $topic');
  }

  // ═══════════════════════════════════════════════════════════
  //  CLEANUP
  // ═══════════════════════════════════════════════════════════
  void disconnect() {
    _client?.disconnect();
    _isConnected = false;
    _currentNodes.clear();
    notifyListeners();
  }
}
