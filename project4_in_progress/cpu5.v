`timescale 1ns / 1ps

module cpu5 (
    input rst,
    output reg stage4_data
);

  wire [7:0] stage2_input;
  wire stage2_req;
  wire stage2_ack;
  wire [7:0] stage3_input;
  wire stage3_req;
  wire stage3_ack;

  stage1 stage1 (
	//in
      .rst(rst),
	//out
      .stage2_input(stage2_input),
      .stage2_req(stage2_req),
      .stage2_ack(stage2_ack)
  );
  stage2 stage2 (
	//in
      .stage2_input(stage2_input),
      .stage2_req(stage2_req),
      .stage2_ack(stage2_ack),
	//out
      .stage3_input(stage3_input),
      .stage3_req(stage3_req),
      .stage3_ack(stage3_ack)
  );
  stage3 stage3 (
	//in
      .stage3_input(stage3_input),
      .stage3_req(stage3_req),
      .stage3_ack(stage3_ack)
  );

endmodule

module stage1 (
    input rst,
    output reg [7:0] stage2_input,
    output reg stage2_req,
    input stage2_ack
);

  reg [7:0] stage1_input = 0;
  reg stage1_start = 0;

  always @(posedge rst ) begin
    stage1_start <= 1;
  end
  
  always @(posedge stage2_ack) begin
    stage1_start <= 1;
  end

  always @( posedge stage1_start) begin
    stage1_start <= 0;
    stage2_req <= 0;
    $display( $time, " stage1 start ", stage1_input);
    #2 $display( $time, " stage1 end   ", stage1_input);
    stage2_input <= stage1_input;
    stage1_input<=stage1_input+1;
    stage2_req <= 1;
  end
endmodule

module stage2 (
    input [7:0] stage2_input,
    input stage2_req,
    output reg stage2_ack,
    output reg [7:0] stage3_input,
    output reg stage3_req,
    input stage3_ack
);

  reg stage2_start = 0;
  reg first_run = 1;
  reg [7:0] inp;

 always @(posedge stage2_req or posedge stage3_ack) begin
    if (stage2_req && (stage3_ack || first_run)) begin
        inp <= stage2_input;
	stage2_ack <= 1;
        first_run <= 0;
	stage2_start <= 1;
    end
  end

  always @(posedge stage2_start) begin
    stage2_start <= 0;
    stage3_req <= 0;
    $display( $time, " stage2 start ", inp);
    #3 $display( $time, " stage2 end   ", inp);
    stage2_ack <= 0;
    stage3_input <= inp;
    stage3_req  <= 1;
  end
endmodule

module stage3 (
    input [7:0] stage3_input,
    input stage3_req,
    output reg stage3_ack
);

  reg stage3_start = 0;
  reg stage3_complete = 1;
  reg first_run = 1;
  reg [7:0] inp;

 always @(posedge stage3_req or posedge stage3_complete) begin
    if (stage3_req && stage3_complete) begin
        inp <= stage3_input;
        first_run <= 0;
	stage3_complete <=0;
	stage3_ack <= 1;
	stage3_start <= 1;
    end
  end

  always @(posedge stage3_start) begin
    $display( $time, " stage3 start ", inp);
    #2 $display( $time, " stage3 end   ", inp, "*");
    stage3_start <= 0;
    stage3_ack <= 0;
    stage3_complete <=1;
  end
endmodule
