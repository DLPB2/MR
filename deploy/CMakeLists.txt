# Windows x64 deployment only.
set(TRANSLATIONS_PATH translations)

install(FILES ${QM_FILES} DESTINATION "${TRANSLATIONS_PATH}")
install(FILES ${ff7tk_QM_FILES} DESTINATION "${TRANSLATIONS_PATH}")

install(CODE "set(_target_file_dir \"${QT_DEPLOY_TMP_DIR}\")")
install(CODE "set(_qt_bin_dir \"${_qt_bin_dir}\")")
install(CODE "set(LANGS \"${LANGS}\")")
install(SCRIPT deployqt.cmake)
