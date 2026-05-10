module lcd_display(
    input        lcd_clk,        // LCD驱动时钟
    input        sys_rst_n,      // 复位信号
    input [10:0] pixel_xpos,     // 像素点横坐标(0-799)
    input [10:0] pixel_ypos,     // 像素点纵坐标(0-479)
    output reg [23:0] pixel_data // 像素点数据(RGB888)
);

parameter H_DISP = 11'd800;  // 水平分辨率
parameter V_DISP = 11'd480;  // 垂直分辨率

// 存储图片像素数据的数组
reg [7:0] image_data[0:799][0:479];

// 初始化图片数据
initial begin
  // 这里应该加载图片数据到image_data数组中
  // 例如：image_data[0][0] = 8'hFF; // 白色
  // 需要根据实际图片数据进行填充
end

// 将灰度值转换为RGB888格式
function [23:0] gray_to_rgb;
  input [7:0] gray;
  begin
		gray_to_rgb = {8'hFF, gray, gray, gray};
  end
endfunction

// 根据坐标获取像素数据
always @(posedge lcd_clk or negedge sys_rst_n) begin
  if (!sys_rst_n) begin
		pixel_data <= 24'd0;
  end else begin
		if ((pixel_xpos < H_DISP) && (pixel_ypos < V_DISP)) begin
			 pixel_data <= gray_to_rgb(image_data[pixel_xpos][pixel_ypos]);
		end else begin
			 pixel_data <= 24'd0; // 黑色
		end
  end
end

endmodule