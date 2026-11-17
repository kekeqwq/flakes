#pragma once
// A per-request decision only; no cached/global authenticated state.
static inline BOOL ProbeBridgeMayUseSE(BOOL freshFidoVerified, BOOL stillLocked, BOOL ownSEKeyReady) {
    return freshFidoVerified && stillLocked && ownSEKeyReady;
}
