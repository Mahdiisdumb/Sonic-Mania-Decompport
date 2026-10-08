
cmake_minimum_required(VERSION 3.20)

project(RetroEngine)

if(NOT EMSCRIPTEN)
    message(FATAL_ERROR
        "This CMake configuration is for WebAssembly/Emscripten. Configure with emcmake."
    )
endif()

set(RETRO_SUBSYSTEM "SDL2")
set(DEP_PATH all)

message(STATUS "Configuring RetroEngine for WebAssembly")

add_executable(RetroEngine ${RETRO_FILES})

find_package(Ogg CONFIG)

if(NOT Ogg_FOUND)
    message(STATUS "libogg not found; building from source")
    set(COMPILE_OGG TRUE)
else()
    message(STATUS "Found libogg")
    add_library(libogg ALIAS Ogg::ogg)
    target_link_libraries(RetroEngine PRIVATE libogg)
endif()

find_package(unofficial-theora CONFIG)

if(unofficial-theora_FOUND)
    message(STATUS "Found libtheora")
    add_library(libtheora ALIAS unofficial::theora::theora)
    target_link_libraries(RetroEngine PRIVATE libtheora)
else()
    find_package(Theora CONFIG)

    if(Theora_FOUND)
        message(STATUS "Found Theora")
        add_library(libtheora ALIAS Theora::theora)
        target_link_libraries(RetroEngine PRIVATE libtheora)
    else()
        message(STATUS "libtheora not found; building from source")
        set(COMPILE_THEORA TRUE)
    endif()
endif()

target_compile_definitions(RetroEngine PRIVATE
    _CRT_SECURE_NO_WARNINGS
)

target_compile_options(RetroEngine PRIVATE
    -sUSE_SDL=2
    -Wno-microsoft-cast
    -Wno-microsoft-exception-spec
)

target_link_options(RetroEngine PRIVATE
    -sUSE_SDL=2
    -sWASM=1
    -sNO_EXIT_RUNTIME=1
    -sASYNCIFY=1
    -sASSERTIONS=1
    -sUSE_WEBGL2=1
    -sMIN_WEBGL_VERSION=2
    -sALLOW_MEMORY_GROWTH=1
    -sPTHREAD_POOL_SIZE=0
    "-sEXPORTED_RUNTIME_METHODS=['ccall','cwrap']"
    -sFORCE_FILESYSTEM=1
)

if(USE_MINIAUDIO)
    target_compile_definitions(RetroEngine PRIVATE
        RETRO_AUDIODEVICE_MINI=1
    )
endif()

set(WEB_OUTPUT_DIR "${CMAKE_BINARY_DIR}/website")
set(WEB_GAME_DIR "${WEB_OUTPUT_DIR}/game")

file(MAKE_DIRECTORY "${WEB_OUTPUT_DIR}" "${WEB_GAME_DIR}")

add_custom_command(
    TARGET RetroEngine
    POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "$<TARGET_FILE:RetroEngine>"
        "${WEB_OUTPUT_DIR}/RSDKv5U.js"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "$<TARGET_FILE_DIR:RetroEngine>/RSDKv5U.wasm"
        "${WEB_OUTPUT_DIR}/RSDKv5U.wasm"
    COMMAND ${CMAKE_COMMAND} -E touch
        "${WEB_OUTPUT_DIR}/Settings.ini"
    COMMENT "Preparing WebAssembly website output"
    VERBATIM
)

file(WRITE "${WEB_OUTPUT_DIR}/index.html" [=[
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Sonic Mania Plus - RSDKv5U</title>
<style>
*{box-sizing:border-box}
html,body{margin:0;min-height:100%;background:#070b18;color:#e8efff;font-family:Consolas,"Courier New",monospace}
body{padding:16px}
#loader{max-width:1000px;margin:0 auto 16px;padding:22px;border:1px solid #2455a0;border-radius:10px;background:#0b1429}
h1{text-align:center;color:#ffd52b;font-size:clamp(25px,5vw,42px);margin:0;text-shadow:3px 3px #174ab0}
#subtitle{text-align:center;color:#9ec5ff;margin:8px 0 22px}
#stage{text-align:center;margin-bottom:10px}
#progressOuter{height:24px;border:1px solid #477dce;background:#020610;border-radius:6px;overflow:hidden}
#progressBar{height:100%;width:0;background:linear-gradient(90deg,#0755ef,#00bfff);transition:width .15s}
#progressDetails{display:flex;justify-content:space-between;gap:10px;margin-top:7px;color:#b6c9e9;font-size:12px}
#status{padding:12px;margin-top:16px;background:#101e38;border-left:3px solid #168cff;overflow-wrap:anywhere}
#consoleTitle{max-width:1000px;margin:auto;padding:10px;border:1px solid #2455a0;border-bottom:0;background:#0b1429;color:#8ec5ff}
#console{max-width:1000px;height:300px;overflow:auto;margin:auto;padding:12px;border:1px solid #2455a0;background:#02050a;font-size:12px;line-height:1.5;white-space:pre-wrap;overflow-wrap:anywhere}
.log-line{margin:0;white-space:pre-wrap;overflow-wrap:anywhere}
.log-info{color:#8bd5ff}.log-warn{color:#ffd36b}.log-error{color:#ff7777}.log-debug{color:#a1afc8}
#actions{text-align:center;margin:10px}
button{padding:8px 12px;border:1px solid #3266ac;border-radius:5px;background:#112647;color:white;cursor:pointer}
#gameContainer{display:flex;justify-content:center;background:#000}
canvas{display:block;width:min(100%,960px);height:auto;aspect-ratio:4/3;background:#000;image-rendering:pixelated}
#footer{text-align:center;color:#8495b5;font-size:12px;padding:10px}
</style>
</head>
<body>
<section id="loader">
<h1>SONIC MANIA+</h1>
<div id="subtitle">RSDKv5U WebAssembly Loader</div>
<div id="stage">Preparing to load...</div>
<div id="progressOuter"><div id="progressBar"></div></div>
<div id="progressDetails"><span id="progressText">0%</span><span id="bytesText">Waiting for downloads</span></div>
<div id="status">Initializing loader...</div>
</section>
<h3 id="consoleTitle">Verbose Runtime Console</h3>
<div id="console" role="log" aria-live="polite"></div>
<div id="actions"><button id="saveLog" type="button">Save verbose log (.txt)</button></div>
<div id="gameContainer"><canvas id="canvas" width="640" height="480" tabindex="0"></canvas></div>
<div id="footer">RSDKv5U WebAssembly · Open DevTools (F12) for native browser diagnostics</div>
<script>
"use strict";

const PART_FILES = [
    "game/Data.rsdk.part1",
    "game/Data.rsdk.part2",
    "game/Data.rsdk.part3"
];

const startTime = performance.now();
const history = [];
const consoleBox = document.getElementById("console");
const progressBar = document.getElementById("progressBar");
const progressText = document.getElementById("progressText");
const bytesText = document.getElementById("bytesText");
const stageText = document.getElementById("stage");
const statusText = document.getElementById("status");

const nativeConsole = {};
for (const level of ["log", "info", "warn", "error", "debug"]) {
    nativeConsole[level] = console[level].bind(console);
}

function stringify(value) {
    if (value instanceof Error) return value.stack || value.message;
    if (typeof value === "string") return value;
    if (value instanceof ArrayBuffer) return `ArrayBuffer(${value.byteLength} bytes)`;
    if (ArrayBuffer.isView(value)) return `${value.constructor.name}(${value.byteLength} bytes)`;
    if (value && typeof value === "object") {
        try { return JSON.stringify(value); } catch {}
    }
    return String(value);
}

function log(level, ...args) {
    const elapsed = ((performance.now() - startTime) / 1000).toFixed(3);
    const line = `[+${elapsed}s] [${level.toUpperCase()}] ${args.map(stringify).join(" ")}`;
    history.push(line);

    const entry = document.createElement("div");
    entry.className = "log-line log-" + level;
    entry.textContent = line;
    consoleBox.appendChild(entry);

    while (consoleBox.childElementCount > 5000) {
        consoleBox.firstElementChild.remove();
    }

    consoleBox.scrollTop = consoleBox.scrollHeight;
    (nativeConsole[level] || nativeConsole.log)(line);
}

function progress(percent, stage, status, details) {
    const value = Math.max(0, Math.min(100, percent));
    progressBar.style.width = value + "%";
    progressText.textContent = value.toFixed(1) + "%";
    stageText.textContent = stage;
    statusText.textContent = status;
    if (details !== undefined) bytesText.textContent = details;
}

function formatBytes(n) {
    if (!Number.isFinite(n)) return "unknown size";
    const units = ["B", "KB", "MB", "GB"];
    let i = 0;
    while (n >= 1024 && i < units.length - 1) {
        n /= 1024;
        i++;
    }
    return n.toFixed(i ? 2 : 0) + " " + units[i];
}

for (const level of ["log", "info", "warn", "error", "debug"]) {
    console[level] = (...args) => log(level, ...args);
}

window.addEventListener("error", event => {
    log("error", "Browser error:", event.message || event.error || "Unknown error",
        event.filename || "", event.lineno || "");
});

window.addEventListener("unhandledrejection", event => {
    log("error", "Unhandled promise rejection:", event.reason);
});

const originalFetch = window.fetch.bind(window);
window.fetch = async function(input, init) {
    const url = typeof input === "string" ? input : input.url;
    const started = performance.now();
    log("debug", "Fetch started:", url);

    try {
        const response = await originalFetch(input, init);
        log(response.ok ? "info" : "error", "Fetch response:", response.status,
            response.statusText, url,
            `(${((performance.now() - started) / 1000).toFixed(3)}s)`);
        return response;
    } catch (error) {
        log("error", "Fetch failed:", url, error);
        throw error;
    }
};

document.getElementById("saveLog").addEventListener("click", () => {
    const blob = new Blob([history.join("\r\n")], {type:"text/plain"});
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "rsdk-webassembly.log.txt";
    a.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
    log("info", "Saved verbose log download.");
});

function reportBytesLoaded(file, received, total) {
    const suffix = total ? ` / ${formatBytes(total)}` : "";
    bytesText.textContent = `${file}: ${formatBytes(received)}${suffix}`;
}

async function fetchPart(url, index) {
    const number = index + 1;
    const started = performance.now();

    progress(5 + index * 17, `Downloading archive (${number}/${PART_FILES.length})`,
        `Downloading ${url}`, `Part ${number} starting...`);
    log("info", `Archive part ${number}/${PART_FILES.length}: ${url}`);

    const response = await fetch(url, {cache:"no-store"});
    if (!response.ok) {
        throw new Error(`HTTP ${response.status} loading ${url}`);
    }

    const total = Number(response.headers.get("content-length")) || 0;
    if (!response.body || !response.body.getReader) {
        const buffer = await response.arrayBuffer();
        log("info", `${url} loaded: ${formatBytes(buffer.byteLength)}`);
        return new Uint8Array(buffer);
    }

    const reader = response.body.getReader();
    const chunks = [];
    let received = 0;
    let lastLog = performance.now();

    while (true) {
        const result = await reader.read();
        if (result.done) break;

        chunks.push(result.value);
        received += result.value.byteLength;

        const fraction = total > 0 ? Math.min(1, received / total) : 0;
        progress(5 + index * 17 + fraction * 16,
            `Downloading archive (${number}/${PART_FILES.length})`,
            `Receiving ${url}`, `${formatBytes(received)}${total ? " / " + formatBytes(total) : ""}`);

        reportBytesLoaded(`Part ${number}`, received, total);

        if (performance.now() - lastLog >= 500) {
            log("debug", `${url}: ${formatBytes(received)} received`);
            lastLog = performance.now();
        }
    }

    const bytes = new Uint8Array(received);
    let offset = 0;
    for (const chunk of chunks) {
        bytes.set(chunk, offset);
        offset += chunk.byteLength;
    }

    log("info", `${url} complete: ${formatBytes(received)} in ${
        ((performance.now() - started) / 1000).toFixed(3)}s`);
    return bytes;
}

async function loadArchive() {
    log("info", "RSDKv5U WebAssembly startup.");
    log("info", "Expected archive parts:", PART_FILES);

    const parts = [];
    for (let i = 0; i < PART_FILES.length; i++) {
        parts.push(await fetchPart(PART_FILES[i], i));
    }

    progress(60, "Combining archive", "All archive parts downloaded. Combining bytes...");
    log("info", "All parts downloaded; assembling contiguous RSDK archive.");

    const total = parts.reduce((sum, part) => sum + part.byteLength, 0);
    const combined = new Uint8Array(total);
    let offset = 0;

    for (let i = 0; i < parts.length; i++) {
        combined.set(parts[i], offset);
        log("debug", `Assembled part ${i + 1}: offset=${offset}, size=${parts[i].byteLength}`);
        offset += parts[i].byteLength;
    }

    log("info", `Combined RSDK archive: ${formatBytes(total)} (${total} bytes)`);
    progress(68, "Archive ready", "RSDK archive assembled; preparing virtual filesystem.",
        formatBytes(total));

    const module = {
        canvas: document.getElementById("canvas"),
        print: text => log("info", "[Emscripten stdout]", text),
        printErr: text => log("warn", "[Emscripten stderr]", text),

        preRun: [],

        onRuntimeInitialized() {
            log("info", "Emscripten runtime initialized.");
            progress(90, "Runtime initialized",
                "WebAssembly runtime is initialized. The engine is starting.");
        },

        onAbort(reason) {
            log("error", "Emscripten aborted:", reason);
            progress(100, "Engine aborted", String(reason));
        },

        onExit(status) {
            log("warn", "Emscripten exited with status:", status);
        },

        setStatus(text) {
            log("debug", "Emscripten status:", text);
        },

        monitorRunDependencies(left) {
            log("debug", "Emscripten run dependencies remaining:", left);
        }
    };

    window.Module = module;

    module.preRun.push(() => {
        log("info", "Preparing Emscripten virtual filesystem.");
        log("info", "Creating /Data.rsdk and /Settings.ini.");

        FS_createDataFile("/", "Data.rsdk", combined, true, true);
        FS_createDataFile("/", "Settings.ini", new Uint8Array(), true, true);

        log("info", "Virtual filesystem setup complete.");
        progress(75, "Mounting archive", "RSDK archive is available to the engine.");
    });

    progress(78, "Loading engine", "Loading RSDKv5U JavaScript and WebAssembly files.");
    log("info", "Loading engine script: RSDKv5U.js");

    const script = document.createElement("script");
    script.src = "RSDKv5U.js";
    script.onload = () => log("info", "RSDKv5U.js downloaded and executed.");
    script.onerror = () => {
        log("error", "Could not load RSDKv5U.js.");
        progress(100, "Engine script failed", "Check that RSDKv5U.js exists beside index.html.");
    };

    document.body.appendChild(script);
}

loadArchive().catch(error => {
    log("error", "Startup failed:", error);
    progress(100, "Loading failed", error.message || String(error));
});
</script>
</body>
</html>
]=])