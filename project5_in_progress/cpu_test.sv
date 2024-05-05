module cpu_test;

reg rst;
reg ram_clk_read=0;
reg ram_clk_write=1;
reg sim_end; //DEBUG info

cpu cpu(.rst(rst), .clkb(ram_clk_read), .clka(ram_clk_write));

always #1 ram_clk_read = ~ram_clk_read;
always #1 ram_clk_write = ~ram_clk_write;

initial begin
    $dumpfile("cpu.vcd");
    $dumpvars(0,cpu_test);
    rst=1;
    #1
    rst=0;
    #40
    //$stop();
    sim_end=1; //DEBUG info
    $finish();
end

endmodule