import std;

int fixture_import_std() {
  std::vector<int> v{1, 2, 3};
  return static_cast<int>(v.size());
}
