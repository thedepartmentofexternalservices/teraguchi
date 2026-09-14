#include "decode-contract.h"
#include <cstdio>
#include <initializer_list>

int main()
{
    const DecodeFormat expected={"hevc",4,3840,2160,10,0,0,0,2};
    int checks=0;
    auto require=[&](bool result) { ++checks; return result; };
    if (!require(!decodeMismatch(expected,expected,true,1))) return 1;
    for (int hardware : {0,-1,-22})
        if (!require(decodeMismatch(expected,expected,true,hardware) != nullptr)) return 2;
    if (!require(!decodeMismatch(expected,expected,false,0))) return 3;
    for (int property=0;property<9;++property) {
        DecodeFormat wrong=expected;
        switch (property) {
            case 0: wrong.codec="h264"; break;
            case 1: wrong.profile=2; break;
            case 2: wrong.width=1920; break;
            case 3: wrong.height=1080; break;
            case 4: wrong.depth=8; break;
            case 5: wrong.chromaW=1; break;
            case 6: wrong.chromaH=1; break;
            case 7: wrong.matrix=1; break;
            case 8: wrong.range=1; break;
        }
        if (!require(decodeMismatch(expected,wrong,true,1) != nullptr)) return 4;
        if (!require(decodeMismatch(expected,wrong,false,0) != nullptr)) return 5;
    }
    // A valid first frame cannot make a later format change pass.
    DecodeFormat later=expected; later.depth=8;
    if (!require(!decodeMismatch(expected,expected,true,1) &&
                 decodeMismatch(expected,later,true,1) != nullptr)) return 6;
    printf("decode_contract=pass checks=%d\n",checks);
}
