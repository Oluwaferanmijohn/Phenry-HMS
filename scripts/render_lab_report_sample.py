from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_RIGHT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfbase import pdfmetrics
from reportlab.platypus import KeepTogether, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "output" / "pdf" / "lab-result-report-sample.pdf"
OUTPUT.parent.mkdir(parents=True, exist_ok=True)

font_dir = Path(r"C:\Windows\Fonts")
regular = font_dir / "arial.ttf"
bold = font_dir / "arialbd.ttf"
if regular.exists() and bold.exists():
    pdfmetrics.registerFont(TTFont("ReportSans", str(regular)))
    pdfmetrics.registerFont(TTFont("ReportSans-Bold", str(bold)))
else:
    regular = bold = None

FONT = "ReportSans" if regular else "Helvetica"
BOLD = "ReportSans-Bold" if bold else "Helvetica-Bold"
NAVY = colors.HexColor("#103F5D")
BLUE = colors.HexColor("#116DA4")
PALE_BLUE = colors.HexColor("#EAF5FB")
INK = colors.HexColor("#172033")
MUTED = colors.HexColor("#647789")
BORDER = colors.HexColor("#DBE3EC")

doc = SimpleDocTemplate(
    str(OUTPUT),
    pagesize=A4,
    rightMargin=14 * mm,
    leftMargin=14 * mm,
    topMargin=12 * mm,
    bottomMargin=12 * mm,
    title="Laboratory Result Report",
    author="Phenry Health",
)

styles = getSampleStyleSheet()
body = ParagraphStyle("Body", parent=styles["BodyText"], fontName=FONT, fontSize=8.5, leading=12, textColor=INK)
small = ParagraphStyle("Small", parent=body, fontSize=7, leading=10, textColor=MUTED)
label = ParagraphStyle("Label", parent=small, fontName=BOLD, fontSize=6.4, leading=8, textColor=MUTED, spaceAfter=2)
heading = ParagraphStyle("Heading", parent=body, fontName=BOLD, fontSize=16, leading=18, textColor=NAVY)
right = ParagraphStyle("Right", parent=small, alignment=TA_RIGHT)
right_heading = ParagraphStyle("RightHeading", parent=heading, alignment=TA_RIGHT, fontSize=16, leading=19)

story = []
brand = Table(
    [[
        Table([[Paragraph("P", ParagraphStyle("Logo", parent=heading, fontSize=24, leading=36, alignment=1, textColor=BLUE))]], colWidths=[18 * mm], rowHeights=[18 * mm], style=TableStyle([
            ("BACKGROUND", (0, 0), (-1, -1), PALE_BLUE),
            ("BOX", (0, 0), (-1, -1), 0.7, BORDER),
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ])),
        Paragraph("<b>PHENRY FERTILITY AND WOMEN'S HEALTH CENTRE</b><br/><font size='7' color='#116DA4'><i>Compassionate fertility care, guided by science</i></font><br/><font size='7' color='#647789'>15 Example Medical Avenue, Lagos, Nigeria<br/>Tel: +234 800 000 0000 | laboratory@example.org<br/>www.example.org</font>", body),
        Table([
            [Paragraph("LABORATORY MEDICINE", right)],
            [Paragraph("Laboratory Result", right_heading)],
            [Paragraph("<font color='#116DA4'><b>REPORT #8B2A41C71D90</b></font>", right)],
        ], colWidths=[62 * mm], style=TableStyle([
            ("ALIGN", (0, 0), (-1, -1), "RIGHT"),
            ("TOPPADDING", (0, 0), (-1, -1), 0),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 2),
        ])),
    ]],
    colWidths=[22 * mm, 92 * mm, 62 * mm],
    style=TableStyle([
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LINEABOVE", (0, 0), (-1, 0), 5, BLUE),
        ("LINEBELOW", (0, 0), (-1, 0), 0.7, BORDER),
        ("TOPPADDING", (0, 0), (-1, -1), 9),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 9),
    ]),
)
story.extend([brand, Spacer(1, 7 * mm)])

patient_data = [
    [Paragraph("PATIENT", label), Paragraph("PATIENT ID", label), Paragraph("DATE OF BIRTH / AGE", label)],
    [Paragraph("<b>Amara Okafor</b>", body), Paragraph("<b>PT-2026-0041</b>", body), Paragraph("<b>14 Jun 1992 / 34 years</b>", body)],
    [Paragraph("SEX", label), Paragraph("COLLECTED", label), Paragraph("REPORTED", label)],
    [Paragraph("<b>Female</b>", body), Paragraph("<b>05 Sep 2026, 09:15</b>", body), Paragraph("<b>05 Sep 2026, 11:42</b>", body)],
]
patient_table = Table(patient_data, colWidths=[70 * mm, 50 * mm, 56 * mm])
patient_table.setStyle(TableStyle([
    ("BOX", (0, 0), (-1, -1), 0.7, BORDER),
    ("INNERGRID", (0, 0), (-1, -1), 0.4, BORDER),
    ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#F7FAFC")),
    ("BACKGROUND", (0, 2), (-1, 2), colors.HexColor("#F7FAFC")),
    ("TOPPADDING", (0, 0), (-1, -1), 6),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
]))
story.extend([patient_table, Spacer(1, 7 * mm)])

story.append(Table([[Paragraph("<font size='7' color='#647789'>INVESTIGATION</font><br/><font size='12'><b>Blood Group and Full Blood Count</b></font>", body), Paragraph("<font color='#08795A'><b>FINAL</b></font>", right)]], colWidths=[145 * mm, 31 * mm], style=TableStyle([("VALIGN", (0, 0), (-1, -1), "BOTTOM")])) )
story.append(Spacer(1, 3 * mm))

result_data = [
    ["TEST PARAMETER", "RESULT", "UNIT", "REFERENCE RANGE", "FLAG"],
    ["ABO blood group", "A", "-", "-", "-"],
    ["Rhesus (RhD) type", "+VE Positive", "-", "Negative / Positive", "-"],
]
result_table = Table(result_data, colWidths=[55 * mm, 40 * mm, 22 * mm, 43 * mm, 16 * mm], repeatRows=1)
result_table.setStyle(TableStyle([
    ("BACKGROUND", (0, 0), (-1, 0), NAVY),
    ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
    ("FONTNAME", (0, 0), (-1, 0), BOLD),
    ("FONTNAME", (1, 1), (1, -1), BOLD),
    ("FONTNAME", (0, 1), (-1, -1), FONT),
    ("FONTSIZE", (0, 0), (-1, 0), 7),
    ("FONTSIZE", (0, 1), (-1, -1), 8.5),
    ("TEXTCOLOR", (0, 1), (-1, -1), INK),
    ("GRID", (0, 1), (-1, -1), 0.4, BORDER),
    ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F7FAFC")]),
    ("TOPPADDING", (0, 0), (-1, -1), 7),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
]))
story.extend([result_table, Spacer(1, 7 * mm)])

remarks = Table([[Paragraph("<b><font size='7' color='#647789'>LABORATORY REMARKS</font></b><br/>ABO and RhD typing completed. Correlate with clinical history where required.", body)]], colWidths=[176 * mm], style=TableStyle([
    ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#F2F8FB")),
    ("LINEBEFORE", (0, 0), (0, -1), 3, colors.HexColor("#4AA2CF")),
    ("TOPPADDING", (0, 0), (-1, -1), 8),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
    ("LEFTPADDING", (0, 0), (-1, -1), 10),
]))
story.extend([remarks, Spacer(1, 12 * mm)])

signoff = Table([[
    Paragraph("<font size='7' color='#647789'>ENTERED BY</font><br/><b>Grace Adeyemi, Medical Laboratory Scientist</b><br/><font size='7' color='#647789'>05 Sep 2026, 11:42</font>", body),
    Paragraph("<font size='7' color='#647789'>LABORATORY DIRECTOR</font><br/><b>Dr. Adaeze Nwosu</b><br/><font size='7' color='#647789'>Consultant Pathologist</font>", right),
]], colWidths=[88 * mm, 88 * mm], style=TableStyle([
    ("LINEABOVE", (0, 0), (-1, 0), 0.7, BORDER),
    ("TOPPADDING", (0, 0), (-1, -1), 10),
]))
identifiers = Table([[Paragraph("Facility Reg: HFR-2026-001 | Laboratory Licence: MLSCN-LAB-0041 | TIN: 12345678-0001", ParagraphStyle("Identifiers", parent=small, fontSize=6.5, alignment=1))]], colWidths=[176 * mm], style=TableStyle([
    ("LINEABOVE", (0, 0), (-1, 0), 0.5, BORDER),
    ("TOPPADDING", (0, 0), (-1, -1), 5),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
]))
disclaimer = Table([[Paragraph("Results must be interpreted by a qualified healthcare professional together with the patient's clinical findings. This report contains confidential medical information.", ParagraphStyle("Disclaimer", parent=small, textColor=colors.HexColor("#DCEAF2"), alignment=1))]], colWidths=[176 * mm], style=TableStyle([
    ("BACKGROUND", (0, 0), (-1, -1), NAVY),
    ("TOPPADDING", (0, 0), (-1, -1), 7),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
]))
story.append(KeepTogether([signoff, Spacer(1, 4 * mm), identifiers, disclaimer]))

doc.build(story)
print(OUTPUT)
