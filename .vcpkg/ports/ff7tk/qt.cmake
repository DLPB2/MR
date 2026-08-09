###############################################################################
## Copyright (C) 2009-2024 Arzel Jérôme <myst6re@gmail.com>
## Copyright (C) 2023 Julian Xhokaxhiu <https://julianxhokaxhiu.com>
##
## This program is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
###############################################################################

if(NOT WIN32)
    message(FATAL_ERROR "Qt auto-detection is configured for Windows x64 only.")
endif()

if(NOT DEFINED QT_VERSION_TO_FIND)
    set(QT_VERSION_TO_FIND 6)
endif()
if(NOT QT_VERSION_TO_FIND EQUAL 6)
    message(FATAL_ERROR "Makou Reactor requires Qt 6.")
endif()

find_package(QT NAMES Qt6 QUIET)

if(NOT QT_FOUND)
    find_program(QT_QMAKE_EXECUTABLE "qmake")

    if(QT_QMAKE_EXECUTABLE)
        get_filename_component(QT_PATH "${QT_QMAKE_EXECUTABLE}" DIRECTORY)
        get_filename_component(QT_PATH "${QT_PATH}" DIRECTORY)
        message(STATUS "Found qmake in PATH: ${QT_QMAKE_EXECUTABLE}")
    else()
        if(NOT QT_INSTALLATION_PATH)
            cmake_host_system_information(
                RESULT QT_INSTALLATION_PATH
                QUERY WINDOWS_REGISTRY
                    "HKEY_CURRENT_USER/Software/Microsoft/Windows/CurrentVersion/Uninstall/{1f0b01f1-fb8c-49bb-8410-ef0628043911}"
                VALUE "InstallLocation"
            )
        endif()

        if(NOT QT_INSTALLATION_PATH)
            message(FATAL_ERROR "Set QT_INSTALLATION_PATH or Qt6_DIR to a Qt 6 MSVC x64 installation.")
        endif()

        file(GLOB QT_VERSIONS "${QT_INSTALLATION_PATH}/6.*")
        list(SORT QT_VERSIONS COMPARE NATURAL ORDER DESCENDING)
        if(NOT QT_VERSIONS)
            message(FATAL_ERROR "No Qt 6 installation found under ${QT_INSTALLATION_PATH}.")
        endif()
        list(GET QT_VERSIONS 0 QT_VERSION)

        file(GLOB QT_COMPILERS "${QT_VERSION}/msvc*_64")
        list(SORT QT_COMPILERS COMPARE NATURAL ORDER DESCENDING)
        if(NOT QT_COMPILERS)
            message(FATAL_ERROR "No Qt 6 MSVC x64 kit found under ${QT_VERSION}.")
        endif()
        list(GET QT_COMPILERS 0 QT_PATH)
        set(QT_QMAKE_EXECUTABLE "${QT_PATH}/bin/qmake.exe")
    endif()

    set(Qt6_DIR "${QT_PATH}/lib/cmake/Qt6")
    set(QT_DIR "${Qt6_DIR}")
    find_package(QT NAMES Qt6 REQUIRED)
endif()

if(NOT DEFINED QT_QMAKE_EXECUTABLE OR NOT EXISTS "${QT_QMAKE_EXECUTABLE}")
    find_package(Qt6 COMPONENTS Core REQUIRED)
    get_target_property(QT_QMAKE_EXECUTABLE Qt6::qmake IMPORTED_LOCATION)
endif()

get_filename_component(_qt_bin_dir "${QT_QMAKE_EXECUTABLE}" DIRECTORY)
get_filename_component(QT_PATH "${_qt_bin_dir}" DIRECTORY)
list(APPEND CMAKE_PREFIX_PATH "${QT_PATH}")
set(QT_PATH "${QT_PATH}" CACHE PATH "Path to the Qt 6 Windows x64 kit")

message(STATUS "QT_QMAKE_EXECUTABLE: ${QT_QMAKE_EXECUTABLE}")
message(STATUS "Qt Windows x64 path: ${QT_PATH}")
