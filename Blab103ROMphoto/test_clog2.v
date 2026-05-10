module test;
  function integer clog2;
    input integer value;
    integer i;
    begin
      clog2 = 0;
      for (i = value - 1; i > 0; i = i >> 1)
        clog2 = clog2 + 1;
    end
  endfunction
  
  initial begin
    $display("IMG_PIXELS = %d", 150*150);
    $display("clog2(22500) = %d", clog2(22500));
    $display("2^11 = %d", 2**11);
    $display("2^15 = %d", 2**15);
  end
endmodule
