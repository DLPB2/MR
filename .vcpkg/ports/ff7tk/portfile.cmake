if(NOT VCPKG_TARGET_IS_WINDOWS OR NOT VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
  message(FATAL_ERROR "The Makou Reactor ff7tk port supports Windows x64 only.")
endif()

set(VCPKG_C_FLAGS "-bigobj ${VCPKG_C_FLAGS}")
set(VCPKG_CXX_FLAGS "-bigobj ${VCPKG_CXX_FLAGS}")

vcpkg_from_github(
  OUT_SOURCE_PATH SOURCE_PATH
  REPO sithlord48/ff7tk
  REF v1.3.1
  SHA512 4800bfaa50d5dc471b703b2c09f45da3478ba7dbc78625d55214069d3ec7acc898663934a0c5195e2170a98dfd3c32299198eee1e675936301cc72a528e289ed
  HEAD_REF master
)

# Keep the upstream archive pristine and perform deterministic source edits
# here. This avoids git-apply/line-ending issues on Windows runners.
set(_iso_cpp "${SOURCE_PATH}/src/formats/IsoArchive.cpp")
file(COPY "${CMAKE_CURRENT_LIST_DIR}/psx-cdrom-edc-ecc.h"
     DESTINATION "${SOURCE_PATH}/src/formats")

vcpkg_replace_string("${_iso_cpp}"
[=[#include <QtEndian>
]=]
[=[#include <QtEndian>
#include "psx-cdrom-edc-ecc.h"
]=])

vcpkg_replace_string("${_iso_cpp}"
[=[qint64 IsoArchiveIO::writeIso(const char *data, qint64 maxSize)
{
    qint64 write, writeTotal = 0, seqLen;

    if (!seekIso(isoPos(pos()))) {
        return 0;
    }

    seqLen = std::min(SECTOR_SIZE_HEADER + SECTOR_SIZE_DATA - (pos() % SECTOR_SIZE), maxSize);
    while ((write = this->write(data, seqLen)) > 0) {
        data += write;
        maxSize -= write;
        writeTotal += write;
        seqLen = std::min(qint64(2048), maxSize);
        // If we are at the end of the sector
        if (pos() % SECTOR_SIZE >= SECTOR_SIZE_HEADER + SECTOR_SIZE_DATA
                && !seek(pos() + SECTOR_SIZE_HEADER + SECTOR_SIZE_FOOTER)) {
            break;
        }
    }

    return write < 0 ? write : writeTotal;
}
]=]
[=[qint64 IsoArchiveIO::writeIso(const char *data, qint64 maxSize)
{
    qint64 write = 0, writeTotal = 0, seqLen;

    if (!seekIso(isoPos(pos()))) {
        return 0;
    }

    const qint64 startIsoPos = posIso();

    seqLen = std::min(SECTOR_SIZE_HEADER + SECTOR_SIZE_DATA - (pos() % SECTOR_SIZE), maxSize);
    while ((write = this->write(data, seqLen)) > 0) {
        data += write;
        maxSize -= write;
        writeTotal += write;
        seqLen = std::min(qint64(SECTOR_SIZE_DATA), maxSize);
        // If we are at the end of the sector
        if (pos() % SECTOR_SIZE >= SECTOR_SIZE_HEADER + SECTOR_SIZE_DATA
                && !seek(pos() + SECTOR_SIZE_HEADER + SECTOR_SIZE_FOOTER)) {
            break;
        }
    }

    if (writeTotal > 0) {
        const quint32 firstSector = quint32(startIsoPos / SECTOR_SIZE_DATA);
        const quint32 lastSector = quint32((startIsoPos + writeTotal - 1) / SECTOR_SIZE_DATA);
        for (quint32 sector = firstSector; sector <= lastSector; ++sector) {
            if (!ff7tk_psx_cd::repairSector(*this, sector)) {
                return -1;
            }
        }
    }

    return write < 0 ? write : writeTotal;
}
]=])

vcpkg_replace_string("${_iso_cpp}"
[=[bool IsoArchiveIO::writeSector(const QByteArray &data, quint8 type, quint8 mode)
{
    qint64 dataSize = data.size();
    quint32 sectorCur = currentSector();
    QByteArray sectorData;

    Q_ASSERT(pos() % SECTOR_SIZE == 0);
    Q_ASSERT(dataSize <= SECTOR_SIZE_DATA);
    // sector header
    sectorData = buildHeader(sectorCur, type, mode);
    // data
    sectorData.append(data);
    if (dataSize != SECTOR_SIZE_DATA) {
        sectorData.append(QByteArray(SECTOR_SIZE_DATA - dataSize, '\x00'));
    }
    // sector footer
    sectorData.append(buildFooter(sectorCur));

    return SECTOR_SIZE == write(sectorData);
}
]=]
[=[bool IsoArchiveIO::writeSector(const QByteArray &data, quint8 type, quint8 mode)
{
    qint64 dataSize = data.size();
    quint32 sectorCur = currentSector();
    QByteArray sectorData;

    Q_ASSERT(pos() % SECTOR_SIZE == 0);
    Q_ASSERT(dataSize <= SECTOR_SIZE_DATA);
    if (mode != 2 || dataSize > SECTOR_SIZE_DATA || pos() % SECTOR_SIZE != 0) {
        return false;
    }

    // sector header
    sectorData = buildHeader(sectorCur, type, mode);
    // data
    sectorData.append(data);
    if (dataSize != SECTOR_SIZE_DATA) {
        sectorData.append(QByteArray(SECTOR_SIZE_DATA - dataSize, '\x00'));
    }
    // Reserve the complete raw-sector footer, then populate its EDC/ECC.
    sectorData.append(QByteArray(SECTOR_SIZE_FOOTER, '\x00'));
    if (!ff7tk_psx_cd::updateSectorEdcEcc(sectorData)) {
        return false;
    }

    return SECTOR_SIZE == write(sectorData);
}
]=])

vcpkg_replace_string("${_iso_cpp}"
[=[        destinationIO->seekIso(SECTOR_SIZE_DATA * 16 + 80);// sector 16 : pos 80 size 4+4
        quint32 volume_space_size = quint32(destinationIO->size() / SECTOR_SIZE), volume_space_size2 = qToBigEndian(volume_space_size);
        destinationIO->write((char*)&volume_space_size, 4);
        destinationIO->write((char*)&volume_space_size2, 4);
]=]
[=[        if (!destinationIO->seekIso(SECTOR_SIZE_DATA * 16 + 80)) {// sector 16 : pos 80 size 4+4
            setError(Archive::WriteError, destinationIO->errorString());
            return false;
        }
        quint32 volume_space_size = quint32(destinationIO->size() / SECTOR_SIZE), volume_space_size2 = qToBigEndian(volume_space_size);
        if (destinationIO->writeIso((char*)&volume_space_size, 4) != 4
                || destinationIO->writeIso((char*)&volume_space_size2, 4) != 4) {
            setError(Archive::WriteError, destinationIO->errorString());
            return false;
        }
]=])

vcpkg_replace_string("${_iso_cpp}"
[=[        } else {
            quint8 type, mode;
            IsoArchiveIO::headerInfos(data, &type, &mode);
            if (!out->writeSector(data.mid(SECTOR_SIZE_HEADER, SECTOR_SIZE_DATA), type, mode)) {
                qWarning() << "IsoArchive::copySectors writeSector error";
                setError(Archive::WriteError, out->errorString());
                return false;
            }
        }
]=]
[=[        } else {
            if (!ff7tk_psx_cd::writeRepairedSector(*out, data)) {
                qWarning() << "IsoArchive::copySectors writeRepairedSector error";
                setError(Archive::WriteError, out->errorString());
                return false;
            }
        }
]=])

# Fail early if the fixed v1.3.1 source ever stops matching the substitutions.
file(READ "${_iso_cpp}" _iso_after)
foreach(_marker
    "#include \"psx-cdrom-edc-ecc.h\""
    "const qint64 startIsoPos = posIso();"
    "ff7tk_psx_cd::updateSectorEdcEcc(sectorData)"
    "ff7tk_psx_cd::writeRepairedSector(*out, data)"
    "destinationIO->writeIso((char*)&volume_space_size, 4)")
  string(FIND "${_iso_after}" "${_marker}" _marker_pos)
  if(_marker_pos EQUAL -1)
    message(FATAL_ERROR "Failed to apply ff7tk PSX CD-ROM fix; missing marker: ${_marker}")
  endif()
endforeach()

vcpkg_cmake_configure(
  SOURCE_PATH ${SOURCE_PATH}
  OPTIONS
    "-DPACKAGE=OFF"
    "-DTESTS=OFF"
    "-DCMAKE_PROJECT_INCLUDE=${CMAKE_CURRENT_LIST_DIR}/qt.cmake"
)

vcpkg_cmake_install()
vcpkg_copy_pdbs()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/${PORT})
vcpkg_fixup_pkgconfig()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include" "${CURRENT_PACKAGES_DIR}/debug/lib/cmake" "${CURRENT_PACKAGES_DIR}/lib/cmake" "${CURRENT_PACKAGES_DIR}/debug/share" "${CURRENT_PACKAGES_DIR}/share/licenses")
file(INSTALL ${SOURCE_PATH}/COPYING.TXT DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT} RENAME copyright)
