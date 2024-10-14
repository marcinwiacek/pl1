`timescale 1ns / 1ps

module cpu4 (
    input rst,
    output reg stage4_data
);

  wire [7:0] stage2_input;
  wire stage2_exec;
  wire stage2_exec_ready;
  wire [7:0] stage3_input;
  wire stage3_exec;
  wire stage3_exec_ready;

  stage1 stage1 (
      .rst(rst),
	//in
      .stage2_input(stage2_input),
	//out
      .stage2_exec(stage2_exec),
      .stage2_exec_ready(stage2_exec_ready)
  );
  stage2 stage2 (
	//in
      .stage2_exec(stage2_exec),
      .stage2_input(stage2_input),
      .stage2_exec_ready(stage2_exec_ready),
	//out
      .stage3_input(stage3_input),
      .stage3_exec(stage3_exec),
      .stage3_exec_ready(stage3_exec_ready)
  );
  stage3 stage3 (
	//in
      .stage3_exec(stage3_exec),
      .stage3_input(stage3_input),
	//out
      .stage3_exec_ready(stage3_exec_ready)
  );

endmodule

module stage1 (
    output reg [7:0] stage2_input,
    input rst,
    output reg stage2_exec,
    input stage2_exec_ready
);

  reg [7:0] stage1_input = 0;
  reg stage1_start = 0;

  always @(posedge rst ) begin
    stage1_start <= 1;
  end

  always @(posedge stage2_exec_ready) begin
    stage1_start <= 1;
  end

  always @( posedge stage1_start) begin
    stage1_start <= 0;
    stage2_exec <= 0;
    $display( " stage1 start ", stage1_input);
    #1 $display( " stage1 end   ", stage1_input);
    stage2_input <= stage1_input;
    stage1_input<=stage1_input+1;
    stage2_exec <= 1;
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
  reg [7:0] inp;

  always @(posedge stage2_exec) begin
    if (stage3_exec_ready || first_run) begin
        inp <= stage2_input;
        first_run <= 0;
	stage2_start <= 1;
    end
  end

  always @(posedge stage3_exec_ready) begin
    if ((stage3_exec_ready || first_run) && stage2_exec) begin
        inp <= stage2_input;
        first_run <= 0;
	stage2_start <= 1;
    end
  end

  always @(posedge stage2_start) begin
    stage2_start <= 0;
    stage3_exec <= 0;
    stage2_exec_ready <= 0;
    $display( " stage2 start ", inp);
    #3 $display( " stage2 end   ", inp);
    stage2_exec_ready <= 1;
    stage3_input <= inp;
    stage3_exec  <= 1;
  end
endmodule

module stage3 (
    input stage3_exec,
    input [7:0] stage3_input,
    output reg stage3_exec_ready
);

  reg [7:0] inp;
  always @(posedge stage3_exec) begin
    stage3_exec_ready <= 0;
    inp <= stage3_input;
    $display( " stage3 start ", inp);
    #2 $display( " stage3 end   ", inp, "*");
    stage3_exec_ready <= 1;
  end
endmodule
