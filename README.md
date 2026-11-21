# Ham Radio / GROL License Quiz

A small desktop app, written in Lazarus/Free Pascal, for practising FCC
license exams one multiple-choice question at a time. It currently ships
with five question pools you can switch between from the **Exam:**
dropdown:

- **Amateur Extra Class (Element 4)** amateur radio exam.
- **GROL Element 1** - Radio Law & Operating Practice (commercial radio).
- **GROL Element 3** - General Radiotelephone (commercial radio).
- **Element 7** - GMDSS Radio Operator (Global Maritime Distress and Safety System).
- **Element 8** - Ship RADAR Techniques (the commercial RADAR endorsement).

Only the pools whose file is actually present next to the program show up
in the dropdown, so the app still works fine if you only have one or two of
all five files.

Written by DL1BWA/AC1WW with support from Claude Opus 5.5.

This is the companion to the
[Technician quiz](https://github.com/versarite/Technician_US_license_exam_quiz).
It shares the same code base and adds the explanations, the commercial
exam pools, mock exams and error analysis.
The right and wrong answers are minimally annotated, 
unless you are completely new to the subjects you can survive 
the exams without textbook preparation.

## Features

- **Five built-in exams** (above), picked from the **Exam:** dropdown.
  Switching exams asks first if it would discard an unfinished run; each
  exam keeps its own saved progress, wrong-answer list and mock-exam
  history, so switching back and forth never mixes them up.
- Study everything at once or filter by a single subelement (Amateur Extra
  only - the GROL pools aren't broken into named subelements, so they're
  studied as one pool).
- Question order and answer order are shuffled every run, so you can't
  memorise answer positions.
- **Why?** button: explains the concept behind the question, with the
  formula, worked numbers or FCC rule where relevant - and, where the
  question file supplies them, a short one-line note on *each* answer
  choice (why the correct one is right, why each distractor is wrong). It's
  available any time a question has explanation content, even before you've
  picked an answer, so you can use it to study as well as to check
  yourself - it only stays disabled when a question has no explanation at
  all. Every question in all five pools now has a correct-answer
  explanation, with the worked calculation for numerical questions and the
  reasoning from the drawing for figure questions. Where the wrong answers
  are real things (other circuits, devices, modes, channels, bands), the
  GROL questions also say what each wrong choice actually is or does
  (about 780 questions). Legal facts, pure calculations and figure-output
  questions get no wrong-answer notes.
- Element 7 (GMDSS) questions also show a **Background** paragraph under
  the explanation: the terms, acronyms and procedure behind the topic
  (sea areas, DSC distress procedure, priorities, NAVTEX/SafetyNET,
  Inmarsat operation, SITOR commands and so on). It comes from the
  optional `background` field in the pool JSON, and any pool can use it.
- For about 220 GROL questions, **Why?** opens a comparison diagram too:
  antenna patterns, waveforms, transistor configurations, filter shapes,
  the pulse RADAR block diagram, microwave band letters, GMDSS identity
  numbers, distress frequencies, emission designators, sea areas, the DSC
  distress procedure, the SART RADAR picture and SITOR ARQ vs FEC.
- For about 170 Amateur Extra questions, **Why?** also opens a diagram in
  its own window: a formula card with a worked example, a chart (resonance
  curves, antenna patterns, filter responses...) or a block diagram.
- The 28 Amateur Extra questions that refer to a diagram, schematic or
  Smith chart (Figures E5-1 to E9-3) open the figure in its own window, as
  do the 21 GROL Element 3 questions that refer to one of its 17 drawings
  (Figures 3B1 to 3H17) and the 20 Element 8 questions that refer to one of
  its 12 drawings (Figures 8A1 to 8F12).
- **Back** button: step back through the questions you've already seen, with
  your earlier answers shown again. Going back never changes the score.
- **Retest Wrong Answers**: every question you miss is remembered (per
  exam), and the button lights up with a running count. Click it to drill
  just those questions; answering one correctly drops it off the list,
  missing it again keeps it on. **Back to Study** returns you to exactly
  where your main run was paused - nothing about it is lost or reshuffled.
- **Mock Exam**: draws a random practice exam the same way the real exam is
  built - one random question from every question "group" in the pool - so
  it's the right length and composition automatically: 50 questions (need
  37 to pass) for Amateur Extra, 24 questions (need 18 to pass) for GROL
  Element 1, 100 questions (need 75 to pass) for GROL Element 3, 100
  questions (need 75 to pass) for Element 7, 50 questions (need 38 to pass)
  for Element 8. It tells
  you PASS or FAIL at the end. Starting one pauses your main study run,
  exactly like Retest; **Back to Study** resumes it. A question you miss on
  a mock exam is added to that exam's wrong-answer list too, so you can
  follow a mock exam straight into Retest.
- **Error Analysis**: a bar chart of your error rate per subelement for
  the exam that's loaded - E0-E9 for Amateur Extra, and the official FCC
  subelements for GROL (1-A Rules & Regulations ... 1-D Other Equipment;
  3-A Principles ... 3-Q Safety). Each row has two bars: **all attempts**
  (every answer ever given for that exam - study runs, retests and mock
  exams, kept across restarts) and the **current study run** only. Press
  Escape to close it. **Reset Error History** clears the all-attempts
  counts for the loaded exam only; it doesn't touch the other exams, your
  current run or the Retest list. The first time an exam is opened with
  this feature, its existing wrong-answer list is imported once as a
  starting point (one answer and one error per listed question).
- **Resumes where you stopped**: the current run (question order, answers,
  score) is saved after every answer and restored the next time you start
  the program, so you can work through the whole pool over several
  sessions. **Restart / Reshuffle** or picking another category starts a new
  run (after asking). Progress files live in your user profile, e.g.
  `C:\Users\<you>\AppData\Local\radioquiz\progress_e.txt` (Amateur Extra),
  `progress_1.txt` (GROL Element 1), `progress_3.txt` (GROL Element 3),
  `progress_7.txt` (Element 7), `progress_8.txt` (Element 8);
  delete one to start that exam fresh. Wrong-answer lists live alongside
  them as `wrong_e.txt`, `wrong_1.txt`, `wrong_3.txt`, `wrong_7.txt`,
  `wrong_8.txt`, and the Error Analysis
  counts as `error_history_e.txt`, `error_history_1.txt`,
  `error_history_3.txt`, `error_history_7.txt`, `error_history_8.txt`. (The program used to be
  called hamquiz; on first start it copies any saved data from the old
  `AppData\Local\hamquiz\` folder, which is left in place.)
- A large window (1820x1000, sized for a 1920x1080 screen) so answer
  choices and the extended **Why?** explanation have room without
  truncating text.
- Running score and percentage shown in the corner. The percentage turns red
  once you've missed more questions than the real exam allows and still
  lets you pass (13 for Amateur Extra, 6 for GROL Element 1, 25 for GROL
  Element 3, 25 for Element 7, 12 for Element 8).

## About the exams

- **Amateur Extra**: 50 questions drawn from all subelements, need 37
  correct (74%) to pass. There is no Morse code test; the U.S. dropped that
  requirement for all license classes in 2007.
- **GROL Element 1** (Radio Law & Operating Practice): 24 questions, need
  18 correct (75%) to pass.
- **GROL Element 3** (General Radiotelephone): 100 questions, need 75
  correct (75%) to pass.
- **Element 7** (GMDSS Radio Operator): 100 questions, need 75 correct
  (75%) to pass.
- **Element 8** (Ship RADAR Techniques): 50 questions, need 38 correct
  (76%) to pass.
- GROL Elements 1 and 3 together make up the General Radiotelephone
  Operator License exam, a commercial (not amateur) FCC license. Element 8
  adds the Ship RADAR endorsement to it. Element 7 is the written exam for
  the GMDSS Radio Operator's License.

## Download

A ready-built Windows program is attached to the
[Releases](../../releases) page. Unzip it and keep `radioquiz.exe`, the
`*.json` pool files and the `images/` folder together.

## Building

1. Install [Lazarus](https://www.lazarus-ide.org/). It includes Free Pascal.
2. Open `radioquiz.lpi` (**File → Open Project**).
3. Press **F9** to compile and run.

Or, from the command line:

```
lazbuild radioquiz.lpi
```

The executable looks for `questions.json`, `grol_element1.json`,
`grol_element3.json`, `grol_element7.json`, `grol_element8.json` and the
`images/` folder (including `images/explain/`)
next to itself, one folder up, or in the current directory. When you move
the built program elsewhere, copy whichever of those you want to keep along
with it.

## Project layout

| File | Purpose |
|------|---------|
| `radioquiz.lpi` | Lazarus project file |
| `radioquiz.lpr` | Program entry point |
| `umain.pas` / `umain.lfm` | Main quiz window |
| `ufigure.pas` / `ufigure.lfm` | Pop-up window for diagrams |
| `uerrorchart.pas` | Error Analysis chart window |
| `questions.json` | Amateur Extra question pool, with explanations |
| `grol_element1.json` | GROL Element 1 question pool |
| `grol_element3.json` | GROL Element 3 question pool |
| `grol_element7.json` | Element 7 (GMDSS) question pool |
| `grol_element8.json` | Element 8 question pool |
| `images/` | Figures E5-1 … E9-3, 3B1 … 3H17 and 8A1 … 8F12 |
| `images/explain/` | Diagrams shown with the explanations |

## Question file format

Each pool file is an array of objects:

```json
{
  "id": "E9G06",
  "question": "…",
  "choices": ["…", "…", "…", "…"],
  "correct": 0,
  "explanation": "…",
  "choice_notes": ["…", "…", "…", "…"],
  "background": "…",
  "explanation_image": "smith_chart.png",
  "figure": "e9-3.png"
}
```

`correct` is the zero-based index into `choices`. `explanation`,
`choice_notes`, `background`, `explanation_image` and `figure` are all optional and can
be left out entirely; `figure` names a file in `images/`,
`explanation_image` a file in `images/explain/`.

`choice_notes`, when present, is a one-line note per entry in `choices`
(same order, same length) - a short "why" for that specific choice. **Why?**
shows these next to each answer letter, re-mapped to however the choices
happen to be shuffled on screen, so they always line up with what's
visible. A choice with an empty string (or no `choice_notes` array at all)
just shows no note for that letter; `explanation` alone still works exactly
as before if a question has no per-choice notes yet.

`background`, when present, is a short paragraph of context (terms,
acronyms, procedures) shown under the explanation. Element 7 uses one per
topic, repeated on each of the topic's six questions.

For a lettered pool (Technician/General/Extra), the first two characters of
`id` set the subelement used for category filtering (e.g. `E9` for
`E9G06`). For a pool whose `id` starts with a digit (the GROL pools use
`"1-7B4"`-style IDs), there's no subelement breakdown - the whole pool is
one category.

**Mock Exam** needs one more thing from `id`: stripping the trailing
digits must give the question's "group" (`E9G06` -> `E9G`, `1-7B4` ->
`1-7B`), and the real exam must draw exactly one question from every group.
That's true of all five bundled pools and is how their mock exams come out
the right length automatically, with no per-pool table to maintain. Drop in
another pool built the same way (e.g. a future GROL Element 9) and add
one line to the `PoolCandidate*` arrays near the top of `umain.pas`'s
implementation section to offer it in the dropdown too.

## Question pools

The official question pool documents (PDFs) are not included in this
repository. They can be downloaded from the FCC web site, under
*Question Pools and Study Guides* on the
[Commercial Radio Operator License page](https://www.fcc.gov/node/182085)
(GROL Elements 1 and 3, GMDSS Element 7, Ship RADAR Element 8), and from
the [NCVEC](https://www.ncvec.org/) (Amateur Extra).

The Amateur Extra questions, answer choices and figures come from the
2024–2028 Amateur Extra question pool published by the NCVEC Question Pool
Committee, which releases its pools into the public domain. Its
explanations and explanation diagrams are **not** part of the official
pool - they were written for this project as study aids and may contain
mistakes; the official pool is the authority on correct answers.
Corrections are welcome as issues or pull requests.

The GROL Element 1 and Element 3 questions were supplied as JSON files
alongside this app's source. 34 of them (2 in Element 1, 32 in Element 3)
originally had an empty `question` field with the real question's tail
folded into the first answer choice and one choice missing outright - an
extraction artifact from whatever produced those files. All 34 were
corrected against the official 2009 FCC Commercial Element 1 and Element 3
question pool PDFs (the source NCVEC released these pools from), so both
files now carry the full official set: 144 questions / 24 groups for
Element 1, 600 questions / 100 groups for Element 3. A later word-for-word
comparison of both files against the PDFs found one more garbled question
(3-52G2, fixed); everything else, including all answer keys, matched. The
17 Element 3 drawings were extracted from the PDF and linked to their
questions.

The Element 8 questions, answer key and drawings were taken directly from
the official FCC Commercial Element 8 question pool PDF (2009 pool, file
dated 2024): 300 questions / 50 groups, 12 drawings. Two obvious typos in
the PDF's answer lettering ("D," in 8-14B5, a missing period in 8-28C4)
didn't affect the text.

The Element 7 questions and answer key were taken directly from the
official GMDSS Element 7 question pool PDF (2019 pool, file dated 2021):
600 questions / 100 groups, no drawings. Element 7 IDs are stored with a
`7-` prefix (`7-1A1`) so they can't clash with the other pools.

The explanations for GROL Elements 1, 3, 7 and 8, like the Amateur Extra
ones, were written for this project as study aids and are **not** part of
the official pools. Numerical answers were worked through and checked
against the official key, but there may still be mistakes; the official
pools are the authority on correct answers. Where the official key itself
looks odd or outdated, the explanation says it is giving the pool's answer.

## License

This project is licensed under
[CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/). See
[LICENSE](LICENSE). The question pools and figures are public domain
(NCVEC and FCC); the license covers the code, explanations and diagrams
written for this project.
