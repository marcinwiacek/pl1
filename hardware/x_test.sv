`timescale 1ns / 1ps

module x_test;

wire tx;
reg clk = 0;
reg rst=1;

x x (
    .clk(clk), .uart_rx_out(tx), .rst(rst)
);

always #1 clk = ~clk;

initial begin
    $dumpfile("x.vcd");
    $dumpvars(0,x_test);
    #1
    rst=0;
    #1000000000
    $finish();
end

endmodule