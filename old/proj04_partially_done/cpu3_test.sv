`timescale 1ns / 1ps

module cpu3_test;


reg rst;
wire stage4_data;

cpu3 cpu3(rst,stage4_data);

//always #1 ram_clk = ~ram_clk;

initial begin
    $dumpfile("cpu.vcd");
    $dumpvars(0,cpu3_test);
    rst=1;
    rst=0;
    #20
    $finish();
end

endmodule