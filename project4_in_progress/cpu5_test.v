`timescale 1ns / 1ps

module cpu5_test;


reg rst;
wire stage4_data;

cpu5 cpu5(rst,stage4_data);

//always #1 ram_clk = ~ram_clk;

initial begin
    $dumpfile("cpu.vcd");
    $dumpvars(0,cpu5_test);
    rst=1;
    #1
    rst=0;
    #20
    $finish();
end

endmodule