// Pure authorization-flow truth table. No key generation, OS query, HID or signing.
#import <Foundation/Foundation.h>
#import "ctk-bridge-policy.h"
#undef NDEBUG
#include <assert.h>
#include <stdio.h>
int main(void) {
    for (unsigned mask = 0; mask < 8; mask++) {
        BOOL fido = !!(mask & 1), locked = !!(mask & 2), ready = !!(mask & 4);
        unsigned calls = 0;
        if (ProbeBridgeMayUseSE(fido, locked, ready)) calls++;
        assert(calls == (mask == 7 ? 1u : 0u));
    }
    assert(ProbeBridgeMayUseSE(YES, YES, YES));
    assert(!ProbeBridgeMayUseSE(NO, YES, YES)); // No authentication cached after success.
    puts("PASS: bridge permits SE only for fresh verified FIDO + still locked + own key; no cached authorization.");
    return 0;
}
