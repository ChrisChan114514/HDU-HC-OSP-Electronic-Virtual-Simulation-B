module image_rom #(
  parameter integer DATA_WIDTH    = 24,
  parameter integer ADDR_WIDTH    = 15,
  parameter integer DEPTH         = 22500,
  parameter        HEX_INIT_FILE  = "",
  parameter        MIF_INIT_FILE  = "rom/lcd_image.mif"
)(
  input                          clk,
  input      [ADDR_WIDTH-1:0]    addr,
  output     [DATA_WIDTH-1:0]    dout
);

  // 使用altsyncram IP核确保正确初始化
  altsyncram #(
    .operation_mode("ROM"),
    .width_a(DATA_WIDTH),
    .widthad_a(ADDR_WIDTH),
    .numwords_a(DEPTH),
    .init_file(MIF_INIT_FILE),
    .outdata_reg_a("UNREGISTERED"),
    .address_aclr_a("NONE"),
    .outdata_aclr_a("NONE"),
    .read_during_write_mode_mixed_ports("DONT_CARE"),
    .ram_block_type("M9K"),
    .intended_device_family("Cyclone IV E")
  ) altsyncram_component (
    .clock0(clk),
    .address_a(addr),
    .q_a(dout),
    .aclr0(1'b0),
    .aclr1(1'b0),
    .addressstall_a(1'b0),
    .addressstall_b(1'b0),
    .byteena_a(1'b1),
    .byteena_b(1'b1),
    .clock1(1'b1),
    .clocken0(1'b1),
    .clocken1(1'b1),
    .clocken2(1'b1),
    .clocken3(1'b1),
    .data_a({DATA_WIDTH{1'b1}}),
    .data_b(1'b1),
    .eccstatus(),
    .q_b(),
    .rden_a(1'b1),
    .rden_b(1'b1),
    .wren_a(1'b0),
    .wren_b(1'b0)
  );

endmodule
