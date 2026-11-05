/**
 * DasboardReport — Apps Script backup Google Sheets.
 *
 * TEMPEL di Extensions → Apps Script spreadsheet "Backup DasboardReport"
 * (ID 1Y2heyVU5LCaSGrv_QXWZxNHa7X2gcov4RpHDYfBQWsg), lalu Deploy sebagai
 * Web App (Execute as: Me). JANGAN deploy dari file ini langsung dan
 * JANGAN buat spreadsheet baru — Sheet-nya sudah ada.
 *
 * Menerima POST JSON dari aplikasi (lihat docs/sheets-backup-schema.md):
 * { type: 'backup', profile, exportedAt, tabs: { Profil, Transaksi,
 *   Tagihan, 'Utang Piutang', 'Log Aktivitas' } }
 * Setiap tab ditulis ulang penuh (header + baris) dari payload.
 * Header baris 1 di Sheet sudah dibekukan; skrip menulis ulang header yang
 * sama agar isi tab selalu konsisten dengan skema.
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
      sheet.clearContents();
      const values = [cols];
      for (const row of rows) {
        values.push(cols.map((c) => row[c] === undefined || row[c] === null ? '' : row[c]));
      }
      sheet.getRange(1, 1, values.length, cols.length).setValues(values);
      sheet.getRange(1, 1, 1, cols.length).setFontWeight('bold');
      sheet.setFrozenRows(1);
      written[tabName] = rows.length;
    }
    return jsonOut({ ok: true, written: written, exportedAt: body.exportedAt || '' });
  } catch (err) {
    return jsonOut({ ok: false, error: String(err) });
  }
}

function jsonOut(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
