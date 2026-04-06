// Stub for __std_find_first_of_trivial_pos_1, an MSVC STL intrinsic introduced
// in VS 2022 17.8 (MSVC 19.38). firebase_app.lib is compiled against a newer
// toolset that emits calls to this symbol. When building with an older toolset
// the CRT does not provide it, so we supply a scalar fallback here.
#include <cstddef>

extern "C" __declspec(noinline) std::size_t __cdecl
__std_find_first_of_trivial_pos_1(
    const void* haystack, std::size_t haystack_length,
    const void* needle,   std::size_t needle_length) noexcept
{
    const unsigned char* h = static_cast<const unsigned char*>(haystack);
    const unsigned char* n = static_cast<const unsigned char*>(needle);
    for (std::size_t i = 0; i < haystack_length; ++i) {
        for (std::size_t j = 0; j < needle_length; ++j) {
            if (h[i] == n[j]) return i;
        }
    }
    return haystack_length;
}
