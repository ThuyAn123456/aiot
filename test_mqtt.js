const mqtt = require('mqtt');

const brokerUrl = process.env.MQTT_URL || 'wss://mqtt.iot.pro.vn/mqtt';
console.log(`🔌 Đang kết nối tới Broker: ${brokerUrl}`);
const client = mqtt.connect(brokerUrl, {
  clientId: 'test_node_client_' + Math.random().toString(16).substr(2, 8),
});

client.on('connect', () => {
  console.log('✅ Connected to MQTT broker via WSS!');
  client.subscribe('tele/#', (err) => {
    if (!err) {
      console.log('✅ Subscribed to tele/#');
    }
  });
});

client.on('message', (topic, message) => {
  console.log(`📩 [${topic}] ${message.toString()}`);
});

client.on('error', (error) => {
  console.error('❌ Connection error:', error);
});

client.on('offline', () => {
  console.log('⚠️ Client went offline');
});
