const mqtt = require('mqtt');
const Node = require('../models/node.model');
const { getMessaging } = require('firebase-admin/messaging');

class MqttService {
  constructor() {
    this.client = null;
    this.subscribedTopics = new Set();
    this.envCache = { T: 0, H: 0, Gas: "0", Fire: "0" };
  }

  async connect() {
    // Ưu tiên biến môi trường MQTT_URL, mặc định kết nối broker local
    const mqttUrl = process.env.MQTT_URL || 'mqtt://127.0.0.1:1883';
    console.log(`🔌 Đang kết nối tới MQTT Broker: ${mqttUrl}`);
    
    this.client = mqtt.connect(mqttUrl, {
      clientId: `backend_server_${Math.random().toString(16).slice(2, 8)}`,
      keepalive: 60,
      reconnectPeriod: 2000,
      clean: true
    });

    this.client.on('connect', async () => {
      console.log('✅ Backend đã kết nối MQTT thành công!');
      await this.subscribeAllNodes();
    });

    this.client.on('error', (err) => {
      console.error('❌ Lỗi kết nối MQTT:', err);
    });

    this.client.on('message', this.handleMessage.bind(this));
  }

  async subscribeAllNodes() {
    try {
      const nodes = await Node.find({});
      nodes.forEach(node => {
        this.subscribeNode(node);
      });
    } catch (err) {
      console.error('Lỗi khi lấy danh sách Node để subscribe:', err.message);
    }
  }

  subscribeNode(node) {
    if (!this.client || !node.chipId) return;
    
    const chipId = node.chipId;
    
    // Subscribe các topic cảnh báo của Bếp & Khách (vì cảm biến Gas/Fire ở đây)
    if (node.templateType === 'kitchen_living') {
      const topicsToSubscribe = [
        `tele/${chipId}_gas_livingroom/status`,
        `tele/${chipId}_fire_livingroom/status`,
        `tele/${chipId}_temp_livingroom/status`,
        `tele/${chipId}_humi_living_room/status`
      ];
      
      topicsToSubscribe.forEach(t => {
        if (!this.subscribedTopics.has(t)) {
          this.client.subscribe(t);
          this.subscribedTopics.add(t);
        }
      });
      console.log(`📡 Backend đã subscribe cảnh báo & môi trường cho Node: ${chipId}`);
    }
  }

  async handleMessage(topic, message) {
    const payloadStr = message.toString();
    let value;
    
    try {
      const json = JSON.parse(payloadStr);
      value = json.value;
    } catch (e) {
      value = payloadStr.trim();
    }

    // --- Cập nhật Cache cho XiaoZhi ---
    if (topic.includes('_temp_')) this.envCache.T = parseFloat(value);
    if (topic.includes('_humi_')) this.envCache.H = parseFloat(value);
    if (topic.includes('_gas_')) this.envCache.Gas = (value == "ON" || value == 1) ? "1" : "0";
    if (topic.includes('_fire_')) this.envCache.Fire = (value == "ON" || value == 1) ? "1" : "0";

    // Kiểm tra có phải báo động không (ON hoặc 1)
    const isAlert = (value.toString().toUpperCase() === "ON" || value == 1 || value === true || value.toString() === "1");
    
    if (!isAlert) return; // Nếu OFF thì bỏ qua

    // Phân tích Topic để tìm chipId và loại cảnh báo
    // Cấu trúc topic: tele/esp_123_gas_livingroom/status
    const topicParts = topic.split('/');
    if (topicParts.length < 3) return;

    const identifier = topicParts[1]; // vd: esp_123_gas_livingroom
    let alertType = '';
    let chipId = '';

    if (identifier.includes('_gas_livingroom')) {
      alertType = 'gas';
      chipId = identifier.replace('_gas_livingroom', '');
    } else if (identifier.includes('_fire_livingroom')) {
      alertType = 'fire';
      chipId = identifier.replace('_fire_livingroom', '');
    } else {
      return;
    }

    // Gửi FCM Push Notification
    this.sendPushNotification(chipId, alertType);
  }

  async sendPushNotification(chipId, alertType) {
    try {
      // Tìm thông tin Node trong DB để lấy tên phòng
      const node = await Node.findOne({ chipId: chipId });
      const roomName = node ? node.name : chipId;

      const title = alertType === 'fire' ? '🔥 Báo cháy khẩn cấp!' : '⚠️ Cảnh báo rò rỉ Gas!';
      const body = alertType === 'fire' 
        ? `Phát hiện có lửa tại ${roomName}! Hãy sơ tán ngay!`
        : `Phát hiện rò rỉ khí gas tại ${roomName}! Mở cửa thông gió và tránh tia lửa!`;

      // Gửi FCM tới topic cụ thể của Chip ID đó
      const topic = `alert_${chipId}`;

      const message = {
        data: {
          title: title,
          body: body,
          alertType: alertType
        },
        android: {
          priority: 'high',
          directBootOk: true
        },
        topic: topic
      };

      const response = await getMessaging().send(message);
      console.log(`🔔 Đã gửi Push Notification FCM (Topic: ${topic}) thành công:`, response);
    } catch (error) {
      console.error('❌ Lỗi khi gửi FCM:', error);
    }
  }
}

module.exports = new MqttService();
