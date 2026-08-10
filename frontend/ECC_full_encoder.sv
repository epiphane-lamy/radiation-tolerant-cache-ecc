import cache_pkg::*;

//------------------------------------------------------------------------------
// Full ECC encoder
//
// Wraps the combinational ECC encoder to operate directly on a complete
// cache line.
//
// The tag and valid bit are preserved unchanged, while the two 8-bit data
// words are encoded to generate their corresponding redundancy values.
//
// The resulting data_cache_ecc_t structure contains the original cache line
// data together with the redundancy bits required for ECC decoding.
//------------------------------------------------------------------------------

module ECC_full_encoder (
    input  data_cache_t     data_cache,
    output data_cache_ecc_t data_cache_ecc
);



logic [7:0] data_in_1;
logic [7:0] data_in_2;
logic [7:0] redun_out_1;
logic [7:0] redun_out_2;

ECC_encoder u_encoder (
    .data1  (data_in_1),
    .data2  (data_in_2),
    .redun1 (redun_out_1),
    .redun2 (redun_out_2)
);


assign data_in_1 = data_cache.data1;
assign data_in_2 = data_cache.data2;


assign data_cache_ecc.tag   = data_cache.tag;
assign data_cache_ecc.valid = data_cache.valid;

assign data_cache_ecc.data1  = data_cache.data1;
assign data_cache_ecc.redun1 = redun_out_1;
assign data_cache_ecc.data2  = data_cache.data2;
assign data_cache_ecc.redun2 = redun_out_2;

endmodule