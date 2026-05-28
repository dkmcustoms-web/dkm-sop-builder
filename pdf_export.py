"""
PDF-generatie voor een SOP, met DKM-branding.
Gebruikt fpdf2 + DejaVuSans (Unicode-compleet) zodat —, é, ', enz. correct
renderen. Valt terug op Helvetica als de fonts ontbreken.
"""

import os
import re
from datetime import date, datetime
from fpdf import FPDF

DKM_BLUE = (60, 206, 255)    # #3cceff
DKM_ORANGE = (243, 94, 64)   # #f35e40
DARK = (33, 37, 41)

FONT_DIR = os.path.join(os.path.dirname(__file__), "fonts")
_HAS_DEJAVU = os.path.exists(os.path.join(FONT_DIR, "DejaVuSans.ttf"))
FAM = "DejaVu" if _HAS_DEJAVU else "Helvetica"


def _md_inline_to_plain(text: str) -> str:
    text = re.sub(r"\*\*(.+?)\*\*", r"\1", text)   # **bold**
    text = re.sub(r"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)", r"\1", text)  # *italic*
    return text


class SOPPdf(FPDF):
    def __init__(self, sop_title, customer_name):
        super().__init__()
        self.sop_title = sop_title
        self.customer_name = customer_name
        self.set_auto_page_break(auto=True, margin=20)
        if _HAS_DEJAVU:
            self.add_font("DejaVu", "", os.path.join(FONT_DIR, "DejaVuSans.ttf"))
            self.add_font("DejaVu", "B", os.path.join(FONT_DIR, "DejaVuSans-Bold.ttf"))
            self.add_font("DejaVu", "I", os.path.join(FONT_DIR, "DejaVuSans-Oblique.ttf"))

    def header(self):
        self.set_fill_color(*DKM_BLUE)
        self.rect(0, 0, 210, 4, "F")
        self.set_font(FAM, "B", 9)
        self.set_text_color(*DARK)
        self.set_y(8)
        self.cell(0, 5, "DKM-Customs", align="L")
        self.cell(0, 5, self.customer_name, align="R", new_x="LMARGIN", new_y="NEXT")
        self.ln(2)

    def footer(self):
        self.set_y(-15)
        self.set_draw_color(*DKM_ORANGE)
        self.line(10, self.get_y(), 200, self.get_y())
        self.set_font(FAM, "I", 7)
        self.set_text_color(120, 120, 120)
        self.cell(0, 8, "DKM-Customs  -  Developed by Luc De Kerf", align="L")
        self.cell(0, 8, f"Pagina {self.page_no()}", align="R")


def build_sop_pdf(sop, blocks) -> bytes:
    pdf = SOPPdf(sop["title"], sop["customer_name"])
    pdf.add_page()

    pdf.ln(6)
    pdf.set_font(FAM, "B", 20)
    pdf.set_text_color(*DARK)
    pdf.multi_cell(pdf.epw, 9, _md_inline_to_plain(sop["title"]),
                   new_x="LMARGIN", new_y="NEXT")
    pdf.set_font(FAM, "", 10)
    pdf.set_text_color(100, 100, 100)
    updated = sop.get("updated_at")
    if isinstance(updated, datetime):
        updated = updated.date().isoformat()
    pdf.cell(0, 6, f"Klant: {sop['customer_name']}   |   Versie {sop.get('version', 1)}"
                   f"   |   {updated or date.today().isoformat()}",
             new_x="LMARGIN", new_y="NEXT")
    pdf.ln(4)
    pdf.set_draw_color(*DKM_BLUE)
    pdf.set_line_width(0.6)
    pdf.line(10, pdf.get_y(), 200, pdf.get_y())
    pdf.ln(6)

    for b in blocks:
        pdf.set_font(FAM, "B", 13)
        pdf.set_text_color(*DKM_ORANGE)
        pdf.multi_cell(pdf.epw, 7, _md_inline_to_plain(b["title"]),
                       new_x="LMARGIN", new_y="NEXT")
        pdf.ln(1)
        pdf.set_font(FAM, "", 10.5)
        pdf.set_text_color(*DARK)
        for line in _md_inline_to_plain(b["content"]).split("\n"):
            pdf.multi_cell(pdf.epw, 5.5, line if line.strip() else " ",
                           new_x="LMARGIN", new_y="NEXT")
        pdf.ln(4)

    return bytes(pdf.output())
