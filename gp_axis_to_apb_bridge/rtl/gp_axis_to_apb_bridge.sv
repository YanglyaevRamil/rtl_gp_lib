
// ************************************************************************************************
// ************************************************************************************************
// **
// **  Title       : gp_axis_to_apb_bridge.sv
// **  Author      : Yanglyaev Ramil
// **
// ************************************************************************************************
// **
// **  Description : Converter AXI-S to APB
// **
// ************************************************************************************************
// **
// **  Change log  : 0.1 version - 30.11.2024 - created file
// **
// ************************************************************************************************
// ************************************************************************************************
module gp_axis_to_apb_bridge #(
    parameter BYPASS_FIFO    =  0, // Controls the presence or absence of FIFO. Support for AXI-S -> APB packages if (ENABLE_FIFO = 1).
    parameter FIFO_DEPTH     =  8, // Fifo size
    parameter APB_ADDR_WIDTH = 32,
    parameter APB_DATA_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 32,
    parameter AXI_USER_WIDTH = APB_ADDR_WIDTH+1
)(
// System channel
input  wire                        clk_i        ,
input  wire                        rst_n_i      ,
// AXI-Stream BWD interface
output wire [AXI_DATA_WIDTH-1 : 0] bwd_tdata_o  ,
output wire                        bwd_tvalid_o ,
input  wire                        bwd_tready_i ,
output wire                        bwd_tuser_o  ,
// AXI-Stream FWD interface
input  wire [AXI_DATA_WIDTH-1 : 0] fwd_tdata_i  ,
input  wire                        fwd_tvalid_i ,
output wire                        fwd_tready_o ,
input  wire [AXI_USER_WIDTH-1 : 0] fwd_tuser_i  ,
// APB-M interface
output wire [APB_ADDR_WIDTH-1 : 0] paddr_o      ,
output wire [APB_DATA_WIDTH-1 : 0] pwdata_o     ,
input  wire [APB_DATA_WIDTH-1 : 0] prdata_i     ,
output wire                        psel_o       ,
output wire                        pwrite_o     ,
output wire                        penable_o    ,
input  wire                        pready_i     ,
input  wire                        pslverr_i
);

// *******************************************************************
// Parameters
// *******************************************************************
    localparam FIFO_DATA_WIDTH = AXI_DATA_WIDTH + AXI_USER_WIDTH;

    localparam [1:0] IDLE   = 2'b00;
    localparam [1:0] SETUP  = 2'b01;
    localparam [1:0] ACCESS = 2'b10;

// ****************************************************************************
// Wire/reg declarations
// ****************************************************************************
    reg [AXI_DATA_WIDTH-1 : 0] fwd_tdata;
    reg [AXI_USER_WIDTH-1 : 0] fwd_tuser;
    reg                        bwd_tvalid;
    reg                        fwd_tready;
    wire                       fwd_tvalid;

    reg [APB_DATA_WIDTH-1 : 0] prdata;
    reg                        pslverr;

    reg  [1 : 0] state;
    reg  [1 : 0] next_state;

// ****************************************************************************
// Module body
// ****************************************************************************
    if (BYPASS_FIFO == 1) begin:byp_fifo_buffer
        assign fwd_tready_o = fwd_tready;
        assign fwd_tvalid = fwd_tvalid_i;

        always @(posedge clk_i)
            if (fwd_hndshk) begin
                fwd_tdata <= fwd_tdata_i;
                fwd_tuser <= fwd_tuser_i;
            end
    end
    else begin:fifo_buffer
        reg [FIFO_DATA_WIDTH-1 : 0] rd_fifo_data;

        // RX fifo buffer | Your FIFO may be here
        gp_fifo_sync #(
            .FIFO_DEPTH ( FIFO_DEPTH      ),
            .DATA_WIDTH ( FIFO_DATA_WIDTH )
        ) u_rx_fifo_buf (
            // System channel
            .clk_i      ( clk_i         ),
            .rst_n_i    ( rst_n_i       ),
            // Write data channel
            .wr_ready_o ( fwd_tready_o  ),
            .wr_valid_i ( fwd_tvalid_i  ),
            .wr_data_i  ( {fwd_tuser_i, 
                           fwd_tdata_i} ),
            // Read data channel
            .rd_ready_i ( fwd_tready    ),
            .rd_valid_o ( fwd_tvalid    ),
            .rd_data_o  ( rd_fifo_data  )
        );

        always @(posedge clk_i)
            if (fwd_hndshk) 
                {fwd_tuser, fwd_tdata} <= rd_fifo_data;
    end

// ****************************************************************************
// Forming handshake signal
    assign fwd_hndshk = fwd_tready & fwd_tvalid;
    assign bwd_hndshk = bwd_tready_i & bwd_tvalid_o;

// Forming ready and valid signal
    always @(posedge clk_i)
        if (~rst_n_i)
            fwd_tready <= 1'b1;
        else if (fwd_hndshk)
            fwd_tready <= 1'b0;
        else if (bwd_hndshk)
            fwd_tready <= 1'b1;
    
    assign bwd_tvalid_o = bwd_tvalid;
    always @(posedge clk_i)
        if (~rst_n_i)
            bwd_tvalid <= 1'b0;
        else if (bwd_hndshk)
            bwd_tvalid <= 1'b0;
        else if (state[1] & pready_i)
            bwd_tvalid <= 1'b1;

// ****************************************************************************
// Save APB Data
    always @(posedge clk_i)
        if (pready_i & penable_o & psel_o) begin
            prdata <= prdata_i;
            pslverr <= pslverr_i;
        end

// ****************************************************************************
// FSM, AMBA APB Protocol Specification, Chapter 4-1
    always @(posedge clk_i)
        if (~rst_n_i) 
            state <= IDLE;
        else 
            state <= next_state;

    always @(*)
        case (state)
            IDLE   : begin
                next_state = fwd_hndshk ? SETUP : IDLE;
            end
            SETUP  : begin
                next_state = ACCESS;
            end
            ACCESS : begin
                next_state = pready_i ? IDLE : ACCESS;
            end
            default : begin
                next_state = IDLE;
            end
        endcase

// ****************************************************************************
// APB
    assign {pwrite_o, paddr_o} = fwd_tuser;
    assign pwdata_o = fwd_tdata;
    assign psel_o = |state;
    assign penable_o = state[1];

// AXI-S
    assign bwd_tuser_o = pslverr;
    assign bwd_tdata_o = prdata;

// ****************************************************************************
endmodule