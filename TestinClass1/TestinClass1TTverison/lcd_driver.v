module lcd_driver( 
 input lcd_clk, //lcd 模块驱动时钟 
 input sys_rst_n, //复位信号 
 
 //下列信号与 RGBLCD 屏幕相连接 
 output lcd_hs, //LCD 行同步信号 
 output lcd_vs, //LCD 场同步信号 
 output lcd_de, //LCD 数据使能 
 output [23:0] lcd_rgb, //LCD RGB888 颜色数据 
 output lcd_bl, //LCD 背光控制信号 
 output lcd_rst, //LCD 复位信号 
 output lcd_pclk, //LCD 采样时钟 
 
 //接口信号，此模块推出 valid 坐标值，并接收用户发来的 RGB888 的像素点颜值 
 input [23:0] pixel_data, //像素点数据 
 output [10:0] pixel_xpos, //像素点横坐标 
 output [10:0] pixel_ypos //像素点纵坐标 
 ); 
  //参数列表 
 parameter H_SYNC = 11'd46; //行同步 
 parameter H_BACK = 11'd0; //行显示后沿 
 parameter H_DISP = 11'd800; //行有效数据 
 parameter H_FRONT = 11'd210; //行显示前沿 
 parameter H_TOTAL = 11'd1056; //行扫描周期 
 
 parameter V_SYNC = 11'd23; //场同步 
 parameter V_BACK = 11'd0; //场显示后沿 
 parameter V_DISP = 11'd480; //场有效数据 
 parameter V_FRONT = 11'd22; //场显示前沿 
 parameter V_TOTAL = 11'd525; //场扫描周期 
 
 //子母两个计数器 
 reg [10:0] cnt_h; 
 reg [10:0] cnt_v; 
 
 //... 
 wire lcd_en; 
 wire data_req; 
 
 //对 lcd 屏幕的某些信号加以固定 
 assign lcd_bl = 1'b1; 
 assign lcd_rst = 1'b1; 
 assign lcd_pclk = lcd_clk; 
 assign lcd_hs = 1'b1; 
 assign lcd_vs = 1'b1; 
 
 //当子母计数器的值处于 valid 范围内时，将 lcd_de 拉高，此时输出 lcd_rgb[23:0]的值到屏幕的对应像素点上。 
 assign lcd_de = lcd_en; 
 assign lcd_en = (((cnt_h > H_SYNC+H_BACK) && (cnt_h <= H_SYNC+H_BACK+H_DISP)) &&((cnt_v > V_SYNC+V_BACK) && (cnt_v <= V_SYNC+V_BACK+V_DISP))) ? 1'b1 : 1'b0; 
 
 //lcd_rgb[23:0]的值由用户(input)给予即为：pixel_data 
 assign lcd_rgb = lcd_en ? pixel_data : 24'd0; 
 
 //...此处做一个简单的分析，lcd_de 拉高，lcd_rgb[23:0]的值瞬间到达屏幕的对应像素点上。 
 // 我们最开始的分析是：cnt 值->产生坐标->根据坐标确认有效范围->再往范围里放颜色值  // 所以说我们在上面写的那个就是有效范围,由于触发器的特性，所以要提前一个时钟周期将坐标值送出，才来的及在 lcd_en 为 1 时候准确的送出颜色值 
 // 而一场是由很多行组成的，母计数器，要比子计数器慢。子计数器变很多次，母计数器才变一次。所以对子计数器需要提前一个时钟周期发送出坐标。 
 
 assign data_req = (((cnt_h > H_SYNC+H_BACK-1'b1) && (cnt_h <= H_SYNC+H_BACK+H_DISP-1'b1)) //对子计数器需要提前一个时钟周期发送出坐标。 
 && ((cnt_v > V_SYNC+V_BACK) && (cnt_v <= V_SYNC+V_BACK+V_DISP))) //母计数器不变 
 ? 1'b1 : 1'b0; 
 
 //当前像素点坐标 
 assign pixel_xpos = data_req ? (cnt_h - (H_SYNC + H_BACK - 1'b1)) : 11'd0; 
 assign pixel_ypos = data_req ? ((cnt_v - (V_SYNC + V_BACK - 1'b1)) - 1'b1) : 11'd0; 
 
 
 //行计数器对像素时钟计数（子） 
 always @(posedge lcd_clk or negedge sys_rst_n) begin 
 if (!sys_rst_n) 
 cnt_h <= 11'd0; 
 else begin 
 if(cnt_h < H_TOTAL - 1'b1) 
 cnt_h <= cnt_h + 1'b1; 
 else 
 cnt_h <= 11'd0; 
 end 
 end 
 
 //场计数器对行计数（母） 
 always @(posedge lcd_clk or negedge sys_rst_n) begin 
 if (!sys_rst_n) 
 cnt_v <= 11'd0; 
 else if(cnt_h == H_TOTAL - 1'b1) begin 
 if(cnt_v < V_TOTAL - 1'b1) 
 cnt_v <= cnt_v + 1'b1; 
 else 
 cnt_v <= 11'd0; 
 end 
 end 
 
 endmodule 
