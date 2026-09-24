const { Aedes } = require('aedes');
const { createServer: createNetServer } = require('node:net');
const { createServer: createHttpServer } = require('node:http');
const { WebSocketServer, createWebSocketStream } = require('ws');

const TCP_PORT = process.env.MQTT_TCP_PORT || 1883;
const WS_PORT = process.env.MQTT_WS_PORT || 8083;

async function startBroker() {
  const aedes = await Aedes.createBroker();

  // 1. MQTT qua TCP (Port 1883) - Thiết bị ESP8266 trong mạng LAN kết nối trực tiếp
  const tcpServer = createNetServer(aedes.handle);
  tcpServer.listen(TCP_PORT, '0.0.0.0', () => {
    console.log(`🚀 [MQTT TCP] Broker đang chạy tại cổng: ${TCP_PORT} (Dành cho ESP / LAN: mqtt://localhost:${TCP_PORT})`);
  });

  // 2. MQTT qua WebSocket (Port 8083) - Dành riêng cho Cloudflare Tunnel
  const wsHttpServer = createHttpServer((req, res) => {
    if (req.url === '/' || req.url === '/health' || req.url === '/mqtt') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ status: 'ok', service: 'AloT MQTT WebSocket Broker', wsPort: WS_PORT }));
    } else {
      res.writeHead(404);
      res.end();
    }
  });

  const wss = new WebSocketServer({
    server: wsHttpServer,
    handleProtocols: (protocols, req) => {
      const protoArr = Array.from(protocols);
      if (protoArr.length > 0) {
        return protoArr[0];
      }
      return 'mqtt';
    }
  });

  wss.on('connection', (websocket, req) => {
    const stream = createWebSocketStream(websocket);
    aedes.handle(stream, req);
  });

  wsHttpServer.listen(WS_PORT, '0.0.0.0', () => {
    console.log(`🌐 [MQTT WebSocket] Broker đang chạy tại cổng: ${WS_PORT}`);
    console.log(`👉 Cấu hình Cloudflare Tunnel:`);
    console.log(`   Type: HTTP`);
    console.log(`   URL : 127.0.0.1:${WS_PORT}`);
  });

  // --- LẮNG NGHE SỰ KIỆN BROKER ---
  aedes.on('client', (client) => {
    console.log(`📱 [MQTT] Client kết nối: [ID: ${client ? client.id : 'N/A'}]`);
  });

  aedes.on('clientDisconnect', (client) => {
    console.log(`🔌 [MQTT] Client ngắt kết nối: [ID: ${client ? client.id : 'N/A'}]`);
  });

  aedes.on('subscribe', (subscriptions, client) => {
    const topics = subscriptions.map(s => s.topic).join(', ');
    console.log(`📡 [MQTT Subscribe] Client [${client ? client.id : 'N/A'}] sub: ${topics}`);
  });

  aedes.on('publish', (packet, client) => {
    if (client && !packet.topic.startsWith('$SYS')) {
      const payload = packet.payload ? packet.payload.toString() : '';
      console.log(`📩 [MQTT Publish] [${packet.topic}]: ${payload}`);
    }
  });

  tcpServer.on('error', (err) => {
    console.error('❌ [MQTT TCP] Lỗi:', err.message);
  });

  wsHttpServer.on('error', (err) => {
    console.error('❌ [MQTT WS] Lỗi:', err.message);
  });
}

startBroker().catch((err) => {
  console.error('❌ Lỗi khởi động MQTT Broker:', err);
});
