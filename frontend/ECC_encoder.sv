
module ECC_encoder (
    input  logic [7:0]  data1,
    input  logic [7:0]  data2,
    output logic [7:0]  redun1,
    output logic [7:0]  redun2
);

    //------------------------------------------------------------------------------
    // ECC encoder
    //
    // Converts two 8-bit data words into their corresponding 8-bit redundancy
    // representations.
    //
    // The encoding is purely combinational: each redundancy bit is computed from
    // the input data bits using the ECC encoding equations.
    //------------------------------------------------------------------------------

    assign redun1[7] = data1[5] ^ data1[1] ^ data1[3];
    assign redun1[6] = data1[0] ^ data1[7];
    assign redun1[5] = data1[5] ^ data1[3] ^ data1[2];
    assign redun1[4] = data1[0] ^ data1[6] ^ data1[2] ^ data1[5] ^ data1[1];
    assign redun1[3] = data1[5] ^ data1[3] ^ data1[0] ^ data1[7];
    assign redun1[2] = data1[0] ^ data1[1] ^ data1[5] ^ data1[3] ^ data1[2];
    assign redun1[1] = data1[1] ^ data1[4] ^ data1[3] ^ data1[2];
    assign redun1[0] = data1[0] ^ data1[6] ^ data1[3] ^ data1[2] ^ data1[1] ^ data1[4];

    assign redun2[7] = data2[5] ^ data2[1] ^ data2[3];
    assign redun2[6] = data2[0] ^ data2[7];
    assign redun2[5] = data2[5] ^ data2[3] ^ data2[2];
    assign redun2[4] = data2[0] ^ data2[6] ^ data2[2] ^ data2[5] ^ data2[1];
    assign redun2[3] = data2[5] ^ data2[3] ^ data2[0] ^ data2[7];
    assign redun2[2] = data2[0] ^ data2[1] ^ data2[5] ^ data2[3] ^ data2[2];
    assign redun2[1] = data2[1] ^ data2[4] ^ data2[3] ^ data2[2];
    assign redun2[0] = data2[0] ^ data2[6] ^ data2[3] ^ data2[2] ^ data2[1] ^ data2[4];
    
    
endmodule