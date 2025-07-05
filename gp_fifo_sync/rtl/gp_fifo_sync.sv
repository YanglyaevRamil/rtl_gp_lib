
// ************************************************************************************************
// ************************************************************************************************
// **
// **  Title       : gp_fifo_sync.sv
// **  Author      : Yanglyaev Ramil
// **
// ************************************************************************************************
// **
// **  Description : FIFO (First-In, First-Out) is a queue with a direct (sequential) 
// **                data processing order. It is used for buffering.
// **
// ************************************************************************************************
// **
// **  Change log  : 0.1 version - 01.11.2024 - created file
// **
// ************************************************************************************************
// ************************************************************************************************
module gp_fifo_sync #(
    parameter FIFO_DEPTH =  8,
    parameter DATA_WIDTH = 32
)(
    // System channel
    input  wire                    clk_i      ,
    input  wire                    rst_n_i    ,
    // Write data channel
    output wire                    wr_ready_o ,
    input  wire                    wr_valid_i ,
    input  wire [DATA_WIDTH-1 : 0] wr_data_i  ,
    // Read data channel
    input  wire                    rd_ready_i ,
    output wire                    rd_valid_o ,
    output wire [DATA_WIDTH-1 : 0] rd_data_o  
);

// *******************************************************************
// Parameters
// *******************************************************************
    localparam ADDR_WIDTH = $clog2(FIFO_DEPTH);
    localparam OCCP_WIDTH = $clog2(FIFO_DEPTH+1);

// ****************************************************************************
// Wire/reg declarations
// ****************************************************************************
    reg [FIFO_DEPTH-1 : 0][DATA_WIDTH-1 : 0] memory;
    reg [OCCP_WIDTH-1 : 0] fifo_cnt;
    reg [ADDR_WIDTH-1 : 0] wr_ptr;
    reg [ADDR_WIDTH-1 : 0] rd_ptr;

    wire fifo_push;
    wire fifo_pop;
    wire empty;
    wire full;

// ****************************************************************************
// Module body
// ****************************************************************************
// Forming handshake signal
    assign fifo_push = wr_valid_i & wr_ready_o;
    assign fifo_pop = rd_ready_i & rd_valid_o;

// Forming status fifo
    assign empty = ~(|fifo_cnt);
    assign full = (fifo_cnt == FIFO_DEPTH);

// Forming valid and ready
    assign rd_valid_o = ~empty;
    assign wr_ready_o = ~full;

// ****************************************************************************
// Occupancy counter
    always @(posedge clk_i)
        if (~rst_n_i) begin
            fifo_cnt <= {OCCP_WIDTH{1'b0}};
        end else begin
            case ({fifo_push, fifo_pop})
                2'b10   : fifo_cnt <= fifo_cnt + 1'b1;
                2'b01   : fifo_cnt <= fifo_cnt - 1'b1;
                default : fifo_cnt <= fifo_cnt;
            endcase
        end

// ****************************************************************************
// Managing the write pointer (wr_ptr)
    always @(posedge clk_i) begin
        if (~rst_n_i) begin
            wr_ptr <= {ADDR_WIDTH{1'b0}};
        end else if (fifo_push) begin
            wr_ptr <= (wr_ptr == (FIFO_DEPTH-1)) ? {ADDR_WIDTH{1'b0}} : wr_ptr + 1'b1;
        end
    end

// Write data in FIFO
    always @(posedge clk_i) begin
        if (fifo_push) begin
            memory[wr_ptr] <= wr_data_i;
        end
    end

// ****************************************************************************
// Managing the read pointer (rd_ptr)
    always @(posedge clk_i) begin
        if (~rst_n_i) begin
            rd_ptr <= {ADDR_WIDTH{1'b0}};
        end else if (fifo_pop) begin
            rd_ptr <= (rd_ptr == (FIFO_DEPTH-1)) ? {ADDR_WIDTH{1'b0}} : rd_ptr + 1'b1;
        end
    end

// Read data from FIFO
    assign rd_data_o = memory[rd_ptr];

// ****************************************************************************
endmodule