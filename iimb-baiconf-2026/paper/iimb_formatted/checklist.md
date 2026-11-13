# IIMB Management Review / BAICONF 2026: submission checklist
Paper: *Revealing hidden jump strategies beyond conventional force-plate metrics* (BAICONF 2026, BAI2575). Updated 13 Nov 2026.

Run `./check_format.sh --build` (or `python3 check_format.py --build` inside `overleaf/`) after any edit. It checks the items below that can be checked by script and exits non-zero on any failure. Last run: 60 of 60 checks passed.

Requirement sources: IIMB "Guidelines for Contributors" (https://www.iimb.ac.in/sites/default/files/inline-files/Author%20Guidelines-New%20final.pdf) and the IIMB author page (https://www.iimb.ac.in/imr/guidelines-authors.php). Re-check the live Elsevier guide (https://www.sciencedirect.com/journal/iimb-management-review/publish/guide-for-authors) before upload.

| # | Requirement | How it is met | Checked by |
|---|---|---|---|
| 1 | Double-blind review | No names, affiliations, centre name, repository URL or GitHub user name in the manuscript or exhibits. The centre is "a private sports physiotherapy and performance centre in India". PDF and DOCX author metadata are blank. | script (2) |
| 2 | Title page: title, short title, authors in order, affiliations, postal address, phone, fax, email, corresponding author | Complete for both authors; fax "not available" | manual |
| 3 | Short title <= 5 words | "Curve shape beyond jump metrics" (5) | script (1) |
| 4 | Front matter: title, short title, abstract <= 100 words, <= 8 keywords, extended summary <= 300 words, together | All on page 1 of the manuscript (1.5-spaced block, labelled Abstract and Extended summary); Introduction starts on page 2 | script (1), (12) |
| 5 | Length up to 8,000 words | About 7,130 words excluding references (title, abstract, summary, text, tables, captions, declarations); about 8,480 including references | script (1) |
| 6 | Times 12 pt, double spaced | newtx (Times) 12 pt, double spaced, A4; DOCX in Times New Roman 12, double spaced | script (3) |
| 7 | Tables and figures numbered in order of mention, with notes; also in a separate file | Tables 1-7, Figs 1-5, in order; separate exhibits file (PDF and DOCX) | script (5) |
| 8 | Exhibits in black and white | Greyscale figures (line type and shade only); captions name no colours | script (5) |
| 9 | Readable tables | booktabs rules, no vertical rules, units in headers, numbers aligned on the decimal point (siunitx), CIs as [a, b], short titles above and notes below; text 10 pt or larger; no table wider than the text block | script (4), (5) |
| 9a | Page layout | Tables and figures float to the tops of pages (placeins keeps them in their section); no page except the last is more than 25% empty | script (11) |
| 10 | British spelling | Yes; cited titles keep their published spelling | script (7) |
| 11 | APA 7 references | biblatex-apa + Biber; 44 DOIs printed as https://doi.org/..., all resolve at doi.org | script (6) |
| 12 | Managerial implications | Section 6 | manual |
| 13 | Declarations | No competing interests; no specific funding; data and code availability (link withheld in the blinded file, full URL on the title page); generative-AI statement | script (2), manual |
| 14 | CRediT | On the title page | manual |
| 15 | Permission for non-public organisational data | Signed NDA and data-sharing agreement with PhysioQinesis / Performance Lab (title page only) | manual |
| 16 | Highlights | 5 bullets, each <= 85 characters | script (8) |
| 17 | Ethics approval and consent (77% of athletes under 18) | **Open: the only placeholder left** (Section 3.1 and title page) | script (9) |
| 18 | Overleaf project | `IIMB_BAICONF2026_overleaf.zip`: main.tex at the root, latexmkrc (pdfLaTeX + Biber), README with compile steps; titlepage.tex = cover page; highlights.tex optional; 0 overfull and 0 underfull boxes; builds from a clean unzip | script (4) |

## Open items for Praveen
1. **Ethics.** Replace the bold bracketed text in Section 3.1 of `body.tex` and on the title page with the committee name, approval number and date, and keep one of the two consent options. Then remove the bold (`\ethics{...}` in `preamble.tex`) and delete the last check in `check_format.py`.
2. **Repository.** https://github.com/praveenmaths89/hidden-jump-strategies-forceplate is public (checked 13 Nov 2026), and branch `iimb-baiconf-2026` is on GitHub. For double-blind review the link appears only on the title page. If the editor wants reviewers to see the code, use an anonymised mirror (for example anonymous.4open.science); the public repo shows the authors' user name. The branch still contains `paper/original/BAICONF2026_submitted_abstract_BAI2575.docx` and the BAICONF analysis report; decide whether they should stay public.
3. **Generative-AI statement.** Elsevier asks authors to name the tools used. The statement is generic.
4. **Deadline.** The BAICONF 2026 full-paper deadline (31 Oct 2026) has passed. Confirm a late upload with the conference office.
5. **Protocol sentence.** Confirm: "Centre staff ran the tests as part of routine assessment, not under a research protocol. Warm-up, verbal instructions and rest intervals were therefore not recorded with the data, and no landing technique was prescribed."
6. **Dual submission.** The same analysis exists as a Sports Biomechanics manuscript draft. The title page states that the paper is not under consideration elsewhere.
7. **Fees.** IMR APC (USD 1,200) is reported to be borne by IIMB; the BAICONF registration fee is not confirmed.
8. **Raw data.** Raw VALD data are excluded from every zip and from Git. On the box they are in `_PRIVATE_raw_do_not_transfer/`.
