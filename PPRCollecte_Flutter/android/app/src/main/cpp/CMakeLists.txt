cmake_minimum_required(VERSION 3.10.2)

project(argon2-arm C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

set(ARGON2_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/argon2)

add_library(
    argon2-arm
    SHARED
    ${ARGON2_ROOT}/src/blake2/blake2b.c
    ${ARGON2_ROOT}/src/argon2.c
    ${ARGON2_ROOT}/src/core.c
    ${ARGON2_ROOT}/src/encoding.c
    ${ARGON2_ROOT}/src/ref.c
    ${ARGON2_ROOT}/src/thread.c
)

target_include_directories(
    argon2-arm
    PRIVATE
    ${ARGON2_ROOT}
    ${ARGON2_ROOT}/src
    ${ARGON2_ROOT}/src/blake2
)
