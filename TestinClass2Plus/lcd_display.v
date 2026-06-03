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
localparam IMG_WIDTH  = 11'd140;  // 图片宽度
localparam IMG_HEIGHT = 11'd120;  // 图片高度

// 初始位置参数
parameter INIT_X = 12'd150;  // 初始X坐标
parameter INIT_Y = 12'd200;  // 初始Y坐标

// 移动参数
parameter MOVE_DISTANCE = 12'd180;  // 移动距离（像素）
parameter PIXELS_PER_SEC = 12'd50;  // 速度：50像素/秒

// 颜色定义
localparam COLOR_BG = 24'hFFFF00;  // 黄色背景

// 时钟频率参数 (lcd_clk = 33MHz)
// 每秒移动50像素，所以每移动1像素需要的时钟周期: 33MHz / 50 = 660000
localparam MOVE_DELAY = 26'd660_000;  // 每像素移动延迟

// 移动相关寄存器
reg [25:0] move_cnt;           // 移动计数器
reg signed [11:0] img_x;       // 图片左上角X坐标 (有符号)
reg signed [11:0] img_y;       // 图片左上角Y坐标 (有符号)
reg signed [11:0] vel_x;       // X方向速度 (+1或-1或0)
reg signed [11:0] vel_y;       // Y方向速度 (+1或-1或0)

// 用于模式3反弹计算的临时变量
reg signed [11:0] next_x;
reg signed [11:0] next_y;

// ROM相关信号
wire [14:0] rom_addr;          // ROM地址 (0-16799)
wire [23:0] rom_data;          // ROM数据输出 (RGB888)
reg  [14:0] rom_addr_r;        // 寄存ROM地址

wire [10:0] x_pos = (pixel_xpos == 11'd0) ? 11'd0 : pixel_xpos - 11'd1;
wire [10:0] y_pos = (pixel_ypos == 11'd0) ? 11'd0 : pixel_ypos - 11'd1;

wire in_active_area = (pixel_xpos >= 11'd1) && (pixel_xpos <= H_DISP) &&
                      (pixel_ypos >= 11'd1) && (pixel_ypos <= V_DISP);

// 判断当前像素是否在图片范围内
wire signed [11:0] rel_x = $signed({1'b0, x_pos}) - img_x;
wire signed [11:0] rel_y = $signed({1'b0, y_pos}) - img_y;
wire in_image = (rel_x >= 0) && (rel_x < IMG_WIDTH) && 
                (rel_y >= 0) && (rel_y < IMG_HEIGHT);

// 计算ROM地址: addr = y * 140 + x
// 由于ROM有1周期延迟，需要提前计算
assign rom_addr = (rel_y[6:0] * 8'd140) + rel_x[7:0];

//-----------------------------------------------------------------------------//
// Logo ROM实例化
//-----------------------------------------------------------------------------//
logo_rom u_logo_rom (
  .address (rom_addr),
  .clock   (lcd_clk),
  .q       (rom_data)
);

//-----------------------------------------------------------------------------//
// 移动逻辑控制
// 模式B0（switches[0]=1，其他=0）: 静态显示在(150, 200)
// 模式B1（switches[1]=1，其他=0）: 向上移动180像素，往复循环
// 模式B2（switches[2]=1，其他=0）: 向下移动，碰壁反弹
// 模式B3（switches[3]=1，其他=0）: 左上45度移动，碰壁穿透
//-----------------------------------------------------------------------------//
always @(posedge lcd_clk or negedge sys_rst_n) begin
  if (!sys_rst_n) begin
    img_x <= INIT_X;    // 初始X位置
    img_y <= INIT_Y;    // 初始Y位置
    vel_x <= 12'sd0;    // 初始X速度
    vel_y <= 12'sd0;    // 初始Y速度
    move_cnt <= 26'd0;
  end else begin
    // 根据开关设置不同模式（每次只有一个开关为1）
    if (switches == 4'b1000) begin
      //=================================================================
      // 模式B3: 左上45度移动，碰壁穿透
      //=================================================================
      // 初始化速度（左上45度：-1, -1）
      if (vel_x == 12'sd0 && vel_y == 12'sd0) begin
        vel_x <= -12'sd1;  // 向左
        vel_y <= -12'sd1;  // 向上
      end
      
      if (move_cnt >= MOVE_DELAY - 1) begin
        move_cnt <= 26'd0;
        
        // X方向穿透
        if (img_x + vel_x < -$signed(IMG_WIDTH)) begin
          // 从左边出去，从右边进来
          img_x <= $signed(H_DISP);
        end else if (img_x + vel_x >= $signed(H_DISP)) begin
          // 从右边出去，从左边进来
          img_x <= -$signed(IMG_WIDTH);
        end else begin
          img_x <= img_x + vel_x;
        end
        
        // Y方向穿透
        if (img_y + vel_y < -$signed(IMG_HEIGHT)) begin
          // 从上边出去，从下边进来
          img_y <= $signed(V_DISP);
        end else if (img_y + vel_y >= $signed(V_DISP)) begin
          // 从下边出去，从上边进来
          img_y <= -$signed(IMG_HEIGHT);
        end else begin
          img_y <= img_y + vel_y;
        end
        
      end else begin
        move_cnt <= move_cnt + 1'b1;
      end
      
    end else if (switches == 4'b0100) begin
      //=================================================================
      // 模式B2: 向下移动，碰壁反弹
      //=================================================================
      // 初始化速度（向下）
      if (vel_y == 12'sd0) begin
        vel_y <= 12'sd1;  // 向下移动
      end
      vel_x <= 12'sd0;  // X方向不移动
      
      if (move_cnt >= MOVE_DELAY - 1) begin
        move_cnt <= 26'd0;
        
        // 计算下一个Y位置
        next_y = img_y + vel_y;
        
        // Y方向碰壁反弹
        if (next_y + $signed(IMG_HEIGHT) >= $signed(V_DISP)) begin
          // 碰到底部，反弹向上
          vel_y <= -12'sd1;
          img_y <= $signed(V_DISP) - $signed(IMG_HEIGHT) - 12'sd1;
        end else if (next_y <= 12'sd0) begin
          // 碰到顶部，反弹向下
          vel_y <= 12'sd1;
          img_y <= 12'sd1;
        end else begin
          // 正常移动
          img_y <= next_y;
        end
        
        // X位置保持在初始位置
        img_x <= INIT_X;
        
      end else begin
        move_cnt <= move_cnt + 1'b1;
      end
      
    end else if (switches == 4'b0010) begin
      //=================================================================
      // 模式B1: 向上移动180像素，往复循环
      //=================================================================
      // X位置始终保持在初始位置
      img_x <= INIT_X;
      vel_x <= 12'sd0;
      
      if (move_cnt >= MOVE_DELAY - 1) begin
        move_cnt <= 26'd0;
        
        // 向上移动180像素后往复
        // 上边界：INIT_Y - 180 = 200 - 180 = 20
        // 下边界：INIT_Y = 200
        
        // 计算下一个位置
        next_y = img_y + vel_y;
        
        if (vel_y == 12'sd0) begin
          // 刚进入B1模式，初始化向上移动
          vel_y <= -12'sd1;
          img_y <= img_y;
        end else if (vel_y < 12'sd0) begin
          // 当前向上移动
          if (next_y <= INIT_Y - MOVE_DISTANCE) begin
            // 到达或超过上边界，反转向下，并校正位置
            vel_y <= 12'sd1;
            img_y <= INIT_Y - MOVE_DISTANCE;
          end else begin
            img_y <= next_y;
          end
        end else begin
          // 当前向下移动
          if (next_y >= INIT_Y) begin
            // 到达或超过下边界（初始位置），反转向上，并校正位置
            vel_y <= -12'sd1;
            img_y <= INIT_Y;
          end else begin
            img_y <= next_y;
          end
        end
        
      end else begin
        move_cnt <= move_cnt + 1'b1;
      end
      
    end else if (switches == 4'b0001) begin
      //=================================================================
      // 模式B0: 静止显示在初始位置(150, 200)
      //=================================================================
      img_x <= INIT_X;
      img_y <= INIT_Y;
      vel_x <= 12'sd0;
      vel_y <= 12'sd0;
      move_cnt <= 26'd0;
      
    end else begin
      //=================================================================
      // 默认：所有开关为0或多个开关同时为1，复位到初始位置
      //=================================================================
      img_x <= INIT_X;
      img_y <= INIT_Y;
      vel_x <= 12'sd0;
      vel_y <= 12'sd0;
      move_cnt <= 26'd0;
    end
  end
end

// 寄存in_image信号以匹配ROM延迟
reg in_image_d1;
always @(posedge lcd_clk) begin
  in_image_d1 <= in_image;
end

//-----------------------------------------------------------------------------//
// 像素显示逻辑
// ROM有1个时钟周期的延迟，所以使用延迟后的in_image_d1信号
//-----------------------------------------------------------------------------//
always @(posedge lcd_clk or negedge sys_rst_n) begin
  if (!sys_rst_n) begin
    pixel_data <= COLOR_BG;
  end else begin
    if (!in_active_area) begin
      pixel_data <= COLOR_BG;
    end else begin
      // 如果在图片范围内，显示ROM读取的图片数据
      if (in_image_d1) begin
        pixel_data <= rom_data;
      end else begin
        pixel_data <= COLOR_BG;  // 背景色
      end
    end
  end
end

endmodule