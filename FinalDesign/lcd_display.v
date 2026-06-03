module lcd_display(
  input        lcd_clk,        // LCD驱动时钟
  input        sys_rst_n,      // 复位信号
  input [3:0]  switches,       // B3,B2,B1,B0 开关输入
  input [10:0] pixel_xpos,     // 像素点横坐标(0-799)
  input [10:0] pixel_ypos,     // 像素点纵坐标(0-479)
  output reg [23:0] pixel_data // 像素点数据(RGB888)
);

//-----------------------------------------------------------------------------//
// Parameter definition
//-----------------------------------------------------------------------------//
localparam H_DISP = 11'd800;  // 水平分辨率
localparam V_DISP = 11'd480;  // 垂直分辨率

// Logo图片参数 (从LOGO.mif读取)
localparam IMG_WIDTH  = 11'd100;  // 原始图片宽度
localparam IMG_HEIGHT = 11'd100;  // 原始图片高度

// 缩放参数 (4倍放大: 100x100 -> 400x400)
localparam SCALE_FACTOR = 3'd4;   // 缩放倍数
localparam SCALED_WIDTH  = 11'd400;  // 缩放后宽度
localparam SCALED_HEIGHT = 11'd400;  // 缩放后高度

// 居中显示位置参数 (屏幕800x480，图像400x400)
// X居中: (800-400)/2 = 200
// Y居中: (480-400)/2 = 40
localparam IMG_X = 11'd200;  // 图像左上角X坐标 (居中)
localparam IMG_Y = 11'd40;   // 图像左上角Y坐标 (居中)

// 颜色定义
localparam COLOR_BG = 24'hFFFFFF;  // 白色背景

// ROM相关信号
wire [13:0] rom_addr;          // ROM地址 (0-9999)
wire [23:0] rom_data;          // ROM数据输出 (RGB888)
reg  [13:0] rom_addr_r;        // 寄存ROM地址

wire [10:0] x_pos = (pixel_xpos == 11'd0) ? 11'd0 : pixel_xpos - 11'd1;
wire [10:0] y_pos = (pixel_ypos == 11'd0) ? 11'd0 : pixel_ypos - 11'd1;

wire in_active_area = (pixel_xpos >= 11'd1) && (pixel_xpos <= H_DISP) &&
                      (pixel_ypos >= 11'd1) && (pixel_ypos <= V_DISP);

// 判断当前像素是否在缩放后的图片范围内 (400x400)
wire [10:0] rel_x_scaled = x_pos - IMG_X;  // 相对于缩放图像的X坐标
wire [10:0] rel_y_scaled = y_pos - IMG_Y;  // 相对于缩放图像的Y坐标
wire in_image = (x_pos >= IMG_X) && (x_pos < IMG_X + SCALED_WIDTH) && 
                (y_pos >= IMG_Y) && (y_pos < IMG_Y + SCALED_HEIGHT);

// 缩放算法: 最近邻插值 (Nearest Neighbor Interpolation)
// 将缩放后的坐标映射回原始图像坐标: src_coord = dst_coord / scale_factor
// 使用右移2位代替除以4
wire [6:0] src_x = rel_x_scaled[8:2];  // 除以4，得到原始图像X坐标 (0-99)
wire [6:0] src_y = rel_y_scaled[8:2];  // 除以4，得到原始图像Y坐标 (0-99)

// 计算ROM地址: addr = y * 100 + x
// 由于ROM有1周期延迟，需要提前计算
assign rom_addr = (src_y * 7'd100) + src_x;

//-----------------------------------------------------------------------------//
// Logo ROM实例化
//-----------------------------------------------------------------------------//
logo_rom u_logo_rom (
  .address (rom_addr),
  .clock   (lcd_clk),
  .q       (rom_data)
);

//-----------------------------------------------------------------------------//
// 图像静态显示在屏幕中央 (无移动逻辑)
// 缩放算法: 最近邻插值 (cv::resize with INTER_NEAREST)
// 100x100 原图 -> 400x400 显示
//-----------------------------------------------------------------------------//

// 寄存in_image信号以匹配ROM延迟
reg in_image_d1;
always @(posedge lcd_clk) begin
  in_image_d1 <= in_image;
end

//-----------------------------------------------------------------------------//
// 图像处理流水线 (Soft Core Hardening) - 边缘检测算法
//-----------------------------------------------------------------------------//
wire [7:0] r = rom_data[23:16];
wire [7:0] g = rom_data[15:8];
wire [7:0] b = rom_data[7:0];

// 灰度化 (Reference: cv::cvtColor RGB2GRAY)
// Formula: Gray = R*0.299 + G*0.587 + B*0.114
// Approx: (R*77 + G*150 + B*29) >> 8
wire [15:0] gray_calc = r * 77 + g * 150 + b * 29;
wire [7:0] gray = gray_calc[15:8];

//-----------------------------------------------------------------------------//
// 3x3 像素窗口缓存 (用于边缘检测卷积运算)
// 使用两个行缓存存储前两行数据，实现完整的3x3窗口
//-----------------------------------------------------------------------------//
// 行缓存 - 存储前两行的灰度值
reg [7:0] line_buf0 [0:IMG_WIDTH-1];  // 前2行缓存 (最上行)
reg [7:0] line_buf1 [0:IMG_WIDTH-1];  // 前1行缓存 (中间行)

// 3x3窗口像素矩阵
// ┌─────┬─────┬─────┐
// │ p00 │ p01 │ p02 │  <- 前2行 (line_buf0)
// ├─────┼─────┼─────┤
// │ p10 │ p11 │ p12 │  <- 前1行 (line_buf1)
// ├─────┼─────┼─────┤
// │ p20 │ p21 │ p22 │  <- 当前行 (实时移位)
// └─────┴─────┴─────┘
reg [7:0] p00, p01, p02;  // 第0行 (最上)
reg [7:0] p10, p11, p12;  // 第1行 (中间)
reg [7:0] p20, p21, p22;  // 第2行 (最下/当前行)

// 流水线延迟信号
reg in_image_d2, in_image_d3;
reg [6:0] src_x_d1, src_x_d2, src_x_d3;
reg [6:0] src_y_d1, src_y_d2, src_y_d3;

// 延迟信号用于流水线对齐
always @(posedge lcd_clk) begin
    in_image_d2 <= in_image_d1;
    in_image_d3 <= in_image_d2;
    src_x_d1 <= src_x;
    src_x_d2 <= src_x_d1;
    src_x_d3 <= src_x_d2;
    src_y_d1 <= src_y;
    src_y_d2 <= src_y_d1;
    src_y_d3 <= src_y_d2;
end

// 当前行的3像素移位寄存器
reg [7:0] cur_row_shift [0:2];  // 当前行移位寄存器

// 行缓存写入和3x3窗口构建
always @(posedge lcd_clk) begin
    if (in_image_d1) begin
        // 当前行移位寄存器更新
        cur_row_shift[2] <= cur_row_shift[1];
        cur_row_shift[1] <= cur_row_shift[0];
        cur_row_shift[0] <= gray;
        
        // 从行缓存读取前两行数据并构建窗口
        // 第0行 (最上行) - 从line_buf0读取
        p02 <= p01;
        p01 <= p00;
        p00 <= line_buf0[src_x_d1];
        
        // 第1行 (中间行) - 从line_buf1读取
        p12 <= p11;
        p11 <= p10;
        p10 <= line_buf1[src_x_d1];
        
        // 第2行 (当前行) - 使用移位寄存器
        p22 <= p21;
        p21 <= p20;
        p20 <= gray;
        
        // 更新行缓存: line_buf0 <- line_buf1 <- 当前灰度值
        line_buf0[src_x_d1] <= line_buf1[src_x_d1];
        line_buf1[src_x_d1] <= gray;
    end
end

// 窗口有效标志 (需要至少处理3个像素和2行才能形成有效窗口)
wire window_valid = in_image_d3 && (src_x_d3 >= 7'd2) && (src_y_d3 >= 7'd2);

//-----------------------------------------------------------------------------//
// Sobel 边缘检测 (Reference: cv::Sobel) - 完整3x3矩阵卷积
// Gx = [-1 0 +1]    Gy = [-1 -2 -1]
//      [-2 0 +2]         [ 0  0  0]
//      [-1 0 +1]         [+1 +2 +1]
//
// Gx = (p02 - p00) + 2*(p12 - p10) + (p22 - p20)
// Gy = (p00 + 2*p01 + p02) - (p20 + 2*p21 + p22)
//-----------------------------------------------------------------------------//
// Sobel Gx 计算: 水平方向梯度
wire signed [10:0] sobel_gx_row0 = $signed({3'b0, p02}) - $signed({3'b0, p00});  // 第0行
wire signed [10:0] sobel_gx_row1 = ($signed({3'b0, p12}) - $signed({3'b0, p10})) <<< 1;  // 第1行 *2
wire signed [10:0] sobel_gx_row2 = $signed({3'b0, p22}) - $signed({3'b0, p20});  // 第2行
wire signed [11:0] sobel_gx = sobel_gx_row0 + sobel_gx_row1 + sobel_gx_row2;

// Sobel Gy 计算: 垂直方向梯度
wire signed [10:0] sobel_gy_top = $signed({3'b0, p00}) + ($signed({3'b0, p01}) <<< 1) + $signed({3'b0, p02});
wire signed [10:0] sobel_gy_bot = $signed({3'b0, p20}) + ($signed({3'b0, p21}) <<< 1) + $signed({3'b0, p22});
wire signed [11:0] sobel_gy = sobel_gy_top - sobel_gy_bot;

// 计算梯度幅值: |Gx| + |Gy| (曼哈顿距离近似)
wire [11:0] sobel_gx_abs = (sobel_gx < 0) ? -sobel_gx : sobel_gx;
wire [11:0] sobel_gy_abs = (sobel_gy < 0) ? -sobel_gy : sobel_gy;
wire [12:0] sobel_mag_full = sobel_gx_abs + sobel_gy_abs;

// 归一化到8位 (除以8，因为Sobel算子最大值为4*255*2=2040)
wire [7:0] sobel_mag = (sobel_mag_full > 13'd2040) ? 8'd255 : sobel_mag_full[10:3];

// 阈值化输出
wire [23:0] data_sobel = (window_valid && sobel_mag > 8'd30) ? 24'h000000 : 24'hFFFFFF;

//-----------------------------------------------------------------------------//
// Prewitt 边缘检测 (Reference: Prewitt operator) - 完整3x3矩阵卷积
// Gx = [-1 0 +1]    Gy = [-1 -1 -1]
//      [-1 0 +1]         [ 0  0  0]
//      [-1 0 +1]         [+1 +1 +1]
//
// Gx = (p02 - p00) + (p12 - p10) + (p22 - p20)
// Gy = (p00 + p01 + p02) - (p20 + p21 + p22)
//-----------------------------------------------------------------------------//
// Prewitt Gx 计算: 水平方向梯度 (均匀权重)
wire signed [10:0] prewitt_gx_row0 = $signed({3'b0, p02}) - $signed({3'b0, p00});  // 第0行
wire signed [10:0] prewitt_gx_row1 = $signed({3'b0, p12}) - $signed({3'b0, p10});  // 第1行
wire signed [10:0] prewitt_gx_row2 = $signed({3'b0, p22}) - $signed({3'b0, p20});  // 第2行
wire signed [11:0] prewitt_gx = prewitt_gx_row0 + prewitt_gx_row1 + prewitt_gx_row2;

// Prewitt Gy 计算: 垂直方向梯度 (均匀权重)
wire signed [10:0] prewitt_gy_top = $signed({3'b0, p00}) + $signed({3'b0, p01}) + $signed({3'b0, p02});
wire signed [10:0] prewitt_gy_bot = $signed({3'b0, p20}) + $signed({3'b0, p21}) + $signed({3'b0, p22});
wire signed [11:0] prewitt_gy = prewitt_gy_top - prewitt_gy_bot;

// 计算梯度幅值: |Gx| + |Gy| (曼哈顿距离近似)
wire [11:0] prewitt_gx_abs = (prewitt_gx < 0) ? -prewitt_gx : prewitt_gx;
wire [11:0] prewitt_gy_abs = (prewitt_gy < 0) ? -prewitt_gy : prewitt_gy;
wire [12:0] prewitt_mag_full = prewitt_gx_abs + prewitt_gy_abs;

// 归一化到8位 (除以6，因为Prewitt算子最大值为3*255*2=1530)
wire [7:0] prewitt_mag = (prewitt_mag_full > 13'd1530) ? 8'd255 : prewitt_mag_full[10:3];

// 阈值化输出
wire [23:0] data_prewitt = (window_valid && prewitt_mag > 8'd25) ? 24'h000000 : 24'hFFFFFF;

//-----------------------------------------------------------------------------//
// Canny 边缘检测 (Reference: cv::Canny)
// Canny包含: 1.高斯滤波 2.梯度计算 3.非极大值抑制 4.双阈值检测
// FPGA实现: 使用完整Sobel梯度 + 双阈值检测
//-----------------------------------------------------------------------------//
// 复用Sobel梯度计算结果
// sobel_gx_abs 和 sobel_gy_abs 已在上面计算

// 梯度幅值 (使用Sobel的结果)
wire [12:0] canny_mag = sobel_mag_full;

// 双阈值检测 (Canny特征)
localparam CANNY_THRESH_LOW  = 10'd100;   // 低阈值
localparam CANNY_THRESH_HIGH = 10'd200;   // 高阈值

// 强边缘(黑色)、弱边缘(灰色)、非边缘(白色) - 白底黑边
wire [23:0] data_canny = (!window_valid) ? 24'hFFFFFF :
                         (canny_mag > CANNY_THRESH_HIGH) ? 24'h000000 :
                         (canny_mag > CANNY_THRESH_LOW)  ? 24'h808080 : 24'hFFFFFF;

//-----------------------------------------------------------------------------//
// 像素显示逻辑
// ROM有1个时钟周期的延迟，所以使用延迟后的in_image_d1信号
// 开关功能:
//   B0 (switches[0]=1): Sobel边缘检测
//   B1 (switches[1]=1): Prewitt边缘检测
//   B2 (switches[2]=1): Canny边缘检测
//   其他/默认: 原图显示
//-----------------------------------------------------------------------------//
always @(posedge lcd_clk or negedge sys_rst_n) begin
  if (!sys_rst_n) begin
    pixel_data <= COLOR_BG;
  end else begin
    if (!in_active_area) begin
      pixel_data <= COLOR_BG;
    end else begin
      // 如果在图片范围内，显示处理后的图片数据
      if (in_image_d1) begin
        case (switches[2:0])
            3'b001: pixel_data <= data_sobel;    // Switch[0]: Sobel边缘检测
            3'b010: pixel_data <= data_prewitt;  // Switch[1]: Prewitt边缘检测
            3'b100: pixel_data <= data_canny;    // Switch[2]: Canny边缘检测
            default: pixel_data <= rom_data;     // Default: 原图显示
        endcase
      end else begin
        pixel_data <= COLOR_BG;  // 背景色
      end
    end
  end
end

endmodule