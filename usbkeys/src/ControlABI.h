#pragma once
#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
// Native selector 9 expects the allocation token, not its mapped address.
static inline void UKControlSetupReply(uint64_t out[5], bool handled,
 size_t length, uint64_t token, uint64_t transaction) {
  out[0]=handled; out[1]=length; out[2]=token;
  out[3]=0; out[4]=transaction;
}
