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

/*
    ============================
    RSDK CONFIGURATION
    ============================
*/

/*
    Set this to true if the RSDK archive
    is split into multiple files.

    false:
        game/game.rsdk

    true:
        game/game.rsdk
        game/game.rsdk.part1
        game/game.rsdk.part2
        etc.
*/

const IS_PART_FILE = false;


/*
    ============================
    NORMAL RSDK
    ============================
*/

/*
    Used when IS_PART_FILE is false.
*/

const NORMAL_RSDK_FILE = \"game/game.rsdk\";


/*
    ============================
    SPLIT RSDK
    ============================
*/

/*
    Used when IS_PART_FILE is true.
*/

const PART_RSDK_FILE = \"game/game.rsdk\";

/*
    Number of additional .part files.

    Example:

        game.rsdk
        game.rsdk.part1
        game.rsdk.part2
        game.rsdk.part3

    PART_COUNT = 3
*/

const PART_COUNT = 3;


/*
    ============================
    RSDK LOADER
    ============================
*/

async function loadNormalRSDK() {

    console.log(
        \"Loading RSDK:\",
        NORMAL_RSDK_FILE
    );

    const response = await fetch(
        NORMAL_RSDK_FILE
    );

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
            \"game.rsdk\",
            data,
            true,
            true
        );

    });

}


async function loadSplitRSDK() {

    console.log(
        \"Loading split RSDK:\",
        PART_RSDK_FILE
    );

    const files = [];

    /*
        The base RSDK file is always loaded first.
    */

    files.push(
        PART_RSDK_FILE
    );

    /*
        Then load:

        .part1
        .part2
        .part3
        etc.
    */

    for (
        let i = 1;
        i <= PART_COUNT;
        i++
    ) {

        files.push(
            PART_RSDK_FILE +
            \".part\" +
            i
        );

    }

    console.log(
        \"RSDK files:\",
        files
    );


    /*
        Fetch every part.
    */

    const responses =
        await Promise.all(
            files.map(
                file => fetch(file)
            )
        );


    /*
        Make sure every part exists.
    */

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


    /*
        Convert every part into bytes.
    */

    const buffers =
        await Promise.all(
            responses.map(
                response =>
                    response.arrayBuffer()
            )
        );


    /*
        Calculate the total size.
    */

    let totalSize = 0;

    for (
        const buffer of buffers
    ) {

        totalSize +=
            buffer.byteLength;

    }


    /*
        Create one large buffer.
    */

    const combined =
        new Uint8Array(
            totalSize
        );


    /*
        Append every part in order.
    */

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


    /*
        Put the combined archive
        into Emscripten's virtual filesystem.
    */

    Module.preRun =
        Module.preRun || [];

    Module.preRun.push(function() {

        FS_createDataFile(
            \"/\",
            \"game.rsdk\",
            combined,
            true,
            true
        );

    });

}


/*
    ============================
    Emscripten Module
    ============================
*/

var Module = {

    canvas:
        document.getElementById(
            \"canvas\"
        ),

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


/*
    ============================
    SELECT RSDK MODE
    ============================
*/

async function prepareGame() {

    if (IS_PART_FILE) {

        await loadSplitRSDK();

    }
    else {

        await loadNormalRSDK();

    }

}


/*
    ============================
    START
    ============================
*/

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

<script src=\"RSDKv5U.js\"></script>

</body>

</html>
"
)