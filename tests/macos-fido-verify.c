// Software assertions only: ephemeral in-memory test keys, never store/log them.
#include <fido.h>
#include <fido/es256.h>
#include <openssl/evp.h>
#include <openssl/rand.h>
#undef NDEBUG
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const char *rp = "pam://keke-flakes";
static void install(fido_assert_t *a, EVP_PKEY *key, const unsigned char nonce[32], unsigned char flags) {
    unsigned char authdata[37] = {0};
    unsigned int length = 0;
    assert(EVP_Digest(rp, strlen(rp), authdata, &length, EVP_sha256(), NULL) == 1 && length == 32);
    authdata[32] = flags;
    authdata[36] = 1;
    EVP_MD_CTX *context = EVP_MD_CTX_new();
    assert(context && EVP_DigestSignInit(context, NULL, EVP_sha256(), NULL, key) == 1);
    assert(EVP_DigestSignUpdate(context, authdata, sizeof(authdata)) == 1);
    assert(EVP_DigestSignUpdate(context, nonce, 32) == 1);
    size_t size = 0;
    assert(EVP_DigestSignFinal(context, NULL, &size) == 1);
    unsigned char *signature = malloc(size);
    assert(signature && EVP_DigestSignFinal(context, signature, &size) == 1);
    assert(fido_assert_set_count(a, 1) == FIDO_OK);
    assert(fido_assert_set_rp(a, rp) == FIDO_OK);
    assert(fido_assert_set_clientdata_hash(a, nonce, 32) == FIDO_OK);
    assert(fido_assert_set_up(a, FIDO_OPT_TRUE) == FIDO_OK);
    assert(fido_assert_set_uv(a, FIDO_OPT_FALSE) == FIDO_OK);
    assert(fido_assert_set_authdata_raw(a, 0, authdata, sizeof(authdata)) == FIDO_OK);
    assert(fido_assert_set_sig(a, 0, signature, size) == FIDO_OK);
    free(signature);
    EVP_MD_CTX_free(context);
}
int main(void) {
    fido_init(0);
    EVP_PKEY *key = EVP_PKEY_Q_keygen(NULL, NULL, "EC", "P-256");
    EVP_PKEY *other = EVP_PKEY_Q_keygen(NULL, NULL, "EC", "P-256");
    es256_pk_t *pk = es256_pk_new(), *wrong = es256_pk_new();
    fido_assert_t *a = fido_assert_new();
    unsigned char nonce[32], changed[32];
    assert(key && other && pk && wrong && a && RAND_bytes(nonce, sizeof(nonce)) == 1);
    assert(es256_pk_from_EVP_PKEY(pk, key) == FIDO_OK);
    assert(es256_pk_from_EVP_PKEY(wrong, other) == FIDO_OK);
    install(a, key, nonce, 1);
    assert(fido_assert_verify(a, 0, COSE_ES256, pk) == FIDO_OK);
    assert(fido_assert_verify(a, 0, COSE_ES256, wrong) != FIDO_OK);
    assert(fido_assert_set_rp(a, "pam://wrong-rp") == FIDO_OK);
    assert(fido_assert_verify(a, 0, COSE_ES256, pk) != FIDO_OK);
    assert(fido_assert_set_rp(a, rp) == FIDO_OK);
    memcpy(changed, nonce, sizeof(changed)); changed[0] ^= 1;
    assert(fido_assert_set_clientdata_hash(a, changed, sizeof(changed)) == FIDO_OK);
    assert(fido_assert_verify(a, 0, COSE_ES256, pk) != FIDO_OK);
    install(a, key, nonce, 0); // Valid signature without presence must fail.
    assert(fido_assert_verify(a, 0, COSE_ES256, pk) != FIDO_OK);
    install(a, key, nonce, 1);
    const unsigned char invalid[] = {0x30, 0x00};
    assert(fido_assert_set_sig(a, 0, invalid, sizeof(invalid)) == FIDO_OK);
    assert(fido_assert_verify(a, 0, COSE_ES256, pk) != FIDO_OK);
    fido_assert_free(&a); es256_pk_free(&pk); es256_pk_free(&wrong);
    EVP_PKEY_free(key); EVP_PKEY_free(other);
    puts("PASS: valid signature; wrong key/RP/nonce, missing UP and invalid signature rejected. No HID or persistent key.");
    return 0;
}
