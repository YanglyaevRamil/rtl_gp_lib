
// ************************************************************************************************
// ************************************************************************************************
// **
// **  Title       : gp_reg_slice.sv
// **  Author      : Yanglyaev Ramil
// **
// ************************************************************************************************
// **
// **  Description :
// **
// ************************************************************************************************
// **
// **  Change log  : 0.1 version - 05.07.2025 - created file
// **
// ************************************************************************************************
// ************************************************************************************************
module gp_reg_slice #(
    parameter DATA_WIDTH  = 32
)(
    // System channel
    input  wire                    clk_i      ,
    input  wire                    arstn_i    ,
    // RX handshake channel
    output wire                    rx_ready_o ,
    input  wire                    rx_valid_i ,
    input  wire [DATA_WIDTH-1 : 0] rx_data_i  ,
    // TX handshake channel
    input  wire                    tx_ready_i ,
    output reg                     tx_valid_o ,
    output reg  [DATA_WIDTH-1 : 0] tx_data_o
);

// ****************************************************************************
// Module body
// ****************************************************************************
// Ready signal forming
    assign rx_ready_o = tx_ready_i | (~tx_valid_o) ;

// Valid signal forming
    always_ff @(posedge clk_i or negedge arstn_i) begin : tx_valid_reg
        if (!arstn_i)
            tx_valid_o <= 1'b0 ;
        else if (rx_ready_o)
            tx_valid_o <= rx_valid_i ;
    end

// Data forming
    always_ff @(posedge clk_i) begin : tx_data_reg
        if (rx_ready_o)
            tx_data_o <= rx_data_i ;
    end

// ****************************************************************************
endmodule // gp_reg_slice