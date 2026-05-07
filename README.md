# 水墨画廊 | Ink Brush Gallery

一个展示东方水墨艺术的数字画廊平台，使用 Three.js 实现沉浸式 3D 水墨画笔动画效果。

## 技术栈

### 前端
- **React 18** - UI 框架
- **TypeScript** - 类型安全
- **Vite** - 构建工具
- **Tailwind CSS** - 样式框架
- **Three.js** + **React Three Fiber** - 3D 渲染

### 后端
- **FastAPI** - Python Web 框架
- **Pydantic** - 数据验证
- **SQLAlchemy** - ORM（预留）

## 功能特色

- 🎨 **3D 水墨画笔动画** - 使用 Three.js 实现逼真的水墨画笔效果
- 📜 **滚动驱动动画** - 用户滚动页面时，画笔沿曲线绘制水墨轨迹
- 🖼️ **画廊展示** - 展示水墨艺术作品
- 📱 **响应式设计** - 适配各种屏幕尺寸

## 快速开始

### 一键启动

```bash
chmod +x start.sh
./start.sh
```

### 分别启动

#### 前端

```bash
cd frontend
npm install
npm run dev
```

访问 http://localhost:3000

#### 后端

```bash
cd backend
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -e .
uvicorn app.main:app --reload
```

访问 http://localhost:8000

API 文档: http://localhost:8000/docs

## 项目结构

```
ink-brush-gallery/
├── frontend/                # 前端项目
│   ├── src/
│   │   ├── components/      # React 组件
│   │   │   ├── Navbar.tsx   # 导航栏
│   │   │   ├── Footer.tsx   # 页脚
│   │   │   ├── Landing.tsx  # 首页
│   │   │   ├── InkScene.tsx # Three.js 场景
│   │   │   ├── InkBrush.tsx # 水墨画笔 3D 模型
│   │   │   └── InkTrail.tsx # 水墨轨迹
│   │   ├── App.tsx
│   │   └── main.tsx
│   ├── package.json
│   └── vite.config.ts
│
├── backend/                 # 后端项目
│   ├── app/
│   │   ├── main.py          # FastAPI 入口
│   │   ├── config.py        # 配置
│   │   ├── models/          # 数据模型
│   │   ├── routers/         # API 路由
│   │   └── services/        # 业务逻辑
│   └── pyproject.toml
│
└── start.sh                 # 一键启动脚本
```

## 水墨画笔动画原理

1. **曲线生成** - 使用 CatmullRom 曲线生成优雅的 S 形路径
2. **画笔跟随** - 根据滚动进度，画笔沿曲线移动
3. **水墨粒子** - 使用自定义着色器实现水墨扩散效果
4. **相机跟随** - 相机平滑跟随画笔移动

## 开发计划

- [ ] 添加更多水墨笔触样式
- [ ] 实现用户上传作品功能
- [ ] 添加艺术家主页
- [ ] 实现作品评论系统
- [ ] 添加虚拟展览功能

## 许可证

MIT License