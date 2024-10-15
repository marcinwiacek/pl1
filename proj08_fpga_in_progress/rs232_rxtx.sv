`timescale 1ns / 1ps

//Reads characters from RS232 input and dumps it into RS232 output
//(115200, 8 bits (LSB first), 1 stop, no parity, for example cu -l /dev/ttyUSB0 -s 115200)
//For Nexys Video:
//## UART
//set_property -dict { PACKAGE_PIN AA19  IOSTANDARD LVCMOS33 } [get_ports { uart_rx_out }]; #IO_L15P_T2_DQS_RDWR_B_14 Sch=uart_rx_out
//set_property -dict { PACKAGE_PIN V18   IOSTANDARD LVCMOS33 } [get_ports { uart_tx_in }]; #IO_L14P_T2_SRCC_14 Sch=uart_tx_in

module x (
    input clk,
    output logic uart_rx_out,
        input uart_tx_in
);

  //uart
  reg [7:0] uart_buffer[0:200];
  reg [6:0] uart_buffer_index = 0;
  wire reset_uart_buffer_index;
  wire uart_buffer_full;
  
  uartx_tx_with_buffer uartx_tx_with_buffer (
    .clk(clk),
    .uart_buffer(uart_buffer),
    .uart_buffer_available(uart_buffer_index),
    .reset_uart_buffer_available(reset_uart_buffer_index),
    .uart_buffer_full(uart_buffer_full),
    .tx(uart_rx_out)
);


wire[7:0] uart_bb;
wire uart_bb_ready;

  uart_rx uart_rx (
    .clk(clk),    
    .uartrx(uart_tx_in),
    .bb(uart_bb),
    .bb_ready(uart_bb_ready)
);

bit flag=1, uart_processed=0;
  
  always @(negedge clk) begin
    if (flag==1) begin
        uart_buffer[0]="a";
         uart_buffer[1]="b";
        uart_buffer_index=2;
        flag=0;
    end else begin
    //  if (reset_uart_buffer_index) begin
//        uart_buffer_index<= 0;
//      end else if (!uart_buffer_full) begin
       if (uart_bb_ready) begin
        if (!uart_processed) begin
          uart_buffer[uart_buffer_index]=uart_bb;
          uart_buffer_index=uart_buffer_index+1;
          uart_processed=1;
        end
       end else begin
          uart_processed=0;
         
       end
  //    end
    end
  end

endmodule


module uartx_tx_with_buffer (
    input clk,
    input [7:0] uart_buffer[0:200],
    input [6:0] uart_buffer_available,
    output bit reset_uart_buffer_available,
    output bit uart_buffer_full,
    output bit tx
);

  bit [7:0] input_data;
  bit [6:0] uart_buffer_processed = 0;
  bit [3:0] uart_buffer_state = 0;
  bit start;
  wire complete;

  assign reset_uart_buffer_available = uart_buffer_available != 0 && uart_buffer_available == uart_buffer_processed && uart_buffer_state == 2 && complete?1:0;
  assign uart_buffer_full = uart_buffer_available == 199 ? 1 : 0;
  assign start = uart_buffer_state == 1;

  uart_tx uart_tx (
      .clk(clk),
      .start(start),
      .input_data(input_data),
      .complete(complete),
      .uarttx(tx)
  );

  always @(posedge clk) begin
    if (uart_buffer_state == 0) begin
      if (uart_buffer_available > 0 && uart_buffer_processed < uart_buffer_available) begin
        input_data <= uart_buffer[uart_buffer_processed];
        uart_buffer_state <= uart_buffer_state + 1;
        uart_buffer_processed <= uart_buffer_processed + 1;
      end else if (uart_buffer_processed > uart_buffer_available) begin
        uart_buffer_processed <= 0;
      end
    end else if (uart_buffer_state == 1) begin
      if (!complete) uart_buffer_state <= uart_buffer_state + 1;
    end else if (uart_buffer_state == 2) begin
      if (complete) uart_buffer_state <= 0;
    end
  end
endmodule


//115200, 8 bits (LSB first), 1 stop, no parity
//values on tx: ...1, 0 (start bit), (8 data bits), 1 (stop bit), 1... 
//(we make some delay in the end before next seq; every bit is sent CLK_PER_BIT cycles)
module uart_tx (
    input clk,
    input start,
    input [7:0] input_data,
    output bit complete,
    output bit uarttx
);

  parameter CLK_PER_BIT = 100000000 / 115200;  //100 Mhz / transmission speed in bits per second

  parameter STATE_IDLE = 0;  //1
  parameter STATE_START_BIT = 1;  //0
  parameter STATE_DATA_BIT_0 = 2;
  //...
  parameter STATE_DATA_BIT_7 = 9;
  parameter STATE_STOP_BIT = 10;  //1

  bit [ 6:0] uart_tx_state = STATE_IDLE;
  bit [10:0] counter = CLK_PER_BIT;

  assign uarttx = uart_tx_state == STATE_IDLE || uart_tx_state == STATE_STOP_BIT ? 1:(uart_tx_state == STATE_START_BIT ? 0:input_data[uart_tx_state-STATE_DATA_BIT_0]);
  assign complete = uart_tx_state == STATE_IDLE;

  always @(negedge clk) begin
    if (uart_tx_state == STATE_IDLE) begin
      uart_tx_state <= start ? STATE_START_BIT : STATE_IDLE;
    end else begin
      uart_tx_state <= counter == 0 ? (uart_tx_state== STATE_STOP_BIT? STATE_IDLE : uart_tx_state + 1) : uart_tx_state;
      counter <= counter == 0 ? CLK_PER_BIT : counter - 1;
    end
  end
endmodule

module uart_rx (
    input clk,    
    input uartrx,
    output logic [7:0] bb,
    output logic bb_ready=0
);

parameter CLK_PER_BYTE = (100000000 / 115200 );  //100 Mhz / transmission speed in bps (bits per second)
parameter CLK_PER_BYTE2 = (100000000 / 115200 )*1.5;  //100 Mhz / transmission speed in bps (bits per second)

  parameter STATE_IDLE = 0; //1
  parameter STATE_START_BIT = 1; //0
  parameter STATE_DATA_BIT_0 = 2;
  //...
  parameter STATE_DATA_BIT_7 = 9;
  parameter STATE_STOP_BIT = 10; //1

  reg [ 6:0] uart_tx_state = STATE_IDLE;
  reg [20:0] counter = 0;
  reg uartrxreg, inp;


//double buffering for avoiding metastability
 always @(posedge clk) begin
    uartrxreg<=uartrx;
    inp <= uartrxreg;
end

 
 always @(posedge clk) begin
    if (uart_tx_state == STATE_IDLE) begin
      if (inp == 0) begin
        counter<=0;
        uart_tx_state <= uart_tx_state+1;   
      end
    end else if (uart_tx_state == STATE_START_BIT) begin
      if (counter == (CLK_PER_BYTE-1)/2) begin
        if (inp == 1) begin      
          uart_tx_state <= STATE_IDLE;
        end else begin
          //starting from this point we will be checking RS input value in the middle of the cycle
          bb_ready<=0;
          uart_tx_state <= uart_tx_state+1;   
          counter<=0;
        end
      end else begin
        counter<=counter+1;
      end         
    end else if (uart_tx_state >= STATE_DATA_BIT_0 && uart_tx_state <= STATE_DATA_BIT_7) begin
      if (counter == CLK_PER_BYTE) begin
        bb[uart_tx_state - STATE_DATA_BIT_0]<=inp;
        uart_tx_state <= uart_tx_state+1;   
        counter<=0;     
      end else begin      
        counter<=counter+1;
      end     
    end else if (uart_tx_state==STATE_STOP_BIT) begin
      if (counter == CLK_PER_BYTE) begin
          bb_ready<=inp;    
          uart_tx_state <= STATE_IDLE;
      end else begin
        counter<=counter+1;
      end         
    end
  end
endmodule

