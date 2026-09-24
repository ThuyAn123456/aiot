const WebSocket = require('ws');
const mqttService = require('./mqtt.service');

// XIAOZHI MCP ENDPOINT (Từ log của user)
const XIAOZHI_URL = process.env.XIAOZHI_URL || "wss://api.xiaozhi.me/mcp/?token=eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjEwNzY3MDMsImFnZW50SWQiOjIzNTU1MDksImVuZHBvaW50SWQiOiJhZ2VudF8yMzU1NTA5IiwicHVycG9zZSI6Im1jcC1lbmRwb2ludCIsImlhdCI6MTc5MDE0NDM5MywiZXhwIjoxODIxNzAxOTkzfQ.ZOLrebcSkNUPeqtqW7Q_Bdd2EP3yvTW9uVqdqueJKr7wwwPse7AhmczSRCxtX2O3nMvqT6mUP-yk_pjnYppsmw";

// ID Mặc định của các phòng
const ID_LIVING = "123";
const ID_BEDROOM = "456";

class XiaoZhiService {
  constructor() {
    this.ws = null;
    this.reconnectTimeout = null;
  }

  connect() {
    console.log(`🤖 Đang kết nối tới XiaoZhi MCP Server...`);
    this.ws = new WebSocket(XIAOZHI_URL);

    this.ws.on('open', () => {
      console.log('✅ XiaoZhi MCP đã kết nối thành công!');
      
      // Giữ kết nối (Keep-alive) để không bị XiaoZhi Server ngắt kết nối do rảnh rỗi (idle)
      this.pingInterval = setInterval(() => {
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
          this.ws.ping();
        }
      }, 25000);
    });

    this.ws.on('message', (data) => {
      const messageStr = data.toString();
      this.handleJsonRpc(messageStr);
    });

    this.ws.on('close', () => {
      if (this.pingInterval) clearInterval(this.pingInterval);
      console.log('❌ XiaoZhi MCP ngắt kết nối. Đang thử lại sau 5s...');
      this.scheduleReconnect();
    });

    this.ws.on('error', (err) => {
      console.error('❌ Lỗi XiaoZhi WS:', err.message);
    });
  }

  scheduleReconnect() {
    if (this.reconnectTimeout) clearTimeout(this.reconnectTimeout);
    this.reconnectTimeout = setTimeout(() => this.connect(), 5000);
  }

  send(msgObj) {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(msgObj));
    }
  }

  handleJsonRpc(messageStr) {
    let doc;
    try {
      doc = JSON.parse(messageStr);
    } catch (e) {
      return;
    }

    if (doc.method === 'ping') {
      this.send({ jsonrpc: "2.0", id: doc.id, result: {} });
      console.log(`[XiaoZhi] Ping -> Pong`);
    } 
    else if (doc.method === 'initialize') {
      this.send({
        jsonrpc: "2.0",
        id: doc.id,
        result: {
          protocolVersion: "2024-11-05",
          capabilities: { experimental: {}, prompts: { listChanged: false }, resources: { subscribe: false, listChanged: false }, tools: { listChanged: false } },
          serverInfo: { name: "NodeJS-HA", version: "1.0.0" }
        }
      });
      this.send({ jsonrpc: "2.0", method: "notifications/initialized" });
      console.log(`[XiaoZhi] Đã phản hồi Initialize`);
    }
    else if (doc.method === 'tools/list') {
      this.send({
        jsonrpc: "2.0",
        id: doc.id,
        result: {
          tools: [
            {
              name: "control_light",
              description: "Điều khiển BẬT (ON) hoặc TẮT (OFF) đèn chiếu sáng tại các phòng.",
              inputSchema: { 
                type: "object", 
                properties: { 
                  state: { type: "string", enum: ["ON", "OFF"] },
                  room: { type: "string", enum: ["living_room", "bedroom"], description: "living_room: phòng khách & bếp, bedroom: phòng ngủ" }
                },
                required: ["state", "room"]
              }
            },
            {
              name: "control_fan",
              description: "Điều khiển BẬT (ON) hoặc TẮT (OFF) quạt gió.",
              inputSchema: { 
                type: "object", 
                properties: { 
                  state: { type: "string", enum: ["ON", "OFF"] },
                  room: { type: "string", enum: ["living_room", "bedroom"], description: "living_room: phòng khách, bedroom: phòng ngủ" }
                },
                required: ["state", "room"]
              }
            },
            {
              name: "control_door",
              description: "Điều khiển đóng mở cửa chính phòng khách. Mở (open), đóng (close) hoặc theo góc độ (angle).",
              inputSchema: { type: "object", properties: { mode: { type: "string", enum: ["open", "close", "angle"] }, angle: { type: "integer" } } }
            },
            {
              name: "control_bedroom_door",
              description: "Điều khiển cửa phòng ngủ. Mở (open), đóng (close) hoặc theo góc độ (angle).",
              inputSchema: { type: "object", properties: { mode: { type: "string", enum: ["open", "close", "angle"] }, angle: { type: "integer" } } }
            },
            {
              name: "control_dryer",
              description: "Điều khiển mở (open) hoặc đóng (close) giàn phơi thông minh tại phòng khách và bếp.",
              inputSchema: { type: "object", properties: { mode: { type: "string", enum: ["open", "close"] } } }
            },
            {
              name: "read_environment",
              description: "Đọc thông số môi trường của phòng khách và bếp, bao gồm: Nhiệt độ, Độ ẩm, tình trạng khí Gas, và báo Cháy (Lửa).",
              inputSchema: { type: "object", properties: {} }
            },
            {
              name: "control_all_devices",
              description: "Điều khiển BẬT (ON) hoặc TẮT (OFF) tất cả các thiết bị trong toàn bộ ngôi nhà (bao gồm tất cả đèn và quạt ở mọi phòng).",
              inputSchema: { 
                type: "object", 
                properties: { 
                  state: { type: "string", enum: ["ON", "OFF"] }
                },
                required: ["state"]
              }
            }
          ]
        }
      });
      console.log(`[XiaoZhi] Đã gửi danh sách Tools (Chi tiết phòng khách & bếp)`);
    }
    else if (doc.method === 'tools/call') {
      const toolName = doc.params.name;
      const args = doc.params.arguments || {};
      console.log(`[XiaoZhi] AI gọi Tool: ${toolName}`, args);

      let responseText = "";
      let mqttTopic = "";
      let mqttValue = "";

      if (toolName === "control_light") {
        const id = args.room === "bedroom" ? ID_BEDROOM : ID_LIVING;
        const suffix = args.room === "bedroom" ? "_led_bedroom" : "_led1";
        mqttValue = args.state === "ON" ? "ON" : "OFF";
        mqttTopic = `cmnd/${id}${suffix}/POWER`;
        responseText = `Đã gửi lệnh ${mqttValue} cho đèn ${args.room === "bedroom" ? "phòng ngủ" : "phòng khách"}.`;
      }
      else if (toolName === "control_fan") {
        const id = args.room === "bedroom" ? ID_BEDROOM : ID_LIVING;
        const suffix = args.room === "bedroom" ? "_fan_bedroom" : "_fan_livingroom";
        mqttValue = args.state === "ON" ? "ON" : "OFF";
        mqttTopic = `cmnd/${id}${suffix}/POWER`;
        responseText = `Đã gửi lệnh ${mqttValue} cho quạt ${args.room === "bedroom" ? "phòng ngủ" : "phòng khách"}.`;
      }
      else if (toolName === "control_door") {
        if (args.mode === "open") mqttValue = "90";
        else if (args.mode === "close") mqttValue = "0";
        else if (args.mode === "angle") mqttValue = args.angle ? args.angle.toString() : "0";
        mqttTopic = `cmnd/${ID_LIVING}_door_livingroom1/POWER`;
        responseText = `Đã điều chỉnh cửa phòng khách tới góc ${mqttValue} độ.`;
      }
      else if (toolName === "control_bedroom_door" || toolName === "control_curtain") {
        if (args.mode === "open") mqttValue = "90";
        else if (args.mode === "close") mqttValue = "0";
        else if (args.mode === "angle") mqttValue = args.angle ? args.angle.toString() : "0";
        mqttTopic = `cmnd/${ID_BEDROOM}_curtain/POWER`;
        responseText = `Đã điều chỉnh cửa phòng ngủ tới góc ${mqttValue} độ.`;
      }
      else if (toolName === "control_dryer") {
        mqttValue = args.mode === "open" ? "90" : "0";
        mqttTopic = `cmnd/${ID_LIVING}_dryer_livingroom/POWER`;
        responseText = `Đã điều chỉnh giàn phơi tới góc ${mqttValue} độ.`;
      }
      else if (toolName === "read_environment") {
        const out = {
          "Khu vực": "Phòng khách và Bếp",
          "Nhiệt độ (°C)": mqttService.envCache.T,
          "Độ ẩm (%)": mqttService.envCache.H,
          "Báo động Gas": mqttService.envCache.Gas === "1" ? "CÓ RÒ RỈ GAS!" : "Bình thường",
          "Báo động Lửa": mqttService.envCache.Fire === "1" ? "CÓ CHÁY!" : "Bình thường"
        };
        responseText = JSON.stringify(out, null, 2);
      }
      else if (toolName === "control_all_devices") {
        mqttValue = args.state === "ON" ? "ON" : "OFF";
        
        // Gửi lệnh cho toàn bộ thiết bị (Không thông qua biến mqttTopic đơn)
        if (mqttService.client) {
          mqttService.client.publish(`cmnd/${ID_LIVING}_led1/POWER`, mqttValue);
          mqttService.client.publish(`cmnd/${ID_LIVING}_fan_livingroom/POWER`, mqttValue);
          mqttService.client.publish(`cmnd/${ID_BEDROOM}_led_bedroom/POWER`, mqttValue);
          mqttService.client.publish(`cmnd/${ID_BEDROOM}_fan_bedroom/POWER`, mqttValue);
          console.log(`[XiaoZhi -> MQTT] Bắn lệnh TOÀN BỘ NHÀ: ${mqttValue}`);
        }
        responseText = `Đã gửi lệnh ${mqttValue} cho TẤT CẢ thiết bị (đèn và quạt) trong ngôi nhà.`;
      }
      else {
        responseText = "Tool không tồn tại.";
      }

      // Bắn lệnh MQTT nếu có
      if (mqttTopic && mqttService.client) {
        mqttService.client.publish(mqttTopic, mqttValue);
        console.log(`[XiaoZhi -> MQTT] Bắn lệnh: ${mqttTopic} = ${mqttValue}`);
      }

      // Gửi phản hồi lại cho XiaoZhi
      this.send({
        jsonrpc: "2.0",
        id: doc.id,
        result: {
          content: [{ type: "text", text: responseText }],
          isError: false
        }
      });
    }
  }
}

module.exports = new XiaoZhiService();
