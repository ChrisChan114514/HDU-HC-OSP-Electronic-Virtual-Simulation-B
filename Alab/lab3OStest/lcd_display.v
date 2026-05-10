module lcd_display(
    input             lcd_clk,                  //lcd驱动时钟
    input             sys_rst_n,                //复位信号
    
    input      [10:0] pixel_xpos,               //像素点横坐标
    input      [10:0] pixel_ypos,               //像素点纵坐标    
    output  reg   [15:0] pixel_data                //像素点数据
    );    
 

localparam BLACK = 16'b00000_000000_00000;
localparam THRESHOLD = 6'd31;//二值化阈值

wire rom_rd_en;//读ROM使能信号
reg [13:0] rom_addr;//读ROM地址


wire [15:0] rom_data;//ROM输出数据
assign rom_rd_en = 1'b1;



always@(posedge lcd_clk or negedge sys_rst_n)begin
    if(!sys_rst_n)
        rom_addr <= 14'd0;
    else
        rom_addr <= pixel_xpos / 5 + (pixel_ypos / 5) * 160;
end

reg [13:0] Gray;
reg [15:0] Gray_erzhi;
reg [13:0] red_r1;
reg [13:0] green_r1;
reg [13:0] blue_r1;


//灰度处理
always  @(posedge lcd_clk or negedge sys_rst_n)begin
    if(sys_rst_n==1'b0)begin
	 red_r1   <= 0 ;  
       green_r1 <= 0 ;
       blue_r1  <= 0 ;
    end
    else begin
       red_r1   <= rom_data[15:11]   * 77 ;        //放大后的值
       green_r1 <= rom_data[10:5] * 150;
       blue_r1  <= rom_data[4:0]  * 29 ;
    end
end

always  @(posedge lcd_clk or negedge sys_rst_n)begin
    if(sys_rst_n==1'b0)begin
        Gray <= 0;    // 三个数之和
		  
    end
    else begin
        Gray <= red_r1 + green_r1 + blue_r1; 
        		  
    end
end

always  @(posedge lcd_clk or negedge sys_rst_n)begin
    if(sys_rst_n==1'b0)begin
        
		  Gray_erzhi <= 0;
    end
    else begin
        
        Gray_erzhi <=  Gray[13:8]>THRESHOLD?16'b1111111111111111:16'b0000000000000000;
    end
end

always  @(posedge lcd_clk or negedge sys_rst_n)begin
    if(sys_rst_n==1'b0)begin
       pixel_data <= 0;  //输出的灰度数据
    end
    else begin
       pixel_data <= Gray_erzhi;//{ Gray_erzhi[13:9], Gray_erzhi[13:8], Gray_erzhi[13:9] };//将Gray值赋值给RGB三个通道
    end
end



	
	//通过调用IP核来例化ROM
	pic_rom pic_rom_inst(
		.clock (lcd_clk),
		.address (rom_addr),
		.rden (rom_rd_en),
		.q (rom_data)
	
	);
    endmodule 
