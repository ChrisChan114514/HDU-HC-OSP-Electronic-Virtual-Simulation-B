module lcd_display(
  input        lcd_clk,        // LCD驱动时钟
  input        sys_rst_n,      // 复位信号
  input        move_en,        // 红色块移动使能（拨动开关）
  input [10:0] pixel_xpos,     // 像素点横坐标(0-799)
  input [10:0] pixel_ypos,     // 像素点纵坐标(0-479)
  output reg [23:0] pixel_data // 像素点数据(RGB888)
);

//-----------------------------------------------------------------------------//
// Parameter definition
//-----------------------------------------------------------------------------//
localparam H_DISP = 11'd800;  // 水平分辨率
localparam V_DISP = 11'd480;  // 垂直分辨率

localparam CELL_COLS = 8;
localparam CELL_ROWS = 6;
localparam [10:0] CELL_W = 11'd100; // 800 / 8
localparam [10:0] CELL_H = 11'd80;  // 480 / 6

localparam COLOR_WHITE = 24'hFFFFFF;
localparam COLOR_BLACK = 24'h000000;
localparam COLOR_RED   = 24'hFF0000;
localparam COLOR_BG    = 24'h000000;
// 红色块位置计数器
reg [2:0] red_col; // 0~7
reg [2:0] red_row; // 0~5
reg move_en_d;

wire [10:0] x_pos = (pixel_xpos == 11'd0) ? 11'd0 : pixel_xpos - 11'd1; // 映射到 0~799
wire [10:0] y_pos = (pixel_ypos == 11'd0) ? 11'd0 : pixel_ypos - 11'd1; // 映射到 0~479

wire in_active_area = (pixel_xpos >= 11'd1) && (pixel_xpos <= H_DISP) &&
                      (pixel_ypos >= 11'd1) && (pixel_ypos <= V_DISP);

wire vert_grid_line = (x_pos == 11'd0) ||
                      ((x_pos % CELL_W) == 11'd0) ||
                      ((x_pos + 11'd1) % CELL_W == 11'd0) ||
                      (x_pos == (H_DISP - 11'd1));

wire hori_grid_line = (y_pos == 11'd0) ||
                      ((y_pos % CELL_H) == 11'd0) ||
                      ((y_pos + 11'd1) % CELL_H == 11'd0) ||
                      (y_pos == (V_DISP - 11'd1));

// 当前红色块所在网格
wire [10:0] red_x_start = red_col * CELL_W;
wire [10:0] red_x_end   = red_x_start + CELL_W;
wire [10:0] red_y_start = (CELL_ROWS-1-red_row) * CELL_H; // 最下行是row=0
wire [10:0] red_y_end   = red_y_start + CELL_H;
wire in_red_cell = (x_pos >= red_x_start) && (x_pos < red_x_end) &&
                   (y_pos >= red_y_start) && (y_pos < red_y_end);

//-----------------------------------------------------------------------------//
// 根据像素坐标输出网格与红色填充
//-----------------------------------------------------------------------------//
always @(posedge lcd_clk or negedge sys_rst_n) begin
  if (!sys_rst_n) begin
    pixel_data <= COLOR_BG;
    red_col <= 3'd0;
    red_row <= 3'd0;
    move_en_d <= 1'b0;
  end else begin
    // 红色块移动逻辑（move_en上升沿）
    move_en_d <= move_en;
    if (!move_en_d && move_en) begin
      if (red_col < CELL_COLS-1) begin
        red_col <= red_col + 1'b1;
      end else if (red_row < CELL_ROWS-1) begin
        red_col <= 3'd0;
        red_row <= red_row + 1'b1;
      end
      // 到最右上角后不再移动
    end
    // 像素显示逻辑
    if (!in_active_area) begin
      pixel_data <= COLOR_BG;
    end else if (vert_grid_line || hori_grid_line) begin
      pixel_data <= COLOR_BLACK;
    end else if (in_red_cell) begin
      pixel_data <= COLOR_RED;
    end else begin
      pixel_data <= COLOR_WHITE;
    end
  end
end

endmodule