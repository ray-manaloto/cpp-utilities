#include <stddef.h>

unsigned fixture_checksum(const unsigned char *data, size_t size) {
  unsigned sum = 0;
  for (size_t i = 0; i < size; ++i) {
    sum = sum * 31u + data[i];
  }
  return sum;
}
