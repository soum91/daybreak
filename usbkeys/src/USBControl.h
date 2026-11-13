#pragma once
#include <IOKit/IOKitLib.h>
typedef struct UKUSBControl UKUSBControl;
typedef struct {
  uint64_t requests, replies, completed, rejected, failures;
  uint64_t getReport, setReport, getIdle, setIdle, getProtocol, setProtocol, descriptor;
  uint8_t protocol, idle;
  IOReturn lastError;
} UKControlStats;
IOReturn UKControlStart(io_connect_t port, UKUSBControl **control);
void UKControlStop(UKUSBControl *control);
UKControlStats UKControlRead(UKUSBControl *control);
