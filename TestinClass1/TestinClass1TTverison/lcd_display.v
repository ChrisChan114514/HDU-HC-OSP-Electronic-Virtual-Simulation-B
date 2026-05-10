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

// 新的网格参数: 32行 * 40列 (每格 20x15)
localparam CELL_COLS = 40;
localparam CELL_ROWS = 32;
localparam [10:0] CELL_W = 11'd20; // 800 / 40
localparam [10:0] CELL_H = 11'd15; // 480 / 32

localparam COLOR_WHITE = 24'hFFFFFF;
localparam COLOR_BLACK = 24'h000000;
localparam COLOR_RED   = 24'hFF0000;
localparam COLOR_BLUE  = 24'h0000FF;
localparam COLOR_BG    = 24'hFFFFFF;  // 背景为白色

// 目标点和起始点位置
// 注意: 要求中(8,35)超出32行范围，这里调整为(8,23)
localparam [5:0] TARGET_COL = 6'd30;  // 目标点列
localparam [4:0] TARGET_ROW = 5'd8;   // 目标点行
localparam [5:0] START_COL = 6'd8;    // 起始点列
localparam [4:0] START_ROW = 5'd23;   // 起始点行(原要求为35，调整到最后一行23)

// 时钟相关参数 (33MHz)
localparam BLINK_DELAY = 26'd66_000_000; // 2秒闪烁周期
localparam MOVE_DELAY  = 26'd6_600_000;  // 0.2秒/格

// 寄存器定义
reg [25:0] blink_cnt;    // 闪烁计数器
reg        blink_state;  // 闪烁状态

reg [25:0] move_cnt;     // 移动计数器
reg [5:0]  blue_col;     // 蓝色块当前列 (0-39)
reg [4:0]  blue_row;     // 蓝色块当前行 (0-23)
reg [3:0]  move_state;   // 移动状态机

// 移动状态定义
localparam MOVE_IDLE   = 4'd0;
localparam MOVE_RIGHT1 = 4'd1;  // 水平右移6格
localparam MOVE_UP     = 4'd2;  // 垂直上移
localparam MOVE_RIGHT2 = 4'd3;  // 水平右移到目标点
localparam MOVE_RESET  = 4'd4;  // 返回起始点

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

// 起始点/蓝色块判断
wire in_blue_cell = (cur_col == blue_col) && (cur_row == blue_row);

// 判断是否在网格内部(非网格线)
wire in_cell_interior = !vert_grid_line && !hori_grid_line;

//-----------------------------------------------------------------------------//
// 闪烁逻辑 (B2控制)
//-----------------------------------------------------------------------------//
always @(posedge lcd_clk or negedge sys_rst_n) begin
  if (!sys_rst_n) begin
    blink_cnt <= 26'd0;
    blink_state <= 1'b0;
  end else begin
    if (switches[2]) begin  // B2=1时闪烁
      if (blink_cnt >= BLINK_DELAY - 1) begin
        blink_cnt <= 26'd0;
        blink_state <= ~blink_state;
      end else begin
        blink_cnt <= blink_cnt + 1'b1;
      end
    end else begin
      blink_cnt <= 26'd0;
      blink_state <= 1'b1;  // 不闪烁时常亮
    end
  end
end

//-----------------------------------------------------------------------------//
// 蓝色块移动逻辑 (B3控制)
//-----------------------------------------------------------------------------//
always @(posedge lcd_clk or negedge sys_rst_n) begin
  if (!sys_rst_n) begin
    blue_col <= START_COL;
    blue_row <= START_ROW;
    move_cnt <= 26'd0;
    move_state <= MOVE_IDLE;
  end else begin
    if (switches[3]) begin  // B3=1时移动
      if (move_cnt >= MOVE_DELAY - 1) begin
        move_cnt <= 26'd0;
        
        case (move_state)
          MOVE_IDLE: begin
            move_state <= MOVE_RIGHT1;
          end
          
          MOVE_RIGHT1: begin  // 水平右移15格
            if (blue_col < START_COL + 15) begin
              blue_col <= blue_col + 1'b1;
            end else begin
              move_state <= MOVE_UP;
            end
          end
          
          MOVE_UP: begin  // 垂直上移(从行23到行8)
            if (blue_row > TARGET_ROW) begin
              blue_row <= blue_row - 1'b1;
            end else begin
              move_state <= MOVE_RIGHT2;
            end
          end
          
          MOVE_RIGHT2: begin  // 水平右移到目标点(从列23到列30)
            if (blue_col < TARGET_COL) begin
              blue_col <= blue_col + 1'b1;
            end else begin
              move_state <= MOVE_RESET;
            end
          end
          
          MOVE_RESET: begin  // 返回起始点，准备重复
            blue_col <= START_COL;
            blue_row <= START_ROW;
            move_state <= MOVE_RIGHT1;
          end
          
          default: move_state <= MOVE_IDLE;
        endcase
      end else begin
        move_cnt <= move_cnt + 1'b1;
      end
    end else begin
      // B3=0时复位到起始点
      blue_col <= START_COL;
      blue_row <= START_ROW;
      move_cnt <= 26'd0;
      move_state <= MOVE_IDLE;
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
      // 优先级: 网格线 > 蓝色块 > 红色目标点 > 白色背景
      if (vert_grid_line || hori_grid_line) begin
        // 网格线为黑色 (所有模式下都显示)
        if (switches[0] || switches[1] || switches[2] || switches[3]) begin
          pixel_data <= COLOR_BLACK;
        end else begin
          pixel_data <= COLOR_WHITE;  // 没有模式时也显示白色背景
        end
      end else if (in_cell_interior) begin
        // B3模式: 显示移动的蓝色块和红色目标点(闪烁)
        if (switches[3]) begin
          if (in_blue_cell) begin
            pixel_data <= COLOR_BLUE;
          end else if (in_target_cell && blink_state) begin
            pixel_data <= COLOR_RED;
          end else begin
            pixel_data <= COLOR_WHITE;
          end
        end
        // B2模式: 显示蓝色起始点和红色目标点(闪烁)
        else if (switches[2]) begin
          if (in_blue_cell) begin
            pixel_data <= COLOR_BLUE;
          end else if (in_target_cell && blink_state) begin
            pixel_data <= COLOR_RED;
          end else begin
            pixel_data <= COLOR_WHITE;
          end
        end
        // B1模式: 显示蓝色起始点和红色目标点(不闪烁)
        else if (switches[1]) begin
          if (in_blue_cell) begin
            pixel_data <= COLOR_BLUE;
          end else if (in_target_cell) begin
            pixel_data <= COLOR_RED;
          end else begin
            pixel_data <= COLOR_WHITE;
          end
        end
        // B0模式: 仅显示网格
        else if (switches[0]) begin
          pixel_data <= COLOR_WHITE;
        end
        // 全部关闭
        else begin
          pixel_data <= COLOR_WHITE;  // 关闭时也显示白色背景
        end
      end else begin
        pixel_data <= COLOR_WHITE;  // 格子内部默认白色
      end
    end
  end
end

endmodule