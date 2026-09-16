#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#ifdef VERIDMA_STANDALONE
#include <vector>
#endif

#ifndef VERIDMA_STANDALONE
#include "svdpi.h"
#endif

namespace {

std::uint32_t crc32(const std::uint8_t* data, std::size_t length) {
  std::uint32_t crc = 0xFFFFFFFFu;
  for (std::size_t byte_index = 0; byte_index < length; ++byte_index) {
    crc ^= data[byte_index];
    for (unsigned bit_index = 0; bit_index < 8; ++bit_index) {
      crc = (crc & 1u) ? ((crc >> 1u) ^ 0xEDB88320u) : (crc >> 1u);
    }
  }
  return ~crc;
}

}  // namespace

#ifndef VERIDMA_STANDALONE
extern "C" void dma_ref_transfer(
    const svOpenArrayHandle source_data,
    const svOpenArrayHandle destination_data,
    unsigned int length,
    svBit crc_enable,
    unsigned int* crc_result) {
  if (source_data == nullptr || destination_data == nullptr || crc_result == nullptr) {
    return;
  }

  std::uint32_t crc = 0xFFFFFFFFu;
  for (unsigned int index = 0; index < length; ++index) {
    auto* source_byte = static_cast<std::uint8_t*>(svGetArrElemPtr1(source_data, index));
    auto* destination_byte = static_cast<std::uint8_t*>(svGetArrElemPtr1(destination_data, index));
    if (source_byte == nullptr || destination_byte == nullptr) {
      return;
    }
    *destination_byte = *source_byte;
    if (crc_enable) {
      crc ^= *source_byte;
      for (unsigned bit_index = 0; bit_index < 8; ++bit_index) {
        crc = (crc & 1u) ? ((crc >> 1u) ^ 0xEDB88320u) : (crc >> 1u);
      }
    }
  }

  *crc_result = crc_enable ? ~crc : 0u;
}
#else
int main() {
  const char* canonical = "123456789";
  const auto result = crc32(reinterpret_cast<const std::uint8_t*>(canonical), 9);
  if (result != 0xCBF43926u) {
    std::fprintf(stderr, "CRC32 self-test failed: got 0x%08X\n", result);
    return EXIT_FAILURE;
  }

  std::vector<std::uint8_t> payload(4096);
  for (std::size_t index = 0; index < payload.size(); ++index) {
    payload[index] = static_cast<std::uint8_t>(index);
  }
  if (crc32(payload.data(), payload.size()) != 0xA2912082u) {
    std::fprintf(stderr, "CRC32 deterministic payload test failed\n");
    return EXIT_FAILURE;
  }
  std::puts("dma_ref CRC32 tests passed");
  return EXIT_SUCCESS;
}
#endif
