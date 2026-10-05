cmake_minimum_required(VERSION 3.20)

project(RetroEngine)

if(NOT EMSCRIPTEN)
    message(FATAL_ERROR
        "This CMake configuration is for WebAssembly/Emscripten. Configure with emcmake."
    )
endif()

set(RETRO_SUBSYSTEM "SDL2" CACHE STRING "The subsystem to use")

set(DEP_PATH all)

message(NOTICE "Configuring RetroEngine for WebAssembly")

add_executable(
    RetroEngine
    ${RETRO_FILES}
)

# ============================
# SDL2
# ============================

target_compile_options(
    RetroEngine
    PRIVATE
    -sUSE_SDL=2
)

# ============================
# OGG
# ============================

find_package(Ogg CONFIG)

if(NOT Ogg_FOUND)

    message(NOTICE
        "libogg not found, attempting to build from source"
    )

    set(COMPILE_OGG TRUE)

else()

    message(NOTICE "found libogg")

    add_library(
        libogg
        ALIAS
        Ogg::ogg
    )

    target_link_libraries(
        RetroEngine
        PRIVATE
        libogg
    )

endif()

# ============================
# THEORA
# ============================

find_package(unofficial-theora CONFIG)

if(unofficial-theora_FOUND)

    message(NOTICE "found libtheora")

    add_library(
        libtheora
        ALIAS
        unofficial::theora::theora
    )

    target_link_libraries(
        RetroEngine
        PRIVATE
        libtheora
    )

else()

    message(NOTICE
        "could not find unofficial-theora, attempting to find Theora"
    )

    find_package(Theora CONFIG)

    if(Theora_FOUND)

        message(NOTICE "found libtheora")

        add_library(
            libtheora
            ALIAS
            Theora::theora
        )

        target_link_libraries(
            RetroEngine
            PRIVATE
            libtheora
        )

    else()

        message(NOTICE
            "libtheora not found, attempting to build from source"
        )

        set(COMPILE_THEORA TRUE)

    endif()

endif()

# ============================
# WEBASSEMBLY
# ============================

target_compile_definitions(
    RetroEngine
    PRIVATE
    _CRT_SECURE_NO_WARNINGS
)

target_compile_options(
    RetroEngine
    PRIVATE
    -Wno-microsoft-cast
    -Wno-microsoft-exception-spec
    -sUSE_SDL=2
)

target_link_options(
    RetroEngine
    PRIVATE
    -sUSE_SDL=2
    -sWASM=1
    -sNO_EXIT_RUNTIME=1
    -sASSERTIONS=1
    -sUSE_WEBGL2=1
    -sMIN_WEBGL_VERSION=2
    -sALLOW_MEMORY_GROWTH=1
    -sPTHREAD_POOL_SIZE=0
    -sEXPORTED_RUNTIME_METHODS=["ccall","cwrap"]
    -sFORCE_FILESYSTEM=1
    -sASYNCIFY=1
)

# ============================
# MINIAUDIO
# ============================

if(USE_MINIAUDIO)

    target_compile_definitions(
        RetroEngine
        PRIVATE
        RETRO_AUDIODEVICE_MINI=1
    )

endif()

# ============================
# WEBASSEMBLY WEBSITE
# ============================

set(WEB_OUTPUT_DIR
    ${CMAKE_BINARY_DIR}/website
)

set(WEB_GAME_DIR
    ${WEB_OUTPUT_DIR}/game
)

add_custom_command(
    TARGET RetroEngine
    POST_BUILD

    COMMAND
        ${CMAKE_COMMAND} -E make_directory
        ${WEB_OUTPUT_DIR}

    COMMAND
        ${CMAKE_COMMAND} -E make_directory
        ${WEB_GAME_DIR}

    COMMAND
        ${CMAKE_COMMAND} -E copy_if_different
        $<TARGET_FILE:RetroEngine>
        ${WEB_OUTPUT_DIR}/RSDKv5U.js

    COMMAND
        ${CMAKE_COMMAND} -E copy_if_different
        ${CMAKE_CURRENT_BINARY_DIR}/RSDKv5U.wasm
        ${WEB_OUTPUT_DIR}/RSDKv5U.wasm

    COMMAND
        ${CMAKE_COMMAND} -E touch
        ${WEB_OUTPUT_DIR}/Settings.ini
)

# ============================
# HTML
# ============================

file(
    WRITE
    ${WEB_OUTPUT_DIR}/index.html

"<!DOCTYPE html>
<html lang=\"en\">

<head>

    <meta charset=\"UTF-8\">

    <meta
        name=\"viewport\"
        content=\"width=device-width, initial-scale=1.0\"
    >

    <title>RSDKv5U Web</title>

    <style>

        html,
        body {
            width: 100%;
            height: 100%;
            margin: 0;
            padding: 0;
            background: #000;
            overflow: hidden;
        }

        body {
            display: flex;
            align-items: center;
            justify-content: center;
        }

        canvas {
            width: 100vw;
            height: 100vh;
            display: block;
            background: #000;
            image-rendering: pixelated;
        }

    </style>

</head>

<body>

<canvas id=\"canvas\"></canvas>

<script>

const IS_PART_FILE = true;

const NORMAL_RSDK_FILE = \"game/Data.rsdk\";

const PART_RSDK_FILE = \"game/Data.rsdk.part\";

const PART_COUNT = 3;


var Module = {

    canvas:
        document.getElementById(\"canvas\"),

    print: function(text) {
        console.log(text);
    },

    printErr: function(text) {
        console.error(text);
    },

    onRuntimeInitialized:
        function() {

            console.log(
                \"RSDKv5U WebAssembly initialized.\"
            );

        }

};


async function loadNormalRSDK() {

    console.log(
        \"Loading RSDK:\",
        NORMAL_RSDK_FILE
    );

    const response =
        await fetch(NORMAL_RSDK_FILE);

    if (!response.ok) {

        throw new Error(
            \"Failed to load RSDK file: \" +
            NORMAL_RSDK_FILE
        );

    }

    const data =
        new Uint8Array(
            await response.arrayBuffer()
        );

    console.log(
        \"RSDK size:\",
        data.byteLength,
        \"bytes\"
    );

    Module.preRun =
        Module.preRun || [];

    Module.preRun.push(function() {

        FS_createDataFile(
            \"/\",
            \"Data.rsdk\",
            data,
            true,
            true
        );

        FS_createDataFile(
            \"/\",
            \"Settings.ini\",
            new Uint8Array(),
            true,
            true
        );

    });

}


async function loadSplitRSDK() {

    const files = [];

    for (
        let i = 1;
        i <= PART_COUNT;
        i++
    ) {

        files.push(
            PART_RSDK_FILE + i
        );

    }

    console.log(
        \"Loading RSDK parts:\",
        files
    );


    const responses =
        await Promise.all(
            files.map(
                file => fetch(file)
            )
        );


    for (
        let i = 0;
        i < responses.length;
        i++
    ) {

        if (!responses[i].ok) {

            throw new Error(
                \"Failed to load RSDK part: \" +
                files[i]
            );

        }

    }


    const buffers =
        await Promise.all(
            responses.map(
                response =>
                    response.arrayBuffer()
            )
        );


    let totalSize = 0;

    for (
        const buffer of buffers
    ) {

        totalSize +=
            buffer.byteLength;

    }


    const combined =
        new Uint8Array(
            totalSize
        );


    let offset = 0;

    for (
        const buffer of buffers
    ) {

        combined.set(
            new Uint8Array(buffer),
            offset
        );

        offset +=
            buffer.byteLength;

    }


    console.log(
        \"Combined RSDK size:\",
        combined.byteLength,
        \"bytes\"
    );


    Module.preRun =
        Module.preRun || [];

    Module.preRun.push(function() {

        FS_createDataFile(
            \"/\",
            \"Data.rsdk\",
            combined,
            true,
            true
        );

        FS_createDataFile(
            \"/\",
            \"Settings.ini\",
            new Uint8Array(),
            true,
            true
        );

    });

}


async function prepareGame() {

    if (IS_PART_FILE) {

        await loadSplitRSDK();

    }
    else {

        await loadNormalRSDK();

    }


    console.log(
        \"RSDK archive ready.\"
    );


    const script =
        document.createElement(\"script\");

    script.src = \"RSDKv5U.js\";

    document.body.appendChild(script);

}


prepareGame()
    .catch(function(error) {

        console.error(error);

        document.body.innerHTML =
            '<pre style=\"' +
            'color:white;' +
            'font-family:monospace;' +
            'padding:20px;' +
            'white-space:pre-wrap;' +
            '\">' +
            'Failed to load game.\\n\\n' +
            error.message +
            '</pre>';

    });

</script>

</body>

</html>
"
)