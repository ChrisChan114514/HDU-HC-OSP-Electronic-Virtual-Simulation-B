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

// 新的网格参数: 24行 * 40列
localparam CELL_COLS = 40;
localparam CELL_ROWS = 24;
localparam [10:0] CELL_W = 11'd20; // 800 / 40
localparam [10:0] CELL_H = 11'd20; // 480 / 24

localparam COLOR_WHITE = 24'hFFFFFF;
localparam COLOR_BLACK = 24'h000000;
localparam COLOR_RED   = 24'hFF0000;
localparam COLOR_BLUE  = 24'h0000FF;
localparam COLOR_BG    = 24'h000000;

// 目标点和起始点位置
localparam [5:0] TARGET_COL = 6'd10;  // 目标点列
localparam [4:0] TARGET_ROW = 5'd20;  // 目标点行
localparam [5:0] START_COL = 6'd20;   // 起始点列
localparam [4:0] START_ROW = 5'd5;    // 起始点行

// 时钟相关参数 (33MHz)
localparam BLINK_DELAY = 26'd66_000_000; // 2秒闪烁周期

// 寄存器定义
reg [25:0] blink_cnt;    // 闪烁计数器
reg        blink_state;  // 闪烁状态

wire [10:0] x_pos = (pixel_xpos == 11'd0) ? 11'd0 : pixel_xpos - 11'd1; // 映射到 0~799
wire [10:0] y_pos = (pixel_ypos == 11'd0) ? 11'd0 : pixel_ypos - 11'd1; // 映射到 0~479

wire in_active_area = (pixel_xpos >= 11'd1) && (pixel_xpos <= H_DISP) &&
                      (pixel_ypos >= 11'd1) && (pixel_ypos <= V_DISP);

// 网格线判断 (1像素宽)
wire vert_grid_line = (x_pos % CELL_W) == 11'd0;
wire hori_grid_line = (y_pos % CELL_H) == 11'd0;

// 计算当前像素所在的网格位置
wire [5:0] cur_col = x_pos / CELL_W;  // 当前列 (0-39)
wire [4:0] cur_row = y_pos / CELL_H;  // 当前行 (0-23)

// 目标点判断
wire in_target_cell = (cur_col == TARGET_COL) && (cur_row == TARGET_ROW);

// 起始点判断（蓝色块位置固定在起始点）
wire in_blue_cell = (cur_col == START_COL) && (cur_row == START_ROW);

// 判断是否在网格内部(非网格线)
wire in_cell_interior = !vert_grid_line && !hori_grid_line;

//-----------------------------------------------------------------------------//
// 闪烁逻辑
//-----------------------------------------------------------------------------//
always @(posedge lcd_clk or negedge sys_rst_n) begin
  if (!sys_rst_n) begin
    blink_cnt <= 26'd0;
    blink_state <= 1'b0;
  end else begin
    if (blink_cnt >= BLINK_DELAY - 1) begin
      blink_cnt <= 26'd0;
      blink_state <= ~blink_state;
    end else begin
      blink_cnt <= blink_cnt + 1'b1;
    end
  end
end

//-----------------------------------------------------------------------------//
// 像素显示逻辑
//-----------------------------------------------------------------------------//
always @(posedge lcd_clk or negedge sys_rst_n) begin
  if (!sys_rst_n) begin
    pixel_data <= COLOR_BG;
  end else begin
    if (!in_active_area) begin
      pixel_data <= COLOR_BG;
    end else begin
      // 优先级: 网格线 > 蓝色起始点 > 红色闪烁目标点 > 白色背景
      if (vert_grid_line || hori_grid_line) begin
        // 网格线为黑色
        pixel_data <= COLOR_BLACK;
      end else if (in_cell_interior) begin
        // 判断是否在蓝色起始点格子内
        if (in_blue_cell) begin
          pixel_data <= COLOR_BLUE;
        end 
        // 判断是否在红色目标点格子内，根据blink_state显示两种颜色闪烁
        else if (in_target_cell) begin
          if (blink_state) begin
            pixel_data <= COLOR_RED;      // 闪烁时显示红色
          end else begin
            pixel_data <= COLOR_WHITE;    // 闪烁时显示白色
          end
        end 
        // 其他区域为白色背景
        else begin
          pixel_data <= COLOR_WHITE;
        end
      end else begin
        pixel_data <= COLOR_BG;
      end
    end
  end
end

endmodule