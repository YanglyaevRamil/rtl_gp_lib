module test_apb_reg #(
    parameter NUM_REG        =  8,
    parameter APB_ADDR_WIDTH = 32,
    parameter APB_DATA_WIDTH = 32
)(
    // APB interface signals
    input  wire                       clk_i     ,    
    input  wire                       rst_n_i   ,  
    input  wire [APB_ADDR_WIDTH-1:0]  paddr_i   ,  
    input  wire [APB_DATA_WIDTH-1:0]  pwdata_i  , 
    output wire [APB_DATA_WIDTH-1:0]  prdata_o  , 
    input  wire                       psel_i    ,   
    input  wire                       pwrite_i  , 
    input  wire                       penable_i ,
    output reg                        pready_o  , 
    output reg                        pslverr_o 
);

// *******************************************************************
// Parameters
// *******************************************************************
    localparam MAX_DELAY      = 5 ;

// ****************************************************************************
// Wire/reg declarations
// ****************************************************************************
    reg [NUM_REG*APB_DATA_WIDTH-1:0] reg_data;

    int delay;

// ****************************************************************************
// Module body
// ****************************************************************************
//    assign pready_o = 1'b1 ; 

    assign prdata_o = (psel_i & !pwrite_i & penable_i) ? reg_data[(paddr_i<<3) +: 32] : {APB_DATA_WIDTH{1'b0}} ; 

    always @(posedge clk_i) 
        if (!rst_n_i)
            reg_data <= {APB_DATA_WIDTH*NUM_REG{1'b0}} ;
        else if (psel_i & pwrite_i & penable_i) 
            reg_data[(paddr_i*8) +: 32] <= pwdata_i ;

    always @(*) begin
        if (psel_i & penable_i & pready_o & (paddr_i >= NUM_REG*4))
            pslverr_o <= 1'b1;
        else
            pslverr_o <= 1'b0;
    end

    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            pready_o <= 1'b0;
        end
        else begin
            if (psel_i & penable_i) begin
                delay <= $random % MAX_DELAY + 1;
                repeat (delay) @(posedge clk_i);
                pready_o <= 1;
                @(posedge clk_i);
                pready_o <= 0;
            end
        end
    end

endmodule