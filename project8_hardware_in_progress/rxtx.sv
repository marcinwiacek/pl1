`timescale 1ns / 1ps

module x (
    input clk,
    output logic uart_rx_out,
        input uart_tx_in
);

  //uart
  reg [7:0] uart_buffer[0:128];
  reg [6:0] uart_buffer_index = 0;
  wire reset_uart_buffer_index;
  wire uart_buffer_full;
  
  uartx_tx_with_buffer uartx_tx_with_buffer (
    .clk(clk),
    .uart_buffer(uart_buffer),
    .uart_buffer_index(uart_buffer_index),
    .reset_uart_buffer_index(reset_uart_buffer_index),
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
  
  always @(negedge clk) begin
    //  if (reset_uart_buffer_index) begin
//        uart_buffer_index<= 0;
//      end else if (!uart_buffer_full) begin
       if (uart_bb_ready) begin
        uart_buffer[uart_buffer_index]<=uart_bb;
        uart_buffer_index<=uart_buffer_index+1;
       end
  //    end
  end

endmodule


module uartx_tx_with_buffer (
  input clk,
  input [7:0] uart_buffer[0:128],
  input [6:0] uart_buffer_index,
  output logic reset_uart_buffer_index,
  output logic uart_buffer_full,
  output logic tx
);

  reg [7:0] input_data;
  reg start = 0;
  wire busy;
  reg [6:0] uart_buffer_processed_index=0;
  
  assign reset_uart_buffer_index = uart_buffer_index != 0 && !busy && uart_buffer_index == uart_buffer_processed_index ?1:0;
  assign uart_buffer_full = uart_buffer_index == 124?1:0;
  
  uart_tx uart_tx (
      .clk(clk),
      .start(start),
      .input_data(input_data),
      .busy(busy),
      .uarttx(tx)
  );
   
  always @(posedge clk) begin 
    if (busy) begin
      start <= 0;
    end else if (!busy && uart_buffer_processed_index < uart_buffer_index) begin
         input_data <= uart_buffer[uart_buffer_processed_index];
         uart_buffer_processed_index<= uart_buffer_processed_index+1;
         start <= 1;
    end else if (!busy && uart_buffer_processed_index > uart_buffer_index) begin
      uart_buffer_processed_index <= 0;
    end
  end
  
endmodule

//9600, 8 bits (LSB first), 1 stop, no parity
//values on tx: ...1, 0 (start bit), (8 data bits), 1... (every bit is sent CLK_PER_BYTE cycles)
module uart_tx (
    input clk,
    input start,
    input [7:0] input_data,
    output logic busy,
    output logic uarttx
);

  parameter CLK_PER_BYTE = 100000000 / 115200 ;  //100 Mhz / transmission speed in bps (bits per second)

  parameter STATE_IDLE = 0; //1
  parameter STATE_START_BIT = 1; //0
  parameter STATE_DATA_BIT_0 = 2;
  //...
  parameter STATE_DATA_BIT_7 = 9;
  parameter STATE_STOP_BIT = 10; //1

  reg [ 6:0] uart_tx_state = STATE_IDLE;
  reg [10:0] counter = CLK_PER_BYTE;

  assign uarttx = uart_tx_state == STATE_IDLE || uart_tx_state == STATE_STOP_BIT ? 1:(uart_tx_state == STATE_START_BIT?0:input_data[uart_tx_state-STATE_DATA_BIT_0]);
  assign busy = uart_tx_state != STATE_IDLE && uart_tx_state != STATE_STOP_BIT;

  always @(posedge clk, posedge start) begin
    if (uart_tx_state == STATE_IDLE) begin
      uart_tx_state <= start? STATE_START_BIT:uart_tx_state;
    end else begin
      uart_tx_state   <= counter == 0 ? (uart_tx_state == STATE_STOP_BIT ? (start?STATE_START_BIT:STATE_IDLE) : uart_tx_state + 1) : uart_tx_state;
      counter <= counter == 0 ? CLK_PER_BYTE : counter - 1;
    end
  end
endmodule

module uart_rx (
    input clk,    
    input uartrx,
    output logic [7:0] bb,
    output logic bb_ready
);

  parameter CLK_PER_BYTE = (100000000 / 115200 );  //100 Mhz / transmission speed in bps (bits per second)
  parameter CLK_PER_BYTE_HALF = (100000000 / 115200 )/2;  //100 Mhz / transmission speed in bps (bits per second)

  parameter STATE_IDLE = 0; //1
  parameter STATE_START_BIT = 1; //0
  parameter STATE_DATA_BIT_0 = 2;
  //...
  parameter STATE_DATA_BIT_7 = 9;
  parameter STATE_STOP_BIT = 10; //1

  reg [ 6:0] uart_tx_state = STATE_IDLE;
  reg [10:0] counter = 0;
  reg [10:0] value=1;

  always @(posedge clk) begin
    if (uart_tx_state == STATE_IDLE) begin
      if (uartrx == 0 && value==1) begin
        counter<=0;
        uart_tx_state <= STATE_START_BIT;
      
      end else begin
        value<=uartrx;
      end
    end else if (uart_tx_state == STATE_START_BIT) begin
      if (counter == CLK_PER_BYTE_HALF && uartrx == 1) begin
        uart_tx_state <= STATE_IDLE;
         value<=1;
      end else if (counter == CLK_PER_BYTE) begin
        uart_tx_state <= STATE_DATA_BIT_0;
        bb<=0;
        counter<=0;
          bb_ready<=0;
      end else begin
        counter<=counter+1;
      end         
    end else if (uart_tx_state >= STATE_DATA_BIT_0 && uart_tx_state <= STATE_DATA_BIT_7) begin
      if (counter == CLK_PER_BYTE_HALF) begin
        bb<=bb+uartrx*(2**(uart_tx_state - STATE_DATA_BIT_0));
      end else if (counter == CLK_PER_BYTE) begin
        uart_tx_state <= uart_tx_state+1;   
        counter<=0;     
      end else begin      
        counter<=counter+1;
      end     
    end else if (uart_tx_state==STATE_STOP_BIT) begin
      if (counter == CLK_PER_BYTE_HALF && uartrx == 0) begin
        uart_tx_state <= STATE_IDLE;
          value<=0;
      end else if (counter == CLK_PER_BYTE) begin
        uart_tx_state <= STATE_IDLE;
        bb_ready<=1;
          counter<=0;
      end else begin
        counter<=counter+1;
      end         
    end
  end
endmodule

