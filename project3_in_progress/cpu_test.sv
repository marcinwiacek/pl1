module cpu_test;

reg rst;
reg ram_clk;
reg sim_end; //DEBUG info

cpu cpu(rst,
    sim_end, //DEBUG info
    ram_clk);

always #1 ram_clk = ~ram_clk;

initial begin
    $dumpfile("cpu.vcd");
    $dumpvars(0,cpu_test);
    ram_clk=0;
    rst=1;
    #500
    //$stop();
    sim_end=1; //DEBUG info
    $finish();
end

endmodule