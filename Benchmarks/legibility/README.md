# How small can a screenshot get before an agent misreads it?

Two dense 1440x900-point screens (`dashboard.html`: table with confusable IDs, 9-12 pt text, checkbox and toggle state;
`ide.html`: 12 pt code, 11 pt terminal, 10 pt status bar) rendered at 2x with headless Chrome, then shrunk with
the same Core Graphics resize Snip uses (`img/`). 46 questions with exact answers (`questions.json`, `answers.json`).
Each width went to a fresh Claude Opus 5.5 subagent that could only `Read` its two images: no cropping, zooming or OCR.
One run per width (2026-10-17).

| Width (px) | Pixels per point | Wrong of 46 | Answers it flagged unsure | Image tokens, both screens (measured) |
|---|---|---|---|---|
| 2880 | 2.0 (Retina) | 1 | 4 | +5.4k |
| 2160 | 1.5 | 1 | 4 | +5.7k |
| 1568 | 1.09 (Snip's copy cap) | 1 | 4 | +3.2k |
| 1440 | 1.0 (Snip's copy) | 1 | 5 | +2.6k |
| 1152 | 0.8 | 1 | 4 | +1.2k |
| 1008 | 0.7 | 0 | 8 | +1.0k |
| 864 | 0.6 | 3 | 22 | +0.4k |
| 720 | 0.5 | 8 | 36 | baseline |

Token column: subagent total minus the 720 px run, so it is relative and a little noisy.

- The one miss from 2x down to 0.8x is `ORD-0O9P`, read as `ORD-009P` every time. That's the font (O and 0 look alike in this monospace face), not resolution.
- Information starts to go at 0.6 px per point: `C0Oo` became `C0Do`, 5 warnings became 6.
- At 0.5x, 8 answers were wrong, all small digits or confusable letters: `10:04:12` read as `:13`, `390ms` as `398ms`, `5.9.3` as `5.6.3`, `#A-55190` as `AX-55180`.
- The agent never gave a wrong answer while saying it was sure. As resolution dropped, it flagged more answers unsure (4 at Retina, 36 at 0.5x).
- Above about 2000 px the harness shrinks the image anyway: 2880 cost about as much as 2160, and neither read better than 1x.

Takeaway: 1 px per point is about 1.4x above where reading starts to fail, and costs half the tokens of a Retina image for the same answers.
