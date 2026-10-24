const PDFDocument = require("pdfkit");

const MARGIN = 36;
const CELL_PAD = 4;
const MAX_CELL_CHARS = 400;
const FONT_SIZE = 8;

// Standard PDF fonts only cover Latin-1; anything else is replaced so the document still renders.
function sanitize(value) {
  let text;
  if (value === null || value === undefined) text = "";
  else if (value instanceof Date) text = value.toISOString();
  else if (typeof value === "object") text = JSON.stringify(value);
  else text = String(value);
  text = text.replace(/[^\t\n\r\x20-\x7E\u00A0-\u00FF]/g, "?");
  if (text.length > MAX_CELL_CHARS) text = `${text.slice(0, MAX_CELL_CHARS)}...`;
  return text;
}

/**
 * Builds an audit report PDF.
 * @param {{ title: string, cover: Array<[string, any] | []>, columns: string[], rows: any[][] }} report
 * @returns {Promise<Buffer>}
 */
function buildReportPdf({ title, cover, columns, rows }) {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({
      size: "A4",
      layout: "landscape",
      margin: MARGIN,
      bufferPages: true,
      info: { Title: title, Author: "iDetect" },
    });
    const chunks = [];
    doc.on("data", (c) => chunks.push(c));
    doc.on("end", () => resolve(Buffer.concat(chunks)));
    doc.on("error", reject);

    const usableWidth = doc.page.width - MARGIN * 2;
    const bottomLimit = () => doc.page.height - MARGIN - 16;

    doc.font("Helvetica-Bold").fontSize(14).fillColor("#0f172a").text(title, MARGIN, MARGIN);
    doc.moveDown(0.5);

    doc.font("Helvetica").fontSize(9).fillColor("#334155");
    for (const entry of cover) {
      if (!entry || entry.length === 0) continue;
      const [label, value] = entry;
      doc.font("Helvetica-Bold").text(`${label}: `, { continued: true });
      doc.font("Helvetica").text(sanitize(value));
    }
    doc.moveDown(1);

    const colCount = Math.max(columns.length, 1);
    const colWidth = usableWidth / colCount;
    const fontSize = colCount > 8 ? 7 : FONT_SIZE;
    const textWidth = colWidth - CELL_PAD * 2;

    const drawRow = (cells, { header = false } = {}) => {
      doc.font(header ? "Helvetica-Bold" : "Helvetica").fontSize(fontSize);
      const texts = cells.map(sanitize);
      const heights = texts.map((t) => doc.heightOfString(t, { width: textWidth }));
      const rowHeight = Math.max(fontSize, ...heights) + CELL_PAD * 2;

      if (doc.y + rowHeight > bottomLimit()) {
        doc.addPage();
        drawHeader();
      }

      const y = doc.y;
      if (header) {
        doc.save().rect(MARGIN, y, usableWidth, rowHeight).fill("#f1f5f9").restore();
      }
      doc.fillColor(header ? "#0f172a" : "#334155");
      texts.forEach((t, i) => {
        doc.text(t, MARGIN + i * colWidth + CELL_PAD, y + CELL_PAD, { width: textWidth });
      });
      doc.save()
        .moveTo(MARGIN, y + rowHeight)
        .lineTo(MARGIN + usableWidth, y + rowHeight)
        .lineWidth(0.4)
        .strokeColor("#cbd5e1")
        .stroke()
        .restore();
      doc.y = y + rowHeight;
      doc.x = MARGIN;
    };

    const drawHeader = () => drawRow(columns, { header: true });

    drawHeader();
    if (rows.length === 0) {
      doc.font("Helvetica").fontSize(fontSize).fillColor("#64748b").text("No records for this period.", MARGIN, doc.y + 6);
    }
    for (const row of rows) drawRow(row);

    // Footers are added after all pages exist, so the page count is known.
    const range = doc.bufferedPageRange();
    for (let i = range.start; i < range.start + range.count; i++) {
      doc.switchToPage(i);
      // The footer sits inside the bottom margin; without this PDFKit adds a blank page per footer.
      doc.page.margins.bottom = 0;
      doc
        .font("Helvetica")
        .fontSize(7)
        .fillColor("#64748b")
        .text(
          `iDetect audit report - Page ${i + 1} of ${range.count}`,
          MARGIN,
          doc.page.height - MARGIN + 4,
          { width: usableWidth, align: "center", lineBreak: false },
        );
    }

    doc.end();
  });
}

module.exports = { buildReportPdf };
