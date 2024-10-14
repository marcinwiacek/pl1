`timescale 1ns / 1ps

module x_simple_test;

wire tx;
reg clk = 0;
reg rst;
reg btnc = 0;

x_simple x_simple (
    .clk(clk),  .uart_rx_out(tx), .btnc(btnc)
);

always #1 clk = ~clk;

initial begin
    $dumpfile("x_simple.vcd");
    $dumpvars(0,x_simple);
    rst=1;
    #1
    rst=0;
    #100000
    $finish();
end

endmodule