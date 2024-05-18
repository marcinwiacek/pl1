`timescale 1ns / 1ps

module cpu4_test;


reg rst;
wire stage4_data;

cpu4 cpu4(rst,stage4_data);

//always #1 ram_clk = ~ram_clk;

initial begin
    $dumpfile("cpu.vcd");
    $dumpvars(0,cpu4_test);
    rst=1;
    #1
    rst=0;
    #20
    $finish();
end

endmodule