
// ************************************************************************************************
// ************************************************************************************************
// **
// **  Title       : dds_rom.sv
// **  Design      : dds_rom
// **  Author      : Yanglyaev Ramil
// **
// ************************************************************************************************
// **
// **  Description : ROM storing data
// **
// ************************************************************************************************
// **
// **  Change log  : 1.0 version - 25.09.2025, created file by Yanglyaev Ramil
// **
// ************************************************************************************************
// ************************************************************************************************

// 256x8 ROM for sine wave
module sine256x8 #(
    parameter WIDTH    =   8 ,
    parameter DEPTH    = 256 ,
    parameter FILE_HEX = "sine256x8.hex"
) (
    input  logic       clk_i  ,
    input  logic [7:0] addr_i ,
    output logic [7:0] data_o
);

    // Declare memory array
    logic [WIDTH-1 : 0] rom [0 : DEPTH-1];

    // Initialize ROM from file (hex or bin)
    initial begin
        $readmemh(FILE_HEX, rom);
    end

    // Registered read (synchronous ROM)
    always_ff @(posedge clk_i) begin
        data_o <= rom[addr_i];
    end

endmodule