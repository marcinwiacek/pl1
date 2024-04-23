module cpu_test;

reg rst;
reg ram_clk;
reg sim_end; //DEBUG info

cpu cpu(rst,
    ram_clk);

always #1 ram_clk = ~ram_clk;

initial begin
    $dumpfile("cpu.vcd");
    $dumpvars(0,cpu_test);
    ram_clk=0;
    rst=1;
    #1
    rst=0;
    #20
    //$stop();
    sim_end=1; //DEBUG info
    $finish();
end

endmodule