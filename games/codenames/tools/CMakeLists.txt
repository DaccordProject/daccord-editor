cmake_minimum_required(VERSION 3.10)
project(daccord_plugin_tools)

# The godot-sandbox compiler library lives in a sibling repo.
# GODOT_SANDBOX_DIR can be overridden at configure time.
if(NOT DEFINED GODOT_SANDBOX_DIR)
    set(GODOT_SANDBOX_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../godot-sandbox"
        CACHE PATH "Path to the godot-sandbox repository")
endif()

set(COMPILER_DIR "${GODOT_SANDBOX_DIR}/src/gdscript/compiler")

if(NOT EXISTS "${COMPILER_DIR}/compiler.h")
    message(FATAL_ERROR
        "Cannot find godot-sandbox compiler at ${COMPILER_DIR}.\n"
        "Set -DGODOT_SANDBOX_DIR=<path> or clone godot-sandbox as a sibling directory.")
endif()

# Build the compiler as a static library (same sources as upstream CMakeLists)
set(COMPILER_SOURCES
    ${COMPILER_DIR}/compiler_exception.cpp
    ${COMPILER_DIR}/token.cpp
    ${COMPILER_DIR}/lexer.cpp
    ${COMPILER_DIR}/parser.cpp
    ${COMPILER_DIR}/ir.cpp
    ${COMPILER_DIR}/ir_optimizer.cpp
    ${COMPILER_DIR}/codegen.cpp
    ${COMPILER_DIR}/riscv_codegen.cpp
    ${COMPILER_DIR}/register_allocator.cpp
    ${COMPILER_DIR}/elf_builder.cpp
    ${COMPILER_DIR}/compiler.cpp
    ${COMPILER_DIR}/ir_interpreter.cpp
)

add_library(gdscript_compiler STATIC ${COMPILER_SOURCES})
target_include_directories(gdscript_compiler PUBLIC ${COMPILER_DIR})
set_target_properties(gdscript_compiler PROPERTIES CXX_STANDARD 17)

# gdsc — GDScript-to-ELF compiler CLI
add_executable(gdsc gdsc.cpp)
target_link_libraries(gdsc gdscript_compiler)
set_target_properties(gdsc PROPERTIES CXX_STANDARD 17)
