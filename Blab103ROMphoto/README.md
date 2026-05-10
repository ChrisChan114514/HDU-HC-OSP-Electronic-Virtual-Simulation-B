# 静态图片 LCD 显示方案

该工程给出了一个基于 ROM 的 LCD 图像显示流程，能够在 800×480 的 RGB LCD 屏幕上居中显示一张 150×150 的静态图片。本仓库提供：

- `lcd_driver.v`：行场时序与坐标生成模块（原有文件）。
- `lcd_display.v`：从像素坐标读取 ROM 并输出 RGB888 数据。
- `image_rom.v`：可综合的同步 ROM 包装。
- `rom/lcd_image.hex` / `rom/lcd_image.mif`：由源图像转换而来的 RGB 数据（前者用于仿真 `$readmemh`，后者供 Quartus 初始化）。
- `tools/image_to_rom.py`：图片转 ROM 的 Python 工具脚本，同时支持生成 `.coe` 文件。

## 使用步骤

1. **准备 Conda 环境（可选）**

   ```powershell
   conda activate fpga_env
   ```

   该环境已经预装 Python 3.11 与 Pillow、NumPy 等依赖。

2. **更新 ROM 数据（如需替换图片）**

   ```powershell
   python tools\image_to_rom.py <输入图片路径> rom\lcd_image.hex --coe rom\lcd_image.coe
   ```

   - 默认会将图片居中裁剪为方形后缩放到 150×150。
   - 生成的 `rom/lcd_image.hex`、`rom/lcd_image.mif` 会自动覆盖旧文件，综合与仿真均会引用最新数据。
   - 如需保留原图比例，可添加 `--no-crop`。
      - 可通过 `--brightness/--contrast/--saturation/--gamma/--invert` 微调颜色和对比度（例如 `--brightness 0.7 --contrast 1.2 --saturation 1.5 --invert`）。
   - 支持使用 `--size WxH` 修改目标分辨率，若修改请同步更新 `lcd_display.v` 中的 `IMG_WIDTH/IMG_HEIGHT` 参数。

3. **综合 / 下载**
   - 在顶层中实例化 `lcd_driver` 与新的 `lcd_display`，保持像素接口连接：
     - `pixel_xpos`, `pixel_ypos` 由 `lcd_driver` 输出。
     - `pixel_data` 由 `lcd_display` 输出并回送给 `lcd_driver`。
   - 确保综合器能找到 `rom/lcd_image.mif` 文件，可在工程中设置为 memory init file（或在 `LCD.qsf` 中出现 `set_global_assignment -name HEX_FILE rom/lcd_image.mif`）。

## 关键点说明

- 图像窗口以 `(IMG_START_X, IMG_START_Y)` 为左上角，在 800×480 分辨率下居中显示。
- ROM 采用同步读取，地址和 `in_image` 标志分别经过两拍流水线与像素输出对齐。
- 背景色目前固定为黑色，可按需修改 `COLOR_BACKGROUND` 常量。
- `image_rom` 默认深度为 `DEPTH` 参数，可自定义为任意像素数，未用空间将初始化为 0。

## 后续可扩展方向

- 增加多张图片切换或动画效果（扩展 ROM 控制逻辑）。
- 引入硬件 Gamma / 颜色 LUT 以提升显示效果。
- 加入仿真 Testbench，验证像素坐标映射是否正确。
