# FPGA LCD 显示与图像处理实验集

[![Verilog](https://img.shields.io/badge/Language-Verilog-blue.svg)](https://en.wikipedia.org/wiki/Verilog)
[![Quartus](https://img.shields.io/badge/IDE-Quartus%20II-orange.svg)](https://www.intel.com/content/www/us/en/products/details/fpga/development-tools/quartus-prime.html)
[![Platform](https://img.shields.io/badge/Platform-Intel%20Cyclone%20IV-green.svg)](https://www.intel.com/content/www/us/en/products/details/fpga/cyclone/iv.html)

> 杭州电子科技大学《电子信息技术虚拟仿真综合实践B》课程实验工程汇总
> 从基础 LCD 驱动到实时图像边缘检测的完整 FPGA 图像处理链路

---

## 项目简介

本仓库记录了一套基于 **Intel Cyclone IV FPGA** 的 LCD 显示与图像处理实验。系统以 **800×480 RGB LCD** 为显示终端，使用 **Verilog HDL** 自底向上实现了从基础图形绘制、静态图片显示到实时卷积图像处理的完整链路。

核心综合设计实现了与 **OpenCV `cv::Sobel()` / `cv::Prewitt()`** 等效的硬件加速边缘检测，采用流水线架构，可通过拨码开关实时切换算法并观察效果。

---

## 仓库结构

| 目录                                        | 实验内容                                                    | 关键知识点                                                                 |
| ------------------------------------------- | ----------------------------------------------------------- | -------------------------------------------------------------------------- |
| [`Blab101Net`](./Blab101Net)                 | 作业 1-1：LCD 网格显示                                      | 时序生成、像素坐标映射、简单图形绘制                                       |
| [`Blab102Shine`](./Blab102Shine)             | 课堂测验 1：色块闪烁                                        | 计数器分频、状态切换、动态刷新                                             |
| [`Blab103ROMphoto`](./Blab103ROMphoto)       | 硬件实验二：基于 ROM 的静态图片显示                         | ROM 初始化、MIF/HEX 格式、图片转 ROM 工具                                  |
| [`LCDexampleLH`](./LCDexampleLH)             | LCD 显示基础示例                                            | `lcd_driver` / `lcd_display` 基本框架                                  |
| [`LCDwithButtonTest1`](./LCDwithButtonTest1) | 按钮控制网格移动                                            | 按键消抖、网格坐标映射、状态机                                             |
| [`TestinClass1`](./TestinClass1)             | 课堂测验 2-1：网格 + 起始点/目标点 + 闪烁 + 自动寻路        | 多模式切换、路径规划、动画时序控制                                         |
| [`TestinClass2`](./TestinClass2)             | 实验 2：图片显示与移动                                      | Logo 图片读取、多方向移动、边界碰撞检测                                    |
| [`TestinClass2Plus`](./TestinClass2Plus)     | 实验 2 增强版                                               | 45° 斜向移动、边界反弹循环                                                |
| [`FinalDesign`](./FinalDesign)               | **综合设计：基于 Sobel/Prewitt 的 FPGA 实时边缘检测** | **图像缩放、RGB→灰度、3×3 卷积窗口、行缓存、流水线、硬件算法优化** |

> 📄 **综合报告**：[`FinalDesign/Tex_Report/edge_detection_report.pdf`](./FinalDesign/Tex_Report/edge_detection_report.pdf)

---

## 综合设计（FinalDesign）

### 系统架构

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  坐标映射    │ -> │  ROM 读取   │ -> │  RGB→灰度   │ -> │  边缘检测   │ -> │  LCD 输出   │
│ (最近邻插值) │    │ (原始像素)  │    │  (预处理)   │    │ (算法选择)  │    │  (实时显示) │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                                              ^
                                                              │
                                                    switches[2:0] 实时切换
```

### 核心模块

| 模块                   | 功能                                         | 技术要点                                                          |
| ---------------------- | -------------------------------------------- | ----------------------------------------------------------------- |
| **坐标映射**     | 将 800×480 屏幕坐标映射到 100×100 原始图像 | 最近邻插值，4 倍放大，除以 4 用右移 2 位实现                      |
| **RGB→灰度**    | 彩色图像转灰度，供边缘检测使用               | 定点化优化：`Gray = (77R + 150G + 29B) >> 8`，避免浮点运算      |
| **3×3 窗口**    | 构建卷积所需的 8 邻域像素窗口                | 双行缓存 (`line_buf`) + 移位寄存器，每时钟周期并行输出 9 个像素 |
| **Sobel 算子**   | 检测水平/垂直方向梯度                        | 中心行权重为 2，对噪声有一定抑制，边缘较平滑                      |
| **Prewitt 算子** | 检测水平/垂直方向梯度                        | 均匀权重，边缘更锐利，计算仅需加法                                |
| **Canny 算子**   | 双阈值边缘检测（拓展）                       | 基于 Sobel 梯度 + 高低阈值分类：强边缘/弱边缘/非边缘              |

### 算法优化：加权近似法

传统绝对值和近似 `|G| = |Gx| + |Gy|` 在 45° 方向会产生约 **+41%** 的高估误差。本设计提出硬件友好的加权近似：

```verilog
// max + min/2，仅需比较器和加法器，无需乘法
wire [11:0] gradient = g_max + {1'b0, g_min[10:1]};
```

该方法将误差控制在 **±12%** 以内，且仅需 1 个右移操作，资源消耗极低。

### 实时切换映射

| `switches[2:0]` | 功能             | 显示效果                     |
| ----------------- | ---------------- | ---------------------------- |
| `3'b001`        | Sobel 边缘检测   | 白底黑边，边缘平滑连续       |
| `3'b010`        | Prewitt 边缘检测 | 白底黑边，边缘锐利清晰       |
| `3'b100`        | Canny 边缘检测   | 强边缘黑、弱边缘灰、非边缘白 |
| 其他              | 原始彩色图像     | 4 倍放大居中显示             |

---

## 🛠️ 硬件环境

- **FPGA 开发板**：Intel Cyclone IV 系列
- **LCD 屏幕**：800 × 480 分辨率，RGB888 接口，@60Hz
- **系统时钟**：50 MHz
- **LCD 驱动时钟**：33 MHz（由 PLL 分频）
- **输入**：4 位拨码开关 (`switches[3:0]`)、复位按键

### 主要引脚

| 信号              | 方向   | 说明                   |
| ----------------- | ------ | ---------------------- |
| `sys_clk`       | Input  | 50 MHz 系统时钟        |
| `sys_rst_n`     | Input  | 复位信号，低电平有效   |
| `switches[3:0]` | Input  | 拨码开关，用于功能切换 |
| `lcd_clk`       | Output | 33 MHz LCD 像素时钟    |
| `lcd_hs`        | Output | 行同步信号             |
| `lcd_vs`        | Output | 场同步信号             |
| `lcd_de`        | Output | 数据使能               |
| `lcd_rgb[23:0]` | Output | RGB888 像素数据        |

---

## 🚀 快速开始

### 1. 克隆仓库

```bash
git clone <repository-url>
cd Blab
```

### 2. 打开工程

使用 **Quartus II / Quartus Prime** 打开对应实验目录下的 `.qpf` 工程文件：

```
FinalDesign/LCD.qpf          # 综合设计（推荐）
Blab103ROMphoto/LCD.qpf      # ROM 图片显示
Blab101Net/LCD.qpf           # 基础网格显示
```

### 3. 综合与下载

1. 执行 **Analysis & Synthesis**
2. 执行 **Fitter**（布局布线）
3. 连接 FPGA 开发板，点击 **Programmer** 下载 `.sof` 文件

### 4. 替换 ROM 图片（仅限 Blab103ROMphoto / FinalDesign）

```powershell
# 需要 Python 3 + Pillow
python Blab103ROMphoto/tools/image_to_rom.py <your-image>.bmp rom/lcd_image.hex --coe rom/lcd_image.coe
```

- 默认裁剪为方形并缩放至目标尺寸（Blab103ROMphoto 为 150×150，FinalDesign 为 100×100）
- 修改尺寸后请同步更新 Verilog 中的 `IMG_WIDTH` / `IMG_HEIGHT` 参数

---

## 📊 实验演进路线

```
基础显示
    │
    ├──► 网格绘制 (Blab101Net)
    │      └──► 色块闪烁 (Blab102Shine)
    │
    ├──► 按键控制移动 (LCDwithButtonTest1)
    │      └──► 自动寻路动画 (TestinClass1)
    │
    └──► ROM 图片显示 (Blab103ROMphoto)
           └──► 图片移动/边界检测 (TestinClass2 / TestinClass2Plus)
                  └──► 
                        【综合设计】实时边缘检测 (FinalDesign)
                        ├── 最近邻插值缩放
                        ├── RGB→灰度定点化
                        ├── 3×3 卷积窗口 + 行缓存
                        ├── Sobel / Prewitt / Canny 硬件实现
                        └── 拨码开关实时切换
```

---

## 📝 技术笔记

### 1. 为什么用右移代替除法？

FPGA 中的除法器资源消耗大、时延高。当缩放因子为 2 的幂次（如 4 = 2²）时，`/ 4` 等价于 `>> 2`，仅需重新接线，零资源消耗。

### 2. 行缓存如何省资源？

使用单端口 RAM 风格的寄存器数组 `reg [7:0] line_buf [0:WIDTH-1]`，每个时钟周期按列地址写入当前行、读出历史行，配合移位寄存器形成 3×3 窗口。

### 3. 流水线深度

FinalDesign 的处理链路共 3 级流水线延迟：

| 周期 | T0       | T1       | T2       | T3       |
| ---- | -------- | -------- | -------- | -------- |
| 阶段 | 坐标计算 | ROM 读取 | 灰度转换 | 边缘检测 |

3 级延迟对于 33 MHz 的显示时钟仅约 **90 ns**，肉眼完全无感知，实现了"实时"处理效果。

---



> **指导教师**：高宇
> **学校**：杭州电子科技大学
> **专业**：智能硬件与系统（电子信息工程）
