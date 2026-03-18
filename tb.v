`timescale 1ns/1ps

module tb_async_fifo;

  parameter DEPTH = 8;
  parameter DATA_WIDTH = 8;

  reg wclk = 0, rclk = 0;
  reg wrst_n = 0, rrst_n = 0;
  reg w_en = 0, r_en = 0;
  reg [DATA_WIDTH-1:0] data_in = 0;

  wire [DATA_WIDTH-1:0] data_out;
  wire full, empty;

  // DUT
  asynchronous_fifo #(DEPTH, DATA_WIDTH) dut (
    .wclk(wclk),
    .wrst_n(wrst_n),
    .rclk(rclk),
    .rrst_n(rrst_n),
    .w_en(w_en),
    .r_en(r_en),
    .data_in(data_in),
    .data_out(data_out),
    .full(full),
    .empty(empty)
  );

  // Clocks
  always #5  wclk = ~wclk;   // 10ns
  always #11 rclk = ~rclk;   // 22ns (different clock → important)

  integer i;

  initial begin
    // Reset
    #20;
    wrst_n = 1;
    rrst_n = 1;

    // ------------------------
    // WRITE DATA (SAFE)
    // ------------------------
    for (i = 1; i <= 8; i = i + 1) begin
      @(posedge wclk);
      if (!full) begin
        w_en = 1;
        data_in = i;
      end
      else begin
        w_en = 0;
      end
    end
    @(posedge wclk);
    w_en = 0;

    // ------------------------
    // WAIT (important for sync)
    // ------------------------
    #50;

    // ------------------------
    // READ DATA (SAFE)
    // ------------------------
    for (i = 1; i <= 8; i = i + 1) begin
      @(posedge rclk);
      if (!empty) begin
        r_en = 1;
      end
      else begin
        r_en = 0;
      end
    end
    @(posedge rclk);
    r_en = 0;

    // Finish
    #50;
    $finish;
  end

  // Clean Monitor
  initial begin
    $display("Time | W_EN R_EN | DIN | DOUT | FULL EMPTY");
    $monitor("%4t |  %b    %b  |  %d  |  %d  |  %b     %b",
              $time, w_en, r_en, data_in, data_out, full, empty);
  end

endmodule