// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "BoohtaRnnoise",
    products: [.library(name: "BoohtaRnnoise", targets: ["BoohtaRnnoise"])],
    targets: [.target(
        name: "BoohtaRnnoise", path: ".",
        sources: ["rnnoise_capture_processor.cc", "noise_engine_names.cc", "deepfilter/capture_hook/process.cc",
                  "microphone_controls/processor.cc", "upstream/src/denoise.c",
                  "upstream/src/kiss_fft.c", "upstream/src/pitch.c",
                  "upstream/src/celt_lpc.c", "upstream/src/rnn.c", "upstream/src/rnn_data.c"],
        publicHeadersPath: "public_include",
        cSettings: [.headerSearchPath("upstream/src"), .headerSearchPath("upstream/include")],
        cxxSettings: [.headerSearchPath("upstream/include")])],
    cxxLanguageStandard: .cxx17)
