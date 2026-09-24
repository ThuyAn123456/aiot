const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
require('dotenv').config();

// Khởi tạo Firebase Admin
require('./config/firebase');

const authRoutes = require('./routes/auth.routes');
const nodeRoutes = require('./routes/node.routes');
const MqttService = require('./services/mqtt.service');
const XiaoZhiService = require('./services/xiaozhi.service');

const app = express();

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Connect to MongoDB
mongoose.connect(process.env.MONGODB_URI)
  .then(() => {
    console.log('✅ Kết nối MongoDB thành công!');
    console.log(`📦 Database: ${process.env.MONGODB_URI}`);
    
    // Khởi tạo MQTT Service lắng nghe cảnh báo
    const mqttService = require('./services/mqtt.service');
    mqttService.connect();
    XiaoZhiService.connect();
  })
  .catch((err) => {
    console.error('❌ Lỗi kết nối MongoDB:', err.message);
    process.exit(1);
  });

// Routes
app.use('/api/auth', authRoutes);
// Vô hiệu hoá deviceRoutes cũ
// app.use('/api/devices', deviceRoutes); 
app.use('/api/nodes', nodeRoutes);

// Health check
app.get('/', (req, res) => {
  res.json({
    message: '🏠 AloT Smart Home API đang chạy!',
    version: '1.0.0',
    endpoints: {
      auth: {
        register: 'POST /api/auth/register',
        login: 'POST /api/auth/login',
        forgotPassword: 'POST /api/auth/forgot-password',
        profile: 'GET /api/auth/profile (cần token)',
      },
      devices: {
        getAll: 'GET /api/devices (cần token)',
        update: 'PUT /api/devices/:id (cần token)',
      }
    }
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ success: false, message: 'Endpoint không tồn tại' });
});

// Error handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ success: false, message: 'Lỗi server nội bộ' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 AloT Backend đang chạy tại http://localhost:${PORT} (IPv4 + IPv6)`);
  console.log(`📱 Flutter app kết nối tới: https://iot.pro.vn/api`);
});
