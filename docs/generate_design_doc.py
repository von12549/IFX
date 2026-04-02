"""
Generates the Fund Registry System design document (.docx).
Run: python docs/generate_design_doc.py
Output: docs/FundRegistrySystem-DetailDesign.docx
"""

from docx import Document
from docx.shared import Pt, RGBColor, Inches, Emu
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml.ns import qn
from docx.oxml import OxmlElement
import os

# ── colour palette ──────────────────────────────────────────────────────────
BLUE_DARK   = RGBColor(0x1F, 0x49, 0x7D)   # heading 1
BLUE_MID    = RGBColor(0x2E, 0x74, 0xB5)   # heading 2
BLUE_LIGHT  = RGBColor(0x5B, 0x9B, 0xD5)   # heading 3
GREY_TEXT   = RGBColor(0x40, 0x40, 0x40)
WHITE       = RGBColor(0xFF, 0xFF, 0xFF)
TABLE_HEADER= RGBColor(0x2E, 0x74, 0xB5)
TABLE_ALT   = RGBColor(0xDF, 0xEB, 0xF7)

# hex strings for XML shading (RGBColor is an int subclass, not a struct)
BLUE_DARK_HEX    = '1F497D'
BLUE_MID_HEX     = '2E74B5'
BLUE_LIGHT_HEX   = '5B9BD5'
TABLE_HEADER_HEX = '2E74B5'
TABLE_ALT_HEX    = 'DFEBF7'

# ── helpers ──────────────────────────────────────────────────────────────────

def set_cell_bg(cell, hex_color: str):
    tc   = cell._tc
    tcPr = tc.get_or_add_tcPr()
    shd  = OxmlElement('w:shd')
    shd.set(qn('w:val'),   'clear')
    shd.set(qn('w:color'), 'auto')
    shd.set(qn('w:fill'),  hex_color)
    tcPr.append(shd)


def set_cell_border(cell):
    tc   = cell._tc
    tcPr = tc.get_or_add_tcPr()
    borders = OxmlElement('w:tcBorders')
    for side in ('top', 'left', 'bottom', 'right'):
        b = OxmlElement(f'w:{side}')
        b.set(qn('w:val'),   'single')
        b.set(qn('w:sz'),    '4')
        b.set(qn('w:space'), '0')
        b.set(qn('w:color'), 'BFBFBF')
        borders.append(b)
    tcPr.append(borders)


def h1(doc, text):
    p = doc.add_heading(text, level=1)
    run = p.runs[0]
    run.font.color.rgb = WHITE
    run.font.size = Pt(16)
    run.font.bold = True
    pPr = p._p.get_or_add_pPr()
    shd = OxmlElement('w:shd')
    shd.set(qn('w:val'),   'clear')
    shd.set(qn('w:color'), 'auto')
    shd.set(qn('w:fill'),  BLUE_DARK_HEX)
    pPr.append(shd)
    p.paragraph_format.space_before = Pt(14)
    p.paragraph_format.space_after  = Pt(4)
    return p


def h2(doc, text):
    p = doc.add_heading(text, level=2)
    run = p.runs[0]
    run.font.color.rgb = BLUE_MID
    run.font.size = Pt(13)
    run.font.bold = True
    p.paragraph_format.space_before = Pt(10)
    p.paragraph_format.space_after  = Pt(3)
    return p


def h3(doc, text):
    p = doc.add_heading(text, level=3)
    run = p.runs[0]
    run.font.color.rgb = BLUE_LIGHT
    run.font.size = Pt(11)
    run.font.bold = True
    p.paragraph_format.space_before = Pt(8)
    p.paragraph_format.space_after  = Pt(2)
    return p


def body(doc, text):
    p = doc.add_paragraph(text)
    p.paragraph_format.space_after = Pt(6)
    for run in p.runs:
        run.font.color.rgb = GREY_TEXT
        run.font.size = Pt(10.5)
    return p


def bullet(doc, text, level=0):
    p = doc.add_paragraph(text, style='List Bullet')
    p.paragraph_format.left_indent = Inches(0.3 + level * 0.25)
    p.paragraph_format.space_after = Pt(2)
    for run in p.runs:
        run.font.size = Pt(10)
        run.font.color.rgb = GREY_TEXT
    return p


def code_block(doc, text):
    p = doc.add_paragraph()
    p.paragraph_format.left_indent  = Inches(0.4)
    p.paragraph_format.right_indent = Inches(0.4)
    p.paragraph_format.space_before = Pt(4)
    p.paragraph_format.space_after  = Pt(4)
    pPr = p._p.get_or_add_pPr()
    shd = OxmlElement('w:shd')
    shd.set(qn('w:val'),   'clear')
    shd.set(qn('w:color'), 'auto')
    shd.set(qn('w:fill'),  'F0F4F8')
    pPr.append(shd)
    run = p.add_run(text)
    run.font.name = 'Courier New'
    run.font.size = Pt(9)
    run.font.color.rgb = RGBColor(0x20, 0x20, 0x80)
    return p


def divider(doc):
    p = doc.add_paragraph()
    pPr = p._p.get_or_add_pPr()
    pBdr = OxmlElement('w:pBdr')
    bottom = OxmlElement('w:bottom')
    bottom.set(qn('w:val'),   'single')
    bottom.set(qn('w:sz'),    '6')
    bottom.set(qn('w:space'), '1')
    bottom.set(qn('w:color'), '2E74B5')
    pBdr.append(bottom)
    pPr.append(pBdr)
    p.paragraph_format.space_before = Pt(2)
    p.paragraph_format.space_after  = Pt(6)


def add_table(doc, headers, rows, col_widths=None):
    t = doc.add_table(rows=1 + len(rows), cols=len(headers))
    t.style = 'Table Grid'
    t.alignment = WD_TABLE_ALIGNMENT.LEFT

    # header row
    hdr_row = t.rows[0]
    for i, hdr in enumerate(headers):
        cell = hdr_row.cells[i]
        set_cell_bg(cell, TABLE_HEADER_HEX)
        set_cell_border(cell)
        cell.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
        p = cell.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.LEFT
        run = p.add_run(hdr)
        run.font.bold  = True
        run.font.color.rgb = WHITE
        run.font.size  = Pt(9.5)

    # data rows
    for r_idx, row_data in enumerate(rows):
        row = t.rows[r_idx + 1]
        bg  = TABLE_ALT_HEX if r_idx % 2 == 0 else 'FFFFFF'
        for c_idx, val in enumerate(row_data):
            cell = row.cells[c_idx]
            set_cell_bg(cell, bg)
            set_cell_border(cell)
            cell.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
            p = cell.paragraphs[0]
            run = p.add_run(str(val))
            run.font.size = Pt(9.5)
            run.font.color.rgb = GREY_TEXT

    # column widths
    if col_widths:
        for row in t.rows:
            for i, w in enumerate(col_widths):
                row.cells[i].width = Inches(w)

    doc.add_paragraph()   # spacing after table
    return t


def note_box(doc, text, colour='F0F7FF'):
    p = doc.add_paragraph()
    p.paragraph_format.left_indent  = Inches(0.3)
    p.paragraph_format.right_indent = Inches(0.3)
    p.paragraph_format.space_before = Pt(4)
    p.paragraph_format.space_after  = Pt(8)
    pPr = p._p.get_or_add_pPr()
    shd = OxmlElement('w:shd')
    shd.set(qn('w:val'),   'clear')
    shd.set(qn('w:color'), 'auto')
    shd.set(qn('w:fill'),  colour)
    pPr.append(shd)
    run = p.add_run('\u24d8  ' + text)
    run.font.size = Pt(9.5)
    run.font.color.rgb = RGBColor(0x1F, 0x49, 0x7D)
    run.font.italic = True
    return p


# ════════════════════════════════════════════════════════════════════════════
# DOCUMENT
# ════════════════════════════════════════════════════════════════════════════

doc = Document()

# ── page margins ─────────────────────────────────────────────────────────────
section = doc.sections[0]
section.top_margin    = Inches(0.9)
section.bottom_margin = Inches(0.9)
section.left_margin   = Inches(1.1)
section.right_margin  = Inches(1.1)

# ── default paragraph font ───────────────────────────────────────────────────
style = doc.styles['Normal']
style.font.name = 'Calibri'
style.font.size = Pt(10.5)

# ════════════════════════════════════════════════════════════════════════════
# COVER PAGE
# ════════════════════════════════════════════════════════════════════════════
doc.add_paragraph()
doc.add_paragraph()

cover_title = doc.add_paragraph()
cover_title.alignment = WD_ALIGN_PARAGRAPH.CENTER
r = cover_title.add_run('Fund Registry System')
r.font.size  = Pt(28)
r.font.bold  = True
r.font.color.rgb = BLUE_DARK

cover_sub = doc.add_paragraph()
cover_sub.alignment = WD_ALIGN_PARAGRAPH.CENTER
r = cover_sub.add_run('Detail Design Document')
r.font.size  = Pt(18)
r.font.color.rgb = BLUE_MID

doc.add_paragraph()
divider(doc)
doc.add_paragraph()

meta = [
    ('Modules', 'CRM · Registry · Holdings · Transaction'),
    ('Architecture', 'Clean Architecture — Modular Monolith'),
    ('Platform', 'ASP.NET Core 8 · Entity Framework Core 8 · MediatR'),
    ('Pattern', 'CQRS · Domain-Driven Design · Integration Events'),
    ('Version', '1.0'),
    ('Date', '2026-04-02'),
]
for label, value in meta:
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r1 = p.add_run(f'{label}:  ')
    r1.font.bold  = True
    r1.font.size  = Pt(11)
    r1.font.color.rgb = BLUE_DARK
    r2 = p.add_run(value)
    r2.font.size  = Pt(11)
    r2.font.color.rgb = GREY_TEXT

doc.add_page_break()

# ════════════════════════════════════════════════════════════════════════════
# 1. OVERVIEW
# ════════════════════════════════════════════════════════════════════════════
h1(doc, '1. Overview')

body(doc,
    'The Fund Registry System is a set of four bounded-context modules that together model '
    'the core business processes of a fund administration platform. Each module is an '
    'independently deployable unit within a modular monolith, sharing a single process but '
    'communicating only through well-defined abstractions and integration events.')

body(doc,
    'The four modules and their primary responsibilities are:')

add_table(doc,
    ['Module', 'Bounded Context', 'Primary Responsibility'],
    [
        ('CRM',         'Client Relationship Management', 'Manages Parties (intermediaries / distributors) and Investors including KYC status tracking.'),
        ('Registry',    'Fund Product Registry',          'Manages Fund master data and Fund Class definitions including fee structures and NAV frequency.'),
        ('Holdings',    'Unit Ledger',                    'Maintains the current unit balance per investor per class. Updated automatically via integration events.'),
        ('Transaction', 'Order Management',               'Captures, validates, processes, and settles subscription, redemption, transfer, and switch orders.'),
    ],
    col_widths=[1.2, 2.0, 3.3])

note_box(doc,
    'The modules depend on shared abstractions only — no module imports domain types from another. '
    'Cross-module business rules are enforced via reader interfaces (ICrmReader, IRegistryReader) '
    'and asynchronous integration events over an in-process event bus.')

divider(doc)

# ════════════════════════════════════════════════════════════════════════════
# 2. ARCHITECTURE
# ════════════════════════════════════════════════════════════════════════════
h1(doc, '2. Architecture')

h2(doc, '2.1 Layered Structure')

body(doc,
    'Every module follows Clean Architecture. Dependencies flow strictly inward — outer layers '
    'depend on inner layers, never the reverse.')

add_table(doc,
    ['Layer', 'Project Suffix', 'Responsibilities'],
    [
        ('Domain',          '.Domain',          'Entities, value objects, enums, domain logic, repository interfaces. Zero external dependencies.'),
        ('Application',     '.Application',     'CQRS commands/queries/handlers, DTOs, validators, AutoMapper profiles, IUnitOfWork, ICurrentUser.'),
        ('Infrastructure',  '.Infrastructure',  'EF Core DbContext, repository implementations, DI registration (IModuleInstaller), DB schema creation.'),
        ('Presentation',    '.Presentation',    'Minimal API endpoint extensions, request/response mapping, HTTP concerns.'),
        ('Composition',     '.Composition',     'Wires all layers together; referenced only by ApiHost.'),
        ('Abstractions',    '.Abstractions',    'Public contracts (integration events, DTOs, reader interfaces) consumed by other modules without coupling.'),
    ],
    col_widths=[1.5, 1.8, 3.2])

h2(doc, '2.2 Module Dependency Graph')

body(doc, 'The only cross-module dependencies are through the .Abstractions projects:')

code_block(doc,
'Transaction.Application\n'
'  ├── IFX.Modules.CRM.Abstractions      (ICrmReader, IsInvestorKycApprovedAsync, PartyExistsAsync)\n'
'  └── IFX.Modules.Registry.Abstractions (IRegistryReader, IsClassOpenForSubscriptionAsync)\n\n'
'Holdings.Application\n'
'  └── IFX.Modules.Transaction.Abstractions  (TransactionProcessedEvent)\n\n'
'No module imports Domain or Application types from another module.')

h2(doc, '2.3 Shared Building Blocks')

add_table(doc,
    ['Project', 'Contents'],
    [
        ('IFX.BuildingBlocks.Domain',   'BaseEntity (Id, Equals, ==), IAuditableEntity (CreatedBy, UpdatedBy, CreatedAt, UpdatedAt). All domain entities inherit from these.'),
        ('IFX.BuildingBlocks.Security', 'ICurrentUser, IResourceAuthorizationService, OpaResourceAttributesBase — shared auth abstractions.'),
        ('IFX.Platform.Messaging.Abstractions', 'IIntegrationEvent, IIntegrationEventBus, IIntegrationEventHandler<T> — event bus contracts.'),
    ],
    col_widths=[2.4, 4.1])

h2(doc, '2.4 Multi-Tenancy')

body(doc,
    'All entities carry a TenantId field. Handlers read TenantId from ICurrentUser.TenantId, '
    'populated from the X-Tenant-Id HTTP request header. Every repository query filters by '
    'TenantId to ensure tenant data isolation. No cross-tenant data access is possible through '
    'these modules without explicitly using a platform-level override.')

divider(doc)

# ════════════════════════════════════════════════════════════════════════════
# 3. CRM MODULE
# ════════════════════════════════════════════════════════════════════════════
h1(doc, '3. CRM Module')

body(doc,
    'The CRM module manages client-facing entities: Parties (legal entities that act as '
    'intermediaries or distributors) and Investors (the end beneficial owners of fund units). '
    'A many-to-many relationship links Parties to Investors.')

h2(doc, '3.1 Domain Entities')

h3(doc, 'Party')

body(doc,
    'Represents a legal entity that interacts with the fund on behalf of investors '
    '(e.g. a fund manager, distributor, custodian, or transfer agent).')

add_table(doc,
    ['Property', 'Type', 'Description'],
    [
        ('Id',          'Guid',        'Sequential UUID v7 — primary key.'),
        ('TenantId',    'Guid',        'Tenant isolation key.'),
        ('PartyCode',   'string',      'Unique code within tenant (trimmed on creation).'),
        ('Name',        'string',      'Display name (trimmed on creation and update).'),
        ('Type',        'PartyType',   'FundManager | Distributor | Custodian | TransferAgent | Other'),
        ('Status',      'EntityStatus','Active | Closed. Defaults to Active.'),
        ('CreatedBy',   'Guid?',       'UserId who created the record.'),
        ('UpdatedBy',   'Guid?',       'UserId who last updated the record.'),
        ('CreatedAt',   'DateTime',    'UTC timestamp — set automatically on save.'),
        ('UpdatedAt',   'DateTime',    'UTC timestamp — updated automatically on save.'),
    ],
    col_widths=[1.4, 1.2, 3.9])

body(doc, 'Business rules enforced in the domain:')
bullet(doc, 'PartyCode and Name cannot be empty or whitespace.')
bullet(doc, 'TenantId cannot be empty Guid.')
bullet(doc, 'Update() rejects empty name.')
bullet(doc, 'Close() is a terminal transition — there is no Reopen.')

h3(doc, 'Investor')

body(doc,
    'Represents a beneficial owner who holds fund units. Carries KYC (Know Your Customer) '
    'status, which must be Approved before the investor can subscribe to a fund class.')

add_table(doc,
    ['Property', 'Type', 'Description'],
    [
        ('Id',               'Guid',         'Sequential UUID v7 — primary key.'),
        ('TenantId',         'Guid',         'Tenant isolation key.'),
        ('InvestorCode',     'string',        'Unique code within tenant.'),
        ('Name',             'string',        'Full name.'),
        ('Type',             'InvestorType',  'Individual | Corporate | Institutional'),
        ('KycStatus',        'KycStatus',     'Pending | Approved | Rejected. Defaults to Pending.'),
        ('KycReviewedAt',    'DateTime?',     'Timestamp of last KYC status change.'),
        ('ResidencyCountry', 'string',        'ISO country code — stored as uppercase.'),
        ('TaxResidency',     'string',        'ISO country code — stored as uppercase.'),
        ('Status',           'EntityStatus',  'Active | Closed.'),
    ],
    col_widths=[1.6, 1.3, 3.6])

body(doc, 'Business rules:')
bullet(doc, 'ResidencyCountry and TaxResidency are normalised to uppercase via ToUpperInvariant().')
bullet(doc, 'UpdateKyc(status) sets KycReviewedAt = DateTime.UtcNow automatically.')
bullet(doc, 'An investor with KycStatus != Approved cannot subscribe (enforced in Transaction Application layer).')

h3(doc, 'PartyInvestorRelationship')

body(doc,
    'A join entity representing a many-to-many link between Party and Investor within the same tenant. '
    'The relationship type (e.g. Introducer, Nominee, Discretionary) is stored on the link.')

h2(doc, '3.2 Repository Interfaces')

add_table(doc,
    ['Interface', 'Key Methods'],
    [
        ('IPartyRepository',            'GetByIdAsync(id, tenantId), GetByTenantIdAsync, CodeExistsAsync, AddAsync, Remove'),
        ('IInvestorRepository',         'GetByIdAsync(id, tenantId), GetByTenantIdAsync, GetByPartyIdAsync, CodeExistsAsync, AddAsync, Remove'),
        ('IPartyInvestorRepository',    'GetByPartyIdAsync, GetByInvestorIdAsync, ExistsAsync, AddAsync, Remove'),
    ],
    col_widths=[2.2, 4.3])

h2(doc, '3.3 Commands & Queries')

add_table(doc,
    ['Operation', 'Type', 'Description'],
    [
        ('CreatePartyCommand',              'Command', 'Validates uniqueness of PartyCode, creates Party, publishes PartyCreatedEvent.'),
        ('UpdatePartyCommand',              'Command', 'Loads by id+tenantId, calls party.Update(), saves.'),
        ('DeletePartyCommand',              'Command', 'Loads party, calls party.Close() (soft delete).'),
        ('GetPartiesQuery',                 'Query',   'Returns all parties for the current tenant.'),
        ('GetPartyByIdQuery',               'Query',   'Returns a single party or 404.'),
        ('CreateInvestorCommand',           'Command', 'Validates InvestorCode uniqueness, creates Investor, publishes InvestorCreatedEvent.'),
        ('UpdateInvestorCommand',           'Command', 'Updates name, type, residency fields.'),
        ('UpdateInvestorKycCommand',        'Command', 'Calls investor.UpdateKyc(), publishes InvestorKycStatusChangedEvent with old and new status.'),
        ('DeleteInvestorCommand',           'Command', 'Calls investor.Close().'),
        ('GetInvestorsQuery',               'Query',   'Returns all investors for the current tenant.'),
        ('GetInvestorsByPartyQuery',        'Query',   'Returns investors linked to a specific party.'),
        ('LinkInvestorToPartyCommand',      'Command', 'Creates PartyInvestorRelationship.'),
        ('UnlinkInvestorFromPartyCommand',  'Command', 'Removes PartyInvestorRelationship.'),
    ],
    col_widths=[2.8, 0.9, 2.8])

h2(doc, '3.4 Integration Events Published')

add_table(doc,
    ['Event', 'Payload', 'Consumers'],
    [
        ('PartyCreatedEvent',               'PartyId, TenantId, PartyCode, Name',                       'None currently (available for future audit/notification)'),
        ('InvestorCreatedEvent',            'InvestorId, TenantId, InvestorCode, Name',                 'None currently'),
        ('InvestorKycStatusChangedEvent',   'InvestorId, TenantId, OldStatus, NewStatus',               'None currently (available for notification workflows)'),
    ],
    col_widths=[2.2, 2.5, 1.8])

h2(doc, '3.5 API Endpoints')

add_table(doc,
    ['Method', 'Route', 'Description'],
    [
        ('GET',    '/api/v1/party',                          'List all parties (tenant-scoped).'),
        ('POST',   '/api/v1/party',                          'Create a party.'),
        ('GET',    '/api/v1/party/{id}',                     'Get party by ID.'),
        ('PUT',    '/api/v1/party/{id}',                     'Update party.'),
        ('DELETE', '/api/v1/party/{id}',                     'Close (soft-delete) party.'),
        ('GET',    '/api/v1/party/{id}/investors',           'List investors linked to party.'),
        ('POST',   '/api/v1/party/{id}/investors/{invId}',   'Link investor to party.'),
        ('DELETE', '/api/v1/party/{id}/investors/{invId}',   'Unlink investor from party.'),
        ('GET',    '/api/v1/investor',                       'List all investors (tenant-scoped).'),
        ('POST',   '/api/v1/investor',                       'Create an investor.'),
        ('GET',    '/api/v1/investor/{id}',                  'Get investor by ID.'),
        ('PUT',    '/api/v1/investor/{id}',                  'Update investor.'),
        ('DELETE', '/api/v1/investor/{id}',                  'Close investor.'),
        ('PUT',    '/api/v1/investor/{id}/kyc',              'Update KYC status.'),
    ],
    col_widths=[0.7, 3.0, 2.8])

divider(doc)

# ════════════════════════════════════════════════════════════════════════════
# 4. REGISTRY MODULE
# ════════════════════════════════════════════════════════════════════════════
h1(doc, '4. Registry Module')

body(doc,
    'The Registry module is the authoritative source of truth for fund product data. '
    'It stores Fund master records and the individual share classes (Fund Classes) that '
    'investors can subscribe to. The Registry exposes IRegistryReader to other modules '
    'so they can check class availability without creating a hard dependency.')

h2(doc, '4.1 Domain Entities')

h3(doc, 'Fund')

body(doc,
    'The top-level fund product. A fund can have multiple classes with different '
    'currencies, fee structures, and NAV frequencies.')

add_table(doc,
    ['Property', 'Type', 'Description'],
    [
        ('Id',            'Guid',       'Sequential UUID v7.'),
        ('TenantId',      'Guid',       'Tenant isolation key.'),
        ('FundCode',      'string',     'Unique code within tenant — stored uppercase.'),
        ('FundName',      'string',     'Display name.'),
        ('FundType',      'FundType',   'UCITS | AIF | Hedge | ETF | PrivateEquity | Other'),
        ('BaseCurrency',  'string',     '3-letter ISO 4217 code — stored uppercase. Validated on creation and update.'),
        ('InceptionDate', 'DateOnly',   'Date the fund was launched.'),
        ('Status',        'FundStatus', 'Active | Closed.'),
    ],
    col_widths=[1.5, 1.2, 3.8])

body(doc, 'Business rules:')
bullet(doc, 'BaseCurrency must be exactly 3 characters (ISO 4217 validation).')
bullet(doc, 'FundCode is normalised to uppercase via ToUpperInvariant().')
bullet(doc, 'Close() is a terminal transition.')

h3(doc, 'FundClass')

body(doc,
    'Represents a share class within a fund. Each class can have its own currency, '
    'fee structure, minimum investment, and NAV calculation frequency.')

add_table(doc,
    ['Property', 'Type', 'Description'],
    [
        ('Id',                   'Guid',          'Sequential UUID v7.'),
        ('FundId',               'Guid',          'FK to parent Fund.'),
        ('TenantId',             'Guid',          'Tenant isolation key.'),
        ('ClassCode',            'string',        'Unique code within fund — stored uppercase.'),
        ('ClassName',            'string',        'Display name.'),
        ('Currency',             'string',        '3-letter ISO 4217 currency code.'),
        ('MinInitialInvestment', 'decimal?',      'Minimum investment amount. Null if no minimum.'),
        ('ManagementFeeRate',    'decimal?',      'Annual management fee as a decimal (e.g. 0.015 = 1.5%).'),
        ('PerformanceFeeRate',   'decimal?',      'Performance fee rate. Null if not applicable.'),
        ('NavFrequency',         'NavFrequency',  'Daily | Weekly | Monthly | Quarterly | Annual'),
        ('Status',               'ClassStatus',   'Active | Closed.'),
    ],
    col_widths=[1.8, 1.2, 3.5])

body(doc, 'Business rules:')
bullet(doc, 'Currency must be exactly 3 characters.')
bullet(doc, 'IsOpenForSubscription() returns true only when Status == Active.')
bullet(doc, 'Update() sets optional fee/investment fields (can be null).')

h2(doc, '4.2 Commands & Queries')

add_table(doc,
    ['Operation', 'Type', 'Description'],
    [
        ('CreateFundCommand',       'Command', 'Validates FundCode uniqueness, creates Fund, publishes FundCreatedEvent.'),
        ('UpdateFundCommand',       'Command', 'Updates FundName, FundType, BaseCurrency.'),
        ('DeleteFundCommand',       'Command', 'Calls fund.Close().'),
        ('GetFundsQuery',           'Query',   'Returns all funds for current tenant.'),
        ('GetFundByIdQuery',        'Query',   'Returns single fund with its classes.'),
        ('CreateClassCommand',      'Command', 'Validates ClassCode uniqueness within fund, creates FundClass, publishes FundClassCreatedEvent.'),
        ('UpdateClassCommand',      'Command', 'Updates ClassName, Currency, fee fields, NavFrequency.'),
        ('DeleteClassCommand',      'Command', 'Calls fundClass.Close().'),
        ('GetClassesQuery',         'Query',   'Returns all classes for a fund.'),
        ('GetClassByIdQuery',       'Query',   'Returns single class.'),
    ],
    col_widths=[2.4, 0.9, 3.2])

h2(doc, '4.3 IRegistryReader (Abstraction)')

body(doc,
    'Published in IFX.Modules.Registry.Abstractions, consumed by the Transaction module '
    'without creating a direct project dependency:')

code_block(doc,
'public interface IRegistryReader\n'
'{\n'
'    Task<bool> IsClassOpenForSubscriptionAsync(Guid classId, Guid tenantId, CancellationToken ct);\n'
'    Task<bool> FundExistsAsync(Guid fundId, Guid tenantId, CancellationToken ct);\n'
'}')

h2(doc, '4.4 Integration Events Published')

add_table(doc,
    ['Event', 'Payload'],
    [
        ('FundCreatedEvent',        'FundId, TenantId, FundCode, FundName'),
        ('FundClassCreatedEvent',   'ClassId, FundId, TenantId, ClassCode, ClassName'),
        ('ClassStatusChangedEvent', 'ClassId, FundId, TenantId, OldStatus, NewStatus'),
    ],
    col_widths=[2.2, 4.3])

note_box(doc,
    'ClassStatusChangedEvent is consumed by the Holdings module. When a class transitions '
    'to Closed or Liquidating, Holdings automatically freezes all unit balances in that class.')

h2(doc, '4.5 API Endpoints')

add_table(doc,
    ['Method', 'Route', 'Description'],
    [
        ('GET',    '/api/v1/fund',                         'List all funds (tenant-scoped).'),
        ('POST',   '/api/v1/fund',                         'Create a fund.'),
        ('GET',    '/api/v1/fund/{id}',                    'Get fund by ID.'),
        ('PUT',    '/api/v1/fund/{id}',                    'Update fund.'),
        ('DELETE', '/api/v1/fund/{id}',                    'Close fund.'),
        ('GET',    '/api/v1/fund/{fundId}/class',          'List all classes for a fund.'),
        ('POST',   '/api/v1/fund/{fundId}/class',          'Create a fund class.'),
        ('GET',    '/api/v1/fund/{fundId}/class/{id}',     'Get class by ID.'),
        ('PUT',    '/api/v1/fund/{fundId}/class/{id}',     'Update class.'),
        ('DELETE', '/api/v1/fund/{fundId}/class/{id}',     'Close class.'),
    ],
    col_widths=[0.7, 3.0, 2.8])

divider(doc)

# ════════════════════════════════════════════════════════════════════════════
# 5. HOLDINGS MODULE
# ════════════════════════════════════════════════════════════════════════════
h1(doc, '5. Holdings Module')

body(doc,
    'The Holdings module maintains the unit ledger — the current balance of units held by each '
    'investor in each fund class. It is a read-mostly module that is updated exclusively through '
    'integration events published by the Transaction module. No direct write endpoints exist for '
    'Holdings; all mutations are event-driven.')

h2(doc, '5.1 Domain Entity: Holding')

add_table(doc,
    ['Property', 'Type', 'Description'],
    [
        ('Id',                'Guid',          'Sequential UUID v7.'),
        ('TenantId',          'Guid',          'Tenant isolation key.'),
        ('InvestorId',        'Guid',          'FK to the investor.'),
        ('ClassId',           'Guid',          'FK to the fund class.'),
        ('Units',             'decimal',       'Current unit balance. Starts at 0. Never negative.'),
        ('Status',            'HoldingStatus', 'Active | Frozen | Closed.'),
        ('LastTransactionAt', 'DateTime?',     'Timestamp of the last unit movement.'),
    ],
    col_widths=[1.7, 1.3, 3.5])

h2(doc, '5.2 Domain Methods')

add_table(doc,
    ['Method', 'Description'],
    [
        ('ApplySubscription(units)',  'Adds units to the balance. Units must be > 0. Updates LastTransactionAt.'),
        ('ApplyRedemption(units)',    'Subtracts units. Validates units > 0 and units <= current balance. If resulting balance == 0, transitions Status to Closed.'),
        ('ApplyTransfer(units)',      'Delegates to ApplyRedemption (transfer-out from this class).'),
        ('Freeze()',                  'Transitions Active → Frozen. No-op if already Frozen or Closed.'),
        ('Unfreeze()',                'Transitions Frozen → Active. No-op if not Frozen.'),
    ],
    col_widths=[2.2, 4.3])

h2(doc, '5.3 Event Handlers')

h3(doc, 'TransactionProcessedEventHandler')

body(doc,
    'Subscribes to TransactionProcessedEvent (published by Transaction module after NAV processing). '
    'Applies the unit movement to the holding ledger:')

add_table(doc,
    ['Transaction Type', 'Holdings Action'],
    [
        ('Subscription', 'Upsert holding (create if not exists), call ApplySubscription(units).'),
        ('Redemption',   'Load holding, call ApplyRedemption(units).'),
        ('Transfer',     'Load source holding → ApplyTransfer(units). Upsert target class holding → ApplySubscription(units).'),
        ('Switch',       'Same as Transfer — source class decremented, target class incremented.'),
    ],
    col_widths=[1.8, 4.7])

h3(doc, 'ClassStatusChangedEventHandler')

body(doc,
    'Subscribes to ClassStatusChangedEvent from the Registry module. '
    'When the new status is "Closed" or "Liquidating", loads all active holdings '
    'for that class and calls Freeze() on each one. This prevents further transactions '
    'against the class while it is being wound down.')

h2(doc, '5.4 API Endpoints (Read-Only)')

add_table(doc,
    ['Method', 'Route', 'Description'],
    [
        ('GET', '/api/v1/holding',                                   'List all holdings for current tenant.'),
        ('GET', '/api/v1/holding/{id}',                              'Get a single holding by ID.'),
        ('GET', '/api/v1/investor/{investorId}/holdings',            'List all holdings for a specific investor.'),
        ('GET', '/api/v1/fund/{fundId}/class/{classId}/holdings',    'List all holdings in a specific fund class.'),
    ],
    col_widths=[0.7, 3.5, 2.3])

note_box(doc,
    'Holdings has no POST/PUT/DELETE endpoints. All writes are performed by event handlers. '
    'This enforces the invariant that the unit ledger can only change as a result of a '
    'processed transaction.')

divider(doc)

# ════════════════════════════════════════════════════════════════════════════
# 6. TRANSACTION MODULE
# ════════════════════════════════════════════════════════════════════════════
h1(doc, '6. Transaction Module')

body(doc,
    'The Transaction module captures and manages the lifecycle of fund orders. '
    'It is the most orchestration-heavy module, performing cross-module validation '
    'before creating an order and publishing integration events to trigger downstream '
    'updates in Holdings.')

h2(doc, '6.1 Domain Entity: Transaction')

add_table(doc,
    ['Property', 'Type', 'Description'],
    [
        ('Id',              'Guid',              'Sequential UUID v7.'),
        ('TenantId',        'Guid',              'Tenant isolation key.'),
        ('Type',            'TransactionType',   'Subscription | Redemption | Transfer | Switch'),
        ('PartyId',         'Guid',              'The party acting on behalf of the investor.'),
        ('InvestorId',      'Guid',              'The beneficial owner of the units.'),
        ('FundId',          'Guid',              'The fund the order belongs to.'),
        ('ClassId',         'Guid',              'The source (or only) class.'),
        ('TargetClassId',   'Guid?',             'The destination class for Transfer and Switch. Null for Subscription/Redemption.'),
        ('Amount',          'decimal',           'Cash amount of the order. Must be > 0.'),
        ('Units',           'decimal?',          'Calculated units = Amount / NAVPrice. Null until processed.'),
        ('NAVPrice',        'decimal?',          'Net Asset Value per unit applied at processing. Null until processed.'),
        ('TradeDate',       'DateOnly',          'Date the order was placed.'),
        ('SettlementDate',  'DateOnly?',         'Date the order settled. Set by Settle().'),
        ('Status',          'TransactionStatus', 'Pending | Processing | Processed | Settled | Cancelled | Failed'),
        ('FailureReason',   'string?',           'Reason text set by Cancel() or Fail().'),
    ],
    col_widths=[1.6, 1.5, 3.4])

h2(doc, '6.2 Transaction State Machine')

body(doc, 'The transaction lifecycle follows a strict state machine enforced in the domain:')

code_block(doc,
'                    ┌──────────────────────────────────────────┐\n'
'                    │                                          │\n'
'              [Created]                                   Cancel()\n'
'                    │                                          │\n'
'               Pending ──── Process(navPrice) ──► Processed ──┤\n'
'                  │  │                               │         │\n'
'              Cancel() │                          Settle()  Fail()\n'
'                  │    │                               │         │\n'
'            Cancelled  │                           Settled   Failed\n'
'                       │\n'
'                    Fail()\n'
'                       │\n'
'                    Failed')

body(doc, 'Guard conditions:')
bullet(doc, 'Process(): status must be Pending or Processing. NAVPrice must be > 0.')
bullet(doc, 'Cancel(): cannot cancel a Settled, Cancelled, or Failed transaction.')
bullet(doc, 'Settle(): status must be Processed.')
bullet(doc, 'Fail(): can be called from any status (emergency override).')

h2(doc, '6.3 Factory Methods')

add_table(doc,
    ['Method', 'Type', 'TargetClassId'],
    [
        ('CreateSubscription(tenantId, partyId, investorId, fundId, classId, amount, tradeDate)',                      'Subscription', 'null'),
        ('CreateRedemption(tenantId, partyId, investorId, fundId, classId, amount, tradeDate)',                        'Redemption',   'null'),
        ('CreateTransfer(tenantId, partyId, investorId, fundId, classId, targetClassId, amount, tradeDate)',           'Transfer',     'required'),
        ('CreateSwitch(tenantId, partyId, investorId, fundId, classId, targetClassId, amount, tradeDate)',             'Switch',       'required'),
    ],
    col_widths=[3.8, 1.2, 1.5])

h2(doc, '6.4 Commands & Handlers')

add_table(doc,
    ['Command', 'Pre-conditions Checked', 'Outcome'],
    [
        ('CreateSubscriptionCommand',  'KYC approved, class open, party exists',         'Creates Pending transaction, publishes TransactionCreatedEvent.'),
        ('CreateRedemptionCommand',    'Investor exists, class open for redemption',      'Creates Pending redemption transaction.'),
        ('CreateTransferCommand',      'Source class exists, target class open',          'Creates Pending transfer with TargetClassId.'),
        ('CreateSwitchCommand',        'Both classes exist, target open for subscription','Creates Pending switch.'),
        ('ProcessTransactionCommand',  'Transaction is Pending, tenant matches',          'Calls tx.Process(navPrice), publishes TransactionProcessedEvent.'),
        ('CancelTransactionCommand',   'Transaction not Settled/Cancelled/Failed',        'Calls tx.Cancel(reason).'),
    ],
    col_widths=[2.2, 2.3, 2.0])

h2(doc, '6.5 Cross-Module Validation')

body(doc,
    'Before creating a subscription, the handler calls two reader interfaces '
    '(injected from CRM and Registry Abstractions):')

code_block(doc,
'// CRM check — investor must have KYC Approved\n'
'bool kycOk = await _crmReader.IsInvestorKycApprovedAsync(request.InvestorId, tenantId, ct);\n'
'if (!kycOk) return Result.Failure("Investor KYC is not approved.");\n\n'
'// Registry check — class must be Active (open for subscription)\n'
'bool classOk = await _registryReader.IsClassOpenForSubscriptionAsync(request.ClassId, tenantId, ct);\n'
'if (!classOk) return Result.Failure("Fund class is not open for subscription.");\n\n'
'// CRM check — party must exist\n'
'bool partyOk = await _crmReader.PartyExistsAsync(request.PartyId, tenantId, ct);\n'
'if (!partyOk) return Result.Failure("Party not found.");')

note_box(doc,
    'These checks are performed at the Application layer via interfaces, keeping the Domain '
    'layer free of cross-module knowledge. The Infrastructure layer implements the readers '
    'by querying the respective databases directly (same process, separate DbContexts).')

h2(doc, '6.6 Integration Events Published')

add_table(doc,
    ['Event', 'Payload', 'Consumer'],
    [
        ('TransactionCreatedEvent',   'TransactionId, TenantId, Type, InvestorId, ClassId, Amount',                                   'None currently (audit/notification)'),
        ('TransactionProcessedEvent', 'TransactionId, TenantId, Type, InvestorId, ClassId, TargetClassId, Units, NAVPrice',           'Holdings module — updates unit balances'),
        ('TransactionCancelledEvent', 'TransactionId, TenantId, Type, InvestorId, ClassId, Reason',                                   'None currently'),
    ],
    col_widths=[2.2, 3.0, 1.3])

h2(doc, '6.7 Unit Calculation')

body(doc,
    'When a transaction is processed, units are calculated as:')

code_block(doc,
'Units = Math.Round(Amount / NAVPrice, 8)\n\n'
'Example: Amount = 10,000.00, NAVPrice = 12.50\n'
'         Units  = Math.Round(10000 / 12.50, 8) = 800.00000000')

h2(doc, '6.8 API Endpoints')

add_table(doc,
    ['Method', 'Route', 'Description'],
    [
        ('GET',  '/api/v1/transaction',                      'List all transactions (tenant-scoped).'),
        ('GET',  '/api/v1/transaction/{id}',                 'Get a single transaction by ID.'),
        ('POST', '/api/v1/transaction/subscription',         'Create a subscription order.'),
        ('POST', '/api/v1/transaction/redemption',           'Create a redemption order.'),
        ('POST', '/api/v1/transaction/transfer',             'Create a transfer order.'),
        ('POST', '/api/v1/transaction/switch',               'Create a switch order.'),
        ('POST', '/api/v1/transaction/{id}/process',         'Process a pending order (apply NAV price).'),
        ('POST', '/api/v1/transaction/{id}/cancel',          'Cancel a pending or processing order.'),
    ],
    col_widths=[0.7, 2.8, 3.0])

divider(doc)

# ════════════════════════════════════════════════════════════════════════════
# 7. CROSS-MODULE RELATIONSHIPS
# ════════════════════════════════════════════════════════════════════════════
h1(doc, '7. Cross-Module Relationships')

h2(doc, '7.1 Entity Relationship Overview')

body(doc,
    'The four modules have logical relationships but no foreign key constraints between their '
    'databases. Referential integrity is maintained by application-level validation:')

code_block(doc,
'CRM                      Registry                  Transaction           Holdings\n'
'─────────────────────    ─────────────────────     ─────────────────     ─────────────────\n'
'Party (1)                Fund (1)                  Transaction (1)       Holding (1)\n'
'  └── PartyInvestor(*)     └── FundClass (*)         ├── PartyId  ──────►  ├── InvestorId\n'
'        │                        │                   ├── InvestorId ─────►  └── ClassId\n'
'Investor (1) ◄────────────────── │                   ├── FundId\n'
'                                 │                   ├── ClassId  ────────►\n'
'                                 │                   └── TargetClassId ──►\n'
'(IDs stored as Guids — no DB-level FK constraints across module boundaries)')

h2(doc, '7.2 End-to-End Subscription Flow')

body(doc, 'A complete subscription from API call to updated unit balance:')

add_table(doc,
    ['Step', 'Actor', 'Action'],
    [
        ('1', 'Client',              'POST /api/v1/transaction/subscription with investorId, classId, partyId, amount, tradeDate. Header: X-Tenant-Id.'),
        ('2', 'Transaction API',     'Dispatches CreateSubscriptionCommand via MediatR.'),
        ('3', 'Handler',             'Calls _crmReader.IsInvestorKycApprovedAsync() — verifies KYC = Approved.'),
        ('4', 'Handler',             'Calls _registryReader.IsClassOpenForSubscriptionAsync() — verifies class Status = Active.'),
        ('5', 'Handler',             'Calls _crmReader.PartyExistsAsync() — verifies party exists in tenant.'),
        ('6', 'Transaction Domain',  'Transaction.CreateSubscription() constructs entity with Status = Pending.'),
        ('7', 'Handler',             'Saves to transaction DB. Publishes TransactionCreatedEvent.'),
        ('8', 'Client (ops)',        'POST /api/v1/transaction/{id}/process with navPrice when NAV is available.'),
        ('9', 'Transaction Domain',  'tx.Process(navPrice) calculates Units = Amount / navPrice, sets Status = Processed.'),
        ('10','Handler',             'Saves updated transaction. Publishes TransactionProcessedEvent(units, navPrice).'),
        ('11','Holdings Handler',    'TransactionProcessedEventHandler receives event. Upserts Holding for (investorId, classId). Calls ApplySubscription(units).'),
        ('12','Holdings DB',         'Holding.Units incremented. LastTransactionAt updated.'),
    ],
    col_widths=[0.4, 1.8, 4.3])

h2(doc, '7.3 Transfer / Switch Flow')

body(doc,
    'Transfer and Switch are two-sided transactions affecting two fund classes:')

add_table(doc,
    ['Step', 'Action'],
    [
        ('1', 'Client posts CreateTransferCommand with classId (source) and targetClassId (destination).'),
        ('2', 'Transaction is created with Type = Transfer (or Switch), both class IDs stored.'),
        ('3', 'On ProcessTransaction: TransactionProcessedEvent includes both ClassId and TargetClassId.'),
        ('4', 'Holdings handler: loads source holding → calls ApplyTransfer(units) → decrements balance.'),
        ('5', 'Holdings handler: upserts target holding → calls ApplySubscription(units) → increments balance.'),
        ('6', 'If source balance reaches zero, source Holding.Status is automatically set to Closed.'),
    ],
    col_widths=[0.4, 6.1])

h2(doc, '7.4 Integration Event Bus')

body(doc,
    'All events are published and consumed via IIntegrationEventBus. The default implementation '
    'is InMemoryIntegrationEventBus (in-process, synchronous). This can be replaced with a '
    'message broker (RabbitMQ, Azure Service Bus) by swapping the DI registration without '
    'changing any module code.')

code_block(doc,
'// Publishing (Transaction module)\n'
'await _eventBus.PublishAsync(new TransactionProcessedEvent(...), ct);\n\n'
'// Subscribing (Holdings module DependencyInjection.cs)\n'
'services.AddScoped<IIntegrationEventHandler<TransactionProcessedEvent>,\n'
'                   TransactionProcessedEventHandler>();')

divider(doc)

# ════════════════════════════════════════════════════════════════════════════
# 8. DATABASE SCHEMA
# ════════════════════════════════════════════════════════════════════════════
h1(doc, '8. Database Schema')

h2(doc, '8.1 Schema Separation')

body(doc,
    'Each module owns its own database schema to enforce module boundary isolation at the '
    'storage layer. All tables are created via EnsureCreatedAsync() at application startup '
    '(new modules do not use EF Core migrations).')

add_table(doc,
    ['Module', 'DB Schema', 'Tables'],
    [
        ('CRM',         '"crm"',         'crm.Parties, crm.Investors, crm.PartyInvestorRelationships'),
        ('Registry',    '"registry"',    'registry.Funds, registry.FundClasses'),
        ('Holdings',    '"holdings"',    'holdings.Holdings'),
        ('Transaction', '"transaction"', 'transaction.Transactions'),
    ],
    col_widths=[1.2, 1.3, 4.0])

h2(doc, '8.2 Audit Columns')

body(doc,
    'All entities implement IAuditableEntity. The DbContext SaveChangesAsync override '
    'automatically sets CreatedAt and UpdatedAt:')

code_block(doc,
'public override Task<int> SaveChangesAsync(CancellationToken ct = default)\n'
'{\n'
'    foreach (var entry in ChangeTracker.Entries<IAuditableEntity>())\n'
'    {\n'
'        if (entry.State == EntityState.Added)\n'
'        {\n'
'            entry.Entity.CreatedAt = DateTime.UtcNow;\n'
'            entry.Entity.UpdatedAt = DateTime.UtcNow;\n'
'        }\n'
'        else if (entry.State == EntityState.Modified)\n'
'        {\n'
'            entry.Entity.UpdatedAt = DateTime.UtcNow;\n'
'        }\n'
'    }\n'
'    return base.SaveChangesAsync(ct);\n'
'}')

h2(doc, '8.3 ID Generation')

body(doc,
    'All entity IDs are UUID v7 (time-ordered UUIDs) generated by UUIDNext.Uuid.NewSequential(). '
    'This provides globally unique, database-index-friendly, time-sortable identifiers '
    'without requiring a database sequence or auto-increment column.')

divider(doc)

# ════════════════════════════════════════════════════════════════════════════
# 9. AUTHORIZATION
# ════════════════════════════════════════════════════════════════════════════
h1(doc, '9. Authorization')

body(doc,
    'All write operations are protected by the ABAC (Attribute-Based Access Control) policy '
    'engine inherited from the platform. Each command handler calls '
    'IResourceAuthorizationService.AuthorizeWithResolvedPolicyAsync() before performing '
    'business logic.')

add_table(doc,
    ['Resource', 'Action', 'Handler'],
    [
        ('party',       'create / update / delete / list / read', 'Party command/query handlers'),
        ('investor',    'create / update / delete / list / read', 'Investor command/query handlers'),
        ('fund',        'create / update / delete / list / read', 'Fund command/query handlers'),
        ('fundclass',   'create / update / delete / list / read', 'FundClass command/query handlers'),
        ('transaction', 'create / process / cancel / list / read','Transaction command/query handlers'),
        ('holding',     'list / read',                            'Holding query handlers'),
    ],
    col_widths=[1.3, 2.7, 2.5])

body(doc,
    'The resource attributes passed to the policy engine include TenantId from ICurrentUser, '
    'enabling tenant-scoped policy evaluation. Platform-level administrators can bypass '
    'tenant restrictions via the GlobalRole system.')

divider(doc)

# ════════════════════════════════════════════════════════════════════════════
# 10. TESTING
# ════════════════════════════════════════════════════════════════════════════
h1(doc, '10. Testing')

h2(doc, '10.1 Test Coverage')

add_table(doc,
    ['Test Project', 'Tests', 'Focus'],
    [
        ('IFX.Modules.CRM.Domain.Tests',            '24', 'Party and Investor entity validation, normalisation, state transitions.'),
        ('IFX.Modules.CRM.Application.Tests',       '11', 'CreateParty, CreateInvestor, UpdateInvestorKyc handlers — happy path, duplicate code, missing tenant, CreatedBy, event publish.'),
        ('IFX.Modules.Registry.Domain.Tests',       '25', 'Fund and FundClass — currency length validation, code uppercase, IsOpenForSubscription, Close.'),
        ('IFX.Modules.Registry.Application.Tests',  '4',  'CreateFund handler — happy path, duplicate code, tenant check, audit field.'),
        ('IFX.Modules.Holdings.Domain.Tests',       '17', 'Holding — subscribe/redeem accumulation, overdraft guard, auto-close on zero, Freeze/Unfreeze no-ops.'),
        ('IFX.Modules.Transaction.Domain.Tests',    '20', 'Transaction state machine — all 4 factory methods, Process unit calc (8dp), Cancel/Fail/Settle guards.'),
        ('IFX.Modules.Transaction.Application.Tests','10','CreateSubscription cross-module validation (KYC, class, party). ProcessTransaction tenant isolation, already-processed guard.'),
    ],
    col_widths=[3.0, 0.6, 3.0])

h2(doc, '10.2 Test Stack')

bullet(doc, 'xUnit 2.9.2 — test framework')
bullet(doc, 'FluentAssertions 6.12.2 — readable assertions')
bullet(doc, 'Moq 4.20.72 — mock generation for Application tests')
bullet(doc, 'Domain tests use no mocks — entities are created directly via factory methods')

divider(doc)

# ════════════════════════════════════════════════════════════════════════════
# 11. KEY DESIGN DECISIONS
# ════════════════════════════════════════════════════════════════════════════
h1(doc, '11. Key Design Decisions')

add_table(doc,
    ['Decision', 'Rationale'],
    [
        ('Option B: In-Process Integration Events',
         'Chosen over HTTP calls or a message broker for simplicity. The InMemoryIntegrationEventBus '
         'can be swapped for a real broker later without changing module code. Avoids distributed '
         'transaction complexity while the system is a monolith.'),

        ('Holdings is write-only via events',
         'Prevents the unit ledger from being modified directly. Every balance change is traceable '
         'to a processed transaction. Simplifies auditing and reconciliation.'),

        ('Reader interfaces instead of shared domain types',
         'Transaction needs to know if a class is open and if an investor is KYC-approved, but '
         'importing Registry.Domain or CRM.Domain would couple the modules. Reader interfaces in '
         '.Abstractions projects provide the same capability with zero coupling.'),

        ('IFX.BuildingBlocks.Domain for BaseEntity/IAuditableEntity',
         'Originally each module had its own copy of BaseEntity. Consolidating into a shared '
         'building block eliminates duplication and ensures consistent entity identity semantics '
         '(Equals, ==, GetHashCode) across all modules.'),

        ('EnsureCreatedAsync instead of migrations for new modules',
         'The Auth module uses real EF Core migrations because it has a long history. New modules '
         'use EnsureCreatedAsync at startup to keep development friction low. Migrations can be '
         'adopted when the schema stabilises for production use.'),

        ('Soft-delete (Close) instead of hard-delete',
         'Parties, Investors, Funds, and Classes are never physically deleted — they are transitioned '
         'to Closed status. This preserves audit trail and referential integrity with historical '
         'transactions.'),
    ],
    col_widths=[2.3, 4.2])

doc.add_page_break()

# ════════════════════════════════════════════════════════════════════════════
# APPENDIX — File Structure
# ════════════════════════════════════════════════════════════════════════════
h1(doc, 'Appendix A — Project Structure')

code_block(doc,
'src/\n'
'├── BuildingBlocks/\n'
'│   ├── IFX.BuildingBlocks.Domain/         BaseEntity, IAuditableEntity\n'
'│   ├── IFX.BuildingBlocks.Security/       ICurrentUser, IResourceAuthorizationService\n'
'│   └── IFX.Platform.Messaging.Abstractions/  IIntegrationEventBus, IIntegrationEvent\n'
'│\n'
'├── Modules/\n'
'│   ├── CRM/\n'
'│   │   ├── IFX.Modules.CRM.Domain/        Party, Investor entities + repository interfaces\n'
'│   │   ├── IFX.Modules.CRM.Abstractions/  ICrmReader, integration events\n'
'│   │   ├── IFX.Modules.CRM.Application/   Commands, Queries, Handlers, DTOs\n'
'│   │   ├── IFX.Modules.CRM.Infrastructure/ EF Core, repositories, DI\n'
'│   │   ├── IFX.Modules.CRM.Presentation/  Minimal API endpoints\n'
'│   │   └── IFX.Modules.CRM.Composition/   Module wiring\n'
'│   │\n'
'│   ├── Registry/                          (same structure as CRM)\n'
'│   │   └── IFX.Modules.Registry.Abstractions/  IRegistryReader, FundClass events\n'
'│   │\n'
'│   ├── Holdings/                          (same structure, no .Abstractions)\n'
'│   │\n'
'│   └── Transaction/\n'
'│       └── IFX.Modules.Transaction.Abstractions/  TransactionProcessedEvent etc.\n'
'│\n'
'tests/\n'
'├── IFX.Modules.CRM.Domain.Tests/\n'
'├── IFX.Modules.CRM.Application.Tests/\n'
'├── IFX.Modules.Registry.Domain.Tests/\n'
'├── IFX.Modules.Registry.Application.Tests/\n'
'├── IFX.Modules.Holdings.Domain.Tests/\n'
'├── IFX.Modules.Transaction.Domain.Tests/\n'
'└── IFX.Modules.Transaction.Application.Tests/')

# ════════════════════════════════════════════════════════════════════════════
# SAVE
# ════════════════════════════════════════════════════════════════════════════
out_path = os.path.join(os.path.dirname(__file__), 'FundRegistrySystem-DetailDesign.docx')
doc.save(out_path)
print(f'Document saved: {out_path}')
