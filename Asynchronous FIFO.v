`timescale 1ns / 1ps

module synchronizer #(parameter width= 4)(d_out , d_in , clk , rst_n);
input clk , rst_n ;
input[width-1:0] d_in ;
output reg[width-1:0] d_out ;
reg[width-1:0] q1 ;
always @(posedge clk or negedge rst_n)begin
if(!rst_n)begin
q1<=0;
d_out<=0;
end
else begin 
q1<=d_in;
d_out<=q1 ;
end 
end
endmodule

module write_pointer_handler #(parameter PTR_WIDTH=3)( b_wptr, g_wptr, full, g_rptr_sync, w_clk, w_en, wrst_n);
input w_clk, wrst_n ,w_en;
input[PTR_WIDTH:0] g_rptr_sync;
output reg[PTR_WIDTH:0] b_wptr, g_wptr ;
output reg full ;

wire [PTR_WIDTH:0] b_wptr_next;
wire [PTR_WIDTH:0] g_wptr_next;
wire wfull ; 

assign b_wptr_next = b_wptr + (w_en & ~full);
assign g_wptr_next = (b_wptr_next >> 1) ^ b_wptr_next;

always @(posedge w_clk or negedge wrst_n) begin
if (!wrst_n) begin
b_wptr <= 0;
g_wptr <= 0;
end 
else begin
b_wptr <= b_wptr_next;
g_wptr <= g_wptr_next;
end
end

always @(posedge w_clk or negedge wrst_n)begin
if(!wrst_n)
full<=0 ;
else
full<=wfull ;
end 

assign wfull = (g_wptr_next == {(~g_rptr_sync[PTR_WIDTH:PTR_WIDTH-1]),(g_rptr_sync[PTR_WIDTH-2:0])}) ; //1100 in gray code for wrap around 

endmodule

module read_pointer_handler #(parameter PTR_WIDTH=3)(rclk , g_wptr_sync, rrst_n, r_en , b_rptr , g_rptr , empty);
input rclk , rrst_n , r_en ;
input[PTR_WIDTH:0] g_wptr_sync ;
output reg empty ;
output reg[PTR_WIDTH:0] b_rptr , g_rptr ;

wire[PTR_WIDTH:0] b_rptr_next ; 
wire[PTR_WIDTH:0] g_rptr_next ; 
wire rempty ;

assign b_rptr_next = b_rptr + (r_en & ~ empty );
assign g_rptr_next = (b_rptr_next>>1) ^ b_rptr_next ;

assign rempty = (g_wptr_sync == g_rptr_next);

always@(posedge rclk or negedge rrst_n) begin
if(!rrst_n)begin 
b_rptr<=0;
g_rptr<=0 ;
end 
else begin
b_rptr <= b_rptr_next ;
g_rptr <= g_rptr_next ;
end 
end 

always @(posedge rclk or negedge rrst_n )begin
if(!rrst_n) 
empty <=1 ;
else
empty <= rempty ;
end 
endmodule

module fifo_memory #(parameter PTR_WIDTH=3 , DATA_WIDTH=8,DEPTH=8)(w_en, w_clk, full,empty, r_en, r_clk, b_wptr, b_rptr, d_in , d_out);
input w_en, w_clk, full,empty, r_en, r_clk ;
input[PTR_WIDTH:0]  b_wptr, b_rptr ;
input[DATA_WIDTH-1:0] d_in ; 
output reg[DATA_WIDTH-1:0] d_out ;

reg [DATA_WIDTH-1:0] fifo [0:DEPTH-1];

//write logic 
always@(posedge w_clk )begin
if(w_en && ~full) begin
fifo[b_wptr[PTR_WIDTH-1:0]]<= d_in ;
end 
end 

// read logic 
always@(posedge r_clk )begin
if(r_en && ~empty) begin
d_out<=fifo[b_rptr[PTR_WIDTH-1:0]] ;
end 
end 

endmodule

module asynchronous_fifo #(parameter DEPTH=8, DATA_WIDTH=8) (
  input wclk, wrst_n,
  input rclk, rrst_n,
  input w_en, r_en,
  input [DATA_WIDTH-1:0] data_in,
  output [DATA_WIDTH-1:0] data_out,
  output full, empty
);

  parameter PTR_WIDTH = $clog2(DEPTH)  ;

  wire [PTR_WIDTH:0] g_wptr_sync, g_rptr_sync;
  wire [PTR_WIDTH:0] b_wptr, b_rptr;
  wire [PTR_WIDTH:0] g_wptr, g_rptr;

  // Synchronizers
  synchronizer #(PTR_WIDTH+1) sync_wptr (
    .clk(rclk),
    .rst_n(rrst_n),
    .d_in(g_wptr),
    .d_out(g_wptr_sync)
  );

  synchronizer #(PTR_WIDTH+1) sync_rptr (
    .clk(wclk),
    .rst_n(wrst_n),
    .d_in(g_rptr),
    .d_out(g_rptr_sync)
  );

  // Pointer handlers
  write_pointer_handler #(PTR_WIDTH) wptr_h (
    .w_clk(wclk),
    .wrst_n(wrst_n),
    .w_en(w_en),
    .g_rptr_sync(g_rptr_sync),
    .b_wptr(b_wptr),
    .g_wptr(g_wptr),
    .full(full)
  );

  read_pointer_handler #(PTR_WIDTH) rptr_h (
    .rclk(rclk),
    .rrst_n(rrst_n),
    .r_en(r_en),
    .g_wptr_sync(g_wptr_sync),
    .b_rptr(b_rptr),
    .g_rptr(g_rptr),
    .empty(empty)
  );

  // Memory
  fifo_memory #(PTR_WIDTH, DATA_WIDTH, DEPTH) fifom (
    .w_en(w_en),
    .w_clk(wclk),
    .full(full),
    .empty(empty),
    .r_en(r_en),
    .r_clk(rclk),
    .b_wptr(b_wptr),
    .b_rptr(b_rptr),
    .d_in(data_in),
    .d_out(data_out)
  );

endmodule




