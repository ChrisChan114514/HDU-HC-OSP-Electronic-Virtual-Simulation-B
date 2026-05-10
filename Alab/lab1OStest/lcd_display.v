module lcd_display(
    input             lcd_clk,                  //lcd驱动时钟
    input             sys_rst_n,                //复位信号
    
    input      [10:0] pixel_xpos,               //像素点横坐标
    input      [10:0] pixel_ypos,               //像素点纵坐标    
    output reg [23:0] pixel_data                //像素点数据
    );    
 
parameter H_DISP = 11'd800;//分辨率一行
parameter V_DISP = 11'd480;//分辨率一列
 
localparam WHITE  = 24'b11111111_11111111_11111111;     //RGB888 白色
localparam BLACK  = 24'b00000000_00000000_00000000;     //RGB888 黑色
localparam RED    = 24'b11111111_00000000_00000000;     //RGB888 红色
localparam GREEN  = 24'b00000000_11111111_00000000;     //RGB888 绿色
localparam BLUE   = 24'b00000000_00000000_11111111;     //RGB888 蓝色

    
    
  //LCD彩条显示
     always @(posedge lcd_clk or negedge sys_rst_n) begin         
          if (!sys_rst_n)
              pixel_data <= 24'd0;
          else begin
          
            if((pixel_xpos >=0) && (pixel_xpos < (H_DISP/5)*1))                                              
                pixel_data <= WHITE;                               
            else if((pixel_xpos >= (H_DISP/5)*1) && (pixel_xpos < (H_DISP/5)*2))  
                pixel_data <= BLACK;
            else if((pixel_xpos >= (H_DISP/5)*2) && (pixel_xpos < (H_DISP/5)*3))
                pixel_data <= RED;    
                
            else if((pixel_xpos >= (H_DISP/5)*3) && (pixel_xpos < (H_DISP/5)*4))
                pixel_data <= GREEN;  
            else 
            
                pixel_data <= BLUE;
          end
      end
/*always @(posedge lcd_clk or negedge sys_rst_n) begin         
          if (!sys_rst_n)
              pixel_data <= 24'd0;
          else pixel_data <= RED;
      end    //LCD设置界面显示红色
*/

    endmodule 
