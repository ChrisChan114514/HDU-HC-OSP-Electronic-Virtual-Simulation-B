module lcd_rgb_colorbar( 
 input sys_clk, 
 input sys_rst_n,
 input btn_move,      // 红色块移动按钮输入
 output lcd_hs, 
 output lcd_vs, 
 output lcd_de, 
 output [23:0] lcd_rgb, 
 output lcd_bl, 
 output lcd_rst, 
 output lcd_pclk 
 ); 
 
 
wire lcd_clk_w; 
wire locked_w; 
wire rst_n_w; 
wire [23:0] pixel_data_w; 
wire [ 10:0] pixel_xpos_w; 
wire [ 10:0] pixel_ypos_w; 
//待 PLL 输出稳定之后，停止复位 
assign rst_n_w = sys_rst_n & locked_w; 
 
lcd_pll u_lcd_pll( //时钟分频模块 
 .inclk0 (sys_clk), 
 .areset (~sys_rst_n),  
 .c0 (lcd_clk_w), //lcd 驱动时钟 
 .locked (locked_w) 
 );
lcd_driver u_lcd_driver( //lcd 驱动模块 
 .lcd_clk (lcd_clk_w), 
 .sys_rst_n (rst_n_w), 
 
 .lcd_hs (lcd_hs), 
 .lcd_vs (lcd_vs), 
 .lcd_de (lcd_de), 
 .lcd_rgb (lcd_rgb), 
 .lcd_bl (lcd_bl), 
 .lcd_rst (lcd_rst), 
 .lcd_pclk (lcd_pclk), 
 
 .pixel_data (pixel_data_w), 
 .pixel_xpos (pixel_xpos_w), 
 .pixel_ypos (pixel_ypos_w) 
 ); 
lcd_display u_lcd_display( //lcd 显示模块 
 .lcd_clk (lcd_clk_w), 
 .sys_rst_n (rst_n_w),
 .move_en (btn_move),    // 连接按钮到移动使能信号
 
 .pixel_xpos (pixel_xpos_w), 
 .pixel_ypos (pixel_ypos_w), 
 .pixel_data (pixel_data_w) 
 ); 
endmodule