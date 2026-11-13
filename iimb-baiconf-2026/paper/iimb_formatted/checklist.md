# IIMB Management Review / BAICONF 2026 – formatting checklist
Paper: *Revealing hidden jump strategies beyond conventional force-plate metrics* (BAICONF 2026, BAI2575).
Built 13 Nov 2026 from the journal manuscript in `hidden-jump-strategies-forceplate/paper` (same data, same R pipeline; numbers re-generated from raw by `package/`).

Sources for the requirements (the ScienceDirect guide itself returned 400/403 to every automated fetch, so these were used):
- IIMB "Guidelines for Contributors" PDF: https://www.iimb.ac.in/sites/default/files/inline-files/Author%20Guidelines-New%20final.pdf (contents read through search; direct fetch blocked)
- IIMB author page: https://www.iimb.ac.in/imr/guidelines-authors.php (up to 8,000 words)
- Summary of the current Elsevier guide: https://contentxprtz.com/article/journal/iimb-management-review-scopus ; DOAJ/EZB record (APC USD 1,200): https://ezb.uni-regensburg.de/detail.phtml?bibid=MPIS&colors=3&jour_id=134855&lang=en
- **Re-check against the live guide** https://www.sciencedirect.com/journal/iimb-management-review/publish/guide-for-authors before upload.

| # | Requirement | How it is met | File |
|---|---|---|---|
| 1 | Double-blind review | Manuscript has no names, affiliations, centre name, acknowledgements, ORCID or repository link; centre described as "a private sports physiotherapy and performance centre in India"; DOCX/PDF author metadata blank | `IIMB_BAICONF2026_Manuscript_anonymised.docx/.pdf` |
| 2 | Cover page: title, short title, authors in order, affiliations, postal address, phone, fax, email, corresponding author | Complete. Usha Ananthakumar's office address, phone (+91 22 2576 7786), email (usha@som.iitb.ac.in) and ORCID (0000-0003-1983-2168, verified on pub.orcid.org) taken from public SJMSOM/ORCID pages; fax "not available" for both | `IIMB_BAICONF2026_Title_Page.docx/.pdf` |
| 3 | Abstract <=100 words, <=8 keywords, extended summary <=300 words | Abstract 100 words; 8 keywords; extended summary ~297 words | manuscript pp. 1-2 |
| 4 | Up to 8,000 words | Main text incl. front matter, tables, captions and declarations ~7,460 words; ~8,880 incl. references. Nothing cut | - |
| 5 | Times 12 pt, double spaced | LaTeX: newtx (Times) 12 pt, double spaced, A4, 1-in margins, line numbers. DOCX: Times New Roman 12, double | both |
| 6 | Tables/figures numbered in order of mention, with notes | Tables 1-6, Figs 1-5 (pipeline diagram removed 13 Nov; old Figs 2-6 renumbered 1-5; pipeline described in prose in Section 3.1) | manuscript |
| 7 | Tables and figures also in a separate file | Done (LaTeX PDF + DOCX) | `IIMB_BAICONF2026_Exhibits_Tables_Figures.*` |
| 8 | Exhibits black and white (older IIMB PDF) | **Open.** Figures are colour (colour-blind-safe palette); captions refer to colours | - |
| 9 | British spelling | Yes | - |
| 10 | References APA 7 | biblatex-apa + Biber (Overleaf); pandoc citeproc APA CSL (DOCX) | - |
| 11 | Managerial implications | Section 6 "Managerial and practical implications", grounded in the reported findings | - |
| 12 | Declarations (competing interests, funding, data availability, generative AI) | Filled: no competing interests; no specific funding; data availability (raw data owned by the centre under NDA; code and de-identified data on request); AI tools assisted language editing and code review, authors take responsibility | manuscript + title page |
| 13 | CRediT | P.C.: Conceptualisation, Data curation, Formal analysis, Methodology, Software, Visualisation, Writing - original draft; U.A.: Supervision, Writing - review and editing | title page |
| 14 | Permission for non-public organisational data | Stated as covered by the signed NDA / data-sharing agreement with PhysioQinesis / Performance Lab | title page |
| 15 | Highlights | 5 bullets, each <=85 characters | `IIMB_BAICONF2026_Highlights.*` |
| 16 | Ethics approval / consent (minors) | **Open - only visible placeholder left** (Section 3.2) | manuscript |
| 17 | Overleaf project | `IIMB_BAICONF2026_overleaf.zip` (root = main.tex), pdfLaTeX + Biber, 0 overfull boxes | - |

## Open items for Praveen
1. **Ethics** (the one visible placeholder): committee name, approval number/date, consent/assent for under-18 athletes (77% of athletes) or waiver, Declaration of Helsinki statement.
2. **Dual submission**: the same analysis exists as a Sports Biomechanics manuscript (not submitted). The title page confirms "not under consideration elsewhere" - keep it that way.
3. Confirm the wording added without a source: test protocol sentence ("administered by the centre's staff as part of routine assessments ... warm-up, verbal instructions and rest intervals were not recorded with the data, and landing technique was not standardised"); the data-availability promise (code and de-identified data on request); the prior-presentation wording; CRediT roles; Usha's details and her approval.
4. Testing period "November 2022 to April 2026" = first and last recorded dates (IST) of the 327 analysed sessions.
5. Colour vs black-and-white figures.
6. Numbers differ from the submitted BAICONF abstract (817/213, 71%, 5-17% vs 805/212, 74.8%, 2.7-13.1%).
7. Fees: IMR APC USD 1,200 reportedly borne by IIMB; BAICONF 2026 registration fee not confirmed.
8. Raw VALD data are excluded from every zip and from Git; on the box they are quarantined in `_PRIVATE_raw_do_not_transfer/`.
