


module ECC_decoder (
    input  logic [7:0]  redun1,
    input  logic [7:0]  redun2,
    output logic [7:0]  data1,
    output logic [7:0]  data2
);

    //------------------------------------------------------------------------------
    // ECC decoder
    //
    // Converts the 8-bit redundancy representation of two cache words back into
    // their corresponding 8-bit data values.
    //
    // The decoding is purely combinational: each output data bit is reconstructed
    // from the corresponding redundancy bits using the ECC decoding equations.
    //------------------------------------------------------------------------------

    assign data1[7] = redun1[7] ^ redun1[3] ^ redun1[2] ^ redun1[5];
    assign data1[6] = redun1[7] ^ redun1[6] ^ redun1[5] ^ redun1[3] ^ redun1[2] ^ redun1[1] ^ redun1[0];
    assign data1[5] = redun1[7] ^ redun1[5] ^ redun1[4] ^ redun1[1] ^ redun1[0];
    assign data1[4] = redun1[6] ^ redun1[4] ^ redun1[3] ^ redun1[0];
    assign data1[3] = redun1[7] ^ redun1[6] ^ redun1[5] ^ redun1[4] ^ redun1[3] ^ redun1[1] ^ redun1[0];
    assign data1[2] = redun1[6] ^ redun1[5] ^ redun1[3];
    assign data1[1] = redun1[7] ^ redun1[6] ^ redun1[3];
    assign data1[0] = redun1[7] ^ redun1[6] ^ redun1[3] ^ redun1[2] ^ redun1[5];

    assign data2[7] = redun2[7] ^ redun2[3] ^ redun2[2] ^ redun2[5];
    assign data2[6] = redun2[7] ^ redun2[6] ^ redun2[5] ^ redun2[3] ^ redun2[2] ^ redun2[1] ^ redun2[0];
    assign data2[5] = redun2[7] ^ redun2[5] ^ redun2[4] ^ redun2[1] ^ redun2[0];
    assign data2[4] = redun2[6] ^ redun2[4] ^ redun2[3] ^ redun2[0];
    assign data2[3] = redun2[7] ^ redun2[6] ^ redun2[5] ^ redun2[4] ^ redun2[3] ^ redun2[1] ^ redun2[0];
    assign data2[2] = redun2[6] ^ redun2[5] ^ redun2[3];
    assign data2[1] = redun2[7] ^ redun2[6] ^ redun2[3];
    assign data2[0] = redun2[7] ^ redun2[6] ^ redun2[3] ^ redun2[2] ^ redun2[5];
    

endmodule