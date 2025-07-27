`timescale 1ns / 1ps

module x_out_of_order5_test;

reg clk = 0;
reg x;

x_out_of_order5 x_out_of_order5 (
    .clk(clk), .x(x)
);

always #1 clk = ~clk;

initial begin
    $dumpfile("x_out_of_order5.vcd");
    $dumpvars(0,x_out_of_order5_test);
    #200
    $finish();
end

endmodule