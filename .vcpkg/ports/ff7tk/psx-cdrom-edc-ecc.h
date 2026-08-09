// SPDX-License-Identifier: LGPL-3.0-or-later
// CD-ROM EDC/ECC generation helpers used by the Makou Reactor ff7tk port.
#pragma once

#include <array>
#include <cstring>

namespace ff7tk_psx_cd {

constexpr int Mode1EdcOffset = 2064;
constexpr int Mode2Form1EdcOffset = 2072;
constexpr int Mode2Form2EdcOffset = 2348;
constexpr int EccPOffset = 2076;
constexpr int EccQOffset = 2248;

inline const std::array<quint32, 256> &edcTable()
{
    static const std::array<quint32, 256> table = []() {
        std::array<quint32, 256> result{};
        for (quint32 i = 0; i < 256; ++i) {
            quint32 value = i;
            for (int bit = 0; bit < 8; ++bit) {
                value = (value >> 1) ^ ((value & 1U) ? 0xD8018001U : 0U);
            }
            result[i] = value;
        }
        return result;
    }();
    return table;
}

inline quint32 computeEdc(const quint8 *data, qsizetype size)
{
    const auto &table = edcTable();
    quint32 edc = 0;
    for (qsizetype i = 0; i < size; ++i) {
        edc = (edc >> 8) ^ table[(edc ^ data[i]) & 0xffU];
    }
    return edc;
}

struct EccTables {
    std::array<quint8, 256> forward{};
    std::array<quint8, 256> backward{};

    EccTables()
    {
        for (int i = 0; i < 256; ++i) {
            const int doubled = (i << 1) ^ ((i & 0x80) ? 0x11d : 0);
            forward[i] = quint8(doubled);
            backward[i ^ doubled] = quint8(i);
        }
    }
};

inline const EccTables &eccTables()
{
    static const EccTables tables;
    return tables;
}

inline void computeEcc(const quint8 *source, quint32 majorCount, quint32 minorCount,
                       quint32 majorMultiplier, quint32 minorIncrement, quint8 *destination)
{
    const auto &tables = eccTables();
    const quint32 size = majorCount * minorCount;

    for (quint32 major = 0; major < majorCount; ++major) {
        quint32 index = (major >> 1) * majorMultiplier + (major & 1U);
        quint8 eccA = 0;
        quint8 eccB = 0;

        for (quint32 minor = 0; minor < minorCount; ++minor) {
            const quint8 value = source[index];
            index += minorIncrement;
            if (index >= size) {
                index -= size;
            }
            eccA ^= value;
            eccB ^= value;
            eccA = tables.forward[eccA];
        }

        eccA = tables.backward[tables.forward[eccA] ^ eccB];
        destination[major] = eccA;
        destination[major + majorCount] = eccA ^ eccB;
    }
}

inline void writeEdcLittleEndian(quint8 *destination, quint32 edc)
{
    destination[0] = quint8(edc);
    destination[1] = quint8(edc >> 8);
    destination[2] = quint8(edc >> 16);
    destination[3] = quint8(edc >> 24);
}

inline bool hasCdRomSync(const quint8 *sector)
{
    if (sector[0] != 0 || sector[11] != 0) {
        return false;
    }
    for (int i = 1; i < 11; ++i) {
        if (sector[i] != 0xff) {
            return false;
        }
    }
    return true;
}

inline bool updateSectorEdcEcc(QByteArray &sectorData, bool updateForm2Edc = true)
{
    if (sectorData.size() != SECTOR_SIZE) {
        return false;
    }

    auto *sector = reinterpret_cast<quint8 *>(sectorData.data());
    if (!hasCdRomSync(sector)) {
        // Audio or another non-data sector: preserve it exactly.
        return true;
    }

    const quint8 mode = sector[15];
    if (mode == 1) {
        const quint32 edc = computeEdc(sector, Mode1EdcOffset);
        writeEdcLittleEndian(sector + Mode1EdcOffset, edc);
        std::memset(sector + Mode1EdcOffset + 4, 0, 8);
        computeEcc(sector + 12, 86, 24, 2, 86, sector + EccPOffset);
        computeEcc(sector + 12, 52, 43, 86, 88, sector + EccQOffset);
        return true;
    }

    if (mode != 2) {
        return true;
    }

    // CD-ROM XA sectors repeat the four-byte subheader at bytes 16..23.
    // Plain Mode 2 sectors have no Form-1 EDC/ECC fields to regenerate here.
    if (std::memcmp(sector + 16, sector + 20, 4) != 0) {
        return true;
    }

    // Mode 2 Form 2: 2324 bytes of user data followed by a four-byte EDC.
    // There is no P/Q ECC. Relocating a raw sector changes only its MSF
    // address, which is outside the Form-2 EDC coverage.
    if ((sector[18] & 0x20U) != 0) {
        if (updateForm2Edc) {
            const quint32 edc = computeEdc(sector + 16, Mode2Form2EdcOffset - 16);
            writeEdcLittleEndian(sector + Mode2Form2EdcOffset, edc);
        }
        return true;
    }

    // Mode 2 Form 1: EDC covers the duplicated XA subheader and 2048 data
    // bytes (raw bytes 16..2071), followed by P and Q Reed-Solomon parity.
    const quint32 edc = computeEdc(sector + 16, Mode2Form1EdcOffset - 16);
    writeEdcLittleEndian(sector + Mode2Form1EdcOffset, edc);

    // For XA Form 1, bytes 12..15 are treated as zero while generating P/Q.
    quint8 header[4];
    std::memcpy(header, sector + 12, sizeof(header));
    std::memset(sector + 12, 0, sizeof(header));
    computeEcc(sector + 12, 86, 24, 2, 86, sector + EccPOffset);
    computeEcc(sector + 12, 52, 43, 86, 88, sector + EccQOffset);
    std::memcpy(sector + 12, header, sizeof(header));

    return true;
}

inline bool repairSector(IsoArchiveIO &io, quint32 num)
{
    const qint64 previousPos = io.pos();
    const qint64 sectorPos = qint64(num) * SECTOR_SIZE;

    if (!io.seek(sectorPos)) {
        return false;
    }

    QByteArray sectorData = io.read(SECTOR_SIZE);
    bool ok = sectorData.size() == SECTOR_SIZE && updateSectorEdcEcc(sectorData);

    if (ok) {
        ok = io.seek(sectorPos) && io.write(sectorData) == SECTOR_SIZE;
    }

    if (!io.seek(previousPos)) {
        ok = false;
    }
    return ok;
}

inline bool writeRepairedSector(IsoArchiveIO &io, QByteArray sectorData)
{
    if (sectorData.size() != SECTOR_SIZE || io.pos() % SECTOR_SIZE != 0) {
        return false;
    }

    auto *sector = reinterpret_cast<quint8 *>(sectorData.data());
    if (hasCdRomSync(sector) && (sector[15] == 1 || sector[15] == 2)) {
        const QByteArray address = IsoArchiveIO::int2Header(io.currentSector());
        std::memcpy(sector + 12, address.constData(), 3);

        // Form-2 EDC does not cover the MSF address, so when merely moving an
        // existing raw Form-2 sector preserve its original EDC and payload.
        if (!updateSectorEdcEcc(sectorData, false)) {
            return false;
        }
    }

    return io.write(sectorData) == SECTOR_SIZE;
}

} // namespace ff7tk_psx_cd
