// HyperOS 4 BAA_ENC patch generator. No embedded OEM files, keys or config.
// Uses the target device's original libbaa_common.so for crypto.
// MIT License; JSON parser: nlohmann/json (MIT).
#include <dlfcn.h>
#include <fstream>
#include <iostream>
#include <iterator>
#include <stdexcept>
#include <string>
#include <sys/stat.h>
#include <nlohmann/json.hpp>

using json = nlohmann::json;

static std::string read_checked(const std::string& path) {
    struct stat st{};
    if (stat(path.c_str(), &st) || !S_ISREG(st.st_mode) || st.st_size < 512 || st.st_size > 1024*1024)
        throw std::runtime_error("Invalid file or size: " + path);
    std::ifstream f(path, std::ios::binary);
    if (!f) throw std::runtime_error("Cannot open input: " + path);
    std::string v((std::istreambuf_iterator<char>(f)), std::istreambuf_iterator<char>());
    if (v.size() != static_cast<size_t>(st.st_size)) throw std::runtime_error("Short read");
    return v;
}
static void write_checked(const std::string& path, const std::string& content) {
    if (path.find("/odm/")==0 || path.find("/vendor/")==0 || path.find("/sys/")==0 ||
        path.find("/proc/")==0 || path.find("/data/vendor/")==0 || path.find("/system/")==0)
        throw std::runtime_error("Refusing output on protected path");
    std::ofstream f(path, std::ios::binary | std::ios::trunc);
    if (!f || !f.write(content.data(), static_cast<std::streamsize>(content.size())) || !f.flush())
        throw std::runtime_error("Write failed");
}
class VendorCrypto {
    alignas(16) unsigned char storage[4096]{};
    using Crypt = std::string (*)(void*, const std::string&);
    Crypt enc{}, dec{};
public:
    VendorCrypto() {
        void* h = dlopen("/vendor/lib64/libbaa_common.so", RTLD_NOW|RTLD_LOCAL);
        if (!h) throw std::runtime_error(std::string("Vendor library unavailable: ")+dlerror());
        constexpr const char* ctor = "_ZN4aidl6vendor6xiaomi8hardware16batteryantiaging13AESEncryptionC1Ev";
        constexpr const char* decrypt_sym = "_ZN4aidl6vendor6xiaomi8hardware16batteryantiaging13AESEncryption7decryptERKNSt3__112basic_stringIcNS5_11char_traitsIcEENS5_9allocatorIcEEEE";
        constexpr const char* encrypt_sym = "_ZN4aidl6vendor6xiaomi8hardware16batteryantiaging13AESEncryption7encryptERKNSt3__112basic_stringIcNS5_11char_traitsIcEENS5_9allocatorIcEEEE";
        auto init = reinterpret_cast<void(*)(void*)>(dlsym(h, ctor));
        dec = reinterpret_cast<Crypt>(dlsym(h,decrypt_sym));
        enc = reinterpret_cast<Crypt>(dlsym(h,encrypt_sym));
        if (!init || !dec || !enc) throw std::runtime_error("Incompatible vendor crypto symbol ABI");
        init(storage);
    }
    std::string decrypt(const std::string& input) const {
        if (input.compare(0,8,"BAA_ENC:") != 0) throw std::runtime_error("Missing BAA_ENC header");
        std::string clear=dec(const_cast<unsigned char*>(storage),input.substr(8));
        if (clear.empty() || clear.front()!='{' || clear.back()!='}') throw std::runtime_error("Vendor decryption returned invalid JSON");
        return clear;
    }
    std::string encrypt(const std::string& json_text) const {
        std::string body=enc(const_cast<unsigned char*>(storage),json_text);
        if (body.empty() || body.size()%4) throw std::runtime_error("Invalid vendor Base64 encryption output");
        return "BAA_ENC:"+body;
    }
};
static void low_soh(json& obj) {
    auto& n=obj.at("LowSoh-FvDown").at("sysfs_node");
    auto& cycle=n.at("cyclecount");
    auto& soh=n.at("soh");
    if (cycle.at("range_min")!=200 || cycle.at("range_max")!=800 || soh.at("threshold")!=85)
        throw std::runtime_error("Unexpected source LowSoh conditions");
    cycle["range_min"]=801;
    cycle["range_max"]=2147483647;
    soh["threshold"]=50;
}
static void maps(json& obj) {
    const json expected=json::parse(R"([{"idx":1,"min":1,"max":100},{"idx":2,"min":101,"max":300},{"idx":3,"min":301,"max":800},{"idx":4,"min":801,"max":2147483647}])");
    const json after=json::parse(R"([{"idx":1,"min":1,"max":2147483647}])");
    auto& vendor=obj.at("BasedOnCC-VolDown").at("vendor_id_3");
    for(const char* battery: {"CN-battery","GL-battery"}) {
        auto& row=vendor.at(battery).at("cyclecount_index_map");
        if (row!=expected) throw std::runtime_error(std::string("Unexpected source map: ")+battery);
        row=after;
    }
}
static void patch(const std::string& source, const std::string& output, VendorCrypto& crypto, bool pudding) {
    const std::string plain=crypto.decrypt(read_checked(source));
    const json initial=json::parse(plain);
    json transformed=initial;
    low_soh(transformed);
    if (pudding) maps(transformed);
    // Semantic proof: reversing *only* the intended changes reconstructs all OEM configuration.
    json reversed=transformed;
    auto& n=reversed.at("LowSoh-FvDown").at("sysfs_node");
    n.at("cyclecount")["range_min"]=200;
    n.at("cyclecount")["range_max"]=800;
    n.at("soh")["threshold"]=85;
    if (pudding) {
        const json original_map=json::parse(R"([{"idx":1,"min":1,"max":100},{"idx":2,"min":101,"max":300},{"idx":3,"min":301,"max":800},{"idx":4,"min":801,"max":2147483647}])");
        auto& v=reversed.at("BasedOnCC-VolDown").at("vendor_id_3");
        v.at("CN-battery")["cyclecount_index_map"]=original_map;
        v.at("GL-battery")["cyclecount_index_map"]=original_map;
    }
    if(reversed!=initial) throw std::runtime_error("Unexpected fields changed");
    const std::string text=transformed.dump();
    const std::string output_cipher=crypto.encrypt(text);
    if (json::parse(crypto.decrypt(output_cipher))!=transformed)
        throw std::runtime_error("BAA_ENC roundtrip validation failed");
    write_checked(output,output_cipher);
    std::cout << "PASS " << (pudding?"pudding":"common") << ", patched ciphertext bytes=" << output_cipher.size() << "\n";
}
int main(int argc, char** argv) {
    if(argc!=5) {
        std::cerr<<"Usage: baa_patch OEM_PUDDING OEM_COMMON OUTPUT_PUDDING OUTPUT_COMMON\n";
        return 2;
    }
    try {
        if(std::string(argv[3])==argv[1] || std::string(argv[4])==argv[2])
            throw std::runtime_error("Refusing in-place patch");
        VendorCrypto crypto;
        patch(argv[1],argv[3],crypto,true);
        patch(argv[2],argv[4],crypto,false);
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "ERROR: " << e.what() << "\n";
        return 1;
    }
}
