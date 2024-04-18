module cpu3 (
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
      .stage3_exec(stage3_exec),
      .stage3_exec_ready(stage3_exec_ready)
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

  reg [7:0] inp = 0;

  always @(posedge rst, posedge stage2_exec_ready) begin
    stage2_exec = 0;
    $display($time, " stage1 start ", inp);
    #1 $display($time, " stage1 end   ", inp);
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

  reg stage2_start = 0;
  reg first_run = 1;
  reg inp;

  always @(posedge stage2_exec, posedge stage3_exec_ready) begin
    if ((stage3_exec_ready || first_run) && stage2_exec) stage2_start = 1;
    first_run = 0;
  end

  always @(posedge stage2_start) begin
    stage2_start = 0;
    stage3_exec = 0;
    stage2_exec_ready = 0;
    inp = stage2_input;
    stage2_exec_ready = 1;
    $display($time, " stage2 start ", inp);
    #1 $display($time, " stage2 end   ", inp);
    stage3_input = inp;
    stage3_exec  = 1;
  end
endmodule

module stage3 (
    input stage3_exec,
    input [7:0] stage3_input,
    output reg stage3_exec_ready
);

  reg inp;
  always @(posedge stage3_exec) begin
    stage3_exec_ready <= 0;
    inp = stage3_input;
    $display($time, " stage3 start ", inp);
    stage3_exec_ready <= 1;
    #1 $display($time, " stage3 end   ", inp, "*");
  end
endmodule
