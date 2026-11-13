#include <assert.h>
#include <stdio.h>
#include "../src/ControlABI.h"
int main(void) {
  uint64_t reply[5];
  // Model an allocation whose token differs from its user mapping.
  uint64_t mapping=0x123400000, token=0x765, transaction=0x8899;
  UKControlSetupReply(reply,true,8,token,transaction);
  assert(reply[0]==1 && reply[1]==8 && reply[2]==token);
  assert(reply[2]!=mapping && reply[3]==0 && reply[4]==transaction);
  UKControlSetupReply(reply,true,0,token,transaction+1);
  assert(reply[1]==0 && reply[4]==transaction+1);
  UKControlSetupReply(reply,false,0,token,transaction+2);
  assert(reply[0]==0);
  puts("PASS: control reply token, payload length, status and transaction packing");
}
