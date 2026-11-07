#include <meta>

struct Point {
  int x;
  int y;
};

int fixture_reflected_members() {
  constexpr auto members =
      std::meta::nonstatic_data_members_of(^^Point, std::meta::access_context::unchecked()).size();
  return static_cast<int>(members);
}
