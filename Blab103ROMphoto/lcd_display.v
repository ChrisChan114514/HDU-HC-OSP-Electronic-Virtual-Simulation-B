module lcd_display(
  input        lcd_clk,        // LCD驱动时钟
  input        sys_rst_n,      // 复位信号
  input [10:0] pixel_xpos,     // 像素点横坐标(1-800)
  input [10:0] pixel_ypos,     // 像素点纵坐标(1-480)
  output reg [23:0] pixel_data // 像素点数据(RGB888)
);

//-----------------------------------------------------------------------------//
// Parameter definition
//-----------------------------------------------------------------------------//
localparam H_DISP = 11'd800;  // 水平有效分辨率
localparam V_DISP = 11'd480;  // 垂直有效分辨率

localparam IMG_WIDTH  = 150;
localparam IMG_HEIGHT = 150;
localparam IMG_PIXELS = 22500;  // 150 * 150，直接使用常量避免计算错误

localparam IMG_START_X = (H_DISP - IMG_WIDTH)  >> 1; // 水平居中
localparam IMG_START_Y = (V_DISP - IMG_HEIGHT) >> 1; // 垂直居中

localparam COLOR_BACKGROUND = 24'h000000; // 背景色（黑）

// 22500像素需要15位地址（2^15=32768 > 22500）
localparam IMG_ADDR_WIDTH = 15;

//-----------------------------------------------------------------------------//
// 坐标与有效区域判定
//-----------------------------------------------------------------------------//
wire frame_active = (pixel_xpos >= 11'd1) && (pixel_xpos <= H_DISP) &&
                    (pixel_ypos >= 11'd1) && (pixel_ypos <= V_DISP);

wire [10:0] x_pos = pixel_xpos - 11'd1;
wire [10:0] y_pos = pixel_ypos - 11'd1;

wire in_image_window = frame_active &&
                       (x_pos >= IMG_START_X) && (x_pos < (IMG_START_X + IMG_WIDTH)) &&
                       (y_pos >= IMG_START_Y) && (y_pos < (IMG_START_Y + IMG_HEIGHT));

wire [10:0] img_x = in_image_window ? (x_pos - IMG_START_X) : 11'd0;
wire [10:0] img_y = in_image_window ? (y_pos - IMG_START_Y) : 11'd0;

wire [17:0] img_y_shift_128 = {img_y, 7'b0};
wire [17:0] img_y_shift_16  = {img_y, 4'b0};
wire [17:0] img_y_shift_4   = {img_y, 2'b0};
wire [17:0] img_y_shift_2   = {img_y, 1'b0};
wire [17:0] row_offset      = img_y_shift_128 + img_y_shift_16 + img_y_shift_4 + img_y_shift_2; // y * 150
wire [17:0] rom_addr_full   = row_offset + {7'd0, img_x};
wire [IMG_ADDR_WIDTH-1:0] rom_addr_next = in_image_window ? rom_addr_full[IMG_ADDR_WIDTH-1:0]
                                                          : {IMG_ADDR_WIDTH{1'b0}};

reg [IMG_ADDR_WIDTH-1:0] rom_addr_reg;
reg                      in_image_d0;
reg                      in_image_d1;

always @(posedge lcd_clk or negedge sys_rst_n) begin
  if (!sys_rst_n) begin
    rom_addr_reg <= {IMG_ADDR_WIDTH{1'b0}};
    in_image_d0  <= 1'b0;
    in_image_d1  <= 1'b0;
  end else begin
    rom_addr_reg <= rom_addr_next;
    in_image_d0  <= in_image_window;
    in_image_d1  <= in_image_d0;
  end
end

//-----------------------------------------------------------------------------//
// 图像 ROM：包含 150x150 RGB888 像素
//-----------------------------------------------------------------------------//
wire [23:0] rom_pixel_data;

image_rom #(
  .DATA_WIDTH(24),
  .ADDR_WIDTH(IMG_ADDR_WIDTH),
  .DEPTH(IMG_PIXELS),
  .HEX_INIT_FILE("rom/lcd_image.hex"),
  .MIF_INIT_FILE("rom/lcd_image.mif")
) u_image_rom (
  .clk (lcd_clk),
  .addr(rom_addr_reg),
  .dout(rom_pixel_data)
);

//-----------------------------------------------------------------------------//
// 输出像素颜色（对齐 ROM 延迟）
//-----------------------------------------------------------------------------//
always @(posedge lcd_clk or negedge sys_rst_n) begin
  if (!sys_rst_n) begin
    pixel_data <= COLOR_BACKGROUND;
  end else if (!frame_active) begin
    pixel_data <= COLOR_BACKGROUND;
  end else if (in_image_d1) begin
    pixel_data <= rom_pixel_data;
  end else begin
    pixel_data <= COLOR_BACKGROUND;
  end
end

endmodule