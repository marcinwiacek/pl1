module cpu2 (
    input rst
);

  wire [7:0] stage2_input;
  wire stage2_exec;
  wire stage2_exec_ready;
  wire [7:0] stage3_input;
  wire stage3_exec;
  wire stage3_exec_ready;

  stage1 stage1 (
      .rst(rst),
      .stage2_input(stage2_input),
      .stage2_exec(stage2_exec),
      .stage2_exec_ready(stage2_exec_ready)
  );
  stage2 stage2 (
      .stage2_exec(stage2_exec),
      .stage2_input(stage2_input),
      .stage3_input(stage3_input),
      .stage2_exec_ready(stage2_exec_ready),
      .stage3_exec(stage3_exec)
  );
  stage3 stage3 (
      .stage3_exec(stage3_exec),
      .stage3_input(stage3_input),
      .stage3_exec_ready(stage3_exec_ready)
  );

endmodule

module stage1 (
    output reg [7:0] stage2_input,
    input rst,
    output reg stage2_exec,
    input stage2_exec_ready
);

  reg [7:0] inp =0;

  always @(posedge rst, posedge stage2_exec_ready) begin
    stage2_exec = 0;
    $display($time, " stage1 start ", inp);
#1
    $display($time, " stage1 end   ", inp);
    stage2_input = inp;
    inp++;
    stage2_exec = 1;
  end
endmodule

module stage2 (
    input [7:0] stage2_input,
    output reg [7:0] stage3_input,
    input stage2_exec,
    output reg stage2_exec_ready,
    output reg stage3_exec,
    input stage3_exec_ready
);

  always @(posedge stage2_exec) begin
    stage3_exec = 0;
    stage2_exec_ready = 0;
    $display($time, " stage2 start ", stage2_input);
#1
    stage2_exec_ready = 1;
    $display($time, " stage2 end   ", stage2_input);
    stage3_input = stage2_input;
    stage3_exec = 1;
    stage2_exec_ready = 1;
  end
endmodule

module stage3 (
    input stage3_exec,
    input [7:0] stage3_input,
    output reg stage3_exec_ready
);

  always @(posedge stage3_exec) begin
    stage3_exec_ready = 0;
    $display($time, " stage3 start ", stage3_input);
#1
    $display($time, " stage3 end   ", stage3_input, "*");
    stage3_exec_ready = 1;
  end
endmodule
