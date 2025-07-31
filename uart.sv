// uart.sv
// Combined UART Transmitter and Receiver

module uart #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 9600
) (
    input logic clk,
    input logic rst_n,

    // Transmitter inputs
    input  logic       tx_start,
    input  logic [7:0] tx_data,
    output logic       tx,
    output logic       tx_busy,

    // Receiver inputs/outputs
    input  logic       rx,
    output logic [7:0] rx_data,
    output logic       rx_ready
);
  localparam integer DIVIDER = CLK_FREQ / BAUD_RATE;
  localparam integer COUNTER_WIDTH = $clog2(DIVIDER);

  // TX Internal Signals
  typedef enum logic [1:0] {
    TX_IDLE,
    TX_START,
    TX_DATA,
    TX_STOP
  } tx_state_t;
  tx_state_t tx_state;
  logic [COUNTER_WIDTH-1:0] tx_baud_cnt;
  logic [2:0] tx_bit_index;
  logic [7:0] tx_data_reg;

  // RX Internal Signals
  typedef enum logic [1:0] {
    RX_IDLE,
    RX_START,
    RX_DATA,
    RX_STOP
  } rx_state_t;
  rx_state_t rx_state;
  logic [COUNTER_WIDTH-1:0] rx_baud_cnt;
  logic [2:0] rx_bit_index;
  logic [7:0] rx_data_reg;

  // ------------------------
  // UART TRANSMITTER (TX)
  // ------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tx           <= 1'b1;
      tx_busy      <= 0;
      tx_state     <= TX_IDLE;
      tx_bit_index <= 0;
    end else begin
      case (tx_state)
        TX_IDLE:
        if (tx_start) begin
          tx_busy      <= 1;
          tx_data_reg  <= tx_data;
          tx_bit_index <= 0;
          tx_baud_cnt  <= 0;
          tx_state     <= TX_START;
          tx           <= 0;
        end

        TX_START:
        if (tx_baud_cnt == COUNTER_WIDTH'(DIVIDER - 1)) begin
          tx_baud_cnt  <= 0;
          tx_state     <= TX_DATA;
          tx           <= tx_data_reg[tx_bit_index];
          tx_bit_index <= tx_bit_index + 1;
        end else tx_baud_cnt <= tx_baud_cnt + 1;

        TX_DATA:
        if (tx_baud_cnt == COUNTER_WIDTH'(DIVIDER - 1)) begin
          tx_baud_cnt <= 0;
          tx          <= tx_data_reg[tx_bit_index];
          if (tx_bit_index == 7) begin
            tx_state <= TX_STOP;
          end else begin
            tx_bit_index <= tx_bit_index + 1;
          end
        end else tx_baud_cnt <= tx_baud_cnt + 1;

        TX_STOP:
        if (tx_baud_cnt == COUNTER_WIDTH'(DIVIDER - 1)) begin
          tx       <= 1;
          tx_busy  <= 0;
          tx_state <= TX_IDLE;
        end else tx_baud_cnt <= tx_baud_cnt + 1;
      endcase
    end
  end

  // ------------------------
  // UART RECEIVER (RX)
  // ------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_ready <= 0;
      rx_state <= RX_IDLE;
      rx_bit_index <= 0;
    end else begin
      case (rx_state)
        RX_IDLE: begin
          rx_ready <= 0;
          if (!rx) begin
            rx_baud_cnt <= COUNTER_WIDTH'(DIVIDER - 1) / 2;
            rx_bit_index <= 0;
            rx_state <= RX_START;
          end
        end

        RX_START:
        if (rx_baud_cnt == 0) begin
          rx_state <= RX_DATA;
          rx_baud_cnt <= COUNTER_WIDTH'(DIVIDER - 1);
        end else rx_baud_cnt <= rx_baud_cnt - 1;

        RX_DATA:
        if (rx_baud_cnt == 0) begin
          if (rx_bit_index == 7) begin
            rx_state <= RX_STOP;
          end else begin
            rx_data_reg  <= {rx, rx_data_reg[7:1]};
            rx_bit_index <= rx_bit_index + 1;
          end
          rx_baud_cnt <= COUNTER_WIDTH'(DIVIDER - 1);
        end else begin
          rx_baud_cnt <= rx_baud_cnt - 1;
        end


        RX_STOP:
        if (rx_baud_cnt == 0) begin
          rx_data  <= rx_data_reg;
          rx_ready <= 1;
          rx_state <= RX_IDLE;
        end else rx_baud_cnt <= rx_baud_cnt - 1;
      endcase
    end
  end

endmodule
