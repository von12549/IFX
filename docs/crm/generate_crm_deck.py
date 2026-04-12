"""
Generate CRM V2 PowerPoint presentation for IFX Fund Registry.
"""
from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN
from pptx.util import Inches, Pt
import copy

# ── Colour palette ──────────────────────────────────────────────────────────
C_NAVY      = RGBColor(0x1A, 0x2B, 0x4A)   # primary dark
C_BLUE      = RGBColor(0x1E, 0x5F, 0xB5)   # accent blue
C_TEAL      = RGBColor(0x0D, 0x9E, 0x8A)   # accent teal
C_AMBER     = RGBColor(0xF5, 0xA6, 0x23)   # highlight amber
C_RED       = RGBColor(0xD9, 0x3A, 0x3A)   # warning / retire
C_LGREY     = RGBColor(0xF2, 0xF4, 0xF7)   # slide background
C_WHITE     = RGBColor(0xFF, 0xFF, 0xFF)
C_DGREY     = RGBColor(0x44, 0x44, 0x55)   # body text
C_GREEN     = RGBColor(0x27, 0xAE, 0x60)

prs = Presentation()
prs.slide_width  = Inches(13.33)
prs.slide_height = Inches(7.5)

BLANK = prs.slide_layouts[6]   # completely blank


# ── Helper utilities ─────────────────────────────────────────────────────────

def add_rect(slide, x, y, w, h, fill=C_NAVY, alpha=None):
    shape = slide.shapes.add_shape(1, Inches(x), Inches(y), Inches(w), Inches(h))
    shape.line.fill.background()
    if fill:
        shape.fill.solid()
        shape.fill.fore_color.rgb = fill
    else:
        shape.fill.background()
    return shape

def add_text(slide, text, x, y, w, h,
             size=18, bold=False, color=C_WHITE, align=PP_ALIGN.LEFT,
             wrap=True, italic=False):
    txb = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h))
    txb.word_wrap = wrap
    tf = txb.text_frame
    tf.word_wrap = wrap
    p = tf.paragraphs[0]
    p.alignment = align
    run = p.add_run()
    run.text = text
    run.font.size = Pt(size)
    run.font.bold = bold
    run.font.italic = italic
    run.font.color.rgb = color
    return txb

def add_bullet_box(slide, lines, x, y, w, h,
                   size=14, color=C_DGREY, head=None, head_color=C_BLUE):
    txb = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h))
    txb.word_wrap = True
    tf = txb.text_frame
    tf.word_wrap = True
    first = True
    if head:
        p = tf.paragraphs[0] if first else tf.add_paragraph()
        first = False
        p.alignment = PP_ALIGN.LEFT
        r = p.add_run()
        r.text = head
        r.font.size = Pt(size + 1)
        r.font.bold = True
        r.font.color.rgb = head_color
    for line in lines:
        p = tf.paragraphs[0] if (first and not head) else tf.add_paragraph()
        first = False
        p.alignment = PP_ALIGN.LEFT
        p.space_before = Pt(2)
        r = p.add_run()
        r.text = line
        r.font.size = Pt(size)
        r.font.color.rgb = color
    return txb

def slide_bg(slide, color=C_LGREY):
    bg = add_rect(slide, 0, 0, 13.33, 7.5, fill=color)
    bg.zorder = 0

def header_bar(slide, title, subtitle=None):
    add_rect(slide, 0, 0, 13.33, 1.15, fill=C_NAVY)
    add_rect(slide, 0, 1.15, 13.33, 0.06, fill=C_BLUE)
    add_text(slide, title, 0.35, 0.12, 10, 0.65,
             size=28, bold=True, color=C_WHITE)
    if subtitle:
        add_text(slide, subtitle, 0.35, 0.72, 11, 0.42,
                 size=14, color=RGBColor(0xB0, 0xC8, 0xF0))

def footer(slide, text="IFX Fund Registry · CRM V2 Design · Confidential"):
    add_rect(slide, 0, 7.2, 13.33, 0.3, fill=C_NAVY)
    add_text(slide, text, 0.3, 7.2, 12, 0.3,
             size=9, color=RGBColor(0x88, 0xAA, 0xCC))

def card(slide, x, y, w, h, title, lines,
         bg=C_WHITE, title_color=C_BLUE, line_color=C_DGREY,
         title_size=13, line_size=12, border_color=None):
    box = add_rect(slide, x, y, w, h, fill=bg)
    if border_color:
        box.line.color.rgb = border_color
        box.line.width = Pt(1)
    else:
        box.line.fill.background()
    add_text(slide, title, x + 0.12, y + 0.08, w - 0.2, 0.3,
             size=title_size, bold=True, color=title_color)
    add_bullet_box(slide, lines, x + 0.12, y + 0.38, w - 0.2, h - 0.45,
                   size=line_size, color=line_color)


# ═══════════════════════════════════════════════════════════════════════════
# SLIDE 1 — Title
# ═══════════════════════════════════════════════════════════════════════════
sl = prs.slides.add_slide(BLANK)
add_rect(sl, 0, 0, 13.33, 7.5, fill=C_NAVY)
add_rect(sl, 0, 0, 0.55, 7.5, fill=C_BLUE)
add_rect(sl, 0.55, 5.8, 12.78, 0.06, fill=C_TEAL)

add_text(sl, "IFX Fund Registry", 1.0, 1.4, 11, 0.7,
         size=20, color=RGBColor(0xB0, 0xC8, 0xF0))
add_text(sl, "CRM V2 Design", 1.0, 2.1, 11, 1.1,
         size=44, bold=True, color=C_WHITE)
add_text(sl, "InvestmentAccount · PartyRelationship · Advisor Model · KYC Enrichment",
         1.0, 3.2, 11.5, 0.55, size=17, color=RGBColor(0xCC, 0xDD, 0xF5))
add_text(sl, "Based on: Taurus inv schema analysis + ChatGPT CRM design review",
         1.0, 3.8, 11, 0.45, size=13,
         color=RGBColor(0x88, 0xAA, 0xCC), italic=True)
add_text(sl, "April 2026", 1.0, 5.95, 4, 0.4,
         size=13, color=RGBColor(0x88, 0xAA, 0xCC))


# ═══════════════════════════════════════════════════════════════════════════
# SLIDE 2 — Agenda
# ═══════════════════════════════════════════════════════════════════════════
sl = prs.slides.add_slide(BLANK)
slide_bg(sl)
header_bar(sl, "Agenda", "What this deck covers")
footer(sl)

items = [
    ("01", "CRM V1 — What we built",         "Foundation: Party, Investor, PartyInvestorRelationship"),
    ("02", "What the analysis revealed",       "Taurus inv schema + ChatGPT design review"),
    ("03", "CRM V2 — New entity model",        "InvestmentAccount, PartyRelationship, AdvisorAccountLink, InvestorDocument"),
    ("04", "Advisor model & hierarchy",         "3-tier: Firm → Branch → Rep; two-layer ABAC"),
    ("05", "KYC / AML enrichment",             "FrankieOne + Taurus fields; InvestorDocument"),
    ("06", "Relationship types",               "AccountRelationshipType & PartyRelationshipType enums"),
    ("07", "API surface",                      "New endpoints across 4 resource groups"),
    ("08", "Implementation roadmap",           "7 phases; 50 tasks"),
]
for i, (num, title, sub) in enumerate(items):
    row = i // 2
    col = i % 2
    bx = 0.4 + col * 6.5
    by = 1.45 + row * 1.4
    add_rect(sl, bx, by, 6.1, 1.22, fill=C_WHITE)
    add_rect(sl, bx, by, 0.52, 1.22, fill=C_BLUE)
    add_text(sl, num, bx + 0.04, by + 0.32, 0.48, 0.55,
             size=18, bold=True, color=C_WHITE, align=PP_ALIGN.CENTER)
    add_text(sl, title, bx + 0.62, by + 0.08, 5.3, 0.38,
             size=14, bold=True, color=C_NAVY)
    add_text(sl, sub, bx + 0.62, by + 0.52, 5.3, 0.58,
             size=11, color=C_DGREY, italic=True)


# ═══════════════════════════════════════════════════════════════════════════
# SLIDE 3 — CRM V1 Recap
# ═══════════════════════════════════════════════════════════════════════════
sl = prs.slides.add_slide(BLANK)
slide_bg(sl)
header_bar(sl, "CRM V1 — What We Built", "Foundation delivered in April 2026")
footer(sl)

# entities
for i, (title, lines, col) in enumerate([
    ("Party", ["PartyCode (unique/tenant)", "Name, PartyType", "Status (Active/Closed)", "TenantId", "CreatedBy / UpdatedBy"], C_BLUE),
    ("Investor", ["InvestorCode (unique/tenant)", "Name, InvestorType", "KycStatus + KycReviewedAt", "ResidencyCountry, TaxResidency", "Status (Active/Closed)"], C_TEAL),
    ("PartyInvestorRelationship", ["PartyId + InvestorId + TenantId", "RelationshipType (4 types)", "EffectiveDate / ExpiryDate", "Composite PK", "⚠  Flat — no ownership %"], C_AMBER),
]):
    x = 0.4 + i * 4.3
    add_rect(sl, x, 1.4, 3.9, 0.42, fill=col)
    add_text(sl, title, x + 0.15, 1.42, 3.6, 0.38,
             size=14, bold=True, color=C_WHITE)
    add_rect(sl, x, 1.82, 3.9, 2.5, fill=C_WHITE)
    add_bullet_box(sl, lines, x + 0.15, 1.9, 3.6, 2.35,
                   size=12, color=C_DGREY)

add_text(sl, "✓  5-layer Clean Architecture   ✓  CQRS (12 commands, 5 queries)   "
             "✓  Full ABAC on writes   ✓  Multi-tenant isolation   "
             "✓  14 HTTP endpoints",
         0.4, 4.5, 12.5, 0.45, size=12, color=C_DGREY)

add_rect(sl, 0.4, 5.05, 12.5, 1.5, fill=RGBColor(0xFF, 0xF3, 0xCD))
add_text(sl, "⚠  Gaps identified by Taurus analysis", 0.6, 5.1, 12, 0.35,
         size=13, bold=True, color=RGBColor(0x85, 0x60, 0x00))
gaps = ("No InvestmentAccount concept  ·  Advisor linked to Investor (wrong)  ·  "
        "No advisor hierarchy  ·  No Party-to-Party relationships  ·  "
        "KYC = single enum only  ·  No ownership % on relationship")
add_text(sl, gaps, 0.6, 5.48, 12.2, 0.95, size=12,
         color=RGBColor(0x85, 0x60, 0x00))


# ═══════════════════════════════════════════════════════════════════════════
# SLIDE 4 — What the analysis revealed
# ═══════════════════════════════════════════════════════════════════════════
sl = prs.slides.add_slide(BLANK)
slide_bg(sl)
header_bar(sl, "What the Analysis Revealed",
           "Taurus inv schema (173 tables) + ChatGPT CRM design review")
footer(sl)

findings = [
    (C_BLUE,  "INVAccount ≠ Party",
     ["Legacy 'Account' is an investment/registry account", "Legal entity = INVInvestorNames (maps to IFX Party)", "One investor → many accounts; one account → many investors (joint)"]),
    (C_TEAL,  "3-tier Advisor hierarchy exists in production",
     ["AdvisoryGroup (licensed firm, AFSL number)", "AdvisoryBranch (regional office, effective dates)", "AdvisorNames (individual rep, rep licence) → User not Party"]),
    (C_AMBER, "Advisor links to Account, not Investor",
     ["AdvisorAccountLink: DateFrom / DateTo / RebateRate", "A person can have account A (Advisor X) + account B (Advisor Y)", "Authorization for new investments needs a separate mechanism"]),
    (C_RED,   "Investor-to-Investor links model corporate structures",
     ["INVInvestorInvestorLink: ParentInvestor + RelationshipType", "Company → Director (BeneficialOwner)", "Trust → Trustee (RegisteredHolder) — real production data"]),
]
for i, (col, title, lines) in enumerate(findings):
    x = 0.35 + (i % 2) * 6.5
    y = 1.45 + (i // 2) * 2.55
    add_rect(sl, x, y, 6.15, 0.42, fill=col)
    add_text(sl, title, x + 0.15, y + 0.04, 5.85, 0.36,
             size=13, bold=True, color=C_WHITE)
    add_rect(sl, x, y + 0.42, 6.15, 2.02, fill=C_WHITE)
    add_bullet_box(sl, ["▸ " + l for l in lines], x + 0.15, y + 0.5,
                   5.85, 1.85, size=12, color=C_DGREY)


# ═══════════════════════════════════════════════════════════════════════════
# SLIDE 5 — CRM V2 Entity Model (overview)
# ═══════════════════════════════════════════════════════════════════════════
sl = prs.slides.add_slide(BLANK)
slide_bg(sl)
header_bar(sl, "CRM V2 — New Entity Model", "5 entities added · 1 retired")
footer(sl)

entities = [
    (0.3,  1.45, C_BLUE,  "InvestmentAccount  🆕",
     ["AccountNumber (unique/tenant)", "AccountType (Individual/Joint/Trust…)", "Status: Active / Inactive / Locked", "CertificateDate (optional)"]),
    (4.55, 1.45, C_TEAL,  "PartyAccountLink  🆕",
     ["PartyId + InvestmentAccountId", "RelationshipType (5 types)", "OwnershipPercentage (decimal)", "LinkOrder (joint accounts)", "EffectiveDate / ExpiryDate"]),
    (8.8,  1.45, C_NAVY,  "PartyRelationship  🆕",
     ["FromPartyId + ToPartyId", "RelationshipType (5 types)", "EffectiveDate / ExpiryDate", "Covers: hierarchy + corporate", "Expire() method"]),
    (0.3,  4.2,  RGBColor(0x6A,0x3F,0xB5), "AdvisorAccountLink  🆕",
     ["AdvisorPartyId + AccountId", "RebateRate (decimal)", "EffectiveDate / ExpiryDate", "Expire() method"]),
    (4.55, 4.2,  C_TEAL,  "InvestorDocument  🆕",
     ["DocumentType (7 types)", "DocumentNumber, IssueCountry", "IssueState, IssueDate, ExpiryDate", "Child of Investor"]),
    (8.8,  4.2,  C_RED,   "PartyInvestorRelationship  ❌ RETIRED",
     ["Replaced by PartyAccountLink", "Existing data migrated", "Table dropped in migration"]),
]
for x, y, col, title, lines in entities:
    w, h = 3.9, 2.55
    add_rect(sl, x, y, w, 0.42, fill=col)
    add_text(sl, title, x + 0.12, y + 0.04, w - 0.2, 0.36,
             size=12, bold=True, color=C_WHITE)
    add_rect(sl, x, y + 0.42, w, h - 0.42, fill=C_WHITE)
    add_bullet_box(sl, ["· " + l for l in lines], x + 0.12, y + 0.5,
                   w - 0.22, h - 0.58, size=11, color=C_DGREY)


# ═══════════════════════════════════════════════════════════════════════════
# SLIDE 6 — Entity Relationship Diagram
# ═══════════════════════════════════════════════════════════════════════════
sl = prs.slides.add_slide(BLANK)
slide_bg(sl)
header_bar(sl, "Entity Relationship Diagram", "CRM V2 — key relationships at a glance")
footer(sl)

def erd_box(sl, x, y, w, h, label, sublabel, col):
    add_rect(sl, x, y, w, h, fill=col)
    add_text(sl, label, x + 0.1, y + 0.06, w - 0.15, 0.32,
             size=12, bold=True, color=C_WHITE, align=PP_ALIGN.CENTER)
    if sublabel:
        add_text(sl, sublabel, x + 0.1, y + 0.38, w - 0.15, h - 0.42,
                 size=9, color=RGBColor(0xDD, 0xEE, 0xFF),
                 align=PP_ALIGN.CENTER)

# Row 1: Advisor firm / branch
erd_box(sl, 0.3,  1.35, 2.8, 1.0, "Party", "AdvisoryFirm\nAdvisoryBranch", C_BLUE)
# arrow right
add_text(sl, "PartyRelationship\nParentFirm", 3.2, 1.62, 1.7, 0.5,
         size=9, color=C_BLUE, italic=True, align=PP_ALIGN.CENTER)
erd_box(sl, 5.0,  1.35, 2.8, 1.0, "Party", "AdvisoryFirm\nAdvisoryBranch", C_BLUE)
add_text(sl, "AuthorizedToAdvise ──────────────►", 3.2, 2.0, 9.4, 0.4,
         size=9, color=C_TEAL, italic=True)

# Row 2: User
erd_box(sl, 0.3,  2.75, 2.8, 0.85, "User", "Advisor Rep\n(linked to Party)", C_DGREY)
add_text(sl, "AdvisorAccountLink\n(RebateRate, DateFrom/To)", 3.2, 2.88, 1.7, 0.6,
         size=9, color=RGBColor(0x6A,0x3F,0xB5), italic=True, align=PP_ALIGN.CENTER)

# Row 3: InvestmentAccount (centre)
erd_box(sl, 5.0,  2.75, 2.8, 0.85, "InvestmentAccount",
        "AccountNumber\nAccountType / Status", C_TEAL)

# Row 4: PartyAccountLink → Party(Investor)
add_text(sl, "PartyAccountLink\n(RelType, Ownership%)", 3.2, 3.75, 1.7, 0.6,
         size=9, color=C_TEAL, italic=True, align=PP_ALIGN.CENTER)
erd_box(sl, 5.0,  3.8,  2.8, 0.9, "Party", "Investor / Legal Entity\n(KYC enriched)", C_NAVY)

# Row 5: PartyRelationship self-ref
erd_box(sl, 8.3,  3.8,  2.8, 0.9, "PartyRelationship",
        "BeneficialOwner\nControllingEntity\nTrustBeneficiary", C_NAVY)
add_text(sl, "◄── Party-to-Party ──►", 5.1, 4.75, 5.8, 0.35,
         size=9, color=C_NAVY, italic=True, align=PP_ALIGN.CENTER)

# InvestorDocument
erd_box(sl, 8.3,  2.75, 2.8, 0.85, "InvestorDocument",
        "Passport / DriverLicence\nDocumentNumber, Expiry", C_TEAL)
add_text(sl, "↑ child of Investor", 8.3, 3.62, 2.8, 0.28,
         size=9, color=C_TEAL, italic=True, align=PP_ALIGN.CENTER)

# connecting arrows (text-based)
add_text(sl, "▼", 1.6, 3.57, 0.4, 0.28, size=16, color=C_DGREY, align=PP_ALIGN.CENTER)
add_text(sl, "▼", 6.3, 3.57, 0.4, 0.28, size=16, color=C_TEAL, align=PP_ALIGN.CENTER)
add_text(sl, "◄──────────────────────────────────────", 0.3, 2.37, 4.6, 0.3,
         size=9, color=C_BLUE, italic=True)

# legend
add_rect(sl, 0.3, 5.6, 12.6, 1.55, fill=C_WHITE)
add_text(sl, "Relationship types at a glance", 0.5, 5.65, 5, 0.32,
         size=12, bold=True, color=C_NAVY)
legend = [
    ("PartyRelationship types:", "ParentFirm · AuthorizedToAdvise · BeneficialOwner · ControllingEntity · TrustBeneficiary"),
    ("PartyAccountLink types:",  "RegisteredHolder · BeneficialHolder · TrustBeneficiary · ControllingEntity · Agent"),
]
for i, (k, v) in enumerate(legend):
    add_text(sl, k, 0.5, 6.05 + i * 0.46, 2.6, 0.38,
             size=11, bold=True, color=C_DGREY)
    add_text(sl, v, 3.15, 6.05 + i * 0.46, 9.5, 0.38,
             size=11, color=C_DGREY)


# ═══════════════════════════════════════════════════════════════════════════
# SLIDE 7 — Advisor Model & Hierarchy
# ═══════════════════════════════════════════════════════════════════════════
sl = prs.slides.add_slide(BLANK)
slide_bg(sl)
header_bar(sl, "Advisor Model & Hierarchy",
           "3-tier structure confirmed by Taurus production data")
footer(sl)

# hierarchy diagram
tiers = [
    (C_BLUE,  "AdvisoryGroup (Firm)",
     "Party(AdvisoryFirm) · AFSL/Licence number · bIsActive"),
    (C_TEAL,  "AdvisoryBranch (Office)",
     "Party(AdvisoryBranch) · DateFrom/DateTo · Parent FK"),
    (C_DGREY, "Advisor Rep (Individual)",
     "User · Rep licence number · Linked to Branch Party via PartyId"),
]
for i, (col, title, sub) in enumerate(tiers):
    indent = i * 0.55
    add_rect(sl, 0.35 + indent, 1.45 + i * 1.2, 5.2 - indent * 2, 0.9, fill=col)
    add_text(sl, title, 0.55 + indent, 1.52 + i * 1.2, 4.8, 0.35,
             size=13, bold=True, color=C_WHITE)
    add_text(sl, sub, 0.55 + indent, 1.85 + i * 1.2, 4.8, 0.42,
             size=10, color=RGBColor(0xDD,0xEE,0xFF))
    if i < 2:
        add_text(sl, "▼  PartyRelationship (ParentFirm)", 1.0 + indent, 2.37 + i * 1.2,
                 3.5, 0.32, size=10, color=col, italic=True)

# two-layer ABAC
add_rect(sl, 6.2, 1.35, 6.7, 5.35, fill=C_WHITE)
add_rect(sl, 6.2, 1.35, 6.7, 0.42, fill=C_NAVY)
add_text(sl, "Two-Layer Advisor Authorization", 6.35, 1.38, 6.35, 0.36,
         size=13, bold=True, color=C_WHITE)

add_rect(sl, 6.3, 1.87, 6.5, 1.75, fill=C_LGREY)
add_text(sl, "Layer 1 — Pre-Account (Can create investment?)",
         6.45, 1.92, 6.2, 0.35, size=12, bold=True, color=C_BLUE)
add_text(sl, "PartyRelationship (AuthorizedToAdvise)\n"
             "FromPartyId = AdvisorParty\n"
             "ToPartyId   = InvestorParty\n"
             "isActive = true",
         6.45, 2.3, 6.2, 1.2, size=11, color=C_DGREY)

add_rect(sl, 6.3, 3.72, 6.5, 1.75, fill=C_LGREY)
add_text(sl, "Layer 2 — Post-Account (Can manage account?)",
         6.45, 3.77, 6.2, 0.35, size=12, bold=True, color=C_TEAL)
add_text(sl, "AdvisorAccountLink\n"
             "AdvisorPartyId = AdvisorParty\n"
             "InvestmentAccountId = target\n"
             "isActive = true",
         6.45, 4.15, 6.2, 1.2, size=11, color=C_DGREY)

add_rect(sl, 6.3, 5.57, 6.5, 0.95, fill=RGBColor(0xE8, 0xF5, 0xE9))
add_text(sl, "ABAC Hierarchy Traversal",
         6.45, 5.62, 6.2, 0.3, size=12, bold=True, color=C_GREEN)
add_text(sl, "OPA template HasAdvisoryAuthorization traverses\n"
             "Rep → Branch → Firm via PartyRelationship(ParentFirm)",
         6.45, 5.92, 6.2, 0.52, size=10, color=C_DGREY)


# ═══════════════════════════════════════════════════════════════════════════
# SLIDE 8 — KYC / AML Enrichment
# ═══════════════════════════════════════════════════════════════════════════
sl = prs.slides.add_slide(BLANK)
slide_bg(sl)
header_bar(sl, "KYC / AML Enrichment",
           "Investor fields enriched from Taurus + FrankieOne model")
footer(sl)

# before/after
add_rect(sl, 0.3, 1.35, 3.5, 0.42, fill=C_RED)
add_text(sl, "CRM V1  (before)", 0.45, 1.38, 3.2, 0.36,
         size=13, bold=True, color=C_WHITE)
add_rect(sl, 0.3, 1.77, 3.5, 1.85, fill=C_WHITE)
add_bullet_box(sl, ["KycStatus (enum: Pending/Approved/Rejected/Expired)",
                    "KycReviewedAt (DateTime?)",
                    "",
                    "⚠  No PEP, no AML gateway, no FATCA",
                    "⚠  No documents, no tax IDs"],
               0.45, 1.85, 3.2, 1.65, size=11, color=C_DGREY)

add_rect(sl, 4.1, 1.35, 8.85, 0.42, fill=C_GREEN)
add_text(sl, "CRM V2  (after)", 4.25, 1.38, 8.5, 0.36,
         size=13, bold=True, color=C_WHITE)
add_rect(sl, 4.1, 1.77, 8.85, 4.85, fill=C_WHITE)

groups = [
    ("Personal (individuals)", C_BLUE,
     ["DateOfBirth, DateOfDeath, Gender, PlaceOfBirth"]),
    ("Nationality & Tax", C_TEAL,
     ["NationalityCountry, IsCitizen, TaxResidencyCountry",
      "TIN, FatcaCrsStatus (enum: 4 values), GIIN"]),
    ("AML / Identity Verification", RGBColor(0x6A,0x3F,0xB5),
     ["AmlStatus (NotChecked/Clear/Review/Blocked)",
      "AmlGatewayReference → FrankieOne entityId",
      "AmlCheckedAt, IsPEP, PepDetails, SourceOfWealth",
      "UnresolvedPepCount, UnresolvedSanctionCount, UnresolvedAdverseMediaCount"]),
    ("Business / Corporate", C_AMBER,
     ["BusinessRegistrationNumber, BusinessTaxNumber",
      "IsPubliclyListed, Regulator, LicenseNumber"]),
    ("Identity Documents (child table)", C_NAVY,
     ["DocumentType: Passport · DriverLicence · NationalId · Other",
      "DocumentNumber, IssueCountry, IssueState, ExpiryDate"]),
]
cy = 1.9
for title, col, lines in groups:
    add_text(sl, "▸ " + title, 4.25, cy, 8.5, 0.28,
             size=11, bold=True, color=col)
    cy += 0.3
    for line in lines:
        add_text(sl, "    " + line, 4.25, cy, 8.4, 0.26,
                 size=10, color=C_DGREY)
        cy += 0.27
    cy += 0.08

add_rect(sl, 0.3, 3.72, 3.5, 0.88, fill=RGBColor(0xE8,0xF5,0xE9))
add_text(sl, "FrankieOne Integration", 0.45, 3.77, 3.2, 0.28,
         size=11, bold=True, color=C_GREEN)
add_text(sl, "Store AmlGatewayReference as pointer.\n"
             "Full check history lives in FrankieOne.\n"
             "IFX stores summary for ABAC evaluation.",
         0.45, 4.05, 3.2, 0.48, size=10, color=C_DGREY)


# ═══════════════════════════════════════════════════════════════════════════
# SLIDE 9 — Relationship Types Reference
# ═══════════════════════════════════════════════════════════════════════════
sl = prs.slides.add_slide(BLANK)
slide_bg(sl)
header_bar(sl, "Relationship Types Reference",
           "AccountRelationshipType · PartyRelationshipType")
footer(sl)

# AccountRelationshipType
add_rect(sl, 0.3, 1.35, 6.1, 0.42, fill=C_TEAL)
add_text(sl, "AccountRelationshipType  (PartyAccountLink)",
         0.45, 1.38, 5.8, 0.36, size=13, bold=True, color=C_WHITE)
rows1 = [
    ("1", "RegisteredHolder",  "The legal person(s) in whose name the holding is registered"),
    ("2", "BeneficialHolder",  "Entity on whose behalf the holding is registered"),
    ("3", "TrustBeneficiary",  "Beneficiary of a trust or controlling shareholder"),
    ("4", "ControllingEntity", "Entity that controls another (e.g. ultimate holding company)"),
    ("5", "Agent",             "Person appointed to act on behalf of another (limited powers)"),
]
add_rect(sl, 0.3, 1.77, 6.1, 3.75, fill=C_WHITE)
for i, (num, name, desc) in enumerate(rows1):
    by = 1.87 + i * 0.72
    add_rect(sl, 0.38, by, 0.45, 0.55, fill=C_TEAL)
    add_text(sl, num, 0.38, by + 0.1, 0.45, 0.35,
             size=14, bold=True, color=C_WHITE, align=PP_ALIGN.CENTER)
    add_text(sl, name, 0.9, by + 0.02, 2.0, 0.28,
             size=11, bold=True, color=C_NAVY)
    add_text(sl, desc, 0.9, by + 0.28, 5.35, 0.28,
             size=10, color=C_DGREY)

# PartyRelationshipType
add_rect(sl, 6.9, 1.35, 6.1, 0.42, fill=C_NAVY)
add_text(sl, "PartyRelationshipType  (PartyRelationship)",
         7.05, 1.38, 5.8, 0.36, size=13, bold=True, color=C_WHITE)
rows2 = [
    ("1", "ParentFirm",          "AdvisoryGroup is the parent of AdvisoryBranch"),
    ("2", "AuthorizedToAdvise",  "Advisor firm/branch is authorised to act for this investor"),
    ("3", "BeneficialOwner",     "Party is the beneficial owner of another party's assets"),
    ("4", "ControllingEntity",   "Party controls another party (e.g. ultimate holding company)"),
    ("5", "TrustBeneficiary",    "Party is the beneficiary of a trust arrangement"),
]
add_rect(sl, 6.9, 1.77, 6.1, 3.75, fill=C_WHITE)
for i, (num, name, desc) in enumerate(rows2):
    by = 1.87 + i * 0.72
    add_rect(sl, 6.98, by, 0.45, 0.55, fill=C_NAVY)
    add_text(sl, num, 6.98, by + 0.1, 0.45, 0.35,
             size=14, bold=True, color=C_WHITE, align=PP_ALIGN.CENTER)
    add_text(sl, name, 7.5, by + 0.02, 2.2, 0.28,
             size=11, bold=True, color=C_NAVY)
    add_text(sl, desc, 7.5, by + 0.28, 5.35, 0.28,
             size=10, color=C_DGREY)

add_rect(sl, 0.3, 5.62, 12.7, 1.52, fill=RGBColor(0xE8,0xF0,0xFF))
add_text(sl, "PartyType enum additions (CRM V2)",
         0.5, 5.67, 5, 0.32, size=12, bold=True, color=C_BLUE)
add_text(sl, "AdvisoryFirm = 6  ·  AdvisoryBranch = 7  "
             "(existing: FundManager=1, Distributor=2, Custodian=3, TransferAgent=4, Other=5)",
         0.5, 6.0, 12.3, 0.35, size=11, color=C_DGREY)
add_text(sl, "AccountType enum (new):  Individual · Joint · Trust · Corporate · "
             "SuperannuationFund · Partnership · Other",
         0.5, 6.38, 12.3, 0.35, size=11, color=C_DGREY)
add_text(sl, "AmlStatus enum (new):  NotChecked · Clear · Review · Blocked    "
             "FatcaCrsStatus (new):  NotReviewed · Compliant · Exempt · ReportingRequired",
         0.5, 6.72, 12.3, 0.35, size=11, color=C_DGREY)


# ═══════════════════════════════════════════════════════════════════════════
# SLIDE 10 — API Surface
# ═══════════════════════════════════════════════════════════════════════════
sl = prs.slides.add_slide(BLANK)
slide_bg(sl)
header_bar(sl, "API Surface", "New endpoints added in CRM V2")
footer(sl)

groups_api = [
    (C_TEAL,  "InvestmentAccount  /api/v1/investment-account",
     ["GET  /                          List (tenant-scoped)",
      "GET  /{id}                      Get by ID",
      "POST /                          Create",
      "PUT  /{id}                      Update",
      "DELETE /{id}                    Soft-delete (Status = Inactive)",
      "GET  /{id}/parties              List linked parties",
      "POST /{id}/parties              Link party (PartyAccountLink)",
      "DELETE /{id}/parties/{partyId}  Unlink party",
      "GET  /{id}/advisors             List advisors",
      "POST /{id}/advisors             Link advisor (AdvisorAccountLink)",
      "DELETE /{id}/advisors/{advId}   Unlink advisor"]),
    (C_NAVY,  "PartyRelationship  /api/v1/party/{id}/relationships",
     ["GET  /                          List for party (by From or To)",
      "POST /                          Create relationship",
      "DELETE /{relId}                 Expire relationship"]),
    (C_BLUE,  "InvestorDocument  /api/v1/investor/{id}/documents",
     ["GET  /                          List documents",
      "POST /                          Add document",
      "DELETE /{docId}                 Remove document"]),
    (C_AMBER, "Retired",
     ["DELETE  /api/v1/party/{id}/investors/{invId}",
      "POST    /api/v1/party/{id}/investors/{invId}",
      "→ replaced by PartyAccountLink endpoints"]),
]
positions = [(0.3, 1.35), (7.05, 1.35), (0.3, 4.45), (7.05, 4.45)]
widths    = [6.6, 6.0, 6.6, 6.0]
for idx, (col, title, lines) in enumerate(groups_api):
    x, y = positions[idx]
    w    = widths[idx]
    add_rect(sl, x, y, w, 0.4, fill=col)
    add_text(sl, title, x + 0.12, y + 0.04, w - 0.2, 0.34,
             size=11, bold=True, color=C_WHITE)
    add_rect(sl, x, y + 0.4, w, 2.65, fill=C_WHITE)
    add_bullet_box(sl, lines, x + 0.12, y + 0.48, w - 0.22, 2.48,
                   size=9.5, color=C_DGREY)


# ═══════════════════════════════════════════════════════════════════════════
# SLIDE 11 — Example Workflow: Advisor Onboards New Investment
# ═══════════════════════════════════════════════════════════════════════════
sl = prs.slides.add_slide(BLANK)
slide_bg(sl)
header_bar(sl, "Workflow: Advisor Onboards a New Investment",
           "End-to-end flow using CRM V2 entities")
footer(sl)

steps = [
    (C_BLUE,  "1  Register Advisor Firm",
     "POST /api/v1/party\nPartyType = AdvisoryFirm, LicenceNumber = AFSL-12345"),
    (C_BLUE,  "2  Register Investor",
     "POST /api/v1/investor\nKYC fields: DateOfBirth, NationalityCountry, TIN\nPOST /api/v1/investor/{id}/documents → Passport"),
    (C_TEAL,  "3  Run AML Check",
     "PUT /api/v1/investor/{id}/aml\nAmlGatewayReference = FrankieOne entityId\nAmlStatus = Clear, AmlCheckedAt = now"),
    (C_TEAL,  "4  Authorise Advisor for Investor",
     "POST /api/v1/party/{advisorId}/relationships\nRelationshipType = AuthorizedToAdvise\nToPartyId = Investor's PartyId"),
    (C_NAVY,  "5  Create InvestmentAccount",
     "POST /api/v1/investment-account\nAccountType = Individual\n→ ABAC checks AuthorizedToAdvise ✓"),
    (C_NAVY,  "6  Link Investor as RegisteredHolder",
     "POST /api/v1/investment-account/{id}/parties\nRelationshipType = RegisteredHolder\nOwnershipPercentage = 100"),
    (RGBColor(0x6A,0x3F,0xB5), "7  Link Advisor to Account",
     "POST /api/v1/investment-account/{id}/advisors\nAdvisorPartyId = AdvisoryFirm\nRebateRate = 0.0055, EffectiveDate = today"),
    (C_AMBER, "8  Submit Subscription (Transaction)",
     "POST /api/v1/transaction (Transaction module)\n→ ICrmReader.IsInvestorKycApprovedAsync ✓\n→ ICrmReader.InvestmentAccountExistsAsync ✓"),
]
cols_layout = [(0.3, 1.42), (4.6, 1.42), (9.0, 1.42),
               (0.3, 3.32), (4.6, 3.32), (9.0, 3.32),
               (0.3, 5.22), (4.6, 5.22)]
for idx, (col, title, body) in enumerate(steps):
    if idx >= len(cols_layout):
        break
    x, y = cols_layout[idx]
    w = 4.1
    add_rect(sl, x, y, w, 0.38, fill=col)
    add_text(sl, title, x + 0.1, y + 0.04, w - 0.15, 0.32,
             size=11, bold=True, color=C_WHITE)
    add_rect(sl, x, y + 0.38, w, 1.5, fill=C_WHITE)
    add_bullet_box(sl, body.split("\n"), x + 0.1, y + 0.45,
                   w - 0.18, 1.35, size=9.5, color=C_DGREY)


# ═══════════════════════════════════════════════════════════════════════════
# SLIDE 12 — Implementation Roadmap
# ═══════════════════════════════════════════════════════════════════════════
sl = prs.slides.add_slide(BLANK)
slide_bg(sl)
header_bar(sl, "Implementation Roadmap", "7 phases · ~50 tasks")
footer(sl)

phases = [
    (C_BLUE,  "Phase 1",  "Domain",
     ["5 new enums", "5 new entities", "Enriched Investor", "5 repo interfaces", "Retire PartyInvestorRelationship"]),
    (C_TEAL,  "Phase 2",  "Application",
     ["~20 new commands/queries", "2 ABAC templates", "Policy seeds", "FluentValidation", "AutoMapper"]),
    (C_NAVY,  "Phase 3",  "Infrastructure",
     ["EF configs + migration", "5 new repositories", "Updated CrmReader", "Drop old table"]),
    (RGBColor(0x6A,0x3F,0xB5), "Phase 4", "Presentation",
     ["InvestmentAccount endpoints", "PartyRelationship endpoints", "AdvisorAccountLink endpoints", "InvestorDocument endpoints"]),
    (C_AMBER, "Phase 5", "Abstractions",
     ["Updated ICrmReader", "New DTOs + Events", "Non-breaking additions"]),
    (C_GREEN, "Phase 6", "Tests",
     ["9+ new test files", "Domain entity tests", "Handler tests", "Regression: Transaction module"]),
    (C_RED,   "Phase 7", "Docs",
     ["CLAUDE.md updates", "API endpoint list", "Test counts"]),
]
for i, (col, phase, name, items) in enumerate(phases):
    col_x = 0.3 + (i % 4) * 3.26
    row_y = 1.38 + (i // 4) * 3.35
    w, h = 3.05, 3.2
    add_rect(sl, col_x, row_y, w, 0.65, fill=col)
    add_text(sl, phase, col_x + 0.1, row_y + 0.04, 1.0, 0.28,
             size=11, color=RGBColor(0xDD,0xEE,0xFF))
    add_text(sl, name, col_x + 0.1, row_y + 0.3, w - 0.18, 0.3,
             size=13, bold=True, color=C_WHITE)
    add_rect(sl, col_x, row_y + 0.65, w, h - 0.65, fill=C_WHITE)
    add_bullet_box(sl, ["▸ " + it for it in items],
                   col_x + 0.12, row_y + 0.72, w - 0.2, h - 0.78,
                   size=10.5, color=C_DGREY)

# Commission deferred note
add_rect(sl, 0.3, 7.0, 12.7, 0.35, fill=RGBColor(0xFF,0xF3,0xCD))
add_text(sl, "⏳  Commission module deferred — RebateRate on AdvisorAccountLink covers current needs. "
             "See /docs/crm/taurus_inv_schema_analysis.md §9 for future scope.",
         0.5, 7.02, 12.3, 0.3, size=9.5, color=RGBColor(0x85,0x60,0x00))


# ═══════════════════════════════════════════════════════════════════════════
# SLIDE 13 — Open Questions
# ═══════════════════════════════════════════════════════════════════════════
sl = prs.slides.add_slide(BLANK)
slide_bg(sl)
header_bar(sl, "Open Questions", "To resolve before or during implementation")
footer(sl)

questions = [
    (C_BLUE,  "Joint Account — LinkOrder uniqueness",
     "For AccountType = Joint, should PartyAccountLink.LinkOrder be enforced unique per account "
     "(DB unique index) or treated as advisory only? Impacts EF migration and validation logic."),
    (C_TEAL,  "ABAC traversal — C# template vs Rego",
     "HasAdvisoryAuthorization must traverse Rep → Branch → Firm via PartyRelationship(ParentFirm). "
     "C# condition template has DB access. Rego is stateless. "
     "Prefer C# template for consistency with existing pattern — confirm?"),
    (C_AMBER, "PartyInvestorRelationship — data migration",
     "Current module has no production data, so the table can be dropped without a data migration script. "
     "Confirm this assumption before cutting the EF migration."),
    (C_NAVY,  "Investor ↔ Party identity — same entity or separate?",
     "Should Investor carry a PartyId FK (making it a 'role' of a Party, as in ChatGPT design)? "
     "Or remain independent? Current design keeps them separate. "
     "Changing this is a larger refactor — out of scope unless confirmed now."),
]
for i, (col, title, body) in enumerate(questions):
    x = 0.3 + (i % 2) * 6.5
    y = 1.38 + (i // 2) * 2.65
    add_rect(sl, x, y, 6.1, 0.42, fill=col)
    add_text(sl, f"Q{i+1}  {title}", x + 0.12, y + 0.05, 5.85, 0.35,
             size=12, bold=True, color=C_WHITE)
    add_rect(sl, x, y + 0.42, 6.1, 2.12, fill=C_WHITE)
    add_text(sl, body, x + 0.15, y + 0.52, 5.82, 1.9,
             size=11, color=C_DGREY, wrap=True)


# ═══════════════════════════════════════════════════════════════════════════
# SLIDE 14 — Summary
# ═══════════════════════════════════════════════════════════════════════════
sl = prs.slides.add_slide(BLANK)
add_rect(sl, 0, 0, 13.33, 7.5, fill=C_NAVY)
add_rect(sl, 0, 0, 0.55, 7.5, fill=C_BLUE)
add_rect(sl, 0.55, 2.2, 12.78, 0.06, fill=C_TEAL)

add_text(sl, "CRM V2 — Summary", 1.0, 0.5, 11, 0.75,
         size=32, bold=True, color=C_WHITE)

summary = [
    ("✓", "InvestmentAccount", "First-class entity between Party and Holdings"),
    ("✓", "PartyAccountLink",  "Replaces PartyInvestorRelationship — adds ownership %, link order, 5 relationship types"),
    ("✓", "PartyRelationship", "Party-to-Party for advisor hierarchy AND corporate investor structures"),
    ("✓", "AdvisorAccountLink","Advisor → Account with RebateRate; correct attachment point confirmed by Taurus"),
    ("✓", "Two-layer ABAC",    "AuthorizedToAdvise (pre-account) + AdvisorAccountLink (post-account)"),
    ("✓", "KYC Enrichment",    "FrankieOne + Taurus fields: PEP, AML, FATCA/CRS, TIN, documents"),
    ("⏳", "Commission module", "Deferred — RebateRate on relationship is sufficient for now"),
]
for i, (tick, title, desc) in enumerate(summary):
    y = 2.42 + i * 0.65
    col = C_TEAL if tick == "✓" else C_AMBER
    add_text(sl, tick, 0.9, y, 0.45, 0.5,
             size=18, bold=True, color=col, align=PP_ALIGN.CENTER)
    add_text(sl, title, 1.45, y + 0.05, 2.8, 0.38,
             size=13, bold=True, color=C_WHITE)
    add_text(sl, desc, 4.35, y + 0.05, 8.6, 0.38,
             size=12, color=RGBColor(0xB0,0xC8,0xF0))

add_text(sl, "Plan: /.claude/Plans/20260413-crm-v2-investment-account-party-relationship-kyc.md",
         0.9, 6.95, 11.5, 0.38,
         size=10, color=RGBColor(0x66,0x88,0xAA), italic=True)


# ── Save ─────────────────────────────────────────────────────────────────────
out = r"D:\IFX\docs\crm\IFX-CRM-V2-Design.pptx"
prs.save(out)
print(f"Saved: {out}")
print(f"Slides: {len(prs.slides)}")
