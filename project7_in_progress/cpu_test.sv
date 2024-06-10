`timescale 1ns / 1ps

module cpu_test;

reg rst;
reg ram_clk_read=0;
//reg ram_clk_write=1;
reg sim_end; //DEBUG info
reg tx;
reg vivado = 1;

cpu cpu(.btnc(rst), .clk(ram_clk_read), .tx(tx));

always #1 ram_clk_read = ~ram_clk_read;
//always #1 ram_clk_write = ~ram_clk_write;

initial begin
    $dumpfile("cpu.vcd");
    $dumpvars(0,cpu_test);
    rst=1;
    #1
    rst=0;
    #30
    //$stop();
    sim_end=1; //DEBUG info
    $finish();
end

endmodule

