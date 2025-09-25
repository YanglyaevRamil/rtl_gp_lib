
// ************************************************************************************************
// ************************************************************************************************
// **
// **  Title       : gp_dds.sv
// **  Design      : gp_dds
// **  Author      : Yanglyaev Ramil
// **
// ************************************************************************************************
// **
// **  Description : Direct Digital Synthesis (DDS)
// **
// ************************************************************************************************
// **
// **  Change log  : 1.0 version - 25.09.2025, created file by Yanglyaev Ramil
// **
// ************************************************************************************************
// ************************************************************************************************

module gp_dds #(
    parameter PHASE_WIDTH = 32 ,
    parameter ADDR_WIDTH  =  8 ,
    parameter DATA_WIDTH  =  8 ,
    parameter FILE_HEX    = "sine256x8.hex"
)(
    input  wire                      clk_i        , // System clock
    input  wire                      arstn_i      , // Asynchronous reset
    input  logic [PHASE_WIDTH-1 : 0] phase_step_i , // Accumulator increment
    output logic [ DATA_WIDTH-1 : 0] wave_o         // System sine output
);
// ****************************************************************************
// Wire/reg declarations
// ****************************************************************************
    reg  [PHASE_WIDTH-1 : 0] acc32 ;
    wire [ ADDR_WIDTH-1 : 0] msbs  ;

// *******************************************************************
// Modules
// *******************************************************************
    assign msbs  = acc32[PHASE_WIDTH +: ADDR_WIDTH];

// *******************************************************************
    always_ff @(posedge clk_i or posedge arstn_i)
        if (arstn_i) begin
            acc32 <= {PHASE_WIDTH{1'b0}};
        end else begin
            acc32 <= acc32 + phase_step_i;
        end

// *******************************************************************
// Instantiate the ROM
    dds_rom #(
        .WIDTH    ( DATA_WIDTH    ),
        .DEPTH    ( 1<<ADDR_WIDTH ),
        .FILE_HEX ( FILE_HEX      )
    ) rom (
        .clk_i  ( clk_i  ),
        .addr_i ( msbs   ),
        .data_o ( wave_o )
    );

endmodule
// gp_dds