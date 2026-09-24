import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../models/node_model.dart';
import '../services/mqtt_service.dart';
import '../services/node_service.dart';
import '../services/notification_service.dart';

class DeviceProvider extends ChangeNotifier {
  final MqttService _mqttService = MqttService();
  final NodeService _nodeService = NodeService();
  StreamSubscription? _mqttSubscription;

  List<NodeModel> _nodes = [];
  List<NodeModel> get nodes => _nodes;

  final Map<String, Timer?> _watchdogs = {};

  bool get isMqttConnected => _mqttService.isConnected;

  DeviceProvider() {
    _init();
  }

  Future<void> _init() async {
    await fetchNodes();
    await _connectMqtt();
  }

  Future<void> fetchNodes() async {
    _nodes = await _nodeService.getNodes();
    if (_mqttService.isConnected) {
      _mqttService.subscribeNodes(_nodes);
    }
    // Subscribe FCM cho tất cả các thiết bị lấy về
    // for (var node in _nodes) {
    //   if (node.chipId.isNotEmpty) {
    //     FirebaseMessaging.instance.subscribeToTopic('alert_${node.chipId}');
    //   }
    // }
    notifyListeners();
  }

  Future<void> _connectMqtt() async {
    final connected = await _mqttService.connect();
    if (connected) {
      _mqttSubscription?.cancel();
      _mqttSubscription = _mqttService.messages.listen((data) {
        _handleMqttMessage(data['topic']!, data['raw']!.toString());
      });
      _mqttService.subscribeNodes(_nodes);
      notifyListeners();
    }
  }

  Future<void> addNode(String name, String chipId, String templateType) async {
    final newNode = await _nodeService.createNode(name, chipId, templateType);
    if (newNode != null) {
      _nodes.add(newNode);
      _mqttService.subscribeNodes(_nodes);
      
      // Bắt đầu nhận Push Notification từ Node mới
      // if (newNode.chipId.isNotEmpty) {
      //   FirebaseMessaging.instance.subscribeToTopic('alert_${newNode.chipId}');
      // }
      
      notifyListeners();
    }
  }

  Future<void> removeNode(String id) async {
    final nodeToRemove = getNodeById(id);
    final success = await _nodeService.deleteNode(id);
    if (success) {
      if (nodeToRemove != null && nodeToRemove.chipId.isNotEmpty) {
        // Ngừng nhận Push Notification từ Node đã xóa
        // FirebaseMessaging.instance.unsubscribeFromTopic('alert_${nodeToRemove.chipId}');
      }
      _nodes.removeWhere((n) => n.id == id);
      _watchdogs[id]?.cancel();
      _watchdogs.remove(id);
      _mqttService.subscribeNodes(_nodes);
      notifyListeners();
    }
  }

  NodeModel? getNodeById(String id) {
    try {
      return _nodes.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }

  void _resetWatchdog(String nodeId) {
    final nodeIndex = _nodes.indexWhere((n) => n.id == nodeId);
    if (nodeIndex == -1) return;

    if (!_nodes[nodeIndex].isOnline) {
      _nodes[nodeIndex].isOnline = true;
      notifyListeners();
    }

    _watchdogs[nodeId]?.cancel();
    _watchdogs[nodeId] = Timer(const Duration(seconds: 5), () {
      final idx = _nodes.indexWhere((n) => n.id == nodeId);
      if (idx != -1 && _nodes[idx].isOnline) {
        _nodes[idx].isOnline = false;
        notifyListeners();
      }
    });
  }

  void _handleMqttMessage(String topic, String payload) {
    // Handle raw LWT and Heartbeat messages
    if (payload == "online" || payload == "offline") {
      final isOnline = payload == "online";
      for (var node in _nodes) {
        if (node.chipId.isNotEmpty && topic.contains(node.chipId)) {
          if (isOnline) {
            _resetWatchdog(node.id);
          } else {
            node.isOnline = false;
            _watchdogs[node.id]?.cancel();
            notifyListeners();
          }
          break;
        }
      }
      return;
    }

    try {
      final data = jsonDecode(payload);
      final value = data['value'];

      for (int i = 0; i < _nodes.length; i++) {
        final node = _nodes[i];
        if (node.chipId.isNotEmpty && topic.contains(node.chipId)) {
          _resetWatchdog(node.id);

          bool stateChanged = false;

          // Bếp & Khách variables
          if (topic.endsWith('_temp_livingroom/status')) {
            node.state['temperature'] = (value is num) ? value.toDouble() : double.tryParse(value.toString()) ?? node.state['temperature'];
            stateChanged = true;
          } else if (topic.endsWith('_humi_living_room/status')) {
            node.state['humidity'] = (value is num) ? value.toDouble() : double.tryParse(value.toString()) ?? node.state['humidity'];
            stateChanged = true;
          } else if (topic.endsWith('_led1/status')) {
            node.state['light'] = (value.toString().toUpperCase() == "ON");
            stateChanged = true;
          } else if (topic.endsWith('_fan_livingroom/status')) {
            node.state['fan'] = (value.toString().toUpperCase() == "ON");
            stateChanged = true;
          } else if (topic.endsWith('_door_livingroom1/status')) {
            final double angle = (value is num) ? value.toDouble() : double.tryParse(value.toString()) ?? 0;
            node.state['doorAngle'] = angle;
            node.state['door'] = angle > 0;
            stateChanged = true;
          } else if (topic.endsWith('_dryer_livingroom/status')) {
            final double angle = (value is num) ? value.toDouble() : double.tryParse(value.toString()) ?? 0;
            node.state['clothesDryerAngle'] = angle;
            node.state['clothesDryer'] = angle > 0;
            stateChanged = true;
          } else if (topic.endsWith('_gas_livingroom/status')) {
            final bool newGas = (value.toString().toUpperCase() == "ON" || value == 1 || value == true || value.toString() == "1");
            if (newGas && node.state['gasDetector'] != true) {
              NotificationService().showWarningNotification(
                id: node.id.hashCode,
                title: '⚠️ Cảnh báo khẩn cấp',
                body: 'Phát hiện rò rỉ khí gas tại ${node.name}!',
              );
            }
            node.state['gasDetector'] = newGas;
            stateChanged = true;
          } else if (topic.endsWith('_fire_livingroom/status')) {
            final bool newFire = (value.toString().toUpperCase() == "ON" || value == 1 || value == true || value.toString() == "1");
            if (newFire && node.state['fireDetector'] != true) {
              NotificationService().showWarningNotification(
                id: node.id.hashCode + 1,
                title: '🔥 Báo cháy khẩn cấp',
                body: 'Phát hiện có lửa tại ${node.name}! Hãy sơ tán ngay!',
              );
            }
            node.state['fireDetector'] = newFire;
            stateChanged = true;
          } else if (topic.endsWith('_rain_livingroom/status')) {
            final bool newRain = (value.toString().toUpperCase() == "ON" || value == 1 || value == true || value.toString() == "1");
            if (newRain && node.state['rainDetector'] != true) {
              NotificationService().showWarningNotification(
                id: node.id.hashCode + 2,
                title: '🌧️ Cảnh báo trời mưa',
                body: 'Phát hiện có mưa tại ${node.name}! Dàn phơi đã tự động đóng.',
              );
            }
            node.state['rainDetector'] = newRain;
            stateChanged = true;
          }

          // Phòng Ngủ variables
          else if (topic.endsWith('_led_bedroom/status')) {
            node.state['bedroomLight'] = (value.toString().toUpperCase() == "ON");
            stateChanged = true;
          } else if (topic.endsWith('_fan_bedroom/status')) {
            node.state['bedroomFan'] = (value.toString().toUpperCase() == "ON");
            stateChanged = true;
          } else if (topic.endsWith('_curtain/status')) {
            final double angle = (value is num) ? value.toDouble() : double.tryParse(value.toString()) ?? 0;
            node.state['curtainAngle'] = angle;
            node.state['curtain'] = angle > 0;
            stateChanged = true;
          }

          if (stateChanged) {
            // Có thể dùng Debounce ở đây nếu muốn update Backend liên tục
            // _nodeService.updateNodeState(node.id, node.state);
            notifyListeners();
          }
          break; // Đã match node thì thoát vòng lặp
        }
      }
    } catch (e) {
      if (kDebugMode) print("Lỗi parse MQTT Payload: $e - Payload raw: $payload");
    }
  }

  // ─── Actions: Bếp & Khách ─────────────────────────────────────────────────
  void toggleKitchenLight(String nodeId) {
    final node = getNodeById(nodeId);
    if (node == null || !node.isOnline) return;
    final newState = !node.light;
    node.state['light'] = newState;
    _mqttService.publishCommand(node.chipId, 'led1', newState ? "ON" : "OFF");
    _nodeService.updateNodeState(node.id, node.state);
    notifyListeners();
  }

  void toggleKitchenFan(String nodeId) {
    final node = getNodeById(nodeId);
    if (node == null || !node.isOnline) return;
    final newState = !node.fan;
    node.state['fan'] = newState;
    _mqttService.publishCommand(node.chipId, 'fan_livingroom', newState ? "ON" : "OFF");
    _nodeService.updateNodeState(node.id, node.state);
    notifyListeners();
  }

  void toggleKitchenDoor(String nodeId) {
    final node = getNodeById(nodeId);
    if (node == null || !node.isOnline) return;
    final newState = !node.door;
    node.state['door'] = newState;
    node.state['doorAngle'] = newState ? 90.0 : 0.0;
    _mqttService.publishCommand(node.chipId, 'door_livingroom1', newState ? "ON" : "OFF");
    _nodeService.updateNodeState(node.id, node.state);
    notifyListeners();
  }

  void toggleClothesDryer(String nodeId) {
    final node = getNodeById(nodeId);
    if (node == null || !node.isOnline) return;
    final newState = !node.clothesDryer;
    node.state['clothesDryer'] = newState;
    node.state['clothesDryerAngle'] = newState ? 90.0 : 0.0;
    _mqttService.publishCommand(node.chipId, 'dryer_livingroom', newState ? "ON" : "OFF");
    _nodeService.updateNodeState(node.id, node.state);
    notifyListeners();
  }

  void setKitchenDoorAngle(String nodeId, double angle) {
    final node = getNodeById(nodeId);
    if (node == null || !node.isOnline) return;
    node.state['doorAngle'] = angle;
    node.state['door'] = angle > 0;
    _mqttService.publishCommand(node.chipId, 'door_livingroom1', angle.toStringAsFixed(0));
    _nodeService.updateNodeState(node.id, node.state);
    notifyListeners();
  }

  void setClothesDryerAngle(String nodeId, double angle) {
    final node = getNodeById(nodeId);
    if (node == null || !node.isOnline) return;
    node.state['clothesDryerAngle'] = angle;
    node.state['clothesDryer'] = angle > 0;
    _mqttService.publishCommand(node.chipId, 'dryer_livingroom', angle.toStringAsFixed(0));
    _nodeService.updateNodeState(node.id, node.state);
    notifyListeners();
  }

  // ─── Actions: Phòng Ngủ ───────────────────────────────────────────────────
  void toggleBedroomLight(String nodeId) {
    final node = getNodeById(nodeId);
    if (node == null || !node.isOnline) return;
    final newState = !node.bedroomLight;
    node.state['bedroomLight'] = newState;
    _mqttService.publishCommand(node.chipId, 'led_bedroom', newState ? "ON" : "OFF");
    _nodeService.updateNodeState(node.id, node.state);
    notifyListeners();
  }

  void toggleBedroomFan(String nodeId) {
    final node = getNodeById(nodeId);
    if (node == null || !node.isOnline) return;
    final newState = !node.bedroomFan;
    node.state['bedroomFan'] = newState;
    _mqttService.publishCommand(node.chipId, 'fan_bedroom', newState ? "ON" : "OFF");
    _nodeService.updateNodeState(node.id, node.state);
    notifyListeners();
  }

  void toggleCurtain(String nodeId) {
    final node = getNodeById(nodeId);
    if (node == null || !node.isOnline) return;
    final newState = !node.curtain;
    node.state['curtain'] = newState;
    node.state['curtainAngle'] = newState ? 90.0 : 0.0;
    _mqttService.publishCommand(node.chipId, 'curtain', newState ? "ON" : "OFF");
    _nodeService.updateNodeState(node.id, node.state);
    notifyListeners();
  }

  void setCurtainAngle(String nodeId, double angle) {
    final node = getNodeById(nodeId);
    if (node == null || !node.isOnline) return;
    node.state['curtainAngle'] = angle;
    node.state['curtain'] = angle > 0;
    _mqttService.publishCommand(node.chipId, 'curtain', angle.toStringAsFixed(0));
    _nodeService.updateNodeState(node.id, node.state);
    notifyListeners();
  }

  @override
  void dispose() {
    _mqttSubscription?.cancel();
    for (var timer in _watchdogs.values) {
      timer?.cancel();
    }
    _mqttService.disconnect();
    super.dispose();
  }
}
