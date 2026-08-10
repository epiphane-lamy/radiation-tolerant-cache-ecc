package cache_pkg;

//------------------------------------------------------------------------------
// Cache line data structures
//
// data_cache_ecc_t : cache line with redundancy fields for error detection
//                    or correction (37 bits total).
//
// data_cache_t     : standard cache line used by the cache controller
//                    (21 bits total).
//------------------------------------------------------------------------------

    typedef struct packed {
        logic [3:0] tag;
        logic       valid;
        logic [7:0] data1;
        logic [7:0] redun1;
        logic [7:0] data2;
        logic [7:0] redun2;
    } data_cache_ecc_t;

    // struct cache line (21bits)
    typedef struct packed {
        logic [3:0] tag;
        logic       valid;
        logic [7:0] data1;
        logic [7:0] data2;
    } data_cache_t;

endpackage
