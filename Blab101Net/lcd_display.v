module lcd_display(
  input        lcd_clk,        // LCD驱动时钟
  input        sys_rst_n,      // 复位信号
  input [10:0] pixel_xpos,     // 像素点横坐标(1-800)
  input [10:0] pixel_ypos,     // 像素点纵坐标(1-480)
  output reg [23:0] pixel_data // 像素点数据(RGB888)
);

//-----------------------------------------------------------------------------//
// 参数定义
//-----------------------------------------------------------------------------//
localparam H_DISP = 11'd800;  // 水平分辨率
localparam V_DISP = 11'd480;  // 垂直分辨率

// 网格参数: 24行 × 40列
localparam [10:0] CELL_W = 11'd20; // 每个格子宽度: 800 / 40 = 20像素
localparam [10:0] CELL_H = 11'd20; // 每个格子高度: 480 / 24 = 20像素

// 颜色定义
localparam COLOR_WHITE = 24'hFFFFFF; // 背景白色
localparam COLOR_BLACK = 24'h000000; // 网格线黑色
localparam COLOR_RED   = 24'hFF0000; // 填充格子红色

// 要填充颜色的格子位置 (列, 行)
localparam [5:0] FILL_COL = 6'd15;  // 第15列 (0-39)
localparam [4:0] FILL_ROW = 5'd10;  // 第10行 (0-23)

//-----------------------------------------------------------------------------//
// 坐标计算
//-----------------------------------------------------------------------------//
// 将输入坐标(1-800, 1-480)映射到(0-799, 0-479)
wire [10:0] x_pos = (pixel_xpos == 11'd0) ? 11'd0 : pixel_xpos - 11'd1;
wire [10:0] y_pos = (pixel_ypos == 11'd0) ? 11'd0 : pixel_ypos - 11'd1;

// 判断是否在有效显示区域内
wire in_active_area = (pixel_xpos >= 11'd1) && (pixel_xpos <= H_DISP) &&
                      (pixel_ypos >= 11'd1) && (pixel_ypos <= V_DISP);

// 判断当前像素是否在网格线上 (1像素宽)
wire vert_grid_line = (x_pos % CELL_W) == 11'd0;  // 垂直网格线
wire hori_grid_line = (y_pos % CELL_H) == 11'd0;  // 水平网格线
wire is_grid_line = vert_grid_line || hori_grid_line;

// 计算当前像素所在的网格位置
wire [5:0] cur_col = x_pos / CELL_W;  // 当前列 (0-39)
wire [4:0] cur_row = y_pos / CELL_H;  // 当前行 (0-23)

// 判断是否在需要填充颜色的格子内
wire in_fill_cell = (cur_col == FILL_COL) && (cur_row == FILL_ROW);

//-----------------------------------------------------------------------------//
// 像素显示逻辑
//-----------------------------------------------------------------------------//
always @(posedge lcd_clk or negedge sys_rst_n) begin
  if (!sys_rst_n) begin
    pixel_data <= COLOR_WHITE;
  end else begin
    if (in_active_area) begin
      // 显示优先级: 网格线 > 填充格子 > 白色背景
      if (is_grid_line) begin
        pixel_data <= COLOR_BLACK;  // 网格线显示黑色
      end else if (in_fill_cell) begin
        pixel_data <= COLOR_RED;    // 指定格子填充红色
      end else begin
        pixel_data <= COLOR_WHITE;  // 其他区域显示白色
      end
    end else begin
      pixel_data <= COLOR_BLACK;    // 非显示区域黑色
    end
  end
end

endmodule