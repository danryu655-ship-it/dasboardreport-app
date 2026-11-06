/**
 * DasboardReport — Apps Script backup Google Sheets (ARSIP).
 *
 * TEMPEL di Extensions → Apps Script spreadsheet "Backup DasboardReport"
 * (ID 1Y2heyVU5LCaSGrv_QXWZxNHa7X2gcov4RpHDYfBQWsg), lalu Deploy sebagai
 * Web App (Execute as: Me). JANGAN deploy dari file ini langsung dan
 * JANGAN buat spreadsheet baru — Sheet-nya sudah ada.
 *
 * Menerima POST JSON dari aplikasi (lihat docs/sheets-backup-schema.md):
 * { type: 'backup', profile, exportedAt, tabs: { Profil, Transaksi,
 *   Tagihan, 'Utang Piutang', 'Log Aktivitas' } }
 *
 * ARSIP (sejak 2026-11-06): skrip TIDAK PERNAH menghapus baris.
 * Per tab: baris lama dipertahankan; baris yang kuncinya ada di payload
 * diperbarui di tempat; baris baru ditambahkan di akhir. Catatan yang
 * sudah dihapus di aplikasi TETAP tersimpan di Sheet sebagai arsip.
 * Kunci pencocokan: 'nama' untuk Profil (id Profil hanya nomor urut yang
 * bisa dipakai ulang), 'id' untuk tab lain.
 * Header baris 1 ditulis ulang (isinya sama dengan skema) dan tetap
 * dibekukan; baris data di bawahnya tidak pernah dihapus.
 */

const TAB_COLUMNS = {
  Profil: ['id', 'nama', 'dibuat_pada'],
  Transaksi: ['id', 'profil', 'tanggal', 'jenis', 'kategori', 'jumlah_rp',
    'keterangan', 'dibuat_pada'],
  Tagihan: ['id', 'profil', 'nama', 'jumlah_rp', 'jatuh_tempo', 'status',
    'dibayar_pada'],
  'Utang Piutang': ['id', 'profil', 'jenis', 'pihak', 'jumlah_total_rp',
    'sisa_rp', 'cicilan_rp', 'status'],
  'Log Aktivitas': ['id', 'profil', 'waktu', 'aksi', 'detail'],
};

/** Kolom kunci tiap tab (lihat penjelasan di atas). */
const KEY_COLUMN = {
  Profil: 'nama',
  Transaksi: 'id',
  Tagihan: 'id',
  'Utang Piutang': 'id',
  'Log Aktivitas': 'id',
};

function doPost(e) {
  try {
    const body = JSON.parse(e.postData.contents);
    if (body.type !== 'backup' || !body.tabs) {
      return jsonOut({ ok: false, error: 'payload bukan backup' });
    }
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const written = {};
    for (const tabName of Object.keys(TAB_COLUMNS)) {
      const rows = body.tabs[tabName] || [];
      const cols = TAB_COLUMNS[tabName];
      let sheet = ss.getSheetByName(tabName);
      if (!sheet) sheet = ss.insertSheet(tabName);
      written[tabName] = mergeTab(sheet, cols, rows);
    }
    return jsonOut({ ok: true, written: written, exportedAt: body.exportedAt || '' });
  } catch (err) {
    return jsonOut({ ok: false, error: String(err) });
  }
}

/**
 * Gabungkan baris payload ke dalam tab TANPA menghapus baris lama.
 * Mengembalikan { kept, updated, added }:
 * - kept: baris lama yang dipertahankan (termasuk yang diperbarui),
 * - updated: baris lama yang nilainya diganti dari payload,
 * - added: baris baru yang ditambahkan di akhir.
 * Algoritma ini dicerminkan di aplikasi (SheetsBackup.mergeArchiveRows,
 * lib/sync/sheets_backup.dart) dan diuji di test/sync_delete_test.dart.
 */
function mergeTab(sheet, cols, rows) {
  const keyCol = KEY_COLUMN[sheet.getName()] || 'id';
  const keyIdx = cols.indexOf(keyCol);
  const lastRow = sheet.getLastRow();
  const existing = lastRow > 1
    ? sheet.getRange(2, 1, lastRow - 1, cols.length).getValues()
    : [];
  const indexByKey = new Map();
  existing.forEach(function (r, i) {
    indexByKey.set(String(r[keyIdx]), i);
  });
  let updated = 0;
  let added = 0;
  for (const row of rows) {
    const values = cols.map(function (c) {
      return row[c] === undefined || row[c] === null ? '' : row[c];
    });
    const key = String(values[keyIdx]);
    if (indexByKey.has(key)) {
      existing[indexByKey.get(key)] = values;
      updated++;
    } else {
      indexByKey.set(key, existing.length);
      existing.push(values);
      added++;
    }
  }
  // Tulis header + seluruh baris (lama dipertahankan, tidak ada yang dihapus).
  const all = [cols].concat(existing);
  sheet.getRange(1, 1, all.length, cols.length).setValues(all);
  sheet.getRange(1, 1, 1, cols.length).setFontWeight('bold');
  sheet.setFrozenRows(1);
  return { kept: existing.length - added, updated: updated, added: added };
}

function jsonOut(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
