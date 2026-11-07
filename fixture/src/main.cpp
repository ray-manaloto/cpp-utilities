#include <cstddef>
#include <cstdio>
#include <string>
#include <vector>

extern "C" unsigned fixture_checksum(const unsigned char *data, std::size_t size);
#ifdef FIXTURE_REFLECTION
int fixture_reflected_members();
#endif
#ifdef FIXTURE_IMPORT_STD
int fixture_import_std();
#endif

int main() {
  const std::string text = "profile";
  std::vector<unsigned char> bytes(text.begin(), text.end());
  int failures = fixture_checksum(bytes.data(), bytes.size()) == 0 ? 1 : 0;
#ifdef FIXTURE_REFLECTION
  failures += fixture_reflected_members() == 2 ? 0 : 1;
#endif
#ifdef FIXTURE_IMPORT_STD
  failures += fixture_import_std() == 3 ? 0 : 1;
#endif
  std::printf("fixture: %d failures\n", failures);
  return failures;
}
