

module lcd_rom_pic(
    input           sys_clk,        
    input           sys_rst_n,      
    output          lcd_hs,         
    output          lcd_vs,         
    output          lcd_de,         
    output  [23:0]  lcd_rgb,        
    output          lcd_bl,         
    output          lcd_rst,        
    output          lcd_pclk        
    );


wire         lcd_clk_w;            
wire         locked_w;              
wire         rst_n_w;               
wire [15:0]  pixel_data_w;          
wire [ 10:0]  pixel_xpos_w;          
wire [ 10:0]  pixel_ypos_w; 
wire  [15:0] lcd_rgb565;
//待PLL输出稳定之后，停止复位
assign rst_n_w = sys_rst_n & locked_w;
assign lcd_rgb = {lcd_rgb565[15:11],3'b000,lcd_rgb565[10:5],2'b00,lcd_rgb565[4:0],3'b000};
lcd_pll	u_lcd_pll(                  //时钟分频模块
	.inclk0         (sys_clk),    
	.areset         (~sys_rst_n),
    
	.c0             (lcd_clk_w),    //lcd驱动时钟
	.locked         (locked_w)
	); 
lcd_driver u_lcd_driver(            //lcd驱动模块
    .lcd_clk        (lcd_clk_w),    
    .sys_rst_n      (rst_n_w),    

    .lcd_hs         (lcd_hs),       
    .lcd_vs         (lcd_vs),       
    .lcd_de         (lcd_de),       
    .lcd_rgb        (lcd_rgb565),
    .lcd_bl         (lcd_bl),
    .lcd_rst        (lcd_rst),
    .lcd_pclk       (lcd_pclk),
    
    .pixel_data     (pixel_data_w), 
    .pixel_xpos     (pixel_xpos_w), 
    .pixel_ypos     (pixel_ypos_w)
    );  
lcd_display u_lcd_display(          //lcd显示模块
    .lcd_clk        (lcd_clk_w),    
    .sys_rst_n      (rst_n_w),
    
    .pixel_xpos     (pixel_xpos_w),
    .pixel_ypos     (pixel_ypos_w),
    .pixel_data     (pixel_data_w)
    );   
endmodule