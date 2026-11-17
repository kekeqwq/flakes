// Pure decision-table test; never reads lock state or starts authentication.
#import "ctk-lock-state.h"
#undef NDEBUG
#include <assert.h>
#include <stdio.h>
static ProbeLockObservation vector(unsigned mask) {
    return (ProbeLockObservation){
        !!(mask & 1), !!(mask & 2), !!(mask & 4), !!(mask & 8),
        !!(mask & 16), !!(mask & 32), !!(mask & 64), !!(mask & 128)
    };
}
int main(void) {
    @autoreleasepool {
        ProbeLockObservation full = vector(255);
        ProbeLockObservation noQuartz = { .ordinaryUser = YES };
        assert(ProbeLockDecision(full, full, 1, 1));
        assert(ProbeLockDecision(noQuartz, full, 1, 1));
        unsigned checked = 0;
        for (unsigned g = 0; g < 256; g++) {
            for (unsigned l = 0; l < 256; l++) {
                ProbeLockObservation local = vector(l), global = vector(g);
                BOOL expected = g == 255 && (l & 1) && (!(l & 2) || l == 255);
                assert(ProbeLockDecision(local, global, 1, 1) == expected);
                checked++;
            }
        }
        for (NSUInteger a = 0; a < 4; a++) for (NSUInteger o = 0; o < 4; o++) {
            assert(ProbeLockDecision(noQuartz, full, a, o) == (a == 1 && o == 1));
            assert(ProbeLockDecision(full, full, a, o) == (a == 1 && o == 1));
        }
        puts("PASS: 65,536 lock-state combinations and ambiguous-console counts; pure test, no OS query/auth.");
        return checked == 65536 ? 0 : 1;
    }
}
