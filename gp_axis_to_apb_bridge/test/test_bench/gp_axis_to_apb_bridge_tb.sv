// ************************************************************************************************
    `timescale  1 ns / 1 ps

// *******************************************************************
// Define Declarations
// *******************************************************************
    // Source global defines parameters
    // `include "list_global_defines.sv"

module gp_axis_to_apb_bridge_tb;
    localparam BYPASS_FIFO    =  1;
    localparam FIFO_DEPTH     =  8;
    localparam APB_ADDR_WIDTH = 32;
    localparam APB_DATA_WIDTH = 32;
    localparam AXI_DATA_WIDTH = 32;
    localparam AXI_USER_WIDTH = APB_ADDR_WIDTH+1;

    localparam TIME_148_5MHZ       = 6.734;
    localparam TIME_HALF_148_5MHZ  = TIME_148_5MHZ/2;

    localparam NUM_REG = 64 ; // Number 32-bit reisters

// *******************************************************************
// Wire/Reg Declarations
// *******************************************************************
    reg sys_clk  = 0;
    reg sys_rstn = 1;

    reg [ AXI_DATA_WIDTH-1:0] fwd_tdata ;
    reg                       fwd_tvalid;
    wire                      fwd_tready;
    reg [ AXI_USER_WIDTH-1:0] fwd_tuser ;

    wire [AXI_DATA_WIDTH-1:0] bwd_tdata ;
    wire                      bwd_tvalid;
    reg                       bwd_tready;
    wire                      bwd_tuser ;

    wire [APB_ADDR_WIDTH-1:0] paddr  ;
    wire [APB_DATA_WIDTH-1:0] pwdata ;
    reg  [APB_DATA_WIDTH-1:0] prdata ;
    wire                      psel   ;
    wire                      pwrite ;
    wire                      penable;
    logic                     pready ;
    reg                       pslverr;

    reg [31:0] data;
    reg [31:0] addr;

    int random_delay;

    reg [NUM_REG-1 : 0][31 : 0] dump;

    reg err = 0;

    int bwd_hndsk_cnt;

// *******************************************************************
// Modules
// *******************************************************************
    always #(TIME_HALF_148_5MHZ) sys_clk = ~sys_clk;

    initial begin
        sys_rstn = 1;
        
        #1000;
        @(posedge sys_clk);
        sys_rstn = 0;

        #100;
        @(posedge sys_clk);
        sys_rstn = 1;
    end

// *******************************************************************
    gp_axis_to_apb_bridge #(
        .BYPASS_FIFO    ( BYPASS_FIFO    ),
        .FIFO_DEPTH     ( FIFO_DEPTH     ),
        .APB_ADDR_WIDTH ( APB_ADDR_WIDTH ),
        .APB_DATA_WIDTH ( APB_DATA_WIDTH ),
        .AXI_DATA_WIDTH ( AXI_DATA_WIDTH ),
        .AXI_USER_WIDTH ( AXI_USER_WIDTH )
    ) u_axis_to_apb_bridge (
        // System channel
        .clk_i        ( sys_clk         ),
        .rst_n_i      ( sys_rstn        ),
        // AXI-Stream BWD interface
        .bwd_tdata_o  ( bwd_tdata       ),
        .bwd_tvalid_o ( bwd_tvalid      ),
        .bwd_tready_i ( bwd_tready      ),
        .bwd_tuser_o  ( bwd_tuser       ),
        // AXI-Stream FWD interface
        .fwd_tdata_i  ( fwd_tdata       ),
        .fwd_tvalid_i ( fwd_tvalid      ),
        .fwd_tready_o ( fwd_tready      ),
        .fwd_tuser_i  ( fwd_tuser       ),
        // APB-M interface
        .paddr_o      ( paddr           ),
        .pwdata_o     ( pwdata          ),
        .prdata_i     ( prdata          ),
        .psel_o       ( psel            ),
        .pwrite_o     ( pwrite          ),
        .penable_o    ( penable         ),
        .pready_i     ( pready          ),
        .pslverr_i    ( pslverr         )
    );

    test_apb_reg #(
        .NUM_REG        ( NUM_REG        ),
        .APB_ADDR_WIDTH ( APB_ADDR_WIDTH ),
        .APB_DATA_WIDTH ( APB_DATA_WIDTH )
    ) u_test_apb_reg (
        .clk_i     ( sys_clk  ),
        .rst_n_i   ( sys_rstn ),
        .paddr_i   ( paddr    ),
        .pwdata_i  ( pwdata   ),
        .prdata_o  ( prdata   ),
        .psel_i    ( psel     ),
        .pwrite_i  ( pwrite   ),
        .penable_i ( penable  ),
        .pready_o  ( pready   ),
        .pslverr_o ( pslverr  )
    );

// *******************************************************************
    always @(posedge sys_clk)
        if (~sys_rstn)
            bwd_hndsk_cnt <= 0;
        else if (bwd_tready & bwd_tvalid)
            bwd_hndsk_cnt <= bwd_hndsk_cnt + 1;

// *******************************************************************
    initial begin;
        // Initialize signals
        fwd_tdata  = 0;
        fwd_tvalid = 0;
        fwd_tuser  = 0;
        bwd_tready = 0;

        @(negedge sys_rstn);
        @(posedge sys_rstn);
        #100
        @(posedge sys_clk);
        bwd_tready = 1;

        // Test Case 1: Single write transaction
        for (int i = 0; i < NUM_REG; i++) begin
            @(posedge sys_clk);
            fwd_tdata = $random;
            dump[i] = fwd_tdata;
            fwd_tvalid = 1;
            fwd_tuser = {1'b1, i*4}; // {Write, Address}

            @(posedge sys_clk);
            while (!fwd_tready) @(posedge sys_clk);
            fwd_tvalid = 0;
        end

        // Test Case 2: Single read transaction
        fork
            begin
                for (int i = 0; i < NUM_REG; i++) begin
                    @(posedge sys_clk);
                    fwd_tvalid = 1;
                    fwd_tuser  = {1'b0, i*4}; // {Read, Address}

                    @(posedge sys_clk);
                    while (!fwd_tready) @(posedge sys_clk);
                    fwd_tvalid = 0;
                end
            end

            begin
                for (int i = 0; i < NUM_REG;) begin
                    @(posedge sys_clk);
                    while (!bwd_tvalid) @(posedge sys_clk);
                    if (bwd_hndsk_cnt >= NUM_REG) begin
                        if (bwd_tdata != dump[i] ) begin
                            $display("ERR: addr = %4h | bwd_tdata = %h : golden_data = %h", i*4, bwd_tdata, dump[i]);
                            err = 1;
                        end
                        else $display("INF: addr = %4h | bwd_tdata = %h : golden_data = %h", i*4, bwd_tdata, dump[i]);
                        i++;
                    end
                end
            end
        join

        // Test Case 3: Error handling
        @(posedge sys_clk);
        fwd_tvalid = 1;
        fwd_tdata = 32'h1234_ABCD;
        fwd_tuser = {1'b1, 32'h0000_1000}; // {Read, Address}
        @(posedge sys_clk);
        while (!fwd_tready) @(posedge sys_clk);
        fwd_tvalid = 0;
        while (!bwd_tvalid) @(posedge sys_clk);
        if (!bwd_tuser) begin
            $display("ERR: Not pslverr signal ");
            err = 1;
        end

        @(posedge sys_clk);
        fwd_tvalid = 1;
        fwd_tuser = {1'b0, 32'h1000_0000}; // {Write, Address}
        @(posedge sys_clk);
        while (!fwd_tready) @(posedge sys_clk);
        fwd_tvalid = 0;
        while (!bwd_tvalid) @(posedge sys_clk);
        if (!bwd_tuser) begin
            $display("ERR: Not pslverr signal ");
            err = 1;
        end

        #100;

        if (err) $display("INF: Test - NoT");
        else     $display("INF: Test - Ok");

        $finish;

    end

// *******************************************************************
endmodule