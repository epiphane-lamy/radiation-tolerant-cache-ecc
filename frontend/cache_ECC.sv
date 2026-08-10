import cache_pkg::*;

module cache_ECC (
    // General
    input logic        clk,
    input logic        rst_n,
    // CPU
    input  op_t        op,
    input  logic [7:0] addr_cpu_in,
    input  logic [7:0] data_cpu_in,
    output logic       data_ready,
    output logic [7:0] data_cpu,
    // Main memory
    output logic        re_mem,
    output logic        we_mem,
    output logic [7:0]  addr_mem,
    output logic [15:0] data_mem_write,
    input  logic        valid_mem,
    input  logic [15:0] data_mem_read
    );

    //------------------------------------------------------------------------------
    // ECC Cache Top-Level
    //
    // Integrates the cache controller, ECC logic, and cache SRAM.
    //
    // The cache controller manages CPU requests, cache hits/misses, memory
    // accesses, and cache replacement.
    //
    // On a cache write, the data is encoded with ECC before being stored in the
    // cache SRAM. On a cache read, the stored ECC-protected line is decoded before
    // being provided to the cache controller.
    //
    // The cache SRAM stores two ECC-protected ways for each cache set and provides
    // synchronous read access with one-cycle latency.
    //
    // Data path:
    //
    // CPU
    // |
    // v
    // Cache Controller <------> Main Memory
    // |
    // v
    // ECC Encoder
    // |
    // v
    // Cache SRAM
    // |
    // +----> ECC Decoder (way 0) ----> Cache Controller
    // |
    // +----> ECC Decoder (way 1) ----> Cache Controller
    //------------------------------------------------------------------------------


    logic        we_cache;
    logic [2:0]  addr_cache;
    logic        way_select;
    data_cache_t data_cache_wr;

    data_cache_ecc_t data_cache_ecc_d0;
    data_cache_ecc_t data_cache_ecc_d1;

    data_cache_ecc_t data_cache_ecc_e;
    data_cache_t data_cache0;
    data_cache_t data_cache1;

    //------------------------------------------------------------------------------
    // Cache controller
    //
    // Handles CPU requests and controls cache and main-memory accesses.
    //------------------------------------------------------------------------------
    cache_controller cache_controller_u (
        .clk            (clk),
        .rst_n          (rst_n),
        .op             (op),
        .addr_cpu_in    (addr_cpu_in),
        .data_cpu_in    (data_cpu_in),
        .data_ready     (data_ready),
        .data_cpu       (data_cpu),
        .we_cache       (we_cache),
        .addr_cache     (addr_cache),
        .data_cache_wr  (data_cache_wr),
        .way_select     (way_select),
        .data_cache1    (data_cache0),
        .data_cache2    (data_cache1),
        .re_mem         (re_mem),
        .we_mem         (we_mem),
        .addr_mem       (addr_mem),
        .data_mem_write (data_mem_write),
        .valid_mem      (valid_mem),
        .data_mem_read  (data_mem_read)
    );


    //------------------------------------------------------------------------------
    // Cache SRAM
    //
    // Stores the ECC-protected cache lines.
    //------------------------------------------------------------------------------
    cache_SRAM memory_cache (
        .clk        (clk),
        .rst_n      (rst_n),
        .we_cache   (we_cache),
        .addr_cache (addr_cache),
        .way_select (way_select),
        .data_in    (data_cache_ecc_e),
        .data_out1  (data_cache_ecc_d0),
        .data_out2  (data_cache_ecc_d1)
    );


    //------------------------------------------------------------------------------
    // ECC encoder
    //
    // Encodes the cache line produced by the controller before it is written
    // into the SRAM.
    //------------------------------------------------------------------------------
    ECC_full_encoder enc (
        .data_cache     (data_cache_wr),
        .data_cache_ecc (data_cache_ecc_e)
    );


    //------------------------------------------------------------------------------
    // ECC decoder - way 0
    //
    // Decodes the ECC-protected cache line read from way 0.
    //------------------------------------------------------------------------------
    ECC_full_decoder dec_way0 (
        .data_cache_ecc (data_cache_ecc_d0),
        .data_cache     (data_cache0)
    );


    //------------------------------------------------------------------------------
    // ECC decoder - way 1
    //
    // Decodes the ECC-protected cache line read from way 1.
    //------------------------------------------------------------------------------
    ECC_full_decoder dec_way1 (
        .data_cache_ecc (data_cache_ecc_d1),
        .data_cache     (data_cache1)
    );



endmodule