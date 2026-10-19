// Build-on-GitHub compatibility probe (Android NDK r27).
// Experimental local compatibility probe, not a charger-modification daemon.
// Only reads the given input file and writes an explicitly named staging file.
#include <dlfcn.h>
#include <sys/stat.h>
#include <cstring>
#include <exception>
#include <fstream>
#include <iostream>
#include <iterator>
#include <string>
#include <array>

static bool read_file(const char* p, std::string &v) {
    struct stat st{};
    if (stat(p, &st) || !S_ISREG(st.st_mode) || st.st_size < 1 || st.st_size > 1024*1024) return false;
    std::ifstream in(p, std::ios::binary);
    if (!in) return false;
    v.assign(std::istreambuf_iterator<char>(in), std::istreambuf_iterator<char>());
    return in.good() || in.eof();
}
static bool write_staging(const char* p, const std::string& v) {
    const std::string path(p);
    if (path.find("/odm/")==0 || path.find("/vendor/")==0 ||
        path.find("/sys/")==0 || path.find("/proc/")==0 ||
        path.find("/data/vendor/")==0) return false;
    std::ofstream out(p, std::ios::binary|std::ios::trunc);
    out.write(v.data(), static_cast<std::streamsize>(v.size()));
    out.flush();
    return out.good();
}
int main(int argc, char** argv) {
    if (argc!=4 || (strcmp(argv[1],"encrypt") && strcmp(argv[1],"decrypt")) ||
        !strcmp(argv[2],argv[3])) {
        std::cerr<<"usage: baa_crypt_probe encrypt|decrypt INPUT STAGING_OUTPUT\n";
        return 2;
    }
    std::string input;
    if (!read_file(argv[2], input)) return 3;
    void* handle=dlopen("/vendor/lib64/libbaa_common.so", RTLD_NOW|RTLD_LOCAL);
    if (!handle) { std::cerr<<dlerror()<<"\n"; return 4; }
    const char* ctor="_ZN4aidl6vendor6xiaomi8hardware16batteryantiaging13AESEncryptionC1Ev";
    const char* dec="_ZN4aidl6vendor6xiaomi8hardware16batteryantiaging13AESEncryption7decryptERKNSt3__112basic_stringIcNS5_11char_traitsIcEENS5_9allocatorIcEEEE";
    const char* enc="_ZN4aidl6vendor6xiaomi8hardware16batteryantiaging13AESEncryption7encryptERKNSt3__112basic_stringIcNS5_11char_traitsIcEENS5_9allocatorIcEEEE";
    using Ctor=void (*)(void*);
    using Crypt=std::string (*)(void*,const std::string&);
    auto init=reinterpret_cast<Ctor>(dlsym(handle,ctor));
    auto run=reinterpret_cast<Crypt>(dlsym(handle,!strcmp(argv[1],"encrypt")?enc:dec));
    if (!init || !run) return 5;
    alignas(16) std::array<unsigned char,4096> obj{};
    try {
        init(obj.data());
        const std::string output=run(obj.data(),input);
        if (output.empty() || output.size()>1024*1024) return 6;
        if (!strcmp(argv[1],"decrypt") && (output.find('{')==std::string::npos || output.find('}')==std::string::npos)) return 7;
        if (!strcmp(argv[1],"encrypt") && output.size()%4 != 0) return 8; // Vendor encrypt() returns Base64 body; config wrapper adds BAA_ENC:
        if (!write_staging(argv[3],output)) return 9;
        std::cout<<"OK "<<argv[1]<<" staged bytes="<<output.size()<<"\n";
        return 0;
    } catch (const std::exception& e) {
        std::cerr<<e.what()<<"\n";return 10;
    } catch (...) {return 11;}
}
