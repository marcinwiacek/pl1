`timescale 1ns / 1ps

module x_async_test;

wire tx;
reg clk = 0;
reg rst;
reg btnc = 0;

x_async x_async (
    .clk(clk),  .uart_rx_out(tx), .btnc(btnc)
);

always #1 clk = ~clk;

initial begin
    $dumpfile("x_async.vcd");
    $dumpvars(0,x_async_test);
    rst=1;
    #1
    rst=0;
    #200
    $finish();
end

endmodule