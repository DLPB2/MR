list(JOIN LANGS "," QT_LANGS)

find_program(WINDEPLOYQT_EXECUTABLE "windeployqt" HINTS "${_qt_bin_dir}" REQUIRED)
execute_process(
    COMMAND "${WINDEPLOYQT_EXECUTABLE}" --translations ${QT_LANGS} "${_target_file_dir}"
    RESULT_VARIABLE ret
)

if(NOT ret EQUAL 0)
    message(FATAL_ERROR "${WINDEPLOYQT_EXECUTABLE} returned ${ret}")
endif()

# Core5Compat is a required module for the current ff7tk/Qt 6 stack.
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(CORE5COMPAT_DLL "${_qt_bin_dir}/Qt6Core5Compatd.dll")
else()
    set(CORE5COMPAT_DLL "${_qt_bin_dir}/Qt6Core5Compat.dll")
endif()

if(EXISTS "${CORE5COMPAT_DLL}")
    file(COPY "${CORE5COMPAT_DLL}" DESTINATION "${_target_file_dir}")
endif()
