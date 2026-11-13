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
| 1 | Double-blind review; author names/affiliations only on the cover page | Manuscript has no names, affiliations, acknowledgements, ORCID or funding; DOCX author metadata blanked | `IIMB_BAICONF2026_Manuscript_anonymised.docx/.pdf` |
| 2 | Cover page: title, short title (≤5 words), all authors in order, affiliations, postal address, phone, fax, email, corresponding author | Done; Usha Ananthakumar's phone/email/ORCID and fax left as placeholders | `IIMB_BAICONF2026_Title_Page.docx/.pdf` |
| 3 | Second page: title, short title, abstract ≤100 words, ≤8 keywords, extended summary ≤300 words | Abstract 100 words; 8 keywords; extended summary 300 words (new text condensed from the paper; numbers from the R run) | manuscript p. 1–2 |
| 4 | Length: up to 8,000 words (IIMB page; older PDF says 8,000–10,000 incl. tables and figures) | Front matter 434 + main text with tables and captions 6,153 + declarations 163 = 6,750; with references 8,142. Nothing was cut | – |
| 5 | Times New Roman 12 pt, double spaced | DOCX: Times New Roman 12, double spacing (tables 10 pt single). PDF: TeX Gyre Termes (Times clone) 12 pt, double spaced, A4, 1-inch margins | both |
| 6 | Tables/figures numbered serially in order of mention, with notes/legends, abbreviations expanded | Tables 1–6 and Figures 1–6 in mention order, each table has a Note; captions expand abbreviations | manuscript |
| 7 | Tables and figures also in a separate Word file | Done | `IIMB_BAICONF2026_Exhibits_Tables_Figures.docx/.pdf` |
| 8 | Exhibits in black and white only (older IIMB PDF) | **Not met – open item.** Figures are colour (Okabe–Ito, colour-blind safe) and captions refer to colours; converting would need re-wording captions and re-drawing in R | – |
| 9 | British spelling | Text already uses British spelling (normalised, centre, programme) | – |
| 10 | References: APA author–date, alphabetical | Rebuilt by pandoc citeproc with APA 7 CSL from the paper's `references.bib` (all DOIs previously Crossref-checked); no field codes | manuscript |
| 11 | Managerial insights emphasised | "Practical applications" renamed "Practical and managerial implications"; extended summary ends with implications for programme managers. **Suggest Praveen adds 1 short paragraph on decision-making value for high-performance centres** (not written, to avoid inventing claims) | – |
| 12 | Declarations (Elsevier): competing interests, funding, data availability, generative-AI use | Sections present at end of manuscript; wording still `[AUTHORS TO COMPLETE]` where the paper had TODOs | manuscript |
| 13 | Originality confirmation (original, not published, not under consideration elsewhere, copyright) | Statement drafted on title page for authors to confirm | title page |
| 14 | Written permission for non-public organisational data | Placeholder on title page | title page |
| 15 | Highlights (Elsevier usual; not confirmed as mandatory for IMR) | 5 bullets, each ≤85 characters | `IIMB_BAICONF2026_Highlights.docx/.pdf` |
| 16 | Ethics approval / consent (minors) | Placeholder kept in Methods | manuscript |
| 17 | Text boxes for background/case material (IIMB preference "wherever possible") | Not used; no case material in the paper | – |

## Open items for Praveen (only he can decide or supply)
1. **Dual-submission conflict.** The same analysis is prepared as a *Sports Biomechanics* article (`hidden-jump-strategies-forceplate`, not submitted). IMR requires the paper not be under consideration elsewhere. Decide which journal gets this version before submitting either.
2. Ethics committee name, approval number, consent/assent for under-18 athletes (77% of athletes were minors), Declaration of Helsinki statement.
3. Centre name or description, testing period, data-sharing agreement, and written permission from the centre (IMR asks for this for non-public organisational data).
4. Test protocol details (warm-up, arm position, landing instruction, trials, rest, acceptance criteria).
5. Funding statement; confirm "no competing interests"; acknowledgements.
6. Generative-AI declaration wording (suggested text is in the manuscript).
7. Data-availability statement: repository URL/DOI; data owner; terms for raw-data requests. The GitHub repo is private.
8. Co-author details: Usha Ananthakumar's phone, email and ORCID; CRediT roles; author order; her approval of this version.
9. Numbers differ from the submitted abstract (817/213, 71%, 5–17% vs 805/212, 74.8%, 2.7–13.1%). Decide whether to tell the BAICONF organisers.
10. Colour vs black-and-white figures (row 8).
11. Fees: IMR lists an APC of USD 1,200 (DOAJ), which IIMB has said it bears on authors' behalf. Confirm before accepting publication. BAICONF registration fee: not confirmed for 2026 (2015 rates were INR 2,500–4,500); the DCAL site blocked automated access.
