`timescale 1ns / 1ps

module x_test;

wire tx;
reg clk = 0;
reg rst;
reg btnc = 0;

x x (
    .clk(clk),  .uart_rx_out(tx), .btnc(btnc)
);

always #1 clk = ~clk;

initial begin
    $dumpfile("x.vcd");
    $dumpvars(0,x_test);
    rst=1;
    #1
    rst=0;
    #10
    $finish();
end

endmodule